if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_ORACLE then return false end

local oracle = TTTBots.RoleData.New("oracle")
local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _bh.Oracle,
    _prior.Requests,
    _prior.FightBack,
    _prior.Support,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

oracle:SetDefusesC4(true)
oracle:SetTeam(TEAM_INNOCENT)
oracle:SetCanHide(true)
oracle:SetCanSnipe(true)
oracle:SetUsesSuspicion(true)
oracle:SetBTree(bTree)
oracle:SetAlliedRoles({})
oracle:SetAlliedTeams({})
oracle:SetEnemyTeams({[TEAM_DOOMSLAYER] = true,})
TTTBots.Roles.RegisterRole(oracle)

return true

