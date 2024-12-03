--- DOOM SLAYER ROLE WHICH IS EVIL AND WINS BY KILLING ALL OTHER PLAYERS (KOS).

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DOOMGUY_RED then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local allyTeams = {
    [TEAM_DOOMSLAYER_RED] = true,
    [TEAM_JESTER] = true,
}


local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _bh.Roledefib,
    _prior.Restore,
    _bh.Interact,
}

local doomguy_red = TTTBots.RoleData.New("doomguy_red", TEAM_DOOMSLAYER_RED)
doomguy_red:SetDefusesC4(false)
doomguy_red:SetCanCoordinate(false)
doomguy_red:SetCanHaveRadar(true)
doomguy_red:SetStartsFights(true)
doomguy_red:SetBuyableWeapons({"arccw_mw2_ranger"})
doomguy_red:SetUsesSuspicion(false)
doomguy_red:SetTeam(TEAM_DOOMSLAYER_RED)
doomguy_red:SetBTree(bTree)
doomguy_red:SetAlliedTeams(allyTeams)
doomguy_red:SetAutoSwitch(true)
doomguy_red:SetKOSAll(true)
doomguy_red:SetKOSedByAll(true)
doomguy_red:SetLovesTeammates(true)
doomguy_red:SetEnemyTeams(enemyTeams)
TTTBots.Roles.RegisterRole(doomguy_red)

return true

