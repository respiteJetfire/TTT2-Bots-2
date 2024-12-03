if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_MEDIC then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local alliedTeams = {
    [TEAM_NONE] = true,
    [TEAM_INNOCENT] = true,
    [TEAM_TRAITOR] = true,
    [TEAM_RESTLESS] = true,
    [TEAM_JESTER] = true,
    [TEAM_BALLAS] = true,
    [TEAM_BLOODS] = true,
    [TEAM_CRIPS] = true,
    [TEAM_DOOMSLAYER] = true,
    [TEAM_PIRATE] = true,
    [TEAM_SERIALKILLER] = true,
}

local bTree = {
    -- _prior.Support,
    -- _bh.DefibPlayer,
    _prior.Requests,
    _bh.Healgun,
    -- _bh.HealgunMedic,
    _bh.Defib,
    _prior.Investigate,
    _prior.Patrol,
}

local medic = TTTBots.RoleData.New("medic")
medic:SetDefusesC4(true)
medic:SetTeam(TEAM_NONE)
medic:SetBTree(bTree)
medic:SetKOSUnknown(false)
medic:SetUsesSuspicion(false)
medic:SetBuyableWeapons("weapon_ttt_defibrillator")
medic:SetAlliedRoles({"medic", "innocent"})
medic:SetNeutralOverride(true)
medic:SetAlliedTeams(alliedTeams)
TTTBots.Roles.RegisterRole(medic)

return true
