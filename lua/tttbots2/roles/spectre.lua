--- Spectre role integration for TTT Bots 2
--- The Spectre is an innocent sub-role on TEAM_INNOCENT with unknownTeam = true.
--- After death, the Spectre enters a haunt phase where they can interact with
--- the world as a ghost, ultimately reviving with partial health. They have
--- special equipment (SPECIAL_EQUIPMENT) and configurable haunt/revive behavior.
---
--- Key mechanics:
---   • unknownTeam = true — does not know teammates
---   • On death: enters ghost haunt state, can haunt players and objects
---   • Revives with ttt2_spectre_revive_health HP
---   • Smoke effect on revive (configurable)
---   • Declare mode: can optionally announce ghost haunt to team
---
--- Bot behavior:
---   • InnocentLike — standard innocent behavior while alive
---   • unknownTeam: uses suspicion system
---   • Revive is server-driven — no bot action needed for haunt phase
---   • After revive, continues acting as innocent

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SPECTRE then return false end

local roleDescription = "You are the Spectre, an innocent sub-role. When you die, you enter a ghost "
    .. "haunt phase and can ultimately revive with partial health. "
    .. "While alive, act as a normal innocent: investigate, use suspicion, and survive. "
    .. "After reviving, continue fighting for the innocent team."

-- InnocentLike sets up: TEAM_INNOCENT, usesSuspicion, no coordination
local spectre = TTTBots.RoleBuilder.InnocentLike("spectre")
spectre:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(spectre)

return true
