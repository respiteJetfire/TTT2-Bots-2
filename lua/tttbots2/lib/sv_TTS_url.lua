util.AddNetworkString("SayTTSUrlStart")

TTTBots.TTSURL = TTTBots.TTSURL or {}
TTTBots.TTSURL.Cache = {}

local lib = TTTBots.Lib

local function playTTSUrl(ply, url, teamOnly)
    net.Start("SayTTSUrlStart")
    net.WriteEntity(ply)
    net.WriteString(url)
    net.WriteBool(teamOnly)
    net.Broadcast()
end

local function TableToQueryString(tbl)
    local queryString = ""
    for key, value in pairs(tbl) do
        queryString = queryString .. key .. "=" .. tostring(value) .. "&"
    end
    return string.sub(queryString, 1, -2) -- Remove the trailing '&'
end

function TTTBots.TTSURL.FreeTTSSendRequest(bot, text, teamOnly)
    -- Sanitize the text to make it URL-friendly
    -- print("Sending to FreeTTS: " .. text)
    local fulltxt = text
    text = string.gsub(text, "[^%w%s]", "") -- Remove non-alphanumeric characters except spaces
    text = string.sub(string.Replace(text, " ", "%20"), 1, 1000) -- Replace spaces with "%20" and limit the text length to 1000 characters
    --- get the bot's personality
    local personality = bot:BotPersonality()
    local voice = personality.voice
    local teamOnly = teamOnly or false

    local url = "https://tetyys.com/SAPI4/SAPI4?voice=" .. voice.name .. "&pitch=" .. voice.pitch .. "&speed=" .. voice.speed .. "&text=" .. text

    -- Play the TTSURL audio directly from the URL
    playTTSUrl(bot, url, teamOnly)
end

function TTTBots.TTSURL.ElevenLabsSendRequest(ply, text, teamOnly)
    -- print("Sending to ElevenLabs: " .. text)
    local personality = ply:BotPersonality()
    local voiceID = personality.voice.id
    local teamOnly = teamOnly or false
    text = string.sub(text, 1, 1000) -- Limit the text length to 1000 characters
    local model_id
    local voiceModelCvar = TTTBots.Lib.GetConVarInt("chatter_elevenlabs_voice_model")
    if voiceModelCvar == 0 then
        model_id = "eleven_turbo_v2_5"
    elseif voiceModelCvar == 1 then
        model_id = "eleven_multilingual_v2"
    elseif voiceModelCvar == 2 then
        model_id = "eleven_monolingual_v1"
    elseif voiceModelCvar == 3 then
        model_id = "eleven_monolingual_v1"
    else
        model_id = "eleven_turbo_v2_5" -- Default to eleven_turbo_v2_5 if the cvar is out of range
    end

    text = string.gsub(text, "[^%w%s]", "") -- Remove non-alphanumeric characters except spaces

    local params = util.TableToJSON({
        text = text,
        voice_id = voiceID,
        model_id = model_id,
        api_key = TTTBots.Lib.GetConVarString("chatter_voice_elevenlabs_api_key")
    })

    local url = 'http://gmodttsapi-hsb8eeeqa8b2acbk.uksouth-01.azurewebsites.net:80/elevenlabs'

    -- print("ElevenLabs request URL: " .. url)
    -- print("ElevenLabs request params: " .. params)

    HTTP({
        url = url,
        method = 'post',
        type = 'application/json',
        headers = {
            ["Content-Type"] = "application/json"
        },
        body = params,
        success = function(code, body)
            -- print("HTTP request successful. Code: " .. code)
            if code == 200 then
                local response = util.JSONToTable(body)
                if response then
                    -- print("ElevenLabs response: " .. body)
                    if response.download_url then
                        local downloadURL = 'http://gmodttsapi-hsb8eeeqa8b2acbk.uksouth-01.azurewebsites.net:80/elevenlabs' .. response.download_url
                        playTTSUrl(ply, downloadURL, teamOnly)
                    else
                        print("Failed to get download URL from ElevenLabs response.")
                    end
                else
                    print("Failed to parse ElevenLabs response.")
                end
            else
                print("The HTTP request to ElevenLabs API failed. HTTP Code: " .. code)
                print("Body: " .. body)
            end
        end,
        failed = function(err)
            print("HTTP request to ElevenLabs API failed: " .. err)
        end
    })
end

function TTTBots.TTSURL.AzureSendRequest(ply, text, teamOnly)
    local personality = ply:BotPersonality()
    local voice_name = personality.voice.id
    local teamOnly = teamOnly or false
    text = string.sub(text, 1, 1000) -- Limit the text length to 1000 characters

    local jsonBody = util.TableToJSON({
        text = text,
        voice_name = voice_name,
        region = TTTBots.Lib.GetConVarString("chatter_voice_azure_region"),
        api_key = TTTBots.Lib.GetConVarString("chatter_voice_azure_resource_api_key")
    })

    local url = 'http://gmodttsapi-hsb8eeeqa8b2acbk.uksouth-01.azurewebsites.net:80/azure'

    HTTP({
        url = url,
        method = 'post',
        type = 'application/json',
        headers = {
            ["Content-Type"] = "application/json"
        },
        body = jsonBody,
        success = function(code, body)
            if code == 200 then
                local response = util.JSONToTable(body)
                if response and response.download_url then
                    local downloadURL = response.download_url
                    playTTSUrl(ply, downloadURL, teamOnly)
                else
                    print("Failed to get download URL from Azure response.")
                end
            else
                print("The HTTP request to Azure API failed. HTTP Code: " .. code)
                print("Body: " .. body)
            end
        end,
        failed = function(err)
            print("HTTP request to Azure API failed: " .. err)
        end
    })
end