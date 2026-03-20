--- necrodefib.lua
--- Dedicated defib behavior for the Necromancer's `weapon_ttth_necrodefi`.
--- Directly invokes the weapon's BeginRevival/FinishRevival server-side (mirroring
--- how the generic Defib behavior calls Revive() directly) so the eye-trace check
--- in weapon_ttt_defibrillator:Think() never has a chance to cancel the revival.
--- OnRevive → AddZombie() still fires normally via weapon_ttth_necrodefi:OnRevive.
--- Includes witness checking, corpse prioritization, and round-phase awareness.

---@class BNecroDefib
TTTBots.Behaviors.NecroDefib = {}

local lib = TTTBots.Lib

---@class BNecroDefib
local NecroDefib = TTTBots.Behaviors.NecroDefib
NecroDefib.Name = "NecroDefib"
NecroDefib.Description = "Use the Necro Defibrillator to revive a corpse as a zombie."
NecroDefib.Interruptible = true
NecroDefib.WeaponClasses = { "weapon_ttth_necrodefi" }

local STATUS = TTTBots.STATUS

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

--- Maximum range to search for corpses.
local SEARCH_RANGE = 3000
--- How close the bot needs to be to the corpse to begin defibbing.
local CLOSE_THRESHOLD = 80
--- How far the bot can drift before we cancel a started revive.
local CANCEL_THRESHOLD = 200
--- Behavior timeout in seconds.
local BEHAVIOR_TIMEOUT = 45
--- Maximum witnesses allowed before the bot waits (early game).
local MAX_WITNESSES_EARLY = 0
--- Maximum witnesses allowed in late/overtime phases (more aggressive).
local MAX_WITNESSES_LATE = 2
--- How long to loiter near the corpse waiting for witnesses to clear (seconds).
local WITNESS_WAIT_TIMEOUT = 15
--- Revive hold duration: matches ttt_necro_defibrillator_revive_time (default 3s) plus a small buffer.
local REVIVE_HOLD_TIME = 3.5

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Check if the bot has a necro defi.
---@param bot Bot
---@return boolean
function NecroDefib.HasNecroDefi(bot)
    for _, class in ipairs(NecroDefib.WeaponClasses) do
        if bot:HasWeapon(class) then return true end
    end
    return false
end

--- Get the necro defi weapon entity.
---@param bot Bot
---@return Weapon?
function NecroDefib.GetNecroDefi(bot)
    for _, class in ipairs(NecroDefib.WeaponClasses) do
        local wep = bot:GetWeapon(class)
        if IsValid(wep) then return wep end
    end
    return nil
end

--- Check if the bot is a necromancer (not a zombie).
---@param bot Bot
---@return boolean
local function isNecromancer(bot)
    if not IsValid(bot) then return false end
    if TTTBots.Roles.IsNecroMaster then
        return TTTBots.Roles.IsNecroMaster(bot)
    end
    -- Fallback: check subrole directly
    return ROLE_NECROMANCER and bot:GetSubRole() == ROLE_NECROMANCER
end

--- Get the spine position of a ragdoll for positioning.
---@param rag Entity
---@return Vector
function NecroDefib.GetSpinePos(rag)
    local default = rag:GetPos()
    local spineName = "ValveBiped.Bip01_Spine"
    local spine = rag:LookupBone(spineName)
    if spine then
        return rag:GetBonePosition(spine)
    end
    return default
end

--- Get the best aim position on a ragdoll that an eye-trace will actually hit.
--- Uses the ragdoll's OBBCenter (the middle of its collision hull) so the
--- MASK_SHOT_HULL trace in weapon Think() resolves to the ragdoll entity
--- instead of sailing over it.
---@param rag Entity
---@return Vector
function NecroDefib.GetCorpseAimPos(rag)
    if not IsValid(rag) then return rag:GetPos() end
    return rag:LocalToWorld(rag:OBBCenter())
end

--- Count non-allied witnesses near a position.
---@param bot Bot
---@param pos Vector
---@return number
local function countWitnesses(bot, pos)
    local nonAllies = TTTBots.Roles.GetNonAllies(bot)
    local witnesses = lib.GetAllWitnessesBasic(pos, nonAllies, bot)
    return table.Count(witnesses)
end

--- Get the maximum allowed witnesses based on round phase.
---@param bot Bot
---@return number
local function getMaxWitnesses(bot)
    local ra = bot.BotRoundAwareness and bot:BotRoundAwareness()
    if ra then
        local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
        if PHASE then
            local phase = ra:GetPhase()
            if phase == PHASE.LATE or phase == PHASE.OVERTIME then
                return MAX_WITNESSES_LATE
            end
        end
    end
    return MAX_WITNESSES_EARLY
end

--- Find the best corpse to revive. Necromancers revive ANY dead player (not ally-only).
--- Priority order:
---   1. Corpses this bot personally killed (tttbots_killedBy tag) — convert own
---      victims immediately to keep the kill quiet and grow the zombie army.
---   2. Closest other revivable corpse within range as fallback.
---@param bot Bot
---@return Player? target
---@return Entity? ragdoll
function NecroDefib.FindBestCorpse(bot)
    local corpses = lib.GetRevivableCorpses()
    if not corpses or #corpses == 0 then return nil, nil end

    local botPos = bot:GetPos()
    local cTime = CurTime()

    local bestKilledTarget, bestKilledRag, bestKilledDist = nil, nil, math.huge
    local bestFallbackTarget, bestFallbackRag, bestFallbackDist = nil, nil, math.huge

    for _, rag in ipairs(corpses) do
        if not lib.IsValidBody(rag) then continue end

        local deadply = player.GetBySteamID64(rag.sid64)
        if not IsValid(deadply) then continue end
        if (deadply.reviveCooldown or 0) > cTime then continue end

        -- Skip bodies already claimed by another bot
        if TTTBots.Match.MarkedForDefib[deadply]
            and TTTBots.Match.MarkedForDefib[deadply] ~= bot then
            continue
        end

        local dist = botPos:Distance(rag:GetPos())
        if dist > SEARCH_RANGE then continue end

        -- Did this bot kill this person?
        local killedByMe = (rag.tttbots_killedBy == bot)
            or (deadply.tttbots_killedBy == bot)

        if killedByMe then
            if dist < bestKilledDist then
                bestKilledDist = dist
                bestKilledTarget = deadply
                bestKilledRag = rag
            end
        else
            if dist < bestFallbackDist then
                bestFallbackDist = dist
                bestFallbackTarget = deadply
                bestFallbackRag = rag
            end
        end
    end

    -- Own kills take priority; otherwise use closest revivable
    if bestKilledTarget then
        return bestKilledTarget, bestKilledRag
    end
    return bestFallbackTarget, bestFallbackRag
end

-- ---------------------------------------------------------------------------
-- Behavior interface
-- ---------------------------------------------------------------------------

function NecroDefib.Validate(bot)
    if not TTTBots.Lib.IsTTT2() then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not isNecromancer(bot) then return false end
    if bot.preventDefib then return false end

    -- Must have the necro defi
    if not NecroDefib.HasNecroDefi(bot) then return false end

    -- Check if weapon still has clip
    local defi = NecroDefib.GetNecroDefi(bot)
    if defi and defi.Clip1 and defi:Clip1() <= 0 then return false end

    -- Re-use existing target if valid
    if bot.necroDefibTarget and bot.necroDefibRag then
        if lib.IsValidBody(bot.necroDefibRag) then
            return true
        end
    end

    -- Find a new target
    local target, rag = NecroDefib.FindBestCorpse(bot)
    if not (target and rag) then return false end

    -- Check if already claimed by another bot
    if TTTBots.Match.MarkedForDefib[target] and TTTBots.Match.MarkedForDefib[target] ~= bot then
        return false
    end

    bot.necroDefibTarget = target
    bot.necroDefibRag = rag

    return true
end

function NecroDefib.OnStart(bot)
    bot.necroDefibBehaviorStart = CurTime()

    if not bot.necroDefibTarget or not bot.necroDefibRag then
        bot.necroDefibTarget, bot.necroDefibRag = NecroDefib.FindBestCorpse(bot)
    end

    if not (bot.necroDefibTarget and bot.necroDefibRag) then
        return STATUS.FAILURE
    end

    -- Mark the target so other bots don't also try to defib it
    if not TTTBots.Match.MarkedForDefib[bot.necroDefibTarget] then
        TTTBots.Match.MarkedForDefib[bot.necroDefibTarget] = bot
    end

    -- Fire chatter event
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("NecroRevivingZombie", { player = bot.necroDefibTarget:Nick() }, true)
    end

    return STATUS.RUNNING
end

---@param bot Bot
function NecroDefib.OnRunning(bot)
    local inventory, loco = bot:BotInventory(), bot:BotLocomotor()
    if not (inventory and loco) then return STATUS.FAILURE end

    local defi = NecroDefib.GetNecroDefi(bot)
    if not NecroDefib.HasNecroDefi(bot) then return STATUS.FAILURE end
    if defi and defi.Clip1 and defi:Clip1() <= 0 then return STATUS.FAILURE end

    local target = bot.necroDefibTarget
    local rag = bot.necroDefibRag

    -- Timeout check
    if bot.necroDefibBehaviorStart and (CurTime() - bot.necroDefibBehaviorStart) > BEHAVIOR_TIMEOUT then
        return STATUS.FAILURE
    end

    if not (target and rag) then return STATUS.FAILURE end
    if not (IsValid(target) and IsValid(rag)) then return STATUS.FAILURE end
    if not lib.IsValidBody(rag) then return STATUS.FAILURE end

    -- If we already triggered BeginRevival, wait for the weapon to finish (state
    -- transitions from DEFI_BUSY back to DEFI_IDLE on success, or DEFI_CHARGE on
    -- error then back to DEFI_IDLE after errorTime).
    if bot.necroDefibStartTime ~= nil then
        local defiState = defi and defi.GetState and defi:GetState()
        -- DEFI_IDLE == 0 (reset after success or after error cooldown expires)
        if defiState == 0 then
            -- Weapon has finished — either revive completed or failed.
            -- Check whether the target was actually revived (IsTerror == alive).
            if IsValid(target) and target:IsTerror() then
                return STATUS.SUCCESS
            end
            -- Weapon went back to idle but target isn't alive — the eye-trace
            -- check in Think() likely cancelled the revival.  Fallback: directly
            -- invoke the revive pipeline and consume one ammo charge.
            if not bot.necroDefibAttemptedDirectRevive then
                bot.necroDefibAttemptedDirectRevive = true
                if IsValid(target) and IsValid(rag) and lib.IsValidBody(rag) and not target:IsTerror() then
                    local reviveHealth = defi.cvars and defi.cvars.revivalHealth and defi.cvars.revivalHealth:GetInt() or 75
                    local doResetConfirm = defi.cvars and defi.cvars.resetConfirmation and defi.cvars.resetConfirmation:GetBool() or false
                    target:Revive(
                        0,
                        function(p)
                            if doResetConfirm then
                                p:ResetConfirmPlayer()
                                p:TTT2NETSetBool("body_found", true)
                            end
                            p:SetMaxHealth(reviveHealth)
                            p:SetHealth(reviveHealth)
                            -- Fire the weapon's OnRevive (e.g. AddZombie for necro)
                            if IsValid(defi) and defi.OnRevive then
                                defi:OnRevive(p, bot)
                            end
                        end,
                        function(p)
                            if p:IsTerror() then return false end
                            return true
                        end,
                        true,
                        REVIVAL_BLOCK_NONE
                    )
                    target:SendRevivalReason(defi.revivalReason or "revived_by_necromancer", { name = bot:Nick() })
                    -- Consume one ammo charge from the defib
                    if defi.TakePrimaryAmmo then
                        defi:TakePrimaryAmmo(1)
                    end
                    if defi.CanPrimaryAttack and not defi:CanPrimaryAttack() then
                        defi:Remove()
                    end
                    bot.necroDefibStartTime = CurTime()
                    return STATUS.RUNNING
                end
            end
            -- Revive failed — bail out so Validate can pick a new corpse.
            return STATUS.FAILURE
        end

        -- Still DEFI_BUSY (1) or DEFI_CHARGE (2) — keep crouching and waiting.
        -- Hold +attack so weapon:Think() doesn't cancel the in-progress revival.
        -- Keep aiming at the ragdoll collision center
        if IsValid(rag) then
            loco:LookAt(NecroDefib.GetCorpseAimPos(rag), 2)
        end
        loco:StartAttack()

        -- Safety timeout: if we've been waiting more than twice the revive time, give up.
        if (CurTime() - bot.necroDefibStartTime) > (REVIVE_HOLD_TIME * 2) then
            return STATUS.FAILURE
        end
        return STATUS.RUNNING
    end

    local ragPos = NecroDefib.GetSpinePos(rag)
    -- Use a ground-level position for navigation so the navmesh lookup resolves
    -- to the correct area.  The spine bone sits ~10-20 units above the floor.
    local ragGroundPos = Vector(ragPos.x, ragPos.y, rag:GetPos().z)

    -- Navigate to the corpse (ground-level for pathing)
    loco:SetGoal(ragGroundPos)

    -- Aim at the ragdoll's collision center so the eye-trace in weapon Think()
    -- actually hits the ragdoll entity instead of sailing over it.
    local aimTarget = NecroDefib.GetCorpseAimPos(rag)
    loco:LookAt(aimTarget, 2)

    -- XY-only distance so spine's vertical offset doesn't inflate the threshold.
    local dist = ragGroundPos:Distance(Vector(bot:GetPos().x, bot:GetPos().y, ragGroundPos.z))

    if dist < CLOSE_THRESHOLD then
        -- Witness check: loiter near the body until the area clears
        local witnessCount = countWitnesses(bot, ragPos)
        local maxWitnesses = getMaxWitnesses(bot)
        if witnessCount > maxWitnesses then
            if not bot.necroDefiWitnessWaitStart then
                bot.necroDefiWitnessWaitStart = CurTime()
                loco:SetGoal()
                loco:SetHalt(true)
                loco.persistCrouch = true
                loco:Crouch(true)
            end

            if (CurTime() - bot.necroDefiWitnessWaitStart) > WITNESS_WAIT_TIMEOUT then
                return STATUS.FAILURE
            end

            return STATUS.RUNNING
        end
        -- Area is clear — reset wait timer
        bot.necroDefiWitnessWaitStart = nil

        -- Close enough — equip the necro defi and position for the revive.
        inventory:PauseAutoSwitch()
        bot:SetActiveWeapon(defi)
        loco:SetGoal()
        loco:SetHalt(true)
        loco:PauseAttackCompat()
        loco.persistCrouch = true
        loco:Crouch(true)
        loco:PauseRepel()

        -- Directly call BeginRevival on the weapon (server-side).
        -- This bypasses the weapon:PrimaryAttack eye-trace requirement that causes
        -- bots to loop indefinitely (eye trace rarely hits the exact ragdoll entity).
        -- weapon_ttth_necrodefi:OnRevive → AddZombie() will still fire normally.
        if IsValid(defi) and defi.BeginRevival then
            -- Guard: weapon must be idle before we start
            local defiState = defi.GetState and defi:GetState() or 0
            if defiState == 0 then
                -- Run the OnReviveStart hook (checks ttt_necro_defibrillator_revive_zombies)
                if defi.OnReviveStart and defi:OnReviveStart(target, bot) == false then
                    -- Target is a zombie and reviving zombies is disabled — skip this corpse.
                    return STATUS.FAILURE
                end
                -- Validate spawn space and headshot flag (mirrors PrimaryAttack checks)
                local spawnPoint = plyspawn and plyspawn.MakeSpawnPointSafe and plyspawn.MakeSpawnPointSafe(target, rag:GetPos())
                if defi.cvars and defi.cvars.reviveBraindead and not defi.cvars.reviveBraindead:GetBool() then
                    if CORPSE and CORPSE.WasHeadshot and CORPSE.WasHeadshot(rag) then
                        -- Braindead — can't revive; fail so we move on.
                        return STATUS.FAILURE
                    end
                end
                if not spawnPoint then
                    -- No space to spawn — bail; we'll retry next tick with a fresh corpse search.
                    return STATUS.FAILURE
                end
                -- Aim at the ragdoll collision center so the eye-trace check passes
                loco:LookAt(NecroDefib.GetCorpseAimPos(rag), 2)
                loco:StartAttack()  -- hold +attack so weapon:Think() keeps the revival alive
                defi:BeginRevival(rag, 0)
                bot.necroDefibStartTime = CurTime()
                bot.necroDefibAttemptedDirectRevive = false
            end
        end
    else
        -- Not close enough — keep walking toward the corpse.
        inventory:ResumeAutoSwitch()
        loco:ResumeAttackCompat()
        loco:SetHalt(false)
        loco:ResumeRepel()
        loco:StopAttack()
        loco.persistCrouch = false
    end

    return STATUS.RUNNING
end

function NecroDefib.OnSuccess(bot)
    if bot.necroDefibTarget and TTTBots.Match.MarkedForDefib[bot.necroDefibTarget] then
        TTTBots.Match.MarkedForDefib[bot.necroDefibTarget] = nil
    end
end

function NecroDefib.OnFailure(bot)
    -- Set a short cooldown on the corpse so we don't immediately re-target it.
    if IsValid(bot.necroDefibTarget) then
        bot.necroDefibTarget.reviveCooldown = CurTime() + 10
    end
end

function NecroDefib.OnEnd(bot)
    if bot.necroDefibTarget and TTTBots.Match.MarkedForDefib[bot.necroDefibTarget] then
        TTTBots.Match.MarkedForDefib[bot.necroDefibTarget] = nil
    end
    bot.necroDefibTarget = nil
    bot.necroDefibRag = nil
    bot.necroDefibStartTime = nil
    bot.necroDefibBehaviorStart = nil
    bot.necroDefiWitnessWaitStart = nil
    bot.necroDefibAttemptedDirectRevive = nil

    local inventory, loco = bot:BotInventory(), bot:BotLocomotor()
    if not (inventory and loco) then return end

    loco:StopAttack()
    loco:ResumeAttackCompat()
    loco.persistCrouch = false
    loco:Crouch(false)
    loco:SetHalt(false)
    loco:ResumeRepel()
    inventory:ResumeAutoSwitch()
end
