-- sv_chatGPT.lua
-- ChatGPT provider adapter for TTTBots.

TTTBots.ChatGPT = TTTBots.ChatGPT or {}

local lib = TTTBots.Lib

-- ---------------------------------------------------------------------------
-- SendText — envelope-based entry point (new)
-- ---------------------------------------------------------------------------

--- Sends a prompt to the ChatGPT API and returns the result via an envelope callback.
--- opts = { teamOnly=bool, wasVoice=bool }
--- callback(envelope) where envelope is MakeOk("ChatGPT", text) or MakeError("ChatGPT", ...).
---@param prompt string
---@param bot Player
---@param opts table
---@param callback function
function TTTBots.ChatGPT.SendText(prompt, bot, opts, callback)
    opts = opts or {}
    local apiKey = lib.GetConVarString("chatter_chatgpt_api_key")
    local temperature = lib.GetConVarFloat("chatter_temperature")
    local model = lib.GetConVarString("chatter_gpt_model")

    if not apiKey or apiKey == "" then
        if callback then
            callback(TTTBots.Providers.MakeError("ChatGPT", 0, "No API key configured", nil))
        end
        return
    end

    -- Char-by-char JSON escaping of the prompt
    local escapedText = string.gsub(prompt, '[%c"%\\]', function(c)
        return string.format('\\u%04x', string.byte(c))
    end)
    local requestBody = string.format(
        '{"model":"%s","messages":[{"role":"user","content":"%s"}],"max_tokens":500,"temperature":%.1f}',
        model, escapedText, temperature
    )

    HTTP({
        url = 'https://api.openai.com/v1/chat/completions',
        type = 'application/json',
        method = 'post',
        headers = {
            ['Content-Type'] = 'application/json',
            ['Authorization'] = 'Bearer ' .. apiKey,
        },
        body = requestBody,
        success = function(code, body, headers)
            local ok, response = pcall(util.JSONToTable, body)
            if not ok or not response then
                if callback then
                    callback(TTTBots.Providers.MakeError("ChatGPT", code, "Invalid response structure", body))
                end
                return
            end

            if response.error and response.error.message then
                if callback then
                    callback(TTTBots.Providers.MakeError("ChatGPT", code, response.error.message, body))
                end
                return
            end

            if response.choices and response.choices[1] and response.choices[1].message and response.choices[1].message.content then
                local text = response.choices[1].message.content
                text = TTTBots.Providers.SanitizeText(text)
                if callback then
                    callback(TTTBots.Providers.MakeOk("ChatGPT", text))
                end
            else
                if callback then
                    callback(TTTBots.Providers.MakeError("ChatGPT", code, "Invalid response structure", body))
                end
            end
        end,
        failed = function(err)
            print('ChatGPT HTTP Error: ' .. tostring(err))
            if callback then
                callback(TTTBots.Providers.MakeError("ChatGPT", 0, tostring(err), nil))
            end
        end
    })
end

-- ---------------------------------------------------------------------------
-- ProcessResponse — backward compatibility helper
-- ---------------------------------------------------------------------------

--- Processes the raw JSON body from the ChatGPT API.
---@param body string
---@return string|nil
function TTTBots.ChatGPT.ProcessResponse(body)
    local success, response = pcall(util.JSONToTable, body)
    if not success then
        print("Failed to parse JSON response from ChatGPT API.")
        return nil
    end

    if response and response.choices and response.choices[1] and response.choices[1].message and response.choices[1].message.content then
        local gptResponse = response.choices[1].message.content
        -- Replace %20 with spaces
        gptResponse = string.gsub(gptResponse, "%%20", " ")
        return gptResponse
    else
        print("Invalid response structure from ChatGPT API.")
        if response and response.error and response.error.message then
            print("Error message from API: " .. response.error.message)
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
function TTTBots.ChatGPT.SendRequest(text, bot, teamOnly, wasVoice, responseCallback)
    TTTBots.ChatGPT.SendText(text, bot, { teamOnly = teamOnly, wasVoice = wasVoice }, function(envelope)
        if not responseCallback then return end
        if envelope.ok then
            -- Apply duplicate-response guard that the old code had
            if bot and IsValid(bot) and TTTBots.Providers.IsDuplicateResponse(envelope.text, text) then
                responseCallback(nil)
            else
                responseCallback(envelope.text)
            end
        else
            print("ChatGPT error: " .. tostring(envelope.message))
            responseCallback(nil)
        end
    end)
end