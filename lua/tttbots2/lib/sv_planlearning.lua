---------------------------------------------------------------------------
-- Plan Learning System
--
-- Tracks the outcomes of traitor plans across rounds and persists the data
-- to disk so bots can learn from experience.  Plans that have historically
-- led to traitor victories are weighted more heavily in future selection,
-- while plans that consistently fail are penalised.
--
-- The system records context alongside each outcome (player count, traitor
-- count, whether the team was outnumbered) so that success rates can be
-- evaluated in similar conditions rather than blindly averaging.
--
-- Design principles:
--   1. Persistent: data survives server restarts via JSON on disk.
--   2. Contextual: success rates are bucketed by game-state context.
--   3. Decaying: old records gradually lose influence so the system
--      adapts to changing player behaviour and meta shifts.
--   4. Exploratory: even poorly-rated plans are still occasionally chosen
--      so the system doesn't get stuck in a local optimum.
---------------------------------------------------------------------------

TTTBots.PlanLearning = TTTBots.PlanLearning or {}
local PL = TTTBots.PlanLearning

--- Directory and filename inside garrysmod/data/
local DATA_DIR = "tttbots2"
local DATA_FILE = DATA_DIR .. "/plan_history.json"

---------------------------------------------------------------------------
-- In-memory state
---------------------------------------------------------------------------

--- The plan that was active when the round was running.
PL.ActivePlanName = nil
--- Snapshot of game-state context at the time the plan was selected.
PL.ActivePlanContext = nil
--- Timestamp when the plan was selected (to detect stale data).
PL.ActivePlanStartTime = 0

--- Loaded history table.  Structure:
--- {
---     Plans = {
---         ["PlanName"] = {
---             Wins   = number,  -- total traitor victories with this plan
---             Losses = number,  -- total traitor losses with this plan
---             --- Contextual buckets (keyed by a context hash string)
---             Contexts = {
---                 ["ctx_hash"] = { Wins = n, Losses = n, LastUsed = timestamp },
---             },
---         },
---     },
---     TotalRounds  = number,
---     LastDecayTime = number,  -- os.time() when decay was last applied
--- }
PL.History = nil

--- How many rounds of history to track before old data starts being pruned.
local MAX_ROUNDS_TRACKED = 500
--- Decay factor applied to old records periodically.  0.95 means 5% decay.
local DECAY_FACTOR = 0.95
--- How often (in real seconds via os.time) to apply decay.
local DECAY_INTERVAL = 3600 -- every hour of server uptime

---------------------------------------------------------------------------
-- Context hashing
--
-- We bucket plan outcomes by a simplified game-state "context" so that
-- a plan's success in a 4-player round doesn't wrongly boost its weight
-- in a 12-player round.
---------------------------------------------------------------------------

--- Build a context table from the current game state.
function PL.CaptureContext()
    local alivePlayers = #(TTTBots.Match.AlivePlayers or {})
    local aliveCoordinators = 0
    local aliveEnemies = 0

    if TTTBots.Match.AlivePlayers then
        for _, ply in ipairs(TTTBots.Match.AlivePlayers) do
            if TTTBots.Roles and TTTBots.Roles.GetRoleFor then
                local role = TTTBots.Roles.GetRoleFor(ply)
                if role and role.GetCanCoordinate and role:GetCanCoordinate() then
                    aliveCoordinators = aliveCoordinators + 1
                else
                    aliveEnemies = aliveEnemies + 1
                end
            end
        end
    end

    -- Bucket player counts into ranges for better generalisation
    local plyBucket = "large"
    if alivePlayers <= 4 then
        plyBucket = "small"
    elseif alivePlayers <= 9 then
        plyBucket = "medium"
    end

    local traitorBucket = "many"
    if aliveCoordinators <= 1 then
        traitorBucket = "solo"
    elseif aliveCoordinators <= 2 then
        traitorBucket = "few"
    end

    local outnumbered = aliveEnemies > 0 and (aliveCoordinators / aliveEnemies) < 0.5

    return {
        PlyBucket = plyBucket,
        TraitorBucket = traitorBucket,
        Outnumbered = outnumbered,
    }
end

--- Convert a context table into a short string key for bucketing.
function PL.ContextToKey(ctx)
    if not ctx then return "unknown" end
    return string.format("%s_%s_%s",
        ctx.PlyBucket or "?",
        ctx.TraitorBucket or "?",
        ctx.Outnumbered and "out" or "even")
end

---------------------------------------------------------------------------
-- Persistence — load / save
---------------------------------------------------------------------------

function PL.GetDefaultHistory()
    return {
        Plans = {},
        TotalRounds = 0,
        LastDecayTime = os.time(),
    }
end

function PL.Load()
    file.CreateDir(DATA_DIR)
    local raw = file.Read(DATA_FILE, "DATA")
    if raw and raw ~= "" then
        local ok, tbl = pcall(util.JSONToTable, raw)
        if ok and tbl then
            PL.History = tbl
            -- Ensure structural integrity after load
            PL.History.Plans = PL.History.Plans or {}
            PL.History.TotalRounds = PL.History.TotalRounds or 0
            PL.History.LastDecayTime = PL.History.LastDecayTime or os.time()
            return
        end
    end
    PL.History = PL.GetDefaultHistory()
end

function PL.Save()
    if not PL.History then return end
    file.CreateDir(DATA_DIR)
    local json = util.TableToJSON(PL.History, true) -- pretty-print for debuggability
    if json then
        file.Write(DATA_FILE, json)
    end
end

--- Ensure history is loaded (call early during init).
function PL.EnsureLoaded()
    if not PL.History then
        PL.Load()
    end
end

---------------------------------------------------------------------------
-- Recording outcomes
---------------------------------------------------------------------------

--- Get or create the history entry for a plan.
function PL.GetPlanEntry(planName)
    PL.EnsureLoaded()
    if not PL.History.Plans[planName] then
        PL.History.Plans[planName] = {
            Wins = 0,
            Losses = 0,
            Contexts = {},
        }
    end
    return PL.History.Plans[planName]
end

--- Record that the active plan resulted in a traitor win or loss.
---@param won boolean true if traitors won
function PL.RecordOutcome(won)
    PL.EnsureLoaded()
    local planName = PL.ActivePlanName
    if not planName then return end

    local entry = PL.GetPlanEntry(planName)
    if won then
        entry.Wins = entry.Wins + 1
    else
        entry.Losses = entry.Losses + 1
    end

    -- Record in context bucket
    local ctxKey = PL.ContextToKey(PL.ActivePlanContext)
    if not entry.Contexts[ctxKey] then
        entry.Contexts[ctxKey] = { Wins = 0, Losses = 0, LastUsed = os.time() }
    end
    local ctxEntry = entry.Contexts[ctxKey]
    if won then
        ctxEntry.Wins = ctxEntry.Wins + 1
    else
        ctxEntry.Losses = ctxEntry.Losses + 1
    end
    ctxEntry.LastUsed = os.time()

    PL.History.TotalRounds = PL.History.TotalRounds + 1

    -- Apply periodic decay
    PL.MaybeDecay()

    -- Prune ancient context buckets
    PL.PruneOldContexts(entry)

    PL.Save()

    -- Clear active plan tracking
    PL.ActivePlanName = nil
    PL.ActivePlanContext = nil
end

---------------------------------------------------------------------------
-- Decay and pruning
---------------------------------------------------------------------------

--- Apply multiplicative decay to all stored win/loss counts so that
--- ancient data gradually fades and the system adapts to new conditions.
function PL.MaybeDecay()
    local now = os.time()
    local lastDecay = PL.History.LastDecayTime or 0
    if (now - lastDecay) < DECAY_INTERVAL then return end

    PL.History.LastDecayTime = now
    for name, entry in pairs(PL.History.Plans) do
        entry.Wins = entry.Wins * DECAY_FACTOR
        entry.Losses = entry.Losses * DECAY_FACTOR

        -- Floor very small values to prevent indefinite float accumulation
        if entry.Wins < 0.1 then entry.Wins = 0 end
        if entry.Losses < 0.1 then entry.Losses = 0 end

        for ctxKey, ctx in pairs(entry.Contexts) do
            ctx.Wins = ctx.Wins * DECAY_FACTOR
            ctx.Losses = ctx.Losses * DECAY_FACTOR
            if ctx.Wins < 0.1 then ctx.Wins = 0 end
            if ctx.Losses < 0.1 then ctx.Losses = 0 end
        end
    end
end

--- Remove context buckets that haven't been used in a very long time.
function PL.PruneOldContexts(entry)
    local now = os.time()
    local MAX_AGE = 604800 -- 7 days in seconds
    for ctxKey, ctx in pairs(entry.Contexts) do
        if (now - (ctx.LastUsed or 0)) > MAX_AGE then
            entry.Contexts[ctxKey] = nil
        end
        -- Also prune empty buckets
        if ctx.Wins == 0 and ctx.Losses == 0 then
            entry.Contexts[ctxKey] = nil
        end
    end
end

---------------------------------------------------------------------------
-- Scoring — used by the plan selection system
---------------------------------------------------------------------------

--- Calculate a learning-based weight modifier for a plan in the current context.
--- Returns a bonus (positive) or penalty (negative) to be added to the plan's
--- selection weight.
---
--- The scoring works in two layers:
---   1. Context-specific: if we have data for this plan in a matching context,
---      use that (most relevant).
---   2. Global fallback: use the plan's overall win rate across all contexts.
---
--- Plans with very few data points get a reduced modifier (low confidence).
--- Plans with NO data get a small exploration bonus to encourage trying them.
---
---@param planName string
---@return number modifier — added to the plan's selection weight
function PL.GetLearningModifier(planName)
    PL.EnsureLoaded()
    if not TTTBots.Lib.GetConVarBool("plan_learning") then return 0 end

    local entry = PL.History.Plans[planName]

    -- No data at all → small exploration bonus to try new/untested plans
    if not entry then
        return 5
    end

    local modifier = 0

    -- 1. Context-specific scoring (weighted more heavily)
    local ctx = PL.CaptureContext()
    local ctxKey = PL.ContextToKey(ctx)
    local ctxEntry = entry.Contexts[ctxKey]

    if ctxEntry then
        local ctxTotal = ctxEntry.Wins + ctxEntry.Losses
        if ctxTotal >= 2 then -- need at least 2 data points for context
            local ctxWinRate = ctxEntry.Wins / ctxTotal
            -- Scale: 50% win rate = neutral (0), 100% = +30, 0% = -30
            -- Confidence factor: scales up with more data, caps at 1.0
            local confidence = math.min(ctxTotal / 10, 1.0)
            modifier = modifier + (ctxWinRate - 0.5) * 60 * confidence
        end
    end

    -- 2. Global scoring (weighted less heavily than context)
    local globalTotal = entry.Wins + entry.Losses
    if globalTotal >= 3 then -- need at least 3 data points globally
        local globalWinRate = entry.Wins / globalTotal
        local globalConfidence = math.min(globalTotal / 20, 1.0)
        -- Smaller influence than context-specific data
        modifier = modifier + (globalWinRate - 0.5) * 30 * globalConfidence
    elseif globalTotal == 0 then
        -- Never been tried → exploration bonus
        modifier = modifier + 5
    end

    -- Clamp the total modifier to prevent any single plan from becoming
    -- overwhelmingly dominant or completely excluded.
    modifier = math.Clamp(modifier, -25, 35)

    return modifier
end

---------------------------------------------------------------------------
-- Integration — tracking the active plan and round outcomes
---------------------------------------------------------------------------

--- Called when a plan is selected (from Plans.Tick or re-evaluation).
--- Records which plan is active and the context in which it was chosen.
function PL.OnPlanSelected(planName)
    if not planName then return end
    if not TTTBots.Lib.GetConVarBool("plan_learning") then return end
    PL.ActivePlanName = planName
    PL.ActivePlanContext = PL.CaptureContext()
    PL.ActivePlanStartTime = CurTime()
end

--- Called at round end.  Determines if the coordinators won or lost.
---@param result any the TTTEndRound result value
function PL.OnRoundEnd(result)
    if not TTTBots.Lib.GetConVarBool("plan_learning") then return end
    if not PL.ActivePlanName then return end

    -- Determine if the coordinating team won.
    -- WIN_TRAITOR is the standard GMod/TTT2 constant for a traitor victory.
    -- Some TTT2 versions may pass a team identifier string instead.
    local coordinatorsWon = false

    if result == WIN_TRAITOR then
        coordinatorsWon = true
    elseif type(result) == "string" then
        local lower = string.lower(result)
        if lower == "traitor" or lower == "traitors" then
            coordinatorsWon = true
        end
    end

    -- Also check: if we had no plan running for more than a few seconds,
    -- don't attribute the outcome to a plan that barely existed.
    local planDuration = CurTime() - (PL.ActivePlanStartTime or 0)
    if planDuration < 10 then
        PL.ActivePlanName = nil
        PL.ActivePlanContext = nil
        return
    end

    PL.RecordOutcome(coordinatorsWon)
end

---------------------------------------------------------------------------
-- Hooks
---------------------------------------------------------------------------

hook.Add("TTTEndRound", "TTTBots.PlanLearning.OnRoundEnd", function(result)
    -- Capture all needed state NOW before other hooks clear it.
    -- Process with a short delay so other TTTEndRound hooks run first,
    -- but use the captured values rather than live state.
    local planName = PL.ActivePlanName
    local planContext = PL.ActivePlanContext
    local planStartTime = PL.ActivePlanStartTime
    timer.Simple(0.5, function()
        -- Temporarily restore the captured state for OnRoundEnd processing
        PL.ActivePlanName = planName
        PL.ActivePlanContext = planContext
        PL.ActivePlanStartTime = planStartTime
        PL.OnRoundEnd(result)
    end)
end)

--- Reset active tracking at round start (belt-and-suspenders cleanup).
hook.Add("TTTBeginRound", "TTTBots.PlanLearning.OnRoundStart", function()
    PL.ActivePlanName = nil
    PL.ActivePlanContext = nil
    PL.ActivePlanStartTime = 0
end)

hook.Add("TTTPrepareRound", "TTTBots.PlanLearning.OnPrepareRound", function()
    PL.ActivePlanName = nil
    PL.ActivePlanContext = nil
    PL.ActivePlanStartTime = 0
end)

---------------------------------------------------------------------------
-- Console command for debugging / admin use
---------------------------------------------------------------------------

concommand.Add("ttt_bot_plan_stats", function(ply, cmd, args)
    PL.EnsureLoaded()
    local history = PL.History
    if not history then
        print("[PlanLearning] No history data loaded.")
        return
    end

    print(string.format("[PlanLearning] Total rounds tracked: %d", history.TotalRounds or 0))
    print(string.format("[PlanLearning] Last decay: %s", os.date("%c", history.LastDecayTime or 0)))
    print("-----------------------------------------------------------")

    -- Sort plans by win rate for readability
    local sorted = {}
    for name, entry in pairs(history.Plans) do
        local total = entry.Wins + entry.Losses
        local winRate = total > 0 and (entry.Wins / total) or 0
        table.insert(sorted, { Name = name, Wins = entry.Wins, Losses = entry.Losses, Total = total, WinRate = winRate })
    end
    table.sort(sorted, function(a, b) return a.WinRate > b.WinRate end)

    for _, info in ipairs(sorted) do
        print(string.format("  %-45s  W:%-6.1f  L:%-6.1f  Total:%-4.0f  WinRate: %5.1f%%",
            info.Name, info.Wins, info.Losses, info.Total, info.WinRate * 100))

        -- Print context breakdown
        local entry = history.Plans[info.Name]
        if entry.Contexts then
            for ctxKey, ctx in pairs(entry.Contexts) do
                local ctxTotal = ctx.Wins + ctx.Losses
                local ctxWinRate = ctxTotal > 0 and (ctx.Wins / ctxTotal) or 0
                print(string.format("    [%s] W:%.1f L:%.1f WR:%.0f%%",
                    ctxKey, ctx.Wins, ctx.Losses, ctxWinRate * 100))
            end
        end
    end

    print("-----------------------------------------------------------")
    -- Show current active plan
    if PL.ActivePlanName then
        local ctxKey = PL.ContextToKey(PL.ActivePlanContext)
        print(string.format("[PlanLearning] Active plan: %s (context: %s)", PL.ActivePlanName, ctxKey))
    else
        print("[PlanLearning] No active plan (round not started or learning disabled).")
    end
end, nil, "Print traitor plan learning statistics and history.")

concommand.Add("ttt_bot_plan_reset", function(ply, cmd, args)
    PL.History = PL.GetDefaultHistory()
    PL.Save()
    print("[PlanLearning] Plan history has been reset.")
end, nil, "Reset all traitor plan learning history data.")

---------------------------------------------------------------------------
-- Initial load
---------------------------------------------------------------------------
PL.EnsureLoaded()
