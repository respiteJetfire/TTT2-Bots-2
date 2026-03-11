

local lib = TTTBots.Lib

TTTBots.Behaviors.RegisterRoleWeapon({
    name         = "CreateSidekick",
    description  = "Sidekick a player (or random player) and ultimately convert them.",
    interruptible = false,
    stateKey     = "SidekickTarget",
    getWeaponFn  = function(inv) return inv:GetJackalGun() end,
    equipFn      = function(inv) return inv:EquipJackalGun() end,
    findTargetFn = function(bot) return lib.FindIsolatedTarget(bot) end,
    engageDistance = 1000,
    witnessThreshold = 2,
    startChance  = 25,
    isConversion = true,  -- Prefer converting in early game over killing
    chatterEvent = "CreatingSidekick",
    chatterTeamOnly = true,
})

local CreateSidekick = TTTBots.Behaviors.CreateSidekick
local STATUS = TTTBots.STATUS

