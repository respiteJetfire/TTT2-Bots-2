--- Patient role integration for TTT Bots 2
--- The Patient is an Innocent sub-role with a contagious cough weapon.
--- Key mechanics:
---   • unknownTeam = true — hidden alignment
---   • No shop (SHOP_DISABLED), no credits
---   • Receives ttt_patient_cough as role loadout — a weapon to infect other players
---     with a sickness DoT (ttt2_pat_sickness_timer seconds duration)
---   • The cough has a cooldown (ttt2_pat_cough_cooldown_timer seconds)
---   • item_pat_immunity can be bought to become immune
---   • item_pat_infection is a deployable that infects an area
---   • Winning condition: survive with innocents
---
--- Bot behavior:
---   • InnocentLike — fights normally, uses suspicion
---   • The cough weapon is treated as a support tool: bot walks near suspected
---     traitors and fires the cough (handled via generic weapon use)
---   • No special behavior node required; weapon use is handled by base combat

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_PAT then return false end

local patient = TTTBots.RoleBuilder.InnocentLike("pat")
TTTBots.Roles.RegisterRole(patient)

return true
