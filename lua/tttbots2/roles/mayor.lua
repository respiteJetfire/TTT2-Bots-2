--- Mayor role integration for TTT Bots 2
--- The Mayor is an omniscient, public-facing, policing Detective sub-role on TEAM_INNOCENT.
--- Key mechanics:
---   • isPublicRole + isPolicingRole: everyone knows the Mayor and takes them seriously
---   • isOmniscientRole: full MIA/life-state awareness
---   • unknownTeam: uses suspicion system
---   • SHOP_FALLBACK_DETECTIVE: has access to detective shop
---   • After a random delay, the Mayor gets a private "tip" naming one player's role
---     (via ttt2_mayor_message net message) — this is server-driven and repeats
---
--- Bot behavior:
---   • DetectiveLike builder — investigate corpses, use DNA scanner, police the map
---   • Public authority figure with omniscient awareness
---   • The intel tip is server-driven; no bot action required

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_MAYOR then return false end

local mayor = TTTBots.RoleBuilder.DetectiveLike("mayor")
TTTBots.Roles.RegisterRole(mayor)

return true
