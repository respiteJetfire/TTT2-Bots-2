if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_PHARAOH then return false end

local pharaoh = TTTBots.RoleData.New("pharaoh")
local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _bh.PlantAnkh,
    _prior.Requests,
    _prior.FightBack,
    _bh.CaptureAnkh,
    _prior.Support,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

pharaoh:SetDefusesC4(true)
pharaoh:SetTeam(TEAM_INNOCENT)
pharaoh:SetCanHide(true)
pharaoh:SetCanSnipe(true)
pharaoh:SetUsesSuspicion(true)
pharaoh:SetBTree(bTree)
pharaoh:SetAlliedRoles({})
pharaoh:SetAlliedTeams({})
pharaoh:SetEnemyTeams({[TEAM_DOOMSLAYER] = true,})
TTTBots.Roles.RegisterRole(pharaoh)

return true

