TTTBots.TTS = TTTBots.TTS or {}
TTTBots.TTS.Cache = {}

local lib = TTTBots.Lib

function TTTBots.TTS.FreeTTSSendRequest(bot, text, teamOnly)
    -- Sanitize the text to make it URL-friendly
    local fulltxt = text
    text = string.gsub(text, "[^%w%s]", "") -- Remove non-alphanumeric characters except spaces
    text = string.sub(string.Replace(text, " ", "%20"), 1, 1000) -- Replace spaces with "%20" and limit the text length to 1000 characters
    --- get the bot's personality
    local personality = bot:BotPersonality()
    local chatter = bot:BotChatter()
    local voice = personality.voice
    local teamOnly = teamOnly or false

    local url = "https://tetyys.com/SAPI4/SAPI4?voice=" .. voice.name .. "&pitch=" .. voice.pitch .. "&speed=" .. voice.speed .. "&text=" .. text

    -- Make an HTTP request to fetch the TTS audio
    HTTP({
        url = url,
        method = "GET",
        success = function(code, body)
            if code == 200 then
                local FileContent = util.Compress(body)
                local FileSize = #FileContent
                local FileID = os.time()
                local FileMaxSize = 63000

                if FileSize > FileMaxSize then
                    local FileParts = math.ceil(FileSize / FileMaxSize)
                    local FileTable = {}

                    for i = 1, FileParts - 1 do
                        local IndexStart = (i - 1) * FileMaxSize + 1
                        local IndexEnd = i * FileMaxSize
                        local FileData = string.sub(FileContent, IndexStart, IndexEnd)

                        FileTable[i] = FileData
                    end

                    local IndexStart = (FileParts - 1) * FileMaxSize + 1
                    local FileData = string.sub(FileContent, IndexStart)
                    FileTable[FileParts] = FileData

                    TTTBots.TTS.Cache[FileID] = FileTable
                    TTTBots.TTS.Cache[FileID .. "_pos"] = 0

                    timer.Create("tts_send_" .. FileID, 1 / 20, #TTTBots.TTS.Cache[FileID], function()
                        local FilePos = TTTBots.TTS.Cache[FileID .. "_pos"] + 1
                        TTTBots.TTS.Cache[FileID .. "_pos"] = FilePos
                        chatter:WriteDataFree(teamOnly, bot, false, FileID, TTTBots.TTS.Cache[FileID][FilePos], FilePos, FileParts)
                    end)
                else
                    chatter:WriteDataFree(teamOnly, bot, true, FileID, FileContent)
                end
            else
                print("The HTTP request to fetch TTS audio failed. HTTP Code: " .. code .. ". Response body: " .. body)
                chatter:Say(fulltxt, teamOnly)
            end
        end,
        failed = function(err)
            print("HTTP request to fetch TTS audio failed: " .. err)
        end
    })
end

function TTTBots.TTS.ElevenLabsSendRequest(ply, text, teamOnly)
    -- print("Received TTS text: " .. text)
    -- if IsValid(ply) then
    --     print("Player: " .. ply:Nick())
    -- else
    --     print("Invalid player entity.")
    -- end
    local personality = ply:BotPersonality()
    local chatter = ply:BotChatter()
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
        model_id = model_id,
        voice_settings = {
            stability = 0.8,
            similarity_boost = 1.0
        },
    })

    -- print("JSON Body: " .. jsonBody)

    -- Make an HTTP request to ElevenLabs API to get the TTS audio
    HTTP({
        url = 'https://api.elevenlabs.io/v1/text-to-speech/' .. voiceID, -- Replace <voice-id> with the desired voice ID
        type = 'application/json',
        method = 'post',
        headers = {
            ['Content-Type'] = 'application/json',
            ['xi-api-key'] = TTTBots.Lib.GetConVarString("chatter_voice_elevenlabs_api_key") -- Replace with your ElevenLabs API key
        },
        body = jsonBody,
        success = function(code, body)
            if code == 200 then
                print("Received TTS audio from ElevenLabs API.")

                local FileContent = util.Compress(body)
                local FileSize = #FileContent
                local FileID = os.time()
                local FileMaxSize = 63000

                if FileSize > FileMaxSize then
                    local FileParts = math.ceil(FileSize / FileMaxSize)
                    local FileTable = {}

                    for i = 1, FileParts - 1 do
                        local IndexStart = (i - 1) * FileMaxSize + 1
                        local IndexEnd = i * FileMaxSize
                        local FileData = string.sub(FileContent, IndexStart, IndexEnd)

                        FileTable[i] = FileData
                    end

                    local IndexStart = (FileParts - 1) * FileMaxSize + 1
                    local FileData = string.sub(FileContent, IndexStart)
                    FileTable[FileParts] = FileData

                    TTTBots.TTS.Cache[FileID] = FileTable
                    TTTBots.TTS.Cache[FileID .. "_pos"] = 0

                    timer.Create("elevenlabs_send_" .. FileID, 1 / 20, #TTTBots.TTS.Cache[FileID], function()
                        local FilePos = TTTBots.TTS.Cache[FileID .. "_pos"] + 1
                        TTTBots.TTS.Cache[FileID .. "_pos"] = FilePos
                        chatter:WriteDataEL(teamOnly, ply, false, FileID, TTTBots.TTS.Cache[FileID][FilePos], FilePos, FileParts)
                    end)
                else
                    chatter:WriteDataEL(teamOnly, ply, true, FileID, FileContent)
                end
            else
                print("The HTTP request to ElevenLabs API failed. HTTP Code: " .. code)
                print("Body: " .. body)
            end
        end,
        failed = function(err)
            print("HTTP request to ElevenLabs API failed: " .. err)
            chatter:Say(text, teamOnly)
        end
    })
end

local function handleTTSResponse(code, body, chatter, teamOnly, ply, text, ssmlBody)
    if code == 200 then
        local FileContent = util.Compress(body)
        local FileSize = #FileContent
        local FileID = os.time()
        local FileMaxSize = 63000

        if FileSize > FileMaxSize then
            local FileParts = math.ceil(FileSize / FileMaxSize)
            local FileTable = {}

            for i = 1, FileParts - 1 do
                local IndexStart = (i - 1) * FileMaxSize + 1
                local IndexEnd = i * FileMaxSize
                local FileData = string.sub(FileContent, IndexStart, IndexEnd)
                FileTable[i] = FileData
            end

            local IndexStart = (FileParts - 1) * FileMaxSize + 1
            local FileData = string.sub(FileContent, IndexStart)
            FileTable[FileParts] = FileData

            TTTBots.TTS.Cache[FileID] = FileTable
            TTTBots.TTS.Cache[FileID .. "_pos"] = 0

            timer.Create("azure_send_" .. FileID, 1 / 20, #TTTBots.TTS.Cache[FileID], function()
                local FilePos = TTTBots.TTS.Cache[FileID .. "_pos"] + 1
                TTTBots.TTS.Cache[FileID .. "_pos"] = FilePos
                chatter:WriteDataFree(teamOnly, ply, false, FileID, TTTBots.TTS.Cache[FileID][FilePos], FilePos, FileParts)
            end)
        else
            chatter:WriteDataFree(teamOnly, ply, true, FileID, FileContent)
        end
    else
        print("The HTTP request to Azure TTS API failed. HTTP Code: " .. code .. ". Response body: " .. body)
        local response = util.JSONToTable(body)
        if response and response.error and response.error.message then
            print("Azure API Error: " .. response.error.message)
        end
        print("SSML Body: " .. ssmlBody) -- Print the SSML body for debugging
        chatter:Say(text, teamOnly)
    end
end

local function handleTokenResponse(body, len, headers, code, azureTTSEndpoint, azureResourceGroupName, azureVoiceName, text, chatter, teamOnly, ply)
    if code == 200 then
        local azureToken = body
        local azureVoiceQuality = {
            "riff-8khz-8bit-mono-alaw",
            "riff-22050hz-16bit-mono-pcm",
            "riff-24khz-16bit-mono-pcm",
            "riff-44100hz-16bit-mono-pcm",
            "riff-48khz-16bit-mono-pcm"
        }

        local qualityIndex = TTTBots.Lib.GetConVarInt("chatter_voice_azure_voice_quality")
        if qualityIndex < 1 or qualityIndex > #azureVoiceQuality then
            qualityIndex = 2 -- Default to "audio-16khz-16kbitrate-mono-mp3"
        end

        local outputFormat = azureVoiceQuality[qualityIndex]

        -- Sanitize the text to remove all non-alphanumeric characters except spaces
        text = string.gsub(text, "[^%w%s]", "")

        -- Prepare the SSML request body
        local ssmlBody = string.format(
            "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'><voice name='%s'>%s</voice></speak>",
            azureVoiceName, text
        )

        -- Make an HTTP request to Azure TTS API to get the TTS audio
        HTTP({
            url = azureTTSEndpoint,
            method = "POST",
            headers = {
                ["Content-Type"] = "application/ssml+xml",
                ["Authorization"] = "Bearer " .. azureToken,
                ["Connection"] = "Keep-Alive",
                ["User-Agent"] = azureResourceGroupName,
                ["X-Microsoft-OutputFormat"] = outputFormat,
            },
            body = ssmlBody,
            success = function(code, body) handleTTSResponse(code, body, chatter, teamOnly, ply, text, ssmlBody) end,
        })
    else
        print("Failed to receive Azure access token. HTTP Code: " .. code)
        print("Response body: " .. body)
    end
end

function TTTBots.TTS.AzureTTSSendRequest(ply, text, teamOnly)
    --- Send a request to Microsoft Azure Text-to-Speech API to get the TTS audio
    local azureRegion = TTTBots.Lib.GetConVarString("chatter_voice_azure_region")
    local azureResourceGroupName = TTTBots.Lib.GetConVarString("chatter_voice_azure_resource_name")
    local azureResourceSpeechAPIKey = TTTBots.Lib.GetConVarString("chatter_voice_azure_resource_api_key")
    local azureVoiceName = ply:BotPersonality().voice.id
    print("Azure Voice Name: " .. azureVoiceName)
    local chatter = ply:BotChatter()
    local azureTokenEndpoint = "https://" .. azureRegion .. ".api.cognitive.microsoft.com/sts/v1.0/issuetoken"
    local azureTTSEndpoint = "https://" .. azureRegion .. ".tts.speech.microsoft.com/cognitiveservices/v1"

    -- Get Azure access token
    http.Post(azureTokenEndpoint, "",
        function(body, len, headers, code)
            handleTokenResponse(body, len, headers, code, azureTTSEndpoint, azureResourceGroupName, azureVoiceName, text, chatter, teamOnly, ply)
        end,
        function(err)
            print("HTTP Error: " .. err)
        end,
        {
            ["Ocp-Apim-Subscription-Key"] = azureResourceSpeechAPIKey,
            ["Content-Length"] = "0"
        }
    )
end