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
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _bh.CreateLovers,
    _prior.Restore,
    _prior.Minge,
    _bh.Stalk,
    _prior.Investigate,
    _prior.Patrol
}

local roleDescription = "The Cupid is a special role with a unique twist. Select up to two people to hit with your Cupid Gun (or yourself as the partner of this target). You will then be moved to a seperate 'Lovers' Team with the objective to kill all other remaining players. You share life between each player so if one dies the other dies too!"

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
cupid:SetLovesTeammates(true)
cupid:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(cupid)

return true
