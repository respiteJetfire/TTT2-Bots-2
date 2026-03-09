

local lib = TTTBots.Lib

TTTBots.Behaviors.RegisterRoleWeapon({
    name         = "CreateCursed",
    description  = "Curse a player (or random player) at stand-off range.",
    interruptible = false,
    stateKey     = "CursedTarget",
    getWeaponFn  = function(inv) return inv:GetCursedGun() end,
    equipFn      = function(inv) return inv:EquipCursedGun() end,
    findTargetFn = function(bot) return lib.FindCloseTarget(bot, nil, false, false, true, true) end,
    engageDistance = 1000,
    minDistance    = 300,
    startChance  = 5,
    validateStartBothConditions = true,
    chatterEvent = "CreatingCursed",
    chatterTeamOnly = true,
})

local CreateCursed = TTTBots.Behaviors.CreateCursed
local STATUS = TTTBots.STATUS

--- Called from externally named HandleRequest(bot, target) which gives a Cursed gun if the bot doesn't have one already and sets a target (if provided).
--- Only traitor-team bots should be able to use the Cursed Deagle (it's a traitor buyable).
---@param bot Bot
---@param target Player?
function CreateCursed.HandleRequest(bot, target)
    if not IsValid(bot) then return end

    -- Only allow traitor-team bots to receive/use the cursed deagle
    local team = bot:GetTeam()
    if team ~= TEAM_TRAITOR then return end

    local inv = bot:BotInventory()
    if not inv then return end
    if not inv:GetCursedGun() then
        bot:Give("weapon_ttt2_cursed_deagle")
    end
    CreateCursed.SetTarget(bot, target)
end
