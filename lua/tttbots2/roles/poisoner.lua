--- Poisoner role integration for TTT Bots 2
--- The Poisoner is an innocent sub-role on TEAM_INNOCENT. They have
--- unknownTeam = true (uses suspicion system). On death, they apply a
--- poison DoT to their killer that deals damage over time. No shop,
--- no traitor buttons. Purely passive death mechanic.
---
--- Bot behavior:
---   • InnocentLike builder — standard innocent behavior
---   • unknownTeam: uses suspicion normally
---   • No special actions needed — the poison-on-death is entirely server-driven
---   • Plays defensively; their kill-on-death is a deterrent

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_POISONER then return false end

local roleDescription = "You are the Poisoner, an innocent sub-role. When you die, your killer is "
    .. "poisoned with a damage-over-time effect. Play defensively — your death is a weapon. "
    .. "Otherwise behave as a standard innocent: investigate, use suspicion, and survive."

-- InnocentLike sets up: TEAM_INNOCENT, usesSuspicion, no coordination
local poisoner = TTTBots.RoleBuilder.InnocentLike("poisoner")
poisoner:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(poisoner)

return true
