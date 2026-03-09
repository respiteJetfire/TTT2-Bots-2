--[[
LootNearby — Behavior that makes bots loot weapons from recently killed players nearby.
Only active when not in combat, and only if a dropped weapon is better than current loadout.
]]
---@class BLootNearby
TTTBots.Behaviors.LootNearby = {}

local lib = TTTBots.Lib

---@class BLootNearby
local LootNearby = TTTBots.Behaviors.LootNearby
LootNearby.Name = "LootNearby"
LootNearby.Description = "Looting weapons from nearby corpses"
LootNearby.Interruptible = true

local STATUS = TTTBots.STATUS

-- Radius around the bot to search for dropped weapons.
local LOOT_RADIUS = 400
-- Timeout after which we give up trying to reach a weapon.
local LOOT_TIMEOUT = 10
-- Distance at which the bot switches from pathfinding to direct walking.
-- Must exceed PathManager.completeRange (~28) to avoid the dead zone where
-- the locomotor clears the goal but the bot isn't close enough to pick up.
local DIRECT_WALK_DIST = 120
-- Distance at which the server-side Give() pickup is attempted.
local PICKUP_DIST = 60

--- Score a dropped weapon entity. Higher = better.
---@param wepEnt Entity
---@param bot Bot
---@return number score
local function ScoreDroppedWeapon(wepEnt, bot)
    if not IsValid(wepEnt) then return -999 end
    local inv = bot:BotInventory()
    if not inv then return -999 end

    -- Dropped TTT weapons expose Primary.Damage and related fields directly on the entity.
    local damage = wepEnt.Primary and wepEnt.Primary.Damage or 1
    local delay = wepEnt.Primary and wepEnt.Primary.Delay or 1
    local numshots = wepEnt.Primary and wepEnt.Primary.NumShots or 1
    local rps = 1 / math.max(delay, 0.01)
    local dps = damage * numshots * rps

    local score = dps

    -- Bonus for snipers/rifles if bot has those traits.
    local isDamageHigh = damage > 40
    local isAutomatic = wepEnt.Primary and wepEnt.Primary.Automatic or false
    local isSniper = isDamageHigh and not isAutomatic
    local isShotgun = wepEnt.AmmoEnt and string.find(wepEnt.AmmoEnt or "", "buckshot") ~= nil

    if isSniper and bot.HasTrait and bot:HasTrait("sniper") then
        score = score + 20
    end
    if isShotgun and bot.HasTrait and bot:HasTrait("CQB") then
        score = score + 10
    end
    -- Silent weapons are useful for traitors not in active combat.
    if wepEnt.IsSilent and bot.GetRoleStringRaw and bot:GetRoleStringRaw() == "traitor" then
        score = score + 15
    end
    -- Penalise weapons with no ammo in the world entity.
    local clip = wepEnt.Clip1 and wepEnt:Clip1() or 0
    if clip <= 0 then
        score = score - 30
    end

    return score
end

--- Score the bot's current best weapon (by DPS).
---@param bot Bot
---@return number score
local function ScoreCurrentBest(bot)
    local inv = bot:BotInventory()
    if not inv then return 0 end

    local best = 0
    local candidates = { inv:GetPrimary(), inv:GetSecondary(), inv:GetSpecialPrimary() }
    for _, wep in ipairs(candidates) do
        if not IsValid(wep) then continue end
        local info = inv:GetWeaponInfo(wep)
        if info and info.dps and info.dps > best then
            best = info.dps
        end
    end
    return best
end

--- Find the best dropped weapon near the bot that beats the current loadout.
---@param bot Bot
---@return Entity|nil
local function FindBestDroppedWeapon(bot)
    local pos = bot:GetPos()
    local nearby = ents.FindInSphere(pos, LOOT_RADIUS)
    local bestEnt = nil
    -- Must beat current best by a margin of 10 DPS.
    local bestScore = ScoreCurrentBest(bot) + 10

    for _, ent in ipairs(nearby) do
        if not IsValid(ent) then continue end
        local class = ent:GetClass()
        if not string.find(class, "weapon_") then continue end
        -- Only pick up world-dropped weapons (no owner).
        if IsValid(ent:GetOwner()) then continue end

        local score = ScoreDroppedWeapon(ent, bot)
        if score > bestScore then
            bestScore = score
            bestEnt = ent
        end
    end

    return bestEnt
end

--- Validate: only loot when not in combat and there's something worth taking.
function LootNearby.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if not lib.IsPlayerAlive(bot) then return false end
    -- No looting during combat.
    if IsValid(bot.attackTarget) then return false end
    -- If we already have a valid loot target, keep using it (don't thrash targets every tick).
    if IsValid(bot.lootTarget) and not IsValid(bot.lootTarget:GetOwner()) then
        return true
    end
    local target = FindBestDroppedWeapon(bot)
    if not target then return false end
    bot.lootTarget = target
    return true
end

function LootNearby.OnStart(bot)
    bot.lootStartTime = CurTime()
    -- Immediately set the goal so the locomotor can start pathfinding right away.
    if IsValid(bot.lootTarget) then
        local loco = bot:BotLocomotor()
        if loco then
            loco:SetGoal(bot.lootTarget:GetPos())
        end
    end
    return STATUS.RUNNING
end

function LootNearby.OnRunning(bot)
    if not lib.IsPlayerAlive(bot) then return STATUS.FAILURE end
    -- Abort if combat starts.
    if IsValid(bot.attackTarget) then return STATUS.FAILURE end
    -- Timeout.
    if CurTime() - (bot.lootStartTime or 0) > LOOT_TIMEOUT then return STATUS.FAILURE end

    local target = bot.lootTarget
    if not IsValid(target) then return STATUS.SUCCESS end
    -- Someone else picked it up.
    if IsValid(target:GetOwner()) then return STATUS.FAILURE end

    local loco = bot:BotLocomotor()
    local targetPos = target:GetPos()
    local dist = bot:GetPos():Distance(targetPos)

    if dist > DIRECT_WALK_DIST then
        -- If the path is impossible, give up rather than standing still.
        if loco.cantReachGoal then
            loco.cantReachGoal = false
            return STATUS.FAILURE
        end
        loco:SetGoal(targetPos)
        return STATUS.RUNNING
    end

    if dist > PICKUP_DIST then
        -- Inside direct-walk zone: bypass pathfinding (which clears the goal
        -- at ~28 units) and walk straight toward the weapon.
        loco:SetGoal(nil)
        loco:SetPriorityGoal(targetPos, PICKUP_DIST)
        loco:LookAt(targetPos)
        return STATUS.RUNNING
    end

    -- Close enough — do a server-side pickup (reliable, like GetWeapons does).
    loco:StopMoving()
    loco:LookAt(targetPos)
    local class = target:GetClass()
    if class and class ~= "" then
        local given = bot:Give(class)
        if IsValid(given) then
            target:Remove()
            return STATUS.SUCCESS
        end
    end
    -- Fallback: try +use if Give() didn't work (e.g. custom weapon entity).
    loco:SetUse(true)
    return STATUS.SUCCESS
end

function LootNearby.OnSuccess(bot)
end

function LootNearby.OnFailure(bot)
end

function LootNearby.OnEnd(bot)
    bot.lootTarget = nil
    bot.lootStartTime = nil
    local loco = bot:BotLocomotor()
    if loco then loco:SetUse(false) end
end
