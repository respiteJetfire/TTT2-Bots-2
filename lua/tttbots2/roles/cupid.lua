--- Cupid behaviour for TTT2, a role which is evil and wins by killing all non-allied players
--- but can also convert someone to their side using the sidekick deagle

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_CUPID then return false end

TEAM_JESTER = TEAM_JESTER or 'jesters'

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_LOVER] = true
}

local allyRoles = {
    sidekick = true
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _bh.CreateLovers,
    _prior.Restore,
    _prior.Minge,
    _bh.Stalk,
    _prior.Investigate,
    _prior.Patrol
}

local cupid = TTTBots.RoleData.New("cupid", TEAM_LOVER)
cupid:SetDefusesC4(false)
cupid:SetCanCoordinate(true)
cupid:SetCanHaveRadar(true)
cupid:SetStartsFights(true)
cupid:SetUsesSuspicion(false)
cupid:SetTeam(TEAM_LOVER)
cupid:SetBTree(bTree)
cupid:SetAlliedTeams(allyTeams)
cupid:SetAlliedRoles(allyRoles)
cupid:SetEnemyRoles({"unknown"})
cupid:SetLovesTeammates(true)
TTTBots.Roles.RegisterRole(cupid)

return true
