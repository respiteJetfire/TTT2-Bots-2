TTTBots.TTS = TTTBots.TTS or {}
TTTBots.TTS.Cache = {}

local lib = TTTBots.Lib

local function handleTTSResponse(code, body, chatter, teamOnly, ply, text, ssmlBody, onVoiceComplete)
    if code == 200 then
        local FileContent = util.Compress(body)
        local FileSize = #FileContent
        local FileID = os.time()
        local FileMaxSize = 63000

        local duration = 5
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
                chatter:WriteDataFree(teamOnly, ply, false, FileID, TTTBots.TTS.Cache[FileID][FilePos], FilePos, FileParts)
            end)
        else
            chatter:WriteDataFree(teamOnly, ply, true, FileID, FileContent)
        end

        if onVoiceComplete then
            onVoiceComplete(duration)
        end
        TTTBots.Match.speakingBot = nil -- Clear speakingBot after completion
    else
        print("The HTTP request to TTS API failed. HTTP Code: " .. code .. ". Response body: " .. body)
        if ssmlBody then
            print("SSML Body: " .. ssmlBody) -- Print the SSML body for debugging
        end
        chatter:Say(text, teamOnly)
        if onVoiceComplete then
            onVoiceComplete(1)
        end
        TTTBots.Match.speakingBot = nil -- Clear speakingBot after failure
    end
end

local function sendTTSRequest(url, headers, body, chatter, teamOnly, ply, text, ssmlBody, onVoiceComplete)
    HTTP({
        url = url,
        method = "POST",
        headers = headers,
        body = body,
        success = function(code, body) handleTTSResponse(code, body, chatter, teamOnly, ply, text, ssmlBody, onVoiceComplete) end,
        failed = function(err)
            print("HTTP request to TTS API failed: " .. err)
            chatter:Say(text, teamOnly)
            if onVoiceComplete then
                onVoiceComplete(1)
            end
            TTTBots.Match.speakingBot = nil -- Clear speakingBot after failure
        end
    })
end

function TTTBots.TTS.FreeTTSSendRequest(bot, text, teamOnly, onVoiceComplete)
    local fulltxt = text
    text = string.gsub(text, "[^%w%s]", "") -- Remove non-alphanumeric characters except spaces
    text = string.sub(string.Replace(text, " ", "%20"), 1, 1000) -- Replace spaces with "%20" and limit the text length to 1000 characters
    local personality = bot:BotPersonality()
    local chatter = bot:BotChatter()
    local voice = personality.voice
    local teamOnly = teamOnly or false

    local url = "https://tetyys.com/SAPI4/SAPI4?voice=" .. voice.name .. "&pitch=" .. voice.pitch .. "&speed=" .. voice.speed .. "&text=" .. text

    HTTP({
        url = url,
        method = "GET",
        success = function(code, body)
            handleTTSResponse(code, body, chatter, teamOnly, bot, fulltxt, nil, onVoiceComplete)
        end,
        failed = function(err)
            print("HTTP request to fetch TTS audio failed: " .. err)
            chatter:Say(fulltxt, teamOnly)
            if onVoiceComplete then
                onVoiceComplete(1)
            end
            TTTBots.Match.speakingBot = nil -- Clear speakingBot after failure
        end
    })
end

function TTTBots.TTS.ElevenLabsSendRequest(ply, text, teamOnly, onVoiceComplete)
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

    local url = 'https://api.elevenlabs.io/v1/text-to-speech/' .. voiceID
    local headers = {
        ['Content-Type'] = 'application/json',
        ['xi-api-key'] = TTTBots.Lib.GetConVarString("chatter_voice_elevenlabs_api_key")
    }

    sendTTSRequest(url, headers, jsonBody, chatter, teamOnly, ply, text, nil, function(duration)
        if onVoiceComplete then
            onVoiceComplete(duration)
        end
        TTTBots.Match.speakingBot = nil -- Clear speakingBot after completion
    end)
end

local function handleTokenResponse(body, len, headers, code, azureTTSEndpoint, azureResourceGroupName, azureVoiceName, text, chatter, teamOnly, ply, onVoiceComplete)
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

        text = string.gsub(text, "[^%w%s]", "") -- Sanitize the text to remove all non-alphanumeric characters except spaces

        local ssmlBody = string.format(
            "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'><voice name='%s'>%s</voice></speak>",
            azureVoiceName, text
        )

        local headers = {
            ["Content-Type"] = "application/ssml+xml",
            ["Authorization"] = "Bearer " .. azureToken,
            ["Connection"] = "Keep-Alive",
            ["User-Agent"] = azureResourceGroupName,
            ["X-Microsoft-OutputFormat"] = outputFormat,
        }

        sendTTSRequest(azureTTSEndpoint, headers, ssmlBody, chatter, teamOnly, ply, text, ssmlBody, onVoiceComplete)
    else
        print("Failed to receive Azure access token. HTTP Code: " .. code)
        print("Response body: " .. body)
    end
end

function TTTBots.TTS.AzureTTSSendRequest(ply, text, teamOnly, onVoiceComplete)
    local azureRegion = TTTBots.Lib.GetConVarString("chatter_voice_azure_region")
    local azureResourceGroupName = TTTBots.Lib.GetConVarString("chatter_voice_azure_resource_name")
    local azureResourceSpeechAPIKey = TTTBots.Lib.GetConVarString("chatter_voice_azure_resource_api_key")
    local azureVoiceName = ply:BotPersonality().voice.id
    local chatter = ply:BotChatter()
    local azureTokenEndpoint = "https://" .. azureRegion .. ".api.cognitive.microsoft.com/sts/v1.0/issuetoken"
    local azureTTSEndpoint = "https://" .. azureRegion .. ".tts.speech.microsoft.com/cognitiveservices/v1"

    http.Post(azureTokenEndpoint, "",
        function(body, len, headers, code)
            handleTokenResponse(body, len, headers, code, azureTTSEndpoint, azureResourceGroupName, azureVoiceName, text, chatter, teamOnly, ply, function(duration)
                if onVoiceComplete then
                    onVoiceComplete(duration)
                end
                TTTBots.Match.speakingBot = nil -- Clear speakingBot after completion
            end)
        end,
        function(err)
            print("HTTP Error: " .. err)
            if onVoiceComplete then
                onVoiceComplete(1)
            end
            TTTBots.Match.speakingBot = nil -- Clear speakingBot after failure
        end,
        {
            ["Ocp-Apim-Subscription-Key"] = azureResourceSpeechAPIKey,
            ["Content-Length"] = "0"
        }
    )
end

-- ---------------------------------------------------------------------------
-- SendVoice — envelope-based entry point for the Providers adapter layer
-- ---------------------------------------------------------------------------

--- Dispatches voice synthesis via the appropriate TTS backend (binary mode).
--- opts = { teamOnly=bool }
--- callback(envelope) where envelope is MakeOk("TTS", duration) or MakeError("TTS", ...).
---@param bot Player
---@param text string
---@param opts table
---@param callback function
function TTTBots.TTS.SendVoice(bot, text, opts, callback)
    opts = opts or {}
    local teamOnly = opts.teamOnly or false

    local personality = bot:BotPersonality()
    local voiceType = personality and personality.voice and personality.voice.type or "free"

    local function wrappedComplete(duration)
        if callback then
            callback(TTTBots.Providers.MakeOk("TTS", duration or 1))
        end
    end

    local function wrappedError(err)
        if callback then
            callback(TTTBots.Providers.MakeError("TTS", 0, tostring(err), nil))
        end
    end

    if voiceType == "elevenlabs" then
        TTTBots.TTS.ElevenLabsSendRequest(bot, text, teamOnly, wrappedComplete)
    elseif voiceType == "Azure" then
        TTTBots.TTS.AzureTTSSendRequest(bot, text, teamOnly, wrappedComplete)
    else
        TTTBots.TTS.FreeTTSSendRequest(bot, text, teamOnly, wrappedComplete)
    end
end