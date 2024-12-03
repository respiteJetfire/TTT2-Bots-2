if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_UNDECIDED then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local allyTeams = {
    [TEAM_JESTER] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

local undecided = TTTBots.RoleData.New("undecided", TEAM_NONE)
undecided:SetDefusesC4(false)
undecided:SetStartsFights(false)
undecided:SetCanCoordinate(false)
undecided:SetUsesSuspicion(false)
undecided:SetTeam(TEAM_NONE)
undecided:SetBTree(bTree)
undecided:SetBuyableWeapons({})
undecided:SetKOSUnknown(false)
undecided:SetKnowsLifeStates(true)
undecided:SetAlliedTeams(allyTeams)
undecided:SetNeutralOverride(true)
undecided:SetEnemyTeams({[TEAM_DOOMSLAYER] = true})
undecided:SetLovesTeammates(false)
TTTBots.Roles.RegisterRole(undecided)
