--- sv_chatter_stt_evidence.lua
--- Tier 8 — 9.4: STT-Driven Evidence Processing
---
--- Sits between the STT transcript polling (sv_chatter_stt.lua) and the
--- keyword command router (RespondToPlayerMessage).  For every voice
--- transcript it:
---   1. Runs fast regex-based extraction for common claim patterns.
---   2. Falls back to an LLM extraction call (Ollama JSON mode) if regex
---      finds nothing AND the LLM provider is available.
---   3. Maps extracted claims to evidence entries on nearby bots.
---   4. Returns so the caller can still route the transcript through
---      RespondToPlayerMessage for command matching / conversational replies.
---
--- Speech-extracted evidence carries a 0.5× trust multiplier because
--- players can lie.

local lib    = TTTBots.Lib
local Parser = TTTBots.ChatterParser  -- for findPlayersInText / isNameInMessage

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
        if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then continue end
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

    -- Fast regex pass
    local claims = extractWithRegex(sanitized, speaker)

    if #claims > 0 then
        applyClaims(claims, speaker)
        -- Record in nearby bot memory ring buffers for LLM context
        local speakerName = speaker:Nick()
        for _, bot in ipairs(TTTBots.Bots or {}) do
            if not (IsValid(bot) and bot:BotMemory()) then continue end
            bot:BotMemory():AddWitnessEvent("speech", string.format("%s said: %s", speakerName, sanitized:sub(1, 60)))
        end
        return  -- regex was enough, skip LLM extraction
    end

    -- LLM fallback — only if Ollama is the active provider or Ollama is reachable
    local providerInt = lib.GetConVarInt("chatter_api_provider")
    if not TTTBots.Ollama or not TTTBots.Ollama.SendText then return end
    if not TTTBots.Match.RoundActive then return end

    local system, prompt = buildExtractionPrompt(sanitized)

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
        stop         = { "\n", "}", "Transcript:" },
        accusation   = false,
    }

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
            detail     = string.format("extracted from speech by %s", speaker:Nick()),
        } }

        applyClaims(llmClaims, speaker)

        -- Record in nearby bot witness ring buffers
        local speakerName = speaker:Nick()
        for _, bot in ipairs(TTTBots.Bots or {}) do
            if not (IsValid(bot) and bot:BotMemory()) then continue end
            bot:BotMemory():AddWitnessEvent("speech", string.format("%s mentioned %s (%s)", speakerName, subject:Nick(), evType))
        end
    end)
end
