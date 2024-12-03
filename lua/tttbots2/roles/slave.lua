if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SLAVE then return false end

local allyTeams = {
    [TEAM_TRAITOR] = true,
    [TEAM_JESTER or 'jesters'] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local slave = TTTBots.RoleData.New("slave", TEAM_TRAITOR)
slave:SetDefusesC4(false)
slave:SetPlantsC4(true)
slave:SetCanHaveRadar(true)
slave:SetCanCoordinate(true)
slave:SetStartsFights(true)
slave:SetTeam(TEAM_TRAITOR)
slave:SetUsesSuspicion(false)
slave:SetBTree(TTTBots.Behaviors.DefaultTrees.traitor)
slave:SetAlliedTeams(allyTeams)
slave:SetEnemyTeams({[TEAM_DOOMSLAYER] = true})
slave:SetCanSnipe(true)
slave:SetLovesTeammates(true)
TTTBots.Roles.RegisterRole(slave)

return true
