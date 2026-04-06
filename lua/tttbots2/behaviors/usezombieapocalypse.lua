--- behaviors/usezombieapocalypse.lua
--- Behavior: equip the Zombie Apocalypse SWEP and immediately activate it.
---
--- The weapon is a single-use traitor SWEP that spawns a horde of team-aware
--- HL2 zombies (npc_zombie, npc_fastzombie, npc_poisonzombie) at hidden
--- positions around the map.  Zombies ignore allies of the user and
--- persistently chase the closest living enemy.
---
--- Because this weapon:
---   • does NOT hurt teammates (fully team-safe)
---   • is extremely powerful (zombie horde that auto-targets enemies)
---   • is single-use and consumed immediately on PrimaryAttack
---
--- ...bots should activate it at the very first opportunity after acquiring
--- it — no target aiming, sky-check, or witness gate required.
---
--- Implementation mirrors ActivateSmartBullets: equip → call PrimaryAttack()
--- directly on the weapon entity → switch back to best combat weapon.

TTTBots = TTTBots or {}
TTTBots.Behaviors = TTTBots.Behaviors or {}

---@class BUseZombieApocalypse
TTTBots.Behaviors.UseZombieApocalypse = {}

local lib = TTTBots.Lib

---@class BUseZombieApocalypse
local UseZombieApocalypse = TTTBots.Behaviors.UseZombieApocalypse
UseZombieApocalypse.Name          = "UseZombieApocalypse"
UseZombieApocalypse.Description   = "Unleashing the zombie apocalypse"
UseZombieApocalypse.Interruptible = false

local STATUS = TTTBots.STATUS

--- Weapon classname — must match the SWEP's class exactly.
local WEAPON_CLASS = "weapon_ttt_zombieapocalypse"

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

    -- Prefer a special primary (e.g. assault rifles) first
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
--- and at least one enemy is still alive.  No target aiming required
--- because the weapon auto-targets all enemies.
---@param bot Bot
---@return boolean
function UseZombieApocalypse.Validate(bot)
    if not IsValid(bot) then return false end
    if not bot:Alive() then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not bot:HasWeapon(WEAPON_CLASS) then return false end

    -- Don't retry after too many consecutive failures
    local retries = bot.ttt2_zombieapoc_retries or 0
    if retries >= MAX_RETRIES then return false end

    -- Need at least one living enemy to make spawning worthwhile
    if CountLiveEnemies(bot) < 1 then return false end

    return true
end

---@param bot Bot
---@return BStatus
function UseZombieApocalypse.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "UseZombieApocalypse")
    state.step      = 0
    state.startTime = CurTime()
    state.fired     = false

    -- Prevent the inventory auto-switch from fighting us
    local inv = bot:BotInventory()
    if inv then inv:PauseAutoSwitch() end

    return STATUS.RUNNING
end

---@param bot Bot
---@return BStatus
function UseZombieApocalypse.OnRunning(bot)
    local state   = TTTBots.Behaviors.GetState(bot, "UseZombieApocalypse")
    local step    = state.step or 0
    local elapsed = CurTime() - (state.startTime or CurTime())

    -- Safety timeout: abort after 4 seconds to avoid getting stuck
    if elapsed > 4.0 then
        return STATUS.FAILURE
    end

    -- If the weapon has already been consumed (stripped after use), we're done
    if not bot:HasWeapon(WEAPON_CLASS) and state.fired then
        SwitchToCombatWeapon(bot)
        return STATUS.SUCCESS
    end

    if step == 0 then
        -- Step 0: select the Zombie Apocalypse weapon
        local wep = bot:GetWeapon(WEAPON_CLASS)
        if not IsValid(wep) then return STATUS.FAILURE end
        bot:SelectWeapon(WEAPON_CLASS)
        state.step = 1
        return STATUS.RUNNING

    elseif step == 1 then
        -- Step 1: wait briefly for the weapon switch to complete, then fire
        -- (0.2 s matches the delay used by ActivateSmartBullets)
        if elapsed < 0.2 then return STATUS.RUNNING end

        local activeWep = bot:GetActiveWeapon()
        if IsValid(activeWep) and activeWep:GetClass() == WEAPON_CLASS then
            -- Call PrimaryAttack() directly — bypasses the locomotor's
            -- reactionDelay and semi-auto click logic (designed for combat,
            -- not single-use utility items like this SWEP).
            activeWep:PrimaryAttack()
            state.fired     = true
            state.firedTime = CurTime()
            state.step      = 2
            return STATUS.RUNNING
        else
            -- Weapon switch hasn't settled yet — keep retrying the select
            if elapsed > 1.5 then
                -- Fallback: force-equip via SetActiveWeapon
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
        -- Step 2: wait for the SWEP to process the attack (it has a 1.5 s
        -- internal timer before stripping itself).  Switch to a combat weapon
        -- promptly so the bot isn't standing around defenceless.
        local timeSinceFire = CurTime() - (state.firedTime or CurTime())
        if timeSinceFire >= 0.3 then
            SwitchToCombatWeapon(bot)
            return STATUS.SUCCESS
        end
        return STATUS.RUNNING
    end

    return STATUS.RUNNING
end

function UseZombieApocalypse.OnEnd(bot)
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end

    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end

    TTTBots.Behaviors.ClearState(bot, "UseZombieApocalypse")
end

function UseZombieApocalypse.OnSuccess(bot)
    -- Reset the retry counter on success
    bot.ttt2_zombieapoc_retries = 0

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("ZombieApocalypseActivated", {}, true)
    end
end

function UseZombieApocalypse.OnFailure(bot)
    -- Increment retry counter to cap the number of attempts per round
    bot.ttt2_zombieapoc_retries = (bot.ttt2_zombieapoc_retries or 0) + 1
end

-- Reset the retry counter at the start of each round so bots always get fresh
-- attempts when they acquire the weapon again.
hook.Add("TTTPrepareRound", "TTTBots_ZombieApocalypse_ResetRetries", function()
    if not TTTBots.Bots then return end
    for _, bot in ipairs(TTTBots.Bots) do
        if IsValid(bot) then
            bot.ttt2_zombieapoc_retries = 0
        end
    end
end)
