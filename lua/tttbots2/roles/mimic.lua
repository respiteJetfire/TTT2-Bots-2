--- Mimic behavior for TTT2, a role which is neutral and can copy the role of a player it touches.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_MIMIC then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Support,
    _prior.Requests,
    _prior.Restore,
    _bh.CopyRole
}

local mimic = TTTBots.RoleData.New("mimic", TEAM_MIMIC)
mimic:SetDefusesC4(false)
mimic:SetStartsFights(false)
mimic:SetTeam(TEAM_MIMIC)
mimic:SetBTree(bTree)
mimic:SetKOSUnknown(false)
mimic:SetAlliedTeams({})
mimic:SetNeutralOverride(true)
TTTBots.Roles.RegisterRole(mimic)

return true