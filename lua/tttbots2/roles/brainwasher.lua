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
    _prior.Chatter,
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

local roleDescription = "The Brainwasher is a special Traitor role which allows the user to convert any non Traitor player over to a 'Slave', an additional Traitor player whom must do your team's bidding! Kill the remaining non-traitors to win the round."

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
brainwasher:SetEnemyRoles({"unknown"})
brainwasher:SetLovesTeammates(true)
brainwasher:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(brainwasher)

return true
