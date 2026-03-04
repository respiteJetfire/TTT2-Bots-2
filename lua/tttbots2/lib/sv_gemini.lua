-- Gemini Implementation
TTTBots.Gemini = TTTBots.Gemini or {}

function TTTBots.Gemini.SendRequest(text, bot, teamOnly, wasVoice, responseCallback)
    local apiKey = TTTBots.Lib.GetConVarString("chatter_gemini_api_key")
    local temperature = TTTBots.Lib.GetConVarFloat("chatter_temperature")
    local model = TTTBots.Lib.GetConVarString("chatter_gemini_model")
    wasVoice = wasVoice or false
    if not apiKey or apiKey == "" then
        print("No Gemini API key found.")
        return
    end
    if not teamOnly then teamOnly = false end

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
                    "text": "]] .. text .. [["
                }]
            }],
            "generationConfig": {
                "temperature": ]] .. temperature .. [[,
                "maxOutputTokens": 500
            }
        }]],
        success = function(code, body, headers)
            if code == 200 then
                local apiResponse = TTTBots.Gemini.ProcessResponse(body)
                if apiResponse and bot and IsValid(bot) and apiResponse ~= text and not string.find(apiResponse, text) and not string.find(text, apiResponse) then
                    if responseCallback then
                        responseCallback(apiResponse)
                    end
                end
            else
                print("Gemini API Error: " .. code .. " - " .. body)
                if responseCallback then
                    responseCallback(nil)
                end
            end
        end,
        failed = function(err)
            print('HTTP Error: ' .. err)
            if responseCallback then
                responseCallback(nil)
            end
            return nil
        end
    })
end

function TTTBots.Gemini.ProcessResponse(body)
    -- print("Gemini API Response Body: " .. body) -- Print the raw response body

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
