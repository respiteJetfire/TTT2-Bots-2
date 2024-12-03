if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_UNKNOWN then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local allyTeams = {
    [TEAM_JESTER] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.Support,
    _prior.Requests,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

local unknown = TTTBots.RoleData.New("unknown", TEAM_NONE)
unknown:SetDefusesC4(false)
unknown:SetStartsFights(false)
unknown:SetCanCoordinate(false)
unknown:SetUsesSuspicion(false)
unknown:SetTeam(TEAM_NONE)
unknown:SetBTree(bTree)
unknown:SetBuyableWeapons({})
unknown:SetKnowsLifeStates(true)
unknown:SetAlliedTeams(allyTeams)
unknown:SetLovesTeammates(false)
TTTBots.Roles.RegisterRole(unknown)
