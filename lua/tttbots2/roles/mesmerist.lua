--- Jackal behaviour for TTT2, a role which is evil and wins by killing all non-allied players
--- but can also convert someone to their side using the sidekick deagle

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_MESMERIST then return false end

TEAM_JESTER = TEAM_JESTER or 'jesters'

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_TRAITOR] = true,
}
local allyRoles = {
    thrall = true
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _prior.Convert,
    _prior.Restore,
    _prior.Minge,
    _bh.Stalk,
    _prior.Investigate,
    _prior.Patrol
}

local mesmerist = TTTBots.RoleData.New("mesmerist", TEAM_TRAITOR)
mesmerist:SetDefusesC4(false)
mesmerist:SetCanCoordinate(true)
mesmerist:SetCanHaveRadar(true)
mesmerist:SetStartsFights(true)
mesmerist:SetUsesSuspicion(false)
mesmerist:SetTeam(TEAM_TRAITOR)
mesmerist:SetBTree(bTree)
mesmerist:SetAlliedTeams(allyTeams)
mesmerist:SetAlliedRoles(allyRoles)
mesmerist:SetEnemyRoles({"unknown"})
mesmerist:SetEnemyTeams({[TEAM_DOOMSLAYER] = true})
mesmerist:SetLovesTeammates(true)
TTTBots.Roles.RegisterRole(mesmerist)

return true
