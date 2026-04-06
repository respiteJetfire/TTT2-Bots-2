--- behaviors/useapocalypse.lua
--- Behavior: equip the unified Apocalypse SWEP and immediately activate it.
---
--- The weapon is a single-use traitor SWEP that opens a selection menu for
--- human players, but for bots it auto-selects randomly between zombie and
--- combine apocalypse types. The weapon spawns a horde of team-aware NPCs
--- at hidden positions around the map.
---
--- Because this weapon:
---   • does NOT hurt teammates (fully team-safe)
---   • is extremely powerful (NPC horde that auto-targets enemies)
---   • is single-use and consumed immediately on PrimaryAttack
---
--- ...bots should activate it at the very first opportunity after acquiring
--- it — no target aiming, sky-check, or witness gate required.
---
--- Implementation mirrors UseZombieApocalypse: equip → call PrimaryAttack()
--- directly on the weapon entity → switch back to best combat weapon.
--- The SWEP's PrimaryAttack() detects bot owners and auto-selects a random
--- apocalypse type, bypassing the menu entirely.

TTTBots = TTTBots or {}
TTTBots.Behaviors = TTTBots.Behaviors or {}

---@class BUseApocalypse
TTTBots.Behaviors.UseApocalypse = {}

local lib = TTTBots.Lib

---@class BUseApocalypse
local UseApocalypse = TTTBots.Behaviors.UseApocalypse
UseApocalypse.Name          = "UseApocalypse"
UseApocalypse.Description   = "Unleashing the apocalypse"
UseApocalypse.Interruptible = false

local STATUS = TTTBots.STATUS

--- Weapon classname — must match the SWEP's class exactly.
local WEAPON_CLASS = "weapon_ttt_apocalypse"

--- Maximum failed attempts before permanently giving up this round.
local MAX_RETRIES = 2

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
function UseApocalypse.Validate(bot)
    if not IsValid(bot) then return false end
    if not bot:Alive() then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not bot:HasWeapon(WEAPON_CLASS) then return false end

    -- Don't retry after too many consecutive failures
    local retries = bot.ttt2_apocalypse_retries or 0
    if retries >= MAX_RETRIES then return false end

    -- Need at least one living enemy
    if CountLiveEnemies(bot) < 1 then return false end

    return true
end

---@param bot Bot
---@return BStatus
function UseApocalypse.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "UseApocalypse")
    state.step      = 0
    state.startTime = CurTime()
    state.fired     = false

    local inv = bot:BotInventory()
    if inv then inv:PauseAutoSwitch() end

    return STATUS.RUNNING
end

---@param bot Bot
---@return BStatus
function UseApocalypse.OnRunning(bot)
    local state   = TTTBots.Behaviors.GetState(bot, "UseApocalypse")
    local step    = state.step or 0
    local elapsed = CurTime() - (state.startTime or CurTime())

    -- Safety timeout
    if elapsed > 4.0 then
        return STATUS.FAILURE
    end

    -- If the weapon has already been consumed, we're done
    if not bot:HasWeapon(WEAPON_CLASS) and state.fired then
        SwitchToCombatWeapon(bot)
        return STATUS.SUCCESS
    end

    if step == 0 then
        -- Step 0: select the Apocalypse weapon
        local wep = bot:GetWeapon(WEAPON_CLASS)
        if not IsValid(wep) then return STATUS.FAILURE end
        bot:SelectWeapon(WEAPON_CLASS)
        state.step = 1
        return STATUS.RUNNING

    elseif step == 1 then
        -- Step 1: wait briefly for weapon switch, then fire
        if elapsed < 0.2 then return STATUS.RUNNING end

        local activeWep = bot:GetActiveWeapon()
        if IsValid(activeWep) and activeWep:GetClass() == WEAPON_CLASS then
            -- Call PrimaryAttack() directly — the SWEP detects bot owners
            -- and auto-selects a random apocalypse type, bypassing the menu
            activeWep:PrimaryAttack()
            state.fired     = true
            state.firedTime = CurTime()
            state.step      = 2
            return STATUS.RUNNING
        else
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

    elseif step == 2 then
        -- Step 2: wait for the SWEP to process, then switch back
        local timeSinceFire = CurTime() - (state.firedTime or CurTime())
        if timeSinceFire >= 0.3 then
            SwitchToCombatWeapon(bot)
            return STATUS.SUCCESS
        end
        return STATUS.RUNNING
    end

    return STATUS.RUNNING
end

function UseApocalypse.OnEnd(bot)
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end

    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end

    TTTBots.Behaviors.ClearState(bot, "UseApocalypse")
end

function UseApocalypse.OnSuccess(bot)
    bot.ttt2_apocalypse_retries = 0

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("ApocalypseActivated", {}, true)
    end
end

function UseApocalypse.OnFailure(bot)
    bot.ttt2_apocalypse_retries = (bot.ttt2_apocalypse_retries or 0) + 1
end

-- Reset the retry counter at the start of each round
hook.Add("TTTPrepareRound", "TTTBots_Apocalypse_ResetRetries", function()
    if not TTTBots.Bots then return end
    for _, bot in ipairs(TTTBots.Bots) do
        if IsValid(bot) then
            bot.ttt2_apocalypse_retries = 0
        end
    end
end)
