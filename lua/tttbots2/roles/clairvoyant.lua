if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_CLAIRVOYANT then return false end


local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _bh.ClairvoyantWicked,
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

local clairvoyant = TTTBots.RoleData.New("clairvoyant")
clairvoyant:SetDefusesC4(true)
clairvoyant:SetTeam(TEAM_INNOCENT)
clairvoyant:SetCanHide(true)
clairvoyant:SetCanSnipe(true)
clairvoyant:SetBTree(bTree)
clairvoyant:SetUsesSuspicion(true)
clairvoyant:SetAlliedRoles({})
clairvoyant:SetAlliedTeams({})
clairvoyant:SetEnemyTeams({[TEAM_DOOMSLAYER] = true,})
TTTBots.Roles.RegisterRole(clairvoyant)

return true

