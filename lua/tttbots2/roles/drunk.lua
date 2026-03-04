--- Drunk behavior for TTT2, a role which is neutral and can get the role of a dead player sometime during the round
if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DRUNK then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
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

local roleDescription = "The Drunk is a role that starts off as a Neutral role, no allegiance to any side. You will only change role if someone dies, during which there is a chance that a timer will start notifying you of your impending role change. Once you change to this role, an announcement will sound to all players that the Drunk has remembered their role, and you will assume this role for the rest of the round."

local drunk = TTTBots.RoleData.New("drunk", TEAM_DRUNK)
drunk:SetDefusesC4(false)
drunk:SetStartsFights(false)
drunk:SetTeam(TEAM_DRUNK)
drunk:SetKOSUnknown(false)
drunk:SetBTree(bTree)
drunk:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(drunk)

return true