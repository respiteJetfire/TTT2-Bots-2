TTTBots.ChatGPT = TTTBots.ChatGPT or {}

local lib = TTTBots.Lib

--- Sends a request to the ChatGPT API.
---@param text string
function TTTBots.ChatGPT.SendRequest(text, bot, teamOnly, wasVoice, responseCallback)
    local apiKey = TTTBots.Lib.GetConVarString("chatter_chatgpt_api_key")
    local temperature = TTTBots.Lib.GetConVarFloat("chatter_temperature")
    local provider = TTTBots.Lib.GetConVarString("chatter_api_provider")
    local model = TTTBots.Lib.GetConVarString("chatter_gpt_model")
    wasVoice = wasVoice or false
    if not apiKey or apiKey == "" then
        print("No ChatGPT API key found.")
        return
    end
    if not teamOnly then teamOnly = false end

    -- Manually construct the JSON string with proper escaping
    local escapedText = string.gsub(text, '[%c"%\\]', function(c)
        return string.format('\\u%04x', string.byte(c))
    end)
    local requestBody = string.format(
        '{"model":"%s","messages":[{"role":"user","content":"%s"}],"max_tokens":500,"temperature":%.1f}',
        model, escapedText, temperature
    )

    -- print(requestBody) -- Debug print to check the JSON string

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
            local apiResponse = TTTBots.ChatGPT.ProcessResponse(body)
            if apiResponse and bot and IsValid(bot) and apiResponse ~= text and not string.find(apiResponse, text) and not string.find(text, apiResponse) then
                if responseCallback then
                    responseCallback(apiResponse)
                end
            elseif apiResponse and apiResponse.error and apiResponse.error.message then
                print("Error message from API: " .. apiResponse.error.message)
                if responseCallback then
                    responseCallback(nil)
                end
            end
        end,
        failed = function(err)
            print('HTTP Error: ' .. err)
            return nil
        end
    })
end

--- Processes the response from the ChatGPT API.
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
        --- replace %20 with spaces
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