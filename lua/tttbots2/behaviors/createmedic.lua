
local lib = TTTBots.Lib

--- Called to check if the bot has the weapon_ttt2_medic_deagle.
---@param bot Bot
---@return boolean
local function HasMedicGun(bot)
    if bot:HasWeapon("weapon_ttt2_medic_deagle") then return true end
end

--- Called to get the weapon_ttt2_medic_deagle entity from the bot.
---@param bot Bot
---@return Weapon?
local function GetMedicGun(bot)
    local wep = bot:GetWeapon("weapon_ttt2_medic_deagle")
    if IsValid(wep) then return wep end
    return wep
end

TTTBots.Behaviors.RegisterRoleWeapon({
    name         = "CreateMedic",
    description  = "Medic a player (or random player) to convert them (TTT2-specific).",
    interruptible = true,
    stateKey     = "MedicTarget",
    hasWeaponFn  = HasMedicGun,
    equipDirectFn = GetMedicGun,
    findTargetFn = function(bot) return lib.FindCloseTarget(bot, nil, false, false, true, true) end,
    engageDistance = 1000,
    startChance  = 20,
    isConversion = true,  -- Prefer converting in early game over killing
    validateStartBothConditions = true,
    validateExtraFn = function(bot) return TTTBots.Lib.IsTTT2() end,
})

local CreateMedic = TTTBots.Behaviors.CreateMedic
-- Re-expose as public members for external use
CreateMedic.HasMedicGun = HasMedicGun
CreateMedic.GetMedicGun = GetMedicGun

local STATUS = TTTBots.STATUS

--- Called from externally named HandleRequest(bot, target) which gives a Medic gun if the bot doesn't have one already and sets a target (if provided).
---@param bot Bot
---@param target Player?
function CreateMedic.HandleRequest(bot, target)
    local inv = bot:BotInventory()
    if not (inv and HasMedicGun(bot)) then
        bot:Give("weapon_ttt2_medic_deagle")
    end
    CreateMedic.SetTarget(bot, target)
end
