--- Roider role integration for TTT Bots 2
--- The Roider is a traitor sub-role on TEAM_TRAITOR. Their crowbar deals
--- heavy damage (configurable via ttt2_roid_cbdmg) and has an enhanced
--- push force (ttt2_roid_cbpush). Pure close-range brawler.
---
--- Bot behavior:
---   • TraitorLike builder — fights, coordinates with traitors, uses traitor buttons
---   • Prefers crowbar for close-range melee kills
---   • Gets in close aggressively — Stalk with short engagement range
---   • Standard traitor coordination

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_ROIDER then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,           -- Brawler — fight back immediately
    _prior.Traitor,             -- Coordinate with traitors
    _bh.Stalk,                  -- Close the gap for crowbar kills
    _prior.Requests,
    _prior.Restore,
    _prior.Patrol,
}

local roleDescription = "You are the Roider, a traitor sub-role. Your crowbar deals massively increased "
    .. "damage and has an enormous push force. Get in close and batter players with your crowbar. "
    .. "Coordinate with your fellow traitors and use your brawling power to your advantage."

local roider = TTTBots.RoleBuilder.TraitorLike("roider", TEAM_TRAITOR)
roider:SetBTree(bTree)
roider:SetPreferredWeapon("weapon_zm_improvised")   -- The crowbar
roider:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(roider)

return true
