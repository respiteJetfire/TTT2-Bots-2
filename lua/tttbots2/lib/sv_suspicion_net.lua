---------------------------------------------------------------------------
-- sv_suspicion_net.lua
-- Server-side suspicion data collection, event ring buffer, and networking.
--
-- Records every ChangeSuspicion call into a ring buffer so clients can see
-- exactly what happened, when, and in what order.  Also snapshots each bot's
-- current suspicion table on request.
--
-- Network messages:
--   TTTBots_RequestSuspicionData   (C→S)  client requests a snapshot
--   TTTBots_SuspicionData          (S→C)  server sends compressed JSON
---------------------------------------------------------------------------

TTTBots.SuspicionNet = TTTBots.SuspicionNet or {}
local SusNet = TTTBots.SuspicionNet

local lib = TTTBots.Lib
local DebugServer = TTTBots.DebugServer   -- reuse GetCompressedTable

-- -----------------------------------------------------------------------
-- Event ring buffer
-- -----------------------------------------------------------------------

--- Maximum events kept in memory (oldest are discarded first).
local MAX_EVENTS = 200

SusNet.Events = SusNet.Events or {}

--- Record a suspicion change event.
---@param bot      Player   The bot whose suspicion changed
---@param target   Player   The player the suspicion is about
---@param reason   string   SUSPICIONVALUES key
---@param delta    number   The raw increase value (after mult/pressure)
---@param newTotal number   Suspicion value after the change
---@param extra    table?   Optional extra context (mult, pressure, etc.)
function SusNet.RecordEvent(bot, target, reason, delta, newTotal, extra)
    if not (IsValid(bot) and IsValid(target)) then return end

    local ev = {
        t   = math.Round(CurTime(), 2),
        rt  = math.Round(TTTBots.Match.SecondsPassed or 0, 1),
        bot = bot:Nick(),
        tgt = target:Nick(),
        rsn = reason,
        d   = delta,
        tot = newTotal,
    }

    if extra then
        if extra.mult and extra.mult ~= 1 then ev.mul = math.Round(extra.mult, 2) end
        if extra.pressure and extra.pressure ~= 1 then ev.prs = math.Round(extra.pressure, 2) end
        if extra.rawValue then ev.raw = extra.rawValue end
        if extra.threshold then ev.thr = extra.threshold end
        -- Multi-dimensional channel data
        if extra.threat then ev.threat = math.Round(extra.threat, 1) end
        if extra.trust then ev.trust = math.Round(extra.trust, 1) end
        if extra.confidence then ev.conf = math.Round(extra.confidence, 2) end
    end

    local events = SusNet.Events
    events[#events + 1] = ev
    -- Trim from front if we exceed the cap
    while #events > MAX_EVENTS do
        table.remove(events, 1)
    end
end

--- Clear all recorded events (called on round reset).
function SusNet.ClearEvents()
    SusNet.Events = {}
end

hook.Add("TTTEndRound",     "TTTBots.SusNet.Clear", SusNet.ClearEvents)
hook.Add("TTTPrepareRound", "TTTBots.SusNet.Clear", SusNet.ClearEvents)

-- -----------------------------------------------------------------------
-- Snapshot builder — gathers all bots' suspicion state
-- -----------------------------------------------------------------------

--- Build a snapshot of all bots' suspicion tables.
--- Now includes multi-dimensional channel data (threat/trust/confidence)
--- alongside the computed effective score for each target.
---@return table snapshot  { BotNick = { sus = { TargetNick = { eff, thr, tru, conf } }, meta = {...} }, ... }
local function BuildSuspicionSnapshot()
    local snapshot = {}

    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and bot.components and bot.components.morality) then continue end
        local morality = bot.components.morality
        local susMap = {}

        for target, rec in pairs(morality.suspicions or {}) do
            if IsValid(target) and target:IsPlayer() then
                if type(rec) == "table" then
                    susMap[target:Nick()] = {
                        eff  = morality:GetSuspicion(target),
                        thr  = math.Round(rec.threat or 0, 1),
                        tru  = math.Round(rec.trust or 0, 1),
                        conf = math.Round(rec.confidence or 0, 2),
                    }
                else
                    -- Legacy raw number (shouldn't happen but handle gracefully)
                    susMap[target:Nick()] = {
                        eff  = rec,
                        thr  = math.max(rec, 0),
                        tru  = math.max(-rec, 0),
                        conf = 0.7,
                    }
                end
            end
        end

        -- Also include attack target and role guesses for context
        local meta = {}
        if IsValid(bot.attackTarget) then
            meta.atkTarget = bot.attackTarget:Nick()
            meta.atkReason = bot.attackTargetReason or "?"
        end

        -- Include role for context (what team is this bot on?)
        local roleData = TTTBots.Roles.GetRoleFor(bot)
        if roleData then
            meta.role = roleData:GetName()
            meta.team = roleData:GetTeam() or "?"
        end

        -- Include round-awareness phase
        local ra = bot:BotRoundAwareness()
        if ra and ra.GetPhase then
            meta.phase = tostring(ra:GetPhase())
        end

        -- Role guesses
        local guesses = {}
        for tgt, roleObj in pairs(morality.roleGuesses or {}) do
            if IsValid(tgt) then
                guesses[tgt:Nick()] = roleObj:GetName()
            end
        end
        if next(guesses) then meta.guesses = guesses end

        snapshot[bot:Nick()] = {
            sus  = susMap,
            meta = meta,
        }
    end

    return snapshot
end

--- Build the thresholds table (static, but sent so client doesn't need to hardcode).
local function GetThresholds()
    local BotMorality = TTTBots.Components.Morality
    if not BotMorality or not BotMorality.Thresholds then
        return { KOS = 10, Sus = 5, Trust = -3, Innocent = -7 }
    end
    return BotMorality.Thresholds
end

-- -----------------------------------------------------------------------
-- Network handler
-- -----------------------------------------------------------------------

net.Receive("TTTBots_RequestSuspicionData", function(len, ply)
    if not (IsValid(ply) and ply:IsSuperAdmin()) then return end

    -- Read the last-seen event index from client so we can send only new events
    local clientLastIdx = net.ReadUInt(32)

    local payload = {
        thresholds = GetThresholds(),
        snapshot    = BuildSuspicionSnapshot(),
        roundTime   = math.Round(TTTBots.Match.SecondsPassed or 0, 1),
        roundActive = TTTBots.Match.RoundActive or false,
    }

    -- Send only events the client hasn't seen yet
    local allEvents = SusNet.Events
    if clientLastIdx < #allEvents then
        local newEvents = {}
        for i = clientLastIdx + 1, #allEvents do
            newEvents[#newEvents + 1] = allEvents[i]
        end
        payload.events     = newEvents
        payload.eventBase  = clientLastIdx  -- so client knows where these start
        payload.eventTotal = #allEvents
    else
        payload.events     = {}
        payload.eventBase  = #allEvents
        payload.eventTotal = #allEvents
    end

    local compressed, byteCount = DebugServer.GetCompressedTable(payload)

    net.Start("TTTBots_SuspicionData")
    net.WriteUInt(byteCount, 32)
    net.WriteData(compressed, byteCount)
    net.Send(ply)
end)

-- -----------------------------------------------------------------------
-- Hook into ChangeSuspicion to record events
-- -----------------------------------------------------------------------

--- We monkey-patch BotMorality:ChangeSuspicion to intercept every call.
--- This runs AFTER the module loads (via timer.Simple 0) so the method exists.
timer.Simple(0, function()
    local BotMorality = TTTBots.Components.Morality
    if not BotMorality or not BotMorality.ChangeSuspicion then
        ErrorNoHaltWithStack("[SusNet] Could not find BotMorality:ChangeSuspicion to hook!\n")
        return
    end

    local OriginalChangeSuspicion = BotMorality.ChangeSuspicion

    function BotMorality:ChangeSuspicion(target, reason, mult)
        -- Capture pre-change state
        local oldSus = self:GetSuspicion(target)
        local oldRec = self:GetSuspicionRecord(target)

        -- Call original
        OriginalChangeSuspicion(self, target, reason, mult)

        -- Capture post-change state
        local newSus = self:GetSuspicion(target)
        local newRec = self:GetSuspicionRecord(target)
        local delta = newSus - oldSus

        -- Only record if something actually changed
        if delta == 0 then return end

        -- Reconstruct the raw value and multipliers for the event log
        local rawValue = BotMorality.SUSPICIONVALUES[reason]
        local pressureMult = 1.0
        if rawValue and rawValue > 0 then
            local ra = self.bot:BotRoundAwareness()
            if ra then pressureMult = ra:GetSuspicionPressure() end
        end

        -- Determine if a threshold was crossed
        local threshold = nil
        local thresholds = BotMorality.Thresholds
        if thresholds then
            if oldSus < thresholds.KOS and newSus >= thresholds.KOS then
                threshold = "KOS"
            elseif oldSus < thresholds.Sus and newSus >= thresholds.Sus then
                threshold = "Sus"
            elseif oldSus > thresholds.Trust and newSus <= thresholds.Trust then
                threshold = "Trust"
            elseif oldSus > thresholds.Innocent and newSus <= thresholds.Innocent then
                threshold = "Innocent"
            end
        end

        SusNet.RecordEvent(self.bot, target, reason, delta, newSus, {
            mult      = mult or 1,
            pressure  = pressureMult,
            rawValue  = rawValue,
            threshold = threshold,
            -- Multi-dimensional channel data
            threat     = newRec and newRec.threat or nil,
            trust      = newRec and newRec.trust or nil,
            confidence = newRec and newRec.confidence or nil,
        })
    end

    print("[TTT Bots 2] Suspicion Monitor: server-side event capture active.")
end)
