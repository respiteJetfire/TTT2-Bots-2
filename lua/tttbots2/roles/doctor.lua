if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DOCTOR then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local alliedTeams = {
    [TEAM_INNOCENT] = true,
}

local alliedRoles = {
    'medic'
}

local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

local doctor = TTTBots.RoleData.New("doctor")
doctor:SetDefusesC4(true)
doctor:SetTeam(TEAM_INNOCENT)
doctor:SetBTree(bTree)
doctor:SetAlliedRoles(alliedRoles)
doctor:SetCanHide(true)
doctor:SetCanSnipe(true)
doctor:SetKOSUnknown(false)
doctor:SetUsesSuspicion(true)
doctor:SetBuyableWeapons("weapon_ttt_defibrillator")
doctor:SetAlliedRoles({"doctor", "innocent"})
doctor:SetAlliedTeams(alliedTeams)
TTTBots.Roles.RegisterRole(doctor)

return true
