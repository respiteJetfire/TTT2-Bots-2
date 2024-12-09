if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_MEDIC then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local alliedTeams = {}

local listofTeams = roles.GetAvailableTeams()

--- Iterate over all TTT2 teams and add them to the list of allied teams and set to true
for i, v in pairs(listofTeams) do
    alliedTeams[v] = true
end

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
medic:SetLovesTeammates(true)
medic:SetNeutralOverride(true)
medic:SetAlliedTeams(alliedTeams)
TTTBots.Roles.RegisterRole(medic)

return true
