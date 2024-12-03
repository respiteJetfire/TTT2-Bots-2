if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_FAMILIES then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local allyTeams = {
    [TEAM_FAMILIES] = true,
}

local enemyTeams = {
    [TEAM_CRIPS] = true,
    [TEAM_BALLAS] = true,
    [TEAM_BLOODS] = true,
    [TEAM_HOOVERS] = true,
}

local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _bh.Roledefib,
    _prior.Restore,
    _bh.Interact,
}
local families = TTTBots.RoleData.New("families", TEAM_FAMILIES)
families:SetDefusesC4(false)
families:SetCanCoordinate(true)
families:SetCanHaveRadar(true)
families:SetStartsFights(true)
families:SetBuyableWeapons({"arccw_mw2_ak47", "arccw_mw2_m4"})
families:SetUsesSuspicion(false)
families:SetTeam(TEAM_FAMILIES)
families:SetBTree(bTree)
families:SetAlliedTeams(allyTeams)
families:SetLovesTeammates(true)
families:SetEnemyTeams(enemyTeams)
TTTBots.Roles.RegisterRole(families)

return true
