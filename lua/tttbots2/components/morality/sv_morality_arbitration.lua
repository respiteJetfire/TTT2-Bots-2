--- sv_morality_arbitration.lua
--- Attack-target arbitration: priority-based targeting gateway with debug reason codes.
--- All SetAttackTarget calls should route through this module's RequestAttackTarget
--- or RequestClearTarget to enforce explicit precedence and traceability.
---
--- Priority tiers (highest wins):
---   5  SELF_DEFENSE         — bot is being attacked
---   4  PLAYER_REQUEST       — explicit player/role request, or role-defense (bodyguard, master, etc.)
---   3  ROLE_HOSTILITY       — hard KOS role flags, role enemies, hostile policy
---   2  SUSPICION_THRESHOLD  — suspicion >= KOS threshold
---   1  OPPORTUNISTIC        — random aggression, last-alive, RDM, boredom
---   0  BEHAVIOR_CLEAR       — behavior OnEnd clears, round resets (always succeeds for clears)

local lib = TTTBots.Lib

--- Namespace for the arbitration sub-module.
TTTBots.Morality = TTTBots.Morality or {}
local Arb = TTTBots.Morality

--- Priority tier constants — exported so callers use names, not magic numbers.
Arb.PRIORITY = {
    BEHAVIOR_CLEAR       = 0,
    OPPORTUNISTIC        = 1,
    SUSPICION_THRESHOLD  = 2,
    ROLE_HOSTILITY       = 3,
    PLAYER_REQUEST       = 4,
    SELF_DEFENSE         = 5,
}

--- Lookup table: reason code → human-readable label (used in debug output).
Arb.REASON_LABELS = {
    -- Priority 5 — Self-defense
    SELF_DEFENSE            = "Self-defense: bot was attacked",

    -- Priority 4 — Player / role request
    PLAYER_REQUEST          = "Player explicitly requested attack",
    ROLE_DEFEND_MASTER      = "Defending master/leader from attacker",
    ROLE_DEFEND_ALLY        = "Defending allied role from attacker",
    BODYGUARD_DEFEND        = "Bodyguard defending charge",
    COPY_MASTER_TARGET      = "Copying master's attack target",
    STALK_ATTACK            = "Stalking target — close and alone",
    CAPTURE_ANKH            = "Ankh capture — forcing target",
    CREATE_MARKER           = "Marker creation — forcing target",
    FOLLOW_PLAN_ATTACK      = "Follow plan — coordinated attack",
    DEFEND_ANKH             = "Defending own ankh from attacker/converter",
    ANKH_GUARDIAN_THREAT     = "Graverobber targeting Pharaoh guarding ankh",
    ANKH_CONVERSION_WITNESS  = "Witnessed ankh conversion — hostile act",

    -- Priority 3 — Role/team hostility policy
    RESTLESS_AGGRESSION     = "Restless armed with ranged weapon — attacking on sight",
    ROLE_ENEMY              = "Target is a declared role enemy",
    KOS_ALL                 = "Role KOS-all non-allies",
    KOSED_BY_ALL            = "Target is KOS'd by all",
    KOS_UNKNOWN             = "Target has unknown role",
    KOS_ZOMBIE              = "Target is a zombie",
    KOS_NPC                 = "Target is a hostile NPC",
    CONTINUE_MASSACRE       = "Red-handed killer continues massacre",
    TRAITOR_WEAPON          = "Target holding a traitor weapon",
    DISGUISED_PLAYER        = "Target is disguised",
    DISGUISED_ATTACKER      = "Attacker is disguised — attack on sight",
    NPC_ATTACKER            = "NPC attacked the bot",
    PREVENT_ALLY            = "Clearing: target is an ally",
    PREVENT_CLOAKED         = "Clearing: target is cloaked",
    PREVENT_NEUTRAL         = "Clearing: target has neutral override",
    PREVENT_CHECKED_ALLY    = "Clearing: target is role-checked ally",

    -- Priority 2 — Suspicion threshold
    SUS_THRESHOLD           = "Suspicion reached KOS threshold",
    SUS_ROLE_GUESS          = "Role guess — non-innocent predicted",
    ALLY_DEFENSE            = "Ally was attacked — defending",
    KOS_LIST_TARGET         = "Target has been KOS'd by a credible caller",

    -- Priority 1 — Opportunistic
    OPPORTUNISTIC_ATTACK    = "Traitor random nearby attack",
    LAST_ALIVE              = "Last two alive — must fight",
    RDM_RAGE                = "RDM triggered by rage/boredom",

    -- Priority 0 — Clears
    BEHAVIOR_END            = "Behavior ended — clearing target",
    ROUND_RESET             = "Round reset — clearing all targets",
    RESPAWN_CLEAR           = "Respawn — clearing stale pre-death target",
    CEASEFIRE               = "Ceasefire — clearing target",
    LEGACY                  = "Legacy call (no reason provided)",
}

-- ---------------------------------------------------------------------------
-- Debug helper
-- ---------------------------------------------------------------------------

--- Emit a debug line about a targeting decision. Gated behind the debug_misc cvar.
---@param bot Player
---@param msg string
function Arb.DebugTarget(bot, msg)
    local dvlpr = lib.GetConVarBool("debug_misc")
    if not dvlpr then return end
    local name = IsValid(bot) and bot:Nick() or "???"
    print(string.format("[Morality:Target] %s | %s", name, msg))
end

-- ---------------------------------------------------------------------------
-- Core arbitration API
-- ---------------------------------------------------------------------------

--- Request setting an attack target on a bot. The request succeeds only if:
---   1. The new priority >= the bot's current target lock priority, OR
---   2. The bot currently has no target.
--- Every successful request records reason + priority on the bot for traceability.
---
---@param bot Player       The bot whose target we want to set.
---@param target Player|Entity|nil  The target entity (or nil to clear).
---@param reason string    A reason code key (from REASON_LABELS).
---@param priority number  A priority tier (from Arb.PRIORITY).
---@return boolean accepted  True if the request was applied.
function Arb.RequestAttackTarget(bot, target, reason, priority)
    if not IsValid(bot) then return false end
    priority = priority or Arb.PRIORITY.OPPORTUNISTIC
    reason   = reason   or "LEGACY"

    -- Defector guard: defectors cannot deal gun damage so attack targets
    -- are meaningless. Only self-defense retreat (handled elsewhere) matters.
    if ROLE_DEFECTOR and bot:GetSubRole() == ROLE_DEFECTOR then
        Arb.DebugTarget(bot, string.format("DEFECTOR_BLOCKED set %s (reason=%s) — defector cannot deal gun damage",
            IsValid(target) and (target.Nick and target:Nick() or tostring(target)) or "nil", reason))
        return false
    end

    -- Clearing via this path should use RequestClearTarget instead, but handle gracefully.
    if target == nil then
        return Arb.RequestClearTarget(bot, reason, priority)
    end

    -- Respawn grace gate: recently respawned bots need time to equip before
    -- fighting. Only self-defense (pri 5) overrides this.
    if (bot.respawnGraceUntil or 0) > CurTime() and priority < Arb.PRIORITY.SELF_DEFENSE then
        Arb.DebugTarget(bot, string.format("RESPAWN_GRACE_BLOCKED set %s (pri %d, reason=%s, grace until %.1f)",
            IsValid(target) and (target.Nick and target:Nick() or tostring(target)) or "nil",
            priority, reason, bot.respawnGraceUntil))
        return false
    end

    -- Karma awareness gate: block attacks that would risk auto-kick
    local KarmaAwareness = TTTBots.Morality
    if KarmaAwareness.CheckPreAttack and not KarmaAwareness.CheckPreAttack(bot, priority) then
        Arb.DebugTarget(bot, string.format("KARMA_BLOCKED set %s (pri %d, reason=%s)",
            IsValid(target) and (target.Nick and target:Nick() or tostring(target)) or "nil",
            priority, reason))
        return false
    end

    local currentPriority = bot.attackTargetPriority or -1

    -- Only allow if new priority >= current (higher or equal priority wins).
    if priority < currentPriority then
        Arb.DebugTarget(bot, string.format("REJECTED set %s (pri %d < current %d, reason=%s)",
            IsValid(target) and (target.Nick and target:Nick() or tostring(target)) or "nil",
            priority, currentPriority, reason))
        return false
    end

    -- Delegate to the original SetAttackTarget (which has ally/hook guards).
    -- We temporarily mark the bot so SetAttackTarget can record the reason.
    bot._pendingTargetReason   = reason
    bot._pendingTargetPriority = priority
    bot:SetAttackTarget(target)

    -- Check if SetAttackTarget actually accepted (it may reject allies, etc.)
    if bot.attackTarget == target then
        bot.attackTargetReason   = reason
        bot.attackTargetPriority = priority
        Arb.DebugTarget(bot, string.format("SET target=%s pri=%d reason=%s",
            IsValid(target) and (target.Nick and target:Nick() or tostring(target)) or "nil",
            priority, reason))
        return true
    else
        bot._pendingTargetReason   = nil
        bot._pendingTargetPriority = nil
        Arb.DebugTarget(bot, string.format("BLOCKED by SetAttackTarget guards (target=%s, reason=%s)",
            IsValid(target) and (target.Nick and target:Nick() or tostring(target)) or "nil",
            reason))
        return false
    end
end

--- Request clearing the bot's current attack target. Clears always succeed when:
---   1. priority >= current lock priority, OR
---   2. priority == BEHAVIOR_CLEAR (0) — always allowed for clears.
---
---@param bot Player
---@param reason string    A reason code key.
---@param priority number  A priority tier.
---@return boolean accepted
function Arb.RequestClearTarget(bot, reason, priority)
    if not IsValid(bot) then return false end
    priority = priority or Arb.PRIORITY.BEHAVIOR_CLEAR
    reason   = reason   or "BEHAVIOR_END"

    local currentPriority = bot.attackTargetPriority or -1

    -- Clears at priority 0 always succeed; otherwise must meet or exceed.
    if priority > 0 and priority < currentPriority then
        Arb.DebugTarget(bot, string.format("REJECTED clear (pri %d < current %d, reason=%s)",
            priority, currentPriority, reason))
        return false
    end

    bot._pendingTargetReason   = reason
    bot._pendingTargetPriority = priority
    bot:SetAttackTarget(nil)

    -- Record after clear
    bot.attackTargetReason   = reason
    bot.attackTargetPriority = 0  -- Reset priority after clearing
    Arb.DebugTarget(bot, string.format("CLEARED reason=%s", reason))
    return true
end

--- Reset arbitration state on a bot. Called on round reset or bot initialization.
---@param bot Player
function Arb.ResetState(bot)
    if not IsValid(bot) then return end
    bot.attackTargetReason   = nil
    bot.attackTargetPriority = 0
    bot._pendingTargetReason = nil
    bot._pendingTargetPriority = nil
end

--- Get a human-readable label for the bot's current target reason.
---@param bot Player
---@return string
function Arb.GetTargetReasonLabel(bot)
    local reason = bot.attackTargetReason or "none"
    return Arb.REASON_LABELS[reason] or reason
end
