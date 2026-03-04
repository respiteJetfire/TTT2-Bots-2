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
    _prior.Chatter,
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

local roleDescription = "The Anonymous role's objective is to kill all the remaining players except their teammates, but the catch is; they don't know who they are! Be careful you and your teammates do not target each other whilst considering other roles in the game!"

local anonymous = TTTBots.RoleData.New("anonymous", TEAM_ANONYMOUS)
anonymous:SetDefusesC4(false)
anonymous:SetCanCoordinate(false)
anonymous:SetCanHaveRadar(true)
anonymous:SetStartsFights(true)
anonymous:SetUsesSuspicion(false)
anonymous:SetTeam(TEAM_ANONYMOUS)
anonymous:SetBTree(bTree)
anonymous:SetAlliedTeams(allyTeams)
anonymous:SetLovesTeammates(false)
anonymous:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(anonymous)

return true
