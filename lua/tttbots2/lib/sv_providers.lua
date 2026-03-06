-- sv_providers.lua
-- Central provider adapter registry for TTTBots text and voice dispatch.
-- Must be included before the individual provider files.

TTTBots.Providers = TTTBots.Providers or {}

local lib = TTTBots.Lib

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
---@return table
function TTTBots.Providers.MakeOk(provider, text)
    return { ok = true, provider = provider, text = text }
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
    else
        adapter = TTTBots.ChatGPT
    end

    if not adapter or not adapter.SendText then
        if callback then
            callback(TTTBots.Providers.MakeError(adapterName, 0, "Adapter not available: " .. tostring(adapterName), nil))
        end
        return
    end

    adapter.SendText(prompt, bot, opts, callback)
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
