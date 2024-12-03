local speakingPlayers = {}
local speakingTeamPlayers = {}
local speakingFilePaths = {}

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
                -- print("Started voice for player: " .. ply:Nick())
                timer.Create("VoiceTimer_" .. ID, 0.1, 0, function()
                    if not IsValid(channel) or channel:GetState() ~= GMOD_CHANNEL_PLAYING then
                        if IsValid(ply) then
                            -- print("Ended voice for player: " .. ply:Nick())
                        end
                        timer.Remove("VoiceTimer_" .. ID)
                        -- Remove player from speakingPlayers table
                        if teamOnly then
                            speakingTeamPlayers[ID] = nil
                        else
                            speakingPlayers[ID] = nil
                        end

                        speakingFilePaths[path] = nil
                        deleteAllFiles()

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


hook.Add("HUDPaint", "DrawVoiceChatPopup", function()
    local yOffset = 0
    for steamID, ply in pairs(speakingPlayers) do
        if IsValid(ply) then
            local x, y = 50, 50 + yOffset -- Position of the popup
            draw.RoundedBox(8, x, y, 400, 50, Color(0, 100, 0, 150)) -- Dark green box
            draw.SimpleText(ply:Nick() .. " is speaking", "Trebuchet24", x + 10, y + 10, Color(255, 255, 255, 255)) -- White text
            yOffset = yOffset + 60 -- Increase yOffset for the next player
        end
    end

    -- Store the yOffset for team voice chat prompts
    local teamYOffset = yOffset

    for steamID, ply in pairs(speakingTeamPlayers) do
        if IsValid(ply) then
            local x, y = 50, 50 + teamYOffset -- Position of the popup below speakingPlayers
            local teamColor = ply:GetRoleColor() or Color(0, 100, 0, 150) -- Default color is dark green
            draw.RoundedBox(8, x, y, 400, 50, teamColor) -- Box for the player's team color
            draw.SimpleText(ply:Nick() .. " is speaking", "Trebuchet24", x + 10, y + 10, Color(255, 255, 255, 255)) -- White text
            teamYOffset = teamYOffset + 60 -- Increase yOffset for the next player
        end
    end
end)

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


local g_file = {}
net.Receive("SayTTSEL", function()
    print("Received TTS data")
    local IsOnePart = net.ReadBool()
    local teamOnly = net.ReadBool()
    local FileID = net.ReadString()
    local ply = net.ReadEntity()

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