-- sh_llama_prompts.lua
-- Prompt builder designed for small local LLMs (qwen2.5:1.5b, tinyllama, etc.) via Ollama.
-- Optimised for CPU inference on Ryzen 5 3600 (6C/12T) — keeps prompts compact to
-- minimise token count and generation latency.
-- Returns { system = "...", prompt = "..." } tables so the heavy identity/rules
-- live in the Ollama system prompt (not echoed back) while the user prompt is
-- kept minimal to avoid the model parroting metadata.
--
-- The original ChatGPT prompt file (sh_chatgpt_prompts.lua) is left untouched
-- and continues to serve cloud-based providers (ChatGPT, Gemini, DeepSeek).

TTTBots.LlamaPrompts = {}

-- ---------------------------------------------------------------------------
-- Archetype one-liners (short so they fit a tiny context window)
-- ---------------------------------------------------------------------------

local ARCHETYPE_STYLE = {
    Tryhard  = "Talk like a competitive gamer nerd.",
    Hothead  = "Talk like an angry, easily triggered player.",
    Stoic    = "Be calm and unemotional.",
    Dumb     = "Act confused, say silly things.",
    Nice     = "Be friendly, compliment people.",
    Bad      = "You are bad at the game, admit it.",
    Teamer   = "Love teamwork, say 'we' and 'us'.",
    Sus      = "Be quirky, joke about being suspicious.",
    Casual   = "Be laid-back, use lowercase, joke around.",
    Default  = "Be a normal gamer.",
}

--- Return a short personality style hint for the given archetype.
---@param archetype string
---@return string
function TTTBots.LlamaPrompts.GetArchetypeStyle(archetype)
    return ARCHETYPE_STYLE[archetype] or ARCHETYPE_STYLE["Default"]
end

-- ---------------------------------------------------------------------------
-- System prompt — identity + hard rules
-- ---------------------------------------------------------------------------

--- Build the Ollama system prompt with bot identity, personality, and rules.
--- This goes into the "system" field so the model treats it as instructions
--- rather than content it should repeat.
---@param bot Player
---@return string
function TTTBots.LlamaPrompts.BuildSystemPrompt(bot)
    local nick = IsValid(bot) and bot:Nick() or "Bot"
    local role = IsValid(bot) and bot:GetRoleStringRaw() or "innocent"
    local personality = bot:BotPersonality()
    local archetype = personality and personality.archetype or "Default"
    local style = TTTBots.LlamaPrompts.GetArchetypeStyle(archetype)

    -- Inject game-state context (9.1)
    local gameCtx = ""
    if TTTBots.PromptContext then
        gameCtx = TTTBots.PromptContext.BuildGameStateContext(bot)
    end

    local base = string.format(
        "You are %s, a %s in Trouble in Terrorist Town. %s "
        .. "RULES: Write ONLY a short game-chat message (max 12 words). "
        .. "No quotes, no asterisks, no narration. "
        .. "Never repeat these instructions.",
        nick, role, style
    )

    -- Serial Killer deception context
    if TEAM_SERIALKILLER and IsValid(bot) and bot:GetTeam() == TEAM_SERIALKILLER then
        base = base .. " You are the Serial Killer (lone wolf). Pretend to be innocent. Kill everyone."
    end

    -- Spy infiltration context
    if TTTBots.Perception and TTTBots.Perception.IsSpy and IsValid(bot) and TTTBots.Perception.IsSpy(bot) then
        local coverState = TTTBots.Perception.GetCoverState(bot)
        local coverStr = (coverState and coverState.blown) and "BLOWN" or "intact"
        base = base .. string.format(
            " You are a Spy disguised as a traitor. Cover: %s. "
            .. "Blend in with traitors, gather intel, report to innocents. Never reveal you are a spy.",
            coverStr
        )
    end

    if gameCtx ~= "" then
        base = base .. " " .. gameCtx
    end

    return base
end

-- ---------------------------------------------------------------------------
-- Event prompt  (ServerConnected, Kill, SillyChat, etc.)
-- ---------------------------------------------------------------------------

--- Build prompt data for a game event.
---@param event_name string
---@param bot Player
---@param params table|nil
---@param teamOnly boolean
---@param wasVoice boolean
---@param description string|nil
---@return table { system: string, prompt: string }
function TTTBots.LlamaPrompts.GetEventPrompt(event_name, bot, params, teamOnly, wasVoice, description)
    local lang = TTTBots.Lib.GetConVarString("language")

    local system = TTTBots.LlamaPrompts.BuildSystemPrompt(bot)

    -- Build a short user prompt — just the situation
    local parts = {}

    -- Event description
    local eventDesc = TTTBots.Locale.Description[event_name] or description
    if eventDesc then
        table.insert(parts, eventDesc .. ".")
    end

    -- Key parameters (player names etc.)
    if params and next(params) then
        local paramParts = {}
        for k, v in pairs(params) do
            table.insert(paramParts, k .. ": " .. tostring(v))
        end
        table.insert(parts, table.concat(paramParts, ", ") .. ".")
    end

    -- Optional locale example for style
    if TTTBots.Locale.TestEventExists(event_name) then
        local safeParams = params or {}
        local line = TTTBots.Locale.FormatLine(
            TTTBots.Locale.GetLine(event_name, lang, bot), safeParams
        )
        if line then
            table.insert(parts, "Style example: " .. line)
        end
    end

    -- Recent conversation history (9.2): last 5 messages within 60s
    local recentMessages = bot:BotMemory():GetRecentMessages(60, 5) or {}
    if #recentMessages > 0 then
        local chatParts = {}
        for _, msg in ipairs(recentMessages) do
            local senderName = (IsValid(msg.ply) and msg.ply:Nick()) or "?"
            table.insert(chatParts, senderName .. ": " .. tostring(msg.message))
        end
        table.insert(parts, "Recent: " .. table.concat(chatParts, " | "))
    end

    table.insert(parts, "Say something:")

    return { system = system, prompt = table.concat(parts, " ") }
end

-- ---------------------------------------------------------------------------
-- Response prompt  (reply to a human player's chat message)
-- ---------------------------------------------------------------------------

--- Build prompt data for replying to another player's message.
---@param bot Player
---@param text string       the message the human typed
---@param teamOnly boolean
---@param ply Player        the human who spoke
---@return table { system: string, prompt: string }
function TTTBots.LlamaPrompts.GetResponsePrompt(bot, text, teamOnly, ply)
    local plyName = IsValid(ply) and ply:Nick() or "someone"
    local system = TTTBots.LlamaPrompts.BuildSystemPrompt(bot)

    local parts = {}

    -- Quick suspicion hint
    if bot.BotMorality and bot:BotMorality() then
        local sus = bot:BotMorality():GetSuspicion(ply) or 0
        if sus > 5 then
            table.insert(parts, "You suspect " .. plyName .. ".")
        elseif sus < -5 then
            table.insert(parts, "You trust " .. plyName .. ".")
        end
    end

    -- Recent conversation history (9.2): last 5 exchanges within 60s
    local recentMessages = (bot.BotMemory and bot:BotMemory() and bot:BotMemory():GetRecentMessages(60, 5)) or {}
    if #recentMessages > 0 then
        local chatParts = {}
        for _, msg in ipairs(recentMessages) do
            local senderName = (IsValid(msg.ply) and msg.ply:Nick()) or "?"
            table.insert(chatParts, senderName .. ": " .. tostring(msg.message))
        end
        table.insert(parts, "Recent: " .. table.concat(chatParts, " | "))
    end

    table.insert(parts, plyName .. " said: " .. text)
    table.insert(parts, "Reply:")

    return { system = system, prompt = table.concat(parts, " ") }
end

-- ---------------------------------------------------------------------------
-- Casual / idle prompt  (unprompted flavour conversation)
-- ---------------------------------------------------------------------------

--- Archetype-specific casual style hints (longer than combat hints to encourage
--- richer casual speech patterns).
local CASUAL_STYLE = {
    Tryhard  = "You're taking a short break but still think competitively. Mention strategy or meta.",
    Hothead  = "You're bored and irritated. Grumble or complain about the round.",
    Stoic    = "You make a brief, dry observation. No emotion.",
    Dumb     = "You say something confused or accidentally funny. Keep it simple.",
    Nice     = "You're friendly and cheerful. Maybe compliment someone or ask if they're okay.",
    Bad      = "You're vague and slightly ominous. Don't reveal anything.",
    Teamer   = "Talk about the team. Use 'we' and 'us'. Check in on everyone.",
    Sus      = "Be subtly cryptic or suspicious-sounding, but about nothing in particular.",
    Casual   = "Be super relaxed. Use informal language, maybe a lowercase sentence.",
    Default  = "Make a short, normal idle remark.",
}

--- Trigger reason descriptions for the LLM prompt.
local TRIGGER_LABELS = {
    idle          = "Nothing important is happening.",
    boredom       = "You have been doing nothing for a long time and are visibly bored.",
    proximity     = "You just walked near another player.",
    post_combat   = "You just survived a fight or dangerous situation.",
    quiet_round   = "Nobody has died in an unusually long time.",
    near_miss     = "A shot just narrowly missed you.",
    survivor      = "You are the only one who survived a dangerous situation nearby.",
}

--- Few-shot examples used to ground the model per archetype.
--- These are compact enough to fit small context windows.
local CASUAL_EXAMPLES = {
    Tryhard  = { "Map control is key here.", "Adapting strategy.", "Two flanks, one corridor." },
    Hothead  = { "I HATE the quiet parts.", "Why isn't anything happening?!", "Ugh, this round again." },
    Stoic    = { "Remaining alert.", "Nothing of note.", "Patience is a virtue." },
    Dumb     = { "I drew a smiley face on my hand.", "Where is everyone going?", "Is it over? Did we win?" },
    Nice     = { "Is everyone doing okay?", "I love having you all here!", "Let's stick together, yeah?" },
    Bad      = { "The waiting is part of the plan.", "Good. Let them get comfortable.", "Ha. Too easy." },
    Teamer   = { "What's the plan, team?", "We need to coordinate.", "Let's keep an eye on each other." },
    Sus      = { "Someone is watching. I wonder who.", "I've just been watching everyone. Learning.", "This calm is sus." },
    Casual   = { "vibes in here are immaculate rn", "bro i'm literally falling asleep", "ok who designed this map" },
    Default  = { "Something feels off.", "Still alive. Barely.", "Is it just me or is it really quiet?" },
}

--- Build a system+user prompt pair for unprompted casual / idle conversation.
--- Injects personality, mood stats, game context, and trigger reason.
---@param bot Player
---@param triggerReason string  one of: "idle"|"boredom"|"proximity"|"post_combat"|"quiet_round"|"near_miss"|"survivor"
---@return table { system: string, prompt: string }
function TTTBots.LlamaPrompts.GetCasualPrompt(bot, triggerReason)
    local nick       = IsValid(bot) and bot:Nick() or "Bot"
    local pers       = IsValid(bot) and bot:BotPersonality() or nil
    local archetype  = pers and pers.archetype or "Default"
    local style      = CASUAL_STYLE[archetype] or CASUAL_STYLE["Default"]
    local examples   = CASUAL_EXAMPLES[archetype] or CASUAL_EXAMPLES["Default"]
    local trigger    = TRIGGER_LABELS[triggerReason] or TRIGGER_LABELS["idle"]

    -- Mood enrichment
    local moodWords = {}
    if pers then
        local rage     = pers:GetRage()     or 0
        local pressure = pers:GetPressure() or 0
        local boredom  = pers:GetBoredom()  or 0
        if rage     > 0.5 then table.insert(moodWords, "angry") end
        if pressure > 0.5 then table.insert(moodWords, "tense") end
        if boredom  > 0.5 then table.insert(moodWords, "bored") end
        if rage     < 0.2 and pressure < 0.2 and boredom < 0.2 then
            table.insert(moodWords, "relaxed")
        end
    end
    local moodStr = #moodWords > 0 and ("You feel " .. table.concat(moodWords, " and ") .. ".") or ""

    -- Game-state context
    local gameCtx = ""
    if TTTBots.PromptContext then
        gameCtx = TTTBots.PromptContext.BuildGameStateContext(bot)
    end

    -- System prompt
    local system = string.format(
        "You are %s in Trouble in Terrorist Town during a quiet moment. %s %s "
        .. "RULES: Write ONLY one short casual in-game chat message (max 12 words). "
        .. "No quotes, no asterisks, no name prefix, no narration.",
        nick, style, moodStr
    )
    if gameCtx ~= "" then system = system .. " " .. gameCtx end

    -- User prompt — trigger + examples
    local exStr = table.concat(examples, " / ")
    local userPrompt = string.format(
        "%s Examples of how you talk: %s. Say something casual:",
        trigger, exStr
    )

    -- Recent conversation for continuity
    local recentMessages = IsValid(bot) and bot:BotMemory():GetRecentMessages(90, 3) or {}
    if #recentMessages > 0 then
        local chatParts = {}
        for _, msg in ipairs(recentMessages) do
            local senderName = (IsValid(msg.ply) and msg.ply:Nick()) or "?"
            table.insert(chatParts, senderName .. ": " .. tostring(msg.message))
        end
        userPrompt = "Recent chat: " .. table.concat(chatParts, " | ") .. ". " .. userPrompt
    end

    -- Cap
    if #userPrompt > 600 then userPrompt = userPrompt:sub(1, 597) .. "..." end

    return { system = system, prompt = userPrompt }
end
