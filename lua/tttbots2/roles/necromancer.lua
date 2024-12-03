if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_NECROMANCER then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local allyTeams = {
    [TEAM_NECROMANCER] = true,
    [TEAM_JESTER] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _prior.Restore,
    _bh.Stalk,
    _prior.Patrol
}

local necromancer = TTTBots.RoleData.New("necromancer", TEAM_NECROMANCER)
necromancer:SetDefusesC4(false)
necromancer:SetStartsFights(true)
necromancer:SetEnemyTeams(enemyTeams)
necromancer:SetCanHaveRadar(true)
necromancer:SetCanCoordinate(true)
necromancer:SetUsesSuspicion(false)
necromancer:SetTeam(TEAM_NECROMANCER)
necromancer:SetBTree(bTree)
necromancer:SetKnowsLifeStates(true)
necromancer:SetAlliedTeams(allyTeams)
necromancer:SetLovesTeammates(true)
TTTBots.Roles.RegisterRole(necromancer)

return true
