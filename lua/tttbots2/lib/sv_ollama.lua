-- sv_ollama.lua
-- Local Ollama LLM provider adapter for TTTBots.
-- Routes through the ttsapi /llm proxy endpoint (Ollama-backed).

TTTBots.Ollama = TTTBots.Ollama or {}

local lib = TTTBots.Lib

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

--- Resolve the LLM endpoint URL.
--- Priority: TTSAPI global (set by ttsapi_config.lua) → CVar override → hardcoded fallback.
---@return string
local function getURL()
    if TTSAPI and TTSAPI.LLMURL and TTSAPI.LLMURL ~= "" then
        return TTSAPI.LLMURL
    end
    local cvarURL = lib.GetConVarString("chatter_ollama_url")
    if cvarURL and cvarURL ~= "" then
        return cvarURL
    end
    return "http://ttsapi:80/llm"
end

--- Resolve the model name.
--- Priority: TTSAPI global → CVar → hardcoded fallback.
---@return string
local function getModel()
    if TTSAPI and TTSAPI.DefaultModel and TTSAPI.DefaultModel ~= "" then
        return TTSAPI.DefaultModel
    end
    local cvarModel = lib.GetConVarString("chatter_ollama_model")
    if cvarModel and cvarModel ~= "" then
        return cvarModel
    end
    return "tinyllama"
end

--- Escape a string for safe inclusion inside a JSON string value.
---@param s string
---@return string
local function jsonEscape(s)
    return string.gsub(s, '[%c"%\\]', function(c)
        return string.format('\\u%04x', string.byte(c))
    end)
end

-- ---------------------------------------------------------------------------
-- SendText — envelope-based entry point
-- ---------------------------------------------------------------------------

--- Sends a prompt to the local Ollama LLM via the ttsapi /llm endpoint.
--- opts = { teamOnly=bool, wasVoice=bool }
--- callback(envelope) where envelope is MakeOk("Ollama", text) or MakeError("Ollama", ...).
---@param prompt string
---@param bot Player
---@param opts table
---@param callback function
function TTTBots.Ollama.SendText(prompt, bot, opts, callback)
    opts = opts or {}

    local url        = getURL()
    local model      = getModel()
    local temperature = lib.GetConVarFloat("chatter_temperature")
    -- Clamp temperature for small models — high values cause incoherent output
    if temperature > 0.7 then temperature = 0.7 end

    local botName = IsValid(bot) and bot:Nick() or nil

    -- Build llama-optimised prompt pair from the event/reply context when available.
    -- This keeps bot identity in the system prompt where small models won't echo it.
    local llamaSystem = ""
    local llamaPrompt = prompt  -- fallback: use the ChatGPT-style flat prompt

    if TTTBots.LlamaPrompts and IsValid(bot) then
        if opts.replyText and opts.replyPly then
            -- Replying to a human player's message
            local pd = TTTBots.LlamaPrompts.GetResponsePrompt(bot, opts.replyText, opts.teamOnly or false, opts.replyPly)
            llamaSystem = pd.system
            llamaPrompt = pd.prompt
        elseif opts.eventName then
            -- Reacting to a game event
            local pd = TTTBots.LlamaPrompts.GetEventPrompt(opts.eventName, bot, opts.eventArgs, opts.teamOnly or false, opts.wasVoice or false, opts.description)
            llamaSystem = pd.system
            llamaPrompt = pd.prompt
        else
            -- No structured context — still build a system prompt to set identity
            llamaSystem = TTTBots.LlamaPrompts.BuildSystemPrompt(bot)
        end
    end

    -- Build JSON body
    local botNameField = ""
    if botName then
        botNameField = string.format(',"bot_name":"%s"', jsonEscape(botName))
    end

    local systemField = ""
    if llamaSystem ~= "" then
        systemField = string.format(',"system":"%s"', jsonEscape(llamaSystem))
    end

    local requestBody = string.format(
        '{"prompt":"%s","model":"%s","temperature":%.2f%s%s}',
        jsonEscape(llamaPrompt), model, temperature, botNameField, systemField
    )

    HTTP({
        url    = url,
        type   = 'application/json',
        method = 'post',
        headers = {
            ['Content-Type'] = 'application/json',
        },
        body = requestBody,
        success = function(code, body, headers)
            -- Non-200 codes still arrive in success; handle them explicitly.
            if code ~= 200 then
                local errMsg = string.format("Ollama returned HTTP %d", code)
                -- Try to extract a message field from the body if present
                local ok, parsed = pcall(util.JSONToTable, body)
                if ok and parsed and parsed.error then
                    errMsg = tostring(parsed.error)
                end
                if callback then
                    callback(TTTBots.Providers.MakeError("Ollama", code, errMsg, body))
                end
                return
            end

            local ok, response = pcall(util.JSONToTable, body)
            if not ok or not response then
                if callback then
                    callback(TTTBots.Providers.MakeError("Ollama", code, "Invalid JSON response", body))
                end
                return
            end

            if response.error then
                if callback then
                    callback(TTTBots.Providers.MakeError("Ollama", code, tostring(response.error), body))
                end
                return
            end

            -- /llm endpoint returns { "response": "...", "model": "..." }
            if response.response and response.response ~= "" then
                local text = TTTBots.Providers.SanitizeText(response.response)
                text = TTTBots.Providers.StripQuotes(text)

                -- Duplicate-response guard
                if bot and IsValid(bot) and TTTBots.Providers.IsDuplicateResponse(text, prompt) then
                    if callback then
                        callback(TTTBots.Providers.MakeError("Ollama", code, "Duplicate response filtered", body))
                    end
                    return
                end

                if callback then
                    callback(TTTBots.Providers.MakeOk("Ollama", text))
                end
            else
                if callback then
                    callback(TTTBots.Providers.MakeError("Ollama", code, "Empty or missing response field", body))
                end
            end
        end,
        failed = function(err)
            print('[TTT Bots 2] Ollama HTTP error: ' .. tostring(err))
            if callback then
                callback(TTTBots.Providers.MakeError("Ollama", 0, tostring(err), nil))
            end
        end
    })
end

-- ---------------------------------------------------------------------------
-- SendRequest — backward-compatibility shim (old signature)
-- ---------------------------------------------------------------------------

--- Backward-compatible shim. Calls SendText and unwraps the envelope for the old callback signature.
---@param text string
---@param bot Player
---@param teamOnly boolean
---@param wasVoice boolean
---@param responseCallback function  -- receives string|nil
function TTTBots.Ollama.SendRequest(text, bot, teamOnly, wasVoice, responseCallback)
    TTTBots.Ollama.SendText(text, bot, { teamOnly = teamOnly, wasVoice = wasVoice }, function(envelope)
        if not responseCallback then return end
        if envelope.ok then
            responseCallback(envelope.text)
        else
            print('[TTT Bots 2] Ollama error: ' .. tostring(envelope.message))
            responseCallback(nil)
        end
    end)
end
