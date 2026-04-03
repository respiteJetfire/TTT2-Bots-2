--- hiddenstunnade.lua
--- Hidden stun grenade behavior.
--- The Hidden can throw weapon_ttt_hd_nade (a stun grenade) that deals 30 blast damage
--- and applies a motion blur stun effect to all players in a 256-unit radius.
--- The grenade respawns after a 30-second configurable delay (ttt2_hdn_nade_delay).
---
--- Tactical scenarios:
---   1. **Escape:** Being chased/shot at — throw at own position to disorient pursuers.
---   2. **Pre-kill:** Before engaging a group — throw to stun then rush in with knife.
---   3. **Cover retreat:** After a knife kill with witnesses approaching.
---   4. **Setup:** About to engage a target — stun then knife for easy kill.

---@class BHiddenStunNade
TTTBots.Behaviors.HiddenStunNade = {}

local lib = TTTBots.Lib
---@class BHiddenStunNade
local StunNade = TTTBots.Behaviors.HiddenStunNade
StunNade.Name = "HiddenStunNade"
StunNade.Description = "Throw stun grenade for area denial, escape, or pre-kill distraction."
StunNade.Interruptible = true

local STATUS = TTTBots.STATUS
local HD_NADE_CLASS = "weapon_ttt_hd_nade"
local HD_KNIFE_CLASS = "weapon_ttt_hd_knife"
local MIN_THREATS = 1    -- minimum nearby threats to consider throwing
local THREAT_RADIUS = 700 -- units; scan radius for nearby threats

--- Returns true if this bot is the Hidden in stalker mode.
---@param bot Bot
---@return boolean
local function isHiddenStalker(bot)
    if not bot then return false end
    local roleStr = bot.GetRoleStringRaw and bot:GetRoleStringRaw() or ""
    if roleStr ~= "hidden" then return false end
    return bot:GetNWBool("ttt2_hd_stalker_mode", false)
end

--- Returns true if the bot has the stun grenade weapon.
--- The nade is removed from inventory when thrown and re-given after the cooldown timer.
---@param bot Bot
---@return boolean
local function hasStunNade(bot)
    return bot:HasWeapon(HD_NADE_CLASS)
end

--- Count nearby non-ally threats.
---@param bot Bot
---@return number threatCount
---@return Player? closestThreat
local function countNearbyThreats(bot)
    local botPos = bot:GetPos()
    local threatCount = 0
    local closestDist = math.huge
    local closestThreat = nil

    for _, ply in ipairs(player.GetAll()) do
        if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end
        if ply == bot then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then continue end

        local dist = botPos:Distance(ply:GetPos())
        if dist <= THREAT_RADIUS then
            threatCount = threatCount + 1
            if dist < closestDist then
                closestDist = dist
                closestThreat = ply
            end
        end
    end

    return threatCount, closestThreat
end

--- Determine if the bot is currently being attacked/chased.
---@param bot Bot
---@return boolean
local function isUnderAttack(bot)
    local lastDmgTime = bot._lastDamageTime or 0
    return (CurTime() - lastDmgTime) < 3
end

--- Determine the best throw position for the stun nade.
---@param bot Bot
---@param scenario string "escape"|"prekill"|"cover"|"setup"
---@param closestThreat Player?
---@return Vector throwPos
local function getThrowPosition(bot, scenario, closestThreat)
    local botPos = bot:GetPos()

    if scenario == "escape" then
        -- Throw at our own feet to disorient pursuers
        return botPos + Vector(0, 0, 20)
    elseif scenario == "prekill" and IsValid(closestThreat) then
        -- Throw at the group of targets
        return closestThreat:GetPos() + Vector(0, 0, 40)
    elseif scenario == "cover" and IsValid(closestThreat) then
        -- Throw between self and approaching witnesses
        local midpoint = (botPos + closestThreat:GetPos()) / 2
        return midpoint + Vector(0, 0, 40)
    elseif scenario == "setup" and IsValid(closestThreat) then
        -- Throw directly at target for stun-then-knife combo
        return closestThreat:GetPos() + Vector(0, 0, 30)
    end

    return botPos + bot:GetAimVector() * 300 + Vector(0, 0, 40)
end

--- Validate: only run as Hidden in stalker mode, must have stun nade, threats nearby.
---@param bot Bot
---@return boolean
function StunNade.Validate(bot)
    if not isHiddenStalker(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not hasStunNade(bot) then return false end

    -- Need threats nearby to justify throwing
    local threatCount, _ = countNearbyThreats(bot)
    if threatCount < MIN_THREATS then return false end

    -- Determine scenario
    local underAttack = isUnderAttack(bot)
    local lowHP = bot:Health() < 50

    -- Only throw in tactical situations:
    -- 1. Under attack (escape)
    -- 2. Multiple threats nearby (pre-kill distraction)
    -- 3. Low HP with threats (desperate escape)
    if underAttack or lowHP or threatCount >= 2 then
        return true
    end

    -- Random chance for tactical throw when 1 threat is nearby (setup for knife kill)
    -- Throttle: only roll once every 2 seconds per bot to avoid near-instant triggering
    local lastRoll = bot._hdStunNadeLastRoll or 0
    if CurTime() - lastRoll < 2.0 then return false end
    bot._hdStunNadeLastRoll = CurTime()

    return math.random(1, 10) == 1
end

--- Called when the behavior starts.
---@param bot Bot
---@return BStatus
function StunNade.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "HiddenStunNade")
    state.throwPhase = "equip"  -- phases: equip -> aim -> throw -> switchback -> done
    state.phaseStart = CurTime()

    -- Determine scenario
    local underAttack = isUnderAttack(bot)
    local threatCount, closestThreat = countNearbyThreats(bot)

    if underAttack then
        state.scenario = "escape"
    elseif threatCount >= 2 then
        state.scenario = "prekill"
    elseif threatCount == 1 then
        state.scenario = "setup"
    else
        state.scenario = "cover"
    end
    state.closestThreat = closestThreat

    return STATUS.RUNNING
end

--- Called each tick while running.
---@param bot Bot
---@return BStatus
function StunNade.OnRunning(bot)
    if not isHiddenStalker(bot) then return STATUS.FAILURE end
    if not TTTBots.Match.IsRoundActive() then return STATUS.FAILURE end

    local state = TTTBots.Behaviors.GetState(bot, "HiddenStunNade")
    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    local phase = state.throwPhase
    local elapsed = CurTime() - (state.phaseStart or CurTime())

    if phase == "equip" then
        -- Equip the stun grenade weapon
        inv:PauseAutoSwitch()
        if not hasStunNade(bot) then
            return STATUS.FAILURE
        end
        bot:SelectWeapon(HD_NADE_CLASS)

        state.throwPhase = "aim"
        state.phaseStart = CurTime()
        return STATUS.RUNNING

    elseif phase == "aim" then
        -- Aim at throw position
        local throwPos = getThrowPosition(bot, state.scenario, state.closestThreat)
        loco:LookAt(throwPos)

        -- Brief delay to aim (0.3s)
        if elapsed >= 0.3 then
            state.throwPhase = "throw"
            state.phaseStart = CurTime()
        end
        return STATUS.RUNNING

    elseif phase == "throw" then
        -- Fire primary attack (M1) — stun nade uses standard grenade throw
        loco:StartAttack()

        -- Brief hold of attack (0.2s)
        if elapsed >= 0.2 then
            loco:StopAttack()

            state.throwPhase = "switchback"
            state.phaseStart = CurTime()
        end
        return STATUS.RUNNING

    elseif phase == "switchback" then
        -- Switch back to the knife (if available) after throwing
        loco:StopAttack()
        if bot:HasWeapon(HD_KNIFE_CLASS) then
            bot:SelectWeapon(HD_KNIFE_CLASS)
        end

        -- Brief delay before completing (0.3s)
        if elapsed >= 0.3 then
            state.throwPhase = "done"
            state.phaseStart = CurTime()
        end
        return STATUS.RUNNING

    elseif phase == "done" then
        -- Cleanup and return success
        inv:ResumeAutoSwitch()
        return STATUS.SUCCESS
    end

    return STATUS.FAILURE
end

--- Called on success.
---@param bot Bot
function StunNade.OnSuccess(bot)
end

--- Called on failure.
---@param bot Bot
function StunNade.OnFailure(bot)
end

--- Called when the behavior ends (success or failure).
---@param bot Bot
function StunNade.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "HiddenStunNade")
    local loco = bot:BotLocomotor()
    if loco then
        loco:StopAttack()
        loco:StopAttack2()
    end
    local inv = bot:BotInventory()
    if inv then
        inv:ResumeAutoSwitch()
    end
end
