--- Link role integration for TTT Bots 2
--- Link is an omniscient, public-facing, policing Detective sub-role
--- themed after The Legend of Zelda's Link.
--- Key mechanics:
---   • isPublicRole + isPolicingRole: everyone knows the Link
---   • isOmniscientRole: full MIA/life-state awareness
---   • unknownTeam = true — hidden alignment
---   • SHOP_FALLBACK_DETECTIVE: detective shop access
---   • Receives weapon_mastersword on loadout (if ttt2_link_msword_start is enabled)
---   • Gains extra HP and armor from convars (ttt2_link_max_health, ttt2_link_armor)
---   • Scores heavily for kills (8×), penalized for team kills (−8×)
---   • Credits awarded on enemy death
---   • Plays the Zelda theme on spawn
---
--- Bot behavior:
---   • DetectiveLike builder — investigate corpses, use DNA scanner, police the map
---   • Prefers melee (master sword) when available — close-range engagements
---   • Omniscient public authority; no hidden coordination needed

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_LINK then return false end

local link = TTTBots.RoleBuilder.DetectiveLike("link")
TTTBots.Roles.RegisterRole(link)

return true
