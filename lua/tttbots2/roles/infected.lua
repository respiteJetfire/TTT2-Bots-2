if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_INFECTED then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local allyTeams = {
    [TEAM_INFECTED] = true,
    [TEAM_JESTER] = true,
}

local enemyTeams = {
    -- [TEAM_CRIPS] = true,
    -- [TEAM_BALLAS] = true,
    -- [TEAM_FAMILIES] = true,
    -- [TEAM_HOOVERS] = true,
    -- [TEAM_INNOCENT] = true,
    -- [TEAM_TRAITOR] = true,
    -- [TEAM_JACKAL] = true,
    -- [TEAM_RESTLESS] = true,
    -- [TEAM_SERIALKILLER] = true,
    -- [TEAM_NONE] = true,
    -- [TEAM_PIRATE] = true,
    [TEAM_DOOMSLAYER] = true,
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

local infected = TTTBots.RoleData.New("infected", TEAM_INFECTED)
infected:SetDefusesC4(false)
infected:SetStartsFights(true)
infected:SetEnemyTeams(enemyTeams)
infected:SetCanHaveRadar(true)
infected:SetCanCoordinate(true)
infected:SetUsesSuspicion(false)
infected:SetTeam(TEAM_INFECTED)
infected:SetBTree(bTree)
infected:SetBuyableWeapons({"weapon_ttt_defib_traitor"})
infected:SetKnowsLifeStates(true)
infected:SetAlliedTeams(allyTeams)
infected:SetLovesTeammates(true)
TTTBots.Roles.RegisterRole(infected)

return true
