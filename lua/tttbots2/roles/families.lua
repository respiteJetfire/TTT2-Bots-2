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

local roleDescription = "The Families role's objective is to eliminate the other gangs and win the game. You are a member of the Families and can use their weapons. Be careful not to attack your own teammates!"

local bTree = {
    _prior.Chatter,
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
families:SetUsesSuspicion(false)
families:SetTeam(TEAM_FAMILIES)
families:SetBTree(bTree)
families:SetAlliedTeams(allyTeams)
families:SetLovesTeammates(true)
families:SetEnemyTeams(enemyTeams)
families:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(families)

return true
