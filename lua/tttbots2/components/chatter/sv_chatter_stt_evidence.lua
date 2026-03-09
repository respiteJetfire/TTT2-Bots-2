--- sv_chatter_stt_evidence.lua
--- Tier 8 — 9.4: STT-Driven Evidence Processing
---
--- Sits between the STT transcript polling (sv_chatter_stt.lua) and the
--- keyword command router (RespondToPlayerMessage).  For every voice
--- transcript it:
---   1. Normalizes Doomguy alias variants into the canonical string "doomguy".
---   2. Runs fast regex-based extraction for common claim patterns.
---   3. Falls back to an LLM extraction call (Ollama JSON mode) if regex
---      finds nothing AND the LLM provider is available.
---   4. Maps extracted claims to evidence entries on nearby bots.
---   5. Fires DoomguyAtLocation or DoomguyChasingMe chatter events on nearby
---      bots when Doomguy-specific speech is detected.
---   6. Returns so the caller can still route the transcript through
---      RespondToPlayerMessage for command matching / conversational replies.
---
--- Speech-extracted evidence carries a 0.5× trust multiplier because
--- players can lie.

local lib    = TTTBots.Lib
local Parser = TTTBots.ChatterParser  -- for findPlayersInText / isNameInMessage

-- ---------------------------------------------------------------------------
-- Doomguy alias normalization
-- ---------------------------------------------------------------------------

--- Patterns that all refer to the Doom Slayer.  Case-insensitive, applied before
--- any other processing so the rest of the code only needs to handle "doomguy".
local DOOMGUY_ALIASES = {
    "doom slayer",
    "doomslayer",
    "doom guy",
    "the slayer",
    "slayer",
    "doom$",      -- lone "doom" at end of sentence
    "^doom ",     -- lone "doom" at start of sentence
    " doom ",     -- lone "doom" mid-sentence
}

--- Normalize Doomguy alias variants in a transcript to the canonical "doomguy".
---@param text string  lowercase sanitized transcript
---@return string normalized, boolean wasDoomguy
local function normalizeDoomguyAliases(text)
    local wasDoomguy = false
    local normalized = text

    for _, pattern in ipairs(DOOMGUY_ALIASES) do
        local replaced, count = string.gsub(normalized, pattern, "doomguy")
        if count > 0 then
            wasDoomguy = true
            normalized = replaced
        end
    end

    return normalized, wasDoomguy
end

-- ---------------------------------------------------------------------------
-- Doomguy-specific STT event firing
-- ---------------------------------------------------------------------------

--- Fire Doomguy chatter events on nearby alive bots that use suspicion/innocents.
--- Called when a human mentions Doomguy in voice.
---@param sanitized string  normalized transcript
---@param speaker Player
local function fireDoomguyChatterEvents(sanitized, speaker)
    if not IsValid(speaker) then return end
    local speakerPos = speaker:GetPos()

    -- Determine which Doomguy event is most appropriate for the transcript.
    local eventName = "DoomguyAtLocation"   -- default: generic sighting
    local args      = { player = speaker:Nick(), location = "unknown area" }

    if string.find(sanitized, "chasing") or string.find(sanitized, "after me") or string.find(sanitized, "following me") then
        eventName = "DoomguyChasingMe"
    elseif string.find(sanitized, "weak") or string.find(sanitized, "low") or string.find(sanitized, "almost dead") then
        eventName = "DoomguyWeak"
    elseif string.find(sanitized, "spotted") or string.find(sanitized, "here") or string.find(sanitized, "near") or string.find(sanitized, "at") then
        eventName = "DoomguySpotted"
    end

    -- Fire the event on nearby bots (within 2500 units — voice range).
    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
        if speakerPos and bot:GetPos():Distance(speakerPos) > 2500 then continue end

        local chatter = bot:BotChatter()
        if not chatter then continue end

        -- Small stagger so all bots don't respond simultaneously.
        local delay = math.random() * 1.5
        chatter:On(eventName, args, false, delay)
    end
end

-- ---------------------------------------------------------------------------
-- Evidence type mapping
-- ---------------------------------------------------------------------------

--- Maps claim patterns to evidence types and base weight multipliers.
--- Each entry: { type=string, weight_mult=number }
local CLAIM_EVIDENCE_MAP = {
    kill      = { type = "WITNESSED_KILL",      weight_mult = 0.5 },
    killed    = { type = "WITNESSED_KILL",      weight_mult = 0.5 },
    murder    = { type = "WITNESSED_KILL",      weight_mult = 0.5 },
    murdered  = { type = "WITNESSED_KILL",      weight_mult = 0.5 },
    weapon    = { type = "TRAITOR_WEAPON",      weight_mult = 0.5 },
    c4        = { type = "TRAITOR_WEAPON",      weight_mult = 0.6 },
    sus       = { type = "SUSPICIOUS_MOVEMENT", weight_mult = 0.4 },
    suspicious= { type = "SUSPICIOUS_MOVEMENT", weight_mult = 0.4 },
    body      = { type = "BODY_FOUND_NEAR",     weight_mult = 0.4 },
    near      = { type = "BODY_FOUND_NEAR",     weight_mult = 0.4 },
}

-- Trust multiplier applied to ALL speech-sourced evidence entries.
local SPEECH_TRUST_MULT = 0.5

-- ---------------------------------------------------------------------------
-- Regex-based fast extraction
-- ---------------------------------------------------------------------------

--- Given a sanitized transcript and speaker, attempt to extract evidence
--- claims using pattern matching alone.
--- Returns a list of { subjectName, type, detail } tables, or empty.
---@param transcript string  lowercase, sanitized
---@param speaker Player
---@return table  array of claim tables
local function extractWithRegex(transcript, speaker)
    if not Parser or not Parser.findPlayersInText then return {} end

    local claims    = {}
    local mentioned = Parser.findPlayersInText(transcript)
    if not mentioned or #mentioned == 0 then return {} end

    for keyword, evidenceInfo in pairs(CLAIM_EVIDENCE_MAP) do
        if string.find(transcript, keyword, 1, true) then
            -- Associate claim with first mentioned player
            local subject = mentioned[1]
            local victim  = mentioned[2] or nil  -- second name = possible victim

            table.insert(claims, {
                subject = subject,
                victim  = victim,
                type    = evidenceInfo.type,
                weightMult = evidenceInfo.weight_mult,
                detail  = string.format("heard player say '%s' in relation to %s", keyword, IsValid(subject) and subject:Nick() or "?"),
            })
            break  -- one claim per transcript to avoid over-penalising
        end
    end

    return claims
end

-- ---------------------------------------------------------------------------
-- LLM-based extraction (fallback)
-- ---------------------------------------------------------------------------

--- Build a simple structured-extraction prompt for Ollama.
--- Asks the model for a JSON object (we handle the parse ourselves).
---@param transcript string
---@return string system, string prompt
local function buildExtractionPrompt(transcript)
    local system = (
        "You are an evidence extractor for a game of TTT. "
        .. "Read a voice transcript and decide if it contains an accusation or evidence claim. "
        .. "Output ONLY a single JSON object: "
        .. "{\"subject\":\"PlayerName or null\",\"type\":\"WITNESSED_KILL|SUSPICIOUS_MOVEMENT|TRAITOR_WEAPON|BODY_FOUND_NEAR|null\"}. "
        .. "If no claim, output {\"subject\":null,\"type\":null}. "
        .. "Do NOT output anything else."
    )
    local prompt = "Transcript: " .. transcript
    return system, prompt
end

--- Parse a minimal JSON object from a raw LLM response string.
--- Returns subject string and type string, or nil/nil.
---@param raw string
---@return string|nil subjectName, string|nil evidenceType
local function parseExtractionResponse(raw)
    if not raw or raw == "" then return nil, nil end

    local subject = raw:match('"subject"%s*:%s*"([^"]+)"')
    local evType  = raw:match('"type"%s*:%s*"([^"]+)"')

    if subject == "null" or subject == "" then subject = nil end
    if evType  == "null" or evType  == "" then evType  = nil end

    return subject, evType
end

-- ---------------------------------------------------------------------------
-- Evidence application
-- ---------------------------------------------------------------------------

--- Valid evidence types the speech extractor is allowed to create.
local VALID_TYPES = {
    WITNESSED_KILL      = true,
    SUSPICIOUS_MOVEMENT = true,
    TRAITOR_WEAPON      = true,
    BODY_FOUND_NEAR     = true,
}

--- Apply a list of extracted claims to nearby alive bots' evidence components.
---@param claims table
---@param speaker Player
local function applyClaims(claims, speaker)
    if not claims or #claims == 0 then return end

    local speakerPos = IsValid(speaker) and speaker:GetPos() or nil

    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
        local roleData = TTTBots.Roles.GetRoleFor(bot)
        if not (roleData and roleData:GetUsesSuspicion()) then continue end
        local evidence = bot:BotEvidence()
        if not evidence then continue end

        -- Only share with bots in reasonable range (2000 units) — voice carries
        if speakerPos then
            local dist = bot:GetPos():Distance(speakerPos)
            if dist > 2000 then continue end
        end

        for _, claim in ipairs(claims) do
            local subject = claim.subject
            if not (IsValid(subject) and subject:IsPlayer()) then continue end
            if not VALID_TYPES[claim.type] then continue end

            local baseWeight = (evidence.EvidenceWeights and evidence.EvidenceWeights[claim.type]) or 3
            local speechWeight = math.max(1, math.floor(baseWeight * (claim.weightMult or SPEECH_TRUST_MULT)))

            evidence:AddEvidence({
                type    = claim.type,
                subject = subject,
                victim  = claim.victim,
                detail  = claim.detail or ("heard player say it"),
                weight  = speechWeight,
            })
        end
    end
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

TTTBots.STTEvidence = TTTBots.STTEvidence or {}

--- Process a voice transcript for evidence claims.
--- Called from sv_chatter_stt.lua BEFORE RespondToPlayerMessage.
--- Does not block — LLM path fires async.
---@param transcript string  Raw (un-sanitized) transcript text
---@param sanitized string   Pre-sanitized lowercase version
---@param speaker Player
function TTTBots.STTEvidence.Process(transcript, sanitized, speaker)
    if not IsValid(speaker) then return end
    if not TTTBots.Match.RoundActive then return end

    -- Normalize Doomguy aliases so downstream patterns find "doomguy" consistently.
    local normalized, wasDoomguy = normalizeDoomguyAliases(sanitized)

    -- If the transcript contained a Doomguy reference, fire lobby-wide chatter events
    -- and treat the mention as high-priority threat intel for nearby bots.
    if wasDoomguy then
        fireDoomguyChatterEvents(normalized, speaker)
        -- Record the Doomguy mention in nearby bot memory so LLM prompts have context.
        local speakerName = speaker:Nick()
        local speakerPosForMem = IsValid(speaker) and speaker:GetPos() or nil
        for _, bot in ipairs(TTTBots.Bots or {}) do
            local mem = bot:BotMemory()
            if not (IsValid(bot) and mem) then continue end
            if speakerPosForMem and bot:GetPos():Distance(speakerPosForMem) > 2500 then continue end
            mem:AddWitnessEvent("speech", string.format("%s mentioned doomguy: %s", speakerName, normalized:sub(1, 60)))
        end
    end

    -- Use the normalized text for all further evidence extraction.
    local sanitizedForExtraction = normalized

    -- Fast regex pass
    local claims = extractWithRegex(sanitizedForExtraction, speaker)

    if #claims > 0 then
        applyClaims(claims, speaker)
        -- Record in nearby bot memory ring buffers for LLM context
        local speakerName = speaker:Nick()
        for _, bot in ipairs(TTTBots.Bots or {}) do
            local mem = bot:BotMemory()
            if not (IsValid(bot) and mem) then continue end
            mem:AddWitnessEvent("speech", string.format("%s said: %s", speakerName, sanitizedForExtraction:sub(1, 60)))
        end
        return  -- regex was enough, skip LLM extraction
    end

    -- LLM fallback — only if Ollama is the active provider or Ollama is reachable
    local providerInt = lib.GetConVarInt("chatter_api_provider")
    if not TTTBots.Ollama or not TTTBots.Ollama.SendText then return end
    if not TTTBots.Match.RoundActive then return end

    local system, prompt = buildExtractionPrompt(sanitizedForExtraction)

    -- Use a dummy "bot" for the Ollama call — pick the first alive bot
    local dummyBot = nil
    for _, b in ipairs(TTTBots.Bots or {}) do
        if IsValid(b) and lib.IsPlayerAlive(b) then
            dummyBot = b
            break
        end
    end
    if not dummyBot then return end

    -- Low token budget for extraction — small and fast
    local opts = {
        system       = system,
        num_predict  = 40,
        num_ctx      = 512,
        temperature  = 0.1,
        stop         = { "\n", "Transcript:" },
        accusation   = false,
    }

    -- Capture speaker identity before async call — entity may disconnect during HTTP round-trip.
    local speakerNameForLLM = IsValid(speaker) and speaker:Nick() or "unknown"

    TTTBots.Ollama.SendText(prompt, dummyBot, opts, function(envelope)
        if not envelope.ok then return end
        if not TTTBots.Match.RoundActive then return end

        local subjectName, evType = parseExtractionResponse(envelope.text or "")
        if not subjectName or not evType then return end
        if not VALID_TYPES[evType] then return end

        -- Resolve player name to entity
        local subject = nil
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Nick():lower() == subjectName:lower() then
                subject = ply
                break
            end
        end
        if not IsValid(subject) then return end

        local llmClaims = { {
            subject    = subject,
            type       = evType,
            weightMult = SPEECH_TRUST_MULT,
            detail     = string.format("extracted from speech by %s", speakerNameForLLM),
        } }

        applyClaims(llmClaims, IsValid(speaker) and speaker or nil)

        -- Record in nearby bot witness ring buffers
        for _, bot in ipairs(TTTBots.Bots or {}) do
            local mem = bot:BotMemory()
            if not (IsValid(bot) and mem) then continue end
            mem:AddWitnessEvent("speech", string.format("%s mentioned %s (%s)", speakerNameForLLM, subject:Nick(), evType))
        end
    end)
end
