--[[
Retreat — Behavior that makes bots flee when severely wounded, outnumbered, or out of ammo.
Sits above Wander/Patrol but below active FightBack in the tree (inserted into SelfDefense group).
]]
---@class BRetreat
TTTBots.Behaviors.Retreat = {}

local lib = TTTBots.Lib

---@class BRetreat
local Retreat = TTTBots.Behaviors.Retreat
Retreat.Name = "Retreat"
Retreat.Description = "Retreating from danger"
Retreat.Interruptible = true

local STATUS = TTTBots.STATUS

-- Health threshold below which a normal bot retreats.
local RETREAT_HEALTH_NORMAL = 30
-- Health threshold for cautious bots (they retreat earlier).
local RETREAT_HEALTH_CAUTIOUS = 45
-- Safe distance to consider the retreat successful.
local SAFE_DISTANCE = 1000
-- How far away to path when retreating (step size).
local RETREAT_STEP = 900
-- How many seconds to maintain retreat state after losing sight of attacker.
local RETREAT_SUSTAIN = 6

--- Get the retreat health threshold for this bot's personality.
---@param bot Bot
---@return number threshold
local function GetRetreatThreshold(bot)
    if bot.HasTrait and bot:HasTrait("cautious") then
        return RETREAT_HEALTH_CAUTIOUS
    end
    return RETREAT_HEALTH_NORMAL
end

--- Count the number of known (non-ally) players seen recently in bot's memory.
---@param bot Bot
---@return integer count
local function CountKnownAttackers(bot)
    local memory = bot.components and bot.components.memory
    if not memory then return 0 end
    local count = 0
    for _, ply in ipairs(player.GetAll()) do
        if not lib.IsPlayerAlive(ply) then continue end
        if ply == bot then continue end
        local lastSeen = memory:GetLastSeenTime(ply)
        if lastSeen and (CurTime() - lastSeen) < 10 then
            if TTTBots.Roles and not TTTBots.Roles.IsAllies(bot, ply) then
                count = count + 1
            end
        end
    end
    return count
end

--- Find a nav area in the direction away from the attacker.
---@param bot Bot
---@param attacker Entity|nil
---@return Vector|nil
local function GetRetreatPos(bot, attacker)
    local botPos = bot:GetPos()

    if IsValid(attacker) then
        local awayDir = (botPos - attacker:GetPos()):GetNormalized()
        local targetPos = botPos + awayDir * RETREAT_STEP
        local navArea = navmesh.GetNearestNavArea(targetPos, false, 200)
        if IsValid(navArea) then
            return navArea:GetCenter()
        end
    end

    -- Fallback: try a hiding spot.
    local hidingSpot = TTTBots.Spots and TTTBots.Spots.GetNearestSpotOfCategory(botPos, "hiding")
    if hidingSpot and botPos:Distance(hidingSpot) > 200 then
        return hidingSpot
    end

    return nil
end

--- Validate: should we retreat right now?
function Retreat.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if not lib.IsPlayerAlive(bot) then return false end

    -- Hothead/aggressive personalities never retreat.
    if bot.HasTrait and (bot:HasTrait("hothead") or bot:HasTrait("aggressive")) then return false end

    local attacker = bot.attackTarget or bot.coverTarget
    local inCombat = IsValid(attacker)
    local inv = bot:BotInventory()

    -- Out of ammo and in combat.
    if inCombat and inv and inv:HasNoWeaponAvailable(true) then return true end

    -- Health below threshold.
    if inCombat and bot:Health() <= GetRetreatThreshold(bot) then return true end

    -- Outnumbered (2+ known enemies).
    if inCombat and CountKnownAttackers(bot) >= 2 then return true end

    -- Sustain retreat state flagged by SeekCover (health < 25%).
    if bot.isRetreating then return true end

    return false
end

function Retreat.OnStart(bot)
    bot.isRetreating = true
    bot.retreatGoal = nil
    bot.retreatStartTime = CurTime()
    local loco = bot:BotLocomotor()
    if loco then loco.shouldSprint = true end
    return STATUS.RUNNING
end

function Retreat.OnRunning(bot)
    if not lib.IsPlayerAlive(bot) then return STATUS.FAILURE end

    local now = CurTime()
    local loco = bot:BotLocomotor()
    local attacker = bot.attackTarget or bot.coverTarget

    -- Succeeded once safe distance is reached.
    if IsValid(attacker) then
        local distToAttacker = bot:GetPos():Distance(attacker:GetPos())
        if distToAttacker >= SAFE_DISTANCE then
            return STATUS.SUCCESS
        end
    else
        -- Give RETREAT_SUSTAIN seconds to reach safety after losing the attacker.
        if now - (bot.retreatStartTime or now) > RETREAT_SUSTAIN then
            return STATUS.SUCCESS
        end
    end

    -- Keep forcing sprint on locomotor.
    if loco then loco.shouldSprint = true end

    -- Recalculate retreat goal when we've arrived or have none.
    if not bot.retreatGoal or (loco and loco:IsCloseEnough(bot.retreatGoal)) then
        local newGoal = GetRetreatPos(bot, attacker)
        if newGoal then
            bot.retreatGoal = newGoal
            if loco then loco:SetGoal(newGoal) end
        end
    end

    -- Call for help via chatter every ~4 seconds.
    lib.CallEveryNTicks(bot, function()
        local chatter = bot:BotChatter()
        if chatter and chatter.On and IsValid(attacker) then
            chatter:On("CallHelp", { player = attacker:Nick() }, false, 1)
        end
    end, math.ceil(TTTBots.Tickrate * 4))

    -- Stop firing while fleeing.
    if loco then
        loco:StopAttack()
        loco.stopLookingAround = false
    end

    return STATUS.RUNNING
end

function Retreat.OnSuccess(bot)
end

function Retreat.OnFailure(bot)
end

function Retreat.OnEnd(bot)
    bot.isRetreating = false
    bot.retreatGoal = nil
    local loco = bot:BotLocomotor()
    if loco then
        loco.shouldSprint = false
        loco:StopAttack()
    end
end
