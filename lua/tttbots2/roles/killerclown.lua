if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_KILLERCLOWN then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_CLOWN] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

local killerclown = TTTBots.RoleData.New("killerclown", TEAM_CLOWN)
killerclown:SetDefusesC4(false)
killerclown:SetStartsFights(true)
killerclown:SetCanCoordinate(true)
killerclown:SetUsesSuspicion(false)
killerclown:SetTeam(TEAM_CLOWN)
killerclown:SetBTree(bTree)
killerclown:SetBuyableWeapons({})
killerclown:SetKOSAll(true)
killerclown:SetKOSedByAll(false)
killerclown:SetNeutralOverride(false)
killerclown:SetKnowsLifeStates(true)
killerclown:SetAlliedTeams(allyTeams)
killerclown:SetLovesTeammates(false)
TTTBots.Roles.RegisterRole(killerclown)

return true
