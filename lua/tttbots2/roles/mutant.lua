--- Mutant role integration for TTT Bots 2
--- The Mutant is a damage-scaling Innocent sub-role on TEAM_INNOCENT.
--- Key mechanics:
---   • unknownTeam = true — hidden alignment
---   • No shop (SHOP_DISABLED), no credits
---   • Gains resistance to fire, explosion, fall, and prop damage (configurable)
---   • Has a status system with 4 mutation tiers driven by cumulative damage taken
---   • At higher tiers: gains radar, speed boosts, increased max HP, and shop access
---   • Damage scaling and tier progression are fully server-driven
---   • ply.mutant_damage_taken tracks cumulative incoming damage
---
--- Bot behavior:
---   • InnocentLike builder — fight back, use suspicion, no coordination
---   • Stat changes (HP, speed, shop) are server-driven; bot benefits automatically
---   • unknownTeam: uses suspicion system

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_MUT then return false end

local mutant = TTTBots.RoleBuilder.InnocentLike("mut")
TTTBots.Roles.RegisterRole(mutant)

return true
