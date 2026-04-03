--- Blight role integration for TTT Bots 2
--- The Blight is a traitor subrole that inflicts a "blighted" status on whoever
--- kills them. The blighted player takes periodic radiation damage until they
--- are cured (by a health station or healing above their blight threshold).
---
--- From the bot's perspective, the Blight plays exactly like a standard traitor.
--- The infection mechanic is entirely server-driven (sv_blight_handler.lua) and
--- triggers automatically on the Blight's death — no special bot action needed.
---
--- Bot behavior:
---   • Standard TraitorLike builder (fights, coordinates, uses shop)
---   • isOmniscientRole: knows MIA/life states
---   • Dying is tactically useful (infects killer), so the bot doesn't
---     need to be extra careful about self-preservation

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_BLIGHT then return false end

local roleDescription = "You are the Blight, a traitor subrole. When you die, your killer becomes 'blighted' — "
    .. "they take periodic radiation damage over time until cured by a health station or by healing. "
    .. "Play aggressively as a traitor. Even in death, you serve the traitor cause by weakening your killer."

local blight = TTTBots.RoleBuilder.TraitorLike("blight", TEAM_TRAITOR)
blight:SetKnowsLifeStates(true)  -- isOmniscientRole
blight:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(blight)

return true
