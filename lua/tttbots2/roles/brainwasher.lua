--- Jackal behaviour for TTT2, a role which is evil and wins by killing all non-allied players
--- but can also convert someone to their side using the sidekick deagle

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_BRAINWASHER then return false end

TEAM_JESTER = TEAM_JESTER or 'jesters'

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_TRAITOR] = true,
}
local allyRoles = {
    slave = true
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _prior.Convert,
    _prior.Support,
    _prior.Restore,
    _prior.Minge,
    _bh.Stalk,
    _prior.Investigate,
    _prior.Patrol
}

local brainwasher = TTTBots.RoleData.New("brainwasher", TEAM_TRAITOR)
brainwasher:SetDefusesC4(false)
brainwasher:SetCanCoordinate(true)
brainwasher:SetCanHaveRadar(true)
brainwasher:SetStartsFights(true)
brainwasher:SetUsesSuspicion(false)
brainwasher:SetTeam(TEAM_TRAITOR)
brainwasher:SetBTree(bTree)
brainwasher:SetAlliedTeams(allyTeams)
brainwasher:SetAlliedRoles(allyRoles)
brainwasher:SetEnemyTeams({[TEAM_DOOMSLAYER] = true})
brainwasher:SetEnemyRoles({"unknown"})
brainwasher:SetLovesTeammates(true)
TTTBots.Roles.RegisterRole(brainwasher)

return true
