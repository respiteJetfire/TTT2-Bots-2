--- Bodyguard behaviour for TTT2, a role which is assigned a target to protect and wins by keeping them alive
--- until their team wins the game.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_BODYGUARD then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _prior.Restore,
    _bh.Interact,
    _prior.Minge,
    _bh.Bodyguard
}

local bodyguard = TTTBots.RoleData.New("bodyguard", TEAM_NONE)
bodyguard:SetDefusesC4(false)
bodyguard:SetPlantsC4(false)
bodyguard:SetCanHaveRadar(false)
bodyguard:SetCanCoordinate(true)
bodyguard:SetStartsFights(false)
bodyguard:SetUsesSuspicion(false)
bodyguard:SetBTree(bTree)
bodyguard:SetAlliedTeams({})
bodyguard:SetCanSnipe(false)
bodyguard:SetLovesTeammates(true)
TTTBots.Roles.RegisterRole(bodyguard)

return true
