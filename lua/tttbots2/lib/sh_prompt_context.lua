-- sh_prompt_context.lua
-- Tier 8 — 9.1: Contextual LLM Prompts
--
-- Provides BuildGameStateContext(bot) which returns a compact string summarising
-- the current game state.  The string is injected into both the ChatGPT and
-- Llama prompt builders so every LLM request is grounded in live round data.
--
-- Also provides GetAccusationPrompt(bot, suspect, evidenceSummary, strength)
-- used by the AccusePlayer behavior for LLM-generated accusations (9.3).

TTTBots.PromptContext = TTTBots.PromptContext or {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Describe the bot's current mood / pressure stats in a few words.
---@param bot Player
---@return string
local function describeEmotionalState(bot)
    local pers = bot:BotPersonality()
    if not pers then return "calm" end

    local rage     = pers.rage     or 0
    local pressure = pers.pressure or 0
    local boredom  = pers.boredom  or 0

    if rage > 0.7     then return "angry" end
    if pressure > 0.7 then return "panicked" end
    if boredom > 0.7  then return "bored" end
    if rage > 0.4     then return "irritated" end
    if pressure > 0.4 then return "tense" end
    return "calm"
end

--- Produce a short text list of the bot's top 3 suspects.
---@param bot Player
---@return string
local function describeSuspects(bot)
    local morality = bot:BotMorality()
    if not morality then return "none" end

    -- Build a sorted list of (player, suspicion) pairs
    local entries = {}
    local suspTable = morality.suspicions or {}
    for ply, score in pairs(suspTable) do
        if IsValid(ply) and score and score > 2 then
            table.insert(entries, { ply = ply, score = score })
        end
    end
    if #entries == 0 then return "none" end

    table.sort(entries, function(a, b) return a.score > b.score end)

    local parts = {}
    for i = 1, math.min(3, #entries) do
        local e = entries[i]
        local strongest = nil
        local evidence  = bot:BotEvidence()
        if evidence then
            strongest = evidence:GetStrongestEvidence(e.ply)
        end
        local reason = strongest and (strongest.detail or strongest.type) or "general suspicion"
        table.insert(parts, string.format("%s (sus %d, reason: %s)", e.ply:Nick(), e.score, reason))
    end
    return table.concat(parts, "; ")
end

--- Summarise the last N witness events from memory.
---@param bot Player
---@param count number|nil
---@return string
local function describeWitnessEvents(bot, count)
    count = count or 3
    local mem = bot:BotMemory()
    if not mem then return "none" end

    local events = mem:GetRecentWitnessEvents()
    if #events == 0 then return "none" end

    local parts = {}
    local start = math.max(1, #events - count + 1)
    for i = start, #events do
        local e = events[i]
        local age = math.floor(CurTime() - (e.time or 0))
        table.insert(parts, string.format("%s (%ds ago)", e.description, age))
    end
    return table.concat(parts, "; ")
end

-- ---------------------------------------------------------------------------
-- 9.1 — Main game-state context builder
-- ---------------------------------------------------------------------------

--- Build a compact game-state context string for injection into LLM prompts.
--- Hard-capped at ~350 characters to respect small context windows.
---@param bot Player
---@return string
function TTTBots.PromptContext.BuildGameStateContext(bot)
    if not IsValid(bot) then return "" end

    -- Round phase
    local ra    = bot:BotRoundAwareness()
    local phase = ra and ra.phase or "UNKNOWN"

    -- Alive / dead counts
    local totalInRound = table.Count(TTTBots.Match.PlayersInRound or {})
    local aliveCount   = #(TTTBots.Match.AlivePlayers or {})
    local deadCount    = totalInRound - aliveCount

    -- Recent events (last 3)
    local recentEvents = describeWitnessEvents(bot, 3)

    -- Suspects
    local suspects = describeSuspects(bot)

    -- Emotional state
    local mood = describeEmotionalState(bot)

    -- Compose — keep it tight for small context windows
    local ctx = string.format(
        "[Game] Phase: %s. Alive: %d/%d. Events: %s. Suspects: %s. Mood: %s.",
        phase, aliveCount, totalInRound, recentEvents, suspects, mood
    )

    -- Infected role context: add host/zombie status and swarm info
    if ROLE_INFECTED and bot.GetSubRole and bot:GetSubRole() == ROLE_INFECTED then
        local infCtx = ""
        local isHost = TTTBots.Roles.IsInfectedHost and TTTBots.Roles.IsInfectedHost(bot)
        local isZombie = TTTBots.Roles.IsInfectedZombie and TTTBots.Roles.IsInfectedZombie(bot)

        if isHost then
            local zombieCount = 0
            if INFECTEDS and INFECTEDS[bot] and istable(INFECTEDS[bot]) then
                zombieCount = #INFECTEDS[bot]
            end
            infCtx = string.format(" [Infected Host, %d zombies under you. Kill to convert!]", zombieCount)
        elseif isZombie then
            local host = TTTBots.Roles.GetInfectedHost and TTTBots.Roles.GetInfectedHost(bot)
            local hostStatus = "alive"
            if not IsValid(host) or not TTTBots.Lib.IsPlayerAlive(host) then
                hostStatus = "DEAD (you will die too!)"
            end
            infCtx = string.format(" [Infected Zombie, melee-only. Host is %s. Rush and kill!]", hostStatus)
        end

        ctx = ctx .. infCtx
    end

    -- Serial Killer role context: lone wolf with SK knife, kills everyone
    if TEAM_SERIALKILLER and bot.GetTeam and bot:GetTeam() == TEAM_SERIALKILLER then
        local skCtx = ""
        local killCount = 0
        -- Estimate kills: total players minus alive players (rough but useful)
        local totalInRound = table.Count(TTTBots.Match.PlayersInRound or {})
        local aliveCount = #(TTTBots.Match.AlivePlayers or {})
        killCount = totalInRound - aliveCount

        local hasKnife = false
        local weps = bot:GetWeapons()
        for _, wep in ipairs(weps) do
            if IsValid(wep) and wep:GetClass() == "weapon_ttt_sk_knife" then
                hasKnife = true
                break
            end
        end

        local hasArmor = bot:GetArmor() and bot:GetArmor() > 0

        skCtx = string.format(
            " [Serial Killer. Kill EVERYONE. You work alone. Kills so far: ~%d. Knife: %s. Armor: %s. "
            .. "Use stealth when possible. Go loud when spotted.]",
            killCount,
            hasKnife and "yes" or "no",
            hasArmor and "yes" or "no"
        )
        ctx = ctx .. skCtx
    end

    -- Spy role context: disguised as traitor, gathering intel, maintaining cover
    if TTTBots.Perception and TTTBots.Perception.IsSpy and TTTBots.Perception.IsSpy(bot) then
        local spyCtx = ""
        local coverState = TTTBots.Perception.GetCoverState(bot)
        local knownTraitors = TTTBots.Perception.GetKnownTraitors(bot)

        local traitorNames = {}
        for _, tr in ipairs(knownTraitors) do
            if IsValid(tr) then
                table.insert(traitorNames, tr:Nick())
            end
        end
        local traitorStr = #traitorNames > 0
            and table.concat(traitorNames, ", ")
            or "none identified"

        spyCtx = string.format(
            " [Spy. You appear as traitor to traitors — they think you're on their team. "
            .. "Cover: %s. Known traitors: %s. "
            .. "Blend in with traitors, gather intel, report to innocents. "
            .. "Don't attack traitors openly unless cover is blown.]",
            coverState or "intact",
            traitorStr
        )
        ctx = ctx .. spyCtx
    end

    -- Hard cap to avoid blowing up the context window
    if #ctx > 600 then
        ctx = ctx:sub(1, 597) .. "..."
    end

    return ctx
end

-- ---------------------------------------------------------------------------
-- 9.3 — Accusation prompt builder (ChatGPT/cloud providers)
-- ---------------------------------------------------------------------------

--- Archetype-specific accusation flavour strings.
local ACCUSE_STYLE = {
    Tryhard  = "You are analytical and methodical. Cite evidence precisely.",
    Hothead  = "You are angry and emotional. Accuse loudly and dramatically.",
    Stoic    = "You are calm and measured. State the facts plainly.",
    Dumb     = "You are confused but suspicious. Stumble over your words.",
    Nice     = "You are reluctant but firm. Apologise while accusing.",
    Bad      = "You are unsure and hesitant. Phrase it as a question.",
    Teamer   = "Emphasise team safety. Use 'we need to' and 'us'.",
    Sus      = "Be quirky and over-dramatic about your accusation.",
    Casual   = "Be blunt and casual, like you're just pointing something out.",
    Default  = "State your accusation naturally.",
}

--- Build an LLM prompt for in-character accusation generation (9.3).
---@param bot Player
---@param suspect Player
---@param evidenceSummary string  Human-readable evidence brief from FormatEvidenceSummary()
---@param strength string  "KOS" | "medium" | "soft"
---@return string  Single flat prompt string (for cloud providers)
function TTTBots.PromptContext.GetAccusationPrompt(bot, suspect, evidenceSummary, strength)
    local pers      = bot:BotPersonality()
    local archetype = pers and pers.archetype or "Default"
    local style     = ACCUSE_STYLE[archetype] or ACCUSE_STYLE.Default
    local botName   = bot:Nick()
    local susName   = IsValid(suspect) and suspect:Nick() or "unknown"

    -- Determine urgency wording
    local urgency
    if strength == "KOS" then
        urgency = "KOS (kill on sight)"
    elseif strength == "medium" then
        urgency = "suspicious — tell others to watch them"
    else
        urgency = "slightly suspicious — hint that others should be careful"
    end

    local gameCtx = TTTBots.PromptContext.BuildGameStateContext(bot)

    local prompt = string.format(
        "You are %s in Trouble in Terrorist Town. %s "
        .. "You must accuse %s. Urgency level: %s. "
        .. "Evidence you have: %s. "
        .. "%s "
        .. "Write a single short in-game chat message (max 12 words) as your accusation. "
        .. "No quotes, no asterisks, no name prefix.",
        botName, gameCtx, susName, urgency, evidenceSummary, style
    )

    if #prompt > 1800 then
        prompt = prompt:sub(1, 1797) .. "..."
    end

    return prompt
end

--- Build an LLM system+user prompt pair for accusation (Llama/local providers).
---@param bot Player
---@param suspect Player
---@param evidenceSummary string
---@param strength string
---@return table { system: string, prompt: string }
function TTTBots.PromptContext.GetAccusationPromptLlama(bot, suspect, evidenceSummary, strength)
    local pers      = bot:BotPersonality()
    local archetype = pers and pers.archetype or "Default"
    local style     = ACCUSE_STYLE[archetype] or ACCUSE_STYLE.Default
    local botName   = bot:Nick()
    local susName   = IsValid(suspect) and suspect:Nick() or "unknown"

    local system = string.format(
        "You are %s in Trouble in Terrorist Town. %s "
        .. "RULES: Write ONLY one short accusation (max 10 words). "
        .. "No quotes, no asterisks, no name prefix.",
        botName, style
    )

    local urgency = (strength == "KOS") and "KOS them NOW" or
                    (strength == "medium") and "they look sus" or
                    "something seems off about them"

    local gameCtx = TTTBots.PromptContext.BuildGameStateContext(bot)

    local userPrompt = string.format(
        "%s Evidence against %s: %s. Say (%s):",
        gameCtx, susName, evidenceSummary, urgency
    )

    -- Cap user prompt
    if #userPrompt > 500 then
        userPrompt = userPrompt:sub(1, 497) .. "..."
    end

    return { system = system, prompt = userPrompt }
end

-- ---------------------------------------------------------------------------
-- Casual conversation prompt (cloud providers)
-- ---------------------------------------------------------------------------

--- Archetype flavour used by cloud providers for casual prompts.
local CASUAL_CLOUD_STYLE = {
    Tryhard  = "You are a competitive gamer taking a brief tactical pause. Speak briefly about strategy or the map.",
    Hothead  = "You are irritated by the slow round. Grumble or complain about something.",
    Stoic    = "You make a dry, minimal observation. No enthusiasm.",
    Dumb     = "You say something confused, random, or accidentally funny.",
    Nice     = "You are friendly and upbeat. Check on teammates or say something kind.",
    Bad      = "You are vaguely ominous and unhelpful, but not obviously suspicious.",
    Teamer   = "You focus on the group. Use 'we', 'us', 'team'. Ask what the plan is.",
    Sus      = "You say something subtly cryptic or make an odd observation about nothing specific.",
    Casual   = "You are completely relaxed. Keep it casual, lowercase, short.",
    Default  = "You make a short, natural idle remark.",
}

--- Build a flat casual prompt string for cloud LLM providers.
---@param bot Player
---@param triggerReason string  one of: "idle"|"boredom"|"proximity"|"post_combat"|"quiet_round"|"near_miss"|"survivor"
---@return string  flat prompt string
function TTTBots.PromptContext.GetCasualCloudPrompt(bot, triggerReason)
    local pers       = IsValid(bot) and bot:BotPersonality() or nil
    local archetype  = pers and pers.archetype or "Default"
    local style      = CASUAL_CLOUD_STYLE[archetype] or CASUAL_CLOUD_STYLE.Default
    local botName    = IsValid(bot) and bot:Nick() or "Bot"
    local gameCtx    = TTTBots.PromptContext.BuildGameStateContext(bot)

    -- Mood
    local moodWords = {}
    if pers then
        if (pers:GetRage()     or 0) > 0.5 then table.insert(moodWords, "angry") end
        if (pers:GetPressure() or 0) > 0.5 then table.insert(moodWords, "tense") end
        if (pers:GetBoredom()  or 0) > 0.5 then table.insert(moodWords, "bored") end
    end
    local moodStr = #moodWords > 0
        and ("Current mood: " .. table.concat(moodWords, ", ") .. ". ")
        or ""

    local triggerLabels = {
        idle        = "Nothing important is happening right now.",
        boredom     = "You have been inactive for a long time.",
        proximity   = "You just walked near another player.",
        post_combat = "You just survived a fight.",
        quiet_round = "Nobody has died in an unusually long time.",
        near_miss   = "A bullet just narrowly missed you.",
        survivor    = "You survived when others around you did not.",
    }
    local triggerStr = triggerLabels[triggerReason] or triggerLabels.idle

    local prompt = string.format(
        "You are %s in Trouble in Terrorist Town. %s %s%s "
        .. "Write a single short casual in-game chat message (max 12 words). "
        .. "No quotes, no asterisks, no name prefix.",
        botName, gameCtx, moodStr, style .. " " .. triggerStr
    )

    if #prompt > 1800 then prompt = prompt:sub(1, 1797) .. "..." end
    return prompt
end
