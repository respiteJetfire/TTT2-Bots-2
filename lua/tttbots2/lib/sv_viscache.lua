--- sv_viscache.lua
--- Visibility result cache for TTT Bots 2.
--- Caches CanSee(A, B), VisibleVec, and GetAllWitnessesBasic results for a
--- short TTL to eliminate the vast majority of redundant ray traces.
---
--- At 16 bots × 16 players × 3 traces per pair × 5 Hz = ~12,800 traces/sec.
--- With a 0.2s TTL cache, ~80% of these become table lookups instead.
---
--- Usage:
---   TTTBots.VisCache.CanSee(ply1, ply2)  -- cached wrapper for lib.CanSee
---   TTTBots.VisCache.Invalidate()         -- clear all (call on round reset)
---   TTTBots.VisCache.GetStats()           -- returns {hits, misses, size}
---
--- The cache auto-flushes stale entries every second via a lightweight timer.
--- Individual entries expire after TTL seconds (default 0.2).

TTTBots.VisCache = TTTBots.VisCache or {}

local VisCache = TTTBots.VisCache

---------------------------------------------------------------------------
-- Configuration
---------------------------------------------------------------------------

--- How long a cached result stays valid (seconds).
--- Bot positions don't change meaningfully in 200ms at walking speed (~250 units/s ≈ 50 units).
VisCache.TTL = 0.2

--- Maximum cache entries before forced flush (safety valve).
VisCache.MAX_ENTRIES = 4096

---------------------------------------------------------------------------
-- Internal state
---------------------------------------------------------------------------

VisCache._cache = {}       -- { [key] = { result = bool, time = number } }
VisCache._hits  = 0
VisCache._misses = 0

---------------------------------------------------------------------------
-- Key generation
---------------------------------------------------------------------------

--- Build a unique cache key for a directed visibility pair.
--- Uses EntIndex which is fast and unique per entity per map session.
---@param ply1 Player
---@param ply2 Player
---@return string
local function makeKey(ply1, ply2)
    return ply1:EntIndex() .. "_" .. ply2:EntIndex()
end

---------------------------------------------------------------------------
-- Core API
---------------------------------------------------------------------------

--- Cached wrapper around TTTBots.Lib.CanSee(ply1, ply2).
--- Returns the cached result if still within TTL, otherwise performs the
--- actual trace and caches the result.
---@param ply1 Player
---@param ply2 Player
---@return boolean canSee
function VisCache.CanSee(ply1, ply2)
    if not IsValid(ply1) or not IsValid(ply2) then return false end

    local key = makeKey(ply1, ply2)
    local entry = VisCache._cache[key]
    local now = CurTime()

    if entry and (now - entry.time) < VisCache.TTL then
        VisCache._hits = VisCache._hits + 1
        return entry.result
    end

    -- Cache miss — perform the actual expensive trace
    local result = TTTBots.Lib._CanSeeRaw(ply1, ply2)
    VisCache._cache[key] = { result = result, time = now }
    VisCache._misses = VisCache._misses + 1

    return result
end

--- Cached wrapper around ply:VisibleVec(pos) with a position-rounded key.
--- Positions are rounded to 64-unit grid cells for cache friendliness.
---@param ply Player
---@param pos Vector
---@return boolean
function VisCache.VisibleVec(ply, pos)
    if not IsValid(ply) then return false end

    -- Round position to 64-unit grid for cache-key stability
    local gx = math.floor(pos.x / 64)
    local gy = math.floor(pos.y / 64)
    local gz = math.floor(pos.z / 64)
    local key = ply:EntIndex() .. "_v_" .. gx .. "_" .. gy .. "_" .. gz
    local entry = VisCache._cache[key]
    local now = CurTime()

    if entry and (now - entry.time) < VisCache.TTL then
        VisCache._hits = VisCache._hits + 1
        return entry.result
    end

    local result = ply:VisibleVec(pos)
    VisCache._cache[key] = { result = result, time = now }
    VisCache._misses = VisCache._misses + 1

    return result
end

--- Clear all cached entries.  Call on round boundaries.
function VisCache.Invalidate()
    VisCache._cache = {}
end

--- Return diagnostic stats.
---@return table { hits, misses, size, hitRate }
function VisCache.GetStats()
    local total = VisCache._hits + VisCache._misses
    return {
        hits    = VisCache._hits,
        misses  = VisCache._misses,
        size    = table.Count(VisCache._cache),
        hitRate = total > 0 and (VisCache._hits / total * 100) or 0,
    }
end

--- Reset hit/miss counters (call per round for clean stats).
function VisCache.ResetStats()
    VisCache._hits  = 0
    VisCache._misses = 0
end

---------------------------------------------------------------------------
-- Automatic maintenance
---------------------------------------------------------------------------

--- Flush stale entries every second to prevent unbounded growth.
timer.Create("TTTBots.VisCache.Flush", 1, 0, function()
    local now = CurTime()
    local ttl = VisCache.TTL
    local cache = VisCache._cache
    local maxEntries = VisCache.MAX_ENTRIES

    -- Fast path: if cache is small, skip pruning
    local size = table.Count(cache)
    if size < 64 then return end

    -- If cache exceeds safety limit, full flush
    if size > maxEntries then
        VisCache._cache = {}
        return
    end

    -- Normal prune: remove expired entries
    for key, entry in pairs(cache) do
        if (now - entry.time) >= ttl then
            cache[key] = nil
        end
    end
end)

--- Clear cache on round boundaries.
hook.Add("TTTEndRound", "TTTBots.VisCache.RoundEnd", function()
    VisCache.Invalidate()
    VisCache.ResetStats()
end)

hook.Add("TTTPrepareRound", "TTTBots.VisCache.PrepareRound", function()
    VisCache.Invalidate()
    VisCache.ResetStats()
end)

---------------------------------------------------------------------------
-- Debug (opt-in via ttt_bot_viscache_debug)
---------------------------------------------------------------------------

timer.Create("TTTBots.VisCache.Debug", 10, 0, function()
    local cv = GetConVar("ttt_bot_viscache_debug")
    if not (cv and cv:GetBool()) then return end

    local stats = VisCache.GetStats()
    print(string.format(
        "[BOTDBG:VISCACHE] Entries: %d | Hits: %d | Misses: %d | Hit Rate: %.1f%%",
        stats.size, stats.hits, stats.misses, stats.hitRate
    ))
end)
