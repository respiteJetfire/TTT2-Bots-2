if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_HOOVERS then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local allyTeams = {
    [TEAM_HOOVERS] = true,
}

local enemyTeams = {
    [TEAM_CRIPS] = true,
    [TEAM_BALLAS] = true,
    [TEAM_BLOODS] = true,
    [TEAM_FAMILIES] = true,
}

local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _bh.Roledefib,
    _prior.Restore,
    _bh.Interact,
}
local hoovers = TTTBots.RoleData.New("hoovers", TEAM_HOOVERS)
hoovers:SetDefusesC4(false)
hoovers:SetCanCoordinate(true)
hoovers:SetCanHaveRadar(true)
hoovers:SetStartsFights(true)
hoovers:SetBuyableWeapons({"arccw_mw2_ak47", "arccw_mw2_m4"})
hoovers:SetUsesSuspicion(false)
hoovers:SetTeam(TEAM_HOOVERS)
hoovers:SetBTree(bTree)
hoovers:SetAlliedTeams(allyTeams)
hoovers:SetLovesTeammates(true)
hoovers:SetEnemyTeams(enemyTeams)
TTTBots.Roles.RegisterRole(hoovers)

return true
