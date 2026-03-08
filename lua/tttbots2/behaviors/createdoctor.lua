

local lib = TTTBots.Lib

--- Called to check if the bot has the weapon_ttt2_doctor_deagle.
---@param bot Bot
---@return boolean
local function HasDoctorGun(bot)
    if bot:HasWeapon("weapon_ttt2_doctor_deagle") then return true end
end

--- Called to get the weapon_ttt2_doctor_deagle entity from the bot.
---@param bot Bot
---@return Weapon?
local function GetDoctorGun(bot)
    local wep = bot:GetWeapon("weapon_ttt2_doctor_deagle")
    if IsValid(wep) then return wep end
    return wep
end

TTTBots.Behaviors.RegisterRoleWeapon({
    name         = "CreateDoctor",
    description  = "Doctor a player (or random player) to convert them (TTT2-specific).",
    interruptible = true,
    stateKey     = "DoctorTarget",
    hasWeaponFn  = HasDoctorGun,
    equipDirectFn = GetDoctorGun,
    findTargetFn = function(bot) return lib.FindCloseTarget(bot, nil, false, false, true, false) end,
    engageDistance = 1000,
    startChance  = 2,
    validateStartBothConditions = true,
    validateExtraFn = function(bot) return TTTBots.Lib.IsTTT2() end,
    chatterEvent = "CreatingDoctor",
    chatterTeamOnly = false,
})

local CreateDoctor = TTTBots.Behaviors.CreateDoctor
-- Re-expose as public members for external use
CreateDoctor.HasDoctorGun = HasDoctorGun
CreateDoctor.GetDoctorGun = GetDoctorGun

local STATUS = TTTBots.STATUS
