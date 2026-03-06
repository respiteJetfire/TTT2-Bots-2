util.AddNetworkString("SayTTSUrlStart")

TTTBots.TTSURL = TTTBots.TTSURL or {}
TTTBots.TTSURL.Cache = {}

local lib = TTTBots.Lib

local function playTTSUrl(ply, url, teamOnly, duration)
    net.Start("SayTTSUrlStart")
    net.WriteEntity(ply)
    net.WriteString(url)
    net.WriteBool(teamOnly)
    net.WriteFloat(duration)
    net.Broadcast()
    TTTBots.Match.speakingBot = nil -- Clear speakingBot after completion
end

local function TableToQueryString(tbl)
    local queryString = ""
    for key, value in pairs(tbl) do
        queryString = queryString .. key .. "=" .. tostring(value) .. "&"
    end
    return string.sub(queryString, 1, -2) -- Remove the trailing '&'
end

function TTTBots.TTSURL.FreeTTSSendRequest(bot, text, teamOnly, onVoiceComplete)
    -- Sanitize the text to make it URL-friendly
    -- print("Sending to FreeTTS: " .. text)
    local fulltxt = text
    text = string.gsub(text, "[^%w%s']", "") -- Remove non-alphanumeric characters except spaces and single quotes
    text = string.sub(string.Replace(text, " ", "%20"), 1, 1000) -- Replace spaces with "%20" and limit the text length to 1000 characters
    --- get the bot's personality
    local personality = bot:BotPersonality()
    local voice = personality.voice
    local teamOnly = teamOnly or false

    local url = "https://tetyys.com/SAPI4/SAPI4?voice=" .. voice.name .. "&pitch=" .. voice.pitch .. "&speed=" .. voice.speed .. "&text=" .. text

    -- Play the TTSURL audio directly from the URL
    playTTSUrl(bot, url, teamOnly, 0) -- Duration is not available for FreeTTS
    if onVoiceComplete then
        onVoiceComplete(0)
    end
    TTTBots.Match.speakingBot = nil -- Clear speakingBot after completion
end

function TTTBots.TTSURL.ElevenLabsSendRequest(ply, text, teamOnly, onVoiceComplete)
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

    text = string.gsub(text, "[^%w%s']", "") -- Remove non-alphanumeric characters except spaces and single quotes

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
                    if response.download_url and response.duration then
                        local downloadURL = url .. response.download_url
                        playTTSUrl(ply, downloadURL, teamOnly, response.duration)
                        if onVoiceComplete then
                            onVoiceComplete(response.duration)
                        end
                        TTTBots.Match.speakingBot = nil -- Clear speakingBot after completion
                    else
                        print("Failed to get download URL or duration from ElevenLabs response.")
                    end
                else
                    print("Failed to parse ElevenLabs response.")
                end
            else
                print("The HTTP request to ElevenLabs API failed. HTTP Code: " .. code)
                print("Body: " .. body)
                if onVoiceComplete then
                    onVoiceComplete(1)
                end
                TTTBots.Match.speakingBot = nil -- Clear speakingBot after failure
            end
        end,
        failed = function(err)
            print("HTTP request to ElevenLabs API failed: " .. err)
            if onVoiceComplete then
                onVoiceComplete(1)
            end
            TTTBots.Match.speakingBot = nil -- Clear speakingBot after failure
        end
    })
end

function TTTBots.TTSURL.AzureSendRequest(ply, text, teamOnly, onVoiceComplete)
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
                if response and response.download_url and response.duration then
                    local downloadURL = url .. response.download_url
                    playTTSUrl(ply, downloadURL, teamOnly, response.duration)
                    if onVoiceComplete then
                        onVoiceComplete(response.duration)
                    end
                    TTTBots.Match.speakingBot = nil -- Clear speakingBot after completion
                else
                    print("Failed to get download URL or duration from Azure response.")
                end
            else
                print("The HTTP request to Azure API failed. HTTP Code: " .. code)
                print("Body: " .. body)
                if onVoiceComplete then
                    onVoiceComplete(1)
                end
                TTTBots.Match.speakingBot = nil -- Clear speakingBot after failure
            end
        end,
        failed = function(err)
            print("HTTP request to Azure API failed: " .. err)
            if onVoiceComplete then
                onVoiceComplete(1)
            end
            TTTBots.Match.speakingBot = nil -- Clear speakingBot after failure
        end
    })
end

function TTTBots.TTSURL.LocalTTSSendRequest(bot, text, teamOnly, onVoiceComplete)
    -- 1. Resolve URL (CVar override → TTSAPI global → hardcoded fallback)
    local cvarURL = TTTBots.Lib.GetConVarString("chatter_voice_local_tts_url")
    local url = (cvarURL and cvarURL ~= "") and cvarURL
        or (TTSAPI and TTSAPI.LocalTTSURL)
        or "http://ttsapi:80/local"

    -- 2. Get voice config from personality
    local personality = bot:BotPersonality()
    local voiceName = (personality and personality.voice and personality.voice.piperVoice)
        or (TTSAPI and TTSAPI.DefaultVoice)
        or "en_US-lessac-medium"
    local speed = (personality and personality.voice and personality.voice.speed) or 1.0

    -- 3. Build JSON request body
    local body = util.TableToJSON({
        text = text,
        voice = voiceName,
        speed = speed,
    })

    -- 4. POST to /local
    HTTP({
        url = url,
        method = "POST",
        headers = { ["Content-Type"] = "application/json" },
        body = body,
        type = "application/json",
        success = function(code, responseBody, headers)
            if code ~= 200 then
                print("[TTTBots] Local TTS request failed. HTTP " .. code .. ": " .. (responseBody or ""))
                if onVoiceComplete then onVoiceComplete(1) end
                TTTBots.Match.speakingBot = nil
                return
            end

            local data = util.JSONToTable(responseBody)
            if not data or not data.download_url then
                print("[TTTBots] Local TTS: invalid response (no download_url)")
                if onVoiceComplete then onVoiceComplete(1) end
                TTTBots.Match.speakingBot = nil
                return
            end

            -- Build the client-accessible download URL.
            -- The POST was sent to the internal URL (url), but the download_url must be
            -- reachable by game clients. If chatter_voice_local_tts_url is a public-facing
            -- address (e.g. http://192.168.1.10:8080), rewrite the base accordingly.
            -- This is Option B: public URL override → URL mode works.
            -- Without an override the URL would still be Docker-internal, so sv_providers.lua
            -- will have already forced binary mode before we ever reach this path.
            local ttsapiRoot = string.gsub(url, "/local$", "")
            local fullUrl = ttsapiRoot .. data.download_url

            -- Estimate duration: ~80ms per character at normal speed
            local duration = math.max(2, #text * 0.08 / speed)

            playTTSUrl(bot, fullUrl, teamOnly, duration)
            if onVoiceComplete then onVoiceComplete(duration) end
            TTTBots.Match.speakingBot = nil
        end,
        failed = function(reason)
            print("[TTTBots] Local TTS HTTP failed: " .. tostring(reason))
            if onVoiceComplete then onVoiceComplete(1) end
            TTTBots.Match.speakingBot = nil
        end,
    })
end

-- ---------------------------------------------------------------------------
-- SendVoice — envelope-based entry point for the Providers adapter layer
-- ---------------------------------------------------------------------------

--- Dispatches voice synthesis via the appropriate TTS backend (URL mode).
--- opts = { teamOnly=bool }
--- callback(envelope) where envelope is MakeOk("TTSURL", duration) or MakeError("TTSURL", ...).
---@param bot Player
---@param text string
---@param opts table
---@param callback function
function TTTBots.TTSURL.SendVoice(bot, text, opts, callback)
    opts = opts or {}
    local teamOnly = opts.teamOnly or false

    local personality = bot:BotPersonality()
    local voiceType = personality and personality.voice and personality.voice.type or "free"

    local function wrappedComplete(duration)
        if callback then
            callback(TTTBots.Providers.MakeOk("TTSURL", duration or 0))
        end
    end

    local function wrappedError(err)
        if callback then
            callback(TTTBots.Providers.MakeError("TTSURL", 0, tostring(err), nil))
        end
    end

    if voiceType == "elevenlabs" then
        TTTBots.TTSURL.ElevenLabsSendRequest(bot, text, teamOnly, wrappedComplete)
    elseif voiceType == "Azure" then
        TTTBots.TTSURL.AzureSendRequest(bot, text, teamOnly, wrappedComplete)
    elseif voiceType == "local" then
        TTTBots.TTSURL.LocalTTSSendRequest(bot, text, teamOnly, wrappedComplete)
    else
        TTTBots.TTSURL.FreeTTSSendRequest(bot, text, teamOnly, wrappedComplete)
    end
end