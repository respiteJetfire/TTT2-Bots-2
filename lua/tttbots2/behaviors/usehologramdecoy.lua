--- behaviors/usehologramdecoy.lua
--- Bot behavior: deploy a hologram decoy when not in active combat,
--- to create a distraction before engaging or to confuse innocents.
---
--- Calls PrimaryAttack() directly on the weapon entity rather than using
--- loco:StartAttack(), which is gated behind reactionDelay and semi-auto
--- click logic in the locomotor — not appropriate for utility activation.

---@class BUseHologramDecoy
TTTBots.Behaviors.UseHologramDecoy = {}

local lib = TTTBots.Lib
local STATUS = TTTBots.STATUS

local UseHologramDecoy = TTTBots.Behaviors.UseHologramDecoy
UseHologramDecoy.Name = "UseHologramDecoy"
UseHologramDecoy.Description = "Deploy a hologram decoy to distract innocents"
UseHologramDecoy.Interruptible = false

--- Maximum number of times the behavior will restart before giving up.
local MAX_RETRIES = 2

function UseHologramDecoy.Validate(bot)
    if not IsValid(bot) or not bot:Alive() then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not bot:HasWeapon("weapon_ttt2_hologram_decoy") then return false end

    -- Don't deploy during active combat
    if IsValid(bot.attackTarget) then return false end

    -- Give up after too many failed attempts this round
    local retries = bot.ttt2_hologram_decoy_retries or 0
    if retries >= MAX_RETRIES then return false end

    -- Random chance gate (deploy opportunistically)
    if math.random(1, 60) > 1 then return false end

    return true
end

function UseHologramDecoy.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "UseHologramDecoy")
    state.step = 0
    state.startTime = CurTime()
    state.fired = false

    local inv = bot:BotInventory()
    if inv then inv:PauseAutoSwitch() end

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("DeployingDecoy", {}, true)
    end

    return STATUS.RUNNING
end

function UseHologramDecoy.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "UseHologramDecoy")
    local elapsed = CurTime() - (state.startTime or CurTime())

    -- If the weapon was consumed (stripped after PrimaryAttack), we're done
    if state.fired and not bot:HasWeapon("weapon_ttt2_hologram_decoy") then
        return STATUS.SUCCESS
    end

    -- Safety timeout
    if elapsed > 3.0 then return STATUS.FAILURE end

    if state.step == 0 then
        -- Step 0: equip the decoy weapon
        bot:SelectWeapon("weapon_ttt2_hologram_decoy")
        state.step = 1
        return STATUS.RUNNING

    elseif state.step == 1 then
        -- Step 1: wait for weapon switch, then call PrimaryAttack directly
        if elapsed < 0.2 then return STATUS.RUNNING end

        local activeWep = bot:GetActiveWeapon()
        if IsValid(activeWep) and activeWep:GetClass() == "weapon_ttt2_hologram_decoy" then
            -- Call PrimaryAttack directly — bypasses locomotor's reactionDelay
            -- and semi-auto click gates
            activeWep:PrimaryAttack()
            state.fired = true
            state.firedTime = CurTime()
            state.step = 2
            return STATUS.RUNNING
        else
            -- Weapon switch didn't complete yet, retry
            if elapsed > 1.0 then
                local wep = bot:GetWeapon("weapon_ttt2_hologram_decoy")
                if IsValid(wep) then
                    bot:SetActiveWeapon(wep)
                end
            else
                bot:SelectWeapon("weapon_ttt2_hologram_decoy")
            end
            return STATUS.RUNNING
        end

    elseif state.step == 2 then
        -- Step 2: wait for weapon to be consumed, then done
        if CurTime() - (state.firedTime or CurTime()) < 0.25 then
            return STATUS.RUNNING
        end

        -- Weapon should be stripped by now
        if not bot:HasWeapon("weapon_ttt2_hologram_decoy") then
            return STATUS.SUCCESS
        end

        -- Still has weapon — PrimaryAttack might not have worked
        return STATUS.FAILURE
    end

    return STATUS.RUNNING
end

function UseHologramDecoy.OnEnd(bot)
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end

    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end

    TTTBots.Behaviors.ClearState(bot, "UseHologramDecoy")
end

function UseHologramDecoy.OnSuccess(bot)
    bot.ttt2_hologram_decoy_retries = 0
end

function UseHologramDecoy.OnFailure(bot)
    bot.ttt2_hologram_decoy_retries = (bot.ttt2_hologram_decoy_retries or 0) + 1
end
