TTTBots.ChatGPT = TTTBots.ChatGPT or {}

local lib = TTTBots.Lib

--- Sends a request to the ChatGPT API.
---@param text string
function TTTBots.ChatGPT.SendRequest(text, bot, teamOnly, wasVoice)
    local apiKey = TTTBots.Lib.GetConVarString("chatter_chatgpt_api_key")
    local temperature = TTTBots.Lib.GetConVarFloat("chatter_chatgpt_temperature")
    wasVoice = wasVoice or false
    if not apiKey or apiKey == "" then
        print("No ChatGPT API key found.")
        return
    end
    if not teamOnly then teamOnly = false end

    HTTP({
        url = 'https://api.openai.com/v1/chat/completions',
        type = 'application/json',
        method = 'post',
        headers = {
            ['Content-Type'] = 'application/json',
            ['Authorization'] = 'Bearer ' .. apiKey,
        },
        body = [[{
            "model": "gpt-3.5-turbo",
            "messages": [{"role": "user", "content": "]] .. text .. [["}],
            "max_tokens": 150,
            "temperature": '0.4'
        }]],
        success = function(code, body, headers)
            local response = TTTBots.ChatGPT.ProcessResponse(body)
            if response and bot and IsValid(bot) and response ~= text and not string.find(response, text) and not string.find(text, response) then
                -- print("Response from ChatGPT API: " .. response)
                local chatter = bot:GetChatter()
                chatter:textorTTS(bot, response, teamOnly, nil, wasVoice)

            elseif response and response.error and response.error.message then
                print("Error message from API: " .. response.error.message)
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