--- sv_morality_suspicion.lua
--- Witness events, suspicion tracking, and announcement logic.
--- Extracted from sv_morality.lua — all suspicion-related instance methods
--- remain on BotMorality; global hooks and timers live here.
---
--- ARCHITECTURE: Multi-Dimensional Suspicion Model
--- ================================================
--- Instead of a single integer per target, suspicion is now tracked across
--- three independent channels per target:
---
---   threat     (0–20)  Accumulated hostile evidence (kills, KOS, weapons, etc.)
---   trust      (0–20)  Accumulated innocent evidence (defusing C4, killing traitors, etc.)
---   confidence (0–1)   How much the bot trusts its own observations.
---                      1.0 = direct witness, 0.7 = hearsay (KOS calls),
---                      0.4 = paranoia/noise. Blended per-event via weighted average.
---
--- Effective suspicion = floor((threat - trust) * confidence)
---
--- This preserves backward compatibility: GetSuspicion() still returns a
--- single integer that all existing threshold checks, attack decisions, and
--- announcement logic can consume without changes.
---
--- Benefits over the old single-integer model:
---  • A player who kills AND defuses C4 no longer nets out to a misleading
---    middle value — the high threat AND high trust are both visible.
---  • Confidence prevents hearsay and paranoia from carrying the same weight
---    as direct witness events.
---  • Per-target announcement cooldowns prevent chatter spam from threshold
---    oscillation.
---  • Channels decay independently, allowing trust to persist longer than
---    threat (reflecting how TTT players remember good deeds).

local lib = TTTBots.Lib

---@class CMorality : Component
local BotMorality = TTTBots.Components.Morality

local Arb = TTTBots.Morality  -- arbitration gateway
local PRI = Arb.PRIORITY

-- ===========================================================================
-- Static data tables
-- ===========================================================================

--- Legacy flat table kept for backward compatibility with hooks and external
--- addons that read SUSPICIONVALUES[reason]. Each value is the net delta that
--- the old system applied. The new system uses SUSPICION_EVENTS instead.
BotMorality.SUSPICIONVALUES = {
    Kill = 4, KillTrusted = 10, KillMedic = 15, KillTraitor = -15,
    Hurt = 2, HurtMe = 6, HurtTrusted = 6, HurtByTrusted = 2, HurtByEvil = -5,
    KOSByInnocent = 7, KOSByTrusted = 15, KOSByDetective = 20,
    KOSByTraitor = -5, KOSByOther = 5, AffirmingKOS = -3,
    TraitorWeapon = 3, NearUnidentified = 2,
    IdentifiedTraitor = -2, IdentifiedInnocent = 0, IdentifiedTrusted = 0,
    DefuseC4 = -7, PlantC4 = 10,
    FollowingMe = 3, FollowingMeLong = -6,
    ShotAtMe = 5, ShotAt = 3, ShotAtTrusted = 4,
    ThrowDiscombob = 2, ThrowIncin = 5, ThrowSmoke = 2, PersonalSpace = 2,
    InfectionWitnessed = 10, ZombieModel = 8,
    CurseWitnessed = 3, CurseSwapWitnessed = 2, CursedApproaching = 1, CursedImmune = 0,
    AnkhConversionWitnessed = 10, AnkhDestructionWitnessed = 5, AnkhLoiteringNearby = 2,
    SmartBulletsVisual = 8, SmartBulletsAudio = 4,
    RoleConfirmedHostile = 20, RoleConfirmedAlly = -10,
}

--- Multi-dimensional event definitions.
--- Each reason maps to { threat, trust, confidence }.
---   threat:     how much to add to the threat channel (≥ 0)
---   trust:      how much to add to the trust channel (≥ 0)
---   confidence: observation quality (1.0 = direct witness, 0.7 = hearsay, 0.4 = noise)
BotMorality.SUSPICION_EVENTS = {
    -- Direct witness: killing
    Kill                    = { threat = 4,  trust = 0,  confidence = 1.0 },
    KillTrusted             = { threat = 10, trust = 0,  confidence = 1.0 },
    KillMedic               = { threat = 15, trust = 0,  confidence = 1.0 },
    KillTraitor             = { threat = 0,  trust = 15, confidence = 1.0 },
    -- Direct witness: hurting
    Hurt                    = { threat = 2,  trust = 0,  confidence = 1.0 },
    HurtMe                  = { threat = 6,  trust = 0,  confidence = 1.0 },
    HurtTrusted             = { threat = 6,  trust = 0,  confidence = 1.0 },
    HurtByTrusted           = { threat = 2,  trust = 0,  confidence = 0.8 },
    HurtByEvil              = { threat = 0,  trust = 5,  confidence = 0.8 },
    -- Hearsay: KOS calls (lower confidence — we didn't see it ourselves)
    KOSByInnocent           = { threat = 7,  trust = 0,  confidence = 0.7 },
    KOSByTrusted            = { threat = 15, trust = 0,  confidence = 0.8 },
    KOSByDetective          = { threat = 20, trust = 0,  confidence = 0.95 },
    KOSByTraitor            = { threat = 0,  trust = 5,  confidence = 0.7 },
    KOSByOther              = { threat = 5,  trust = 0,  confidence = 0.6 },
    AffirmingKOS            = { threat = 0,  trust = 3,  confidence = 0.7 },
    -- Behavioral observations
    TraitorWeapon           = { threat = 3,  trust = 0,  confidence = 0.9 },
    NearUnidentified        = { threat = 2,  trust = 0,  confidence = 0.8 },
    IdentifiedTraitor       = { threat = 0,  trust = 2,  confidence = 0.9 },
    IdentifiedInnocent      = { threat = 0,  trust = 0,  confidence = 0.5 },
    IdentifiedTrusted       = { threat = 0,  trust = 0,  confidence = 0.5 },
    DefuseC4                = { threat = 0,  trust = 7,  confidence = 1.0 },
    PlantC4                 = { threat = 10, trust = 0,  confidence = 1.0 },
    FollowingMe             = { threat = 3,  trust = 0,  confidence = 0.6 },
    FollowingMeLong         = { threat = 0,  trust = 6,  confidence = 0.7 },
    ShotAtMe                = { threat = 5,  trust = 0,  confidence = 1.0 },
    ShotAt                  = { threat = 3,  trust = 0,  confidence = 0.8 },
    ShotAtTrusted           = { threat = 4,  trust = 0,  confidence = 0.9 },
    ThrowDiscombob          = { threat = 2,  trust = 0,  confidence = 0.8 },
    ThrowIncin              = { threat = 5,  trust = 0,  confidence = 0.9 },
    ThrowSmoke              = { threat = 2,  trust = 0,  confidence = 0.7 },
    PersonalSpace           = { threat = 2,  trust = 0,  confidence = 0.5 },
    -- Infected role events
    InfectionWitnessed      = { threat = 10, trust = 0,  confidence = 1.0 },
    ZombieModel             = { threat = 8,  trust = 0,  confidence = 0.9 },
    -- Cursed role events
    CurseWitnessed          = { threat = 3,  trust = 0,  confidence = 0.8 },
    CurseSwapWitnessed      = { threat = 2,  trust = 0,  confidence = 0.7 },
    CursedApproaching       = { threat = 1,  trust = 0,  confidence = 0.5 },
    CursedImmune            = { threat = 0,  trust = 0,  confidence = 0.5 },
    -- Pharaoh / Graverobber / Ankh events
    AnkhConversionWitnessed = { threat = 10, trust = 0,  confidence = 1.0 },
    AnkhDestructionWitnessed= { threat = 5,  trust = 0,  confidence = 0.9 },
    AnkhLoiteringNearby     = { threat = 2,  trust = 0,  confidence = 0.6 },
    -- Smart Bullets SWEP events
    SmartBulletsVisual      = { threat = 8,  trust = 0,  confidence = 1.0 },
    SmartBulletsAudio       = { threat = 4,  trust = 0,  confidence = 0.6 },
    -- TTT2 role confirmation events
    RoleConfirmedHostile    = { threat = 20, trust = 0,  confidence = 1.0 },
    RoleConfirmedAlly       = { threat = 0,  trust = 10, confidence = 1.0 },
}

BotMorality.SuspicionDescriptions = {
    ["10"] = "Definitely evil",
    ["9"] = "Almost certainly evil",
    ["8"] = "Highly likely evil",
    ["7"] = "Very suspicious, likely evil",
    ["6"] = "Very suspicious",
    ["5"] = "Quite suspicious",
    ["4"] = "Suspicious",
    ["3"] = "Somewhat suspicious",
    ["2"] = "A little suspicious",
    ["1"] = "Slightly suspicious",
    ["0"] = "Neutral",
    ["-1"] = "Slightly trustworthy",
    ["-2"] = "Somewhat trustworthy",
    ["-3"] = "Quite trustworthy",
    ["-4"] = "Very trustworthy",
    ["-5"] = "Highly likely to be innocent",
    ["-6"] = "Almost certainly innocent",
    ["-7"] = "Definitely innocent",
    ["-8"] = "Undeniably innocent",
    ["-9"] = "Absolutely innocent",
    ["-10"] = "Unwaveringly innocent",
}

BotMorality.Thresholds = {
    KOS = 10,
    RoleGuess = 8,
    Sus = 5,
    Trust = -3,
    Innocent = -7,
}

--- Per-threshold announcement cooldown in seconds.
--- Prevents chatter spam when suspicion oscillates around a threshold.
BotMorality.AnnounceCooldowns = {
    KOS      = 20,
    Sus      = 15,
    Trust    = 15,
    Innocent = 20,
}

-- ===========================================================================
-- Instance methods (operate on BotMorality via self / self.bot)
-- ===========================================================================

--- Create or retrieve the multi-dimensional suspicion record for a target.
--- Record structure: { threat, trust, confidence, lastEvent, announced }
---@param target Player
---@return table record  The mutable suspicion record for this target
function BotMorality:EnsureRecord(target)
    local rec = self.suspicions[target]
    if not rec or type(rec) ~= "table" then
        -- Migrate legacy raw numbers or create fresh record
        local legacyVal = (type(rec) == "number") and rec or 0
        rec = {
            threat     = math.max(legacyVal, 0),
            trust      = math.max(-legacyVal, 0),
            confidence = (legacyVal ~= 0) and 0.7 or 0,
            lastEvent  = 0,
            announced  = { KOS = 0, Sus = 0, Trust = 0, Innocent = 0 },
        }
        self.suspicions[target] = rec
    end
    return rec
end

--- Increase/decrease the suspicion on the player for the given reason.
--- Positive events feed the threat channel; negative events feed the trust channel.
--- Confidence is blended per-event as a weighted average so direct witness events
--- carry more weight than hearsay.
---@param target Player
---@param reason string The reason (matching a key in SUSPICION_EVENTS / SUSPICIONVALUES)
function BotMorality:ChangeSuspicion(target, reason, mult)
    local roleDisablesSuspicion = not TTTBots.Roles.GetRoleFor(self.bot):GetUsesSuspicion()
    if roleDisablesSuspicion then return end
    if not mult then mult = 1 end
    if target == self.bot then return end
    if TTTBots.Match.RoundActive == false then return end
    local targetIsPolice = TTTBots.Roles.GetRoleFor(target):GetAppearsPolice()

    mult = mult * (hook.Run("TTTBotsModifySuspicion", self.bot, target, reason, mult) or 1)

    -- Look up the event definition (multi-dim first, fall back to legacy)
    local evDef = self.SUSPICION_EVENTS[reason]
    if not evDef then
        -- Fallback: auto-generate from legacy SUSPICIONVALUES
        local legacyVal = self.SUSPICIONVALUES[reason]
        if not legacyVal then
            ErrorNoHaltWithStack("Invalid suspicion reason: " .. reason)
            return
        end
        if legacyVal >= 0 then
            evDef = { threat = legacyVal, trust = 0, confidence = 0.7 }
        else
            evDef = { threat = 0, trust = math.abs(legacyVal), confidence = 0.7 }
        end
    end

    -- Police suppression: reduce threat contribution for police targets
    local policeMult = 1
    if targetIsPolice and evDef.threat > 0 then
        policeMult = 0.3
    end

    -- Round-phase pressure: amplify threat as fewer players remain
    local pressureMult = 1.0
    if evDef.threat > 0 then
        local ra = self.bot:BotRoundAwareness()
        if ra then
            pressureMult = ra:GetSuspicionPressure()
        end
    end

    local threatAdd = math.max(0, math.ceil(evDef.threat * mult * policeMult * pressureMult))
    local trustAdd  = math.max(0, math.ceil(evDef.trust  * mult))
    local evConf    = evDef.confidence or 0.7

    local rec = self:EnsureRecord(target)

    -- Update threat & trust channels (capped at 20 each)
    rec.threat = math.min(rec.threat + threatAdd, 20)
    rec.trust  = math.min(rec.trust  + trustAdd,  20)

    -- Blend confidence: weighted average — larger events carry more weight
    local evWeight = threatAdd + trustAdd
    if evWeight > 0 then
        local oldWeight = rec.threat + rec.trust - evWeight  -- pre-event total
        if oldWeight <= 0 then
            rec.confidence = evConf
        else
            rec.confidence = (rec.confidence * oldWeight + evConf * evWeight) / (oldWeight + evWeight)
        end
    end

    rec.lastEvent = CurTime()

    -- Fire specific chatter events for high-interest suspicion reasons.
    -- These complement the threshold-based announcements with targeted callouts.
    local chatter = self.bot:BotChatter()
    if chatter and chatter.On then
        local now = CurTime()
        self._reasonChatterTimes = self._reasonChatterTimes or {}
        local lastTime = self._reasonChatterTimes[reason] or 0
        if (now - lastTime) >= 15 then
            local targetName = target:Nick()
            if reason == "DefuseC4" then
                chatter:On("WitnessC4Defuse", { player = targetName, playerEnt = target })
                self._reasonChatterTimes[reason] = now
            elseif reason == "PlantC4" then
                chatter:On("WitnessC4Plant", { player = targetName, playerEnt = target })
                self._reasonChatterTimes[reason] = now
            elseif reason == "TraitorWeapon" then
                chatter:On("TraitorWeaponSpotted", { player = targetName, playerEnt = target })
                self._reasonChatterTimes[reason] = now
            elseif reason == "PersonalSpace" then
                chatter:On("SuspicionPersonalSpace", { player = targetName, playerEnt = target })
                self._reasonChatterTimes[reason] = now
            end
        end
    end

    self:AnnounceIfThreshold(target)
    self:SetAttackIfTargetSus(target)
    self:GuessRole(target)
end

--- Compute the effective suspicion score from the multi-dimensional record.
--- Returns a single integer for backward compatibility with all existing
--- threshold checks, attack decisions, and announcement logic.
---@param target Player
---@return number  Effective suspicion (positive = suspicious, negative = trusted)
function BotMorality:GetSuspicion(target)
    local rec = self.suspicions[target]
    if not rec then return 0 end
    -- Handle legacy: if something externally wrote a raw number, return it
    if type(rec) == "number" then return rec end
    return math.floor((rec.threat - rec.trust) * math.max(rec.confidence, 0.01))
end

--- Return the full multi-dimensional record for a target (read-only intent).
---@param target Player
---@return table|nil  { threat, trust, confidence, lastEvent, announced }
function BotMorality:GetSuspicionRecord(target)
    local rec = self.suspicions[target]
    if not rec then return nil end
    -- Handle legacy raw numbers gracefully
    if type(rec) == "number" then
        return { threat = math.max(rec, 0), trust = math.max(-rec, 0), confidence = 0.7, lastEvent = 0, announced = { KOS = 0, Sus = 0, Trust = 0, Innocent = 0 } }
    end
    return rec
end

--- Directly set the effective suspicion to a specific value.
--- Used by external code that previously wrote `morality.suspicions[target] = X`.
--- Reverse-engineers appropriate threat/trust values to produce the desired
--- effective score at the record's current confidence level.
---@param target Player
---@param value number  Desired effective suspicion score
function BotMorality:SetSuspicionDirect(target, value)
    local rec = self:EnsureRecord(target)
    local conf = math.max(rec.confidence, 0.1)  -- avoid division by zero

    -- Goal: floor((threat - trust) * conf) == value
    -- We adjust threat or trust to achieve the target while preserving the other.
    if value >= 0 then
        -- Positive: set threat to produce desired score, zero out trust
        rec.threat = math.Clamp(math.ceil(value / conf), 0, 20)
        rec.trust  = 0
    else
        -- Negative: set trust to produce desired score, zero out threat
        rec.trust  = math.Clamp(math.ceil(math.abs(value) / conf), 0, 20)
        rec.threat = 0
    end

    rec.lastEvent = CurTime()
end

--- Mark a player as tested clean by a role tester. Sets suspicion floor to -5.
--- Call this when a player passes a RoleChecker test.
---@param target Player
function BotMorality:SetTestedClean(target)
    if not (IsValid(target) and target:IsPlayer()) then return end
    self.testedClean = self.testedClean or {}
    self.testedClean[target] = true
    -- Immediately reduce suspicion to at most -5
    local cur = self:GetSuspicion(target)
    if cur > -5 then
        self:SetSuspicionDirect(target, -5)
    end
    -- Add positive evidence entry
    local evidence = self.bot:BotEvidence()
    if evidence then
        evidence:ConfirmInnocent(target, "passed_role_tester")
    end
end

--- Announce the suspicion level of the given player if it is above a certain threshold.
--- Uses per-target, per-threshold cooldowns to prevent chatter spam from
--- suspicion oscillation.
---@param target Player
function BotMorality:AnnounceIfThreshold(target)
    if not (IsValid(target) and target:IsPlayer() and target:Visible(self.bot) and target:GetPos():Distance(self.bot:GetPos()) <= 600) then
        return
    end

    local sus = self:GetSuspicion(target)
    local chatter = self.bot:BotChatter()
    if not chatter or not chatter.On then return end
    local KOSThresh = self.Thresholds.KOS
    local SusThresh = self.Thresholds.Sus
    local TrustThresh = self.Thresholds.Trust
    local InnocentThresh = self.Thresholds.Innocent

    -- Retrieve per-target cooldown timestamps
    local rec = self:EnsureRecord(target)
    local ann = rec.announced
    local now = CurTime()
    local cd = self.AnnounceCooldowns

    if sus >= KOSThresh and (now - ann.KOS >= cd.KOS) then
        chatter:On("CallKOS", { player = target:Nick() })
        ann.KOS = now
    elseif sus >= SusThresh and sus < KOSThresh and (now - ann.Sus >= cd.Sus) then
        chatter:On("DeclareSuspicious", { player = target:Nick() })
        ann.Sus = now
    elseif sus <= InnocentThresh and (now - ann.Innocent >= cd.Innocent) then
        chatter:On("DeclareInnocent", { player = target:Nick() })
        ann.Innocent = now
    elseif sus <= TrustThresh and sus > InnocentThresh and (now - ann.Trust >= cd.Trust) then
        chatter:On("DeclareTrustworthy", { player = target:Nick() })
        ann.Trust = now
    end

    -- Rising suspicion chatter: fire at a mid-range level (3-4) before Sus threshold
    -- to give a more gradual "I'm noticing something" feel
    local RISING_THRESH = 3
    ann.Rising = ann.Rising or 0
    if sus >= RISING_THRESH and sus < SusThresh and (now - ann.Rising >= 25) then
        chatter:On("SuspicionRising", { player = target:Nick(), playerEnt = target })
        ann.Rising = now
    end
end

--- Announce when suspicion on a target has fully cleared (decayed to zero).
--- Called from TickSuspicions when a record is about to be cleaned up.
---@param target Player
function BotMorality:AnnounceCleared(target)
    if not (IsValid(target) and target:IsPlayer()) then return end
    local chatter = self.bot:BotChatter()
    if not chatter or not chatter.On then return end

    -- Only announce if we previously had significant suspicion on this target
    local rec = self.suspicions[target]
    if not rec or type(rec) ~= "table" then return end
    local ann = rec.announced or {}
    -- Must have previously announced suspicion (Sus or KOS) to announce clearing
    if (ann.Sus or 0) == 0 and (ann.KOS or 0) == 0 then return end

    -- Rate-limit to avoid spam
    self._clearedChatterTimes = self._clearedChatterTimes or {}
    local now = CurTime()
    if (now - (self._clearedChatterTimes[target] or 0)) < 30 then return end
    self._clearedChatterTimes[target] = now

    chatter:On("SuspicionCleared", { player = target:Nick(), playerEnt = target })
end

--- Set the bot's attack target to the given player if they seem evil.
function BotMorality:SetAttackIfTargetSus(target)
    if self.bot.attackTarget ~= nil then return end
    local sus = self:GetSuspicion(target)
    if sus >= self.Thresholds.KOS then
        Arb.RequestAttackTarget(self.bot, target, "SUS_THRESHOLD", PRI.SUSPICION_THRESHOLD)
        return true
    end
    return false
end

--- Allow the bot to have a chance of correctly guessing the role of the player if they are suspicious enough.
--- Rate-limited: each bot can only guess a given target's role once every 30 seconds to prevent spam.
function BotMorality:GuessRole(target)
    local sus = self:GetSuspicion(target)
    local archetype = self.bot:BotPersonality().archetype
    if sus < self.Thresholds.RoleGuess then return end
    if not (IsValid(target) and target:IsPlayer() and target:Visible(self.bot) and target:GetPos():Distance(self.bot:GetPos()) <= 600) then
        return
    end

    -- Rate-limit: don't guess the same target more than once every 30 seconds
    self.roleGuessTimestamps = self.roleGuessTimestamps or {}
    local lastGuessTime = self.roleGuessTimestamps[target] or 0
    if CurTime() - lastGuessTime < 30 then return end

    -- Don't re-guess if we already have a guess for this target
    if self.roleGuesses[target] then return end

    self.roleGuessTimestamps[target] = CurTime()

    local chance = math.random(1, 100)

    if archetype == "Tryhard/Nerd" then
        chance = math.max(chance - 40, 1)
    elseif archetype == "Bad" or archetype == "Dumb" then
        chance = math.min(chance + 40, 100)
    end

    if chance <= 15 then
        self.roleGuesses[target] = TTTBots.Roles.GetRoleFor(target)
        print(self.bot:Nick() .. " has guessed " .. target:Nick() .. "'s role as " .. self.roleGuesses[target]:GetName())
    elseif chance <= 35 then
        self.roleGuesses[target] = TTTBots.Roles.GetRandomRole()
        print(self.bot:Nick() .. " has INCORRECTLY guessed " .. target:Nick() .. "'s role as " .. self.roleGuesses[target]:GetName())
    end
    if self.roleGuesses[target] and self.roleGuesses[target]:GetTeam() ~= TEAM_INNOCENT then
        if math.random(1, 100) > 25 then
            local chatter = self.bot:BotChatter()
            if chatter and chatter.On then
                chatter:On("RoleGuess", { player = target:Nick(), playerEnt = target, role = self.roleGuesses[target]:GetName() })
            end
        end
        -- Only attack on role guess if suspicion is actually at KOS level.
        -- A mere guess at SUSPICION_THRESHOLD caused too many innocent-on-innocent
        -- TDM chains from incorrect guesses. Now the guess must be backed by
        -- actual high suspicion before triggering an attack.
        if sus >= self.Thresholds.KOS and math.random(1, 100) > 40 then
            Arb.RequestAttackTarget(self.bot, target, "SUS_ROLE_GUESS", PRI.SUSPICION_THRESHOLD)
        end
    end
end

--- Returns the evidence-weighted suspicion floor for a player.
--- This prevents suspicion from decaying below what the evidence supports.
---@param target Player
---@return number
function BotMorality:GetEvidenceFloor(target)
    local evidence = self.bot:BotEvidence()
    if not evidence then return 0 end
    return evidence:EvidenceWeight(target)
end

function BotMorality:TickSuspicions()
    local roundStarted = TTTBots.Match.RoundActive
    if not roundStarted then
        self.suspicions = {}
        return
    end

    -- Skip decay for roles that don't use suspicion
    if not TTTBots.Roles.GetRoleFor(self.bot):GetUsesSuspicion() then return end

    -- Trait-modulated decay rate
    local personality = self.bot:BotPersonality()
    local threatDecay = 0.996  -- base per-tick threat decay (faster than old 0.998)
    local trustDecay  = 0.999  -- trust decays slower (good deeds remembered longer)
    if personality then
        local traits = personality.traits or {}
        for _, trait in ipairs(traits) do
            if trait == "suspicious" then
                threatDecay = math.max(threatDecay, 0.999)  -- suspicious: slower threat decay
                trustDecay  = math.min(trustDecay,  0.997)  -- suspicious: faster trust decay
            elseif trait == "gullible" then
                threatDecay = math.min(threatDecay, 0.992)  -- gullible: faster threat decay
                trustDecay  = math.max(trustDecay,  0.9995) -- gullible: slower trust decay
            end
        end
    end

    local now = CurTime()

    for target, rec in pairs(self.suspicions) do
        if not (IsValid(target) and target:IsPlayer()) then
            self.suspicions[target] = nil
            continue
        end

        -- Handle legacy raw numbers that may have been injected by external code
        if type(rec) == "number" then
            local legacyVal = rec
            rec = self:EnsureRecord(target)
            if legacyVal >= 0 then
                rec.threat = math.min(legacyVal, 20)
            else
                rec.trust = math.min(math.abs(legacyVal), 20)
            end
            rec.confidence = 0.7
        end

        -- Decay threat channel
        if rec.threat > 0 then
            rec.threat = rec.threat * threatDecay
            if rec.threat < 0.3 then rec.threat = 0 end
        end

        -- Decay trust channel
        if rec.trust > 0 then
            rec.trust = rec.trust * trustDecay
            if rec.trust < 0.3 then rec.trust = 0 end
        end

        -- Confidence decays slowly toward 0 when no events occur
        -- (stale opinions become less certain over time)
        local timeSinceEvent = now - (rec.lastEvent or 0)
        if timeSinceEvent > 5 then
            -- ~0.1% per tick after 5s of no events
            rec.confidence = rec.confidence * 0.999
            if rec.confidence < 0.05 then rec.confidence = 0 end
        end

        -- Enforce evidence floor: effective score can't decay below evidence-based floor
        local evidenceFloor = self:GetEvidenceFloor(target)
        local effective = self:GetSuspicion(target)
        if effective < evidenceFloor and evidenceFloor > 0 then
            -- Boost threat to maintain the evidence floor
            local conf = math.max(rec.confidence, 0.1)
            local neededThreat = math.ceil(evidenceFloor / conf) + rec.trust
            rec.threat = math.min(math.max(rec.threat, neededThreat), 20)
        end

        -- Enforce tested-clean ceiling: tested-clean players can't go above -5
        local testedClean = self.testedClean and self.testedClean[target]
        if testedClean and effective > -5 then
            self:SetSuspicionDirect(target, -5)
        end

        -- Clean up records where all channels are zero (save memory)
        if rec.threat == 0 and rec.trust == 0 and rec.confidence == 0 then
            self:AnnounceCleared(target)
            self.suspicions[target] = nil
        end
    end
end

-- ===========================================================================
-- Witness event handlers (instance methods)
-- ===========================================================================

--- Called by OnWitnessHurt, but only if an ally is being attacked.
---@param victim Player
---@param attacker Player
---@param healthRemaining number
---@param damageTaken number
function BotMorality:OnWitnessHurtIfAlly(victim, attacker, healthRemaining, damageTaken)
    -- Check if the VICTIM is an ally of the WITNESSING BOT (not if victim and attacker are allies).
    -- The old check (IsAllies(victim, attacker)) only fired on friendly fire, which is backwards.
    local victimIsAlly = (TTTBots.Perception and TTTBots.Perception.IsPerceivedAlly(self.bot, victim))
        or TTTBots.Roles.IsAllies(self.bot, victim)
    if not victimIsAlly then return end
    -- Don't defend against allies attacking each other (actual friendly fire)
    -- UNLESS mistrust is enabled and the attacker has extreme suspicion
    local attackerIsAlly = (TTTBots.Perception and TTTBots.Perception.IsPerceivedAlly(self.bot, attacker))
        or TTTBots.Roles.IsAllies(self.bot, attacker)
    if attackerIsAlly then
        -- INNOCENT MISTRUST: If mistrust is enabled, check if we should
        -- intervene despite the attacker being an ally — they might be
        -- a traitor we haven't confirmed yet.
        local mistrustEnabled = lib.GetConVarBool("innocent_mistrust")
        if mistrustEnabled then
            local morality = self.bot.components and self.bot.components.morality
            if morality then
                local attackerSus = morality:GetSuspicion(attacker)
                local kosThreshold = BotMorality.Thresholds.KOS or 10
                local mistrustMult = lib.GetConVarFloat("innocent_mistrust_threshold") or 1.8
                local mistrustThreshold = kosThreshold * mistrustMult
                if attackerSus >= mistrustThreshold then
                    -- Attacker ally has extreme suspicion — defend the victim
                    local mem = self.bot.components and self.bot.components.memory
                    if mem and mem.UpdateKnownPositionFor and IsValid(attacker) then
                        mem:UpdateKnownPositionFor(attacker, attacker:GetPos())
                    end
                    Arb.RequestAttackTarget(self.bot, attacker, "ALLY_DEFENSE", PRI.SUSPICION_THRESHOLD)
                    return
                end
            end
        end
        return -- Normal case: ally-on-ally, don't intervene
    end

    -- Defend our ally: only engage if the attacker has enough built-up suspicion
    -- to be considered hostile. This prevents innocent-on-innocent TDM chains
    -- from single hits, crossfire, or accidental damage. The suspicion system
    -- ensures the bot needs EVIDENCE before attacking in defense of allies.
    -- Use SUSPICION_THRESHOLD priority so higher-priority events can override.
    local morality = self.bot.components and self.bot.components.morality
    local attackerSus = morality and morality:GetSuspicion(attacker) or 0
    local currentPri = self.bot.attackTargetPriority or 0
    if currentPri < PRI.SUSPICION_THRESHOLD and attackerSus >= BotMorality.Thresholds.Sus then
        -- Seed attacker position so AttackTarget can path toward them immediately
        local mem = self.bot.components and self.bot.components.memory
        if mem and mem.UpdateKnownPositionFor and IsValid(attacker) then
            mem:UpdateKnownPositionFor(attacker, attacker:GetPos())
        end
        Arb.RequestAttackTarget(self.bot, attacker, "ALLY_DEFENSE", PRI.SUSPICION_THRESHOLD)
    end
end

function BotMorality:OnKilled(attacker)
    if not (attacker and IsValid(attacker) and attacker:IsPlayer()) then
        self.bot.grudge = nil
        return
    end

    -- Never hold a grudge against an ally (teammate) — this applies to all
    -- teams, not just innocents. Prevents Hothead traitors from grudge-hunting
    -- fellow traitors next round after accidental friendly fire.
    local attackerIsAlly = (TTTBots.Perception and TTTBots.Perception.IsPerceivedAlly(self.bot, attacker))
        or TTTBots.Roles.IsAllies(self.bot, attacker)
    if attackerIsAlly then
        self.bot.grudge = nil
        return
    end

    if self.bot:BotPersonality().archetype == "Hothead" then
        self.bot.grudge = attacker
    end
end

function BotMorality:OnWitnessKill(victim, weapon, attacker)
    if (weapon and IsValid(weapon) and weapon.GetClass and weapon:GetClass() == "ttt_c4") then return end
    if not lib.IsPlayerAlive(self.bot) then return end
    local vicIsTraitor = victim:GetTeam() ~= TEAM_INNOCENT
    local vicIsMedic = victim:GetRoleStringRaw() == "medic"
    local numWitnesses = #lib.GetAllWitnesses(attacker:EyePos(), true)
    local chance = 1 / numWitnesses or 1

    if vicIsTraitor then
        self:ChangeSuspicion(attacker, "KillTraitor")
    elseif TTTBots.Roles.GetRoleFor(victim):GetAppearsPolice() then
        self:ChangeSuspicion(attacker, "KillTrusted")
    elseif vicIsMedic then
        self:ChangeSuspicion(attacker, "KillMedic")
    else
        self:ChangeSuspicion(attacker, "Kill")
    end

    -- Feed evidence log
    local evidence = self.bot:BotEvidence()
    if evidence then
        local weaponName = (weapon and IsValid(weapon) and weapon.GetClass) and weapon:GetClass() or "unknown weapon"
        local navArea    = navmesh.GetNearestNavArea(attacker:GetPos())
        local location   = (navArea and navArea.GetPlace and navArea:GetPlace() ~= "") and navArea:GetPlace() or "unknown location"
        evidence:AddEvidence({
            type     = "WITNESSED_KILL",
            subject  = attacker,
            victim   = victim,
            detail   = weaponName,
            location = location,
        })

        -- Record in witness ring buffer for LLM game-state context (9.1)
        local mem = self.bot:BotMemory()
        if mem then
            local desc = string.format("%s killed %s", attacker:Nick(), victim:Nick())
            if location and location ~= "unknown location" then
                desc = desc .. " at " .. location
            end
            mem:AddWitnessEvent("kill", desc)
        end
    end

    local chatter = self.bot:BotChatter()
    if not chatter or not chatter.On then return end
    -- Prevent self-reporting: a bot should never call out its own kills
    if self.bot == attacker then return end
    if TTTBots.Roles.IsAllies(self.bot, attacker) and self.bot:GetTeam() ~= TEAM_INNOCENT then return end
    -- Use the richer WitnessCallout event; fall back to Kill for backwards compat
    -- Store full weapon class in evidence but strip prefix for chat display
    local fullWeaponName = (weapon and IsValid(weapon) and weapon:GetClass()) or nil
    local displayWeapon = fullWeaponName
    if displayWeapon then
        -- Strip leading components (e.g. "weapon_ttt_m16" -> "m16")
        local parts = string.Explode("_", displayWeapon)
        if #parts > 2 then
            displayWeapon = table.concat(parts, "_", 3)
        end
    end
    local navArea    = navmesh.GetNearestNavArea(attacker:GetPos())
    local location   = (navArea and navArea.GetPlace and navArea:GetPlace() ~= "") and navArea:GetPlace() or nil
    chatter:On("WitnessCallout", {
        victim      = victim:Nick(),
        victimEnt   = victim,
        attacker    = attacker:Nick(),
        attackerEnt = attacker,
        weapon      = displayWeapon,
        location    = location,
    })
    -- Also fire legacy Kill event so existing locale lines still trigger
    chatter:On("Kill", { victim = victim:Nick(), victimEnt = victim, attacker = attacker:Nick(), attackerEnt = attacker })
end

function BotMorality:OnKOSCalled(caller, target)
    if not lib.IsPlayerAlive(self.bot) then return end
    if not TTTBots.Roles.GetRoleFor(caller):GetUsesSuspicion() then return end

    local callerSus = self:GetSuspicion(caller)
    local callerIsPolice = TTTBots.Roles.GetRoleFor(caller):GetAppearsPolice()
    local targetSus = self:GetSuspicion(target)

    local TRAITOR = self.Thresholds.KOS
    local TRUSTED = self.Thresholds.Trust
    local INNOCENT = self.Thresholds.Innocent

    if targetSus > TRAITOR then
        self:ChangeSuspicion(caller, "AffirmingKOS")
    end
    if callerIsPolice then
        -- Detective/police KOS carries near-absolute authority
        self:ChangeSuspicion(target, "KOSByDetective")
    elseif callerSus < INNOCENT then
        self:ChangeSuspicion(target, "KOSByInnocent")
    elseif callerSus < TRUSTED then
        self:ChangeSuspicion(target, "KOSByTrusted")
    elseif callerSus > TRAITOR then
        self:ChangeSuspicion(target, "KOSByTraitor")
    else
        self:ChangeSuspicion(target, "KOSByOther")
    end

    -- Feed evidence log: hearing a KOS gives the bot reason to suspect the target
    -- Detective/police KOS carries significantly more weight than a regular player's
    local evidence = self.bot:BotEvidence()
    if evidence then
        local evidenceType = callerIsPolice and "KOS_BY_DETECTIVE" or "KOS_CALLED_BY"
        evidence:AddEvidence({
            type    = evidenceType,
            subject = target,
            detail  = caller:Nick(),
        })

        -- Record in witness ring buffer for LLM game-state context (9.1)
        local mem = self.bot:BotMemory()
        if mem then
            mem:AddWitnessEvent("kos", string.format("%s called KOS on %s", caller:Nick(), target:Nick()))
        end
    end
end

--- When we witness someone getting hurt.
function BotMorality:OnWitnessHurt(victim, attacker, healthRemaining, damageTaken)
    if damageTaken < 1 then return end
    self:OnWitnessHurtIfAlly(victim, attacker, healthRemaining, damageTaken)
    if attacker == self.bot then
        if victim == self.bot.attackTarget then
            local personality = self.bot:BotPersonality()
            if not personality then return end
            personality:OnPressureEvent("HurtEnemy")
        end
        return
    end
    if self.bot == victim then
        -- Bot was hurt: check if the attacker is an ally (bot OR player).
        -- If so, do NOT retaliate — just apply suspicion and call out.
        -- This prevents friendly-fire chains between teammates.
        local attackerIsAlly = IsValid(attacker) and attacker:IsPlayer()
            and ((TTTBots.Perception and TTTBots.Perception.IsPerceivedAlly(self.bot, attacker))
                or TTTBots.Roles.IsAllies(self.bot, attacker))
        if attackerIsAlly then
            -- Still apply suspicion so repeated team damage accumulates
            self:ChangeSuspicion(attacker, "HurtMe")
            local personality = self.bot:BotPersonality()
            if personality then
                personality:OnPressureEvent("Hurt")
            end

            -- INNOCENT MISTRUST: If mistrust is enabled and this ally has now
            -- accumulated enough suspicion from repeated attacks, the bot may
            -- decide they're actually a traitor and retaliate. This creates
            -- realistic innocent-on-innocent TDM chains from persistent FF.
            local mistrustEnabled = lib.GetConVarBool("innocent_mistrust")
            if mistrustEnabled and damageTaken > 10 then
                local attackerSus = self:GetSuspicion(attacker)
                local kosThreshold = BotMorality.Thresholds.KOS or 10
                local mistrustMult = lib.GetConVarFloat("innocent_mistrust_threshold") or 1.8
                local mistrustThreshold = kosThreshold * mistrustMult
                if attackerSus >= mistrustThreshold then
                    -- Suspicion has been pushed past mistrust threshold by
                    -- repeated ally damage — retaliate with self-defense priority.
                    local mem = self.bot.components and self.bot.components.memory
                    if mem and mem.UpdateKnownPositionFor and IsValid(attacker) then
                        mem:UpdateKnownPositionFor(attacker, attacker:GetPos())
                    end
                    -- Clear any existing lower-priority target
                    local currentPri = self.bot.attackTargetPriority or 0
                    if currentPri < PRI.SELF_DEFENSE then
                        self.bot.attackTarget         = nil
                        self.bot.attackTargetPriority = 0
                        self.bot.attackTargetReason   = nil
                    end
                    Arb.RequestAttackTarget(self.bot, attacker, "SELF_DEFENSE", PRI.SELF_DEFENSE)
                    if lib.GetConVarBool("debug_misc") then
                        print(string.format("[TTTBots][MISTRUST_SELFDEF] %s retaliating against ally %s (sus=%d >= mistrust=%d, dmg=%d)",
                            self.bot:Nick(), attacker:Nick(), attackerSus, mistrustThreshold, damageTaken))
                    end
                    return -- retaliating, skip normal ally-hit path
                end
            end

            -- Verbally call out (rate-limited per attacker to 10s)
            local now = CurTime()
            self.lastShotChatterTime = self.lastShotChatterTime or {}
            if (now - (self.lastShotChatterTime[attacker] or 0)) >= 10 then
                self.lastShotChatterTime[attacker] = now
                local chatter = self.bot:BotChatter()
                if chatter and chatter.On and TTTBots.Roles.GetRoleFor(self.bot):GetUsesSuspicion() then
                    local allyName = (IsValid(attacker) and attacker.Nick) and attacker:Nick() or "someone"
                    chatter:On("BeingShotAt", { player = allyName, playerEnt = attacker })
                end
            end
            return -- ally hit us, do NOT retaliate (suspicion not high enough)
        end

        -- Non-ally attacker: request retaliation and apply HurtMe suspicion.
        -- Seed the attacker's position into memory so AttackTarget's Seek mode
        -- can immediately path toward them rather than wandering aimlessly.
        -- This is critical when the bot is shot from behind and has never
        -- "seen" the attacker — without this, the bot has no known position
        -- for the target and defaults to random wander instead of turning
        -- to face and engage.
        local mem = self.bot.components and self.bot.components.memory
        if mem and mem.UpdateKnownPositionFor and IsValid(attacker) then
            mem:UpdateKnownPositionFor(attacker, attacker:GetPos())
        end

        -- Graduated self-defense response: chip damage (<=5 HP) only raises
        -- suspicion without triggering a full SELF_DEFENSE attack. This prevents
        -- TDM chains from stray bullets, splash damage, or accidental hits.
        -- Moderate damage (6-20 HP) uses SUSPICION_THRESHOLD priority so the
        -- bot investigates but doesn't override stronger combat priorities.
        -- Heavy damage (>20 HP) or repeated attacks (high suspicion) use full
        -- SELF_DEFENSE priority for immediate retaliation.
        local selfDefPriority = PRI.SELF_DEFENSE
        local existingSus = self:GetSuspicion(attacker)
        if damageTaken <= 5 and existingSus < BotMorality.Thresholds.Sus then
            -- Chip damage from an unsuspected player: just raise suspicion, don't attack
            selfDefPriority = nil
        elseif damageTaken <= 20 and existingSus < BotMorality.Thresholds.Sus then
            -- Moderate damage from an unsuspected player: investigate, not full retaliation
            selfDefPriority = PRI.SUSPICION_THRESHOLD
        end

        local accepted = false
        if selfDefPriority then
            -- Force-clear any stale lower-priority target so self-defense can take
            -- over immediately. Without this, the bot may be locked on a nil or
            -- low-priority target that prevents the SELF_DEFENSE request from
            -- succeeding (SetAttackTarget's "same target" early-return guard).
            local currentTarget = self.bot.attackTarget
            local currentPri    = self.bot.attackTargetPriority or 0
            if currentTarget ~= attacker and currentPri < selfDefPriority then
                self.bot.attackTarget         = nil
                self.bot.attackTargetPriority = 0
                self.bot.attackTargetReason   = nil
            end
            accepted = Arb.RequestAttackTarget(self.bot, attacker, "SELF_DEFENSE", selfDefPriority)
        end
        if not accepted and selfDefPriority and lib.GetConVarBool("debug_attack") then
            local ct = self.bot.attackTarget
            local cp = self.bot.attackTargetPriority or 0
            print(string.format("[TTTBots][SELF_DEFENSE] %s: RequestAttackTarget REJECTED for attacker %s (currentTarget=%s, currentPri=%d, requestedPri=%d)",
                IsValid(self.bot) and self.bot.Nick and self.bot:Nick() or "invalid_bot",
                IsValid(attacker) and attacker.Nick and attacker:Nick() or "invalid",
                IsValid(ct) and ct.Nick and ct:Nick() or "nil",
                cp, selfDefPriority or 0))
        end
        self:ChangeSuspicion(attacker, "HurtMe")
        local personality = self.bot:BotPersonality()
        if personality then
            personality:OnPressureEvent("Hurt")
        end
        -- Verbally call out / accuse the attacker (rate-limited per attacker to 10s)
        local now = CurTime()
        self.lastShotChatterTime = self.lastShotChatterTime or {}
        if (now - (self.lastShotChatterTime[attacker] or 0)) >= 10 then
            self.lastShotChatterTime[attacker] = now
            local chatter = self.bot:BotChatter()
            if chatter and chatter.On and TTTBots.Roles.GetRoleFor(self.bot):GetUsesSuspicion() then
                local sus = self:GetSuspicion(attacker)
                local attackerName = (IsValid(attacker) and attacker.Nick) and attacker:Nick() or "someone"
                local args = { player = attackerName, playerEnt = attacker }
                if sus >= self.Thresholds.KOS then
                    chatter:On("CallKOS", args)
                else
                    chatter:On("BeingShotAt", args)
                end
            end
        end
        return -- self is victim, skip bystander suspicion logic below
    end
    -- Bystander logic: skip if attacker is an ally hurting the victim
    if TTTBots.Roles.IsAllies(victim, attacker) then return end
    if TTTBots.Match.IsPlayerDisguised(attacker) then
        if self.bot.attackTarget == nil then
            Arb.RequestAttackTarget(self.bot, attacker, "DISGUISED_ATTACKER", PRI.ROLE_HOSTILITY)
        end
        return
    end

    local attackerSusMod = 1.0
    local victimSusMod = 1.0
    local can_cheat = lib.GetConVarBool("cheat_know_shooter")
    if can_cheat then
        local bad_guy = TTTBots.Match.WhoShotFirst(victim, attacker)
        if bad_guy == victim then
            victimSusMod = 2.0
            attackerSusMod = 0.5
        elseif bad_guy == attacker then
            victimSusMod = 0.5
            attackerSusMod = 2.0
        end
    end

    local impact = math.min((damageTaken / victim:GetMaxHealth()) * 3, 1.5)
    local victimIsPolice = TTTBots.Roles.GetRoleFor(victim):GetAppearsPolice()
    local attackerIsPolice = TTTBots.Roles.GetRoleFor(attacker):GetAppearsPolice()
    local attackerSus = self:GetSuspicion(attacker)
    local victimSus = self:GetSuspicion(victim)
    if victimIsPolice or victimSus < BotMorality.Thresholds.Trust then
        self:ChangeSuspicion(attacker, "HurtTrusted", impact * attackerSusMod)
        -- Defend a trusted/police ally being attacked, but only if the damage
        -- is significant (>10 HP) and the attacker already has some suspicion.
        -- This prevents innocent-on-innocent TDM chains from chip damage,
        -- crossfire, or single stray bullets. Use PLAYER_REQUEST (4) priority
        -- instead of SELF_DEFENSE (5) so that prevent-ally clears can override.
        local attackerCurrentSus = self:GetSuspicion(attacker)
        local currentPri = self.bot.attackTargetPriority or 0
        if currentPri < PRI.PLAYER_REQUEST and damageTaken > 10
            and attackerCurrentSus >= BotMorality.Thresholds.Sus then
            -- Seed attacker position into memory for immediate pathfinding
            local mem = self.bot.components and self.bot.components.memory
            if mem and mem.UpdateKnownPositionFor and IsValid(attacker) then
                mem:UpdateKnownPositionFor(attacker, attacker:GetPos())
            end
            Arb.RequestAttackTarget(self.bot, attacker, "ALLY_DEFENSE", PRI.PLAYER_REQUEST)
        end
        -- Verbally accuse the attacker for shooting a trusted ally (rate-limited per attacker to 10s)
        local now = CurTime()
        self.lastAllyDefChatterTime = self.lastAllyDefChatterTime or {}
        if (now - (self.lastAllyDefChatterTime[attacker] or 0)) >= 10 then
            self.lastAllyDefChatterTime[attacker] = now
            local chatter = self.bot:BotChatter()
            if chatter and chatter.On and TTTBots.Roles.GetRoleFor(self.bot):GetUsesSuspicion() then
                local sus = self:GetSuspicion(attacker)
                local args = { player = attacker:Nick(), playerEnt = attacker, attacker = attacker:Nick(), attackerEnt = attacker, victim = victim:Nick(), victimEnt = victim }
                if sus >= self.Thresholds.KOS then
                    chatter:On("CallKOS", { player = attacker:Nick(), playerEnt = attacker })
                else
                    chatter:On("WitnessAllyShot", args)
                end
            end
        end
    elseif attackerIsPolice or attackerSus < BotMorality.Thresholds.Trust then
        self:ChangeSuspicion(victim, "HurtByTrusted", impact * victimSusMod)
    elseif attackerSus > BotMorality.Thresholds.KOS then
        self:ChangeSuspicion(victim, "HurtByEvil", impact * victimSusMod)
    else
        self:ChangeSuspicion(attacker, "Hurt", impact * attackerSusMod)
    end
end

function BotMorality:OnWitnessFireBullets(attacker, data, angleDiff)
    local angleDiffPercent = angleDiff / 30
    local sus = -1 * (1 - angleDiffPercent) / 4
    if sus < 1 then sus = 0.1 end

    if sus > 3 then
        local personality = self.bot:BotPersonality()
        if personality then
            personality:OnPressureEvent("BulletClose")
        end
    end
    self:ChangeSuspicion(attacker, "ShotAt", sus)
end

-- ===========================================================================
-- Global hooks — witness event dispatchers
-- ===========================================================================

hook.Add("PlayerDeath", "TTTBots.Components.Morality.PlayerDeath", function(victim, weapon, attacker)
    if not (IsValid(victim) and victim:IsPlayer()) then return end
    if not (IsValid(attacker) and attacker:IsPlayer()) then return end
    local timestamp = CurTime()
    -- Stash the attacker on the victim so TTTOnCorpseCreated can tag the rag.
    victim.tttbots_killedBy = attacker
    if attacker:IsBot() then
        attacker.lastKillTime = timestamp
        -- Track self-defense kills for innocent-side bots so InvestigateCorpse can
        -- confirm the body without the normal post-kill suppression delay.
        if attacker:GetTeam() == TEAM_INNOCENT then
            attacker.selfDefenseKills = attacker.selfDefenseKills or {}
            attacker.selfDefenseKills[victim] = timestamp
        end
    end
    if victim:IsBot() and victim.components and victim.components.morality then
        victim.components.morality:OnKilled(attacker)
    end
    -- Mark red-handed regardless of victim visibility — any witness who saw
    -- the attacker should be able to identify them as a killer.
    if victim:GetTeam() == TEAM_INNOCENT then
        local ttt_bot_cheat_redhanded_time = lib.GetConVarInt("cheat_redhanded_time")
        attacker.redHandedTime = timestamp + ttt_bot_cheat_redhanded_time
    end
    -- Gather witnesses who can see either the attacker or the victim.
    -- Previously gated on victim:Visible(attacker), which meant backstab kills
    -- produced zero witness awareness even for bots watching the victim die.
    -- No FOV restriction: kills are loud and highly noticeable — any bot with
    -- line-of-sight to either the attacker or the victim should react.
    local witnesses = {}
    local seen = {}
    for _, bot in ipairs(TTTBots.Bots) do
        if not IsValid(bot) or not lib.IsPlayerAlive(bot) then continue end
        if seen[bot] then continue end
        if bot:VisibleVec(attacker:EyePos()) or bot:VisibleVec(victim:EyePos()) then
            table.insert(witnesses, bot)
            seen[bot] = true
        end
    end
    table.insert(witnesses, victim)

    for i, witness in pairs(witnesses) do
        if witness and witness.components then
            witness.components.morality:OnWitnessKill(victim, weapon, attacker)
        end
    end
end)

hook.Add("EntityFireBullets", "TTTBots.Components.Morality.FireBullets", function(entity, data)
    if not (IsValid(entity) and entity:IsPlayer()) then return end
    local witnesses = lib.GetAllWitnesses(entity:EyePos(), true)

    local lookAngle = entity:EyeAngles()

    for i, witness in pairs(witnesses) do
        if not witness:IsBot() then continue end
        ---@cast witness Bot
        local morality = witness:BotMorality()

        local witnessAngle = witness:EyeAngles()
        local angleDiff = lookAngle.y - witnessAngle.y
        angleDiff = ((angleDiff + 180) % 360) - 180
        angleDiff = math.abs(angleDiff)

        morality:OnWitnessFireBullets(entity, data, angleDiff)
        hook.Run("TTTBotsOnWitnessFireBullets", witness, entity, data, angleDiff)
    end
end)

hook.Add("PlayerHurt", "TTTBots.Components.Morality.PlayerHurt", function(victim, attacker, healthRemaining, damageTaken)
    if not (IsValid(victim) and victim:IsPlayer()) then return end
    if not (IsValid(attacker) and attacker:IsPlayer()) then return end

    -- If NPC is the attacker, attack them directly.
    if attacker:IsNPC() and not attacker:IsBot() then
        if victim:IsBot() then
            Arb.RequestAttackTarget(victim, attacker, "NPC_ATTACKER", PRI.SELF_DEFENSE)
        end
        return
    end

    -- Always notify the victim bot so it can retaliate, even if it can't see the attacker.
    if victim:IsBot() and victim.components then
        victim.components.morality:OnWitnessHurt(victim, attacker, healthRemaining, damageTaken)
        hook.Run("TTTBotsOnWitnessHurt", victim, victim, attacker, healthRemaining, damageTaken)
    end

    -- Notify visible bystander bots (exclude victim — already handled above).
    -- Check witnesses who can see either the attacker OR the victim. Previously
    -- this was gated on victim:Visible(attacker), which meant backstab attacks
    -- produced zero bystander awareness even for bots staring at the scene.
    -- No FOV restriction: gunshots are loud and combat is highly noticeable —
    -- any bot with line-of-sight to either combatant should react.
    if not IsValid(attacker) then return end
    local witnesses = {}
    for _, bot in ipairs(TTTBots.Bots) do
        if not IsValid(bot) or not lib.IsPlayerAlive(bot) then continue end
        if bot == victim then continue end
        if bot:VisibleVec(attacker:EyePos()) or bot:VisibleVec(victim:EyePos()) then
            table.insert(witnesses, bot)
        end
    end
    for i, witness in pairs(witnesses) do
        if witness == victim then continue end -- already dispatched
        if witness and witness.components then
            witness.components.morality:OnWitnessHurt(victim, attacker, healthRemaining, damageTaken)
            hook.Run("TTTBotsOnWitnessHurt", witness, victim, attacker, healthRemaining, damageTaken)
        end
    end
end)

hook.Add("TTTBodyFound", "TTTBots.Components.Morality.BodyFound", function(ply, deadply, rag)
    if not (IsValid(ply) and ply:IsPlayer()) then return end
    if not (IsValid(deadply) and deadply:IsPlayer()) then return end
    local corpseIsTraitor = deadply:GetTeam() ~= TEAM_INNOCENT
    local corpseIsPolice = deadply:GetRoleStringRaw() == "detective"

    for i, bot in pairs(lib.GetAliveBots()) do
        local morality = bot.components and bot.components.morality
        if not morality or not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then continue end
        if corpseIsTraitor then
            morality:ChangeSuspicion(ply, "IdentifiedTraitor")
        elseif corpseIsPolice then
            morality:ChangeSuspicion(ply, "IdentifiedTrusted")
        else
            morality:ChangeSuspicion(ply, "IdentifiedInnocent")
        end
    end
end)

-- ===========================================================================
-- Corpse proximity tracking
-- ===========================================================================

function BotMorality.IsPlayerNearUnfoundCorpse(ply, corpses)
    local IsIdentified = CORPSE.GetFound
    for _, corpse in pairs(corpses) do
        if not IsValid(corpse) then continue end
        if IsIdentified(corpse) then continue end
        local dist = ply:GetPos():Distance(corpse:GetPos())
        local THRESHOLD = 500
        if ply:Visible(corpse) and (dist < THRESHOLD) then
            return true
        end
    end
    return false
end

local playersNearBodies = {}
timer.Create("TTTBots.Components.Morality.PlayerCorpseTimer", 1, 0, function()
    if TTTBots.Match.RoundActive == false then return end
    local alivePlayers = TTTBots.Match.AlivePlayers
    local corpses = TTTBots.Match.Corpses

    for i, ply in pairs(alivePlayers) do
        if not IsValid(ply) then continue end
        local isNearCorpse = BotMorality.IsPlayerNearUnfoundCorpse(ply, corpses)
        if isNearCorpse then
            local prev = playersNearBodies[ply] or 0
            playersNearBodies[ply] = prev + 1
            -- After 3 continuous seconds near a body, apply suspicion + evidence
            if playersNearBodies[ply] == 3 then
                for _, bot in pairs(lib.GetAliveBots()) do
                    if not (bot.components and bot.components.morality) then continue end
                    if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then continue end
                    -- Only apply if the bot can see the player near the body
                    if not bot:Visible(ply) then continue end
                    bot.components.morality:ChangeSuspicion(ply, "NearUnidentified")
                    local evidence = bot:BotEvidence()
                    if evidence then
                        evidence:AddEvidence({
                            type    = "NEAR_BODY",
                            subject = ply,
                            detail  = "near unidentified corpse for 3+ seconds",
                        })
                    end
                end
            end
        else
            playersNearBodies[ply] = math.max((playersNearBodies[ply] or 0) - 1, 0)
        end
    end
end)

-- ===========================================================================
-- Disguised player detection
-- ===========================================================================

timer.Create("TTTBots.Components.Morality.DisguisedPlayerDetection", 1, 0, function()
    if not TTTBots.Match.RoundActive then return end
    local alivePlayers = TTTBots.Match.AlivePlayers
    for i, ply in pairs(alivePlayers) do
        local isDisguised = TTTBots.Match.IsPlayerDisguised(ply)

        if isDisguised then
            local witnessBots = lib.GetAllWitnesses(ply:EyePos(), true)
            for i, bot in pairs(witnessBots) do
                ---@cast bot Bot
                if not IsValid(bot) then continue end
                if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then continue end
                local chatter = bot:BotChatter()
                if not chatter or not chatter.On then continue end
                if bot.attackTarget == nil then
                    Arb.RequestAttackTarget(bot, ply, "DISGUISED_PLAYER", PRI.ROLE_HOSTILITY)
                end
                chatter:On("DisguisedPlayer")
            end
        end
    end
end)

-- ===========================================================================
-- Paranoia / False-Positive Suspicion — Innocent Mistrust System
-- ===========================================================================
-- Core TTT mechanic: innocents don't have perfect information, so they
-- sometimes become paranoid about other innocents. This generates organic
-- false-positive suspicion that can escalate to innocent-on-innocent attacks.
--
-- Events that trigger paranoia:
-- • Nearby player hasn't spoken/called out in a while ("too quiet")
-- • Nearby player is following us (already tracked via PersonalSpace/FollowingMe)
-- • Random paranoia spikes based on personality traits
-- • Late-round pressure when few players remain
-- • Player was near a body we later found (retroactive suspicion)

--- Paranoia suspicion values (lower than real events, but they accumulate)
BotMorality.PARANOIA_VALUES = {
    TooQuiet          = 1.5,  -- Player nearby but hasn't spoken or done anything notable
    NervousBehavior   = 2.0,  -- Player acting "nervously" (random misread)
    LateRoundPanic    = 2.5,  -- Panic when few players remain and unknowns are high
    RandomParanoia    = 1.0,  -- Baseline random paranoia spike
    TraitorMetagame   = 1.5,  -- "They were traitor last round" cross-round suspicion
}

timer.Create("TTTBots.Morality.ParanoiaTick", 10, 0, function()
    if not TTTBots.Match.IsRoundActive() then return end
    if not lib.GetConVarBool("innocent_mistrust") then return end

    local paranoiaChance = lib.GetConVarFloat("paranoia_chance") or 8
    if paranoiaChance <= 0 then return end

    for _, bot in pairs(TTTBots.Bots) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
        if not (bot.components and bot.components.morality) then continue end

        -- Only innocent-side bots that use suspicion get paranoid
        local roleData = TTTBots.Roles.GetRoleFor(bot)
        if not roleData:GetUsesSuspicion() then continue end

        -- Roll for paranoia event
        if math.random(1, 100) > paranoiaChance then continue end

        local morality = bot.components.morality
        local personality = bot:BotPersonality()

        -- Personality-driven paranoia multiplier
        local paranoidMult = 1.0
        if personality then
            -- Suspicious/cautious bots are more paranoid
            local susTrait = personality:GetTraitMult("suspicion") or 1.0
            paranoidMult = paranoidMult * math.min(susTrait, 2.0)

            -- Gullible/oblivious bots are less paranoid
            if personality:HasTrait("gullible") then paranoidMult = paranoidMult * 0.3 end
            if personality:HasTrait("oblivious") or personality:HasTrait("veryoblivious") then
                paranoidMult = paranoidMult * 0.4
            end

            -- High pressure increases paranoia
            local pressure = personality:GetPressure()
            paranoidMult = paranoidMult * (1.0 + pressure * 0.5)

            -- Rage increases paranoia
            local rage = personality:GetRage()
            paranoidMult = paranoidMult * (1.0 + rage * 0.3)
        end

        -- Late-round panic: more paranoia when fewer players remain
        local ra = bot:BotRoundAwareness()
        local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
        if ra and PHASE then
            local phase = ra:GetPhase()
            if phase == PHASE.LATE then
                paranoidMult = paranoidMult * 1.5
            elseif phase == PHASE.OVERTIME then
                paranoidMult = paranoidMult * 2.0
            end
        end

        -- Skip if paranoia is effectively zero
        if paranoidMult < 0.2 then continue end

        -- Find a nearby visible player to be paranoid about
        local visible = lib.GetAllWitnessesBasic(bot:EyePos(), TTTBots.Match.AlivePlayers, bot)
        if #visible == 0 then continue end

        -- Weight toward players we already have some suspicion of
        local candidates = {}
        for _, ply in ipairs(visible) do
            if ply == bot then continue end
            local existingSus = morality:GetSuspicion(ply)
            -- More likely to be paranoid about players we're already slightly suspicious of
            local weight = 1 + math.max(existingSus, 0) * 0.5
            -- Less likely to be paranoid about police/detective roles
            if TTTBots.Roles.GetRoleFor(ply):GetAppearsPolice() then
                weight = weight * 0.1
            end
            -- Less likely to be paranoid about tested-clean players
            if morality.testedClean and morality.testedClean[ply] then
                weight = weight * 0.05
            end
            for _ = 1, math.ceil(weight) do
                candidates[#candidates + 1] = ply
            end
        end

        if #candidates == 0 then continue end
        local target = candidates[math.random(#candidates)]

        -- Choose paranoia type
        local paranoiaType
        local roll = math.random(1, 100)
        if ra and PHASE and (ra:GetPhase() == PHASE.LATE or ra:GetPhase() == PHASE.OVERTIME) then
            paranoiaType = "LateRoundPanic"
        elseif roll <= 30 then
            paranoiaType = "NervousBehavior"
        elseif roll <= 60 then
            paranoiaType = "TooQuiet"
        else
            paranoiaType = "RandomParanoia"
        end

        local susValue = BotMorality.PARANOIA_VALUES[paranoiaType] or 1.0
        local finalIncrease = math.ceil(susValue * paranoidMult)

        -- Apply paranoia as low-confidence threat (bypasses ChangeSuspicion to
        -- avoid triggering announcement/attack cascades — this is background noise).
        -- Paranoia uses very low confidence (0.4) so it can never push the
        -- effective score past the Sus threshold on its own without corroborating
        -- real evidence raising confidence.
        local rec = morality:EnsureRecord(target)
        rec.threat = math.min(rec.threat + finalIncrease, 20)

        -- Blend confidence down: paranoia drags confidence toward 0.4
        local paranoiaConf = 0.4
        local totalWeight = rec.threat + rec.trust
        if totalWeight > 0 then
            rec.confidence = (rec.confidence * (totalWeight - finalIncrease) + paranoiaConf * finalIncrease) / totalWeight
        else
            rec.confidence = paranoiaConf
        end
        rec.lastEvent = CurTime()

        -- Anti-snowball: paranoia alone (confidence < 0.5) cannot push the
        -- effective score past the Sus threshold. Only corroborated suspicion
        -- (confidence ≥ 0.5, i.e. backed by real witness events) can cross it.
        local newSus = morality:GetSuspicion(target)

        -- Occasionally vocalize the paranoia
        if math.random(1, 100) <= 15 and finalIncrease >= 2 then
            local chatter = bot:BotChatter()
            if chatter and chatter.On then
                if newSus >= BotMorality.Thresholds.KOS then
                    chatter:On("CallKOS", { player = target:Nick() })
                elseif newSus >= BotMorality.Thresholds.Sus then
                    chatter:On("DeclareSuspicious", { player = target:Nick() })
                end
            end
        end

        -- Check if this push crosses the attack threshold — but only if
        -- confidence is high enough (paranoia alone shouldn't trigger attacks)
        if rec.confidence >= 0.5 then
            morality:SetAttackIfTargetSus(target)
        end

        if lib.GetConVarBool("debug_misc") then
            print(string.format("[TTTBots][PARANOIA] %s +%d threat on %s (%s, mult=%.2f, eff=%d, conf=%.2f)",
                bot:Nick(), finalIncrease, target:Nick(), paranoiaType, paranoidMult,
                newSus, rec.confidence))
        end
    end
end)

hook.Add("TTTEndRound", "TTTBots.Morality.ClearParanoia", function()
    -- Paranoia state is already wiped by the morality round reset (suspicions = {})
end)

-- Clear corpse proximity tracking between rounds
hook.Add("TTTEndRound", "TTTBots.Morality.ClearPlayersNearBodies", function()
    playersNearBodies = {}
end)

hook.Add("TTTPrepareRound", "TTTBots.Morality.PreparePlayersNearBodies", function()
    playersNearBodies = {}
end)

-- When a player passes a role tester, mark them as tested clean in nearby bots' morality
-- 🟡 9: Enhanced tester result sharing — broadcast results to ALL bots within
-- a generous radius (not just direct witnesses), and have the detective
-- announce the result via chatter so human players get the information too.
hook.Add("TTTBots.UseRoleChecker.Result", "TTTBots.Morality.TestedClean", function(user, target, result)
    -- result is expected to be "innocent" or "traitor" or similar
    if not (IsValid(user) and IsValid(target)) then return end

    -- Gather all bots that should learn about this result.
    -- Use a generous radius (1500 units) instead of strict line-of-sight
    -- to simulate the loud/public nature of a tester result announcement.
    local userPos = user:GetPos()
    local informedBots = {}

    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
        if not (bot.components and bot.components.morality) then continue end

        -- Inform bots that can see the tester user OR are within broadcast range
        local dist = bot:GetPos():Distance(userPos)
        local canSee = bot:Visible(user)
        if canSee or dist < 1500 then
            table.insert(informedBots, bot)
        end
    end

    for _, bot in ipairs(informedBots) do
        if result == "innocent" then
            bot.components.morality:SetTestedClean(target)
        else
            -- Target failed the test — strong evidence of guilt
            local morality = bot.components.morality
            morality:ChangeSuspicion(target, "Kill", 2) -- Strong suspicion

            local evidence = bot:BotEvidence()
            if evidence then
                evidence:AddEvidence({
                    type    = "FAILED_TEST",
                    subject = target,
                    detail  = "failed the role tester",
                })
            end
        end

        -- Record in memory for LLM context
        local mem = bot:BotMemory()
        if mem and mem.AddWitnessEvent then
            mem:AddWitnessEvent("tester", string.format(
                "%s %s the role tester (%s)",
                target:Nick(),
                result == "innocent" and "passed" or "FAILED",
                result
            ))
        end
    end

    -- 🟡 9: Detective announces the tester result via chatter so all players
    -- (including humans) learn the outcome. Only the closest detective announces.
    local detBot = nil
    local detBestDist = math.huge
    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
        local role = TTTBots.Roles.GetRoleFor(bot)
        if role and role:GetAppearsPolice() then
            local d = bot:GetPos():Distance(userPos)
            if d < detBestDist then
                detBestDist = d
                detBot = bot
            end
        end
    end

    if detBot then
        local chatter = detBot:BotChatter()
        if chatter and chatter.On then
            if result == "innocent" then
                chatter:On("DeclareInnocent", { player = target:Nick() })
            else
                chatter:On("CallKOS", { player = target:Nick() })
                TTTBots.Match.CallKOS(detBot, target)
            end
        end
    end
end)

-- ===========================================================================
-- Ankh-related suspicion monitoring (M-1, M-2, M-3)
-- ===========================================================================

--- M-1: Witness ankh conversion — if an innocent bot sees someone using (converting)
--- an ankh, that's highly suspicious. Pharaohs know the converter is hostile.
--- M-2: Witness ankh damage — if a bot sees someone shooting an ankh, raise suspicion.
--- M-3: Proximity suspicion — non-owner players loitering near an ankh are suspicious.

timer.Create("TTTBots.Morality.AnkhSuspicion", 2, 0, function()
    if not TTTBots.Match.RoundActive then return end
    if not ROLE_PHARAOH then return end

    local ankhs = ents.FindByClass("ttt_ankh")
    if #ankhs == 0 then return end

    for _, ankh in pairs(ankhs) do
        if not IsValid(ankh) then continue end
        local ankhPos = ankh:GetPos()
        local owner = ankh:GetOwner()

        -- M-1: Check for conversion in progress (someone using the ankh)
        -- Check both ankh.last_activator (human player USE) and ankh._tttbots_converter
        -- (bot conversion via CaptureAnkh behavior, which bypasses ENT:Use())
        local activator = ankh.last_activator or ankh._tttbots_converter
        if IsValid(activator) and activator:IsPlayer() and lib.IsPlayerAlive(activator) then
            -- Find witness bots who can see this
            local witnesses = lib.GetAllWitnessesBasic(activator:EyePos(), TTTBots.Match.AlivePlayers, activator)
            for _, witness in ipairs(witnesses) do
                if not (IsValid(witness) and witness:IsBot() and witness.components and witness.components.morality) then continue end
                if witness == activator then continue end

                local morality = witness.components.morality
                if not TTTBots.Roles.GetRoleFor(witness):GetUsesSuspicion() then continue end

                -- Witnessing ankh conversion is highly suspicious
                morality:ChangeSuspicion(activator, "AnkhConversionWitnessed")

                -- Feed evidence log
                local evidence = witness:BotEvidence()
                if evidence then
                    evidence:AddEvidence({
                        type    = "ANKH_CONVERSION",
                        subject = activator,
                        detail  = "converting an ankh",
                    })
                end

                -- If the witness is the Pharaoh who owns this ankh, KOS the converter
                if witness == owner and owner:GetSubRole() == ROLE_PHARAOH then
                    Arb.RequestAttackTarget(witness, activator, "DEFEND_ANKH", PRI.PLAYER_REQUEST)
                end
            end
        end

        -- M-3: Non-owner players loitering near the ankh
        local nearbyEnts = ents.FindInSphere(ankhPos, 200)
        for _, ent in pairs(nearbyEnts) do
            if not (IsValid(ent) and ent:IsPlayer() and lib.IsPlayerAlive(ent)) then continue end
            if ent == owner then continue end -- Owner standing near their own ankh is fine

            -- Only the Pharaoh bot who owns the ankh gets suspicious of loiterers
            if not (IsValid(owner) and owner:IsBot() and owner.components and owner.components.morality) then continue end
            if not TTTBots.Roles.GetRoleFor(owner):GetUsesSuspicion() then continue end
            if not owner:Visible(ent) then continue end

            owner.components.morality:ChangeSuspicion(ent, "AnkhLoiteringNearby")
        end
    end
end)

--- M-2: Witness ankh damage — hook into entity damage to detect ankh attacks
hook.Add("EntityTakeDamage", "TTTBots.Morality.AnkhDamageWitness", function(target, dmginfo)
    if not TTTBots.Match.RoundActive then return end
    if not ROLE_PHARAOH then return end
    if not (IsValid(target) and target:GetClass() == "ttt_ankh") then return end

    local attacker = dmginfo:GetAttacker()
    if not (IsValid(attacker) and attacker:IsPlayer() and lib.IsPlayerAlive(attacker)) then return end

    -- Find witness bots
    local witnesses = lib.GetAllWitnessesBasic(attacker:EyePos(), TTTBots.Match.AlivePlayers, attacker)
    for _, witness in ipairs(witnesses) do
        if not (IsValid(witness) and witness:IsBot() and witness.components and witness.components.morality) then continue end
        if witness == attacker then continue end

        local morality = witness.components.morality
        if not TTTBots.Roles.GetRoleFor(witness):GetUsesSuspicion() then continue end

        morality:ChangeSuspicion(attacker, "AnkhDestructionWitnessed")

        local evidence = witness:BotEvidence()
        if evidence then
            evidence:AddEvidence({
                type    = "ANKH_DAMAGE",
                subject = attacker,
                detail  = "shooting/damaging an ankh",
            })
        end
    end
end)
