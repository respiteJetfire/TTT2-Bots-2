--- Gambler role integration for TTT Bots 2
--- The Gambler is a traitor sub-role on TEAM_TRAITOR. At round start they
--- receive a random assortment of traitor shop items and weapons (configurable
--- count). They cannot earn credits normally. isOmniscientRole.
---
--- Bot behavior:
---   • TraitorLike builder — fights, coordinates, uses traitor buttons
---   • Uses whatever random equipment they were given at round start
---   • No credit-earning means no shop re-stocking — fight with what you have
---   • isOmniscientRole: full life-state knowledge

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_GAMBLER then return false end

local roleDescription = "You are the Gambler, a traitor sub-role. At round start you received a "
    .. "random assortment of traitor items and weapons — make the best of what you have. "
    .. "You cannot earn new credits, so use your starting equipment wisely. "
    .. "Coordinate with your fellow traitors and fight to win."

-- Use TraitorLike as the foundation — Gambler is a standard traitor otherwise
local gambler = TTTBots.RoleBuilder.TraitorLike("gambler", TEAM_TRAITOR)
gambler:SetKnowsLifeStates(true)    -- isOmniscientRole
gambler:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(gambler)

return true
