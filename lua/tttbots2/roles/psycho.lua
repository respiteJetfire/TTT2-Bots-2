--- Psycho role integration for TTT Bots 2
--- The Psycho is a traitor sub-role on TEAM_TRAITOR. They are given the
--- psycho_transform weapon and armor. After a delay (ttt2_psy_transform_delay),
--- they gain access to item_psycho which boosts damage and speed while active.
--- isOmniscientRole, no shop (SHOP_DISABLED), no standard credits.
---
--- Key mechanics:
---   • psycho_transform: grants item_psycho after the delay
---   • item_psycho: while active, +damage multiplier, +speed multiplier
---   • Damage bonus and speed bonus are server-side stat modifiers
---
--- Bot behavior:
---   • TraitorLike builder — fights, coordinates with traitors
---   • Highly aggressive close-range fighter (boosted melee/damage)
---   • isOmniscientRole: full life-state knowledge
---   • Transform buff is triggered passively by the server after the timer
---   • No special bot action needed for transformation

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_PSYCHO then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,           -- Highly aggressive — boosted damage
    _prior.Traitor,             -- Coordinate with traitors
    _bh.Stalk,                  -- Hunt targets; transformation makes this more deadly
    _prior.Requests,
    _prior.Restore,
    _prior.Patrol,
}

local roleDescription = "You are the Psycho, a traitor sub-role. After a delay, you gain a "
    .. "transformation item that boosts your damage and speed. "
    .. "Fight aggressively and coordinate with your traitor team. "
    .. "Once transformed, you are a significantly more dangerous threat."

local psycho = TTTBots.RoleBuilder.TraitorLike("psycho", TEAM_TRAITOR)
psycho:SetBTree(bTree)
psycho:SetKnowsLifeStates(true)     -- isOmniscientRole
psycho:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(psycho)

return true
