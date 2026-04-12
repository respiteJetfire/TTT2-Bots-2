-- sv_providers.lua
-- Central provider adapter registry for TTTBots text and voice dispatch.
-- Must be included before the individual provider files.

TTTBots.Providers = TTTBots.Providers or {}

local lib = TTTBots.Lib

-- ---------------------------------------------------------------------------
-- Rate Limiter & Cost Tracker
-- ---------------------------------------------------------------------------

TTTBots.Providers.RateLimiter = TTTBots.Providers.RateLimiter or {
    --- Sliding window: timestamps of requests in the current minute
    minuteTimestamps     = {},
    --- Per-round request counter (reset on TTTBeginRound)
    currentRoundCount    = 0,
    --- Lifetime token counter (resets on map change)
    totalTokensUsed      = 0,
    --- Per-round token counter (reset on TTTBeginRound)
    roundTokensUsed      = 0,
    --- Estimated lifetime cost in USD
    totalCostEstimate    = 0,
    --- Per-round estimated cost in USD
    roundCostEstimate    = 0,
    --- Requests rejected this round
    roundRejected        = 0,
    --- Requests allowed this round
    roundAllowed         = 0,
    --- High-priority events that bypass soft limits
    HIGH_PRIORITY_EVENTS = {
        CallKOS            = true,
        accusation         = true,  -- opts.accusation flag from AccusePlayer
        DeclareSuspicious  = true,
        DeclareInnocent    = true,
    },
}

local RL = TTTBots.Providers.RateLimiter

--- Determine if a request has high priority based on opts table.
---@param opts table|nil  The options table passed to SendText
---@return boolean
function RL.IsHighPriority(opts)
    if not opts then return false end
    -- Explicit accusation flag from AccusePlayer behavior
    if opts.accusation then return true end
    -- Event-name-based priority
    if opts.eventName and RL.HIGH_PRIORITY_EVENTS[opts.eventName] then return true end
    return false
end

--- Prune timestamps older than 60 seconds from the sliding window.
local function pruneMinuteWindow()
    local cutoff = CurTime() - 60
    local ts = RL.minuteTimestamps
    local newTs = {}
    for i = 1, #ts do
        if ts[i] > cutoff then
            newTs[#newTs + 1] = ts[i]
        end
    end
    RL.minuteTimestamps = newTs
end

--- Check whether a request should be allowed through the rate limiter.
--- Returns true if allowed, false + reason string if rejected.
---@param opts table|nil  The opts table from SendText (used for priority check)
---@return boolean allowed
---@return string|nil reason
function RL.ShouldAllow(opts)
    local highPri = RL.IsHighPriority(opts)
    local debug   = lib.GetConVarBool("llm_ratelimit_debug")

    -- 1. Per-minute sliding window
    local maxRPM = lib.GetConVarInt("llm_max_rpm") or 30
    if maxRPM > 0 then
        pruneMinuteWindow()
        if #RL.minuteTimestamps >= maxRPM and not highPri then
            if debug then
                print("[BOTDBG:RATELIMIT] REJECTED per-minute limit ("
                    .. #RL.minuteTimestamps .. "/" .. maxRPM .. ")")
            end
            return false, "Rate limit: " .. maxRPM .. " requests/min exceeded"
        end
    end

    -- 2. Per-round budget
    local maxPerRound = lib.GetConVarInt("llm_max_per_round") or 200
    if maxPerRound > 0 then
        if RL.currentRoundCount >= maxPerRound and not highPri then
            if debug then
                print("[BOTDBG:RATELIMIT] REJECTED per-round limit ("
                    .. RL.currentRoundCount .. "/" .. maxPerRound .. ")")
            end
            return false, "Rate limit: " .. maxPerRound .. " requests/round exceeded"
        end
    end

    -- 3. Cost budget per round
    local budgetPerRound = lib.GetConVarFloat("llm_budget_per_round") or 1.0
    if budgetPerRound > 0 then
        if RL.roundCostEstimate >= budgetPerRound and not highPri then
            if debug then
                print(string.format("[BOTDBG:RATELIMIT] REJECTED cost budget ($%.4f / $%.2f)",
                    RL.roundCostEstimate, budgetPerRound))
            end
            return false, string.format("Cost budget: $%.2f/round exceeded", budgetPerRound)
        end
    end

    return true, nil
end

--- Record that a request was allowed and sent.
function RL.RecordRequest()
    RL.minuteTimestamps[#RL.minuteTimestamps + 1] = CurTime()
    RL.currentRoundCount = RL.currentRoundCount + 1
    RL.roundAllowed = RL.roundAllowed + 1
end

--- Record that a request was rejected.
function RL.RecordRejection()
    RL.roundRejected = RL.roundRejected + 1
end

--- Record token usage from an API response and update cost estimates.
---@param tokenCount number  Total tokens from the API response
function RL.RecordTokens(tokenCount)
    if not tokenCount or tokenCount <= 0 then return end

    RL.totalTokensUsed  = RL.totalTokensUsed  + tokenCount
    RL.roundTokensUsed  = RL.roundTokensUsed  + tokenCount

    local costPer1k = lib.GetConVarFloat("llm_cost_per_1k_tokens") or 0.01
    local cost = (tokenCount / 1000) * costPer1k
    RL.totalCostEstimate = RL.totalCostEstimate + cost
    RL.roundCostEstimate = RL.roundCostEstimate + cost

    local debug = lib.GetConVarBool("llm_ratelimit_debug")
    if debug then
        print(string.format("[BOTDBG:RATELIMIT] +%d tokens ($%.6f) | Round: %d tokens ($%.4f) | Total: %d tokens ($%.4f)",
            tokenCount, cost,
            RL.roundTokensUsed, RL.roundCostEstimate,
            RL.totalTokensUsed, RL.totalCostEstimate))
    end
end

--- Reset per-round counters. Called on TTTBeginRound.
function RL.ResetRound()
    RL.currentRoundCount = 0
    RL.roundTokensUsed   = 0
    RL.roundCostEstimate = 0
    RL.roundRejected     = 0
    RL.roundAllowed      = 0
    -- Keep the sliding window; it self-prunes
end

--- Get a snapshot of current stats for the admin dashboard.
---@return table
function RL.GetStats()
    pruneMinuteWindow()
    return {
        rpm              = #RL.minuteTimestamps,
        maxRPM           = lib.GetConVarInt("llm_max_rpm") or 30,
        roundRequests    = RL.currentRoundCount,
        maxPerRound      = lib.GetConVarInt("llm_max_per_round") or 200,
        roundTokens      = RL.roundTokensUsed,
        totalTokens      = RL.totalTokensUsed,
        roundCost        = RL.roundCostEstimate,
        totalCost        = RL.totalCostEstimate,
        budgetPerRound   = lib.GetConVarFloat("llm_budget_per_round") or 1.0,
        roundRejected    = RL.roundRejected,
        roundAllowed     = RL.roundAllowed,
    }
end

-- Reset per-round counters at the start of each round
hook.Add("TTTBeginRound", "TTTBots.RateLimiter.ResetRound", function()
    RL.ResetRound()
    local debug = lib.GetConVarBool("llm_ratelimit_debug")
    if debug then
        print("[BOTDBG:RATELIMIT] Round counters reset.")
    end
end)

-- ---------------------------------------------------------------------------
-- Admin dashboard networking (server → client)
-- ---------------------------------------------------------------------------

util.AddNetworkString("TTTBots_RateLimiterStats")

--- Push rate limiter stats to all connected admins.
--- Called periodically (every 5 seconds) while a round is active.
local function BroadcastRateLimiterStats()
    local stats = RL.GetStats()

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and not ply:IsBot() and ply:IsAdmin() then
            net.Start("TTTBots_RateLimiterStats")
                net.WriteUInt(stats.rpm,            16)
                net.WriteUInt(stats.maxRPM,         16)
                net.WriteUInt(stats.roundRequests,  16)
                net.WriteUInt(stats.maxPerRound,    16)
                net.WriteUInt(stats.roundTokens,    32)
                net.WriteUInt(stats.totalTokens,    32)
                net.WriteFloat(stats.roundCost)
                net.WriteFloat(stats.totalCost)
                net.WriteFloat(stats.budgetPerRound)
                net.WriteUInt(stats.roundRejected,  16)
                net.WriteUInt(stats.roundAllowed,    16)
            net.Send(ply)
        end
    end
end

timer.Create("TTTBots.RateLimiter.Broadcast", 5, 0, BroadcastRateLimiterStats)

-- ---------------------------------------------------------------------------
-- Shared policy helpers
-- ---------------------------------------------------------------------------

--- Strips control characters, backslashes, forward slashes, non-printable chars,
--- replaces %20 with space, and truncates to 1000 characters.
---@param text string
---@return string
function TTTBots.Providers.SanitizeText(text)
    if not text then return "" end
    -- Replace %20 with space
    text = string.gsub(text, "%%20", " ")
    -- Strip backslash and forward slash
    text = string.gsub(text, "[/\\]", "")
    -- Strip control chars and non-printable ASCII (below 0x20, above 0x7E)
    text = string.gsub(text, "[%c\128-\255]", "")
    -- Truncate to 1000 chars
    return string.sub(text, 1, 1000)
end

--- Strips leading/trailing single or double quotes from a string.
---@param text string
---@return string
function TTTBots.Providers.StripQuotes(text)
    if not text then return "" end
    return string.match(text, '^["\']?(.-)["\']?$') or text
end

--- Creates a failed-envelope table.
---@param provider string
---@param code number
---@param message string
---@param raw string|nil
---@return table
function TTTBots.Providers.MakeError(provider, code, message, raw)
    return { ok = false, provider = provider, code = code, message = message, raw = raw }
end

--- Creates a success-envelope table.
---@param provider string
---@param text any  -- for voice adapters this is the duration number
---@param totalTokens number|nil  -- optional: total_tokens from the API usage field
---@return table
function TTTBots.Providers.MakeOk(provider, text, totalTokens)
    return { ok = true, provider = provider, text = text, totalTokens = totalTokens }
end

--- Returns true if the response duplicates the prompt (either equal or one contains the other).
---@param response string
---@param prompt string
---@return boolean
function TTTBots.Providers.IsDuplicateResponse(response, prompt)
    if not response or not prompt then return false end
    if response == prompt then return true end
    if string.find(response, prompt, 1, true) then return true end
    if string.find(prompt, response, 1, true) then return true end
    return false
end

--- Safely serialises a Lua table into a JSON string using util.TableToJSON.
--- All adapters should use this instead of manual string concatenation to
--- prevent JSON injection from untrusted prompt text.
---@param tbl table  The request body as a Lua table
---@return string    JSON-encoded string suitable for an HTTP body
function TTTBots.Providers.BuildRequestBody(tbl)
    return util.TableToJSON(tbl)
end

-- ---------------------------------------------------------------------------
-- Provider lookup tables
-- ---------------------------------------------------------------------------

--- Maps the chatter_api_provider cvar integer to an adapter name.
TTTBots.Providers.TextAdapters = {
    [0] = "ChatGPT",
    [1] = "Gemini",
    [2] = "DeepSeek",
    -- [3] = mixed mode — resolved dynamically via bot personality
    [4] = "Ollama",
    [5] = "OpenRouter",
}

--- Maps voice type strings to adapter names.
TTTBots.Providers.VoiceAdapters = {
    ["elevenlabs"] = "ElevenLabs",
    ["Azure"]      = "Azure",
    ["local"]      = "Local",
    ["Local"]      = "Local",
    ["piper"]      = "Local",
    ["Piper"]      = "Local",
    -- anything else defaults to "FreeTTS"
}

-- ---------------------------------------------------------------------------
-- Adapter resolution helpers
-- ---------------------------------------------------------------------------

--- Returns the text adapter name for the given provider integer.
--- When providerInt is 3 (mixed mode), falls back to the bot's textAPI personality field.
---@param providerInt number
---@param bot Player|nil  -- required for mixed-mode (3)
---@return string  -- e.g. "ChatGPT", "Gemini", "DeepSeek"
function TTTBots.Providers.GetTextAdapter(providerInt, bot)
    if providerInt == 3 then
        -- Mixed mode: use bot personality
        if bot and IsValid(bot) and bot.components and bot.components.personality then
            local textAPI = bot.components.personality.textAPI
            if textAPI and TTTBots.Providers.TextAdapters then
                -- textAPI is already a name string like "Gemini", "DeepSeek", "ChatGPT"
                return textAPI
            end
        end
        return "ChatGPT" -- safe default
    end
    return TTTBots.Providers.TextAdapters[providerInt] or "ChatGPT"
end

--- Returns the voice adapter name for the given voice type string.
---@param voiceType string
---@return string
function TTTBots.Providers.GetVoiceAdapterName(voiceType)
    return TTTBots.Providers.VoiceAdapters[voiceType] or "FreeTTS"
end

-- ---------------------------------------------------------------------------
-- SendText — unified text dispatch
-- ---------------------------------------------------------------------------

--- Sends a text prompt to the appropriate LLM provider.
--- opts = { teamOnly=bool, wasVoice=bool, provider=int|nil }
--- callback(envelope) where envelope is MakeOk or MakeError.
---@param prompt string
---@param bot Player
---@param opts table
---@param callback function
function TTTBots.Providers.SendText(prompt, bot, opts, callback)
    opts = opts or {}

    -- Master LLM kill-switch: when disabled, immediately call back with an error
    -- so all callers fall through to their locale-string / fallback paths.
    if not lib.GetConVarBool("llm_enabled") then
        if callback then
            callback(TTTBots.Providers.MakeError("SendText", 0, "LLM is disabled (ttt_bot_llm_enabled = 0)", nil))
        end
        return
    end

    -- Rate limiter gate
    local allowed, reason = RL.ShouldAllow(opts)
    if not allowed then
        RL.RecordRejection()
        if callback then
            callback(TTTBots.Providers.MakeError("RateLimiter", 429, reason, nil))
        end
        return
    end

    -- Per-bot cooldown gate
    local cooldown = lib.GetConVarFloat("llm_cooldown") or 1.0
    if cooldown > 0 and IsValid(bot) and not RL.IsHighPriority(opts) then
        local lastCall = bot._lastLLMCallTime or 0
        if CurTime() - lastCall < cooldown then
            RL.RecordRejection()
            local debug = lib.GetConVarBool("llm_ratelimit_debug")
            if debug then
                print(string.format("[BOTDBG:RATELIMIT] REJECTED per-bot cooldown for %s (%.1fs / %.1fs)",
                    bot:Nick(), CurTime() - lastCall, cooldown))
            end
            if callback then
                callback(TTTBots.Providers.MakeError("BotCooldown", 429,
                    string.format("Per-bot cooldown: %.1fs remaining", cooldown - (CurTime() - lastCall)), nil))
            end
            return
        end
    end

    -- Stamp the bot's last LLM call time
    if IsValid(bot) then
        bot._lastLLMCallTime = CurTime()
    end

    RL.RecordRequest()

    local providerInt = opts.provider
    if providerInt == nil then
        providerInt = lib.GetConVarInt("chatter_api_provider")
    end

    local adapterName = TTTBots.Providers.GetTextAdapter(providerInt, bot)

    local adapter
    if adapterName == "Gemini" then
        adapter = TTTBots.Gemini
    elseif adapterName == "DeepSeek" then
        adapter = TTTBots.DeepSeek
    elseif adapterName == "Ollama" then
        adapter = TTTBots.Ollama
    elseif adapterName == "OpenRouter" then
        adapter = TTTBots.OpenRouter
    else
        adapter = TTTBots.ChatGPT
    end

    if not adapter or not adapter.SendText then
        if callback then
            callback(TTTBots.Providers.MakeError(adapterName, 0, "Adapter not available: " .. tostring(adapterName), nil))
        end
        return
    end

    -- Wrap callback to intercept token usage from the envelope
    local wrappedCallback = function(envelope)
        if envelope and envelope.totalTokens then
            RL.RecordTokens(envelope.totalTokens)
        end
        if callback then
            callback(envelope)
        end
    end

    adapter.SendText(prompt, bot, opts, wrappedCallback)
end

-- ---------------------------------------------------------------------------
-- SendVoice — unified voice dispatch
-- ---------------------------------------------------------------------------

--- Sends voice audio via the appropriate TTS provider.
--- opts = { teamOnly=bool }
--- callback(envelope) where envelope is MakeOk("TTS"/"TTSURL", duration) or MakeError.
---@param bot Player
---@param text string
---@param opts table
---@param callback function
function TTTBots.Providers.SendVoice(bot, text, opts, callback)
    opts = opts or {}

    local personality = bot:BotPersonality()
    local voiceType = personality and personality.voice and personality.voice.type or "free"
    local urlMode = lib.GetConVarInt("chatter_voice_url_mode")

    local adapterName = TTTBots.Providers.GetVoiceAdapterName(voiceType)

    local adapter
    -- Local TTS URLs are Docker-internal (http://ttsapi:80) and unreachable by game clients.
    -- In URL mode we can only use local TTS if the operator has set chatter_voice_local_tts_url
    -- to a public-facing address (Option B). Without that override, force binary mode instead.
    local localPublicURL = lib.GetConVarString("chatter_voice_local_tts_url")
    local localNeedsURLOverride = (voiceType == "local" and urlMode == 1 and (not localPublicURL or localPublicURL == ""))
    if urlMode == 1 and not localNeedsURLOverride then
        adapter = TTTBots.TTSURL
    else
        adapter = TTTBots.TTS
    end

    if not adapter or not adapter.SendVoice then
        if callback then
            callback(TTTBots.Providers.MakeError("TTS", 0, "Voice adapter not available", nil))
        end
        return
    end

    adapter.SendVoice(bot, text, opts, callback)
end
