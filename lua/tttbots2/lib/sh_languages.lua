TTTBots.Locale = {
    Priorities = {},
    Description = {}
}



--- Adds a localized string in the given language to the type
--- Unlike chat messages, we don't need to deal with variance.
---@param name string The identifier of the localized string
---@param text string The content of the localized string
---@param lang string The language to add the localized string to, e.g. "en"
function TTTBots.Locale.AddLocalizedString(name, text, lang)
    local lang = lang or "en"
    TTTBots.Locale[lang] = TTTBots.Locale[lang] or {}
    TTTBots.Locale[lang][name] = text
end

function TTTBots.Locale.GetChatGPTPromptResponse(bot, text, teamOnly, ply)
    local personality = bot:BotPersonality()
    local nickname = bot:Nick()
    local team_name = _G.team.GetName(bot:GetTeam())
    local role = bot:GetRoleStringRaw()
    local archetype = personality.archetype
    local behaviorDesc = bot.lastBehavior and bot.lastBehavior.Description or "None"
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
    -- print("Creating prompt")
    -- --- print first and second halves of the prompt
    -- print(promptIntro .. promptName .. promptGame .. promptGameDesc .. promptRole .. promptPersonality .. promptArchetype .. promptReply .. promptBehavior .. promptDirective .. promptTeam .. promptInnocent .. promptMessagerInfo .. promptSus .. teamOnlyPrompt)
    -- print(promptPremessage .. promptMessage .. promptEnd)

    return promptIntro .. promptName .. promptGame .. promptGameDesc .. promptRole .. promptPersonality .. promptArchetype .. promptReply .. promptBehavior .. promptDirective .. promptTeam .. promptInnocent .. promptMessagerInfo .. promptSus .. teamOnlyPrompt .. promptPremessage .. promptMessage .. promptEnd
end


function TTTBots.Locale.GetChatGPTPrompt(event_name, bot, params, teamOnly, wasVoice)
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
    if eventDesc then
        prompt = prompt .. " The chat event description is: " .. eventDesc
    end
    if line then
        prompt = prompt .. " an example of a response to this message is: " .. line
    end
    prompt = prompt .. " The response must be less than 7 words long and should just be the text of the message with no Emojis or paranthesis. Do not make up any player names that are not provided in the prompt."
    -- print(prompt)
    return prompt

end

--- Gets a localized string name from the given language.
---@param name string
---@param ... any|nil Any varargs to pass to string.format
---@return string|nil string returns string if line exists, nil if it doesn't
function TTTBots.Locale.GetLocalizedString(name, ...)
    local lang = GetConVar("ttt_bot_language"):GetString()
    local str = TTTBots.Locale[lang] and TTTBots.Locale[lang][name] or TTTBots.Locale["en"][name] or "<No translation>"

    -- check if we have any varargs before formatting
    if ... then
        str = string.format(str, ...)
        return str
    end

    return str
end

local f = string.format
local supportedLangs = { "en" }
for _, lang in pairs(supportedLangs) do
    local directory = f("tttbots2/locale/%s/", lang)
    local chatPath = f("%ssh_chats.lua", directory)
    local stringsPath = f("%ssh_strings.lua", directory)

    AddCSLuaFile(chatPath)
    AddCSLuaFile(stringsPath)
    include(chatPath)
    include(stringsPath)
end

--- Add a line into the localized strings table, according to its language. Depending on the type of event, the line may contain parameters.
--- An example is "Hi, my name is {{botname}}" -> "Hi, my name is Bob"
---@param event_name string The name of the event
---@param line string The line to add
---@param lang string The language to add the line to, e.g. "en"
---@param archetype string A string corresponding to a TTTBots.Archetypes enum
function TTTBots.Locale.AddLine(event_name, line, lang, archetype)
    local lang = lang or "en"
    local langtable = TTTBots.Locale[lang]
    if not langtable then
        TTTBots.Locale[lang] = {}
        langtable = TTTBots.Locale[lang]
    end
    langtable[event_name] = langtable[event_name] or {}

    table.insert(langtable[event_name], {
        line = line,
        archetype = archetype or "default"
    })

    -- print(string.format("Added line '%s' to event '%s' in language '%s'", line, event_name, lang))
end

--- Format a line with parameters
---@param line string? The line to format
---@param params table<string, string> A table of parameters to replace in the line
---@return string line The formatted line
function TTTBots.Locale.FormatLine(line, params)
    if not line then return "" end
    if not (params) then return line end
    for key, value in pairs(params) do
        line = line:gsub("{{" .. tostring(key) .. "}}", tostring(value))
    end
    return line
end

---Function to retrieve archetype-specific lines from the localized table
---@param bot Bot The bot entity
---@param localizedTbl table The localized table containing event lines
---@param forceDefault? boolean Flag to force retrieving default archetype lines
---@return table The archetype-specific lines from the localized table
local function getArchetypalLines(bot, localizedTbl, forceDefault)
    local archetypeLocalized = {}
    local personality = bot.components.personality ---@type CPersonality

    -- Iterate through the localized table entries
    for i, entry in pairs(localizedTbl) do
        -- Check if the entry's archetype matches the bot's personality archetype or forceDefault flag
        if entry.archetype == (forceDefault and TTTBots.Archetypes.Default) or personality.archetype then
            table.insert(archetypeLocalized, entry)
        end
    end

    -- If no archetype-specific lines found and forceDefault flag is not set, recursively call the function with forceDefault set to true
    if #archetypeLocalized == 0 and not forceDefault then
        return getArchetypalLines(bot, localizedTbl, true)
    end

    return archetypeLocalized
end

--- Gets a random valid line from the given event name and language. After 20 attempts, it will return nil.
---@param event_name string
---@param lang string
---@param bot Bot
---@param attemptN number|nil
---@return string|nil
function TTTBots.Locale.GetLine(event_name, lang, bot, attemptN)
    if attemptN and attemptN > 20 then return nil end
    local localizedTbl = TTTBots.Locale[lang] and TTTBots.Locale[lang][event_name]
    if not localizedTbl then
        TTTBots.Locale[lang] = TTTBots.Locale[lang] or {}
        TTTBots.Locale[lang][event_name] = TTTBots.Locale[lang][event_name] or {}
        print("No localized strings for event " ..
            event_name .. " in language " .. lang .. "... try setting lang cvar to 'en'.")
        return
    end

    local archetypeLocalizedLines = getArchetypalLines(bot, localizedTbl)
    local randArchetypal = table.Random(archetypeLocalizedLines)

    if not randArchetypal then return nil end

    return randArchetypal.line
end

function TTTBots.Locale.GetLocalizedLine(event_name, bot, params)
    local lang = TTTBots.Lib.GetConVarString("language")

    -- Test that the event event_name exists in the language.
    local exists = TTTBots.Locale.TestEventExists(event_name)
    if not exists then
        print("No localized strings for event " ..
            event_name .. " in language " .. lang .. "... try setting lang cvar to 'en'.")
        return false
    end
    -- Check if this selected category is enabled, per the user's settings.
    local categoryEnabled = TTTBots.Locale.CategoryIsEnabled(event_name)
    if not categoryEnabled then return false end

    -- Get the localized line for this event, then format it.
    local formatted = TTTBots.Locale.FormatLine(TTTBots.Locale.GetLine(event_name, lang, bot), params)

    -- Sometimes it will format to nothing or be nil, so we check for that.
    if not formatted or formatted == "" then return false end
    return formatted
end

--- Return true if the event has any lines associated in this language.
---@param event_name string
---@return boolean
function TTTBots.Locale.TestEventExists(event_name)
    local lang = TTTBots.Lib.GetConVarString("language")
    return TTTBots.Locale[lang] and TTTBots.Locale[lang][event_name] and true or false
end

function TTTBots.Locale.GetLocalizedPlanLine(event_name, bot, params)
    local lang = TTTBots.Lib.GetConVarString("language")
    local modifiedEvent = "Plan." .. event_name

    return TTTBots.Locale.GetLocalizedLine(modifiedEvent, bot, params)
end

--- Registers an event type with the given priority. This is used to cull undesired chatter (user customization)
function TTTBots.Locale.RegisterCategory(event_name, lang, priority, description)
    local lang = lang or "en"
    local langtable = TTTBots.Locale[lang]
    if not langtable then
        TTTBots.Locale[lang] = {}
        langtable = TTTBots.Locale[lang]
    end
    langtable[event_name] = langtable[event_name] or {}
    TTTBots.Locale.Priorities[event_name] = priority
    TTTBots.Locale.Description[event_name] = description or "No description provided."
    description = description or "No description provided."
    -- print("Registered event " .. event_name .. " with priority " .. priority .. " with description " .. description)
end

function TTTBots.Locale.FormatArgsIntoTxt(txt, args)
    if not txt then return "" end
    for k, v in pairs(args) do
        txt = txt:gsub("{{" .. k .. "}}", tostring(v))
    end
    return txt
end

function TTTBots.Locale.CategoryIsEnabled(event_name)
    local maxlevel = TTTBots.Lib.GetConVarFloat("chatter_lvl")
    local level = TTTBots.Locale.Priorities[event_name]
    return level and (level <= maxlevel) or false
end
