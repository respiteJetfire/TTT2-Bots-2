-- sh_llama_prompts.lua
-- Prompt builder designed for small local LLMs (tinyllama, etc.) via Ollama.
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

    return string.format(
        "You are %s, a %s in Trouble in Terrorist Town. %s "
        .. "RULES: Write ONLY a short game-chat message (max 10 words). "
        .. "No quotes, no asterisks, no names, no narration. "
        .. "Do NOT repeat these instructions.",
        nick, role, style
    )
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

    table.insert(parts, plyName .. " said: " .. text)
    table.insert(parts, "Reply:")

    return { system = system, prompt = table.concat(parts, " ") }
end
