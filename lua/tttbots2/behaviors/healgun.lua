
local lib = TTTBots.Lib

TTTBots.Behaviors.RegisterRoleWeapon({
    name         = "Healgun",
    description  = "Heal a player (or random player) to restore their HP to Max Health.",
    interruptible = true,
    stateKey     = "HealgunTarget",
    getWeaponFn  = function(inv) return inv:GetMedicMedigun() end,
    equipFn      = function(inv) return inv:EquipMedigun() end,
    findTargetFn = function(bot)
        if bot:GetTeam() == TEAM_NONE then
            return TTTBots.Lib.FindCloseLowHPTarget(bot, false, 1000, 500)
        else
            return TTTBots.Lib.FindCloseLowHPTarget(bot, true, 600, 300)
        end
    end,
    engageDistance = 1000,
    alwaysStart = true,
    successConditionFn = function(bot, target)
        return target:Health() >= target:GetMaxHealth()
    end,
    cleanupOnSuccess = true,
})

local Healgun = TTTBots.Behaviors.Healgun
local STATUS = TTTBots.STATUS

--- Called in the sv_chatter function when a bot is requested to healgun a player.
---@param bot Bot
---@param target Player
function Healgun.HandleRequest(bot, target)
    local response = true
    if not IsValid(target) then response = false end
    local inv = bot:BotInventory()
    if not (inv and inv:GetMedicMedigun()) then response = false end
    if target:Health() >= target:GetMaxHealth() then response = false end
    if not Healgun.ValidateTarget(bot, target) then response = false end
    if response then
        local chatter = bot:BotChatter()
        local teamOnly = (bot:GetTeam() == target:GetTeam() and bot:GetTeam() ~= TEAM_INNOCENT) or false
        if chatter and chatter.On then chatter:On("HealAccepted", { player = target:Nick() }, teamOnly, math.random(1, 4)) end
        Healgun.SetTarget(bot, target)
    else
        local chatter = bot:BotChatter()
        local teamOnly = (bot:GetTeam() == target:GetTeam() and bot:GetTeam() ~= TEAM_INNOCENT) or false
        if chatter and chatter.On then chatter:On("HealRefused", { player = target:Nick() }, teamOnly, math.random(1, 4)) end
    end
end
