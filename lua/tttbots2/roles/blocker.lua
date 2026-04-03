--- Blocker role integration for TTT Bots 2
--- The Blocker is a traitor subrole that prevents ALL non-Blocker players from
--- identifying corpses while the Blocker is alive. When the Blocker dies, all
--- unidentified corpses are automatically identified.
---
--- From the bot's perspective, the Blocker plays like a standard traitor but
--- has heightened strategic value in staying alive (to keep corpse ID blocked).
--- The corpse-blocking mechanic is entirely server-driven via hooks.
---
--- Bot behavior:
---   • Standard TraitorLike builder (fights, coordinates, uses shop)
---   • isOmniscientRole: knows MIA/life states
---   • Staying alive is strategically important — corpse info is blocked

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_BLOCKER then return false end

local roleDescription = "You are the Blocker, a traitor subrole. While you are alive, no other player can identify "
    .. "dead bodies — this denies the innocents critical information. When you die, all corpses are "
    .. "automatically identified. Play as a traitor but know that your survival has extra strategic value. "
    .. "Stay alive as long as possible to keep the innocents in the dark."

local blocker = TTTBots.RoleBuilder.TraitorLike("blocker", TEAM_TRAITOR)
blocker:SetKnowsLifeStates(true)  -- isOmniscientRole
blocker:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(blocker)

return true
