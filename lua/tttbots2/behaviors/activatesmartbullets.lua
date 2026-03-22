--- behaviors/activatesmartbullets.lua
--- Behavior: equip the Smart Bullets SWEP, fire primary to activate the buff,
--- then switch back to the best combat weapon. The SWEP is consumed on use.
---
--- The activation calls PrimaryAttack() directly on the weapon entity rather
--- than relying on the locomotor's IN_ATTACK pipeline, which is gated behind
--- reactionDelay and semi-auto click logic — neither of which is appropriate
--- for a one-shot utility activation.

---@class BActivateSmartBullets
TTTBots.Behaviors.ActivateSmartBullets = {}

local lib = TTTBots.Lib

---@class BActivateSmartBullets
local ActivateSmartBullets = TTTBots.Behaviors.ActivateSmartBullets
ActivateSmartBullets.Name = "ActivateSmartBullets"
ActivateSmartBullets.Description = "Activating smart bullets"
ActivateSmartBullets.Interruptible = false

local STATUS = TTTBots.STATUS

--- Maximum number of times the behavior will restart before giving up.
--- Prevents infinite validate→start→timeout→validate loops.
local MAX_RETRIES = 2

--- Validate: should we activate Smart Bullets right now?
---@param bot Bot
---@return boolean
function ActivateSmartBullets.Validate(bot)
    if not IsValid(bot) then return false end
    if not bot:Alive() then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Must have the weapon in inventory
    if not bot:HasWeapon("weapon_ttt2_smart_bullets") then return false end

    -- Must not already have the buff active
    if bot.ttt2_smart_bullets_active then return false end

    -- Give up after too many failed attempts this round
    local retries = bot.ttt2_smart_bullets_retries or 0
    if retries >= MAX_RETRIES then return false end

    -- Must have a real combat weapon to fire during the buff
    local inv = bot:BotInventory()
    if not inv then return false end
    if not (inv:HasPrimary() or inv:HasSecondary() or inv:GetSpecialPrimary()) then return false end

    -- Tactical gate: only activate when we have a target or a reason to fight
    local hasTarget = IsValid(bot.attackTarget)
    -- Also consider activating proactively if personality is aggressive
    local personality = bot:BotPersonality()
    local isAggressive = personality and (
        personality:GetTraitBool("aggressive")
        or personality:GetTraitBool("hothead")
        or personality:GetTraitBool("tryhard")
    )

    -- Aggressive/tryhard bots can activate when they see ANY non-ally alive and in view
    if not hasTarget and isAggressive then
        local visibles = lib.GetAllVisible(bot:EyePos(), true, bot)
        hasTarget = #visibles > 0
    end

    return hasTarget
end

--- Called when the behavior starts
---@param bot Bot
---@return BStatus
function ActivateSmartBullets.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ActivateSmartBullets")
    state.step = 0
    state.startTime = CurTime()
    state.fired = false

    -- Pause inventory auto-switch so it doesn't fight us
    local inv = bot:BotInventory()
    if inv then inv:PauseAutoSwitch() end

    return STATUS.RUNNING
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

--- Called each tick while running
---@param bot Bot
---@return BStatus
function ActivateSmartBullets.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ActivateSmartBullets")
    local step = state.step or 0
    local elapsed = CurTime() - (state.startTime or CurTime())

    -- If the buff became active (weapon fired & consumed), we're done
    if bot.ttt2_smart_bullets_active then
        SwitchToCombatWeapon(bot)

        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("SmartBulletsActivated", {}, true)
        end

        return STATUS.SUCCESS
    end

    -- Safety timeout: if we've been running more than 3 seconds, abort
    if elapsed > 3.0 then
        return STATUS.FAILURE
    end

    if step == 0 then
        -- Step 0: Select the Smart Bullets weapon
        local wep = bot:GetWeapon("weapon_ttt2_smart_bullets")
        if not IsValid(wep) then return STATUS.FAILURE end
        bot:SelectWeapon("weapon_ttt2_smart_bullets")
        state.step = 1
        return STATUS.RUNNING

    elseif step == 1 then
        -- Step 1: Wait for weapon to be equipped, then call PrimaryAttack directly
        if elapsed < 0.2 then return STATUS.RUNNING end -- give time for weapon switch

        local activeWep = bot:GetActiveWeapon()
        if IsValid(activeWep) and activeWep:GetClass() == "weapon_ttt2_smart_bullets" then
            -- Call PrimaryAttack directly — bypasses the locomotor's reactionDelay
            -- and semi-auto click logic which are designed for combat, not utility activation
            activeWep:PrimaryAttack()
            state.fired = true
            state.firedTime = CurTime()
            state.step = 2
            return STATUS.RUNNING
        else
            -- Weapon switch didn't complete yet, retry select
            if elapsed > 1.0 then
                -- Waited too long for switch, try SetActiveWeapon as fallback
                local wep = bot:GetWeapon("weapon_ttt2_smart_bullets")
                if IsValid(wep) then
                    bot:SetActiveWeapon(wep)
                end
            else
                bot:SelectWeapon("weapon_ttt2_smart_bullets")
            end
            return STATUS.RUNNING
        end

    elseif step == 2 then
        -- Step 2: Wait briefly for the weapon to be consumed, then switch back
        -- The SWEP strips itself via timer.Simple(0.1) after PrimaryAttack
        if elapsed < (state.firedTime - state.startTime + 0.25) then
            return STATUS.RUNNING
        end

        SwitchToCombatWeapon(bot)

        -- Verify the buff actually activated
        if bot.ttt2_smart_bullets_active then
            local chatter = bot:BotChatter()
            if chatter and chatter.On then
                chatter:On("SmartBulletsActivated", {}, true)
            end
            return STATUS.SUCCESS
        end

        -- PrimaryAttack was called but buff didn't activate — weapon may have
        -- had an issue. Fail so we can potentially retry.
        return STATUS.FAILURE
    end

    return STATUS.RUNNING
end

--- Cleanup when the behavior ends
---@param bot Bot
function ActivateSmartBullets.OnEnd(bot)
    local loco = bot:BotLocomotor()
    if loco then
        loco:StopAttack()
    end

    -- Resume inventory auto-switch
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end

    TTTBots.Behaviors.ClearState(bot, "ActivateSmartBullets")
end

function ActivateSmartBullets.OnSuccess(bot)
    -- Reset retry counter on success
    bot.ttt2_smart_bullets_retries = 0
end

function ActivateSmartBullets.OnFailure(bot)
    -- Increment retry counter to prevent infinite loops
    bot.ttt2_smart_bullets_retries = (bot.ttt2_smart_bullets_retries or 0) + 1
end
