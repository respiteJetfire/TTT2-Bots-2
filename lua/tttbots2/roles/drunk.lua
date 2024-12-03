--- Drunk behavior for TTT2, a role which is neutral and can get the role of a dead player sometime during the round
if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DRUNK then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Support,
    _prior.FightBack,
    _prior.Requests,
    _bh.Defib,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

local drunk = TTTBots.RoleData.New("drunk", TEAM_DRUNK)
drunk:SetDefusesC4(false)
drunk:SetStartsFights(false)
drunk:SetTeam(TEAM_DRUNK)
drunk:SetKOSUnknown(false)
drunk:SetEnemyTeams({[TEAM_DOOMSLAYER] = true})
drunk:SetBTree(bTree)
drunk:SetAlliedTeams({})
TTTBots.Roles.RegisterRole(drunk)

return true