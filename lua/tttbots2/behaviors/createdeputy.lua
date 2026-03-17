

local lib = TTTBots.Lib

--- ----------------------------------------------------------------
--- Server-side deagle refill for bots.
--- The role-deagle addons handle refill entirely client-side via net
--- messages, but bots have no client realm. This detects missed shots
--- and refills the clip after the configured cooldown.
--- Covers: Deputy, Sidekick, Slave deagles.
--- ----------------------------------------------------------------

local DEAGLE_REFILL_CONFIG = {
    ["weapon_ttt2_deputydeagle"] = {
        refillCvar   = "ttt2_dep_deagle_refill",
        cooldownCvar = "ttt2_dep_deagle_refill_cd",
        timerPrefix  = "TTTBots.DeputyDeagle.Refill.",
    },
    ["weapon_ttt2_sidekickdeagle"] = {
        refillCvar   = "ttt2_siki_deagle_refill",
        cooldownCvar = "ttt2_siki_deagle_refill_cd",
        timerPrefix  = "TTTBots.SidekickDeagle.Refill.",
    },
    ["weapon_ttt2_slavedeagle"] = {
        refillCvar   = "ttt2_slave_deagle_refill",
        cooldownCvar = "ttt2_slave_deagle_refill_cd",
        timerPrefix  = "TTTBots.SlaveDeagle.Refill.",
    },
}

--- Track which bots have active refill timers so we can clean up
local botDeagleRefillTimers = {}

local function HandleBotDeagleMissRefill(bot, weaponClass)
    if not IsValid(bot) then return end
    local cfg = DEAGLE_REFILL_CONFIG[weaponClass]
    if not cfg then return end

    local refillEnabled = GetConVar(cfg.refillCvar)
    if refillEnabled and not refillEnabled:GetBool() then return end

    local cooldown = GetConVar(cfg.cooldownCvar)
    cooldown = cooldown and cooldown:GetInt() or 120

    local timerName = cfg.timerPrefix .. bot:EntIndex()
    botDeagleRefillTimers[timerName] = true

    timer.Create(timerName, cooldown, 1, function()
        botDeagleRefillTimers[timerName] = nil
        if not IsValid(bot) then return end
        local wep = bot:GetWeapon(weaponClass)
        if IsValid(wep) then
            wep:SetClip1(1)
        end
    end)
end

--- Hook into EntityFireBullets to detect deagle misses for bots.
--- After a short delay, check if the weapon still exists and has 0 clip.
--- A hit removes the weapon (deputy/sidekick/slave callbacks), so if it's
--- still present with 0 clip, the shot missed.
hook.Add("EntityFireBullets", "TTTBots.RoleDeagle.DetectMiss", function(entity, data)
    if not IsValid(entity) or not entity:IsPlayer() or not entity:IsBot() then return end
    local wep = entity:GetActiveWeapon()
    if not IsValid(wep) then return end
    local weaponClass = wep:GetClass()
    if not DEAGLE_REFILL_CONFIG[weaponClass] then return end

    -- After a short delay, check if the shot missed (weapon still exists with empty clip)
    timer.Simple(0.3, function()
        if not IsValid(entity) then return end
        local w = entity:GetWeapon(weaponClass)
        if IsValid(w) and w:Clip1() <= 0 then
            HandleBotDeagleMissRefill(entity, weaponClass)
        end
    end)
end)

--- Clean up refill timers on round end
hook.Add("TTTEndRound", "TTTBots.RoleDeagle.Cleanup", function()
    for timerName, _ in pairs(botDeagleRefillTimers) do
        timer.Remove(timerName)
    end
    botDeagleRefillTimers = {}
end)

--- ----------------------------------------------------------------

TTTBots.Behaviors.RegisterRoleWeapon({
    name         = "CreateDeputy",
    description  = "Deputy a player (or random player) to convert them.",
    interruptible = true,
    stateKey     = "DeputyTarget",
    getWeaponFn  = function(inv) return inv:GetDeputyGun() end,
    equipFn      = function(inv) return inv:EquipDeputyGun() end,
    findTargetFn = function(bot) return lib.FindCloseInnocentTarget(bot) end,
    engageDistance = 1000,
    startChance  = 25,
    isConversion = true,  -- Prefer converting in early game
    validateStartBothConditions = true,
    equipFailureFails = true,
    chatterEvent = "CreatingDeputy",
    chatterTeamOnly = false,
})

local CreateDeputy = TTTBots.Behaviors.CreateDeputy
local STATUS = TTTBots.STATUS
