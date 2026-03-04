if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_INFECTED then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local allyTeams = {
    [TEAM_INFECTED] = true,
    [TEAM_JESTER] = true,
}


local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _prior.Restore,
    _bh.Stalk,
    _prior.Patrol
}

local roleDescription = "The Infected role is hostile to all players, when you kill someone they will be converted into a Zombie and will attack other players!"

local infected = TTTBots.RoleData.New("infected", TEAM_INFECTED)
infected:SetDefusesC4(false)
infected:SetStartsFights(true)
infected:SetCanHaveRadar(true)
infected:SetCanCoordinate(true)
infected:SetUsesSuspicion(false)
infected:SetTeam(TEAM_INFECTED)
infected:SetBTree(bTree)
infected:SetBuyableWeapons({"weapon_ttt_defib_traitor"})
infected:SetKnowsLifeStates(true)
infected:SetAlliedTeams(allyTeams)
infected:SetLovesTeammates(true)
infected:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(infected)

return true
