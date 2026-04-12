--- Necrohealiac role integration for TTT Bots 2
--- The Necrohealiac is an Innocent sub-role on TEAM_INNOCENT that heals
--- whenever another player (non-Necrohealiac) dies.
--- Key mechanics:
---   • TEAM_INNOCENT, unknownTeam = true — hidden alignment
---   • No shop (SHOP_DISABLED), no credits
---   • preventFindCredits + preventKillCredits: cannot pick up or earn credits
---   • On any player death (other than themselves), heals by a configurable amount
---     — server-driven via PlayerDeath hook
---   • The Necrohealiac benefits from others dying, so they benefit from traitor kills
---   • Winning condition: survive with innocents
---
--- Bot behavior:
---   • InnocentLike builder — fight back, use suspicion, no coordination
---   • The healing mechanic is fully server-driven; bot benefits automatically
---   • unknownTeam: uses suspicion system

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_NECROH then return false end

local roleDescription = "You are the Necrohealiac, an innocent sub-role. You heal whenever another player dies. "
    .. "This means you benefit from deaths — even traitor kills indirectly help you. "
    .. "Play as a standard innocent: investigate, use suspicion, and survive. "
    .. "Your passive healing makes you increasingly resilient as the round progresses."

local necrohealiac = TTTBots.RoleBuilder.InnocentLike("necroh")
necrohealiac:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(necrohealiac)

return true
