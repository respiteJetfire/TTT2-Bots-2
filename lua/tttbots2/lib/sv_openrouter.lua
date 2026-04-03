-- sv_openrouter.lua
-- OpenRouter provider adapter for TTTBots.
-- OpenRouter exposes an OpenAI-compatible /chat/completions endpoint that can
-- proxy to hundreds of models (GPT-4o, Claude, Gemini, Mistral, etc.).
-- Docs: https://openrouter.ai/docs

TTTBots.OpenRouter = TTTBots.OpenRouter or {}

local lib = TTTBots.Lib

-- ---------------------------------------------------------------------------
-- SendText — envelope-based entry point
-- ---------------------------------------------------------------------------

--- Sends a prompt to OpenRouter and returns the result via an envelope callback.
--- opts = { teamOnly=bool, wasVoice=bool }
--- callback(envelope) where envelope is MakeOk("OpenRouter", text) or MakeError("OpenRouter", ...).
---@param prompt string
---@param bot Player
---@param opts table
---@param callback function
function TTTBots.OpenRouter.SendText(prompt, bot, opts, callback)
    opts = opts or {}

    local apiKey     = lib.GetConVarString("chatter_openrouter_api_key")
    local model      = lib.GetConVarString("chatter_openrouter_model")
    local temperature = lib.GetConVarFloat("chatter_temperature")
    local siteURL    = lib.GetConVarString("chatter_openrouter_site_url")
    local siteName   = lib.GetConVarString("chatter_openrouter_site_name")

    if not apiKey or apiKey == "" then
        if callback then
            callback(TTTBots.Providers.MakeError("OpenRouter", 0, "No API key configured (ttt_bot_chatter_openrouter_api_key)", nil))
        end
        return
    end

    -- JSON escaping helper
    local function jsonEscape(s)
        return string.gsub(s, '[%c"%\\]', function(c)
            return string.format('\\u%04x', string.byte(c))
        end)
    end

    -- Build messages array: optional system prompt + user prompt
    local systemPrompt = opts.systemPrompt
    local messagesJson
    if systemPrompt and systemPrompt ~= "" then
        messagesJson = string.format(
            '[{"role":"system","content":"%s"},{"role":"user","content":"%s"}]',
            jsonEscape(systemPrompt), jsonEscape(prompt)
        )
    else
        messagesJson = string.format(
            '[{"role":"user","content":"%s"}]',
            jsonEscape(prompt)
        )
    end

    local requestBody = string.format(
        '{"model":"%s","messages":%s,"max_tokens":500,"temperature":%.2f}',
        model, messagesJson, temperature
    )

    -- Build request headers
    local headers = {
        ['Content-Type']  = 'application/json',
        ['Authorization'] = 'Bearer ' .. apiKey,
        -- OpenRouter optional attribution headers (ignored if blank)
    }

    if siteURL and siteURL ~= "" then
        headers['HTTP-Referer'] = siteURL
    end
    if siteName and siteName ~= "" then
        headers['X-Title'] = siteName
    end

    HTTP({
        url     = 'https://openrouter.ai/api/v1/chat/completions',
        type    = 'application/json',
        method  = 'post',
        headers = headers,
        body    = requestBody,
        success = function(code, body, _headers)
            local ok, response = pcall(util.JSONToTable, body)
            if not ok or not response then
                if callback then
                    callback(TTTBots.Providers.MakeError("OpenRouter", code, "Invalid JSON response", body))
                end
                return
            end

            -- OpenRouter surfaces API errors as { "error": { "message": "...", "code": N } }
            if response.error then
                local errMsg = (type(response.error) == "table" and response.error.message)
                    or tostring(response.error)
                if callback then
                    callback(TTTBots.Providers.MakeError("OpenRouter", code, errMsg, body))
                end
                return
            end

            -- Standard OpenAI-compatible response path
            if response.choices
                and response.choices[1]
                and response.choices[1].message
                and response.choices[1].message.content
            then
                local text = TTTBots.Providers.SanitizeText(response.choices[1].message.content)
                text = TTTBots.Providers.StripQuotes(text)

                -- Duplicate-response guard
                if bot and IsValid(bot) and TTTBots.Providers.IsDuplicateResponse(text, prompt) then
                    if callback then
                        callback(TTTBots.Providers.MakeError("OpenRouter", code, "Duplicate response filtered", body))
                    end
                    return
                end

                -- Extract token usage for cost tracking
                local totalTokens = response.usage and response.usage.total_tokens or nil
                if callback then
                    callback(TTTBots.Providers.MakeOk("OpenRouter", text, totalTokens))
                end
            else
                if callback then
                    callback(TTTBots.Providers.MakeError("OpenRouter", code, "Invalid response structure", body))
                end
            end
        end,
        failed = function(err)
            print('[TTT Bots 2] OpenRouter HTTP error: ' .. tostring(err))
            if callback then
                callback(TTTBots.Providers.MakeError("OpenRouter", 0, tostring(err), nil))
            end
        end
    })
end

-- ---------------------------------------------------------------------------
-- ProcessResponse — backward compatibility helper
-- ---------------------------------------------------------------------------

--- Processes the raw JSON body from the OpenRouter API.
---@param body string
---@return string|nil
function TTTBots.OpenRouter.ProcessResponse(body)
    local success, response = pcall(util.JSONToTable, body)
    if not success then
        print("[TTT Bots 2] Failed to parse JSON response from OpenRouter API.")
        return nil
    end

    if response
        and response.choices
        and response.choices[1]
        and response.choices[1].message
        and response.choices[1].message.content
    then
        local text = response.choices[1].message.content
        return string.gsub(text, "%%20", " ")
    else
        print("[TTT Bots 2] Invalid response structure from OpenRouter API.")
        if response and response.error then
            local errMsg = (type(response.error) == "table" and response.error.message) or tostring(response.error)
            print("[TTT Bots 2] OpenRouter error: " .. errMsg)
        end
        return nil
    end
end

-- ---------------------------------------------------------------------------
-- SendRequest — backward compatibility shim (old signature)
-- ---------------------------------------------------------------------------

--- Backward-compatible shim. Calls SendText and unwraps the envelope for the old callback signature.
---@param text string
---@param bot Player
---@param teamOnly boolean
---@param wasVoice boolean
---@param responseCallback function  -- receives string|nil
function TTTBots.OpenRouter.SendRequest(text, bot, teamOnly, wasVoice, responseCallback)
    TTTBots.OpenRouter.SendText(text, bot, { teamOnly = teamOnly, wasVoice = wasVoice }, function(envelope)
        if not responseCallback then return end
        if envelope.ok then
            if bot and IsValid(bot) and TTTBots.Providers.IsDuplicateResponse(envelope.text, text) then
                responseCallback(nil)
            else
                responseCallback(envelope.text)
            end
        else
            print("[TTT Bots 2] OpenRouter error: " .. tostring(envelope.message))
            responseCallback(nil)
        end
    end)
end
