---@class CRoundAwareness : Component
--- Component that tracks round timing, phase, and derived tactical awareness values
--- for bots. Provides phase (EARLY/MID/LATE/OVERTIME), aggression multipliers,
--- group urgency, suspicion pressure, and traitor overtake detection.

TTTBots.Components.RoundAwareness = {}

local BotRoundAwareness = TTTBots.Components.RoundAwareness
local lib = TTTBots.Lib

---------------------------------------------------------------------------
-- Phase constants
---------------------------------------------------------------------------

BotRoundAwareness.PHASE = {
    EARLY    = "EARLY",    -- 0–25 % of round time
    MID      = "MID",      -- 25–60 %
    LATE     = "LATE",     -- 60–85 %
    OVERTIME = "OVERTIME", -- 85 %+
}

local PHASE = BotRoundAwareness.PHASE

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function BotRoundAwareness:New(bot)
    local newObj = {}
    setmetatable(newObj, self)
    self.__index = self

    newObj.componentID = string.format("RoundAwareness (%s)", lib.GenerateID())
    newObj.bot = bot

    newObj:Initialize(bot)
    return newObj
end

function BotRoundAwareness:Initialize(bot)
    self.ThinkRate = 3 -- Run every 3rd tick (~1.7Hz)
    self.bot = bot or self.bot
    self:ClearRoundState()
end

---------------------------------------------------------------------------
-- State reset
---------------------------------------------------------------------------

function BotRoundAwareness:ClearRoundState()
    self.phase                  = PHASE.EARLY
    self.phaseProgress          = 0.0
    self.isHaste                = false
    self.roundDurationSecs      = 600      -- default 10 min, re-read on round start
    self.aggressionMult         = 1.0
    self.groupUrgency           = 0.1
    self.suspicionPressure      = 1.0
    self.overtake               = false
    self.traitorCount           = 0
    self.confirmedTraitorDeaths = 0
    self.tooQuiet               = false
    self.tooQuietTimer          = CurTime()
    self.minPhase               = nil       -- forced minimum phase (set when ally dies)
    self.minAggressionMult      = nil       -- forced minimum aggression (set when ally dies)
end

---------------------------------------------------------------------------
-- Round-start initialisation
---------------------------------------------------------------------------

function BotRoundAwareness:OnRoundStart()
    self:ClearRoundState()

    -- Read round duration from CVars
    local roundTimeCVar = GetConVar("ttt_roundtime_minutes")
    local roundMins     = roundTimeCVar and roundTimeCVar:GetInt() or 10
    self.roundDurationSecs = math.max(roundMins * 60, 60) -- at least 60 s

    -- Count initial traitors by examining every player's role
    local count = 0
    for ply, _ in pairs(TTTBots.Match.PlayersInRound) do
        if IsValid(ply) then
            local roleData = TTTBots.Roles.GetRoleFor(ply)
            if roleData and roleData:GetTeam() == TEAM_TRAITOR then
                count = count + 1
            end
        end
    end
    self.traitorCount = count

    if lib.GetConVarBool("debug_misc") then
        print(string.format("[RoundAwareness] Round started. Duration: %ds, Traitors: %d",
            self.roundDurationSecs, self.traitorCount))
    end
end

---------------------------------------------------------------------------
-- Phase + derived multipliers
---------------------------------------------------------------------------

function BotRoundAwareness:UpdatePhase()
    local Match   = TTTBots.Match
    local elapsed = Match.Time()

    local duration = self.roundDurationSecs
    if duration == 0 then duration = 600 end

    local progress = math.Clamp(elapsed / duration, 0, 1)

    -- Check haste mode
    local hasteCVar = GetConVar("ttt_haste")
    local haste     = hasteCVar and (hasteCVar:GetInt() == 1) or false
    self.isHaste    = haste

    -- Determine phase
    local phase
    if haste and progress > 0.5 then
        phase = PHASE.OVERTIME
    elseif progress < 0.25 then
        phase = PHASE.EARLY
    elseif progress < 0.60 then
        phase = PHASE.MID
    elseif progress < 0.85 then
        phase = PHASE.LATE
    else
        phase = PHASE.OVERTIME
    end

    -- Respect forced minimum phase (set when an allied traitor dies).
    -- Phase ordering: EARLY < MID < LATE < OVERTIME
    if self.minPhase then
        local phaseOrder = { [PHASE.EARLY] = 1, [PHASE.MID] = 2, [PHASE.LATE] = 3, [PHASE.OVERTIME] = 4 }
        local currentOrder = phaseOrder[phase] or 1
        local minOrder = phaseOrder[self.minPhase] or 1
        if currentOrder < minOrder then
            phase = self.minPhase
        end
    end

    self.phase         = phase
    self.phaseProgress = progress

    -- Aggression multiplier (meaningful for roles that start fights)
    local roleData       = TTTBots.Roles.GetRoleFor(self.bot)
    local startsFights   = roleData and roleData:GetStartsFights() or false
    local aggrBase
    if     phase == PHASE.EARLY    then aggrBase = 1.0
    elseif phase == PHASE.MID      then aggrBase = 1.3
    elseif phase == PHASE.LATE     then aggrBase = 1.7
    else                                aggrBase = 2.2 end
    if haste and phase == PHASE.OVERTIME then aggrBase = aggrBase + 0.3 end
    -- Respect forced minimum aggression (set when an allied traitor dies)
    if self.minAggressionMult and aggrBase < self.minAggressionMult then
        aggrBase = self.minAggressionMult
    end
    self.aggressionMult = startsFights and aggrBase or 1.0

    -- Group urgency (innocents benefit most)
    local urgencyBase
    if     phase == PHASE.EARLY    then urgencyBase = 0.1
    elseif phase == PHASE.MID      then urgencyBase = 0.3
    elseif phase == PHASE.LATE     then urgencyBase = 0.7
    else                                urgencyBase = 1.0 end

    -- Boost urgency by death proportion
    local totalInRound = table.Count(Match.PlayersInRound)
    local aliveCount   = #Match.AlivePlayers
    local deadCount    = totalInRound - aliveCount
    if totalInRound > 0 then
        urgencyBase = urgencyBase + (deadCount / totalInRound) * 0.3
    end
    self.groupUrgency = math.Clamp(urgencyBase, 0.0, 1.0)

    -- Overtake: traitors have numbers advantage
    local aliveTraitors    = 0
    local aliveNonTraitors = 0
    for _, ply in ipairs(Match.AlivePlayers) do
        if IsValid(ply) then
            local rd = TTTBots.Roles.GetRoleFor(ply)
            if rd and rd:GetTeam() == TEAM_TRAITOR then
                aliveTraitors = aliveTraitors + 1
            else
                aliveNonTraitors = aliveNonTraitors + 1
            end
        end
    end
    self.overtake = (aliveTraitors >= aliveNonTraitors) and (aliveTraitors > 0)
end

---------------------------------------------------------------------------
-- Suspicion pressure
---------------------------------------------------------------------------

function BotRoundAwareness:UpdateSuspicionPressure()
    local Match      = TTTBots.Match
    local aliveCount = #Match.AlivePlayers

    -- "known" players = confirmed dead + self; everyone else is unknown
    local unknownCount = math.max(aliveCount - 1, 0) -- subtract self

    local pressure
    if     unknownCount == 0 then pressure = 3.0
    elseif unknownCount == 1 then pressure = 2.0
    elseif unknownCount <= 3 then pressure = 1.5
    else                          pressure = 1.0 end

    self.suspicionPressure = pressure
end

---------------------------------------------------------------------------
-- Traitor death tracking
---------------------------------------------------------------------------

function BotRoundAwareness:UpdateTraitorDeaths()
    -- Only relevant for traitors or omniscient roles
    local roleData = TTTBots.Roles.GetRoleFor(self.bot)
    if not roleData then return end
    local team = roleData:GetTeam()
    if team ~= TEAM_TRAITOR then return end

    local count = 0
    for ply, _ in pairs(TTTBots.Match.ConfirmedDead) do
        if IsValid(ply) then
            local rd = TTTBots.Roles.GetRoleFor(ply)
            if rd and rd:GetTeam() == TEAM_TRAITOR then
                count = count + 1
            end
        end
    end
    self.confirmedTraitorDeaths = count
end

---------------------------------------------------------------------------
-- "Too quiet" detection
---------------------------------------------------------------------------

function BotRoundAwareness:UpdateTooQuiet()
    local TOO_QUIET_THRESHOLD = 90 -- seconds of silence = suspicious
    self.tooQuiet = (CurTime() - self.tooQuietTimer) > TOO_QUIET_THRESHOLD
end

---------------------------------------------------------------------------
-- Think
---------------------------------------------------------------------------

function BotRoundAwareness:Think()
    if not TTTBots.Match.RoundActive then return end

    self:UpdatePhase()
    self:UpdateSuspicionPressure()
    self:UpdateTraitorDeaths()
    self:UpdateTooQuiet()
end

---------------------------------------------------------------------------
-- Getters
---------------------------------------------------------------------------

function BotRoundAwareness:GetPhase()
    return self.phase
end

function BotRoundAwareness:GetPhaseProgress()
    return self.phaseProgress
end

function BotRoundAwareness:IsHaste()
    return self.isHaste
end

function BotRoundAwareness:GetAggressionMult()
    return self.aggressionMult
end

function BotRoundAwareness:GetGroupUrgency()
    return self.groupUrgency
end

function BotRoundAwareness:GetSuspicionPressure()
    return self.suspicionPressure
end

function BotRoundAwareness:IsOvertake()
    return self.overtake
end

function BotRoundAwareness:IsTooQuiet()
    return self.tooQuiet or false
end

function BotRoundAwareness:GetRemainingTraitorCount()
    return math.max(self.traitorCount - self.confirmedTraitorDeaths, 0)
end

function BotRoundAwareness:IsPhase(phase)
    return self.phase == phase
end

--- Returns the estimated seconds remaining in the round.
--- Based on round duration ConVar minus elapsed seconds.
---@return number secondsRemaining
function BotRoundAwareness:GetSecondsRemaining()
    local elapsed = TTTBots.Match.Time()
    local remaining = self.roundDurationSecs - elapsed
    return math.max(remaining, 0)
end

--- Returns true if 15 or fewer seconds remain in the round.
--- Used to suppress deceptive/subtle behaviors and force direct engagement.
---@return boolean
function BotRoundAwareness:IsEndgame()
    return self:GetSecondsRemaining() <= 15
end

---------------------------------------------------------------------------
-- Player meta accessor
---------------------------------------------------------------------------

local plyMeta = FindMetaTable("Player")

function plyMeta:BotRoundAwareness()
    return self.components and self.components.roundawareness
end

---------------------------------------------------------------------------
-- Server-side hooks
---------------------------------------------------------------------------

if SERVER then

    --- On round begin: initialise every bot's round awareness state
    hook.Add("TTTBeginRound", "TTTBots.RoundAwareness.OnRoundStart", function()
        if not TTTBots.Bots then return end
        for _, bot in ipairs(TTTBots.Bots) do
            if IsValid(bot) then
                local comp = bot:BotRoundAwareness()
                if comp then
                    comp:OnRoundStart()
                end
            end
        end
    end)

    --- On player death: reset the "too quiet" timer for all bots
    --- and escalate phase for surviving traitor allies when a teammate dies.
    hook.Add("PlayerDeath", "TTTBots.RoundAwareness.PlayerDeath", function(victim, inflictor, attacker)
        if not TTTBots.Bots then return end
        local now = CurTime()

        -- Check if the victim was a traitor-team member
        local victimIsTraitor = false
        if IsValid(victim) then
            local victimRole = TTTBots.Roles.GetRoleFor(victim)
            if victimRole and victimRole:GetTeam() == TEAM_TRAITOR then
                victimIsTraitor = true
            end
        end

        for _, bot in ipairs(TTTBots.Bots) do
            if IsValid(bot) and bot.components and bot.components.roundawareness then
                bot.components.roundawareness.tooQuietTimer = now

                -- When a traitor teammate dies, escalate surviving traitors'
                -- phase to at least MID with boosted aggression.
                -- This prevents the "solo traitor stuck in EARLY" problem.
                if victimIsTraitor and bot ~= victim and TTTBots.Lib.IsPlayerAlive(bot) then
                    local botRole = TTTBots.Roles.GetRoleFor(bot)
                    if botRole and botRole:GetTeam() == TEAM_TRAITOR then
                        local ra = bot.components.roundawareness
                        local currentPhase = ra.phase

                        -- If still in EARLY, force-escalate to MID
                        if currentPhase == PHASE.EARLY then
                            ra.phase = PHASE.MID
                            ra.aggressionMult = math.max(ra.aggressionMult, 1.5)
                            -- Set minimum phase floor so UpdatePhase doesn't
                            -- downgrade back to EARLY on the next think tick
                            ra.minPhase = PHASE.MID
                            ra.minAggressionMult = 1.5

                            -- Check if this bot is now the LAST traitor alive
                            local aliveTraitorAllies = 0
                            local allies = TTTBots.Roles.GetLivingAllies(bot)
                            if allies then
                                for _, ally in ipairs(allies) do
                                    if ally ~= bot and TTTBots.Lib.IsPlayerAlive(ally) then
                                        aliveTraitorAllies = aliveTraitorAllies + 1
                                    end
                                end
                            end

                            -- Solo traitor gets even more aggressive
                            if aliveTraitorAllies == 0 then
                                ra.phase = PHASE.LATE
                                ra.aggressionMult = math.max(ra.aggressionMult, 1.7)
                                ra.minPhase = PHASE.LATE
                                ra.minAggressionMult = 1.7
                            end

                            if TTTBots.Lib.GetConVarBool("debug_misc") then
                                print(string.format(
                                    "[RoundAwareness] %s phase escalated to %s (ally %s died, aggr=%.1f)",
                                    bot:Nick(), ra.phase, victim:Nick(), ra.aggressionMult))
                            end
                        end

                        -- Also clear any current FollowPlan job so the bot
                        -- re-evaluates with new (solo) conditions
                        local state = TTTBots.Behaviors.GetState(bot, "FollowPlan")
                        if state and state.Job then
                            local job = state.Job
                            -- Clear jobs gated on MinTraitors that no longer apply
                            if job.Conditions and job.Conditions.MinTraitors then
                                local aliveTraitors = #TTTBots.Lib.FilterTable(
                                    TTTBots.Match.AlivePlayers,
                                    function(ply)
                                        local team = ply.GetTeam and ply:GetTeam()
                                        return team == TEAM_TRAITOR
                                    end)
                                if aliveTraitors < job.Conditions.MinTraitors then
                                    state.Job = nil
                                    state.shouldClear = true
                                end
                            end
                        end

                        -- Invalidate shared target cache so the survivor picks
                        -- a fresh target instead of re-engaging the player
                        -- who just killed the ally
                        if TTTBots.Plans.SharedTargetCache then
                            TTTBots.Plans.SharedTargetCache = {}
                        end
                    end
                end
            end
        end
    end)

end
