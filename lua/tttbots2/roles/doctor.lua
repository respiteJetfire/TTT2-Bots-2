if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DOCTOR then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local alliedTeams = {
    [TEAM_INNOCENT] = true,
}

local bTree = {
    _prior.Chatter,
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

local roleDescription = "You are a Doctor. The Doctor is an innocent role that comes with a Defibrillator and a Medicgun, with access to a shop which lets you buy more Defibrillators for free. Keep your Teammates alive, and revive any dead Innocent players to prevent the Traitors or hostile roles accomplishing their objectives! Other players cannot verify you are a Doctor, as other roles do have access to these items in the shop, and Traitors and Hostile roles will target you first if they know you are a Doctor."

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
doctor:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(doctor)

return true
