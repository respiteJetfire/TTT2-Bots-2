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
    _prior.Chatter,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Requests,
    _prior.Convert,
    _prior.Support,
    _bh.Roledefib,
    _prior.Deception,   -- AlibiBuilding, FakeInvestigate, PlausibleIgnorance (blend in while seeking convert targets)
    _prior.Restore,
    _bh.Stalk,          -- Stalk isolated targets (suppressed in EARLY game when conversion available)
    _prior.Investigate,
    _prior.Minge,
    _prior.Patrol
}

local roleDescription = "The Jackal is a hostile role which starts alone, but has a sidekick deagle which allows the Jackal to shoot any player and make them into their Sidekick. You only get 1 sidekick but yourself and them get access to the Traitor shop and can use this to win the game for your own Team!"

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
jackal:SetLovesTeammates(true)
jackal:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(jackal)

return true
