

local lib = TTTBots.Lib

TTTBots.Behaviors.RegisterRoleWeapon({
    name         = "SwapDeagle",
    description  = "Swap a player's weapon using the swap deagle.",
    interruptible = true,
    stateKey     = "SwapDeagleTarget",
    getWeaponFn  = function(inv) return inv:GetSwapDeagleGun() end,
    equipFn      = function(inv) return inv:EquipSwapDeagleGun() end,
    findTargetFn = function(bot) return lib.FindCloseTarget(bot, nil, false, false, true, false) end,
    engageDistance = 1000,
    startChance  = 2,
    validateStartBothConditions = true,
    equipFailureFails = false,
    clipEmptyFails = true,
})

local SwapDeagle = TTTBots.Behaviors.SwapDeagle
local STATUS = TTTBots.STATUS
