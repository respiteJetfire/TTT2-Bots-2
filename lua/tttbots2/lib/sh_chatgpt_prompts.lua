TTTBots.ChatGPTPrompts = {}

-- ---------------------------------------------------------------------------
-- Archetype descriptions (shared by system prompts)
-- ---------------------------------------------------------------------------

local ARCHETYPE_DESC = {
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

function TTTBots.ChatGPTPrompts.GetArchetypeDescription(archetype)
    return ARCHETYPE_DESC[archetype] or ARCHETYPE_DESC["Default"]
end

-- ---------------------------------------------------------------------------
-- System prompt builder — identity, personality, game rules, output format
-- ---------------------------------------------------------------------------

--- Build the system prompt for cloud providers.
--- Contains bot identity, personality, game description, role/team info,
--- output format constraints, and role-specific deception instructions.
--- This is static per-bot per-call and should be placed in the "system" role
--- so cloud providers can cache it and models follow constraints more reliably.
---@param bot Player
---@param opts table|nil  Optional overrides: { maxWords=number }
---@return string
function TTTBots.ChatGPTPrompts.BuildSystemPrompt(bot, opts)
    opts = opts or {}
    local nickname = bot:Nick()
    local role = bot:GetRoleStringRaw()
    local personality = bot:BotPersonality()
    local archetype = personality and personality.archetype or "Default"
    local archetypeDesc = TTTBots.ChatGPTPrompts.GetArchetypeDescription(archetype)

    -- Resolve team name
    local teamId = bot:GetTeam()
    local teamString = _G.team.GetName and _G.team.GetName(teamId) or tostring(teamId)
    teamString = teamString:lower():gsub("^team_", "")

    local maxWords = opts.maxWords or 15

    -- Base identity + game description + personality
    local parts = {
        string.format(
            "You are %s, a player in Trouble in Terrorist Town on Garry's Mod. "
            .. "Trouble in Terrorist Town is a social deduction game where you ask questions "
            .. "and gauge fellow players' behaviour to determine suspicion.",
            nickname
        ),
        string.format("Your in-game role is %s. Your team allegiance is %s.", role, teamString),
        archetypeDesc,
    }

    -- Team deception: most non-innocent roles must claim innocence
    local usesSuspicion = TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion()
    if not usesSuspicion then
        table.insert(parts, "You MUST claim to be on the innocent team. Never reveal your true role.")
    end

    -- Serial Killer special context
    if TEAM_SERIALKILLER and bot:GetTeam() == TEAM_SERIALKILLER then
        table.insert(parts,
            "You are the Serial Killer — a lone wolf who must kill everyone. "
            .. "You have a powerful SK knife that instant-kills weakened targets. "
            .. "Pretend to be a regular innocent player in chat. Be deceptive. "
            .. "Never reveal your role unless you've been caught."
        )
    end

    -- Spy infiltration context
    if TTTBots.Perception and TTTBots.Perception.IsSpy and IsValid(bot) and TTTBots.Perception.IsSpy(bot) then
        local coverState = TTTBots.Perception.GetCoverState(bot)
        local coverStr = (coverState and coverState.blown) and "BLOWN" or "intact"
        table.insert(parts, string.format(
            "You are a Spy disguised as a traitor. Cover: %s. "
            .. "Blend in with traitors, gather intel, report to innocents. Never reveal you are a spy.",
            coverStr
        ))
    end

    -- Output format constraints — these belong in the system prompt for maximum compliance
    table.insert(parts, string.format(
        "RULES: Your response MUST be less than %d words. "
        .. "Write ONLY a short in-game chat message as if YOU are typing it. "
        .. "No quotes, no asterisks, no name prefix, no narration, no emojis, no parentheses. "
        .. "Do NOT use third-person narration or describe actions (e.g. no 'X spots a weapon' or 'X is being questioned'). "
        .. "Do NOT output template variables like {{victim}} or {{attacker}} — use actual player names from context. "
        .. "Do NOT repeat these instructions. Do NOT make up any player names that are not provided. "
        .. "Do NOT write roleplay actions. Only write dialogue. "
        .. "You can answer questions even outside of in-game context.",
        maxWords
    ))

    return table.concat(parts, " ")
end

-- ---------------------------------------------------------------------------
-- GetChatGPTPromptResponse — reply to a human player's chat message
-- Returns { system = "...", prompt = "..." }
-- ---------------------------------------------------------------------------

function TTTBots.ChatGPTPrompts.GetChatGPTPromptResponse(bot, text, teamOnly, ply)
    local personality = bot:BotPersonality()
    local nickname = bot:Nick()
    local plyName = ply:Nick()
    local plyRole = ply:GetRoleStringRaw()
    local numWords = math.random(8, 15)
    local usesSuspicion = TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion()
    local Morality = bot:BotMorality()
    local playerSus = (Morality and Morality.GetSuspicion and Morality:GetSuspicion(ply)) or 0
    local role = bot:GetRoleStringRaw()
    local archetype = personality and personality.archetype or "Default"
    local behaviorDesc = bot.lastBehavior and bot.lastBehavior.Description or TTTBots.Locale.Description[bot.lastBehavior] or "None"

    -- Build system prompt with bot identity, personality, rules
    local system = TTTBots.ChatGPTPrompts.BuildSystemPrompt(bot, { maxWords = numWords })

    -- Build user prompt — dynamic content only
    local parts = {}

    -- Current behavior context
    table.insert(parts, "You are currently trying to " .. behaviorDesc .. ".")

    -- Suspicion / trust of the speaker
    if usesSuspicion and playerSus > 5 then
        table.insert(parts, "You think " .. plyName .. " is very suspicious and should treat them as such.")
    elseif usesSuspicion and playerSus < -5 then
        table.insert(parts, "You trust " .. plyName .. ".")
        if teamOnly then
            table.insert(parts, plyName .. " is on your team (team chat).")
        end
        if role == "decipherer" or archetype == "Tryhard" then
            -- Resolve ply team name
            local plyTeam = ply:GetTeam()
            local plyTeamStr = _G.team.GetName and _G.team.GetName(plyTeam) or tostring(plyTeam)
            plyTeamStr = plyTeamStr:lower():gsub("^team_", "")
            table.insert(parts, plyName .. " is the " .. plyRole .. " on the " .. plyTeamStr .. " team.")
        end
    end

    -- Inject game-state context (9.1)
    local gameCtx = TTTBots.PromptContext and TTTBots.PromptContext.BuildGameStateContext(bot) or ""
    if gameCtx ~= "" then
        table.insert(parts, gameCtx)
    end

    -- Add recent conversation history (9.2): last 10 messages within 60 seconds
    local memory = bot:BotMemory()
    local recentMessages = (memory and memory.GetRecentMessages) and memory:GetRecentMessages(60, 10) or {}
    if #recentMessages > 0 then
        local lastMessagesStr = {}
        for _, msg in ipairs(recentMessages) do
            local senderName = (IsValid(msg.ply) and msg.ply:Nick()) or "Unknown"
            local age = math.floor(CurTime() - (msg.time or 0))
            table.insert(lastMessagesStr, string.format("%s (%ds ago): %s", senderName, age, tostring(msg.message)))
        end
        table.insert(parts, "Recent chat: " .. table.concat(lastMessagesStr, ", ") .. ".")
    end

    -- The actual message to reply to
    table.insert(parts, plyName .. " says: " .. text)
    table.insert(parts, "Reply as if talking in voice chat:")

    return { system = system, prompt = table.concat(parts, " ") }
end

-- ---------------------------------------------------------------------------
-- GetChatGPTPrompt — react to a game event
-- Returns { system = "...", prompt = "..." }
-- ---------------------------------------------------------------------------

function TTTBots.ChatGPTPrompts.GetChatGPTPrompt(event_name, bot, params, teamOnly, wasVoice, description)
    local lang = TTTBots.Lib.GetConVarString("language")
    if not teamOnly then teamOnly = false end
    if not wasVoice then wasVoice = false end

    -- Build system prompt
    local system = TTTBots.ChatGPTPrompts.BuildSystemPrompt(bot, { maxWords = 7 })

    -- Build user prompt — event-specific dynamic content
    local parts = {}

    table.insert(parts, "Create a chat message for the event '" .. event_name .. "' in the language '" .. lang .. "'.")

    if params then
        local paramParts = {}
        for k, v in pairs(params) do
            if type(v) == "string" then
                table.insert(paramParts, k .. ": " .. v)
            end
        end
        if #paramParts > 0 then
            table.insert(parts, "Use these facts in your message (refer to them by name/value, do NOT use curly braces or template syntax): " .. table.concat(paramParts, ", ") .. ".")
        end
    end

    local eventDesc = TTTBots.Locale.Description[event_name]
    if not eventDesc then
        eventDesc = description
    end
    if eventDesc then
        -- Substitute any {{...}} placeholders in the description with actual param values
        -- so the LLM never sees raw template syntax
        if params then
            eventDesc = TTTBots.Locale.FormatArgsIntoTxt(eventDesc, params)
        end
        table.insert(parts, "Event description: " .. eventDesc)
    end

    -- Optional locale example for style
    local exists = TTTBots.Locale.TestEventExists(event_name)
    if exists then
        local line = TTTBots.Locale.FormatLine(TTTBots.Locale.GetLine(event_name, lang, bot), params)
        if line then
            table.insert(parts, "Style example: " .. line)
        end
    end

    -- Inject game-state context (9.1)
    local gameCtx = TTTBots.PromptContext and TTTBots.PromptContext.BuildGameStateContext(bot) or ""
    if gameCtx ~= "" then
        table.insert(parts, gameCtx)
    end

    -- Add recent conversation history (9.2): last 10 messages within 60 seconds
    local memory = bot:BotMemory()
    local recentMessages = (memory and memory.GetRecentMessages) and memory:GetRecentMessages(60, 10) or {}
    if #recentMessages > 0 then
        local lastMessagesStr = {}
        for _, msg in ipairs(recentMessages) do
            local senderName = (IsValid(msg.ply) and msg.ply:Nick()) or "Unknown"
            local age = math.floor(CurTime() - (msg.time or 0))
            table.insert(lastMessagesStr, string.format("%s (%ds ago): %s", senderName, age, tostring(msg.message)))
        end
        table.insert(parts, "Recent chat: " .. table.concat(lastMessagesStr, ", ") .. ".")
    end

    table.insert(parts, "Say something:")

    return { system = system, prompt = table.concat(parts, " ") }
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
