--- behaviors/usepeacekeeper.lua
--- Uses the Peacekeeper / "High Noon" weapon (weapon_ttt_peacekeeper).
--- This is a McCree-style ultimate: the bot equips it, charges up targets in FOV,
--- then fires lethal homing shots. It's a one-use weapon that slows the user.
--- The bot should only use it when multiple enemies are visible at once.

local lib = TTTBots.Lib
local STATUS = TTTBots.STATUS

---@class BUsePeacekeeper
TTTBots.Behaviors.UsePeacekeeper = {}

local UsePeacekeeper = TTTBots.Behaviors.UsePeacekeeper
UsePeacekeeper.Name = "UsePeacekeeper"
UsePeacekeeper.Description = "Use the Peacekeeper (High Noon) weapon on multiple visible enemies."
UsePeacekeeper.Interruptible = false  -- Once committed, don't abort

--- Minimum visible enemies to justify using this powerful one-shot weapon.
local MIN_VISIBLE_ENEMIES = 2
--- Max time we'll hold before firing if not all tracked targets are ready yet.
local CHARGE_TIME = 4.0
--- Max total behavior duration before we force-fire or fail.
local MAX_DURATION = 8.0
local PRIMARY_PRESS_TIME = 0.2

function UsePeacekeeper.HasPeacekeeper(bot)
    return bot:HasWeapon("weapon_ttt_peacekeeper")
end

function UsePeacekeeper.GetPeacekeeper(bot)
    local wep = bot:GetWeapon("weapon_ttt_peacekeeper")
    return IsValid(wep) and wep or nil
end

--- Count enemies visible to the bot within a reasonable FOV/range.
---@param bot Bot
---@return number visibleEnemies
local function CountVisibleEnemies(bot)
    local count = 0
    for _, ply in pairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() or ply == bot then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then continue end
        -- Check if the bot can see them within weapon range
        if bot:GetPos():Distance(ply:GetPos()) > 2000 then continue end
        if bot:Visible(ply) then
            count = count + 1
        end
    end
    return count
end

---@param wep Weapon|nil
---@return string
local function GetHighNoonState(wep)
    if not IsValid(wep) or not wep.GetHighNoon then return "none" end

    return wep:GetHighNoon() or "none"
end

---@param bot Bot
---@param wep Weapon|nil
---@return Player[]
local function GetTrackedTargets(bot, wep)
    if not IsValid(bot) or not IsValid(wep) then return {} end

    local tracked = {}
    local targets = bot.highnoontargets or {}
    local entIndex = wep:EntIndex()

    for _, ply in pairs(targets) do
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then continue end
        if not ply:GetNWBool("HighNoonFOV" .. entIndex, false) then continue end

        table.insert(tracked, ply)
    end

    return tracked
end

---@param trackedTargets Player[]
---@param wep Weapon|nil
---@return boolean
local function AreAllTrackedTargetsReady(trackedTargets, wep)
    if not IsValid(wep) or #trackedTargets == 0 then return false end

    local entIndex = wep:EntIndex()

    for _, ply in ipairs(trackedTargets) do
        local charge = ply:GetNWInt("HighNoonCharged" .. entIndex, 0)
        if charge < ply:Health() then
            return false
        end
    end

    return true
end

---@param bot Bot
---@param stateKey string
---@return boolean
local function IsPressActive(bot, stateKey)
    return (bot[stateKey] or 0) > CurTime()
end

---@param bot Bot
---@param stateKey string
local function StartPrimaryPress(bot, stateKey)
    bot[stateKey] = CurTime() + PRIMARY_PRESS_TIME
end

function UsePeacekeeper.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if not UsePeacekeeper.HasPeacekeeper(bot) then return false end

    local visibleEnemies = CountVisibleEnemies(bot)
    if visibleEnemies < MIN_VISIBLE_ENEMIES then return false end

    -- Small chance gate per tick
    if math.random(1, 40) > 1 then return false end

    return true
end

function UsePeacekeeper.OnStart(bot)
    bot._peacekeeperStart = CurTime()
    bot._peacekeeperChargeStart = nil
    bot._peacekeeperStartPressUntil = nil
    bot._peacekeeperFirePressUntil = nil
    bot._peacekeeperQueuedFire = false
    bot._peacekeeperSawChargingState = false
    bot._peacekeeperSawFiringState = false

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("HighNoon", {}, false)
    end

    return STATUS.RUNNING
end

function UsePeacekeeper.OnRunning(bot)
    if not UsePeacekeeper.HasPeacekeeper(bot) then
        -- Weapon consumed — we successfully fired
        return STATUS.SUCCESS
    end

    -- Hard timeout
    if bot._peacekeeperStart and (CurTime() - bot._peacekeeperStart) > MAX_DURATION then
        return STATUS.FAILURE
    end

    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    local wep = UsePeacekeeper.GetPeacekeeper(bot)
    if not wep then return STATUS.FAILURE end
    local highNoonState = GetHighNoonState(wep)

    -- Equip the peacekeeper
    inv:PauseAutoSwitch()
    bot:SetActiveWeapon(wep)
    loco:PauseAttackCompat()

    -- Find the centroid of visible enemies to look at
    local enemyPositions = {}
    for _, ply in pairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() or ply == bot then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then continue end
        if bot:GetPos():Distance(ply:GetPos()) > 2000 then continue end
        if bot:Visible(ply) then
            table.insert(enemyPositions, ply:EyePos())
        end
    end

    if #enemyPositions == 0 then
        -- Lost sight of everyone
        return STATUS.FAILURE
    end

    -- Look at centroid of enemy eyes
    local center = Vector(0, 0, 0)
    for _, pos in ipairs(enemyPositions) do
        center = center + pos
    end
    center = center / #enemyPositions
    loco:LookAt(center)
    loco:SetHalt(true)

    if highNoonState == "firing" then
        bot._peacekeeperSawFiringState = true
        return STATUS.SUCCESS
    end

    if highNoonState == "starting" or highNoonState == "charging" then
        bot._peacekeeperSawChargingState = true
    end

    -- Phase 1: pulse primary once to begin High Noon.
    if highNoonState == "none" and not bot._peacekeeperSawChargingState then
        if not IsPressActive(bot, "_peacekeeperStartPressUntil") then
            StartPrimaryPress(bot, "_peacekeeperStartPressUntil")
        end

        loco:StartAttack()
        return STATUS.RUNNING
    end

    -- Release primary after the initial click so the weapon can receive a second click later.
    if not IsPressActive(bot, "_peacekeeperStartPressUntil") then
        loco:StopAttack()
    end

    if highNoonState == "starting" and not bot._peacekeeperChargeStart then
        bot._peacekeeperChargeStart = CurTime()
        return STATUS.RUNNING
    end

    if highNoonState == "charging" and not bot._peacekeeperChargeStart then
        bot._peacekeeperChargeStart = CurTime()
    end

    if highNoonState ~= "charging" then
        return STATUS.RUNNING
    end

    local trackedTargets = GetTrackedTargets(bot, wep)
    local allTargetsReady = AreAllTrackedTargetsReady(trackedTargets, wep)
    local chargeElapsed = bot._peacekeeperChargeStart and (CurTime() - bot._peacekeeperChargeStart) or 0
    local shouldFire = allTargetsReady or chargeElapsed >= CHARGE_TIME

    -- Phase 2: while charging, do not hold primary. Fire with a second primary click once ready.
    if shouldFire and not bot._peacekeeperQueuedFire then
        bot._peacekeeperQueuedFire = true
        StartPrimaryPress(bot, "_peacekeeperFirePressUntil")
    end

    if IsPressActive(bot, "_peacekeeperFirePressUntil") then
        loco:StartAttack()
        return STATUS.RUNNING
    end

    loco:StopAttack()

    return STATUS.RUNNING
end

function UsePeacekeeper.OnSuccess(bot)
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("PeacekeeperFired", {}, false)
    end
end

function UsePeacekeeper.OnFailure(bot) end

function UsePeacekeeper.OnEnd(bot)
    bot._peacekeeperStart = nil
    bot._peacekeeperChargeStart = nil
    bot._peacekeeperStartPressUntil = nil
    bot._peacekeeperFirePressUntil = nil
    bot._peacekeeperQueuedFire = nil
    bot._peacekeeperSawChargingState = nil
    bot._peacekeeperSawFiringState = nil
    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if loco then
        loco:StopAttack()
        loco:StopAttack2()
        loco:ResumeAttackCompat()
        loco:SetHalt(false)
    end
    if inv then
        inv:ResumeAutoSwitch()
    end
end
