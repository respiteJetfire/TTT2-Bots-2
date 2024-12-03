--- Jackal behaviour for TTT2, a role which is evil and wins by killing all non-allied players
--- but can also convert someone to their side using the sidekick deagle

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_JACKAL then return false end

TEAM_JESTER = TEAM_JESTER or 'jesters'

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_JACKAL] = true,
}
local allyRoles = {
    sidekick = true
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _prior.Convert,
    -- _bh.Roledefib,
    _prior.Restore,
    _prior.Minge,
    _bh.Stalk,
    _prior.Investigate,
    _prior.Patrol
}

local jackal = TTTBots.RoleData.New("jackal", TEAM_JACKAL)
jackal:SetDefusesC4(false)
jackal:SetCanCoordinate(true)
jackal:SetCanHaveRadar(true)
jackal:SetStartsFights(true)
jackal:SetUsesSuspicion(false)
jackal:SetTeam(TEAM_JACKAL)
jackal:SetBTree(bTree)
jackal:SetAlliedTeams(allyTeams)
jackal:SetAlliedRoles(allyRoles)
jackal:SetEnemyRoles({"unknown"})
jackal:SetLovesTeammates(true)
TTTBots.Roles.RegisterRole(jackal)

return true
