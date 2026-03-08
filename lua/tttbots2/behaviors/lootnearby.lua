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
-- Distance at which we can pick up a weapon.
local PICKUP_DIST = 50
-- How many ticks to hold +use when in pickup range.
local PICKUP_USE_TICKS = 5
-- Cooldown (seconds) before retrying a weapon we already attempted to loot.
local LOOT_ATTEMPT_COOLDOWN = 8

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

    local attempted = bot.lootAttempted or {}
    local now = CurTime()
    for _, ent in ipairs(nearby) do
        if not IsValid(ent) then continue end
        local class = ent:GetClass()
        if not string.find(class, "weapon_") then continue end
        -- Only pick up world-dropped weapons (no owner).
        local owner = ent:GetOwner()
        if owner and owner ~= NULL and IsValid(owner) then continue end
        -- Skip weapons we recently attempted to loot (prevents infinite retry loop).
        if attempted[ent] and (now - attempted[ent]) < LOOT_ATTEMPT_COOLDOWN then continue end

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
    local target = FindBestDroppedWeapon(bot)
    if not target then return false end
    bot.lootTarget = target
    return true
end

function LootNearby.OnStart(bot)
    bot.lootStartTime = CurTime()
    bot.lootUseTicks = 0
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

    local loco = bot:BotLocomotor()
    local dist = bot:GetPos():Distance(target:GetPos())

    if dist > PICKUP_DIST then
        loco:SetGoal(target:GetPos())
        -- If the path is impossible, give up rather than standing still.
        if loco.cantReachGoal then
            loco.cantReachGoal = false
            -- Record that we failed to reach this weapon so we don't immediately retry it.
            bot.lootAttempted = bot.lootAttempted or {}
            bot.lootAttempted[target] = CurTime()
            return STATUS.FAILURE
        end
        return STATUS.RUNNING
    end

    -- Close enough — pick up the weapon directly server-side (most reliable method).
    -- Also hold IN_USE as a belt-and-suspenders for any TTT2 pickup hooks.
    loco:StopMoving()
    loco:LookAt(target:GetPos())
    loco:SetUse(true)

    -- Direct server-side give: the canonical reliable pickup path in GMod.
    local class = target:GetClass()
    if IsValid(target) and class ~= "" then
        local given = bot:Give(class)
        if IsValid(given) then
            -- Successfully given; remove the world entity to avoid a duplicate.
            target:Remove()
        end
    end

    -- Record attempt and finish regardless of Give result.
    bot.lootAttempted = bot.lootAttempted or {}
    bot.lootAttempted[target] = CurTime()
    return STATUS.SUCCESS
end

function LootNearby.OnSuccess(bot)
end

function LootNearby.OnFailure(bot)
end

function LootNearby.OnEnd(bot)
    bot.lootTarget = nil
    bot.lootStartTime = nil
    bot.lootUseTicks = nil
    local loco = bot:BotLocomotor()
    if loco then loco:SetUse(false) end
    -- Prune entries from the attempt-cooldown table that have already expired.
    if bot.lootAttempted then
        local now = CurTime()
        for ent, t in pairs(bot.lootAttempted) do
            if (now - t) >= LOOT_ATTEMPT_COOLDOWN then
                bot.lootAttempted[ent] = nil
            end
        end
    end
end
