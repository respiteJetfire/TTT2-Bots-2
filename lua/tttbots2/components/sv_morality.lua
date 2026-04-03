--- sv_morality.lua
--- Morality component coordinator.  The heavy logic has been decomposed into:
---   morality/sv_morality_arbitration.lua  — priority-based target gateway + reason codes
---   morality/sv_morality_suspicion.lua    — witness events, suspicion tracking, announcements
---   morality/sv_morality_hostility.lua    — role/team "common sense" attack/prevent policy
---
--- This file retains: class skeleton, New/Initialize/Think, and the opportunistic
--- targeting functions (SetRandomNearbyTarget, TickIfLastAlive) that form the
--- "arbitration phase" of the Think loop.

---@class CMorality : Component
TTTBots.Components.Morality = TTTBots.Components.Morality or {}

local lib = TTTBots.Lib
---@class CMorality : Component
local BotMorality = TTTBots.Components.Morality

-- ---------------------------------------------------------------------------
-- Sub-module includes  (order matters — arbitration first, then the others)
-- ---------------------------------------------------------------------------
include("tttbots2/components/morality/sv_morality_arbitration.lua")
include("tttbots2/components/morality/sv_karma_awareness.lua")
include("tttbots2/components/morality/sv_morality_suspicion.lua")
include("tttbots2/components/morality/sv_morality_hostility.lua")
include("tttbots2/components/morality/sv_morality_smartbullets.lua")

local Arb = TTTBots.Morality
local PRI = Arb.PRIORITY

-- ===========================================================================
-- Component lifecycle
-- ===========================================================================

function BotMorality:New(bot)
    local newMorality = {}
    setmetatable(newMorality, {
        __index = function(t, k) return BotMorality[k] end,
    })
    newMorality:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        print("Initialized Morality for bot " .. bot:Nick())
    end

    return newMorality
end

function BotMorality:Initialize(bot)
    bot.components = bot.components or {}
    bot.components.morality = self

    self.componentID = string.format("Morality (%s)", lib.GenerateID())
    self.ThinkRate = 1 -- Run every tick (5Hz)

    self.tick = 0
    self.bot = bot ---@type Bot
    self.suspicions = {}
    self.roleGuesses = {}

    Arb.ResetState(bot)
end

-- ===========================================================================
-- Opportunistic targeting (runs inside Think)
-- ===========================================================================

--- Returns a random victim player, weighted off of each player's traits.
---@param playerlist table<Player>
---@return Player
function BotMorality:GetRandomVictimFrom(playerlist)
    local tbl = {}

    for i, player in pairs(playerlist) do
        if player:IsBot() then
            local victim = player:GetTraitMult("victim")
            table.insert(tbl, lib.SetWeight(player, victim))
        else
            table.insert(tbl, lib.SetWeight(player, 1))
        end
    end

    return lib.RandomWeighted(tbl)
end

--- Makes it so that traitor bots will attack random players nearby.
--- Phase-aware: deceptive roles avoid attacking in EARLY phase unless truly isolated.
function BotMorality:SetRandomNearbyTarget()
    if not (self.tick % TTTBots.Tickrate == 0) then return end
    local roundStarted = TTTBots.Match.RoundActive
    local roleData = TTTBots.Roles.GetRoleFor(self.bot)
    local targetsRandoms = roleData:GetStartsFights()
    if not (roundStarted and targetsRandoms) then return end
    if self.bot.attackTarget ~= nil then return end
    local delay = lib.GetConVarFloat("attack_delay")
    if TTTBots.Match.Time() <= delay then return end

    -- Phase awareness: deceptive roles should blend in during EARLY phase.
    -- Roles that are KOS by all (doomguy, etc.) are already exposed — they skip this gate.
    local ra = self.bot:BotRoundAwareness()
    local phase = ra and ra:GetPhase() or "EARLY"
    local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
    local isKOSedByAll = roleData.GetKOSedByAll and roleData:GetKOSedByAll()

    local aggression = math.max((self.bot:GetTraitMult("aggression")) * (self.bot:BotPersonality().rage / 100), 0.3)
    local time_modifier = TTTBots.Match.SecondsPassed / 30
    -- Phase-based aggression scaling: traitors become bolder as round progresses
    if ra then
        time_modifier = time_modifier * ra:GetAggressionMult()
    end

    -- Armor aggression boost: armored bots (especially SK) are more willing to engage
    local armorBoost = 1.0
    local botArmor = self.bot:Armor() or 0
    if botArmor > 30 then
        armorBoost = 1.3  -- 30% more aggressive with armor
    elseif botArmor > 0 then
        armorBoost = 1.15
    end
    aggression = aggression * armorBoost

    local maxTargets = math.max(2, math.ceil(aggression * 2 * time_modifier))
    local targets = lib.GetAllVisible(self.bot:EyePos(), true, self.bot)
    if (#targets > maxTargets) or (#targets == 0) then return end

    -- EARLY phase suppression for deceptive roles:
    -- Only attack if the target is truly isolated (1 visible enemy, no other witnesses).
    -- KOS-by-all roles (Doomguy etc.) skip this — they are already publicly hostile.
    -- EXCEPTION: solo traitors (last one alive on their team) skip EARLY suppression
    -- entirely — they need to act now, not wait for allies that no longer exist.
    if PHASE and phase == PHASE.EARLY and not isKOSedByAll then
        -- Check if this bot is the last traitor alive
        local isSoloTraitor = false
        local aliveAllies = TTTBots.Roles.GetLivingAllies(self.bot)
        if aliveAllies then
            local aliveAllyCount = 0
            for _, ally in ipairs(aliveAllies) do
                if ally ~= self.bot then
                    aliveAllyCount = aliveAllyCount + 1
                end
            end
            isSoloTraitor = (aliveAllyCount == 0)
        end

        if not isSoloTraitor then
            -- Normal EARLY phase suppression: refuse to start random fights
            -- unless there is exactly 1 visible non-ally and no other witnesses.
            if #targets > 1 then return end
            local soleTarget = targets[1]
            if soleTarget and IsValid(soleTarget) then
                local witnessesNearTarget = lib.GetAllWitnessesBasic(
                    soleTarget:GetPos(),
                    TTTBots.Roles.GetNonAllies(self.bot),
                    self.bot
                )
                -- Abort if anyone else can see the target (we'd be caught)
                if table.Count(witnessesNearTarget) > 1 then return end
            end
            -- Even with an isolated target in EARLY, dramatically reduce the chance
            aggression = aggression * 0.15
        else
            -- Solo traitor in EARLY: still prefer isolated targets but don't
            -- hard-block on witness count. Moderate suppression instead of near-zero.
            if #targets > 2 then return end
            aggression = aggression * 0.5
        end
    end

    -- MID phase: moderate suppression — reduce chance somewhat
    if PHASE and phase == PHASE.MID and not isKOSedByAll then
        if #targets > 2 then return end -- don't attack in groups of 3+
        aggression = aggression * 0.5
    end

    local base_chance = 4.5
    local chanceAttackPerSec = (
        base_chance
        * aggression
        * (maxTargets / #targets)
        * time_modifier
        * (#targets == 1 and 5 or 1)
    )
    if lib.TestPercent(chanceAttackPerSec) then
        local target = BotMorality:GetRandomVictimFrom(targets)
        Arb.RequestAttackTarget(self.bot, target, "OPPORTUNISTIC_ATTACK", PRI.OPPORTUNISTIC)
    end
end

function BotMorality:TickIfLastAlive()
    if not TTTBots.Match.RoundActive then return end
    local plys = self.bot.components.memory:GetActualAlivePlayers()

    -- Phase-aware threshold: trigger at ≤3 players in LATE/OVERTIME, ≤2 otherwise
    local threshold = 2
    local ra = self.bot:BotRoundAwareness()
    if ra then
        local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
        if PHASE and (ra:IsPhase(PHASE.LATE) or ra:IsPhase(PHASE.OVERTIME)) then
            threshold = 3
        end
    end

    if #plys > threshold then return end

    local otherPlayer = nil
    for i, ply in pairs(plys) do
        if ply ~= self.bot then
            otherPlayer = ply
            break
        end
    end

    if not otherPlayer then return end
    local isCloaked = TTTBots.Match.IsPlayerCloaked(otherPlayer)
    if isCloaked then return end

    -- Don't force innocent bots to attack perceived allies. Only attack if
    -- the other player is NOT an ally or if the bot has significant suspicion.
    local isAlly = (TTTBots.Perception and TTTBots.Perception.IsPerceivedAlly(self.bot, otherPlayer))
        or TTTBots.Roles.IsAllies(self.bot, otherPlayer)
    if isAlly then
        local morality = self.bot.components and self.bot.components.morality
        local sus = morality and morality:GetSuspicion(otherPlayer) or 0
        if sus < (TTTBots.Components.Morality.Thresholds and TTTBots.Components.Morality.Thresholds.Sus or 3) then
            return -- Don't attack an ally we don't suspect
        end
    end

    Arb.RequestAttackTarget(self.bot, otherPlayer, "LAST_ALIVE", PRI.OPPORTUNISTIC)
end

-- ===========================================================================
-- Round reset — wipe ALL per-round morality / suspicion state
-- ===========================================================================

--- Full morality state wipe. Must be called on every round boundary to prevent
--- suspicion, role guesses, grudges, and other per-round state from leaking
--- into the next round.
function BotMorality:ResetRoundState()
    self.suspicions = {}
    self.roleGuesses = {}
    self.roleGuessTimestamps = {}
    self.testedClean = nil
    self._confirmedHostilesSeen = nil

    local bot = self.bot
    if not IsValid(bot) then return end

    -- Clear per-bot fields that accumulate during a round
    bot.grudge              = nil
    bot.personalSpaceTbl    = nil
    bot.redHandedTime       = nil
    bot.selfDefenseKills    = nil
    bot.lastKillTime        = nil
    bot.pendingAccusations  = nil
    bot.respawnGraceUntil   = nil

    -- Reset arbitration state (attack target priority & reason)
    Arb.ResetState(bot)
end

hook.Add("TTTEndRound", "TTTBots.Morality.ResetRoundState", function()
    local isPostRoundDM = TTTBots.Match.IsPostRoundDM()
    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and bot.components and bot.components.morality) then continue end
        if isPostRoundDM then
            -- Post-round DM: clear suspicion/role state but keep the bot combat-ready.
            -- Attack targets are cleared by the Match hook; FFA targeting will reassign.
            local morality = bot.components.morality
            morality.suspicions = {}
            morality.roleGuesses = {}
            morality.roleGuessTimestamps = {}
            morality.testedClean = nil
            morality._confirmedHostilesSeen = nil
            bot.grudge = nil
            bot.personalSpaceTbl = nil
            bot.pendingAccusations = nil
        else
            bot.components.morality:ResetRoundState()
        end
    end
end)

hook.Add("TTTPrepareRound", "TTTBots.Morality.PrepareRoundReset", function()
    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and bot.components and bot.components.morality) then continue end
        bot.components.morality:ResetRoundState()
    end
end)

-- ===========================================================================
-- Respawn grace period — clear stale combat state so bots equip first
-- ===========================================================================

--- Seconds after a mid-round respawn during which the bot won't initiate
--- attacks (it needs time to pick up weapons / heal). Self-defense (priority 5)
--- still overrides this.
local RESPAWN_GRACE_SECONDS = 5

hook.Add("PlayerSpawn", "TTTBots.Morality.RespawnGrace", function(ply)
    if not IsValid(ply) then return end
    if not ply:IsBot() then return end
    if not TTTBots.Match.IsRoundActive() then return end

    -- Delay slightly so that role data, inventory, etc. are initialised.
    timer.Simple(0, function()
        if not IsValid(ply) then return end
        if not TTTBots.Match.IsRoundActive() then return end

        -- Clear any attack target that survived death (stale from pre-death)
        if ply.attackTarget ~= nil then
            ply:SetAttackTarget(nil, "RESPAWN_CLEAR")
        end
        ply.grudge = nil

        -- Clear stale behavior so the tree re-evaluates from scratch
        if ply.lastBehavior then
            pcall(function()
                ply.lastBehavior.OnEnd(ply)
            end)
            ply.lastBehavior = nil
        end

        -- Set grace period: blocks low-priority attack requests so the bot
        -- has time to pick up weapons and find health first.
        ply.respawnGraceUntil = CurTime() + RESPAWN_GRACE_SECONDS

        Arb.DebugTarget(ply, string.format(
            "RESPAWN_GRACE set for %.1fs (until %.1f)",
            RESPAWN_GRACE_SECONDS, ply.respawnGraceUntil))
    end)
end)

-- ===========================================================================
-- Think — orchestrates the per-tick morality update
-- ===========================================================================

function BotMorality:Think()
    self.tick = (self.bot.tick or 0)
    if not lib.IsPlayerAlive(self.bot) then return end

    -- Post-round DM: skip all role-based morality, FFA targeting is handled
    -- by the dedicated PostRoundDM timer in sv_morality_hostility.lua
    if TTTBots.Match.IsPostRoundDM() then return end

    self:TickSuspicions()        -- from sv_morality_suspicion.lua
    self:SetRandomNearbyTarget() -- opportunistic (this file)
    self:TickIfLastAlive()       -- opportunistic (this file)

    -- Per-tick on-sight KOS response: innocents/detectives engage a KOS target
    -- the moment they see one, without waiting for the 1-second CommonSense timer.
    if TTTBots.Morality.AttackKOSListed then
        TTTBots.Morality.AttackKOSListed(self.bot)
    end

    -- Per-tick KOSedByAll response: all bots react immediately when they see a
    -- KOSedByAll target (Doomguy, infected zombies, etc.) instead of waiting
    -- for the 1-second CommonSense timer.
    if TTTBots.Morality.AttackKOSedByAll then
        TTTBots.Morality.AttackKOSedByAll(self.bot)
    end

    -- Per-tick restless aggression: restless bots with a ranged weapon attack
    -- any visible non-ally immediately.
    if TTTBots.Morality.RestlessRangedAggression then
        TTTBots.Morality.RestlessRangedAggression(self.bot)
    end

    -- Per-tick confirmed hostiles: react immediately when a player's hostile
    -- role has been publicly confirmed by TTT2 (body searched, resurrected, etc.)
    if TTTBots.Morality.AttackConfirmedHostiles then
        TTTBots.Morality.AttackConfirmedHostiles(self.bot)
    end
end

-- ===========================================================================
-- Player meta accessor
-- ===========================================================================

---@class Player
local plyMeta = FindMetaTable("Player")
function plyMeta:BotMorality()
    ---@cast self Bot
    return self.components and self.components.morality or nil
end
