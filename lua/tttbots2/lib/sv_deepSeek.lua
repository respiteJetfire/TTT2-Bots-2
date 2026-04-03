-- sv_deepSeek.lua
-- DeepSeek provider adapter for TTTBots.

TTTBots.DeepSeek = TTTBots.DeepSeek or {}

local lib = TTTBots.Lib

-- ---------------------------------------------------------------------------
-- SendText — envelope-based entry point (new)
-- ---------------------------------------------------------------------------

--- Sends a prompt to the DeepSeek API and returns the result via an envelope callback.
--- opts = { teamOnly=bool, wasVoice=bool }
--- callback(envelope) where envelope is MakeOk("DeepSeek", text) or MakeError("DeepSeek", ...).
---@param prompt string
---@param bot Player
---@param opts table
---@param callback function
function TTTBots.DeepSeek.SendText(prompt, bot, opts, callback)
    opts = opts or {}
    local apiKey = lib.GetConVarString("chatter_deepseek_api_key")
    local temperature = lib.GetConVarFloat("chatter_temperature")
    local model = lib.GetConVarString("chatter_deepseek_model")

    if not apiKey or apiKey == "" then
        if callback then
            callback(TTTBots.Providers.MakeError("DeepSeek", 0, "No API key configured", nil))
        end
        return
    end

    -- Build request body as a proper Lua table, then serialise safely with
    -- util.TableToJSON to prevent JSON injection from untrusted prompt text.
    local messages = {}
    local systemPrompt = opts.systemPrompt
    if systemPrompt and systemPrompt ~= "" then
        messages[#messages + 1] = { role = "system", content = systemPrompt }
    end
    messages[#messages + 1] = { role = "user", content = prompt }

    local requestBody = util.TableToJSON({
        model = model,
        messages = messages,
        max_tokens = 500,
        temperature = temperature
    })

    HTTP({
        url = 'https://api.deepseek.com/v1/chat/completions',
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
                    callback(TTTBots.Providers.MakeError("DeepSeek", code, "Invalid response structure", body))
                end
                return
            end

            if response.choices and response.choices[1] and response.choices[1].message and response.choices[1].message.content then
                local text = TTTBots.Providers.SanitizeText(response.choices[1].message.content)
                -- Extract token usage for cost tracking
                local totalTokens = response.usage and response.usage.total_tokens or nil
                if callback then
                    callback(TTTBots.Providers.MakeOk("DeepSeek", text, totalTokens))
                end
            else
                local msg = "Invalid response structure"
                if response.error and response.error.message then
                    msg = response.error.message
                end
                if callback then
                    callback(TTTBots.Providers.MakeError("DeepSeek", code, msg, body))
                end
            end
        end,
        failed = function(err)
            print('DeepSeek HTTP Error: ' .. tostring(err))
            if callback then
                callback(TTTBots.Providers.MakeError("DeepSeek", 0, tostring(err), nil))
            end
        end
    })
end

-- ---------------------------------------------------------------------------
-- ProcessResponse — backward compatibility helper
-- ---------------------------------------------------------------------------

--- Processes the raw JSON body from the DeepSeek API.
---@param body string
---@return string|nil
function TTTBots.DeepSeek.ProcessResponse(body)
    local success, response = pcall(util.JSONToTable, body)
    if not success then
        print(body)
        print("Failed to parse JSON response from DeepSeek API.")
        return nil
    end

    if response and response.choices and response.choices[1] and response.choices[1].message and response.choices[1].message.content then
        return string.gsub(response.choices[1].message.content, "%%20", " ")
    else
        print(body)
        print("Invalid response structure from DeepSeek API.")
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
function TTTBots.DeepSeek.SendRequest(text, bot, teamOnly, wasVoice, responseCallback)
    TTTBots.DeepSeek.SendText(text, bot, { teamOnly = teamOnly, wasVoice = wasVoice }, function(envelope)
        if not responseCallback then return end
        if envelope.ok then
            if bot and IsValid(bot) and TTTBots.Providers.IsDuplicateResponse(envelope.text, text) then
                responseCallback(nil)
            else
                responseCallback(envelope.text)
            end
        else
            print("DeepSeek error: " .. tostring(envelope.message))
            responseCallback(nil)
        end
    end)
end
