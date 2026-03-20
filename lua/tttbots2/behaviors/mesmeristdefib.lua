--- mesmeristdefib.lua
--- Dedicated defib behavior for the Mesmerist's `weapon_ttt_mesdefi`.
--- The Mesmerist revives corpses as Thralls (traitor-aligned converts).
---
--- Priority logic:
---   1. Corpses the bot personally killed (tttbots_killedBy tag) are
---      favoured — the bot already knows the location and team is rewarded
---      for clean kills that can immediately be converted.
---   2. Any other revivable corpse within range is used as a fallback.
---
--- Witness safety:
---   Before beginning the hold-attack sequence the bot checks for non-allied
---   witnesses at the corpse.  If any are present it loiters at or near the
---   body (crouching behind cover if possible) until the area clears, or
---   times out and abandons the target.

---@class BMesmeristDefib
TTTBots.Behaviors.MesmeristDefib = {}

local lib = TTTBots.Lib

---@class BMesmeristDefib
local MesDefi = TTTBots.Behaviors.MesmeristDefib
MesDefi.Name = "MesmeristDefib"
MesDefi.Description = "Use the Mesmerist's Defib to revive a corpse as a Thrall."
MesDefi.Interruptible = true
MesDefi.WeaponClass = "weapon_ttt_mesdefi"

local STATUS = TTTBots.STATUS

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

--- Search radius for corpses.
local SEARCH_RANGE = 3000
--- Distance at which we start the hold-attack.
local CLOSE_THRESHOLD = 80
--- If we have started the timer, don't cancel until we drift this far.
local CANCEL_THRESHOLD = 200
--- Overall behavior timeout (seconds).
local BEHAVIOR_TIMEOUT = 50
--- How long to loiter near the corpse waiting for witnesses to clear (seconds).
local WITNESS_WAIT_TIMEOUT = 12
--- How close to the corpse we must be to start waiting for witnesses.
local WITNESS_WAIT_RANGE = 300
--- Max witnesses allowed before waiting.
local MAX_WITNESSES = 0
--- How long the bot holds attack before assuming success (matches ttt2_mesdefi_revive_time default).
local REVIVE_HOLD_TIME = 3.5

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function hasMesDefi(bot)
    return bot:HasWeapon(MesDefi.WeaponClass)
end

local function getMesDefi(bot)
    local wep = bot:GetWeapon(MesDefi.WeaponClass)
    if IsValid(wep) then return wep end
    return nil
end

--- Count non-allied living witnesses who can see `pos`.
---@param bot Bot
---@param pos Vector
---@return number
local function countWitnesses(bot, pos)
    local nonAllies = TTTBots.Roles.GetNonAllies(bot)
    local witnesses = lib.GetAllWitnessesBasic(pos, nonAllies, bot)
    return table.Count(witnesses)
end

--- Get spine world position from a ragdoll.
---@param rag Entity
---@return Vector
local function getSpinePos(rag)
    local default = rag:GetPos()
    local spine = rag:LookupBone("ValveBiped.Bip01_Spine")
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
local function getCorpseAimPos(rag)
    if not IsValid(rag) then return rag:GetPos() end
    return rag:LocalToWorld(rag:OBBCenter())
end

--- Find the best corpse to revive.
--- Prefers corpses that this bot personally killed (tttbots_killedBy),
--- then falls back to the closest other revivable corpse.
---@param bot Bot
---@return Player? target
---@return Entity? ragdoll
local function findBestCorpse(bot)
    local corpses = TTTBots.Lib.GetRevivableCorpses()
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

        -- Skip if another bot is already claiming this body
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

    -- Prefer own kills; fall back to nearest other corpse.
    if bestKilledTarget then
        return bestKilledTarget, bestKilledRag
    end
    return bestFallbackTarget, bestFallbackRag
end

-- ---------------------------------------------------------------------------
-- Behavior interface
-- ---------------------------------------------------------------------------

function MesDefi.Validate(bot)
    if not TTTBots.Lib.IsTTT2() then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.preventMesDefi then return false end

    -- Must be the mesmerist (subrole check; guard against nil ROLE_MESMERIST)
    if ROLE_MESMERIST and bot:GetSubRole() ~= ROLE_MESMERIST then return false end

    if not hasMesDefi(bot) then return false end

    -- Check clip
    local wep = getMesDefi(bot)
    if wep and wep.Clip1 and wep:Clip1() <= 0 then return false end

    -- Re-use existing valid target
    if bot.mesDefiTarget and bot.mesDefiRag then
        if lib.IsValidBody(bot.mesDefiRag) then return true end
        -- Target gone — clear and re-search below
        bot.mesDefiTarget = nil
        bot.mesDefiRag = nil
    end

    -- Find a new target
    local target, rag = findBestCorpse(bot)
    if not (target and rag) then return false end

    bot.mesDefiTarget = target
    bot.mesDefiRag = rag

    return true
end

function MesDefi.OnStart(bot)
    bot.mesDefiBehaviorStart = CurTime()
    bot.mesDefiWitnessWaitStart = nil

    if not (bot.mesDefiTarget and bot.mesDefiRag) then
        bot.mesDefiTarget, bot.mesDefiRag = findBestCorpse(bot)
    end

    if not (bot.mesDefiTarget and bot.mesDefiRag) then
        return STATUS.FAILURE
    end

    -- Claim the body so other bots don't also go for it
    if not TTTBots.Match.MarkedForDefib[bot.mesDefiTarget] then
        TTTBots.Match.MarkedForDefib[bot.mesDefiTarget] = bot
    end

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("RevivingPlayer", { player = bot.mesDefiTarget:Nick() }, true)
    end

    return STATUS.RUNNING
end

---@param bot Bot
function MesDefi.OnRunning(bot)
    local inventory, loco = bot:BotInventory(), bot:BotLocomotor()
    if not (inventory and loco) then return STATUS.FAILURE end

    if not hasMesDefi(bot) then return STATUS.FAILURE end
    local wep = getMesDefi(bot)
    if not IsValid(wep) then return STATUS.FAILURE end
    if wep.Clip1 and wep:Clip1() <= 0 then return STATUS.FAILURE end

    -- Overall timeout guard
    if bot.mesDefiBehaviorStart and (CurTime() - bot.mesDefiBehaviorStart) > BEHAVIOR_TIMEOUT then
        return STATUS.FAILURE
    end

    local target = bot.mesDefiTarget
    local rag    = bot.mesDefiRag
    if not (target and rag) then return STATUS.FAILURE end
    if not (IsValid(target) and IsValid(rag)) then return STATUS.FAILURE end
    if not lib.IsValidBody(rag) then return STATUS.FAILURE end

    local ragPos       = getSpinePos(rag)
    local ragGroundPos = Vector(ragPos.x, ragPos.y, rag:GetPos().z)

    -- Navigate toward the corpse
    loco:SetGoal(ragGroundPos)
    -- Aim at the ragdoll's collision center so eye-trace hits the entity
    loco:LookAt(getCorpseAimPos(rag))

    -- XY-only distance so vertical offset doesn't fool the threshold
    local botXY = Vector(bot:GetPos().x, bot:GetPos().y, ragGroundPos.z)
    local dist = ragGroundPos:Distance(botXY)

    local alreadyStarted = bot.mesDefiStartTime ~= nil

    -- ── Within activation range ────────────────────────────────────────────
    if dist < CLOSE_THRESHOLD or (alreadyStarted and dist < CANCEL_THRESHOLD) then

        -- Witness check: wait for the area to clear before committing
        if not alreadyStarted then
            local witnessCount = countWitnesses(bot, ragPos)
            if witnessCount > MAX_WITNESSES then
                -- Start (or continue) witness-wait timer
                if not bot.mesDefiWitnessWaitStart then
                    bot.mesDefiWitnessWaitStart = CurTime()
                    -- Crouch in place to look natural while waiting
                    loco:SetGoal()
                    loco:SetHalt(true)
                    loco.persistCrouch = true
                    loco:Crouch(true)
                end

                -- Timeout: give up if the area hasn't cleared
                if (CurTime() - bot.mesDefiWitnessWaitStart) > WITNESS_WAIT_TIMEOUT then
                    return STATUS.FAILURE
                end

                -- Still waiting — re-check next tick
                return STATUS.RUNNING
            end
            -- Area is clear — reset the wait timer
            bot.mesDefiWitnessWaitStart = nil
        end

        -- ── Commit to the revive ───────────────────────────────────────────
        inventory:PauseAutoSwitch()
        bot:SetActiveWeapon(wep)
        loco:SetGoal()
        loco:SetHalt(true)
        loco:PauseAttackCompat()
        loco.persistCrouch = true
        loco:Crouch(true)
        loco:PauseRepel()
        -- Aim at the ragdoll's collision center so the eye-trace check passes
        loco:LookAt(getCorpseAimPos(rag), 2)
        loco:StartAttack()

        if bot.mesDefiStartTime == nil then
            bot.mesDefiStartTime = CurTime()
            -- Try to use the weapon's BeginRevival if available
            if IsValid(wep) and wep.BeginRevival and wep.GetState then
                local wepState = wep:GetState()
                if wepState == 0 then -- DEFI_IDLE
                    wep:BeginRevival(rag, 0)
                end
            end
        end

        -- Wait for the full revive hold duration
        if bot.mesDefiStartTime + REVIVE_HOLD_TIME < CurTime() then
            loco:StopAttack()
            -- Check if the weapon's pipeline handled the revive
            if IsValid(wep) and wep.GetState then
                local wepState = wep:GetState()
                if wepState == 1 then
                    -- DEFI_BUSY: weapon pipeline still active, let it finish
                    if wep.FinishRevival then
                        wep:FinishRevival()
                    end
                    return STATUS.SUCCESS
                end
            end
            -- Weapon pipeline was cancelled (eye-trace miss) or doesn't
            -- support BeginRevival — fallback: directly fire the revive and
            -- reduce the defib's ammo charge by 1.
            if IsValid(target) and not target:IsTerror() and IsValid(rag) and lib.IsValidBody(rag) then
                local owner = bot
                local mes_team = owner:GetTeam()
                target:Revive(
                    0,
                    function(p)
                        if ROLE_THRALL then
                            if GetConVar("ttt2_thr_team_inherit") and GetConVar("ttt2_thr_team_inherit"):GetBool() then
                                p:SetRole(ROLE_THRALL, mes_team)
                            else
                                p:SetRole(ROLE_THRALL, TEAM_TRAITOR)
                            end
                        end
                        p:ResetConfirmPlayer()
                        if events and events.Trigger and EVENT_MES_DEFIB then
                            events.Trigger(EVENT_MES_DEFIB, owner, p)
                        end
                        SendFullStateUpdate()
                    end,
                    function(p)
                        if p:IsTerror() then return false end
                        return true
                    end,
                    true,
                    REVIVAL_BLOCK_NONE
                )
                target:SendRevivalReason("revived_by_mesmerist", { name = bot:Nick() })
                -- Consume one ammo charge from the defib
                if IsValid(wep) then
                    wep:SetClip1(wep:Clip1() - 1)
                    if wep:Clip1() < 1 then
                        if wep.SafeRemove then
                            wep:SafeRemove()
                        else
                            wep:Remove()
                        end
                    end
                end
            end
            return STATUS.SUCCESS
        end

    -- ── Not yet close enough ──────────────────────────────────────────────
    else
        -- Only reset locomotor state if we haven't started the hold timer
        if not alreadyStarted then
            inventory:ResumeAutoSwitch()
            loco:ResumeAttackCompat()
            loco:SetHalt(false)
            loco:ResumeRepel()
            loco:StopAttack()
            loco.persistCrouch = false
        end
        bot.mesDefiStartTime = nil
        bot.mesDefiWitnessWaitStart = nil
    end

    return STATUS.RUNNING
end

function MesDefi.OnSuccess(bot)
    if bot.mesDefiTarget and TTTBots.Match.MarkedForDefib[bot.mesDefiTarget] then
        TTTBots.Match.MarkedForDefib[bot.mesDefiTarget] = nil
    end
end

function MesDefi.OnFailure(bot)
end

---@param bot Bot
function MesDefi.OnEnd(bot)
    if bot.mesDefiTarget and TTTBots.Match.MarkedForDefib[bot.mesDefiTarget] then
        TTTBots.Match.MarkedForDefib[bot.mesDefiTarget] = nil
    end

    bot.mesDefiTarget          = nil
    bot.mesDefiRag             = nil
    bot.mesDefiStartTime       = nil
    bot.mesDefiBehaviorStart   = nil
    bot.mesDefiWitnessWaitStart = nil

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
