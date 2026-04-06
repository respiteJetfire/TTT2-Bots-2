--- Wrath role integration for TTT Bots 2
--- The Wrath is a hidden innocent subrole with a powerful passive: if killed
--- by a member of TEAM_INNOCENT, they revive as a full TRAITOR after a delay.
---
--- Key mechanics (all server-driven):
---   • disableSync: true — even the bot itself is shown as an innocent (role hidden)
---   • unknownTeam: true
---   • On death by innocent: Revive → SetRole(ROLE_TRAITOR), gets credits
---   • REVIVAL_BLOCK_ALL prevents round from ending during revival
---
--- Bot behavior:
---   • InnocentLike base — acts fully like an innocent pre-death
---   • unknownTeam: uses suspicion
---   • After revival as traitor: bot will receive a new tree from traitor.lua
---   • No special actions needed — revival and role change are server-driven

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_WRATH then return false end

local roleDescription = "You are the Wrath, a hidden innocent subrole. You don't even know your own role. "
    .. "If you are killed by an innocent, you will revive after a delay as a full Traitor — "
    .. "gaining credits and full traitor capabilities. Until then, act completely like an innocent. "
    .. "Be cautious around traitors (they can kill you without triggering the revival) "
    .. "but try to get innocents to shoot you first."

local wrath = TTTBots.RoleBuilder.InnocentLike("wrath")
wrath:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(wrath)

-- ---------------------------------------------------------------------------
-- Suspicion hook: Wrath appears as a completely normal innocent.
-- No modifier needed — default innocent behavior.
-- ---------------------------------------------------------------------------

return true
