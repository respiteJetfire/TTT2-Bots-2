--- Serial Killer — solo neutral killer role.
--- Wins by being the LAST player alive. Every non-jester is an enemy.
--- Has a silent knife (instant kill at low HP), a shake grenade for area denial,
--- starting armor, and a tracker/radar that reveals all player positions.
--- The SK should play stealthily early, escalating aggression as players die.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SERIALKILLER then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

--- SK stealth-focused behavior tree (EARLY game).
--- Prioritizes deception, stalking, and knife kills on isolated targets.
local bTreeStealth = {
    _prior.Chatter,                  -- Social deception + chatter
    _prior.FightBack,                -- React to being attacked
    _prior.SelfDefense,              -- Defend from accusations
    _prior.Requests,                 -- Handle incoming requests
    _bh.SKKnifeAttack,               -- Prioritize knife kills on isolated targets
    _bh.SKShakeNade,                 -- Throw shake nade for area denial/escape
    _prior.Deception,                -- Alibi building, fake investigating (early game)
    _prior.Restore,                  -- Pick up weapons/health
    _bh.Stalk,                       -- Stalk isolated targets
    _prior.Minge,                    -- Occasional minge behavior for cover
    _prior.Patrol,                   -- Default patrol when nothing else to do
}

--- SK combat-focused behavior tree (LATE/OVERTIME game).
--- More aggressive: FightBack and attacks take higher priority, less deception.
local bTreeAggressive = {
    _prior.Chatter,                  -- Social deception + chatter
    _prior.FightBack,                -- React to being attacked (HIGH PRIORITY)
    _bh.SKKnifeAttack,               -- Prioritize knife kills aggressively
    _bh.SKShakeNade,                 -- Throw shake nade for area denial/escape
    _prior.SelfDefense,              -- Defend from accusations
    _prior.Requests,                 -- Handle incoming requests
    _bh.Stalk,                       -- Hunt remaining targets
    _prior.Restore,                  -- Pick up weapons/health
    _prior.Patrol,                   -- Default patrol when nothing else to do
}

--- Dynamic BTree selection based on round phase.
--- Returns the stealth tree during EARLY phase, aggressive tree during LATE/OVERTIME.
---@param bot Player
---@return table bTree
local function getPhaseBasedBTree(bot)
    if not IsValid(bot) then return bTreeStealth end

    local ra = bot.BotRoundAwareness and bot:BotRoundAwareness()
    if not ra then return bTreeStealth end

    local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
    if not PHASE then return bTreeStealth end

    local phase = ra:GetPhase()
    if phase == PHASE.LATE or phase == PHASE.OVERTIME then
        return bTreeAggressive
    end

    -- Also go aggressive if more than half are dead (regardless of time)
    local totalInRound = table.Count(TTTBots.Match.PlayersInRound or {})
    local aliveCount = #(TTTBots.Match.AlivePlayers or {})
    if totalInRound > 0 and aliveCount <= math.ceil(totalInRound / 2) then
        return bTreeAggressive
    end

    return bTreeStealth
end

local roleDescription = "The Serial Killer is a solo hostile role that must kill every other player to win. "
    .. "You have a silent knife (instant kill at low HP), a shake grenade for area denial, "
    .. "armor, and a tracker that shows all player positions. You start alone — no allies. "
    .. "You know who the Jesters are (avoid them). Play stealthily early, escalate aggression "
    .. "as players die. You are cunning, methodical, and ruthless."

local serialkiller = TTTBots.RoleBuilder.NeutralKiller("serialkiller", TEAM_SERIALKILLER)
-- NeutralKiller sets: KOSAll, KOSedByAll, StartsFights, UsesSuspicion=false, CanCoordinate=false
serialkiller:SetDefusesC4(true)
serialkiller:SetKnowsLifeStates(true)          -- Omniscient: sees all players, knows life states
serialkiller:SetLovesTeammates(true)
serialkiller:SetIsFollower(false)               -- SK hunts, not follows
serialkiller:SetBTree(bTreeStealth)             -- Default; overridden at runtime by GetTreeFor hook
serialkiller:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(serialkiller)

-- ---------------------------------------------------------------------------
-- Runtime tree override: swap tree based on round phase each tick.
-- We hook into GetTreeFor by storing the original function and wrapping it.
-- This follows the same pattern as the necromancer/infected role's dynamic tree switching.
-- ---------------------------------------------------------------------------
local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor
function TTTBots.Behaviors.GetTreeFor(bot)
    if not IsValid(bot) then return nil end

    -- Only intercept for Serial Killer role
    local role = TTTBots.Roles.GetRoleFor(bot)
    if role and role:GetName() == "serialkiller" then
        return getPhaseBasedBTree(bot)
    end

    return _origGetTreeFor(bot)
end

return true
