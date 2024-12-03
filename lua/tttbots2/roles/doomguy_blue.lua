--- DOOM SLAYER ROLE WHICH IS EVIL AND WINS BY KILLING ALL OTHER PLAYERS (KOS).

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DOOMGUY_BLUE then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local allyTeams = {
    [TEAM_DOOMSLAYER_BLUE] = true,
    [TEAM_JESTER] = true,
}


local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _bh.Roledefib,
    _prior.Restore,
    _bh.Interact,
}

local doomguy_blue = TTTBots.RoleData.New("doomguy_blue", TEAM_DOOMSLAYER_BLUE)
doomguy_blue:SetDefusesC4(false)
doomguy_blue:SetCanCoordinate(false)
doomguy_blue:SetCanHaveRadar(true)
doomguy_blue:SetStartsFights(true)
doomguy_blue:SetBuyableWeapons({"arccw_mw2_ranger"})
doomguy_blue:SetUsesSuspicion(false)
doomguy_blue:SetTeam(TEAM_DOOMSLAYER_BLUE)
doomguy_blue:SetBTree(bTree)
doomguy_blue:SetAlliedTeams(allyTeams)
doomguy_blue:SetAutoSwitch(true)
doomguy_blue:SetKOSAll(true)
doomguy_blue:SetKOSedByAll(true)
doomguy_blue:SetLovesTeammates(true)
doomguy_blue:SetEnemyTeams(enemyTeams)
TTTBots.Roles.RegisterRole(doomguy_blue)

return true

