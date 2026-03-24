--- RequestConsignment — Behavior for bots to request weapons/ammo from a
--- nearby Gun Dealer when they are low on weapons or ammo.
---
--- Bots will:
---   1. Detect when they need weapons or are low on ammo
---   2. Find a nearby alive Gun Dealer
---   3. Approach the Gun Dealer
---   4. Use chatter to request weapons/ammo
---   5. Wait nearby for the crate to appear
---
--- This applies to ALL non-Gun-Dealer bots.

---@class BRequestConsignment
TTTBots.Behaviors.RequestConsignment = {}

local lib = TTTBots.Lib

---@class BRequestConsignment
local RequestConsignment = TTTBots.Behaviors.RequestConsignment
RequestConsignment.Name = "RequestConsignment"
RequestConsignment.Description = "Approach a Gun Dealer and request weapons or ammo"
RequestConsignment.Interruptible = true

local STATUS = TTTBots.STATUS

-- How close the bot needs to get to the Gun Dealer to make the request
local REQUEST_APPROACH_DIST = 200
-- Maximum distance to consider approaching a Gun Dealer
local MAX_SEEK_DIST = 1500
-- How long to wait near the Gun Dealer for the crate
local WAIT_TIME = 15
-- Cooldown between requests
local REQUEST_COOLDOWN = 45
-- Minimum total ammo percentage before requesting ammo
local LOW_AMMO_THRESHOLD = 0.3

--- Check if the bot is low on ammo across all weapons
---@param bot Bot
---@return boolean
local function IsLowOnAmmo(bot)
    local weapons = bot:GetWeapons()
    if not weapons or #weapons == 0 then return false end

    local totalAmmo = 0
    local totalMaxAmmo = 0

    for _, wep in pairs(weapons) do
        if not IsValid(wep) then continue end
        if not wep.Primary then continue end
        if wep.Primary.Ammo == "none" then continue end

        local clip = wep:Clip1()
        local maxClip = wep:GetMaxClip1()
        local reserve = bot:GetAmmoCount(wep:GetPrimaryAmmoType())

        if maxClip > 0 then
            totalAmmo = totalAmmo + clip + reserve
            totalMaxAmmo = totalMaxAmmo + maxClip * 3 -- rough estimate of "full" ammo
        end
    end

    if totalMaxAmmo == 0 then return false end
    return (totalAmmo / totalMaxAmmo) < LOW_AMMO_THRESHOLD
end

--- Check if the bot needs a weapon (missing primary or secondary)
---@param bot Bot
---@return boolean
local function NeedsWeapon(bot)
    local inv = bot:BotInventory()
    if not inv then return false end
    return not inv:HasPrimary() or not inv:HasSecondary()
end

--- Find the nearest alive Gun Dealer
---@param bot Bot
---@return Player|nil
local function FindNearestGunDealer(bot)
    if not ROLE_GUNDEALER then return nil end

    local alivePlayers = TTTBots.Match.AlivePlayers or {}
    local bestDealer = nil
    local bestDist = math.huge

    for _, ply in ipairs(alivePlayers) do
        if not IsValid(ply) then continue end
        if ply == bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end
        if ply:GetSubRole() ~= ROLE_GUNDEALER then continue end

        local dist = bot:GetPos():Distance(ply:GetPos())
        if dist > MAX_SEEK_DIST then continue end
        if dist < bestDist then
            bestDist = dist
            bestDealer = ply
        end
    end

    return bestDealer
end

function RequestConsignment.Validate(bot)
    if not lib.IsPlayerAlive(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Gun Dealers don't request from themselves
    if ROLE_GUNDEALER and bot:GetSubRole() == ROLE_GUNDEALER then return false end

    -- Don't request during combat
    if IsValid(bot.attackTarget) then return false end

    -- Cooldown
    if (bot._requestConsignmentCooldown or 0) > CurTime() then return false end

    -- Must actually need weapons or ammo
    local needsWeapon = NeedsWeapon(bot)
    local lowAmmo = IsLowOnAmmo(bot)
    if not needsWeapon and not lowAmmo then return false end

    -- If already in progress, keep going
    local state = TTTBots.Behaviors.GetState(bot, "RequestConsignment")
    if IsValid(state.dealer) and lib.IsPlayerAlive(state.dealer) then
        return true
    end

    -- Find a Gun Dealer
    local dealer = FindNearestGunDealer(bot)
    if not dealer then return false end

    state.dealer = dealer
    state.needsWeapon = needsWeapon
    state.lowAmmo = lowAmmo

    return true
end

function RequestConsignment.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "RequestConsignment")
    state.startTime = CurTime()
    state.hasRequested = false

    return STATUS.RUNNING
end

function RequestConsignment.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "RequestConsignment")
    local dealer = state.dealer

    -- Dealer is no longer valid
    if not IsValid(dealer) or not lib.IsPlayerAlive(dealer) then
        return STATUS.FAILURE
    end

    -- Abort if combat starts
    if IsValid(bot.attackTarget) then return STATUS.FAILURE end

    -- Timeout
    if (CurTime() - (state.startTime or 0)) > WAIT_TIME + 10 then
        return STATUS.FAILURE
    end

    local loco = bot:BotLocomotor()
    local dist = bot:GetPos():Distance(dealer:GetPos())

    -- Approach the Gun Dealer
    if dist > REQUEST_APPROACH_DIST then
        loco:SetGoal(dealer:GetPos())
        return STATUS.RUNNING
    end

    -- We're close enough — make the request via chatter
    if not state.hasRequested then
        state.hasRequested = true

        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            if state.needsWeapon then
                chatter:On("GunDealerRequestWeapon", {
                    player = dealer:Nick(),
                    playerEnt = dealer,
                }, false, 0)
            else
                chatter:On("GunDealerRequestAmmo", {
                    player = dealer:Nick(),
                    playerEnt = dealer,
                }, false, 0)
            end
        end

        -- Notify the Gun Dealer bot (if it is a bot) that someone is requesting
        if dealer:IsBot() then
            dealer._gunDealerRequestedBy = bot
            dealer._gunDealerRequestTime = CurTime()
        end

        state.waitStartTime = CurTime()
    end

    -- Wait near the dealer for a crate to appear
    loco:SetGoal(nil) -- Stay put
    loco:LookAt(dealer:EyePos())

    -- Check if a crate has appeared nearby (delivery completed)
    local nearbyCrates = ents.FindByClass("ent_ttt2_consignment")
    for _, crate in ipairs(nearbyCrates) do
        if IsValid(crate) and bot:GetPos():Distance(crate:GetPos()) < 300 then
            -- A crate appeared nearby — go break it (BreakConsignment will handle this)
            return STATUS.SUCCESS
        end
    end

    -- Timeout waiting for delivery
    if state.waitStartTime and (CurTime() - state.waitStartTime) > WAIT_TIME then
        return STATUS.FAILURE
    end

    return STATUS.RUNNING
end

function RequestConsignment.OnSuccess(bot)
    bot._requestConsignmentCooldown = CurTime() + REQUEST_COOLDOWN

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("GunDealerRequestThanks", {}, false, 0)
    end
end

function RequestConsignment.OnFailure(bot)
    bot._requestConsignmentCooldown = CurTime() + REQUEST_COOLDOWN * 0.5
end

function RequestConsignment.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "RequestConsignment")
end
