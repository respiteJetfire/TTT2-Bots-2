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
