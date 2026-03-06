--- sv_chatter_stt.lua
--- Local Speech-to-Text polling: watches the data/transcribed/ folder for
--- freshly written transcript files and routes them through RespondToPlayerMessage.
--- Depends on: sv_chatter_commands.lua (BotChatter:RespondToPlayerMessage)

local BotChatter = TTTBots.Components.Chatter

-- ---------------------------------------------------------------------------
-- Local transcript polling
-- ---------------------------------------------------------------------------

local function sanitizeText(text)
    text = string.gsub(text, "[^%w%s]", "") -- keep only alphanumeric + spaces
    text = string.lower(text)
    text = string.gsub(text, "%s+", " ")    -- collapse multiple spaces
    return text
end

local timeWindow    = 60    -- seconds; ignore files older than this
local checkInterval = 0.5   -- polling interval in seconds
local heartbeatInterval = 30 -- log a heartbeat every N seconds to confirm the timer is alive
local lastHeartbeat = 0

local function checkTranscriptionsLocal()
    local folderPath  = "transcribed"
    local allFiles    = file.Find(folderPath .. "/*", "DATA")
    local currentTime = os.time()

    -- Periodic heartbeat so you can confirm the timer is running
    if currentTime - lastHeartbeat >= heartbeatInterval then
        lastHeartbeat = currentTime
        print(string.format("[TTTBots STT] Polling '%s/' — found %d file(s)", folderPath, #allFiles))
    end

    for _, fileName in ipairs(allFiles) do
        local steamID, timestamp = fileName:match("user_(%d+)_(%d+).txt")
        if steamID and timestamp then
            local fileTime = tonumber(timestamp)
            local age = currentTime - fileTime
            if age <= timeWindow then
                local textFilePath = folderPath .. "/user_" .. steamID .. "_" .. timestamp .. ".txt"
                if file.Exists(textFilePath, "DATA") then
                    local text = file.Read(textFilePath, "DATA")
                    if text and text ~= "" then
                        print(string.format("[TTTBots STT] Transcript found: %s (age=%ds) text='%s'", fileName, age, text:sub(1, 80)))
                        local ply = player.GetBySteamID64(steamID)
                        if IsValid(ply) then
                            local sanitized = sanitizeText(text)
                            print(string.format("[TTTBots STT] Routing to RespondToPlayerMessage: player='%s' sanitized='%s'", ply:Nick(), sanitized))
                            BotChatter:RespondToPlayerMessage(ply, sanitized, false, false, true)
                            file.Delete(textFilePath)
                            print(string.format("[TTTBots STT] Deleted transcript: %s", textFilePath))
                        else
                            print(string.format("[TTTBots STT] WARNING: No valid player found for SteamID64=%s — deleting stale transcript", steamID))
                            file.Delete(textFilePath)
                        end
                    else
                        print(string.format("[TTTBots STT] WARNING: Empty transcript file %s — deleting", fileName))
                        file.Delete(textFilePath)
                    end
                end
            else
                print(string.format("[TTTBots STT] WARNING: Stale transcript ignored (age=%ds > window=%ds): %s", age, timeWindow, fileName))
                local textFilePath = folderPath .. "/user_" .. steamID .. "_" .. timestamp .. ".txt"
                file.Delete(textFilePath)
            end
        end
    end
end

print("[TTTBots STT] Starting transcript polling timer (interval=" .. checkInterval .. "s, window=" .. timeWindow .. "s)")
timer.Create("CheckTranscriptionsLocal", checkInterval, 0, checkTranscriptionsLocal)
