--- Fuse role integration for TTT Bots 2
--- The Fuse is a traitor sub-role on TEAM_TRAITOR. They have a countdown
--- timer: if it expires without a kill, they explode (dealing 200 damage
--- in a 300-unit radius). Each kill resets the timer. The explosion auto-
--- restarts the countdown. isOmniscientRole.
---
--- Bot behavior:
---   • TraitorLike builder — fights, coordinates, uses shop
---   • Extremely aggressive: MUST kill within the timer window
---   • isOmniscientRole: full life-state knowledge
---   • Timer pressure drives urgency — Stalk is kept very high priority
---   • FightBack / attack at top to minimize time between kills

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_FUSE then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,           -- React instantly — delay costs time
    _prior.Traitor,             -- Coordinate with other traitors
    _bh.Stalk,                  -- Aggressively hunt targets (timer pressure)
    _prior.Requests,
    _prior.Restore,
    _prior.Patrol,
}

local roleDescription = "You are the Fuse, a traitor sub-role. You have a countdown timer: if it "
    .. "expires without you getting a kill, you explode. Each kill resets the timer. "
    .. "You must kill frequently to stay alive. Coordinate with traitors but prioritize "
    .. "getting kills above all else — the clock is always ticking."

-- Use TraitorLike as the foundation for traitor defaults
local fuse = TTTBots.RoleBuilder.TraitorLike("fuse", TEAM_TRAITOR)
fuse:SetBTree(bTree)
fuse:SetKnowsLifeStates(true)       -- isOmniscientRole
fuse:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(fuse)

return true
