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

    local jsonBody = util.TableToJSON({
        text = text,
        voice_id = voiceID,
        model_id = model_id,
        api_key = TTTBots.Lib.GetConVarString("chatter_voice_elevenlabs_api_key")
    })

    HTTP({
        url = 'http://gmodttsapi-hsb8eeeqa8b2acbk.uksouth-01.azurewebsites.net:80/elevenlabs',
        type = 'application/json',
        method = 'post',
        headers = {
            ['Content-Type'] = 'application/json'
        },
        body = jsonBody,
        success = function(code, body)
            if code == 200 then
                local response = util.JSONToTable(body)
                if response then
                    print("ElevenLabs response: " .. body)
                    if response.download_url then
                        playTTSUrl(ply, response.download_url, teamOnly)
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

-- function TTTBots.TTSURL.AzureTTSSendRequest(ply, text, teamOnly)
--     print("Sending to Azure: " .. text)
--     local azureRegion = TTTBots.Lib.GetConVarString("chatter_voice_azure_region")
--     local azureResourceGroupName = TTTBots.Lib.GetConVarString("chatter_voice_azure_resource_name")
--     local azureResourceSpeechAPIKey = TTTBots.Lib.GetConVarString("chatter_voice_azure_resource_api_key")
--     local azureVoiceName = ply:BotPersonality().voice.id
--     local azureTokenEndpoint = "https://" .. azureRegion .. ".api.cognitive.microsoft.com/sts/v1.0/issuetoken"
--     local azureTTSEndpoint = "https://" .. azureRegion .. ".tts.speech.microsoft.com/cognitiveservices/v1"

--     local function handleTTSResponse(code, body)
--         if code == 200 then
--             local response = util.JSONToTable(body)
--             if response and response.audio_url then
--                 playTTSUrl(ply, response.audio_url, teamOnly)
--             else
--                 print("Failed to get audio URL from Azure response.")
--             end
--         else
--             print("The HTTP request to Azure TTSURL API failed. HTTP Code: " .. code .. ". Response body: " .. body)
--         end
--     end

--     local function handleTokenResponse(body, len, headers, code)
--         if code == 200 then
--             local azureToken = body
--             local azureVoiceQuality = {
--                 "riff-8khz-8bit-mono-alaw",
--                 "riff-22050hz-16bit-mono-pcm",
--                 "riff-24khz-16bit-mono-pcm",
--                 "riff-44100hz-16bit-mono-pcm",
--                 "riff-48khz-16bit-mono-pcm"
--             }

--             local qualityIndex = TTTBots.Lib.GetConVarInt("chatter_voice_azure_voice_quality")
--             if qualityIndex < 1 or qualityIndex > #azureVoiceQuality then
--                 qualityIndex = 2 -- Default to "audio-16khz-16kbitrate-mono-mp3"
--             end

--             local outputFormat = azureVoiceQuality[qualityIndex]

--             local ssmlBody = string.format(
--                 "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'><voice name='%s'>%s</voice></speak>",
--                 azureVoiceName, text
--             )

--             HTTP({
--                 url = azureTTSEndpoint,
--                 method = "POST",
--                 headers = {
--                     ["Content-Type"] = "application/ssml+xml",
--                     ["Authorization"] = "Bearer " .. azureToken,
--                     ["Connection"] = "Keep-Alive",
--                     ["User-Agent"] = azureResourceGroupName,
--                     ["X-Microsoft-OutputFormat"] = outputFormat,
--                 },
--                 body = ssmlBody,
--                 success = handleTTSResponse,
--                 failed = function(err)
--                     print("HTTP request to Azure TTSURL API failed: " .. err)
--                 end
--             })
--         else
--             print("Failed to receive Azure access token. HTTP Code: " .. code)
--             print("Response body: " .. body)
--         end
--     end

--     http.Post(azureTokenEndpoint, "",
--         handleTokenResponse,
--         function(err)
--             print("HTTP Error: " .. err)
--         end,
--         {
--             ["Ocp-Apim-Subscription-Key"] = azureResourceSpeechAPIKey,
--             ["Content-Length"] = "0"
--         }
--     )
-- end