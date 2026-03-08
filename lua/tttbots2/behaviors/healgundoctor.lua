
local lib = TTTBots.Lib

TTTBots.Behaviors.RegisterRoleWeapon({
    name         = "HealgunDoctor",
    description  = "Heal a same-team player to restore their HP to 100 (Doctor role).",
    interruptible = true,
    stateKey     = "HealgunDoctorTarget",
    getWeaponFn  = function(inv) return inv:GetStandardMedigun() end,
    equipFn      = function(inv) return inv:EquipStandardMedigun() end,
    findTargetFn = function(bot) return lib.FindCloseLowHPTargetSameTeam(bot) end,
    engageDistance = 1000,
    startChance  = 50,
    successConditionFn = function(bot, target)
        return target:Health() >= 100
    end,
})

local HealgunDoctor = TTTBots.Behaviors.HealgunDoctor
local STATUS = TTTBots.STATUS
