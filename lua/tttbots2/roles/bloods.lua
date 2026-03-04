--- Bloods behavior for TTT2, a role which is evil and wins by killing all other players.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_BLOODS then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local allyTeams = {
    [TEAM_BLOODS] = true,
}

local enemyTeams = {
    [TEAM_CRIPS] = true,
    [TEAM_BALLAS] = true,
    [TEAM_FAMILIES] = true,
    [TEAM_HOOVERS] = true,
}

local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _bh.Roledefib,
    _prior.Restore,
    _bh.Interact,
}

local roleDescription = "The Bloods role's objective is to eliminate the other gangs and win the game. You are a member of the Bloods and can use their weapons. Be careful not to attack your own teammates!"
local bloods = TTTBots.RoleData.New("bloods", TEAM_BLOODS)
bloods:SetDefusesC4(false)
bloods:SetCanCoordinate(true)
bloods:SetCanHaveRadar(true)
bloods:SetStartsFights(true)
bloods:SetUsesSuspicion(false)
bloods:SetTeam(TEAM_BLOODS)
bloods:SetBTree(bTree)
bloods:SetAlliedTeams(allyTeams)
bloods:SetLovesTeammates(true)
bloods:SetEnemyTeams(enemyTeams)
bloods:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(bloods)

return true
