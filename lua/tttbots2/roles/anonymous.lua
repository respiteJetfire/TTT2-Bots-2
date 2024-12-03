--- Anonymous behaviour for TTT2, a role which is evil and wins by killing all non-allied players
--- but can also convert someone to their side using the sidekick deagle

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_ANONYMOUS then return false end

TEAM_JESTER = TEAM_JESTER or 'jesters'

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_ANONYMOUS] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _prior.Convert,
    _bh.Roledefib,
    _prior.Restore,
    _prior.Minge,
    _bh.Stalk,
    _prior.Investigate,
    _prior.Patrol
}

local anonymous = TTTBots.RoleData.New("anonymous", TEAM_ANONYMOUS)
anonymous:SetDefusesC4(false)
anonymous:SetCanCoordinate(false)
anonymous:SetCanHaveRadar(true)
anonymous:SetStartsFights(true)
anonymous:SetUsesSuspicion(false)
anonymous:SetTeam(TEAM_ANONYMOUS)
anonymous:SetBTree(bTree)
anonymous:SetAlliedTeams(allyTeams)
anonymous:SetEnemyRoles({"unknown"})
anonymous:SetLovesTeammates(false)
TTTBots.Roles.RegisterRole(anonymous)

return true
