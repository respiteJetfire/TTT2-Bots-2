if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_CURSED then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.Convert,
    _prior.Requests,
    _bh.Interact,
    _prior.Patrol,
}

local cursed = TTTBots.RoleData.New("cursed", TEAM_NONE)
cursed:SetDefusesC4(false)
cursed:SetCanCoordinate(false)
cursed:SetCanHaveRadar(true)
cursed:SetUsesSuspicion(false)
cursed:SetTeam(TEAM_NONE)
cursed:SetKOSedByAll(false)
cursed:SetBTree(bTree)
cursed:SetLovesTeammates(true)
TTTBots.Roles.RegisterRole(cursed)

return true