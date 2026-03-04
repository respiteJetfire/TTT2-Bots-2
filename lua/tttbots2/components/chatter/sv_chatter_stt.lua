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

local function checkTranscriptionsLocal()
    local folderPath  = "transcribed"
    local allFiles    = file.Find(folderPath .. "/*", "DATA")
    local currentTime = os.time()

    for _, fileName in ipairs(allFiles) do
        local steamID, timestamp = fileName:match("user_(%d+)_(%d+).txt")
        if steamID and timestamp then
            local fileTime = tonumber(timestamp)
            if currentTime - fileTime <= timeWindow then
                local textFilePath = folderPath .. "/user_" .. steamID .. "_" .. timestamp .. ".txt"
                if file.Exists(textFilePath, "DATA") then
                    local text = file.Read(textFilePath, "DATA")
                    if text then
                        print("Transcription Detected, Text: ", text)
                        local ply = player.GetBySteamID64(steamID)
                        if IsValid(ply) then
                            local sanitized = sanitizeText(text)
                            BotChatter:RespondToPlayerMessage(ply, sanitized, false, false, true)
                            print("Responding to player voice chat")
                            file.Delete(textFilePath)
                        end
                    end
                end
            end
        end
    end
end

timer.Create("CheckTranscriptionsLocal", checkInterval, 0, checkTranscriptionsLocal)
