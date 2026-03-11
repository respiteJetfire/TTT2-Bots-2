--- Killer Clown role data — post-transformation aggressive solo hunter.
--- This role is created by the Clown's transformation and is a PUBLIC threat.
--- Everyone knows the Killer Clown has transformed (confetti + sound + HUD message).
--- KOSedByAll = true: all bots should immediately target the Killer Clown.
--- Has traitor shop access (SHOP_TRAITOR fallback) and optional damage bonus.
--- The behavior tree is managed by the GetTreeFor chain in clown.lua.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_KILLERCLOWN then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"
TEAM_CLOWN = TEAM_CLOWN or "clowns"

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_CLOWN] = true,
}

-- The behavior tree is dynamically assigned by the GetTreeFor chain in clown.lua.
-- This default tree is a fallback and should not normally be used.
local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _bh.Stalk,
    _prior.Requests,
    _prior.Restore,
    _bh.Interact,
    _bh.Wander,
}

local roleDescription = "The Killer Clown is the post-transformation form of the Clown. "
    .. "Your transformation was PUBLIC — everyone heard the confetti and saw the message. "
    .. "You have the traitor shop, possible bonus damage, and must kill all remaining players to win. "
    .. "There is no deception phase — hunt aggressively, buy equipment, and eliminate everyone. "
    .. "You are a solo threat on TEAM_CLOWN with no allies."

local killerclown = TTTBots.RoleData.New("killerclown", TEAM_CLOWN)
killerclown:SetDefusesC4(false)
killerclown:SetStartsFights(true)
killerclown:SetCanCoordinate(false)   -- Solo role — no teammates to coordinate with
killerclown:SetUsesSuspicion(false)
killerclown:SetTeam(TEAM_CLOWN)
killerclown:SetBTree(bTree)
killerclown:SetBuyableWeapons({})     -- Buyables registered in sv_default_buyables.lua
killerclown:SetKOSAll(true)           -- Attack all non-allies
killerclown:SetKOSedByAll(true)       -- PUBLIC threat — all bots KOS on sight
killerclown:SetNeutralOverride(false)
killerclown:SetKnowsLifeStates(true)
killerclown:SetAlliedTeams(allyTeams)
killerclown:SetLovesTeammates(false)
killerclown:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(killerclown)

return true
