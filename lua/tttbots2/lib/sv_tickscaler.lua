--- Dynamic Tick Rate Scaler for TTT Bots 2
--- When many bots are present, this module logarithmically scales back how
--- often each bot's behavior tree and components tick, making bots "dumber"
--- on high-population servers while preserving full responsiveness for small
--- populations.
---
--- The master timer (`TTTBots_Tick`) keeps firing at the original `TTTBots.Tickrate`.
--- Instead of slowing the timer we increase **per-bot skip counts** so each
--- individual bot processes fewer ticks.  This keeps real-time timers, strafe
--- timeouts, and `Match.SecondsPassed` perfectly intact.
---
--- CVars (all prefixed with `ttt_bot_`):
---   tickscaler_enabled           0/1   Master toggle (default 0 — opt-in)
---   tickscaler_threshold         int   Bot count at or below which no scaling
---                                      is applied (default 8)
---   tickscaler_factor            float Log multiplier — higher = more aggressive
---                                      scaling (default 1.4427, i.e. 1/ln(2))
---   tickscaler_max_skip          int   Hard cap on the skip value so bots never
---                                      become *completely* unresponsive (default 6)
---   tickscaler_exempt_combat     0/1   If 1, bots currently in combat (have an
---                                      attack target) are NOT throttled (default 1)
---   tickscaler_stagger           0/1   If 1, bots are staggered across ticks so
---                                      not all bots think on the same tick (default 1)
---   tickscaler_debug             0/1   Print scaling info periodically (default 0)
---
--- API:
---   TTTBots.TickScaler.GetSkipForBot(bot) -> number
---       Returns the current effective skip value for that bot (1 = no skip).
---
---   TTTBots.TickScaler.ShouldBotThink(bot) -> boolean
---       Returns true if this bot should process its behavior tree + components
---       on the current global tick.
---
---   TTTBots.TickScaler.GetEffectiveTickrate() -> number
---       Returns the effective ticks-per-second a "normal" (non-exempt) bot
---       experiences right now.  For display / debug only.
---
---   TTTBots.TickScaler.GetCurrentSkip() -> number
---       Returns the raw skip value derived from the current bot count.

TTTBots.TickScaler = TTTBots.TickScaler or {}

local TickScaler = TTTBots.TickScaler

---------------------------------------------------------------------------
-- Internal state
---------------------------------------------------------------------------
TickScaler._globalTick = 0          -- monotonically increasing counter
TickScaler._cachedSkip = 1          -- last computed skip value
TickScaler._cachedBotCount = 0      -- last observed bot count
TickScaler._lastRecalcTime = 0      -- CurTime() of last recalculation

---------------------------------------------------------------------------
-- Helper: read cvars (uses the standard TTTBots wrapper pattern)
---------------------------------------------------------------------------
local function cvarBool(name)
    local cv = GetConVar("ttt_bot_" .. name)
    return cv and cv:GetBool() or false
end

local function cvarInt(name)
    local cv = GetConVar("ttt_bot_" .. name)
    return cv and cv:GetInt() or 0
end

local function cvarFloat(name)
    local cv = GetConVar("ttt_bot_" .. name)
    return cv and cv:GetFloat() or 0
end

---------------------------------------------------------------------------
-- Core calculation
---------------------------------------------------------------------------

--- Recompute the skip value from the current bot population.
--- Called once per tick from the main loop (cheap).
function TickScaler.Recalculate()
    TickScaler._globalTick = TickScaler._globalTick + 1

    if not cvarBool("tickscaler_enabled") then
        TickScaler._cachedSkip = 1
        TickScaler._cachedBotCount = #TTTBots.Bots
        return
    end

    local botCount = #TTTBots.Bots
    TickScaler._cachedBotCount = botCount

    local threshold = math.max(1, cvarInt("tickscaler_threshold"))
    local factor    = math.max(0.01, cvarFloat("tickscaler_factor"))
    local maxSkip   = math.max(1, cvarInt("tickscaler_max_skip"))

    if botCount <= threshold then
        TickScaler._cachedSkip = 1
        return
    end

    -- Logarithmic scaling: skip = 1 + factor * ln(botCount / threshold)
    -- At threshold+1 this is barely above 1, and it grows slowly.
    local raw = 1 + factor * math.log(botCount / threshold)
    local skip = math.Clamp(math.floor(raw), 1, maxSkip)

    TickScaler._cachedSkip = skip
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Returns the skip value for a specific bot.
--- If the bot is in combat and `tickscaler_exempt_combat` is enabled,
--- returns 1 (no throttling).
---@param bot Player
---@return number skip  1 = every tick, 2 = every other tick, etc.
function TickScaler.GetSkipForBot(bot)
    if not cvarBool("tickscaler_enabled") then return 1 end

    local skip = TickScaler._cachedSkip

    -- Exempt bots that are actively fighting
    if skip > 1 and cvarBool("tickscaler_exempt_combat") then
        if bot.attackTarget and IsValid(bot.attackTarget) then
            return 1
        end
    end

    return skip
end

--- Should the given bot run its behavior tree + component Think calls this tick?
--- Uses staggering (if enabled) so that bots with skip=3 don't ALL skip the
--- same two ticks — they're spread across the cycle.
---@param bot Player
---@return boolean
function TickScaler.ShouldBotThink(bot)
    local skip = TickScaler.GetSkipForBot(bot)
    if skip <= 1 then return true end

    if cvarBool("tickscaler_stagger") then
        -- Use the bot's UserID to give each bot a unique phase offset
        local phase = (bot:UserID() or 0) % skip
        return (TickScaler._globalTick % skip) == phase
    else
        return (TickScaler._globalTick % skip) == 0
    end
end

--- Returns the effective ticks-per-second for a throttled bot.
---@return number
function TickScaler.GetEffectiveTickrate()
    local skip = TickScaler._cachedSkip
    return TTTBots.Tickrate / skip
end

--- Returns the raw skip value (not per-bot; doesn't consider combat exemption).
---@return number
function TickScaler.GetCurrentSkip()
    return TickScaler._cachedSkip
end

--- Returns true when the feature is enabled.
---@return boolean
function TickScaler.IsEnabled()
    return cvarBool("tickscaler_enabled")
end

---------------------------------------------------------------------------
-- Debug logging (opt-in via cvar)
---------------------------------------------------------------------------
timer.Create("TTTBots.TickScaler.Debug", 10, 0, function()
    if not cvarBool("tickscaler_debug") then return end
    if not cvarBool("tickscaler_enabled") then return end

    local botCount  = TickScaler._cachedBotCount
    local skip      = TickScaler._cachedSkip
    local threshold = cvarInt("tickscaler_threshold")
    local factor    = cvarFloat("tickscaler_factor")
    local maxSkip   = cvarInt("tickscaler_max_skip")
    local effRate   = TickScaler.GetEffectiveTickrate()

    print(string.format(
        "[BOTDBG:TICKSCALER] Bots: %d | Threshold: %d | Factor: %.2f | MaxSkip: %d | Skip: %d | Effective Hz: %.1f",
        botCount, threshold, factor, maxSkip, skip, effRate
    ))

    -- Per-bot breakdown
    for _, bot in ipairs(TTTBots.Bots) do
        if not IsValid(bot) then continue end
        local bSkip = TickScaler.GetSkipForBot(bot)
        local inCombat = (bot.attackTarget and IsValid(bot.attackTarget)) and "COMBAT" or "idle"
        print(string.format(
            "[BOTDBG:TICKSCALER]   %-24s skip=%d  (%s)  effectiveHz=%.1f",
            bot:Nick(), bSkip, inCombat, TTTBots.Tickrate / bSkip
        ))
    end
end)

---------------------------------------------------------------------------
-- Automatic Tick Rate Adjuster (performance-based)
---------------------------------------------------------------------------
--- Monitors how long each bot tick takes and adjusts TTTBots.Tickrate
--- (and recreates the master timer) automatically based on a hard
--- millisecond threshold.
---
--- CVars (all prefixed with `ttt_bot_`):
---   tickrate                  int   The base/current tick rate (1-20)
---   tickrate_auto             0/1   Master toggle for auto-adjustment (default 0)
---   tickrate_auto_threshold_ms int  Max avg tick duration in ms before lowering rate (default 30)
---   tickrate_auto_min         int   Floor tick rate the adjuster won't go below (default 2)
---   tickrate_auto_recover     float Seconds of good performance before raising rate (default 5)
---   tickrate_auto_debug       0/1   Print diagnostics every 5s (default 0)

TTTBots.TickRateAuto = TTTBots.TickRateAuto or {}

local Auto = TTTBots.TickRateAuto

Auto._samples        = {}       -- ring buffer of recent tick durations (seconds)
Auto._sampleIdx      = 0
Auto._maxSamples     = 30       -- ~6 seconds at 5 Hz
Auto._goodSince      = 0        -- CurTime when we first started seeing "good" performance
Auto._lastAdjustTime = 0        -- CurTime of the last adjustment
Auto._lastTickrate   = 0        -- tracks the cvar so we notice manual changes
Auto._escalationLevel = 0       -- 0 = none, 1-3 = progressively heavier throttling
Auto._escalationTime  = 0       -- CurTime of last escalation change

--- Call at the START of each master tick to record the timestamp.
function Auto.BeginSample()
    Auto._tickStart = SysTime()
end

--- Call at the END of each master tick to record the elapsed time.
function Auto.EndSample()
    if not Auto._tickStart then return end
    local elapsed = SysTime() - Auto._tickStart
    Auto._sampleIdx = (Auto._sampleIdx % Auto._maxSamples) + 1
    Auto._samples[Auto._sampleIdx] = elapsed
end

--- Returns the average tick duration from recent samples (seconds).
---@return number avgSeconds
---@return number count
function Auto.GetAverageDuration()
    local sum, count = 0, 0
    for _, v in ipairs(Auto._samples) do
        sum = sum + v
        count = count + 1
    end
    if count == 0 then return 0, 0 end
    return sum / count, count
end

--- Returns the current emergency escalation level (0 = none, 1-3 = progressively heavier).
---@return number level
function Auto.GetEscalationLevel()
    if not cvarBool("tickrate_auto") then return 0 end
    if not cvarBool("tickrate_auto_escalate") then return 0 end
    return Auto._escalationLevel
end

--- Returns the component ThinkRate multiplier for the current escalation level.
--- Level 0 = 1 (normal), Level 1 = 2, Level 2 = 3, Level 3 = 4.
---@return number multiplier
function Auto.GetThinkRateMultiplier()
    local level = Auto.GetEscalationLevel()
    return 1 + level
end

--- Returns whether a non-combat bot should skip its behavior tree this tick
--- based on the current escalation level and a stagger offset.
--- Level 0-1: never skip trees.  Level 2: skip every other tick.  Level 3: skip 3 of 4 ticks.
---@param bot Player
---@return boolean shouldSkip
function Auto.ShouldSkipBehaviorTree(bot)
    local level = Auto.GetEscalationLevel()
    if level < 2 then return false end

    -- Don't skip bots in active combat
    if bot.attackTarget and IsValid(bot.attackTarget) then
        return false
    end

    local phase = (bot:UserID() or 0)
    if level == 2 then
        -- Skip every other tick (50% reduction)
        return (TickScaler._globalTick + phase) % 2 ~= 0
    else
        -- Level 3+: skip 3 of 4 ticks (75% reduction)
        return (TickScaler._globalTick + phase) % 4 ~= 0
    end
end

--- The core auto-adjust logic.  Called once per second from a timer.
--- Uses a hard millisecond threshold: if the average tick duration exceeds
--- the threshold, lower the rate immediately.  If it stays below the
--- threshold for the recovery period, raise the rate back toward the cvar.
--- When the tick rate is already at minimum and still over threshold,
--- escalates through additional throttling levels.
function Auto.Think()
    if not cvarBool("tickrate_auto") then return end

    local thresholdMs = math.Clamp(cvarInt("tickrate_auto_threshold_ms"), 5, 200)
    local thresholdSec = thresholdMs / 1000
    local minRate     = math.max(1, cvarInt("tickrate_auto_min"))
    local recoverSec  = math.max(1, cvarFloat("tickrate_auto_recover"))

    local currentRate = TTTBots.Tickrate
    local avgDur, n   = Auto.GetAverageDuration()

    if n < 5 then return end  -- need enough samples before making decisions

    local avgMs = avgDur * 1000
    local now   = CurTime()

    if avgDur > thresholdSec then
        -- Over threshold → lower the tick rate immediately (but not below min)
        local newRate = math.max(minRate, currentRate - 1)
        if newRate ~= currentRate then
            Auto._applyRate(newRate)
            Auto._goodSince = 0
            Auto._lastAdjustTime = now
            -- Reset escalation when we still have tickrate headroom
            if Auto._escalationLevel > 0 then
                Auto._escalationLevel = 0
                Auto._escalationTime = now
                if cvarBool("tickrate_auto_debug") then
                    print("[BOTDBG:TICKRATE] Escalation reset to 0 (tickrate lowered)")
                end
            end
            if cvarBool("tickrate_auto_debug") then
                print(string.format(
                    "[BOTDBG:TICKRATE] OVER THRESHOLD (avg %.1fms > %dms) — lowered tickrate %d → %d",
                    avgMs, thresholdMs, currentRate, newRate
                ))
            end
        else
            -- Already at minimum tickrate and STILL over threshold → escalate
            if cvarBool("tickrate_auto_escalate") then
                local maxLevel = math.Clamp(cvarInt("tickrate_auto_escalate_max"), 1, 3)
                if Auto._escalationLevel < maxLevel and (now - Auto._escalationTime) >= recoverSec then
                    Auto._escalationLevel = Auto._escalationLevel + 1
                    Auto._escalationTime = now
                    Auto._goodSince = 0
                    -- Clear samples so we measure the new escalation level cleanly
                    Auto._samples = {}
                    Auto._sampleIdx = 0
                    if cvarBool("tickrate_auto_debug") then
                        local descs = {
                            [1] = "component ThinkRates 2x",
                            [2] = "ThinkRates 3x + behavior tree skip 50%",
                            [3] = "ThinkRates 4x + behavior tree skip 75%",
                        }
                        print(string.format(
                            "[BOTDBG:TICKRATE] ESCALATING to level %d (%s) — tickrate already at min %d, still avg %.1fms > %dms",
                            Auto._escalationLevel, descs[Auto._escalationLevel] or "?",
                            currentRate, avgMs, thresholdMs
                        ))
                    end
                end
            end
        end
    else
        -- Under threshold → track how long we've been consistently good
        if Auto._goodSince == 0 then
            Auto._goodSince = now
        end
        local goodDuration = now - Auto._goodSince
        if goodDuration >= recoverSec and (now - Auto._lastAdjustTime) >= recoverSec then
            -- First de-escalate before raising tick rate
            if Auto._escalationLevel > 0 then
                Auto._escalationLevel = Auto._escalationLevel - 1
                Auto._escalationTime = now
                Auto._goodSince = 0
                -- Clear samples so we measure the de-escalation cleanly
                Auto._samples = {}
                Auto._sampleIdx = 0
                if cvarBool("tickrate_auto_debug") then
                    print(string.format(
                        "[BOTDBG:TICKRATE] DE-ESCALATING to level %d (avg %.1fms < %dms for %.1fs)",
                        Auto._escalationLevel, avgMs, thresholdMs, goodDuration
                    ))
                end
            else
                -- No escalation active → try bumping rate back up
                local cvarRate = math.Clamp(cvarInt("tickrate"), 1, 20)
                if currentRate < cvarRate then
                    local newRate = math.min(cvarRate, currentRate + 1)
                    Auto._applyRate(newRate)
                    Auto._goodSince = 0
                    Auto._lastAdjustTime = now
                    if cvarBool("tickrate_auto_debug") then
                        print(string.format(
                            "[BOTDBG:TICKRATE] RECOVERING (avg %.1fms < %dms for %.1fs) — raised tickrate %d → %d (target %d)",
                            avgMs, thresholdMs, goodDuration, currentRate, newRate, cvarRate
                        ))
                    end
                end
            end
        end
    end
end

--- Internal: apply a new tick rate and recreate the master timer.
---@param newRate number
function Auto._applyRate(newRate)
    newRate = math.Clamp(math.floor(newRate), 1, 20)
    if newRate == TTTBots.Tickrate then return end

    TTTBots.Tickrate = newRate
    -- Recreate the master timer with the new interval
    if timer.Exists("TTTBots_Tick") then
        timer.Adjust("TTTBots_Tick", 1 / TTTBots.Tickrate, 0)
    end
    -- Also update the alive-players cache timer
    if timer.Exists("TTTBots.Lib.AlivePlayersInterval") then
        timer.Adjust("TTTBots.Lib.AlivePlayersInterval", 1 / TTTBots.Tickrate, 0)
    end

    -- Clear samples so we measure the new rate cleanly
    Auto._samples   = {}
    Auto._sampleIdx = 0
end

--- Debug printer (every 5 seconds).
timer.Create("TTTBots.TickRateAuto.Debug", 5, 0, function()
    if not cvarBool("tickrate_auto_debug") then return end

    local currentRate  = TTTBots.Tickrate
    local cvarRate     = math.Clamp(cvarInt("tickrate"), 1, 20)
    local avgDur, n    = Auto.GetAverageDuration()
    local thresholdMs  = math.Clamp(cvarInt("tickrate_auto_threshold_ms"), 5, 200)
    local autoOn       = cvarBool("tickrate_auto")
    local avgMs        = avgDur * 1000
    local status       = (avgMs > thresholdMs) and "OVER" or "OK"
    local escLevel     = Auto._escalationLevel
    local escDescs     = { [0] = "none", [1] = "ThinkRate 2x", [2] = "ThinkRate 3x + tree skip 50%", [3] = "ThinkRate 4x + tree skip 75%" }

    print(string.format(
        "[BOTDBG:TICKRATE] Auto: %s | CVar Rate: %d | Active Rate: %d | Avg Tick: %.1fms / %dms threshold [%s] | Escalation: %d (%s) | Samples: %d",
        autoOn and "ON" or "OFF", cvarRate, currentRate,
        avgMs, thresholdMs, status, escLevel, escDescs[escLevel] or "?", n
    ))
end)

--- Detect manual cvar changes (e.g. from the menu) and apply immediately
--- when auto-adjust is OFF.
timer.Create("TTTBots.TickRateAuto.CvarSync", 2, 0, function()
    local cvarRate = math.Clamp(cvarInt("tickrate"), 1, 20)
    if cvarRate ~= Auto._lastTickrate then
        Auto._lastTickrate = cvarRate
        -- If auto-adjust is off, apply the cvar directly
        if not cvarBool("tickrate_auto") then
            Auto._applyRate(cvarRate)
        end
    end
end)

--- Run the auto-adjuster once per second.
timer.Create("TTTBots.TickRateAuto.Think", 1, 0, function()
    Auto.Think()
end)
