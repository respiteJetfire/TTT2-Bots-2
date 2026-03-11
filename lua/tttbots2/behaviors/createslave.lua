

local lib = TTTBots.Lib

TTTBots.Behaviors.RegisterRoleWeapon({
    name         = "CreateSlave",
    description  = "Slave a player (or random player) and ultimately convert them.",
    interruptible = false,
    stateKey     = "SlaveTarget",
    getWeaponFn  = function(inv) return inv:GetSlaveGun() end,
    equipFn      = function(inv) return inv:EquipSlaveGun() end,
    findTargetFn = function(bot) return lib.FindCloseTarget(bot, nil, false, false, true, true) end,
    engageDistance = 1000,
    startChance  = 25,
    isConversion = true,  -- Prefer converting in early game over killing
    chatterEvent = "CreatingSlave",
    chatterTeamOnly = true,
})

local CreateSlave = TTTBots.Behaviors.CreateSlave
local STATUS = TTTBots.STATUS
