--- groupup.lua
--- GroupUp Behavior — Innocent-side bots seek confirmed innocent players
--- to travel with, building the trust network through proximity.
---
--- Priority: "Patrol" group (alongside Follow/Wander, preferably before Wander)
--- Skipped by bots with the "loner" trait.

---@class GroupUp
TTTBots.Behaviors.GroupUp = {}

local lib = TTTBots.Lib
---@class GroupUp
local GroupUp = TTTBots.Behaviors.GroupUp
GroupUp.Name         = "GroupUp"
GroupUp.Description  = "Seek confirmed innocent players to travel with"
GroupUp.Interruptible = true

local STATUS = TTTBots.STATUS

local GROUPUP_DIST   = 300  -- How close to get before behavior succeeds
local GROUPUP_MAX    = 1200 -- Don't try to group with someone further than this

function GroupUp.Validate(bot)
    if not lib.IsPlayerAlive(bot) then return false end
    -- Only innocent-side bots group up
    if bot:GetTeam() ~= TEAM_INNOCENT then return false end
    -- Loner bots skip this entirely
    local personality = bot:BotPersonality()
    if personality and personality:GetTraitMult("loner") > 1.5 then return false end
    -- Already following someone? Skip
    if bot.followTarget and IsValid(bot.followTarget) then return false end
    -- In combat? Skip
    if bot.attackTarget and IsValid(bot.attackTarget) then return false end

    local evidence = bot:BotEvidence()
    if not evidence then return false end

    -- Find a confirmed innocent player that isn't already close
    local confirmed = evidence.trustNetwork.confirmedInnocent
    local best, bestDist = nil, math.huge

    for ply, entry in pairs(confirmed) do
        if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end
        if ply == bot then continue end
        local dist = bot:GetPos():Distance(ply:GetPos())
        if dist < GROUPUP_DIST then continue end -- already close enough
        if dist > GROUPUP_MAX then continue end  -- too far
        if dist < bestDist then
            bestDist = dist
            best     = ply
        end
    end

    -- Also consider travel companions who are trusted (lower bar)
    if not best then
        local companions = evidence.trustNetwork.travelCompanions
        for ply, entry in pairs(companions) do
            if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end
            if ply == bot then continue end
            if not entry.continuous then continue end
            local dist = bot:GetPos():Distance(ply:GetPos())
            if dist < GROUPUP_DIST then continue end
            if dist > GROUPUP_MAX then continue end
            if dist < bestDist then
                bestDist = dist
                best     = ply
            end
        end
    end

    if not best then return false end

    local state = TTTBots.Behaviors.GetState(bot, "GroupUp")
    state.target    = best
    state.startTime = CurTime()
    return true
end

function GroupUp.OnStart(bot)
    return STATUS.RUNNING
end

function GroupUp.OnRunning(bot)
    local state  = TTTBots.Behaviors.GetState(bot, "GroupUp")
    local target = state.target

    if not (IsValid(target) and lib.IsPlayerAlive(target)) then
        return STATUS.FAILURE
    end

    -- Expire after 12 seconds of trying
    if (CurTime() - state.startTime) > 12 then return STATUS.SUCCESS end

    local dist = bot:GetPos():Distance(target:GetPos())
    if dist < GROUPUP_DIST then
        -- We've successfully grouped up; register as travel companion
        local evidence = bot:BotEvidence()
        if evidence then
            evidence:AddTravelCompanion(target)
        end
        return STATUS.SUCCESS
    end

    local loco = bot:BotLocomotor()
    if loco then
        loco:SetGoal(target:GetPos())
        loco:LookAt(target:GetPos())
    end

    return STATUS.RUNNING
end

function GroupUp.OnSuccess(bot)
end

function GroupUp.OnFailure(bot)
end

function GroupUp.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "GroupUp")
end
