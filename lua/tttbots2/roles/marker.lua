--- Marker behaviour for TTT2, a role which is evil and wins by being killed by a player.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_MARKER then return false end

local allyTeams = {
    [TEAM_MARKER] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _bh.CreateMarker,
    _prior.Requests,
    _prior.Support,
    _prior.Restore,
    _prior.Minge,
    _prior.Patrol
}

local marker = TTTBots.RoleData.New("marker", TEAM_MARKER)
marker:SetDefusesC4(false)
marker:SetStartsFights(true)
marker:SetNeutralOverride(false)
marker:SetTeam(TEAM_MARKER)
marker:SetBTree(bTree)
marker:SetAlliedTeams(allyTeams)
TTTBots.Roles.RegisterRole(marker)

return true
