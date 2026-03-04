if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_CURSED then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.Chatter,
    _prior.Convert,
    _prior.Requests,
    _bh.Interact,
    _prior.Patrol
}

local roleDescription = "The Cursed is a special role which cannot do damage or be permanently killed, with the objective of stealing another player's role, either by walking up to them and pressing the USE key to convert them, or by shooting them with a Cursed Deagle to convert them from range!"

local cursed = TTTBots.RoleData.New("cursed", TEAM_NONE)
cursed:SetDefusesC4(false)
cursed:SetCanCoordinate(false)
cursed:SetCanHaveRadar(true)
cursed:SetUsesSuspicion(false)
cursed:SetTeam(TEAM_NONE)
cursed:SetKOSedByAll(false)
cursed:SetBTree(bTree)
cursed:SetLovesTeammates(true)
cursed:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(cursed)

return true