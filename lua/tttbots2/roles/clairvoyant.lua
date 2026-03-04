if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_CLAIRVOYANT then return false end


local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
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

local roleDescription = "The Clairvoyant is a special Innocent role which allows the player to see if any player in the scoreboard has an Original TTT Role (Innocent, Detective, Traitor), or any of the special TTT2 Roles added (e.g Banker, Amnesiac, Unknown, Brainwasher, Infected etc.). It will not tell you what role they are, it does not automatically mean the player is hostile but use this information to survive and help the other Innocent players eliminate the remaining Traitors!"

local clairvoyant = TTTBots.RoleData.New("clairvoyant")
clairvoyant:SetDefusesC4(true)
clairvoyant:SetTeam(TEAM_INNOCENT)
clairvoyant:SetCanHide(true)
clairvoyant:SetCanSnipe(true)
clairvoyant:SetBTree(bTree)
clairvoyant:SetUsesSuspicion(true)
clairvoyant:SetAlliedRoles({})
clairvoyant:SetAlliedTeams({})
clairvoyant:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(clairvoyant)

return true

