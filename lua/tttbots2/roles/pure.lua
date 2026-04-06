--- Pure role integration for TTT Bots 2
--- The Pure is a passive, no-shop Innocent sub-role on TEAM_INNOCENT.
--- Key mechanics:
---   • unknownTeam = true — hidden from both sides
---   • No shop (SHOP_DISABLED), no credits
---   • On-death penalty: if someone kills the Pure (and isn't the Pure), that attacker
---     is temporarily blinded for ttt2_pure_blind_time seconds — server-driven
---   • If the Pure kills anyone, the Pure is demoted to a plain Innocent (loses role)
---   • Winning condition: survive as a regular innocent
---
--- Bot behavior:
---   • InnocentLike builder — fight back normally, use suspicion
---   • The blinding mechanic and demotion on kill are entirely server-driven
---   • Bot avoids unnecessary combat (would lose their role on a kill)

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_PURE then return false end

local pure = TTTBots.RoleBuilder.InnocentLike("pure")
TTTBots.Roles.RegisterRole(pure)

-- Pure loses their role if they kill someone — lower combat aggression
hook.Add("TTTBotsModifyPersonality", "TTTBots.pure.personality", function(bot)
    if not IsValid(bot) then return end
    if bot:GetSubRole() ~= ROLE_PURE then return end
    -- Discourage aggression; the Pure wants to survive without killing
    bot:BotAttribute("ttt2_aggression", 0.2)
end)

return true
