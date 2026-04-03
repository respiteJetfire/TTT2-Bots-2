--- Cyclone role integration for TTT Bots 2
--- The Cyclone is a traitor subrole with a unique "flagging" mechanic.
--- The first shot the Cyclone fires at another player deals NO damage but
--- instead "flags" (marks) that player:
---   • The flagged player's max health is reduced (configurable)
---   • The flagged player may be muted (voice/text chat blocked)
---   • An EPOP announcement may broadcast the flagged player
---   • The Cyclone's weapon may be stripped after the flag shot
---
--- After the flag shot is used, the Cyclone plays as a normal traitor.
--- The flagging is server-driven (ScalePlayerDamage hook) — the bot just
--- needs to shoot someone early to trigger the flag, then fight normally.
---
--- Bot behavior:
---   • TraitorLike builder with shop access
---   • Should shoot someone early to use the flag shot (happens naturally)
---   • After flagging, plays standard traitor

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_CYCLONE then return false end

local roleDescription = "You are the Cyclone, a traitor subrole with a special 'flagging' ability. "
    .. "Your first shot at a player deals no damage but 'flags' them — reducing their max health, "
    .. "potentially muting them, and publicly marking them as suspicious. "
    .. "After your flag shot is used, you play as a normal traitor. Use the flag strategically on "
    .. "a dangerous player (like a detective) to weaken the innocent team."

local cyclone = TTTBots.RoleBuilder.TraitorLike("cyclone", TEAM_TRAITOR)
cyclone:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(cyclone)

return true
