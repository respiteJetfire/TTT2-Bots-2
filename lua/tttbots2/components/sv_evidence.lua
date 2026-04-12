--- sv_evidence.lua
--- Evidence Reasoning Engine component.
--- Tracks timestamped evidence entries per suspect, calculates evidence-weighted
--- suspicion scores, manages the trust network (vouching / travel companions /
--- confirmed innocents), and exposes helpers for the Accuse / DefendSelf behaviors.
---
--- Integration points:
---   • CMorality hooks call evidence:AddEvidence() when witness events fire
---   • AccusePlayer behavior reads EvidenceWeight() / GetStrongestEvidence()
---   • DefendSelf behavior reads trustNetwork for alibi generation
---   • CChatter calls On("WitnessCallout", ...) with evidence context
---   • Match.ResetStats hook clears per-round data

---@class CEvidence : Component
TTTBots.Components.Evidence = TTTBots.Components.Evidence or {}

local lib = TTTBots.Lib
---@class CEvidence : Component
local BotEvidence = TTTBots.Components.Evidence

-- ===========================================================================
-- Static data — evidence type weights
-- ===========================================================================

--- Base suspicion contribution of each evidence type.
--- These are modulated by personality traits at runtime.
BotEvidence.EvidenceWeights = {
    WITNESSED_KILL      = 12,   -- Bot directly saw suspect kill someone
    NEAR_BODY           = 4,    -- Suspect was near an unidentified body for >3s
    TRAITOR_WEAPON      = 5,    -- Suspect was seen holding a traitor weapon
    FAILED_TEST         = 8,    -- Suspect failed a role-checker test
    REFUSED_TEST        = 6,    -- Suspect refused to use a role-checker
    ABSENT_FROM_GROUP   = 3,    -- Suspect didn't respond to life-check
    DNA_MATCH           = 10,   -- DNA scanner linked suspect to a corpse
    ALIBI_CONFIRMED     = -8,   -- Someone confirmed suspect's whereabouts
    ALIBI_BROKEN        = 7,    -- Suspect's stated alibi was disproved
    KOS_CALLED_BY       = 5,    -- Another player called KOS on suspect
    KOS_BY_DETECTIVE    = 11,   -- A detective/police role called KOS on suspect (high authority)
    BODY_FOUND_NEAR     = 3,    -- Suspect was in area when body was found
    SUSPICIOUS_MOVEMENT = 2,    -- General suspicious behavior
    -- Spy role events
    SPY_INTEL           = 8,    -- Spy-gathered intelligence on traitor identity/behavior
    -- Cursed role events
    CURSE_WITNESSED     = 3,    -- Saw someone become Cursed (neutral, but noteworthy)
    CURSE_SWAP_WITNESSED = 2,   -- Witnessed a Cursed role swap event
    CURSE_APPROACHING   = 1,    -- Cursed player approaching (low weight, just awareness)
    -- Clairvoyant role events
    CLAIRVOYANT_INTEL   = 3,    -- Clairvoyant detected player as having a special role
    -- Clown role events
    CLOWN_TRANSFORMED   = 10,   -- The Clown transformed into Killer Clown (public event)
}

--- Minimum total evidence weight before bot considers suspect KOS-worthy.
--- Overridden per-personality in EvidenceWeight().
BotEvidence.KOSWeightThreshold   = 14
BotEvidence.AccuseWeightThreshold = 7
BotEvidence.SoftSusThreshold      = 3

--- Max age (seconds) before an evidence entry starts decaying (halved weight).
BotEvidence.EvidenceDecayTime = 90
--- Age (seconds) after decay before entry is pruned entirely.
BotEvidence.EvidencePruneTime = 180

--- How long a travel-companion relationship must be continuous (seconds) before
--- it counts for an alibi vouch.
BotEvidence.CompanionMinTime = 20

--- Distance threshold (units) to count as "together" for travel-companion tracking.
BotEvidence.CompanionDistance = 400

--- Trust decay: vouches older than this many seconds lose their weight.
BotEvidence.TrustDecayTime = 120

-- ===========================================================================
-- Component lifecycle
-- ===========================================================================

function BotEvidence:New(bot)
    local newEvidence = {}
    setmetatable(newEvidence, {
        __index = function(t, k) return BotEvidence[k] end,
    })
    newEvidence:Initialize(bot)
    return newEvidence
end

function BotEvidence:Initialize(bot)
    bot.components         = bot.components or {}
    bot.components.evidence = self

    self.componentID = string.format("Evidence (%s)", lib.GenerateID())
    self.ThinkRate   = 3 -- Run every 3rd tick (~1.7Hz)
    self.bot         = bot ---@type Bot

    self:ClearRoundEvidence()
end

--- Wipe all round-scoped evidence and trust state. Called on round end.
function BotEvidence:ClearRoundEvidence()
    self.log = {}          -- { type, subject, victim, time, location, detail, weight }
    self.trustNetwork = {
        confirmedInnocent = {},   -- [player] = { reason, time }
        travelCompanions  = {},   -- [player] = { since, continuous, lastSeen }
        vouchedBy         = {},   -- [player] = { voucher, time }
    }
    self.accuseCooldowns = {}  -- [player] = CurTime() of last accusation
    self.lifeCheckTime   = 0
    self.lifeCheckRespondents = {}
end

function BotEvidence:Think()
    self:DecayEvidence()
    self:UpdateTravelCompanions()
    self:DecayTrust()
end

-- ===========================================================================
-- Evidence log management
-- ===========================================================================

--- Add a new evidence entry for a suspect.
--- Fires RecalcSuspicion() to update morality immediately.
---@param entry table  { type=string, subject=Player, [victim=Player], [detail=string], [location=string] }
function BotEvidence:AddEvidence(entry)
    if not (IsValid(entry.subject) and entry.subject:IsPlayer()) then return end
    if entry.subject == self.bot then return end
    if not TTTBots.Match.RoundActive then return end

    local baseWeight = self.EvidenceWeights[entry.type] or 1
    entry.time     = entry.time or CurTime()
    entry.weight   = entry.weight or baseWeight
    entry.location = entry.location or "unknown"
    entry.detail   = entry.detail or ""

    table.insert(self.log, entry)
    self:RecalcSuspicion(entry.subject)

    -- Auto-break trust if the vouched player just committed something serious
    if entry.type == "WITNESSED_KILL" or entry.type == "TRAITOR_WEAPON" or entry.type == "DNA_MATCH" then
        self:BreakTrust(entry.subject, entry.type)
    end
end

--- Called after any evidence change; updates the morality suspicion score
--- for the given player based on pure evidence weighting.
--- Only applied if morality uses suspicion for this bot.
---@param target Player
function BotEvidence:RecalcSuspicion(target)
    if not (IsValid(target) and target:IsPlayer()) then return end
    local morality = self.bot:BotMorality()
    if not morality then return end
    if not TTTBots.Roles.GetRoleFor(self.bot):GetUsesSuspicion() then return end

    local score = self:EvidenceWeight(target)
    -- Blend with existing raw suspicion: evidence provides a floor
    local current = morality:GetSuspicion(target)
    if score > current then
        morality:SetSuspicionDirect(target, score)
        morality:AnnounceIfThreshold(target)
        morality:SetAttackIfTargetSus(target)
    end
end

--- Calculate the total evidence-weighted suspicion score for a given player.
--- Modulated by the bot's personality traits.
---@param target Player
---@return number
function BotEvidence:EvidenceWeight(target)
    if not (IsValid(target) and target:IsPlayer()) then return 0 end

    local total      = 0
    local now        = CurTime()
    local personality = self.bot:BotPersonality()
    local susMult    = personality and personality:GetTraitMult("suspicion") or 1.0
    local decayTime  = lib.GetConVarInt("evidence_decay_time") or self.EvidenceDecayTime

    for _, entry in ipairs(self.log) do
        if entry.subject ~= target then continue end
        local age = now - entry.time
        local w   = entry.weight

        -- Decay: halve weight for aged evidence
        if age > decayTime then
            w = w * 0.5
        end
        total = total + w
    end

    return math.Round(total * susMult)
end

--- Return the single most damning evidence entry for a player.
--- Used by AccusePlayer to compose a natural-language callout.
---@param target Player
---@return table|nil
function BotEvidence:GetStrongestEvidence(target)
    local best   = nil
    local bestW  = -math.huge
    for _, entry in ipairs(self.log) do
        if entry.subject ~= target then continue end
        if entry.weight > bestW then
            bestW = entry.weight
            best  = entry
        end
    end
    return best
end

--- Returns true if the bot has articulable evidence against a player.
--- "Sus" archetype ignores the check (always returns true if any evidence exists).
---@param target Player
---@return boolean
function BotEvidence:CanExplainSuspicion(target)
    local personality = self.bot:BotPersonality()
    local archetype   = personality and personality:GetClosestArchetype() or "Default"
    if archetype == TTTBots.Archetypes.Sus then
        -- Sus archetype accuses with minimal evidence
        return self:EvidenceWeight(target) > 0
    end
    return self:GetStrongestEvidence(target) ~= nil
        and self:EvidenceWeight(target) >= (lib.GetConVarInt("evidence_soft_threshold") or self.SoftSusThreshold)
end

--- Copy qualifying evidence entries from this bot to another bot's Evidence component.
---@param otherBot Bot
function BotEvidence:ShareEvidence(otherBot)
    if not (IsValid(otherBot) and otherBot.components and otherBot.components.evidence) then return end
    local theirEvidence = otherBot.components.evidence
    local now = CurTime()

    for _, entry in ipairs(self.log) do
        -- Only share strong, recent entries
        if entry.weight < 4 then continue end
        if (now - entry.time) > 60 then continue end

        -- Dedup: skip if they already have a same-type+subject entry within 10s
        local duplicate = false
        for _, theirEntry in ipairs(theirEvidence.log) do
            if theirEntry.type == entry.type and theirEntry.subject == entry.subject then
                if math.abs(theirEntry.time - entry.time) < 10 then
                    duplicate = true
                    break
                end
            end
        end
        if not duplicate then
            local copy = table.Copy(entry)
            table.insert(theirEvidence.log, copy)
            theirEvidence:RecalcSuspicion(entry.subject)
        end
    end
end

--- Retrieve all suspects with at least minWeight evidence score.
---@param minWeight number
---@return table<Player>
function BotEvidence:GetSuspects(minWeight)
    minWeight = minWeight or lib.GetConVarInt("evidence_soft_threshold") or self.SoftSusThreshold
    local seen    = {}
    local results = {}
    for _, entry in ipairs(self.log) do
        if not seen[entry.subject] then
            seen[entry.subject] = true
            if self:EvidenceWeight(entry.subject) >= minWeight then
                table.insert(results, entry.subject)
            end
        end
    end
    return results
end

--- Prune stale entries from the log.
function BotEvidence:DecayEvidence()
    if not TTTBots.Match.RoundActive then return end
    local now      = CurTime()
    local pruneAge = lib.GetConVarInt("evidence_prune_time") or self.EvidencePruneTime
    local pruned   = {}
    for _, entry in ipairs(self.log) do
        local age = now - entry.time
        if age <= pruneAge then
            table.insert(pruned, entry)
        end
    end
    self.log = pruned
end

-- ===========================================================================
-- Trust Network
-- ===========================================================================

--- Mark a player as confirmed innocent (e.g. tested clean, alibi confirmed).
---@param target Player
---@param reason string
function BotEvidence:ConfirmInnocent(target, reason)
    if not (IsValid(target) and target:IsPlayer()) then return end
    self.trustNetwork.confirmedInnocent[target] = { reason = reason, time = CurTime() }
    -- Also add a positive evidence entry so it surfaces in suspicion calcs
    self:AddEvidence({
        type    = "ALIBI_CONFIRMED",
        subject = target,
        detail  = reason,
    })
    -- If morality has them flagged, reduce suspicion toward innocent
    local morality = self.bot:BotMorality()
    if morality then
        local cur = morality:GetSuspicion(target)
        if cur > 0 then
            morality:SetSuspicionDirect(target, math.max(cur - 8, -5))
        end
    end
end

--- Record that this bot has been travelling with another player.
--- Should be called from the Think tick when players are near each other.
---@param target Player
function BotEvidence:AddTravelCompanion(target)
    if not (IsValid(target) and target:IsPlayer()) then return end
    if target == self.bot then return end
    local tn = self.trustNetwork.travelCompanions
    if not tn[target] then
        tn[target] = { since = CurTime(), continuous = true, lastSeen = CurTime() }
    else
        tn[target].lastSeen   = CurTime()
        tn[target].continuous = true
    end
end

--- Add a vouch from another player (transitive trust: detective-vouched = trusted).
---@param target Player
---@param voucher Player
function BotEvidence:Vouch(target, voucher)
    if not (IsValid(target) and target:IsPlayer()) then return end
    self.trustNetwork.vouchedBy[target] = { voucher = voucher, time = CurTime() }
end

--- Revoke trust for a player whose actions contradicted their vouched status.
---@param target Player
---@param reason string
function BotEvidence:BreakTrust(target, reason)
    if not (IsValid(target) and target:IsPlayer()) then return end
    local changed = false
    if self.trustNetwork.confirmedInnocent[target] then
        self.trustNetwork.confirmedInnocent[target] = nil
        changed = true
    end
    if self.trustNetwork.vouchedBy[target] then
        self.trustNetwork.vouchedBy[target] = nil
        changed = true
    end
    if changed then
        local chatter = self.bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("BreakTrust", { player = target:Nick() })
        end
    end
end

--- Returns the continuous travel-companion duration in seconds, or 0.
---@param target Player
---@return number
function BotEvidence:GetCompanionDuration(target)
    local entry = self.trustNetwork.travelCompanions[target]
    if not entry then return 0 end
    if not entry.continuous then return 0 end
    return CurTime() - entry.since
end

--- Returns true if the bot has a confirmed companion that can alibi them.
---@return Player|nil  The companion if found.
function BotEvidence:GetBestAlibieCompanion()
    for ply, entry in pairs(self.trustNetwork.travelCompanions) do
        if not IsValid(ply) then continue end
        if (CurTime() - entry.since) >= (lib.GetConVarInt("evidence_companion_min_time") or self.CompanionMinTime) and entry.continuous then
            return ply
        end
    end
    return nil
end

--- Periodic update of travelCompanions based on proximity.
function BotEvidence:UpdateTravelCompanions()
    if not TTTBots.Match.RoundActive then return end
    if not lib.IsPlayerAlive(self.bot) then return end

    local myPos = self.bot:GetPos()
    local alivePlayers = TTTBots.Match.AlivePlayers or {}

    for _, ply in pairs(alivePlayers) do
        if not IsValid(ply) or ply == self.bot then continue end
        local dist = myPos:Distance(ply:GetPos())
        if dist < self.CompanionDistance then
            self:AddTravelCompanion(ply)
        else
            -- Mark as non-continuous if they've drifted away
            local entry = self.trustNetwork.travelCompanions[ply]
            if entry and entry.continuous then
                local gapTime = CurTime() - (entry.lastSeen or 0)
                if gapTime > 10 then
                    entry.continuous = false
                end
            end
        end
    end
end

--- Expire old vouch records.
function BotEvidence:DecayTrust()
    local now       = CurTime()
    local decayTime = lib.GetConVarInt("evidence_trust_decay_time") or self.TrustDecayTime
    for ply, entry in pairs(self.trustNetwork.vouchedBy) do
        if (now - entry.time) > decayTime then
            self.trustNetwork.vouchedBy[ply] = nil
        end
    end
    -- Expire confirmed-innocent records older than 150s (players may have changed)
    for ply, entry in pairs(self.trustNetwork.confirmedInnocent) do
        if (now - entry.time) > 150 then
            self.trustNetwork.confirmedInnocent[ply] = nil
        end
    end
end

-- ===========================================================================
-- Evidence summary for LLM prompts (9.3)
-- ===========================================================================

--- Human-readable type labels for evidence entries.
local EVIDENCE_LABELS = {
    WITNESSED_KILL      = "witnessed kill",
    NEAR_BODY           = "found near body",
    TRAITOR_WEAPON      = "carrying traitor weapon",
    FAILED_TEST         = "failed role test",
    REFUSED_TEST        = "refused role test",
    ABSENT_FROM_GROUP   = "absent from group",
    DNA_MATCH           = "DNA match",
    ALIBI_BROKEN        = "alibi disproved",
    KOS_CALLED_BY       = "KOS called by others",
    KOS_BY_DETECTIVE    = "KOS called by detective",
    BODY_FOUND_NEAR     = "found near a body",
    SUSPICIOUS_MOVEMENT = "suspicious movement",
    SPY_INTEL           = "spy intelligence",
}

--- Build a compact, natural-language evidence brief for a suspect.
--- Used by GetAccusationPrompt (9.3) to feed the LLM concrete evidence.
--- Capped at ~200 characters to stay within small context windows.
---@param suspect Player
---@return string  e.g. "witnessed kill (Alex, at storage); DNA match; refused role test"
function BotEvidence:FormatEvidenceSummary(suspect)
    if not (IsValid(suspect) and suspect:IsPlayer()) then return "no evidence" end

    local now     = CurTime()
    local entries = {}

    for _, entry in ipairs(self.log) do
        if entry.subject ~= suspect then continue end
        local age   = now - (entry.time or 0)
        local label = EVIDENCE_LABELS[entry.type] or entry.type

        local detail = ""
        if entry.victim and IsValid(entry.victim) then
            detail = detail .. entry.victim:Nick()
        end
        if entry.location and entry.location ~= "" and entry.location ~= "unknown" then
            detail = detail ~= "" and (detail .. " at " .. entry.location) or ("at " .. entry.location)
        elseif entry.detail and entry.detail ~= "" and not entry.victim then
            detail = entry.detail
        end

        local piece = label
        if detail ~= "" then
            piece = piece .. " (" .. detail .. ")"
        end
        if age > 60 then
            piece = piece .. " ~" .. math.floor(age) .. "s ago"
        end

        table.insert(entries, { text = piece, weight = entry.weight or 1, time = entry.time or 0 })
    end

    if #entries == 0 then return "no specific evidence" end

    -- Sort by weight descending, keep top 4
    table.sort(entries, function(a, b) return a.weight > b.weight end)

    local parts = {}
    for i = 1, math.min(4, #entries) do
        table.insert(parts, entries[i].text)
    end

    local summary = table.concat(parts, "; ")

    -- Hard cap
    if #summary > 200 then
        summary = summary:sub(1, 197) .. "..."
    end

    return summary
end

-- ===========================================================================
-- Accusation cooldown helpers
-- ===========================================================================

--- True if this bot has accused the target recently (within cooldown window).
---@param target Player
---@param cooldown number seconds, default 60
---@return boolean
function BotEvidence:HasAccusedRecently(target, cooldown)
    cooldown = cooldown or 60
    local last = self.accuseCooldowns[target] or 0
    return (CurTime() - last) < cooldown
end

--- Mark the target as recently accused.
---@param target Player
function BotEvidence:RecordAccusation(target)
    self.accuseCooldowns[target] = CurTime()
end

-- ===========================================================================
-- Life-check tracking
-- ===========================================================================

--- Record that the bot is starting a life-check; store time.
function BotEvidence:StartLifeCheck()
    self.lifeCheckTime        = CurTime()
    self.lifeCheckRespondents = {}
end

--- Record that a player responded to a life-check.
---@param ply Player
function BotEvidence:RecordLifeCheckResponse(ply)
    self.lifeCheckRespondents[ply] = CurTime()
end

--- After LIFE_CHECK_WINDOW seconds, bots that haven't responded get ABSENT_FROM_GROUP evidence.
local LIFE_CHECK_WINDOW = 15
function BotEvidence:ProcessLifeCheckResults()
    if self.lifeCheckTime == 0 then return end
    local now = CurTime()
    if (now - self.lifeCheckTime) < LIFE_CHECK_WINDOW then return end

    local alivePlayers = TTTBots.Match.AlivePlayers or {}
    for _, ply in pairs(alivePlayers) do
        if not IsValid(ply) or ply == self.bot then continue end
        if not self.lifeCheckRespondents[ply] then
            self:AddEvidence({
                type    = "ABSENT_FROM_GROUP",
                subject = ply,
                detail  = "did not respond to life check",
            })
        end
    end
    self.lifeCheckTime = 0
end

-- ===========================================================================
-- Round reset hook
-- ===========================================================================

hook.Add("TTTEndRound", "TTTBots.Evidence.RoundReset", function()
    for _, bot in pairs(TTTBots.Lib.GetAliveBots()) do
        if bot.components and bot.components.evidence then
            bot.components.evidence:ClearRoundEvidence()
        end
    end
    -- Also reset for dead bots
    for _, bot in ipairs(TTTBots.Bots or {}) do
        if IsValid(bot) and bot.components and bot.components.evidence then
            bot.components.evidence:ClearRoundEvidence()
        end
    end
end)

-- ===========================================================================
-- Player meta accessor
-- ===========================================================================

---@class Player
local plyMeta = FindMetaTable("Player")
function plyMeta:BotEvidence()
    ---@cast self Bot
    return self.components and self.components.evidence
end
