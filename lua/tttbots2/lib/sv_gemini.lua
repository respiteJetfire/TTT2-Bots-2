-- sv_gemini.lua
-- Gemini provider adapter for TTTBots.

TTTBots.Gemini = TTTBots.Gemini or {}

local lib = TTTBots.Lib

-- ---------------------------------------------------------------------------
-- SendText — envelope-based entry point (new)
-- ---------------------------------------------------------------------------

--- Sends a prompt to the Gemini API and returns the result via an envelope callback.
--- opts = { teamOnly=bool, wasVoice=bool }
--- callback(envelope) where envelope is MakeOk("Gemini", text) or MakeError("Gemini", ...).
---@param prompt string
---@param bot Player
---@param opts table
---@param callback function
function TTTBots.Gemini.SendText(prompt, bot, opts, callback)
    opts = opts or {}
    local apiKey = lib.GetConVarString("chatter_gemini_api_key")
    local temperature = lib.GetConVarFloat("chatter_temperature")
    local model = lib.GetConVarString("chatter_gemini_model")

    if not apiKey or apiKey == "" then
        if callback then
            callback(TTTBots.Providers.MakeError("Gemini", 0, "No API key configured", nil))
        end
        return
    end

    local url = 'https://generativelanguage.googleapis.com/v1beta/models/' .. model .. ':generateContent?key=' .. apiKey
    if string.find(model, "gemini-2") then
        url = 'https://generativelanguage.googleapis.com/v1/models/' .. model .. ':generateContent?key=' .. apiKey
    end

    HTTP({
        url = url,
        type = 'application/json',
        method = 'post',
        headers = {
            ['Content-Type'] = 'application/json',
        },
        body = [[{
            "contents": [{
                "parts": [{
                    "text": "]] .. prompt .. [["
                }]
            }],
            "generationConfig": {
                "temperature": ]] .. temperature .. [[,
                "maxOutputTokens": 500
            }
        }]],
        success = function(code, body, headers)
            if code == 200 then
                local ok, response = pcall(util.JSONToTable, body)
                if not ok or not response then
                    if callback then
                        callback(TTTBots.Providers.MakeError("Gemini", code, "Invalid response structure", body))
                    end
                    return
                end

                if response.candidates and response.candidates[1] and
                   response.candidates[1].content and response.candidates[1].content.parts and
                   response.candidates[1].content.parts[1] and response.candidates[1].content.parts[1].text then
                    local text = TTTBots.Providers.SanitizeText(response.candidates[1].content.parts[1].text)
                    if callback then
                        callback(TTTBots.Providers.MakeOk("Gemini", text))
                    end
                else
                    local msg = "Invalid response structure"
                    if response.error and response.error.message then
                        msg = response.error.message
                    end
                    if callback then
                        callback(TTTBots.Providers.MakeError("Gemini", code, msg, body))
                    end
                end
            else
                print("Gemini API Error: " .. code .. " - " .. body)
                if callback then
                    callback(TTTBots.Providers.MakeError("Gemini", code, "HTTP " .. code, body))
                end
            end
        end,
        failed = function(err)
            print('Gemini HTTP Error: ' .. tostring(err))
            if callback then
                callback(TTTBots.Providers.MakeError("Gemini", 0, tostring(err), nil))
            end
        end
    })
end

-- ---------------------------------------------------------------------------
-- ProcessResponse — backward compatibility helper
-- ---------------------------------------------------------------------------

-- The old SendRequest is now a shim; keep ProcessResponse for any code that calls it directly.

--- Backward-compatible shim. Calls SendText and unwraps the envelope for the old callback signature.
---@param text string
---@param bot Player
---@param teamOnly boolean
---@param wasVoice boolean
---@param responseCallback function  -- receives string|nil
function TTTBots.Gemini.SendRequest(text, bot, teamOnly, wasVoice, responseCallback)
    TTTBots.Gemini.SendText(text, bot, { teamOnly = teamOnly, wasVoice = wasVoice }, function(envelope)
        if not responseCallback then return end
        if envelope.ok then
            if bot and IsValid(bot) and TTTBots.Providers.IsDuplicateResponse(envelope.text, text) then
                responseCallback(nil)
            else
                responseCallback(envelope.text)
            end
        else
            print("Gemini error: " .. tostring(envelope.message))
            responseCallback(nil)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- ProcessResponse
-- ---------------------------------------------------------------------------

--- Processes the raw JSON body from the Gemini API.
---@param body string
---@return string|nil
function TTTBots.Gemini.ProcessResponse(body)
    local success, response = pcall(util.JSONToTable, body)
    if not success then
        print("Failed to parse JSON response from Gemini API.")
        return nil
    end

    if response and response.candidates and response.candidates[1] and response.candidates[1].content and response.candidates[1].content.parts and response.candidates[1].content.parts[1] and response.candidates[1].content.parts[1].text then
        return string.gsub(response.candidates[1].content.parts[1].text, "%%20", " ")
    else
        print("Invalid response structure from Gemini API.")
        if response and response.error and response.error.message then
            print("Error message from API: " .. response.error.message)
        end
        return nil
    end
end
