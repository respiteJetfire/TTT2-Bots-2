--- CreateDefector: Traitor behavior to convert an innocent player into a
--- defector by dropping the weapon_ttt_defector_jihad near them.
---
--- The actual addon's conversion mechanism is drop-and-pickup:
---   1. Traitor buys weapon_ttt_defector_jihad (conversion item)
---   2. Traitor drops it near an isolated innocent
---   3. The innocent picks it up → WeaponEquip hook converts them
---
--- This replaces the old RegisterRoleWeapon-based "shoot with deagle" approach
--- which referenced a non-existent weapon_ttt2_defector_deagle.

TTTBots.Behaviors.CreateDefector = {}

local lib = TTTBots.Lib

---@class BCreateDefector
local CreateDefector = TTTBots.Behaviors.CreateDefector
CreateDefector.Name = "CreateDefector"
CreateDefector.Description = "Drop the defector jihad item near an isolated innocent to convert them."
CreateDefector.Interruptible = true

local STATUS = TTTBots.STATUS

--- The class name of the conversion weapon (traitor buys this, drops for innocent)
local DEFECTOR_JIHAD_CLASS = "weapon_ttt_defector_jihad"

--- Maximum distance to the target before dropping the weapon
local DROP_DISTANCE = 150
--- How long to wait after dropping before giving up (seconds)
local DROP_TIMEOUT = 8

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

local function GetState(bot)
    return TTTBots.Behaviors.GetState(bot, "CreateDefector")
end

--- Check if the bot has the conversion weapon
---@param bot Bot
---@return boolean
function CreateDefector.HasDefectorItem(bot)
    return bot:HasWeapon(DEFECTOR_JIHAD_CLASS)
end

--- Get the conversion weapon entity
---@param bot Bot
---@return Weapon?
function CreateDefector.GetDefectorItem(bot)
    local wep = bot:GetWeapon(DEFECTOR_JIHAD_CLASS)
    if IsValid(wep) then return wep end
    return nil
end

--- Find an isolated innocent player suitable for conversion.
--- Prefers truly isolated players (fewer witnesses = better).
---@param bot Bot
---@return Player?
local function FindConversionTarget(bot)
    local candidates = {}
    local botPos = bot:GetPos()
    local nonAllies = TTTBots.Roles.GetNonAllies(bot)

    for _, ply in pairs(TTTBots.Match.AlivePlayers or player.GetAll()) do
        if not IsValid(ply) then continue end
        if ply == bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end

        -- The addon only converts ROLE_INNOCENT on TEAM_INNOCENT
        if not (ply:GetRole() == ROLE_INNOCENT and ply:GetTeam() == TEAM_INNOCENT) then continue end

        -- Must be within reasonable range
        local dist = botPos:Distance(ply:GetPos())
        if dist > 2000 then continue end

        -- Count nearby witnesses (excluding the bot and the candidate)
        local witnesses = lib.GetAllWitnessesBasic(ply:GetPos(), nonAllies, bot)
        local witnessCount = 0
        for _, w in pairs(witnesses) do
            if w ~= ply then witnessCount = witnessCount + 1 end
        end

        -- Score: prefer closer, more isolated targets
        local score = 1000 - dist - (witnessCount * 300)

        table.insert(candidates, { player = ply, score = score, dist = dist })
    end

    if #candidates == 0 then return nil end

    -- Sort by score descending
    table.sort(candidates, function(a, b) return a.score > b.score end)

    return candidates[1].player
end

-- ---------------------------------------------------------------------------
-- Behavior interface
-- ---------------------------------------------------------------------------

function CreateDefector.Validate(bot)
    if not IsValid(bot) then return false end
    if not TTTBots.Lib.IsTTT2() then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.attackTarget ~= nil then return false end

    if not CreateDefector.HasDefectorItem(bot) then return false end

    -- Phase-aware: conversion is the primary purpose of having this weapon.
    -- Early/mid game: almost always try to convert (the item exists solely for this).
    local effectiveChance = 50
    local ra = bot.BotRoundAwareness and bot:BotRoundAwareness()
    local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
    if ra and PHASE then
        local phase = ra:GetPhase()
        if phase == PHASE.EARLY then
            effectiveChance = 100 -- Always attempt in early game
        elseif phase == PHASE.MID then
            effectiveChance = 80 -- Very likely in mid game
        end
    end

    local state = GetState(bot)
    local target = state.DefectorTarget

    -- If we already have a valid target, keep going
    if target and IsValid(target) and lib.IsPlayerAlive(target) then
        return true
    end

    -- Chance gate before expensive target search
    if math.random(1, 100) > effectiveChance then return false end

    -- Find a new target
    local newTarget = FindConversionTarget(bot)
    if not newTarget then return false end

    state.DefectorTarget = newTarget
    return true
end

function CreateDefector.OnStart(bot)
    local state = GetState(bot)
    local target = state.DefectorTarget

    if target and IsValid(target) then
        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("CreatingDefector", { player = target:Nick() }, true)
        end
    end

    state.dropped = false
    state.dropTime = nil

    return STATUS.RUNNING
end

function CreateDefector.OnRunning(bot)
    local state = GetState(bot)
    local target = state.DefectorTarget

    -- Validate target is still alive and eligible
    if not (target and IsValid(target) and lib.IsPlayerAlive(target)) then
        return STATUS.FAILURE
    end

    -- If they're no longer ROLE_INNOCENT on TEAM_INNOCENT, abort
    if not (target:GetRole() == ROLE_INNOCENT and target:GetTeam() == TEAM_INNOCENT) then
        return STATUS.FAILURE
    end

    local loco = bot:BotLocomotor()
    local inv = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    local dist = bot:GetPos():Distance(target:GetPos())

    -- If we already dropped the weapon, wait for pickup or timeout
    if state.dropped then
        if not CreateDefector.HasDefectorItem(bot) then
            -- Weapon was picked up (removed from our inventory) — that's success
            return STATUS.SUCCESS
        end
        -- Check timeout
        if state.dropTime and (CurTime() - state.dropTime) > DROP_TIMEOUT then
            return STATUS.FAILURE
        end
        -- Still waiting — stay near the target
        if dist > DROP_DISTANCE * 2 then
            loco:SetGoal(target:GetPos())
        end
        return STATUS.RUNNING
    end

    -- Navigate toward the target
    loco:SetGoal(target:GetPos())

    -- Not close enough yet
    if dist > DROP_DISTANCE then
        return STATUS.RUNNING
    end

    -- We're close enough — equip and drop the conversion weapon
    local wep = CreateDefector.GetDefectorItem(bot)
    if not wep then return STATUS.FAILURE end

    inv:PauseAutoSwitch()
    bot:SetActiveWeapon(wep)

    -- Announce the drop in team chat
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("DefectorDropping", { player = target:Nick() }, true)
    end

    -- Drop the weapon
    bot:DropWeapon(wep)

    state.dropped = true
    state.dropTime = CurTime()

    return STATUS.RUNNING
end

function CreateDefector.OnSuccess(bot)
end

function CreateDefector.OnFailure(bot)
end

function CreateDefector.OnEnd(bot)
    local state = GetState(bot)
    state.DefectorTarget = nil
    state.dropped = false
    state.dropTime = nil
    TTTBots.Behaviors.ClearState(bot, "CreateDefector")

    local loco = bot:BotLocomotor()
    if loco then
        loco:StopAttack()
    end
    local inv = bot:BotInventory()
    if inv then
        inv:ResumeAutoSwitch()
    end
end

--- External API: force-set a conversion target (e.g. from HandleRequest)
---@param bot Bot
---@param target Player
function CreateDefector.HandleRequest(bot, target)
    if not IsValid(bot) then return end
    if not CreateDefector.HasDefectorItem(bot) then
        -- Try to give the weapon if the bot doesn't have it
        bot:Give(DEFECTOR_JIHAD_CLASS)
    end
    local state = GetState(bot)
    state.DefectorTarget = target
end

