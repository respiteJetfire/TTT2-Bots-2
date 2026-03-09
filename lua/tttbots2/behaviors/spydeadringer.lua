--- spydeadringer.lua
--- SpyDeadRinger Behavior — Spy uses the Dead Ringer item to fake their death.
--- Phase 4 (P4-4): The spy equips and activates the Dead Ringer when under threat,
--- then relocates while "dead" to continue gathering intel undetected.

local lib = TTTBots.Lib
local STATUS = TTTBots.STATUS

---@class SpyDeadRinger
TTTBots.Behaviors.SpyDeadRinger = {}

---@class SpyDeadRinger
local SpyDeadRinger = TTTBots.Behaviors.SpyDeadRinger
SpyDeadRinger.Name = "SpyDeadRinger"
SpyDeadRinger.Description = "Spy uses the Dead Ringer to fake death and escape."
SpyDeadRinger.Interruptible = false

--- The Dead Ringer should only be used when the spy is under imminent threat.
--- Must be a spy, have the dead ringer weapon, and be in danger.
function SpyDeadRinger.Validate(bot)
    -- Must have perception system
    if not TTTBots.Perception then return false end

    -- Must be a spy with intact or blown cover (both can use it)
    if not TTTBots.Perception.IsSpy(bot) then return false end

    -- Must be alive
    if not lib.IsPlayerAlive(bot) then return false end

    local state = TTTBots.Behaviors.GetState(bot, "SpyDeadRinger")

    -- Only use once per round
    if state.usedThisRound then return false end

    -- Must have the dead ringer weapon
    local hasDeadRinger = false
    local weps = bot:GetWeapons()
    for _, wep in ipairs(weps) do
        if IsValid(wep) and wep:GetClass() == "weapon_ttt_deadringer" then
            hasDeadRinger = true
            break
        end
    end
    if not hasDeadRinger then return false end

    -- Only trigger if spy is under threat:
    -- 1. Cover is blown and a traitor is nearby
    -- 2. Being attacked (low health)
    -- 3. Someone is aiming at the spy
    local coverState = TTTBots.Perception.GetCoverState(bot)
    local isBlown = coverState and coverState.blown

    -- Check health — more likely to use at low HP
    local healthPct = bot:Health() / bot:GetMaxHealth()

    -- Check for nearby threats
    local nearbyThreats = 0
    local nonAllies = TTTBots.Roles.GetNonAllies(bot) or {}
    for _, ply in ipairs(nonAllies) do
        if IsValid(ply) and lib.IsPlayerAlive(ply) then
            local dist = bot:GetPos():Distance(ply:GetPos())
            if dist < 600 then
                nearbyThreats = nearbyThreats + 1
            end
        end
    end

    -- Decision logic:
    -- Use dead ringer if: health is low + threats nearby, or cover blown + threats nearby
    local shouldUse = false
    if healthPct < 0.35 and nearbyThreats > 0 then
        shouldUse = true
    elseif isBlown and nearbyThreats >= 2 then
        shouldUse = true
    elseif healthPct < 0.20 then
        shouldUse = true -- Desperate, use regardless
    end

    return shouldUse
end

function SpyDeadRinger.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "SpyDeadRinger")
    state.phase = "activate"
    state.startTime = CurTime()
    state.usedThisRound = true

    -- Select the dead ringer weapon
    local weps = bot:GetWeapons()
    for _, wep in ipairs(weps) do
        if IsValid(wep) and wep:GetClass() == "weapon_ttt_deadringer" then
            bot:SelectWeapon("weapon_ttt_deadringer")
            break
        end
    end

    return STATUS.RUNNING
end

function SpyDeadRinger.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "SpyDeadRinger")

    -- Timeout safety
    if CurTime() - state.startTime > 5 then return STATUS.SUCCESS end

    if state.phase == "activate" then
        -- Fire the dead ringer (primary attack activates it)
        bot:SetAttackTarget(nil)
        local wep = bot:GetActiveWeapon()
        if IsValid(wep) and wep:GetClass() == "weapon_ttt_deadringer" then
            -- Simulate pressing attack to activate
            bot:ConCommand("+attack")
            timer.Simple(0.2, function()
                if IsValid(bot) then
                    bot:ConCommand("-attack")
                end
            end)
        end

        state.phase = "flee"
        state.fleeStart = CurTime()
        return STATUS.RUNNING
    end

    if state.phase == "flee" then
        -- After activating, flee to a safe location
        if CurTime() - (state.fleeStart or CurTime()) > 3 then
            return STATUS.SUCCESS
        end

        -- Run away from threats
        local locomotor = bot:BotLocomotor()
        if locomotor then
            -- Find a nav point away from threats
            local myPos = bot:GetPos()
            local bestNav = nil
            local bestDist = 0

            local nearNavs = navmesh.Find(myPos, 800, 200, 200)
            for _, nav in ipairs(nearNavs or {}) do
                local navPos = nav:GetCenter()
                local dist = navPos:Distance(myPos)

                -- Prefer positions far from current location
                if dist > bestDist and dist > 300 then
                    bestDist = dist
                    bestNav = nav
                end
            end

            if bestNav then
                locomotor:SetGoal(bestNav:GetCenter())
            end
        end

        return STATUS.RUNNING
    end

    return STATUS.SUCCESS
end

function SpyDeadRinger.OnSuccess(bot)
    -- Fire deflection chatter after faking death
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("SpyDeflection", {}, false, math.random(5, 10))
    end
end

function SpyDeadRinger.OnFailure(bot) end

function SpyDeadRinger.OnEnd(bot)
    local state = TTTBots.Behaviors.GetState(bot, "SpyDeadRinger")
    state.phase = nil
    state.startTime = nil
    state.fleeStart = nil
end

-- Reset per-round state
hook.Add("TTTBeginRound", "SpyDeadRinger.ResetState", function()
    for _, bot in pairs(TTTBots.Bots) do
        if IsValid(bot) then
            local state = TTTBots.Behaviors.GetState(bot, "SpyDeadRinger")
            state.usedThisRound = false
        end
    end
end)
