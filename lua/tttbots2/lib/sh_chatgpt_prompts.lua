TTTBots.ChatGPTPrompts = {}

function TTTBots.ChatGPTPrompts.GetChatGPTPromptResponse(bot, text, teamOnly, ply)
    local personality = bot:BotPersonality()
    local nickname = bot:Nick() or "Unknown"
    local role = bot:GetRoleStringRaw() or "innocent"
    local archetype = personality.archetype or "Default"
    local behaviorDesc = bot.lastBehavior and bot.lastBehavior.Description or "playing the game"
    local numWords = math.random(4, 7) -- Reduced word count for more concise responses
    local plyName = IsValid(ply) and ply:Nick() or "someone"
    local plyRole = IsValid(ply) and ply:GetRoleStringRaw() or "unknown"
    local usesSuspicion = bot:BotMorality() and true or false
    --- is the target in bot:BotMorality().roleGuesses or not
    local isRoleGuess = usesSuspicion and bot:BotMorality().roleGuesses[ply] or false
    --- is the role hostile to us, i.e is it on another team (excluding TEAM_NONE)
    local isHostile = usesSuspicion and ply:GetTeam() ~= bot:GetTeam() and ply:GetTeam() ~= TEAM_NONE or false

    -- Simplified team handling
    local team = bot:GetTeam()
    local teamString = (team.GetName and team:GetName() or tostring(team)):lower():gsub("^team_", "")
    local plyTeam = IsValid(ply) and ((ply:GetTeam().GetName and ply:GetTeam():GetName()) or tostring(ply:GetTeam())):lower():gsub("^team_", "")

    -- Core prompt components
    local prompt = {
        "You are roleplaying as a player named " .. nickname .. " in Trouble in Terrorist Town.",
        "Generate ONLY a single short response message.",
        "Your role is " .. role .. ".",
        "Your personality type is " .. archetype .. ".",
        "You are currently " .. behaviorDesc .. ".",
        "You are responding to: " .. text,
        "Your team is " .. teamString .. ".",
        "Message is from " .. plyName .. ".",
    }

    -- Add suspicion context if applicable
    if bot:BotMorality() then
        local suspicion = bot:BotMorality():GetSuspicion(ply) or 0
        if suspicion > 5 then
            table.insert(prompt, "You are very suspicious of " .. plyName .. ".")
        elseif suspicion < -5 then
            table.insert(prompt, "You trust " .. plyName .. ".")
        end
    end

    --- Add role guessing and hostile context if applicable
    if isRoleGuess then
        table.insert(prompt, "You think " .. plyName .. " is a " .. ply:GetRoleStringRaw() .. ".")
    end

    if isHostile then
        local cleanTeamName = plyTeam:gsub("^team_", "")
        table.insert(prompt, plyName .. " is on an enemy team (" .. cleanTeamName .. ") and you should not trust this person.")
    end

    -- Add recent chat context
    local lastMessages = bot:BotMemory():GetLastMessages() or {}
    if #lastMessages > 0 then
        local lastMessagesStr = {}
        for i = 1, math.min(3, #lastMessages) do
            local msg = lastMessages[i]
            if msg.sender and IsValid(msg.sender) then
                table.insert(lastMessagesStr, msg.sender:Nick() .. ": " .. tostring(msg.message))
            else
                table.insert(lastMessagesStr, tostring(msg.message))
            end
        end
        table.insert(prompt, "Recent chat: " .. table.concat(lastMessagesStr, ", ") .. 
            ". From: " .. (IsValid(lastMessages[1].sender) and lastMessages[1].sender:Nick() or "Unknown"))
    end

    -- Final instructions
    table.insert(prompt, "Respond with ONLY " .. numWords .. " words or less.")
    table.insert(prompt, "Do not use quotes or explanations.")
    table.insert(prompt, "Be natural and casual.")

    return table.concat(prompt, " ")
end

function TTTBots.ChatGPTPrompts.GetChatGPTPrompt(event_name, bot, params, teamOnly, wasVoice, description)
    local lang = TTTBots.Lib.GetConVarString("language")
    if not teamOnly then teamOnly = false end
    if not wasVoice then wasVoice = false end

    -- Test that the event event_name exists in the language.
    local exists = TTTBots.Locale.TestEventExists(event_name)
    local line = nil

    if exists then
        -- Get the localized line for this event, then format it with safe parameters
        local safeParams = params or {}
        line = TTTBots.Locale.FormatLine(TTTBots.Locale.GetLine(event_name, lang, bot), safeParams)
    end

    local prompt = "You are roleplaying as a player named " .. bot:Nick() .. " in a game. Generate ONLY a short chat message without any additional context, formatting, or quotation marks. "
    
    if params and next(params) then
        local paramStr = {}
        for k, v in pairs(params) do
            table.insert(paramStr, k .. ": " .. tostring(v))
        end
        print("Params: " .. table.concat(paramStr, ", "))
        prompt = prompt .. "Available parameters: " .. table.concat(paramStr, ", ") .. ". "
    end
    
    prompt = prompt .. "You are on the " .. _G.team.GetName(bot:GetTeam()) .. " team as a " .. bot:GetRoleStringRaw() .. ". "
    prompt = prompt .. "Your personality is " .. bot:BotPersonality().archetype .. ". "
    prompt = prompt .. "You are currently " .. (bot.lastBehavior and bot.lastBehavior.Description or "None") .. ". "
    
    local eventDesc = TTTBots.Locale.Description[event_name] or description
    if eventDesc then
        prompt = prompt .. "You want to: " .. eventDesc .. ". "
    end
    
    if line then
        prompt = prompt .. "Example message: " .. line .. ". "
    end

    -- Add last messages from bot's memory (up to 2)
    local lastMessages = bot:BotMemory():GetLastMessages() or {}
    if #lastMessages > 0 then
        local lastMessagesStr = {}
        for i = 1, math.min(2, #lastMessages) do
            local msg = lastMessages[i]
            if msg.sender and IsValid(msg.sender) then
                table.insert(lastMessagesStr, msg.sender:Nick() .. ": " .. tostring(msg.message))
            else
                table.insert(lastMessagesStr, tostring(msg.message))
            end
        end
        prompt = prompt .. "Recent chat: " .. table.concat(lastMessagesStr, ", ") .. ". From: " .. (IsValid(lastMessages[1].sender) and lastMessages[1].sender:Nick() or "Unknown") .. ". "
    end

    prompt = prompt .. "Respond with ONLY a short message (max 7 words). Do not use emojis or special characters. Do not add quotes or explanations."
    return prompt
end

function splitPromptsbyFullStop(prompt)
    local prompts = {}
    while prompt:find("%.") do
        local index = prompt:find("%.")
        table.insert(prompts, prompt:sub(1, index))
        prompt = prompt:sub(index + 1)
    end
    table.insert(prompts, prompt)
    return prompts
end

function TTTBots.ChatGPTPrompts.GetArchetypeDescription(archetype)
    local descriptions = {
        Tryhard = "You are a Tryhard/nerd, often saying nerdy or tryhard things.",
        Hothead = "You are a Hothead, quick to anger in your communication.",
        Stoic = "You are Stoic, rarely complaining or gloating.",
        Dumb = "You are Dumb, often confused or saying 'huh?'.",
        Nice = "You are Nice, often saying nice things and loving to compliment others.",
        Bad = "You are just Bad, not very good at the game.",
        Teamer = "You are a Teamer, loving to say 'us' instead of 'me'.",
        Sus = "You are Sus/Quirky, often saying things like 'guys I'm the traitor'.",
        Casual = "You are Casual, loving to make jokes and often talking in lowercase.",
        Default = "You have a default personality, used as a fallback."
    }
    return descriptions[archetype] or descriptions["Default"]
end
