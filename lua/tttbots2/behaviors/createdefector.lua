
local lib = TTTBots.Lib

--- Called to check if the bot has the weapon_ttt2_defector_deagle.
---@param bot Bot
---@return boolean
local function HasDefectorGun(bot)
    if bot:HasWeapon("weapon_ttt2_defector_deagle") then return true end
end

--- Called to get the weapon_ttt2_defector_deagle entity from the bot.
---@param bot Bot
---@return Weapon?
local function GetDefectorGun(bot)
    local wep = bot:GetWeapon("weapon_ttt2_defector_deagle")
    if IsValid(wep) then return wep end
    return wep
end

TTTBots.Behaviors.RegisterRoleWeapon({
    name         = "CreateDefector",
    description  = "Defect a player by firing the defector deagle (TTT2-specific).",
    interruptible = true,
    stateKey     = "DefectorTarget",
    hasWeaponFn  = HasDefectorGun,
    equipDirectFn = GetDefectorGun,
    findTargetFn = function(bot) return lib.FindCloseTarget(bot, nil, false, false, true, true) end,
    engageDistance = 1000,
    minDistance    = 300,
    startChance  = 5,
    validateStartBothConditions = true,
    validateExtraFn = function(bot) return TTTBots.Lib.IsTTT2() end,
    chatterEvent = "CreatingDefector",
    chatterTeamOnly = true,
    onFireFn = function(bot, target)
        target:Give("weapon_ttt_jihad_bomb")
    end,
})

local CreateDefector = TTTBots.Behaviors.CreateDefector
-- Re-expose as public members for external use
CreateDefector.HasDefectorGun = HasDefectorGun
CreateDefector.GetDefectorGun = GetDefectorGun

local STATUS = TTTBots.STATUS

--- Called from externally named HandleRequest(bot, target) which gives a defector gun if the bot doesn't have one already and sets a target (if provided).
---@param bot Bot
---@param target Player
function CreateDefector.HandleRequest(bot, target)
    if not IsValid(bot) then return end
    local inv = bot:BotInventory()
    if not (inv and HasDefectorGun(bot)) then
        bot:Give("weapon_ttt2_defector_deagle")
    end
    CreateDefector.SetTarget(bot, target)
end
