--- Hurricane role integration for TTT Bots 2
--- The Hurricane is the innocent-team counterpart of the Cyclone.
--- It is a detective subrole (baseRole = ROLE_DETECTIVE) with a "flagging" mechanic.
--- The first shot the Hurricane fires at a player deals NO damage but "flags" them:
---   • The flagged player's max health is reduced (configurable)
---   • The flagged player may be muted (voice/text chat blocked)
---   • An EPOP announcement may broadcast the flagged player
---   • The Hurricane's weapon may be stripped after the flag shot
---
--- The Hurricane has isPolicingRole = true, isPublicRole = true, unknownTeam = true.
--- They receive a weapon_ttt_wtester (role tester) on spawn.
--- After the flag shot is used, they play as a detective-like investigator.
---
--- Bot behavior:
---   • DetectiveLike builder (investigate corpses, DNA scan, public role)
---   • Should shoot a suspicious player early to flag them
---   • Uses weapon tester equipment
---   • unknownTeam = true, but still a public policing role

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_HURRICANE then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "You are the Hurricane, an innocent-team detective subrole with a 'flagging' ability. "
    .. "Your first shot at a player deals no damage but 'flags' them — reducing their max health, "
    .. "potentially muting them, and publicly marking them as suspicious. "
    .. "You are a public policing role (everyone knows you're Hurricane) and you get a role tester. "
    .. "Use the flag on someone you suspect is a traitor to weaken them for the team."

-- DetectiveLike tree: investigate, support, use flag shot naturally
local hurricane = TTTBots.RoleBuilder.DetectiveLike("hurricane")
hurricane:SetRoleDescription(roleDescription)
hurricane:SetLovesTeammates(false)         -- unknownTeam = true
hurricane:SetCanCoordinateInnocent(true)   -- Still a policing role
TTTBots.Roles.RegisterRole(hurricane)

return true
