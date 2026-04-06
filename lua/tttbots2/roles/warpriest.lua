--- Warpriest (Warrior Priest) role integration for TTT Bots 2
--- The Warpriest is an omniscient, public-facing, policing Detective sub-role.
--- Key mechanics:
---   • isPublicRole + isPolicingRole: everyone knows the Warpriest
---   • isOmniscientRole: full MIA/life-state awareness
---   • unknownTeam = true — hidden until outed or defeated
---   • SHOP_FALLBACK_DETECTIVE: detective shop access
---   • Receives weapon_ttt_sigmartome as role loadout (a special melee tome weapon)
---   • Scores heavily for kills (8×), penalized for team kills (−8×)
---   • Gains armor from shop (item_ttt_armor given on role change)
---
--- Bot behavior:
---   • DetectiveLike builder — investigate, police, use shop, use DNA scanner
---   • Prefer melee range when equipped with the tome
---   • Omniscient public authority figure; no coordination (public role)

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_WARP then return false end

local warpriest = TTTBots.RoleBuilder.DetectiveLike("warp")
TTTBots.Roles.RegisterRole(warpriest)

return true
