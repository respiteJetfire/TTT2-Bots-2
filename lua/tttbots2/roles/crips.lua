--- Crips Role for TTT2, a role which is evil and wins by killing all non-allied players

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_CRIPS then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local allyTeams = {
    [TEAM_CRIPS] = true,
}

local enemyTeams = {
    [TEAM_BLOODS] = true,
    [TEAM_BALLAS] = true,
    [TEAM_FAMILIES] = true,
    [TEAM_HOOVERS] = true,
}

local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _bh.Roledefib,
    _prior.Restore,
    _bh.Interact,
}
local crips = TTTBots.RoleData.New("crips", TEAM_CRIPS)
crips:SetDefusesC4(false)
crips:SetCanCoordinate(true)
crips:SetCanHaveRadar(true)
crips:SetStartsFights(true)
crips:SetBuyableWeapons({"arccw_mw2_ak47", "arccw_mw2_m4"})
crips:SetUsesSuspicion(false)
crips:SetTeam(TEAM_CRIPS)
crips:SetBTree(bTree)
crips:SetAlliedTeams(allyTeams)
crips:SetLovesTeammates(true)
crips:SetEnemyTeams(enemyTeams)
TTTBots.Roles.RegisterRole(crips)

return true
