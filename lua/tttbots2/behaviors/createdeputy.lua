

local lib = TTTBots.Lib

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
