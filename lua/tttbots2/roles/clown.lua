if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_CLOWN then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local allyTeams = {
    [TEAM_JESTER] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.Chatter,
    _prior.Requests,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

local roleDescription = "The Clown is a Jester-like role, to other Traitors and hostile roles you will be shown as a Jester, use this to your advantage by surviving to the end of the round. If you do, you will be transformed into a Killer Clown and then you must kill all remaining players. Remember to act like a Jester to deter people from killing you, as you have no defence and cannot do damage until your transformation!"

local clown = TTTBots.RoleData.New("clown", TEAM_CLOWN)
clown:SetDefusesC4(false)
clown:SetStartsFights(false)
clown:SetCanCoordinate(false)
clown:SetUsesSuspicion(false)
clown:SetTeam(TEAM_CLOWN)
clown:SetBTree(bTree)
clown:SetBuyableWeapons({})
clown:SetKnowsLifeStates(true)
clown:SetNeutralOverride(true)
clown:SetAlliedTeams(allyTeams)
clown:SetLovesTeammates(false)
clown:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(clown)

return true