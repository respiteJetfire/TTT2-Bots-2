--- DOOM SLAYER ROLE WHICH IS EVIL AND WINS BY KILLING ALL OTHER PLAYERS (KOS).

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DOOMGUY then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local allyTeams = {
    [TEAM_DOOMSLAYER] = true,
    [TEAM_JESTER] = true,
}


local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _bh.Roledefib,
    _prior.Restore,
    _bh.Interact,
}

local doomguy = TTTBots.RoleData.New("doomguy", TEAM_DOOMSLAYER)
doomguy:SetDefusesC4(false)
doomguy:SetCanCoordinate(false)
doomguy:SetCanHaveRadar(true)
doomguy:SetStartsFights(true)
doomguy:SetBuyableWeapons({"arccw_mw2_ranger"})
doomguy:SetUsesSuspicion(false)
doomguy:SetTeam(TEAM_DOOMSLAYER)
doomguy:SetBTree(bTree)
doomguy:SetAlliedTeams(allyTeams)
doomguy:SetPreferredWeapon("weapon_dredux_de_supershotgun")
doomguy:SetAutoSwitch(false)
doomguy:SetKOSAll(true)
doomguy:SetKOSedByAll(true)
doomguy:SetLovesTeammates(true)
doomguy:SetEnemyTeams(enemyTeams)
TTTBots.Roles.RegisterRole(doomguy)

return true

