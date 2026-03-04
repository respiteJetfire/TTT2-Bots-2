--- Ballas Behavior for TTT2, a role which is evil and wins by killing all non-allied players

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_BALLAS then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local allyTeams = {
    [TEAM_BALLAS] = true,
}

local enemyTeams = {
    [TEAM_CRIPS] = true,
    [TEAM_BLOODS] = true,
    [TEAM_FAMILIES] = true,
    [TEAM_HOOVERS] = true,
}

local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _bh.Roledefib,
    _prior.AttackTarget,
    _prior.Restore,
    _bh.Interact,
}
local roleDescription = "The Ballas role's objective is to eliminate the other gangs and win the game. You are a member of the Ballas and can use their weapons. Be careful not to attack your own teammates!"
local ballas = TTTBots.RoleData.New("ballas", TEAM_BALLAS)
ballas:SetDefusesC4(false)
ballas:SetCanCoordinate(true)
ballas:SetCanHaveRadar(true)
ballas:SetStartsFights(true)
ballas:SetUsesSuspicion(false)
ballas:SetTeam(TEAM_BALLAS)
ballas:SetBTree(bTree)
ballas:SetAlliedTeams(allyTeams)
ballas:SetLovesTeammates(true)
ballas:SetEnemyTeams(enemyTeams)
ballas:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(ballas)

return true
