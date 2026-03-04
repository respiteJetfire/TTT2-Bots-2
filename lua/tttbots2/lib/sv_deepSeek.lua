-- DeepSeek Implementation
TTTBots.DeepSeek = TTTBots.DeepSeek or {}

function TTTBots.DeepSeek.SendRequest(text, bot, teamOnly, wasVoice, responseCallback)
    local apiKey = TTTBots.Lib.GetConVarString("chatter_deepseek_api_key")
    local temperature = TTTBots.Lib.GetConVarFloat("chatter_temperature")
    local model = TTTBots.Lib.GetConVarString("chatter_deepseek_model")
    wasVoice = wasVoice or false
    if not apiKey or apiKey == "" then
        print("No DeepSeek API key found.")
        return
    end
    if not teamOnly then teamOnly = false end

    -- Sanitize and escape the text for JSON
    local sanitizedText = string.gsub(text, '[%c%z\128-\255]', '')
    sanitizedText = string.gsub(sanitizedText, '["]', '\\"')

    HTTP({
        url = 'https://api.deepseek.com/v1/chat/completions',
        type = 'application/json',
        method = 'post',
        headers = {
            ['Content-Type'] = 'application/json',
            ['Authorization'] = 'Bearer ' .. apiKey,
        },
        body = [[{
            "model": "]] .. model .. [[",
            "messages": [{"role": "user", "content": "]] .. sanitizedText .. [["}],
            "max_tokens": 500,
            "temperature": ]] .. temperature .. [[
        }]],
        success = function(code, body, headers)
            local apiResponse = TTTBots.DeepSeek.ProcessResponse(body)
            if apiResponse and bot and IsValid(bot) and apiResponse ~= text and not string.find(apiResponse, text) and not string.find(text, apiResponse) then
                if responseCallback then
                    responseCallback(apiResponse)
                end
            end
        end,
        failed = function(err)
            print('HTTP Error: ' .. err)
            return nil
        end
    })
end

function TTTBots.DeepSeek.ProcessResponse(body)
    local success, response = pcall(util.JSONToTable, body)
    -- print(body)
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
