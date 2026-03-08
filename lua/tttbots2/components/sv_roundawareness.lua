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
    hook.Add("PlayerDeath", "TTTBots.RoundAwareness.PlayerDeath", function(victim, inflictor, attacker)
        if not TTTBots.Bots then return end
        local now = CurTime()
        for _, bot in ipairs(TTTBots.Bots) do
            if IsValid(bot) and bot.components and bot.components.roundawareness then
                bot.components.roundawareness.tooQuietTimer = now
            end
        end
    end)

end
