

---@class BDefibPlayer
TTTBots.Behaviors.DefibPlayer = {}

local lib = TTTBots.Lib

---@class BDefibPlayer
local DefibPlayer = TTTBots.Behaviors.DefibPlayer
DefibPlayer.Name = "DefibPlayer"
DefibPlayer.Description = "Use the defibrillator on a corpse."
DefibPlayer.Interruptible = true
DefibPlayer.WeaponClasses = { "weapon_ttt_defibrillator", "weapon_ttt2_medic_defibrillator" }


local STATUS = TTTBots.STATUS

local function printf(...) print(string.format(...)) end

---Get the closest revivable corpse to our bot
---@param bot any
---@param allyOnly boolean
---@return Player? closest
---@return any? ragdoll
function DefibPlayer.GetCorpse(bot, allyOnly)
    local closest, rag = TTTBots.Lib.GetClosestRevivable(bot, allyOnly, true)
    -- printf("closest: %s, rag: %s", tostring(closest), tostring(rag))
    if not closest then return end

    -- local canSee = lib.CanSeeArc(bot, rag:GetPos() + Vector(0, 0, 16), 120)
    -- print(canSee)
    -- if canSee then
    return closest, rag
    -- end
end

function DefibPlayer.HasDefibPlayer(bot)
    for i, class in pairs(DefibPlayer.WeaponClasses) do
        if bot:HasWeapon(class) then return true end
    end

    return false
end

---Get the defib weapon, if the bot has one.
---@param bot Bot
---@return Weapon?
function DefibPlayer.GetDefibPlayer(bot)
    for i, class in pairs(DefibPlayer.WeaponClasses) do
        local wep = bot:GetWeapon(class)
        if IsValid(wep) then return wep end
    end
end

local function failFunc(bot, target)
    target.reviveCooldown = CurTime() + 30
    local defib = DefibPlayer.GetDefibPlayer(bot)
    if not (defib and IsValid(defib)) then return end

    defib:StopSound("hum")
    defib:PlaySound("beep")
end

local function startFunc(bot)
    local defib = DefibPlayer.GetDefibPlayer(bot)
    if not (defib and IsValid(defib)) then return end

    defib:PlaySound("hum")
end

local function successFunc(bot)
    local defib = DefibPlayer.GetDefibPlayer(bot)
    local botRole = bot:GetSubRole()
    if not (defib and IsValid(defib)) then return end

    defib:StopSound("hum")
    defib:PlaySound("zap")

    timer.Simple(1, function()
        if not (defib and IsValid(defib)) then return end
        if botRole == ROLE_MEDIC or botRole == ROLE_DOCTOR then return end
        defib:Remove()
    end)
end
---Revives a player from the dead, assuming the target is alive
---@param bot Bot
---@param target Player
function DefibPlayer.FullDefibPlayer(bot, target)
    target:Revive(
        0,                                    -- delay number=3
        function() successFunc(bot) end,      -- OnRevive function?
        nil,                                  -- DoCheck function?
        true,                                 -- needsCorpse
        REVIVAL_BLOCK_NONE,                   -- blockRound number=REVIVAL_BLOCK_NONE
        function() failFunc(bot, target) end, -- OnFail function?
        nil,                                  -- spawnPos Vector?
        nil                                   -- spawnAng Angle?
    )
end

function DefibPlayer.ValidateCorpse(bot, corpse)
    return lib.IsValidBody(corpse or bot.defibRag)
end

function DefibPlayer.Validate(bot)
    if not TTTBots.Lib.IsTTT2() then return false end -- This is TTT2-specific.
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.preventDefibPlayer then return false end         -- just an extra feature to prevent defibbing

    -- cant defib without defib
    local hasDefibPlayer = DefibPlayer.HasDefibPlayer(bot)
    if not hasDefibPlayer then return false end

    -- re-use existing
    local hasCorpse = DefibPlayer.ValidateCorpse(bot, bot.defibRag)
    if hasCorpse then return true end

    -- get new target
    local role = bot:GetSubRole()
    local corpse, rag
    if role == ROLE_DOCTOR then
        corpse, rag = DefibPlayer.GetCorpse(bot, true)
    elseif role == ROLE_MEDIC then
        corpse, rag = DefibPlayer.GetCorpse(bot, false)
    else
        corpse, rag = DefibPlayer.GetCorpse(bot, true)
    end

    if not corpse then return false end

    -- one last valid check
    local cValid = DefibPlayer.ValidateCorpse(bot, rag)
    if not cValid then return false end

    return true
end

function DefibPlayer.OnStart(bot)
    local role = bot:GetSubRole()
    bot.defibBehaviorStart = CurTime()
    if role == ROLE_DOCTOR then
        bot.defibTarget, bot.defibRag = DefibPlayer.GetCorpse(bot, true)
    elseif role == ROLE_MEDIC then
        bot.defibTarget, bot.defibRag = DefibPlayer.GetCorpse(bot, false)
    else
        bot.defibTarget, bot.defibRag = DefibPlayer.GetCorpse(bot, true)
    end

    -- Announce revive attempt
    if bot.defibTarget and IsValid(bot.defibTarget) then
        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("RevivingPlayer", { player = bot.defibTarget:Nick() }, false, 0)
        end
    end

    return STATUS.RUNNING
end

function DefibPlayer.GetSpinePos(rag)
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
function DefibPlayer.GetCorpseAimPos(rag)
    if not IsValid(rag) then return rag:GetPos() end
    return rag:LocalToWorld(rag:OBBCenter())
end

---@class Bot
---@field defibTarget Player? The PLAYER of the defibRag we found
---@field defibRag Entity? The ragdoll we found to defib
---@field defibStartTime number? When we started defibbing our defibTarget

---@param bot Bot
function DefibPlayer.OnRunning(bot)
    local inventory, loco = bot:BotInventory(), bot:BotLocomotor()
    local botRole = bot:GetSubRole()
    if not (inventory and loco) then return STATUS.FAILURE end

    local defib = DefibPlayer.GetDefibPlayer(bot)
    local target = bot.defibTarget
    local rag = bot.defibRag
    -- Timeout: give up if running too long without completing
    if bot.defibBehaviorStart and (CurTime() - bot.defibBehaviorStart) > 45 then
        return STATUS.FAILURE
    end
    if not (target and rag and defib) then return STATUS.FAILURE end
    if not (IsValid(target) and IsValid(rag) and IsValid(defib)) then return STATUS.FAILURE end
    local ragPos = DefibPlayer.GetSpinePos(rag)
    -- Use a ground-level position for navigation so the navmesh lookup resolves
    -- to the correct area.  The spine bone sits above the floor and can map to a
    -- neighbouring nav area, stalling the path follower.
    local ragGroundPos = Vector(ragPos.x, ragPos.y, rag:GetPos().z)

    loco:SetGoal(ragGroundPos)
    -- Aim at the ragdoll's collision center so eye-trace hits the entity
    local aimTarget = DefibPlayer.GetCorpseAimPos(rag)
    loco:LookAt(aimTarget)

    -- Use XY distance so the spine's vertical offset doesn't shrink the
    -- effective threshold and prevent the bot from reaching the corpse.
    local dist = ragGroundPos:Distance(Vector(bot:GetPos().x, bot:GetPos().y, ragGroundPos.z))

    -- Use a larger threshold to approach, and once we've started the hold timer
    -- don't cancel it just because of minor locomotor drift (hysteresis).
    local closeThreshold = 120
    local cancelThreshold = 250  -- only cancel if we've drifted *far* away
    local alreadyStarted = bot.defibStartTime ~= nil

    if dist < closeThreshold or (alreadyStarted and dist < cancelThreshold) then
        inventory:PauseAutoSwitch()
        bot:SetActiveWeapon(defib)
        loco:SetGoal() -- reset goal to stop moving
        loco:SetHalt(true)
        loco:PauseAttackCompat()
        loco.persistCrouch = true
        loco:Crouch(true)
        loco:PauseRepel()
        -- Aim at the ragdoll's collision center so the eye-trace check passes
        local lookTarget = DefibPlayer.GetCorpseAimPos(rag)
        loco:LookAt(lookTarget, 2)
        loco:StartAttack()
        if bot.defibStartTime == nil then
            bot.defibStartTime = CurTime()
            startFunc(bot)
            -- Try to use the weapon's BeginRevival if available (TTT2 base defib)
            if IsValid(defib) and defib.BeginRevival and defib.GetState then
                local defiState = defib:GetState()
                if defiState == 0 then -- DEFI_IDLE
                    defib:BeginRevival(rag, 0)
                end
            end
        end
        local holdTime = (botRole == ROLE_DOCTOR and 5 or botRole == ROLE_MEDIC and 15 or 5)
        if bot.defibStartTime + holdTime < CurTime() then
            -- Check if the weapon's pipeline already handled it
            if IsValid(defib) and defib.GetState and defib:GetState() == 1 then
                -- DEFI_BUSY: weapon pipeline is active, let FinishRevival handle it
                if defib.FinishRevival then
                    defib:FinishRevival(target, bot)
                end
                return STATUS.SUCCESS
            end
            -- Weapon pipeline was cancelled (eye-trace miss) or weapon doesn't
            -- support BeginRevival — fallback: directly fire the revive and
            -- reduce the defib's ammo charge by 1.
            if IsValid(target) and not target:IsTerror() and IsValid(rag) and lib.IsValidBody(rag) then
                target:Revive(
                    0,
                    function(p)
                        if IsValid(defib) and defib.OnRevive then
                            defib:OnRevive(p, bot)
                        end
                        successFunc(bot)
                    end,
                    function(p)
                        if p:IsTerror() then return false end
                        return true
                    end,
                    true,
                    REVIVAL_BLOCK_NONE,
                    function() failFunc(bot, target) end
                )
                -- Consume one ammo charge from the defib
                if IsValid(defib) then
                    if defib.TakePrimaryAmmo then
                        defib:TakePrimaryAmmo(1)
                    end
                    if defib.CanPrimaryAttack and not defib:CanPrimaryAttack() then
                        defib:Remove()
                    end
                end
            end
            return STATUS.SUCCESS
        end
    else
        -- Only fully reset if we've moved genuinely far from the target
        if not alreadyStarted then
            inventory:ResumeAutoSwitch()
            loco:ResumeAttackCompat()
            loco:SetHalt(false)
            loco:ResumeRepel()
            loco:StopAttack()
            loco.persistCrouch = false
        end
        bot.defibStartTime = nil
    end

    return STATUS.RUNNING
end

function DefibPlayer.OnSuccess(bot)
end

function DefibPlayer.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function DefibPlayer.OnEnd(bot)
    bot.defibTarget, bot.defibRag = nil, nil
    bot.defibStartTime = nil
    bot.defibBehaviorStart = nil
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
