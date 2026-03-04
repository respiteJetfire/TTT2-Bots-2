if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_RESTLESS then return false end

TEAM_JESTER = TEAM_JESTER or 'jesters'

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_RESTLESS] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _prior.Convert,
    _bh.Stalk,
    _prior.Patrol,
    _prior.Minge
}

local restless = TTTBots.RoleData.New("restless", TEAM_RESTLESS)
restless:SetDefusesC4(false)
restless:SetCanCoordinate(true)
restless:SetStartsFights(true)
restless:SetCanHaveRadar(true)
restless:SetKnowsLifeStates(true)
restless:SetUsesSuspicion(false)
restless:SetTeam(TEAM_RESTLESS)
restless:SetBTree(bTree)
restless:SetAlliedTeams(allyTeams)
restless:SetLovesTeammates(true)
TTTBots.Roles.RegisterRole(restless)

return true