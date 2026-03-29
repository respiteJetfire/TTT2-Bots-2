--- sv_adaptive_difficulty.lua
--- Dynamic traitor difficulty scaling based on rolling win-rate.
---
--- Tracks the last N (default 5) round outcomes for the traitor/coordinator
--- team.  When the rolling win-rate falls below a lower threshold (default
--- 40%), the system progressively BOOSTS traitor accuracy and bonus credits.
--- When it exceeds an upper threshold (default 50%), the boosts are
--- progressively REDUCED back toward baseline.
---
--- The boost is expressed as a single float "AdaptiveBoost" in [0, 1]:
---   0 = no boost (traitors winning enough)
---   1 = maximum boost (traitors on a long losing streak)
---
--- Consumers read TTTBots.AdaptiveDifficulty.GetBoost() and apply it:
---   • Accuracy:  inaccuracy multiplied by (1 - boost * MAX_ACCURACY_REDUCTION)
---   • Credits:   bonus credits = floor(boost * MAX_BONUS_CREDITS)
---
--- The system is server-authoritative and persists across map changes via
--- a simple JSON file.

local lib = TTTBots.Lib

TTTBots.AdaptiveDifficulty = TTTBots.AdaptiveDifficulty or {}
local AD = TTTBots.AdaptiveDifficulty

-- =========================================================================
-- Configuration constants
-- =========================================================================

--- Number of rounds in the rolling window.
AD.WINDOW_SIZE = 5

--- When rolling win-rate is BELOW this, the boost starts increasing.
AD.LOWER_THRESHOLD = 0.40

--- When rolling win-rate is ABOVE this, the boost starts decreasing.
AD.UPPER_THRESHOLD = 0.50

--- Maximum accuracy improvement factor (0.35 = up to 35% less inaccuracy at full boost).
AD.MAX_ACCURACY_REDUCTION = 0.35

--- Maximum bonus credits awarded at full boost.
AD.MAX_BONUS_CREDITS = 2

--- How much the boost changes per round end.
--- When losing and below lower threshold: boost += BOOST_INCREMENT
--- When winning and above upper threshold: boost -= BOOST_DECREMENT
AD.BOOST_INCREMENT = 0.20
AD.BOOST_DECREMENT = 0.15

--- Persistence file path (inside the data/ folder)
AD.SAVE_FILE = "tttbots2/adaptive_difficulty.json"

-- =========================================================================
-- State
-- =========================================================================

--- Rolling window of round outcomes: true = traitor win, false = traitor loss.
--- Most recent outcome is at index #History.
AD.History = AD.History or {}

--- Current adaptive boost level [0, 1].
AD.Boost = AD.Boost or 0

-- =========================================================================
-- Persistence
-- =========================================================================

function AD.Save()
    local data = {
        History = AD.History,
        Boost = AD.Boost,
    }
    file.CreateDir("tttbots2")
    file.Write(AD.SAVE_FILE, util.TableToJSON(data, true))
end

function AD.Load()
    if not file.Exists(AD.SAVE_FILE, "DATA") then return end
    local raw = file.Read(AD.SAVE_FILE, "DATA")
    if not raw or raw == "" then return end

    local data = util.JSONToKeyValues(raw)
    if not data then return end

    if data.History and istable(data.History) then
        -- JSONToKeyValues may convert the array to string-keyed table; normalize.
        local history = {}
        for _, v in pairs(data.History) do
            table.insert(history, tobool(v))
        end
        AD.History = history
    end

    if data.Boost then
        AD.Boost = math.Clamp(tonumber(data.Boost) or 0, 0, 1)
    end
end

-- =========================================================================
-- Core logic
-- =========================================================================

--- Calculate the rolling win-rate from the history window.
---@return number winRate 0.0–1.0
function AD.GetWinRate()
    local n = #AD.History
    if n == 0 then return 0.5 end -- no data: assume neutral

    local wins = 0
    for _, v in ipairs(AD.History) do
        if v then wins = wins + 1 end
    end
    return wins / n
end

--- Returns the current adaptive boost value [0, 1].
---@return number boost
function AD.GetBoost()
    if not lib.GetConVarBool("adaptive_difficulty") then return 0 end
    return AD.Boost
end

--- Returns the accuracy multiplier that should be applied to inaccuracy.
--- A value < 1 means traitors are MORE accurate than baseline.
---@return number mult  (e.g., 0.75 means 25% less inaccuracy)
function AD.GetAccuracyMult()
    local boost = AD.GetBoost()
    return 1 - (boost * AD.MAX_ACCURACY_REDUCTION)
end

--- Returns the number of bonus credits to award traitor bots this round.
---@return number bonusCredits  integer 0–MAX_BONUS_CREDITS
function AD.GetBonusCredits()
    local boost = AD.GetBoost()
    return math.floor(boost * AD.MAX_BONUS_CREDITS)
end

--- Record a round outcome and update the boost.
---@param traitorWin boolean  did the traitor/coordinator team win?
function AD.RecordRound(traitorWin)
    table.insert(AD.History, traitorWin)

    -- Trim to window size
    while #AD.History > AD.WINDOW_SIZE do
        table.remove(AD.History, 1)
    end

    local winRate = AD.GetWinRate()

    if traitorWin then
        -- Traitors won this round
        if winRate > AD.UPPER_THRESHOLD then
            -- Winning too much: pull boost back down
            AD.Boost = math.max(0, AD.Boost - AD.BOOST_DECREMENT)
        end
        -- If between thresholds, hold steady (don't change boost on a win)
    else
        -- Traitors lost this round
        if winRate < AD.LOWER_THRESHOLD then
            -- Losing too much: push boost up
            AD.Boost = math.min(1, AD.Boost + AD.BOOST_INCREMENT)
        end
        -- If between thresholds, hold steady (don't change boost on a loss)
    end

    AD.Save()

    -- Debug output
    if lib.GetConVarBool("debug_misc") then
        print(string.format(
            "[TTTBots][AdaptiveDifficulty] Round result: %s | WinRate: %.0f%% (%d/%d) | Boost: %.2f | AccuracyMult: %.2f | BonusCredits: %d",
            traitorWin and "TRAITOR WIN" or "TRAITOR LOSS",
            winRate * 100,
            AD.GetWinsInWindow(),
            #AD.History,
            AD.Boost,
            AD.GetAccuracyMult(),
            AD.GetBonusCredits()
        ))
    end
end

--- Helper: count wins in current window (for debug output).
---@return number
function AD.GetWinsInWindow()
    local wins = 0
    for _, v in ipairs(AD.History) do
        if v then wins = wins + 1 end
    end
    return wins
end

--- Reset all adaptive difficulty state.
function AD.Reset()
    AD.History = {}
    AD.Boost = 0
    AD.Save()
end

-- =========================================================================
-- Hooks
-- =========================================================================

--- Detect round outcome and feed it into the adaptive system.
hook.Add("TTTEndRound", "TTTBots.AdaptiveDifficulty.OnRoundEnd", function(result)
    if not lib.GetConVarBool("adaptive_difficulty") then return end

    -- Determine if coordinators (traitors) won.
    -- TTT2 passes WIN_TRAITOR (2) or a team-name string.
    local traitorWin = false

    if result == WIN_TRAITOR then
        traitorWin = true
    elseif type(result) == "string" then
        local lower = string.lower(result)
        if lower == "traitor" or lower == "traitors" then
            traitorWin = true
        end
    end

    -- Short delay so other end-round hooks run first (same pattern as PlanLearning)
    local capturedWin = traitorWin
    timer.Simple(0.3, function()
        AD.RecordRound(capturedWin)
    end)
end)

--- Grant bonus credits to traitor bots at round start.
hook.Add("TTT2ModifyDefaultTraitorCredits", "TTTBots.AdaptiveDifficulty.BonusCredits", function(ply, credits)
    if not lib.GetConVarBool("adaptive_difficulty") then return end
    if not (IsValid(ply) and ply:IsBot()) then return end

    local bonus = AD.GetBonusCredits()
    if bonus <= 0 then return end

    return credits + bonus
end)

--- Load persisted state on initialization.
AD.Load()

--- Print status on load
timer.Simple(2, function()
    local winRate = AD.GetWinRate()
    local boost = AD.Boost
    print(string.format(
        "[TTT Bots 2] Adaptive Difficulty loaded: %d rounds tracked, %.0f%% win-rate, boost=%.2f, accuracy_mult=%.2f, bonus_credits=%d",
        #AD.History, winRate * 100, boost, AD.GetAccuracyMult(), AD.GetBonusCredits()
    ))
end)
