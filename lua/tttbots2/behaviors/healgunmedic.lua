
local lib = TTTBots.Lib

TTTBots.Behaviors.RegisterRoleWeapon({
    name         = "HealgunMedic",
    description  = "Heal any low-HP player to restore their HP to Max Health (Medic role).",
    interruptible = true,
    stateKey     = "HealgunMedicTarget",
    getWeaponFn  = function(inv) return inv:GetMedicMedigun() end,
    equipFn      = function(inv) return inv:EquipMedicMedigun() end,
    findTargetFn = function(bot) return lib.FindCloseLowHPTarget(bot) end,
    engageDistance = 1000,
    alwaysStart = true,
    successConditionFn = function(bot, target)
        return target:Health() >= target:GetMaxHealth()
    end,
})

local HealgunMedic = TTTBots.Behaviors.HealgunMedic
local STATUS = TTTBots.STATUS
