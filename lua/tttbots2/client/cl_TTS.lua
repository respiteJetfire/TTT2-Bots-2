local speakingPlayers = {}
local speakingTeamPlayers = {}
local speakingFilePaths = {}

local MAX_SPEAKERS = 2

-- Override VOICE.IsSpeaking so the native TTT2 voice widget picks up bot TTS speakers.
-- The engine ply:IsSpeaking() always returns false for bots (no real mic), so we
-- supplement it with our own speaking tables.
hook.Add("InitPostEntity", "TTTBots_OverrideVOICEIsSpeaking", function()
    local _originalIsSpeaking = VOICE.IsSpeaking
    VOICE.IsSpeaking = function(ply)
        if not ply or ply == LocalPlayer() then
            return LocalPlayer().speaking
        end
        -- Check our bot speaking tables first
        local id = IsValid(ply) and ply:SteamID64()
        if id and (speakingPlayers[id] or speakingTeamPlayers[id]) then
            return true
        end
        -- Fall back to the original (engine ply:IsSpeaking())
        return _originalIsSpeaking(ply)
    end
end)

local function playFileURL(ply, url, teamOnly)
    -- Add player to speakingPlayers table
    local localPlayer = LocalPlayer()
    print("Local player: ", localPlayer)
    local localPlayerTeam = localPlayer and localPlayer:GetTeam()
    print("Local player team: ", localPlayerTeam)
    print("URL: ", url)
    if IsValid(ply) then
        print("ply team: ", ply:GetTeam())
    else
        print("Invalid player entity.")
        return
    end
    local cantPlay = ((teamOnly and (localPlayerTeam ~= ply:GetTeam() or localPlayerTeam == "nones")) or false)
    if cantPlay then
        print("Can't play sound file for player: " .. ply:Nick())
        return
    end

    -- Check if the file is already being played by another player
    for _, player in pairs(speakingPlayers) do
        if player == ply then
            print("File is already being played by player: " .. ply:Nick())
            return
        end
    end

    -- Limit the number of speakers
    if table.Count(speakingPlayers) >= MAX_SPEAKERS then
        print("Max speakers reached. Can't play sound file for player: " .. ply:Nick())
        return
    end

    sound.PlayURL(url, "noplay", function(channel, errID, errStr)
        --- check if ply is alive and not spectating
        if not IsValid(ply) or not ply:Alive() or ply:IsSpec() then
            return
        end
        local ID = ply:SteamID64()
        if IsValid(channel) then
            channel:SetVolume(3)
            channel:Play()
            if not ID then
                print("Player has no SteamID64")
                return
            end
            -- print("Played sound file", url)
            
            local debugChatterVoiceTeamColor = GetConVar("ttt_bot_debug_chatter_voice_team_color")

            if IsValid(localPlayer) and localPlayerTeam ~= nil and ((teamOnly and localPlayerTeam == ply:GetTeam() and localPlayerTeam ~= "nones") or (debugChatterVoiceTeamColor and debugChatterVoiceTeamColor:GetBool())) then
                print("Team only")
                speakingTeamPlayers[ID] = ply
            elseif not teamOnly then
                print("Not team only")
                speakingPlayers[ID] = ply
            end

            if IsValid(ply) then
                -- Set voice mode so the TTT2 widget uses the correct color
                if VOICE and VOICE.SetVoiceMode then
                    local mode = teamOnly and VOICE_MODE_TEAM or VOICE_MODE_GLOBAL
                    VOICE.SetVoiceMode(ply, mode)
                end
                -- Seed lastSteps so spectrum bars animate from the start
                ply.lastSteps = ply.lastSteps or {}
                for i = 1, 24 do
                    ply.lastSteps[i] = ply.lastSteps[i] or 0
                end
                -- Notify TTT2 that this player started voice chat
                hook.Run("PlayerStartVoice", ply)

                -- Drive ply:VoiceVolume() substitute via a timer so GetFakeVoiceSpectrum animates
                timer.Create("BotSpectrumDrive_" .. ID, 0.05, 0, function()
                    if not IsValid(ply) then
                        timer.Remove("BotSpectrumDrive_" .. ID)
                        return
                    end
                    -- Mutate lastSteps directly to keep bars moving
                    ply.lastSteps = ply.lastSteps or {}
                    for i = 1, 24 do
                        local prev = ply.lastSteps[i] or 0
                        local target = math.Clamp(math.sin((CurTime() * 8) + i * 0.4) * 0.5 + 0.5 + math.Rand(-0.1, 0.1), 0, 1)
                        ply.lastSteps[i] = Lerp(0.3, prev, target)
                    end
                end)

                -- print("Started voice for player: " .. ply:Nick())
                timer.Create("VoiceTimer_" .. ID, 0.1, 0, function()
                    if not IsValid(channel) or channel:GetState() ~= GMOD_CHANNEL_PLAYING then
                        if IsValid(ply) then
                            -- print("Ended voice for player: " .. ply:Nick())
                        end
                        timer.Remove("VoiceTimer_" .. ID)
                        timer.Remove("BotSpectrumDrive_" .. ID)
                        -- Remove player from speakingPlayers table
                        if teamOnly then
                            speakingTeamPlayers[ID] = nil
                        else
                            speakingPlayers[ID] = nil
                        end
                        -- Notify TTT2 that voice ended and clean up voice state
                        if IsValid(ply) then
                            hook.Run("PlayerEndVoice", ply)
                            ply.lastSteps = nil
                            if VOICE and VOICE.SetVoiceMode then
                                VOICE.SetVoiceMode(ply, VOICE_MODE_GLOBAL)
                            end
                        end
                    end
                end)
            end
        else
            print("Failed to play sound file: " .. errStr)
        end
    end)
end


local function playFile(ply, path, teamOnly)
    -- Add player to speakingPlayers table
    local localPlayer = LocalPlayer()
    print("Local player: ", localPlayer)
    local localPlayerTeam = localPlayer and localPlayer:GetTeam()
    print("Local player team: ", localPlayerTeam)
    print("ply team: ", ply:GetTeam())
    local cantPlay = ((teamOnly and (localPlayerTeam ~= ply:GetTeam() or localPlayerTeam == "nones")) or false)
    if cantPlay then
        print("Can't play sound file for player: " .. ply:Nick())
        return
    end

    -- Check if the file is already being played by another player
    for _, player in pairs(speakingPlayers) do
        if player == ply then
            print("File is already being played by player: " .. ply:Nick())
            return
        end
    end

    -- Limit the number of speakers
    if table.Count(speakingPlayers) >= MAX_SPEAKERS then
        print("Max speakers reached. Can't play sound file for player: " .. ply:Nick())
        return
    end

    if not speakingFilePaths[path] then
        speakingFilePaths[path] = true
    else
        print("File is already being played")
        return
    end

    sound.PlayFile("data/" .. path, "noplay", function(channel, errID, errStr)
        --- check if ply is alive and not spectating
        if not IsValid(ply) or not ply:Alive() or ply:IsSpec() then
            return
        end
        local ID = ply:SteamID64()
        if IsValid(channel) then
            channel:SetVolume(3)
            channel:Play()
            if not ID then
                print("Player has no SteamID64")
                return
            end
            -- print("Played sound file", path)
            
            local debugChatterVoiceTeamColor = GetConVar("ttt_bot_debug_chatter_voice_team_color")

            if IsValid(localPlayer) and localPlayerTeam ~= nil and ((teamOnly and localPlayerTeam == ply:GetTeam() and localPlayerTeam ~= "nones") or (debugChatterVoiceTeamColor and debugChatterVoiceTeamColor:GetBool())) then
                print("Team only")
                speakingTeamPlayers[ID] = ply
            elseif not teamOnly then
                print("Not team only")
                speakingPlayers[ID] = ply
            end

            if IsValid(ply) then
                -- Set voice mode so the TTT2 widget uses the correct color
                if VOICE and VOICE.SetVoiceMode then
                    local mode = teamOnly and VOICE_MODE_TEAM or VOICE_MODE_GLOBAL
                    VOICE.SetVoiceMode(ply, mode)
                end
                -- Seed lastSteps so spectrum bars animate from the start
                ply.lastSteps = ply.lastSteps or {}
                for i = 1, 24 do
                    ply.lastSteps[i] = ply.lastSteps[i] or 0
                end
                -- Notify TTT2 that this player started voice chat
                hook.Run("PlayerStartVoice", ply)

                -- Drive spectrum animation
                timer.Create("BotSpectrumDrive_" .. ID, 0.05, 0, function()
                    if not IsValid(ply) then
                        timer.Remove("BotSpectrumDrive_" .. ID)
                        return
                    end
                    ply.lastSteps = ply.lastSteps or {}
                    for i = 1, 24 do
                        local prev = ply.lastSteps[i] or 0
                        local target = math.Clamp(math.sin((CurTime() * 8) + i * 0.4) * 0.5 + 0.5 + math.Rand(-0.1, 0.1), 0, 1)
                        ply.lastSteps[i] = Lerp(0.3, prev, target)
                    end
                end)

                -- print("Started voice for player: " .. ply:Nick())
                timer.Create("VoiceTimer_" .. ID, 0.1, 0, function()
                    if not IsValid(channel) or channel:GetState() ~= GMOD_CHANNEL_PLAYING then
                        if IsValid(ply) then
                            -- print("Ended voice for player: " .. ply:Nick())
                        end
                        timer.Remove("VoiceTimer_" .. ID)
                        timer.Remove("BotSpectrumDrive_" .. ID)
                        -- Remove player from speakingPlayers table
                        if teamOnly then
                            speakingTeamPlayers[ID] = nil
                        else
                            speakingPlayers[ID] = nil
                        end

                        speakingFilePaths[path] = nil
                        deleteAllFiles()

                        -- Notify TTT2 that voice ended and clean up voice state
                        if IsValid(ply) then
                            hook.Run("PlayerEndVoice", ply)
                            ply.lastSteps = nil
                            if VOICE and VOICE.SetVoiceMode then
                                VOICE.SetVoiceMode(ply, VOICE_MODE_GLOBAL)
                            end
                        end

                        --- delete the file after playing
                        local fullPath = "data/" .. path
                        timer.Simple(1, function()
                            if file.Exists(fullPath, "DATA") then
                                local success = file.Delete(fullPath)
                                if success then
                                    print("Deleted sound file", fullPath)
                                else
                                    print("Failed to delete sound file: " .. fullPath)
                                end
                            else
                                print("Sound file does not exist: " .. fullPath)
                            end
                        end)
                    end
                end)
            end
        else
            print("Failed to play sound file: " .. errStr)
        end
    end)
end

function deleteAllFiles()
    --- delete all files in the freetts and elevenlabs directories
    local files = file.Find("data/elevenlabs/*", "GAME")
    for _, fileName in pairs(files) do
        print("Deleting file: " .. fileName)
        file.Delete("elevenlabs/" .. fileName)
    end

    files = file.Find("data/freetts/*", "GAME")
    for _, fileName in pairs(files) do
        print("Deleting file: " .. fileName)
        file.Delete("freetts/" .. fileName)
    end
end


-- NOTE: The custom HUDPaint voice popup has been removed.
-- Bot TTS speakers are now displayed via the native TTT2 voice chat widget
-- (pure_skin_voice HUD element) by overriding VOICE.IsSpeaking above.

local function SetFileNameEL(name)
    name = string.lower( name:gsub("[%p%c]", ""):gsub("%s+", "_") )

    if not file.Exists("elevenlabs", "DATA") then
        file.CreateDir("elevenlabs")
    end

    local format = "elevenlabs/%s_%s.wav"
    -- print("Setting file name")

    return string.format(format, os.time(), name)
end

local function SetFileNameFree(name)
    name = string.lower( name:gsub("[%p%c]", ""):gsub("%s+", "_") )

    if not file.Exists("freetts", "DATA") then
        file.CreateDir("freetts")
    end

    local format = "freetts/%s_%s.wav"
    -- print("Setting file name")

    return string.format(format, os.time(), name)
end

net.Receive("SayTTSUrlStart", function()
    print("Received TTS URL data")
    local ply = net.ReadEntity()
    local url = net.ReadString()
    local teamOnly = net.ReadBool()

    local enableTTS = GetConVar("ttt_bot_chatter_enable_tts")
    if enableTTS and not enableTTS:GetBool() then
        print("TTS globally disabled (chatter_enable_tts = 0)")
        return
    end

    playFileURL(ply, url, teamOnly)
end)


local g_file = {}
net.Receive("SayTTSEL", function()
    print("Received TTS data")
    local IsOnePart = net.ReadBool()
    local teamOnly = net.ReadBool()
    local FileID = net.ReadString()
    local ply = net.ReadEntity()

    local enableTTS = GetConVar("ttt_bot_chatter_enable_tts")
    if enableTTS and not enableTTS:GetBool() then
        print("TTS globally disabled (chatter_enable_tts = 0)")
        return
    end

    -- if not IsValid(ply) then
    --     ply = LocalPlayer()
    -- end
    if teamOnly then
        print("Team only")
    end
    if not IsValid(ply) then
        print("Invalid player entity.")
        return
    end
    local localPlayerTeam = LocalPlayer():GetTeam()
    local cantPlay = ((teamOnly and (localPlayerTeam ~= ply:GetTeam() or localPlayerTeam == "nones")) or false)
    if cantPlay then
        print("Can't play sound file for player: " .. ply:Nick())
        return
    end
    -- print("Player: " .. ply:Nick())

    if IsOnePart then
        local FileSize = net.ReadUInt(16)
        local FileContent = util.Decompress(net.ReadData(FileSize))

        g_file[FileID] = FileContent

        local FilePath = SetFileNameEL("voice")
        file.Write(FilePath, FileContent)
        print(FilePath)
        -- print("Playing TTS file")

        playFile(ply, FilePath, teamOnly)
        return
    end

    local FileCurrentPart = net.ReadUInt(16)
    local FileLastPart = net.ReadUInt(16)
    local chunks = net.ReadUInt(16)

    for i = 1, chunks do
        local chunkSize = net.ReadUInt(16)
        local chunkData = net.ReadData(chunkSize)
        g_file[FileID] = g_file[FileID] and g_file[FileID] .. chunkData or chunkData
    end

    if FileCurrentPart == FileLastPart then
        local FileContent = util.Decompress(g_file[FileID])

        local FilePath = SetFileNameEL("voice")
        file.Write(FilePath, FileContent)
        print(FilePath)
        -- print("Playing TTS file")

        playFile(ply, FilePath, teamOnly)
    else
        print("Received TTS data part")
    end
end)

-- net.Receive( "SayTTSBad",  function()
--     -- print("Received Free TTS")
-- 	local text = net.ReadString() -- Read the TTS text from the network
-- 	local ply = net.ReadEntity() -- Read the player entity from the network
--     -- print("Received TTS data for player: " .. ply:Nick())
--     -- Sanitize the text to make it URL-friendly
--     text = string.gsub(text, "[^%w%s]", "") -- Remove non-alphanumeric characters except spaces
--     text = string.sub(string.Replace(text, " ", "%20"), 1, 1000) -- Replace spaces with "%20" and limit the text length to 1000 characters
--     urlparams = {
--         Sam = {
--             pitch = 100,
--             speed = 150
--         },
--         Mike = {
--             pitch = 113,
--             speed = 170
--         },
--         Mary = {
--             pitch = 169,
--             speed = 170
--         }
--     }
--     --- get a random voice from the urlparams table
--     local keys = {}
--     for k in pairs(urlparams) do
--         table.insert(keys, k)
--     end
--     local randomKey = keys[math.random(1, #keys)]
--     local voice = urlparams[randomKey]
--     -- print("voice: " .. randomKey)
--     url = "https://tetyys.com/SAPI4/SAPI4?voice=" .. randomKey .. "&pitch=" .. voice.pitch .. "&speed=" .. voice.speed .. "&text=" .. text
	
--     -- Play the TTS sound using the provided URL
--     sound.PlayURL(url, "", function(sound)
--         if IsValid(sound) then
--             -- print("received sound from url: " .. url)
--             sound:SetVolume(2) -- Set the sound volume to maximum
--             sound:Play() -- Play the sound
--         else
--             print("Failed to play sound from URL: " .. url)
--         end
--     end)
-- end)

net.Receive("SayTTSBad", function()
    print("Received Free TTS data")
    local IsOnePart = net.ReadBool()
    local teamOnly = net.ReadBool()
    local FileID = net.ReadString()
    local ply = net.ReadEntity()

    local enableTTS = GetConVar("ttt_bot_chatter_enable_tts")
    if enableTTS and not enableTTS:GetBool() then
        print("TTS globally disabled (chatter_enable_tts = 0)")
        return
    end

    -- if not IsValid(ply) then
    --     ply = LocalPlayer()
    -- end
    if teamOnly then
        print("Team only")
    end
    if not IsValid(ply) then
        print("Invalid player entity.")
        return
    end
    local localPlayerTeam = LocalPlayer():GetTeam()
    local cantPlay = ((teamOnly and (localPlayerTeam ~= ply:GetTeam() or localPlayerTeam == "nones")) or false)
    if cantPlay then
        print("Can't play sound file for player: " .. ply:Nick())
        return
    end

    if IsOnePart then
        local FileSize = net.ReadUInt(16)
        local FileContent = util.Decompress(net.ReadData(FileSize))

        g_file[FileID] = FileContent

        local FilePath = SetFileNameFree("voice")
        file.Write(FilePath, FileContent)
        print(FilePath)
        -- print("Playing TTS file")

        playFile(ply, FilePath, teamOnly)
        return
    end

    local FileCurrentPart = net.ReadUInt(16)
    local FileLastPart = net.ReadUInt(16)
    local chunks = net.ReadUInt(16)

    for i = 1, chunks do
        local chunkSize = net.ReadUInt(16)
        local chunkData = net.ReadData(chunkSize)
        g_file[FileID] = g_file[FileID] and g_file[FileID] .. chunkData or chunkData
    end

    if FileCurrentPart == FileLastPart then
        local FileContent = util.Decompress(g_file[FileID])

        local FilePath = SetFileNameFree("voice")
        file.Write(FilePath, FileContent)
        print(FilePath)
        -- print("Playing TTS file")

        playFile(ply, FilePath, teamOnly)
    else
        print("Received TTS data part")
    end
end)