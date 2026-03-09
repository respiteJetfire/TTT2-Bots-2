--- usemeathook.lua
--- Phase 2 — Doomguy meathook usage behavior.
---
--- The Doom Super Shotgun's secondary attack fires the meathook: a grapple that
--- pulls Doomguy toward a target and sets up a close-range follow-up blast.
---
--- Bot version strategy:
---   - Attempt the hook only when conditions are favorable (range, LOS, target state).
---   - Press attack2 (secondary fire) once to launch the hook.
---   - The hook resolves quickly; the bot then immediately attempts primary fire.
---   - Safety checks prevent hooking into bad geometry or while overwhelmed.
---
--- This behavior runs in parallel with AttackTarget (it is Interruptible=true and
--- checks bot.attackTarget). It inserts itself into the Doomguy tree just below
--- DoomguyPressureAdvance and above Restore.

---@class BUseMeathook
TTTBots.Behaviors.UseMeathook = {}

local lib = TTTBots.Lib
---@class BUseMeathook
local Hook = TTTBots.Behaviors.UseMeathook
Hook.Name = "UseMeathook"
Hook.Description = "Use the Doom SSG meathook to close distance on a target."
Hook.Interruptible = true

local STATUS = TTTBots.STATUS

--- Meathook optimal range window (units).
--- Below MIN: too close — hook would overshoot. Above MAX: hook likely won't reach or LOS issues.
local HOOK_MIN_DIST = 200
local HOOK_MAX_DIST = 900

--- Minimum HP Doomguy needs to attempt a hook (don't hook while critically low).
local HOOK_MIN_HP = 35

--- Cooldown (seconds) between hook attempts to avoid button-mashing.
local HOOK_COOLDOWN = 4.0

--- Duration (seconds) that we suppress normal movement post-hook to let it play out.
local HOOK_COMMIT_DURATION = 1.2

--- Returns true if this bot is playing the Doomguy role.
---@param bot Bot
---@return boolean
local function isDoomguy(bot)
    if not bot then return false end
    local roleStr = bot.GetRoleStringRaw and bot:GetRoleStringRaw() or ""
    return (roleStr == "doomguy" or roleStr == "doomguy_blue" or roleStr == "doomguy_red")
end

--- Returns true if the bot is currently holding the Super Shotgun.
---@param bot Bot
---@return boolean
local function holdingSSG(bot)
    local inv = bot:BotInventory()
    if not inv then return false end
    local wep = inv:GetHeldWeaponInfo()
    return wep and wep.class == "weapon_dredux_de_supershotgun"
end

--- Rough geometry safety check: trace from bot eye to target.
--- Returns true if the path is not obstructed by solid world geometry that would
--- trap or damage Doomguy (e.g. short ceilings, inside walls).
---@param bot Bot
---@param target Player
---@return boolean safe
local function hookPathSafe(bot, target)
    -- Basic: can we see the target? If so, path is clear enough.
    if not bot:Visible(target) then return false end

    -- Check that neither entity is clipped into a wall.
    local botPos    = bot:EyePos()
    local targetPos = target:EyePos()
    local tr = util.TraceLine({
        start  = botPos,
        endpos = targetPos,
        filter = { bot, target },
        mask   = MASK_SOLID_BRUSHONLY,
    })

    -- If the trace hit something before 80% of the way, path is obstructed.
    if tr.Fraction < 0.8 then return false end

    return true
end

--- Assess whether hooking right now is a good idea.
---@param bot Bot
---@param target Player
---@return boolean shouldHook
local function shouldAttemptHook(bot, target)
    if not (IsValid(target) and lib.IsPlayerAlive(target)) then return false end

    local botPos    = bot:GetPos()
    local targetPos = target:GetPos()
    local dist      = botPos:Distance(targetPos)

    -- Range check.
    if dist < HOOK_MIN_DIST or dist > HOOK_MAX_DIST then return false end

    -- Health check.
    if bot:Health() < HOOK_MIN_HP then return false end

    -- Geometry safety.
    if not hookPathSafe(bot, target) then return false end

    -- Don't hook if we are overwhelmed (multiple enemies nearby at close range).
    local closeEnemies = 0
    for _, ply in ipairs(player.GetAll()) do
        if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end
        if ply == bot or TTTBots.Roles.IsAllies(bot, ply) then continue end
        if botPos:Distance(ply:GetPos()) < 400 then
            closeEnemies = closeEnemies + 1
        end
    end
    if closeEnemies >= 3 then return false end

    return true
end

--- Validate: Doomguy only, must have attack target, SSG must be equipped, cooldown must have expired.
---@param bot Bot
---@return boolean
function Hook.Validate(bot)
    if not isDoomguy(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not IsValid(bot.attackTarget) then return false end
    if not holdingSSG(bot) then return false end

    local state = TTTBots.Behaviors.GetState(bot, "UseMeathook")
    local lastHook = state.lastHookTime or 0
    if CurTime() - lastHook < HOOK_COOLDOWN then return false end

    return shouldAttemptHook(bot, bot.attackTarget)
end

--- Called when the behavior starts.
---@param bot Bot
---@return BStatus
function Hook.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "UseMeathook")
    state.lastHookTime    = CurTime()
    state.hookCommitUntil = CurTime() + HOOK_COMMIT_DURATION
    state.hookFired       = false
    return STATUS.RUNNING
end

--- Runs each tick during the hook commit window.
---@param bot Bot
---@return BStatus
function Hook.OnRunning(bot)
    if not isDoomguy(bot) then return STATUS.FAILURE end
    if not IsValid(bot.attackTarget) then return STATUS.FAILURE end

    local state   = TTTBots.Behaviors.GetState(bot, "UseMeathook")
    local timeNow = CurTime()

    -- Commit window expired — let AttackTarget resume.
    if timeNow > state.hookCommitUntil then
        return STATUS.SUCCESS
    end

    local loco = bot:BotLocomotor() ---@type CLocomotor
    if not loco then return STATUS.FAILURE end

    local target    = bot.attackTarget
    local targetPos = target:EyePos()

    -- Look at the target so the hook traces correctly.
    loco:LookAt(targetPos)

    if not state.hookFired then
        -- Fire the meathook (secondary attack = attack2).
        loco:StartAttack2()
        state.hookFired = true
    else
        -- After hook fires: stop the alt-fire input and let the hook pull us.
        loco:StopAttack2()
        -- Stop all movement so the hook physics can pull Doomguy properly.
        loco:StopMoving()
        loco:SetForceForward(false)
        loco:SetForceBackward(false)
    end

    return STATUS.RUNNING
end

--- Called on success (commit window expired, hook resolved).
--- Fire primary attack only if the attack target is still valid.
---@param bot Bot
function Hook.OnSuccess(bot)
    if not IsValid(bot.attackTarget) then return end
    local loco = bot:BotLocomotor()
    if loco then
        loco:StartAttack()
    end
end

--- Called on failure.
---@param bot Bot
function Hook.OnFailure(bot)
    local loco = bot:BotLocomotor()
    if loco then
        loco:StopAttack2()
    end
end

--- Called when behavior ends.
---@param bot Bot
function Hook.OnEnd(bot)
    local loco = bot:BotLocomotor()
    if loco then
        loco:StopAttack2()
    end
    TTTBots.Behaviors.ClearState(bot, "UseMeathook")
end
