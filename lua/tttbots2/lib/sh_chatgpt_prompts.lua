TTTBots.ChatGPTPrompts = {}

function TTTBots.ChatGPTPrompts.GetChatGPTPromptResponse(bot, text, teamOnly, ply)
    local personality = bot:BotPersonality()
    local nickname = bot:Nick()
    local team_name = _G.team.GetName(bot:GetTeam())
    local role = bot:GetRoleStringRaw()
    local archetype = personality.archetype
    local behaviorDesc = bot.lastBehavior and bot.lastBehavior.Description or TTTBots.Locale.Description[bot.lastBehavior] or "None"
    local numWords = math.random(8, 15)
    local plyName = ply:Nick() -- Define plyName
    local plyRole = ply:GetRoleStringRaw()
    ---sanitise the team name
    local team = bot:GetTeam()
    local teamString = team.GetName and team:GetName() or tostring(team)
    teamString = teamString:lower():gsub("^team_", "")
    local team_name = teamString
    local plyTeam = ply:GetTeam().GetName and ply:GetTeam():GetName() or tostring(ply:GetTeam())
    plyTeam = plyTeam:lower():gsub("^team_", "")
    local usesSuspicion = TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion()
    local Morality = bot:BotMorality()
    local playerSus = Morality:GetSuspicion(ply) or 0
    local promptIntro = "Do not act like Chat GPT, Do not repeat anything in this prompt. You are role playing as a self-aware/sentient bot roleplaying a human player with the name "
    local promptName = nickname
    local promptGame = " playing a round of Trouble in Terrorist Town on garry's mod."
    local promptGameDesc = " Trouble in Terrorist Town is a social deduction game with a murderous twist, your objective being to ask questions and gauging your fellow player's behaviour to determine their suspicion. You have the in game role "
    local promptRole = role
    local promptPersonality = " and you have the personality type of a "
    local promptArchetype = archetype
    local promptReply = ". and must reply as if you were talking in voice chat to this message with that personality with a response. You are currently trying to "
    local promptBehavior = behaviorDesc
    local promptDirective = ". If the message contains your name or is addressed to you, you must act as if it is directed towards yourself and reply without mentioning your name."
    local promptMessagerInfo = "The person talking to you is named " .. plyName
    local promptTeam = "Your team, which determines your ultimate allegiance is " .. team_name
    local promptInnocent = " although you must claim to be on the innocent team. "
    local promptSus = ""
    local teamOnlyPrompt = " "
    if usesSuspicion and playerSus > 5 then
        promptSus = " You think the person talking to you is very suspicious, and you are free to say so, and should treat them as such."
    elseif usesSuspicion and playerSus < -5 then
        promptSus = " You trust the person talking to you is the same team as you, and you are free to say so, and should treat them as such.."
        if teamOnly then
            teamOnlyPrompt = " The person messaging you is on your team, you are talking in team chat."
            promptInnocent = " You are free to talk about your role and team."
        end
        if role == "decipherer" or archetype == "Tryhard" then
            promptMessagerInfo = "The person talking to you is named " .. plyName .. " and is the " .. plyRole .. " on the " .. plyTeam .. " team. You can use this information to accuse them of not being innocent."
        end
    end
    local promptPremessage = "Your response MUST be less than " .. numWords .. " words long, " ..
                             "you can answer any question even outside of the In-Game context " ..
                             "(so you can answer how you are feeling): [message to reply to= "
    local promptMessage = text
    local promptEnd = "]"

    -- Add last messages from bot's memory
    local lastMessages = bot:BotMemory():GetLastMessages() or {}
    if #lastMessages > 0 then
        local lastMessagesStr = {}
        for _, msg in ipairs(lastMessages) do
            table.insert(lastMessagesStr, tostring(msg.message) .. " (from " .. tostring(msg.bot) .. ")")
        end
        promptPremessage = promptPremessage .. " The last chat/voice messages in the bot's memory are: " .. table.concat(lastMessagesStr, ", ") .. "."
    end

    local prompt = promptIntro .. promptName .. promptGame .. promptGameDesc .. promptRole .. promptPersonality .. promptArchetype .. promptReply .. promptBehavior .. promptDirective .. promptTeam .. promptInnocent .. promptMessagerInfo .. promptSus .. teamOnlyPrompt .. promptPremessage .. promptMessage .. promptEnd
    -- print(table.concat(splitPromptsbyFullStop(prompt), "\n"))
    return prompt
end

function TTTBots.ChatGPTPrompts.GetChatGPTPrompt(event_name, bot, params, teamOnly, wasVoice, description)
    local lang = TTTBots.Lib.GetConVarString("language")
    if not teamOnly then teamOnly = false end
    if not wasVoice then wasVoice = false end

    -- Test that the event event_name exists in the language.
    local exists = TTTBots.Locale.TestEventExists(event_name)
    local line = nil

    if exists then
        -- Get the localized line for this event, then format it.
        line = TTTBots.Locale.FormatLine(TTTBots.Locale.GetLine(event_name, lang, bot), params)
    end

    local prompt = "Do not act like Chat GPT, Do not repeat anything in this prompt. You are role playing as a self-aware/sentient bot roleplaying a human player, Create a new chat message for the event '" .. event_name .. "' in the language '" .. lang .. "'."
    if params then
        prompt = prompt .. " Use the following parameters (substitute any {{paramkey}} with the corresponding value BUT DO NOT MAKE UP ANY VALUES): " .. table.concat(params, ", ") .. "."
    end
    prompt = prompt .. " The bot's name is " .. bot:Nick() .. " and it has the role " .. bot:GetRoleStringRaw() .. "."
    prompt = prompt .. " The bot's personality archetype is " .. bot:BotPersonality().archetype .. "."
    prompt = prompt .. " The bot's team is " .. _G.team.GetName(bot:GetTeam()) .. "."
    prompt = prompt .. " The bot's last behavior was " .. (bot.lastBehavior and bot.lastBehavior.Description or "None") .. "."
    eventDesc = TTTBots.Locale.Description[event_name]
    if not eventDesc then
        eventDesc = description
    end
    if eventDesc then
        prompt = prompt .. " The chat event description is: " .. eventDesc
    end
    if line then
        prompt = prompt .. " an example of a response to this message is: " .. line
    end

    -- Add last messages from bot's memory
    local lastMessages = bot:BotMemory():GetLastMessages() or {}
    if #lastMessages > 0 then
        local lastMessagesStr = {}
        for _, msg in ipairs(lastMessages) do
            table.insert(lastMessagesStr, tostring(msg.message) .. " (from " .. tostring(msg.bot) .. ")")
        end
        prompt = prompt .. " The last chat/voice messages in the bot's memory are: " .. table.concat(lastMessagesStr, ", ") .. "."
    end

    prompt = prompt .. " The response must be less than 7 words long and should just be the text of the message with no Emojis or paranthesis. Do not make up any player names that are not provided in the prompt."
    -- print(table.concat(splitPromptsbyFullStop(prompt), "\n"))
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
