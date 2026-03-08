

local lib = TTTBots.Lib

TTTBots.Behaviors.RegisterRoleWeapon({
    name         = "CreateDeputy",
    description  = "Deputy a player (or random player) to convert them.",
    interruptible = true,
    stateKey     = "DeputyTarget",
    getWeaponFn  = function(inv) return inv:GetDeputyGun() end,
    equipFn      = function(inv) return inv:EquipDeputyGun() end,
    findTargetFn = function(bot) return lib.FindCloseTarget(bot, nil, false, false, true, false) end,
    engageDistance = 1000,
    startChance  = 2,
    validateStartBothConditions = true,
    equipFailureFails = true,
    chatterEvent = "CreatingDeputy",
    chatterTeamOnly = false,
})

local CreateDeputy = TTTBots.Behaviors.CreateDeputy
local STATUS = TTTBots.STATUS
