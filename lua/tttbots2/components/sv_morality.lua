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
function BotMorality:SetRandomNearbyTarget()
    if not (self.tick % TTTBots.Tickrate == 0) then return end
    local roundStarted = TTTBots.Match.RoundActive
    local targetsRandoms = TTTBots.Roles.GetRoleFor(self.bot):GetStartsFights()
    if not (roundStarted and targetsRandoms) then return end
    if self.bot.attackTarget ~= nil then return end
    local delay = lib.GetConVarFloat("attack_delay")
    if TTTBots.Match.Time() <= delay then return end

    local aggression = math.max((self.bot:GetTraitMult("aggression")) * (self.bot:BotPersonality().rage / 100), 0.3)
    local time_modifier = TTTBots.Match.SecondsPassed / 30
    -- Phase-based aggression scaling: traitors become bolder as round progresses
    local ra = self.bot:BotRoundAwareness()
    if ra then
        time_modifier = time_modifier * ra:GetAggressionMult()
    end

    local maxTargets = math.max(2, math.ceil(aggression * 2 * time_modifier))
    local targets = lib.GetAllVisible(self.bot:EyePos(), true, self.bot)
    if (#targets > maxTargets) or (#targets == 0) then return end

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

    Arb.RequestAttackTarget(self.bot, otherPlayer, "LAST_ALIVE", PRI.OPPORTUNISTIC)
end

-- ===========================================================================
-- Think — orchestrates the per-tick morality update
-- ===========================================================================

function BotMorality:Think()
    self.tick = (self.bot.tick or 0)
    if not lib.IsPlayerAlive(self.bot) then return end
    self:TickSuspicions()        -- from sv_morality_suspicion.lua
    self:SetRandomNearbyTarget() -- opportunistic (this file)
    self:TickIfLastAlive()       -- opportunistic (this file)
end

-- ===========================================================================
-- Player meta accessor
-- ===========================================================================

---@class Player
local plyMeta = FindMetaTable("Player")
function plyMeta:BotMorality()
    ---@cast self Bot
    return self.components.morality
end
