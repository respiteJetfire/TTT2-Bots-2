--- behaviors/usejermalauncher.lua
--- Behavior: equip the Jerma Launcher and fire it at an enemy position.
---
--- The weapon is a single-use traitor SWEP that spawns a Jerma985 Nextbot
--- wherever the shooter is looking. The nextbot relentlessly chases players,
--- making it an extremely disruptive tactical tool.
---
--- Because this weapon:
---   • is single-use (consumed immediately on PrimaryAttack)
---   • spawns a mobile nextbot that hunts players autonomously
---   • needs to be aimed in a valid direction (traces forward from the eye)
---
--- ...the bot should:
---   1. Find the nearest visible enemy (or look forward as a fallback).
---   2. Equip the weapon.
---   3. Aim at the target area and call PrimaryAttack() directly.
---   4. Switch back to their best combat weapon.
---
--- Implementation follows the same step-based state machine pattern used by
--- UseApocalypse, UseHologramDecoy, etc.

TTTBots = TTTBots or {}
TTTBots.Behaviors = TTTBots.Behaviors or {}

---@class BUseJermaLauncher
TTTBots.Behaviors.UseJermaLauncher = {}

local lib = TTTBots.Lib

---@class BUseJermaLauncher
local UseJermaLauncher = TTTBots.Behaviors.UseJermaLauncher
UseJermaLauncher.Name          = "UseJermaLauncher"
UseJermaLauncher.Description   = "Launching a Jerma985 Nextbot"
UseJermaLauncher.Interruptible = false

local STATUS = TTTBots.STATUS

--- Weapon classname — must match the SWEP's class exactly.
local WEAPON_CLASS = "weapon_ttt2_jerma_launcher"

--- Maximum failed attempts before permanently giving up this round.
local MAX_RETRIES = 2

--- Minimum live enemies before the bot bothers firing.
local MIN_ENEMIES = 1

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Count how many living non-ally players exist right now.
---@param bot Bot
---@return number
local function CountLiveEnemies(bot)
    local count = 0
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if not ply:Alive() then continue end
        if ply == bot then continue end
        if TTTBots.Roles and TTTBots.Roles.IsAllies(bot, ply) then continue end
        count = count + 1
    end
    return count
end

--- Find the closest living non-ally player the bot can see.
---@param bot Bot
---@return Player?
local function FindNearestVisibleEnemy(bot)
    local botPos = bot:EyePos()
    local closest = nil
    local closestDist = math.huge

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if not ply:Alive() then continue end
        if ply == bot then continue end
        if TTTBots.Roles and TTTBots.Roles.IsAllies(bot, ply) then continue end

        local dist = bot:GetPos():Distance(ply:GetPos())
        if dist < closestDist then
            -- Quick visibility check
            local tr = util.TraceLine({
                start  = botPos,
                endpos = ply:EyePos(),
                filter = bot,
                mask   = MASK_SOLID_BRUSHONLY,
            })
            if not tr.Hit or tr.Fraction > 0.95 then
                closest = ply
                closestDist = dist
            end
        end
    end

    return closest
end

--- Switch to the best available combat weapon after activation.
---@param bot Bot
local function SwitchToCombatWeapon(bot)
    local inv = bot:BotInventory()
    if not inv then return end

    local bestSpecial = inv:GetSpecialPrimary()
    if bestSpecial and IsValid(bestSpecial) then
        bot:SelectWeapon(bestSpecial:GetClass())
        return
    end

    local primary = inv:GetPrimary()
    if primary and IsValid(primary) then
        bot:SelectWeapon(primary:GetClass())
        return
    end

    local secondary = inv:GetSecondary()
    if secondary and IsValid(secondary) then
        bot:SelectWeapon(secondary:GetClass())
    end
end

-- ---------------------------------------------------------------------------
-- Behavior lifecycle
-- ---------------------------------------------------------------------------

--- Validate: activate as soon as we have the weapon, the round is live,
--- and at least one enemy is still alive.
---@param bot Bot
---@return boolean
function UseJermaLauncher.Validate(bot)
    if not IsValid(bot) then return false end
    if not bot:Alive() then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not bot:HasWeapon(WEAPON_CLASS) then return false end

    -- Don't retry after too many consecutive failures
    local retries = bot.ttt2_jerma_launcher_retries or 0
    if retries >= MAX_RETRIES then return false end

    -- Need at least one living enemy
    if CountLiveEnemies(bot) < MIN_ENEMIES then return false end

    -- Random chance gate — ~10% per validate tick to add slight delay
    if math.random(1, 10) ~= 1 then return false end

    return true
end

---@param bot Bot
---@return BStatus
function UseJermaLauncher.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "UseJermaLauncher")
    state.step      = 0
    state.startTime = CurTime()
    state.fired     = false

    local inv = bot:BotInventory()
    if inv then inv:PauseAutoSwitch() end

    return STATUS.RUNNING
end

---@param bot Bot
---@return BStatus
function UseJermaLauncher.OnRunning(bot)
    local state   = TTTBots.Behaviors.GetState(bot, "UseJermaLauncher")
    local step    = state.step or 0
    local elapsed = CurTime() - (state.startTime or CurTime())

    -- Safety timeout
    if elapsed > 5.0 then
        return STATUS.FAILURE
    end

    -- If the weapon has already been consumed, we're done
    if not bot:HasWeapon(WEAPON_CLASS) and state.fired then
        SwitchToCombatWeapon(bot)
        return STATUS.SUCCESS
    end

    if step == 0 then
        -- Step 0: select the Jerma Launcher weapon
        local wep = bot:GetWeapon(WEAPON_CLASS)
        if not IsValid(wep) then return STATUS.FAILURE end
        bot:SelectWeapon(WEAPON_CLASS)
        state.step = 1
        return STATUS.RUNNING

    elseif step == 1 then
        -- Step 1: wait briefly for weapon switch, then aim at a target
        if elapsed < 0.25 then return STATUS.RUNNING end

        local activeWep = bot:GetActiveWeapon()
        if not (IsValid(activeWep) and activeWep:GetClass() == WEAPON_CLASS) then
            -- Weapon switch hasn't completed — retry select
            if elapsed > 1.5 then
                local wep = bot:GetWeapon(WEAPON_CLASS)
                if IsValid(wep) then
                    bot:SetActiveWeapon(wep)
                end
            else
                bot:SelectWeapon(WEAPON_CLASS)
            end
            return STATUS.RUNNING
        end

        -- Try to aim at an enemy before firing
        local loco = bot:BotLocomotor()
        local target = FindNearestVisibleEnemy(bot)
        if target and IsValid(target) and loco then
            loco:LookAt(target:GetPos())
        end

        state.step     = 2
        state.aimStart = CurTime()
        return STATUS.RUNNING

    elseif step == 2 then
        -- Step 2: brief aiming delay, then fire
        local aimTime = CurTime() - (state.aimStart or CurTime())
        if aimTime < 0.3 then
            -- Keep aiming at the target during the aiming window
            local loco = bot:BotLocomotor()
            local target = FindNearestVisibleEnemy(bot)
            if target and IsValid(target) and loco then
                loco:LookAt(target:GetPos())
            end
            return STATUS.RUNNING
        end

        local activeWep = bot:GetActiveWeapon()
        if not (IsValid(activeWep) and activeWep:GetClass() == WEAPON_CLASS) then
            return STATUS.FAILURE
        end

        -- Call PrimaryAttack() directly — the weapon traces forward from
        -- the bot's eye position and spawns the Jerma nextbot there
        activeWep:PrimaryAttack()
        state.fired     = true
        state.firedTime = CurTime()
        state.step      = 3
        return STATUS.RUNNING

    elseif step == 3 then
        -- Step 3: wait for the SWEP to process, then switch back
        local timeSinceFire = CurTime() - (state.firedTime or CurTime())
        if timeSinceFire >= 0.5 then
            SwitchToCombatWeapon(bot)
            return STATUS.SUCCESS
        end
        return STATUS.RUNNING
    end

    return STATUS.RUNNING
end

function UseJermaLauncher.OnEnd(bot)
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end

    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end

    TTTBots.Behaviors.ClearState(bot, "UseJermaLauncher")
end

function UseJermaLauncher.OnSuccess(bot)
    bot.ttt2_jerma_launcher_retries = 0

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("JermaLauncherFired", {}, true)
    end
end

function UseJermaLauncher.OnFailure(bot)
    bot.ttt2_jerma_launcher_retries = (bot.ttt2_jerma_launcher_retries or 0) + 1
end

-- Reset the retry counter at the start of each round
hook.Add("TTTPrepareRound", "TTTBots_JermaLauncher_ResetRetries", function()
    if not TTTBots.Bots then return end
    for _, bot in ipairs(TTTBots.Bots) do
        if IsValid(bot) then
            bot.ttt2_jerma_launcher_retries = 0
        end
    end
end)
