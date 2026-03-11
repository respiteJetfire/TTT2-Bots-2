--- behaviors/swapdeagle.lua
--- Cursed-role RoleSwap Deagle behavior.
--- Shoots targets at range to swap roles using the addon's native swap system.
--- Includes server-side deagle refill handling since bots lack a client realm.

if not (TTT2 and ROLE_CURSED) then return end

local lib = TTTBots.Lib

--- Server-side refill tracking for bot swap deagles.
--- The addon's refill is client-side only; bots need this workaround.
local botDeagleRefillTimers = {}

local function HandleBotDeagleMiss(bot)
    if not IsValid(bot) then return end
    local cooldown = GetConVar("ttt2_role_swap_deagle_refill_time")
        and GetConVar("ttt2_role_swap_deagle_refill_time"):GetInt() or 30

    local timerName = "TTTBots.SwapDeagle.Refill." .. bot:EntIndex()
    botDeagleRefillTimers[bot] = true

    timer.Create(timerName, cooldown, 1, function()
        botDeagleRefillTimers[bot] = nil
        if not IsValid(bot) then return end
        local wep = bot:GetWeapon("weapon_ttt2_role_swap_deagle")
        if IsValid(wep) then
            wep:SetClip1(1)
        end
    end)
end

--- Hook into EntityFireBullets to detect swap deagle misses for bots.
--- The addon weapon sends a net message on miss to CLIENT; bots have no client.
hook.Add("EntityFireBullets", "TTTBots.SwapDeagle.DetectMiss", function(entity, data)
    if not IsValid(entity) or not entity:IsPlayer() or not entity:IsBot() then return end
    local wep = entity:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "weapon_ttt2_role_swap_deagle" then return end

    -- Queue a check: after a short delay, if the bot is still cursed, the shot missed
    timer.Simple(0.2, function()
        if not IsValid(entity) then return end
        if entity:GetSubRole() == ROLE_CURSED then
            -- Shot missed (if it hit, the bot would no longer be cursed)
            HandleBotDeagleMiss(entity)
        end
    end)
end)

--- Clean up refill timers on round end
hook.Add("TTTEndRound", "TTTBots.SwapDeagle.Cleanup", function()
    for bot, _ in pairs(botDeagleRefillTimers) do
        if IsValid(bot) then
            local timerName = "TTTBots.SwapDeagle.Refill." .. bot:EntIndex()
            timer.Remove(timerName)
        end
    end
    botDeagleRefillTimers = {}
end)

TTTBots.Behaviors.RegisterRoleWeapon({
    name         = "SwapDeagle",
    description  = "Swap roles with a player using the RoleSwap Deagle.",
    interruptible = true,
    stateKey     = "SwapDeagleTarget",
    getWeaponFn  = function(inv) return inv:GetSwapDeagleGun() end,
    equipFn      = function(inv) return inv:EquipSwapDeagleGun() end,
    findTargetFn = function(bot) return lib.FindCloseTarget(bot, nil, false, false, true, false) end,
    engageDistance = 1000,
    startChance  = 40,  -- Cursed should be eager to use this
    isConversion = true,  -- Prefer converting in early game over killing
    validateStartBothConditions = true,
    equipFailureFails = false,
    clipEmptyFails = false,  -- Don't permanently fail; server-side refill handles cooldown
    validateExtraFn = function(bot)
        -- Only allow if the bot is Cursed and the deagle isn't on cooldown
        if not ROLE_CURSED then return false end
        if bot:GetSubRole() ~= ROLE_CURSED then return false end
        if botDeagleRefillTimers[bot] then return false end
        return true
    end,
    chatterEvent = "CursedDeagleFired",
    chatterTeamOnly = false,
})

local SwapDeagle = TTTBots.Behaviors.SwapDeagle
local STATUS = TTTBots.STATUS
