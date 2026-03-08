

local lib = TTTBots.Lib

--- Called to check if the bot has the 'weapon_ttt2_markergun', returns true if the bot has the weapon.
---@param bot Bot
---@return boolean
local function HasMarkerGun(bot)
    if bot:HasWeapon("weapon_ttt2_markergun") then return true end
end

--- Called to get the 'weapon_ttt2_markergun' entity from the bot.
---@param bot Bot
---@return Weapon?
local function GetMarkerGun(bot)
    local wep = bot:GetWeapon("weapon_ttt2_markergun")
    if IsValid(wep) then return wep end
    return wep
end

TTTBots.Behaviors.RegisterRoleWeapon({
    name         = "CreateMarker",
    description  = "Mark a player that is not marked already (TTT2-specific).",
    interruptible = true,
    stateKey     = "MarkerTarget",
    hasWeaponFn  = HasMarkerGun,
    equipDirectFn = GetMarkerGun,
    findTargetFn = function(bot) return lib.FindCloseTarget(bot, nil, false, true, true, true) end,
    engageDistance = 350,
    startChance  = 95,
    validateExtraFn = function(bot) return TTTBots.Lib.IsTTT2() end,
    onEndFn = function(bot, target)
        if not IsValid(target) then return end
        local markedPlayers = MARKER_DATA.marked_players
        local alivePlayers = lib.GetAlivePlayers()
        local alivePlayersCount = #alivePlayers
        local markedPlayersCount = #markedPlayers
        local kosChance = markedPlayersCount / alivePlayersCount >= 0.5 and math.random(1, 2) == 1
        if target:IsBot() and kosChance then
            target:SetAttackTarget(bot, "CREATE_MARKER", 4)
            local chatter = bot:BotChatter()
            if chatter then
                chatter:On("KOS", {player = target:Nick()})
            end
        end
    end,
})

local CreateMarker = TTTBots.Behaviors.CreateMarker
-- Re-expose as public members for external use
CreateMarker.HasMarkerGun = HasMarkerGun
CreateMarker.GetMarkerGun = GetMarkerGun

local STATUS = TTTBots.STATUS
