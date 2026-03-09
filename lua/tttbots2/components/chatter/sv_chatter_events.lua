--- sv_chatter_events.lua
--- Event probability table, BotChatter:On() (main event dispatcher),
--- the PlayerCanSeePlayersChat hook, and the SillyChat idle timer.
--- Depends on: sv_chatter_dispatch.lua (BotChatter:textorTTS)

local lib = TTTBots.Lib
local BotChatter = TTTBots.Components.Chatter

-- ---------------------------------------------------------------------------
-- Event probability table (base chances out of 100)
-- ---------------------------------------------------------------------------

local chancesOf100 = {
    InvestigateNoise           = 15,
    InvestigateCorpse          = 65, -- overrides the 15 below (last entry wins in Lua)
    DeclareInnocent            = 25,
    DeclareSuspicious          = 20,
    DeclareTrustworthy         = 15,
    WaitStart                  = 40,
    WaitEnd                    = 40,
    WaitRefuse                 = 40,
    FollowMe                   = 20, -- overrides the 40 below
    FollowMeRefuse             = 40,
    FollowMeEnd                = 40,
    LifeCheck                  = 65,
    Kill                       = 25,
    -- CallKOS is set dynamically (15 * difficulty) inside BotChatter:On
    FollowStarted              = 10,
    ServerConnected            = 45,
    SillyChat                  = 30,
    SillyChatDead              = 15,
    AttackStart                = 80,
    AttackRefuse               = 80,
    CreatingCursed             = 80,
    CreatingDefector           = 80,
    CreatingMedic              = 80,
    CreatingDoctor             = 80,
    CreatingSidekick           = 80,
    CreatingDeputy             = 80,
    CreatingSlave              = 60,
    CeaseFireStart             = 60,
    CeaseFireRefuse            = 60,
    CeaseFireEnd               = 60,
    HealAccepted               = 80,
    HealRefused                = 50,
    RoleCheckerRequestAccepted = 90,
    UsingRoleChecker           = 50,
    ComeHereStart              = 75,
    ComeHereRefuse             = 50,
    ComeHereEnd                = 50,
    JihadBombWarn              = 75,
    JihadBombUse               = 100,
    UseTraitorButton           = 60,  -- Activating a traitor button
    PlacedAnkh                 = 75,
    NewContract                = 75,
    ContractAccepted           = 75,
    -- -----------------------------------------------------------------------
    -- Social Deduction Core — new events
    -- -----------------------------------------------------------------------
    WitnessCallout             = 90,  -- Saw someone kill (richer than Kill)
    ProximityCallout           = 40,  -- Someone has been following/crowding
    DeathCallout               = 80,  -- Bot's last words naming their killer
    LifeCheckRollCall          = 65,  -- "Who's still alive? Sound off"
    AccuseKOS                  = 85,  -- Strong evidence KOS accusation
    AccuseMedium               = 75,  -- Medium evidence declaration
    AccuseSoft                 = 50,  -- Weak/soft suspicion hint
    AccuseRetract              = 70,  -- Retracting a previous accusation
    RequestRoleCheck           = 80,  -- Asking a player to take the role test
    DefendOfferTest            = 80,  -- "I'll use the tester, I'm clean"
    DefendAlibi                = 80,  -- "I was with {{player}} the whole time"
    DefendCounterAccuse        = 75,  -- Innocent counter-accusing
    DefendAppealGroup          = 65,  -- Appealing to group
    DefendRage                 = 60,  -- Hothead rage at accuser
    DefendFeign                = 70,  -- Traitor feigning innocence
    DefendFrameOther           = 70,  -- Traitor framing someone else
    DefendAssassinate          = 60,  -- Traitor announcing they'll silence someone (team-only)
    DefendTraitorPanic         = 55,  -- Dumb traitor panicking
    BreakTrust                 = 75,  -- "Wait, {{player}} just... I take it back!"
    VouchChat                  = 70,  -- "{{player}} is with me, they're clean"
    EvidenceShare              = 60,  -- Sharing evidence with a nearby bot
    BodyEvidenceFound          = 75,  -- Bot found killer info on a corpse
    -- -----------------------------------------------------------------------
    -- Round Phase Awareness
    -- -----------------------------------------------------------------------
    PhaseGroupUp               = 60,  -- "We're running out of time, group up!" (late/innocent)
    PhaseOvertimePanic         = 80,  -- "Test everyone NOW" (overtime/innocent)
    PhaseTraitorNow            = 65,  -- "Now's our chance" (late/traitor, team-only)
    PhaseOvertimeAssault       = 75,  -- "All-out, no more stealth" (overtime/traitor, team-only)
    DeductionMustBeTraitor     = 70,  -- "Process of elimination — it's gotta be X"
    TooQuiet                   = 45,  -- "Nobody's died in a while... stay alert"
    OvertakeWarning            = 60,  -- "They outnumber us, be careful" (innocent)
    OvertakeReady              = 65,  -- "We have numbers — move in" (traitor, team-only)
    DangerZoneWarning          = 55,  -- "Stay away from X, someone just died there"
    TraitorCountDeduction      = 65,  -- "One traitor left, stay sharp" (innocent/detective)
    DNAMatch                   = 90,  -- DNA scanner found a match
    ScanningBody               = 40,  -- About to scan a body
    -- -----------------------------------------------------------------------
    -- Tier 6 — Personality & Immersion: Emotional Reactions
    -- -----------------------------------------------------------------------
    WitnessKill                = 85,  -- Bot witnessed a kill in front of them
    BeingShotAt                = 60,  -- Bot is being shot at before combat kicks in
    FindFriendBody             = 80,  -- Bot found the body of a trusted player
    RoundStart                 = 35,  -- Bot comments at round start
    OvertimeHaste              = 90,  -- Bot reacts to overtime/haste activating
    LastInnocent               = 95,  -- Bot realizes they are the last innocent alive
    TraitorVictory             = 70,  -- Traitor gloats after winning (team chat)
    -- Deception chatter events
    AlibiBuilding              = 40,  -- Traitor makes small talk to build alibi
    FakeInvestigateApproach    = 75,  -- Traitor announces they'll check a body
    FakeInvestigateReport      = 85,  -- Traitor reports fake findings from a body
    FalseKOS                   = 80,  -- Traitor calls false KOS on an innocent
    PlausibleIgnorance         = 80,  -- Traitor excuses presence near fresh kill
    -- -----------------------------------------------------------------------
    -- Casual / Idle events
    -- -----------------------------------------------------------------------
    CasualObservation          = 20,  -- Random map/environment observation
    CasualJoke                 = 15,  -- Light joke or pun
    CasualStory                = 15,  -- Mini anecdote snippet
    CasualCompliment           = 20,  -- Complimenting another player
    CasualComplaint            = 18,  -- Low-stakes gripe
    CasualQuestion             = 22,  -- Rhetorical or idle question
    CasualNervous              = 25,  -- Nervous small-talk during quiet stretch
    CasualBoredom              = 35,  -- Boredom-driven chatter (boosted by mood multiplier)
    CasualWeather              = 12,  -- Absurd map flavour observation
    PostCombatRelief           = 60,  -- After surviving a fight
    NearMissReaction           = 50,  -- Bullet narrowly missed
    SurvivorRelief             = 55,  -- Survived when others nearby died
    QuietRoundComment          = 30,  -- Nobody has died in a long while
    -- -----------------------------------------------------------------------
    -- Infected role events
    -- -----------------------------------------------------------------------
    ZombieSpotted              = 90,  -- Bot sees a player get converted into a zombie
    HostKilled                 = 85,  -- The infected host was killed
    InfectedTeamRush           = 70,  -- Infected team-chat: rallying zombies to attack
    InfectedVictory            = 80,  -- Infected team won the round
    -- -----------------------------------------------------------------------
    -- Doomguy / Doom Slayer events
    -- -----------------------------------------------------------------------
    DoomguySpotted             = 90,  -- Bot spots the Doom Slayer (public alert)
    DoomguyKilledPlayer        = 85,  -- Doomguy killed a player in view of the bot
    DoomguyWeak                = 80,  -- Doomguy appears to be at low health — push time
    DoomguyChasingMe           = 95,  -- Bot is being actively chased by Doomguy
    DoomguyAvoid               = 65,  -- Bot warns others not to approach Doomguy alone
    DoomguyAtLocation          = 70,  -- Bot calls out Doomguy's last known location
}

-- ---------------------------------------------------------------------------
-- Casual event classification helpers
-- ---------------------------------------------------------------------------

--- Full set of event names that are casual/idle in nature.
--- These use the dedicated casual LLM prompts and the separate chance cvar.
local CASUAL_EVENT_SET = {
    CasualObservation = true, CasualJoke     = true, CasualStory       = true,
    CasualCompliment  = true, CasualComplaint= true, CasualQuestion    = true,
    CasualNervous     = true, CasualBoredom  = true, CasualWeather     = true,
    PostCombatRelief  = true, NearMissReaction= true, SurvivorRelief   = true,
    QuietRoundComment = true,
    -- Also treat the legacy SillyChat events as casual for mood-gating purposes
    SillyChat = true, SillyChatDead = true,
}

--- Map from casual event name → triggerReason string consumed by the prompt builders.
local CASUAL_TRIGGER_REASON = {
    CasualBoredom     = "boredom",
    PostCombatRelief  = "post_combat",
    NearMissReaction  = "near_miss",
    SurvivorRelief    = "survivor",
    QuietRoundComment = "quiet_round",
    -- everything else defaults to "idle"
}
local function getCasualTriggerReason(event_name)
    return CASUAL_TRIGGER_REASON[event_name] or "idle"
end

--- Build the appropriate prompt for a casual event.
--- Returns: prompt (string or table), isCasualLLM (bool), sendOpts (table).
local function buildCasualPrompt(bot, event_name, args, teamOnly)
    local triggerReason = getCasualTriggerReason(event_name)
    local providerInt   = lib.GetConVarInt("chatter_api_provider")
    local prompt, sendOpts

    if providerInt == 4 then
        -- Ollama / local LLM — GetCasualPrompt returns {system, prompt}
        local promptData = TTTBots.LlamaPrompts and TTTBots.LlamaPrompts.GetCasualPrompt(bot, triggerReason)
        if promptData then
            prompt = promptData.prompt or ""
            sendOpts = {
                teamOnly      = teamOnly,
                wasVoice      = false,
                systemPrompt  = promptData.system,
                triggerReason = triggerReason,
                eventName     = event_name,
                eventArgs     = args,
            }
        end
    else
        -- Cloud providers (ChatGPT / Gemini / DeepSeek / OpenRouter / mixed)
        local cloudPrompt = TTTBots.PromptContext and TTTBots.PromptContext.GetCasualCloudPrompt(bot, triggerReason)
        if cloudPrompt then
            prompt = cloudPrompt
            sendOpts = {
                teamOnly      = teamOnly,
                wasVoice      = false,
                triggerReason = triggerReason,
                eventName     = event_name,
                eventArgs     = args,
            }
        end
    end

    -- Fallback: if the casual prompt builders are unavailable, use the generic prompt
    if not prompt then
        prompt = TTTBots.ChatGPTPrompts.GetChatGPTPrompt(event_name, bot, args, teamOnly, true, nil)
        sendOpts = {
            teamOnly  = teamOnly,
            wasVoice  = false,
            eventName = event_name,
            eventArgs = args,
        }
    end

    return prompt, sendOpts
end

-- ---------------------------------------------------------------------------
-- BotChatter:On  — main event entry-point
-- ---------------------------------------------------------------------------

--- React to a named game event with LLM-backed or localized chat output.
---@param event_name string
---@param args table|nil    arbitrary event arguments
---@param teamOnly boolean|nil
---@param delay number|nil  optional delay before speaking
---@param description string|nil  optional human-readable description for the LLM prompt
---@return boolean  true if a reply was (or will be) sent
function BotChatter:On(event_name, args, teamOnly, delay, description)
    local dvlpr = lib.GetConVarBool("debug_misc")
    if dvlpr then
        print(string.format("Event %s called with %d args.", event_name, args and #args or 0))
    end

    if not self:CanSayEvent(event_name) then return false end

    -- Special gate: don't call KOS on the same target more than once per 5 s
    if event_name == "CallKOS" then
        local target = args and args.playerEnt
        if target and IsValid(target) then
            if (target.lastKOSTime or 0) + 5 > CurTime() then return false end
            target.lastKOSTime = CurTime()
        end
    end

    -- Special gate: Kill event needs valid victim + attacker
    if event_name == "Kill" then
        if not (args and args.victim and args.attacker and args.victimEnt and args.attackerEnt) then
            return false
        end
    end

    local difficulty   = lib.GetConVarInt("difficulty")
    local ChanceMult   = lib.GetConVarFloat("chatter_chance_multi") or 1

    -- Dynamic CallKOS probability
    local dynamicChances = table.Copy(chancesOf100)
    dynamicChances.CallKOS = 15 * difficulty

    local personality = self.bot.components.personality ---@type CPersonality
    local isCasualEvent = CASUAL_EVENT_SET[event_name] == true

    if dynamicChances[event_name] then
        local chance = dynamicChances[event_name]
        -- For casual/idle events, apply the mood multiplier so boredom increases
        -- chatter frequency while pressure/rage suppress it.
        local moodMult = isCasualEvent
            and (personality.GetChatMoodMultiplier and personality:GetChatMoodMultiplier() or 1.0)
            or 1.0
        if math.random(0, 100) > (chance * personality:GetTraitMult("textchat") * ChanceMult * moodMult) then
            return false
        end
    end

    -- Build localized response string, falling back to locale if LLM fails
    local localizedString
    local function handleChatResponse(response)
        if response then
            return TTTBots.Locale.FormatArgsIntoTxt(response, args) or response
        else
            return TTTBots.Locale.GetLocalizedLine(event_name, self.bot, args) or "I don't know what to say."
        end
    end

    local function setLocalizedString(response)
        localizedString = handleChatResponse(response)
        local isCasualArch = personality:GetClosestArchetype() == TTTBots.Archetypes.Casual
        if localizedString then
            if isCasualArch then localizedString = string.lower(localizedString) end
            if delay then
                timer.Simple(delay, function()
                    if not IsValid(self.bot) then return end
                    self:textorTTS(self.bot, localizedString, teamOnly, event_name, args)
                end)
            else
                self:textorTTS(self.bot, localizedString, teamOnly, event_name, args)
            end
            return true
        end
        return false
    end

    -- -----------------------------------------------------------------------
    -- Casual event path — dedicated prompt builders + separate LLM chance
    -- -----------------------------------------------------------------------
    if isCasualEvent then
        local casualLLMEnabled = lib.GetConVarBool("chatter_casual_llm")
        local casualLLMChance  = lib.GetConVarFloat("chatter_casual_llm_chance") or 0.4

        if casualLLMEnabled and math.random() < casualLLMChance then
            local prompt, sendOpts = buildCasualPrompt(self.bot, event_name, args, teamOnly)
            TTTBots.Providers.SendText(prompt, self.bot, sendOpts, function(envelope)
                if not IsValid(self.bot) then return end
                setLocalizedString(envelope.ok and envelope.text or nil)
            end)
        else
            -- Locale path for casual events
            localizedString = TTTBots.Locale.GetLocalizedLine(event_name, self.bot, args)
            if localizedString then
                setLocalizedString(localizedString)
                return true
            else
                -- No locale line; try LLM as fallback even if casual LLM is off
                local prompt, sendOpts = buildCasualPrompt(self.bot, event_name, args, teamOnly)
                TTTBots.Providers.SendText(prompt, self.bot, sendOpts, function(envelope)
                    if not IsValid(self.bot) then return end
                    setLocalizedString(envelope.ok and envelope.text or nil)
                end)
            end
        end
        return false
    end

    -- -----------------------------------------------------------------------
    -- Standard (non-casual) event path
    -- -----------------------------------------------------------------------
    local chatGPTChance = lib.GetConVarFloat("chatter_gpt_chance") or 0.25

    local prompt = TTTBots.ChatGPTPrompts.GetChatGPTPrompt(event_name, self.bot, args, teamOnly, true, description)
    local sendOpts = {
        teamOnly = teamOnly,
        wasVoice = false,
        -- Extra context for adapters that build their own prompts (e.g. Ollama/llama)
        eventName   = event_name,
        eventArgs   = args,
        description = description,
    }

    if math.random() < chatGPTChance then
        TTTBots.Providers.SendText(prompt, self.bot, sendOpts, function(envelope)
            if not IsValid(self.bot) then return end
            setLocalizedString(envelope.ok and envelope.text or nil)
        end)
    else
        localizedString = TTTBots.Locale.GetLocalizedLine(event_name, self.bot, args)
        if not localizedString then
            TTTBots.Providers.SendText(prompt, self.bot, sendOpts, function(envelope)
                if not IsValid(self.bot) then return end
                setLocalizedString(envelope.ok and envelope.text or nil)
            end)
        else
            setLocalizedString(localizedString)
            return true
        end
    end

    return false
end

-- ---------------------------------------------------------------------------
-- PlayerCanSeePlayersChat — restrict team chat to team members
-- ---------------------------------------------------------------------------

hook.Add("PlayerCanSeePlayersChat", "TTTBots_PlayerCanSeePlayersChat", function(text, teamOnly, listener, sender)
    if not (IsValid(sender) and sender:IsBot() and teamOnly) then return end
    if not lib.IsPlayerAlive(sender) then return false end
    if listener:IsInTeam(sender) then return true end
    return false
end)

-- ---------------------------------------------------------------------------
-- SillyChat timer — random idle chatter every ~3 minutes
-- ---------------------------------------------------------------------------

timer.Create("TTTBots.Chatter.SillyChat", 20, 0, function()
    if math.random(1, 9) > 1 then return end
    local targetBot = TTTBots.Bots[math.random(1, #TTTBots.Bots)]
    if not (targetBot and IsValid(targetBot)) then return end
    if not targetBot.components then return end

    local chatter = targetBot:BotChatter()
    if not chatter then return end

    local randomPlayer = TTTBots.Match.AlivePlayers[math.random(1, #TTTBots.Match.AlivePlayers)]
    if not randomPlayer or randomPlayer == targetBot then return end

    local eventName = lib.IsPlayerAlive(targetBot) and "SillyChat" or "SillyChatDead"
    chatter:On(eventName, { player = randomPlayer:Nick() })
end)

-- ---------------------------------------------------------------------------
-- Casual proximity trigger — bots near each other start idle conversation
-- ---------------------------------------------------------------------------

local CASUAL_PROXIMITY_DIST = 300  -- units; close enough to chat
--- Casual event pool (weighted): pick from these for proximity-triggered chatter
local casualProximityPool = {
    { event = "CasualObservation", weight = 3 },
    { event = "CasualJoke",        weight = 2 },
    { event = "CasualQuestion",    weight = 3 },
    { event = "CasualNervous",     weight = 2 },
    { event = "CasualCompliment",  weight = 2 },
    { event = "CasualWeather",     weight = 1 },
    { event = "CasualStory",       weight = 1 },
}
local casualProximityWeighted = (function()
    local t = {}
    for _, entry in ipairs(casualProximityPool) do
        for _ = 1, entry.weight do table.insert(t, entry.event) end
    end
    return t
end)()

timer.Create("TTTBots.Chatter.CasualProximity", 15, 0, function()
    if not TTTBots.Match.RoundActive then return end
    local bots = lib.GetAliveBots()
    if #bots < 2 then return end

    -- Shuffle bot list to avoid always picking the same pair
    local shuffled = table.Copy(bots)
    for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    for _, bot in ipairs(shuffled) do
        if not (IsValid(bot) and bot.components) then continue end
        local personality = bot:BotPersonality()
        if not personality then continue end

        -- Respect the mood multiplier — high pressure bots skip casual chat
        local moodMult = personality.GetChatMoodMultiplier
            and personality:GetChatMoodMultiplier() or 1.0
        if moodMult <= 0.1 then continue end  -- silent/suppressed

        -- Find a nearby bot to chat with
        local botPos = bot:GetPos()
        local chatTarget = nil
        for _, other in ipairs(shuffled) do
            if other == bot then continue end
            if not (IsValid(other) and other.components) then continue end
            if botPos:Distance(other:GetPos()) <= CASUAL_PROXIMITY_DIST then
                chatTarget = other
                break
            end
        end
        if not chatTarget then continue end

        -- Per-bot casual cooldown (separate from regular rate-limit table)
        local now = CurTime()
        if (bot._lastCasualProximityTime or 0) + 30 > now then continue end
        bot._lastCasualProximityTime = now

        -- Mark both bots as in conversation so the memory system is aware
        local botMem    = bot.components.memory
        local targetMem = chatTarget.components and chatTarget.components.memory
        if botMem then
            botMem.conversationPartner  = chatTarget
            botMem.lastConversationTime = CurTime()
        end
        if targetMem then
            targetMem.conversationPartner  = bot
            targetMem.lastConversationTime = CurTime()
        end

        -- Pick a random casual event from the weighted pool
        local eventName = casualProximityWeighted[math.random(1, #casualProximityWeighted)]
        local chatter = bot:BotChatter()
        if chatter then
            chatter:On(eventName, { player = chatTarget:Nick() }, false, math.random(0, 2))
        end
        break  -- one pair per sweep to keep it natural
    end
end)

hook.Add("TTTBeginRound", "TTTBots.Chatter.ResetCasualProximity", function()
    for _, bot in ipairs(TTTBots.Bots) do
        if IsValid(bot) then bot._lastCasualProximityTime = nil end
    end
end)

-- ---------------------------------------------------------------------------
-- Death callout — bot's last words naming their killer
-- ---------------------------------------------------------------------------

hook.Add("PlayerDeath", "TTTBots.Chatter.DeathCallout", function(victim, weapon, attacker)
    if not (IsValid(victim) and victim:IsBot()) then return end
    if not (IsValid(attacker) and attacker:IsPlayer()) then return end

    local chatter = victim:BotChatter()
    if not chatter then return end

    local personality = victim:BotPersonality()
    local archetype   = personality and personality:GetClosestArchetype() or "Default"
    local A = TTTBots.Archetypes

    -- Dumb archetype: 20% chance to name the wrong person as their killer
    local namedKiller = attacker
    if archetype == A.Dumb and math.random(1, 100) <= 20 then
        local alive = TTTBots.Match.AlivePlayers or {}
        local others = {}
        for _, p in ipairs(alive) do
            if p ~= victim and p ~= attacker then table.insert(others, p) end
        end
        if #others > 0 then
            namedKiller = others[math.random(1, #others)]
        end
    end

    chatter:On("DeathCallout", { player = namedKiller:Nick(), playerEnt = namedKiller }, false, 0)
end)

-- ---------------------------------------------------------------------------
-- Life check roll call — periodic "who's alive?" callout
-- ---------------------------------------------------------------------------

timer.Create("TTTBots.Chatter.LifeCheck", 90, 0, function()
    if not TTTBots.Match.RoundActive then return end
    local bots = lib.GetAliveBots()
    if #bots == 0 then return end

    local caller = bots[math.random(1, #bots)]
    if not (caller and IsValid(caller) and caller.components) then return end

    local chatter = caller:BotChatter()
    if not chatter then return end

    chatter:On("LifeCheckRollCall", {}, false, 0)

    -- Start tracking who responds in CEvidence
    local evidence = caller:BotEvidence()
    if evidence then
        evidence:StartLifeCheck()
        -- Schedule result processing after LIFE_CHECK_WINDOW seconds
        timer.Simple(16, function()
            if IsValid(caller) and caller.components and caller.components.evidence then
                caller.components.evidence:ProcessLifeCheckResults()
            end
        end)
    end
end)

-- ---------------------------------------------------------------------------
-- Evidence sharing — bots near each other share evidence periodically
-- ---------------------------------------------------------------------------

timer.Create("TTTBots.Chatter.EvidenceShare", 15, 0, function()
    if not TTTBots.Match.RoundActive then return end
    local bots = lib.GetAliveBots()

    for _, bot in ipairs(bots) do
        if not (IsValid(bot) and bot.components) then continue end
        local evidence = bot:BotEvidence()
        if not evidence then continue end
        if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then continue end

        -- Share evidence with nearby allied/trustworthy bots
        local nearby = TTTBots.Lib.GetAllWitnessesBasic(bot:EyePos(), TTTBots.Match.AlivePlayers, bot)
        for _, other in ipairs(nearby) do
            if not (IsValid(other) and other:IsBot()) then continue end
            if other == bot then continue end
            -- Share if they are on same team or both confirmed innocent-side
            if bot:GetTeam() == other:GetTeam() or
               (bot:GetTeam() == TEAM_INNOCENT and other:GetTeam() == TEAM_INNOCENT) then
                local myEvidence = bot:BotEvidence()
                if myEvidence then
                    myEvidence:ShareEvidence(other)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Phase-aware chatter — periodic round-phase callouts
-- ---------------------------------------------------------------------------

timer.Create("TTTBots.Chatter.PhaseAwareness", 30, 0, function()
    if not TTTBots.Match.RoundActive then return end
    local bots = lib.GetAliveBots()
    if #bots == 0 then return end

    -- Pick a random eligible bot as the speaker
    local speaker = bots[math.random(1, #bots)]
    if not (speaker and IsValid(speaker) and speaker.components) then return end
    local chatter = speaker:BotChatter()
    if not chatter then return end

    local ra = speaker:BotRoundAwareness()
    if not ra then return end

    local phase = ra:GetPhase()
    local role = TTTBots.Roles.GetRoleFor(speaker)
    local isTraitor = role:GetTeam() == TEAM_TRAITOR
    local usesSuspicion = role:GetUsesSuspicion()
    local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE

    -- Too quiet detection (any role)
    if ra:IsTooQuiet() and math.random(1, 3) == 1 then
        chatter:On("TooQuiet", {}, false)
        return
    end

    -- Overtake awareness
    if ra:IsOvertake() then
        if isTraitor and math.random(1, 2) == 1 then
            chatter:On("OvertakeReady", {}, true)  -- team-only
            return
        elseif usesSuspicion then
            chatter:On("OvertakeWarning", {}, false)
            return
        end
    end

    -- Phase-specific callouts
    if PHASE then
        if phase == PHASE.LATE then
            if isTraitor then
                chatter:On("PhaseTraitorNow", {}, true)
            elseif usesSuspicion then
                chatter:On("PhaseGroupUp", {}, false)
            end
        elseif phase == PHASE.OVERTIME then
            if isTraitor then
                chatter:On("PhaseOvertimeAssault", {}, true)
            elseif usesSuspicion then
                chatter:On("PhaseOvertimePanic", {}, false)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Deduction chatter — "process of elimination" callouts
-- ---------------------------------------------------------------------------

timer.Create("TTTBots.Chatter.Deduction", 45, 0, function()
    if not TTTBots.Match.RoundActive then return end
    local bots = lib.GetAliveBots()
    if #bots == 0 then return end

    for _, bot in ipairs(bots) do
        if not (IsValid(bot) and bot.components) then continue end
        local role = TTTBots.Roles.GetRoleFor(bot)
        if not role:GetUsesSuspicion() then continue end  -- only innocents/detectives

        local ra = bot:BotRoundAwareness()
        if not ra then continue end

        local chatter = bot:BotChatter()
        if not chatter then continue end

        -- "One traitor left" deduction
        local remaining = ra:GetRemainingTraitorCount()
        if remaining == 1 and math.random(1, 4) == 1 then
            chatter:On("TraitorCountDeduction", { count = remaining }, false)
        end

        -- "Process of elimination" — only when very few unknowns remain
        local susPress = ra:GetSuspicionPressure()
        if susPress >= 2.0 then
            local evidence = bot:BotEvidence()
            if evidence then
                local suspects = evidence:GetSuspects(6)
                if #suspects == 1 then
                    local suspect = suspects[1]
                    if IsValid(suspect) then
                        chatter:On("DeductionMustBeTraitor", { player = suspect:Nick(), playerEnt = suspect }, false)
                    end
                end
            end
        end

        break  -- only one bot speaks per sweep to avoid spam
    end
end)

-- ---------------------------------------------------------------------------
-- Danger zone proximity warning
-- ---------------------------------------------------------------------------

timer.Create("TTTBots.Chatter.DangerZone", 8, 0, function()
    if not TTTBots.Match.RoundActive then return end
    local bots = lib.GetAliveBots()

    for _, bot in ipairs(bots) do
        if not (IsValid(bot) and bot.components) then continue end
        local role = TTTBots.Roles.GetRoleFor(bot)
        if not role:GetUsesSuspicion() then continue end  -- only innocents warn about danger zones

        local memory = bot:BotMemory()
        if not memory then continue end

        -- Check if the bot's current wander destination is a danger zone
        if bot.wander and bot.wander.targetPos then
            if memory:IsDangerZone(bot.wander.targetPos) then
                local chatter = bot:BotChatter()
                if chatter and math.random(1, 4) == 1 then
                    chatter:On("DangerZoneWarning", {}, false)
                end
            end
        end
        break  -- only one bot warns per sweep
    end
end)

-- ===========================================================================
-- Tier 6 — Personality & Immersion: Emotional Reaction Hooks
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- WitnessKill — bot witnesses a kill and panics
-- ---------------------------------------------------------------------------

hook.Add("TTTBots.WitnessKill", "TTTBots.Chatter.WitnessKill", function(witness, killer, victim)
    if not TTTBots.Lib.GetConVarBool("emotional_chatter") then return end
    if not (IsValid(witness) and witness:IsBot()) then return end
    local chatter = witness:BotChatter()
    if not chatter then return end

    chatter:On("WitnessKill", {
        killer    = IsValid(killer) and killer:Nick() or "someone",
        killerEnt = killer,
        victim    = IsValid(victim) and victim:Nick() or "someone",
        victimEnt = victim,
    }, false, 0.5)  -- slight delay so it doesn't overlap combat callout
end)

-- ---------------------------------------------------------------------------
-- BeingShotAt — bot is taking damage before FightBack activates
-- ---------------------------------------------------------------------------

hook.Add("EntityTakeDamage", "TTTBots.Chatter.BeingShotAt", function(target, dmginfo)
    if not TTTBots.Lib.GetConVarBool("emotional_chatter") then return end
    if not (IsValid(target) and target:IsPlayer() and target:IsBot()) then return end
    if not TTTBots.Lib.IsPlayerAlive(target) then return end

    -- Rate-limit: once every 8 seconds per bot (sufficient to prevent spam)
    if (CurTime() - (target.lastBeingShotAtChatter or 0)) < 8 then return end
    target.lastBeingShotAtChatter = CurTime()

    local attacker = dmginfo:GetAttacker()
    if not (IsValid(attacker) and attacker:IsPlayer()) then return end
    if attacker == target then return end

    local chatter = target:BotChatter()
    if not chatter then return end

    chatter:On("BeingShotAt", { player = attacker:Nick(), playerEnt = attacker }, false, 0)
end)

-- ---------------------------------------------------------------------------
-- FindFriendBody — bot finds the body of a trusted player
-- (fires from InvestigateCorpse behavior, supplemented here for human players)
-- ---------------------------------------------------------------------------

hook.Add("TTTBodyFound", "TTTBots.Chatter.FindFriendBody", function(discoverer, deceased, ragdoll)
    if not TTTBots.Lib.GetConVarBool("emotional_chatter") then return end
    if not (IsValid(discoverer) and discoverer:IsBot()) then return end
    local chatter = discoverer:BotChatter()
    if not chatter then return end

    -- Check if the deceased was trusted (in evidence companion list)
    local evidence = discoverer.BotEvidence and discoverer:BotEvidence()
    local wasTrusted = false
    if evidence then
        local companions = evidence.travelCompanions or {}
        for _, companion in ipairs(companions) do
            if companion == deceased then wasTrusted = true; break end
        end
        if not wasTrusted then
            -- Also check confirmed innocents list
            local ci = evidence.confirmedInnocents or {}
            for _, innocent in ipairs(ci) do
                if innocent == deceased then wasTrusted = true; break end
            end
        end
    end

    if wasTrusted and math.random(1, 2) == 1 then
        chatter:On("FindFriendBody", {
            victim    = IsValid(deceased) and deceased:Nick() or "someone",
            victimEnt = deceased,
        }, false, 0)
    end
end)

-- ---------------------------------------------------------------------------
-- RoundStart — bot comments at the very beginning of a round
-- ---------------------------------------------------------------------------

hook.Add("TTTBeginRound", "TTTBots.Chatter.RoundStart", function()
    if not TTTBots.Lib.GetConVarBool("emotional_chatter") then return end

    -- Use a short delay before sampling bots so the alive-state cache has time
    -- to reflect the new round (TTTBeginRound can fire before :Alive() returns true).
    timer.Simple(2, function()
        local bots = TTTBots.Lib.GetAliveBots()
        -- Fall back to all valid bots if the alive-cache is still empty.
        if #bots == 0 then
            for _, bot in ipairs(TTTBots.Bots) do
                if IsValid(bot) and bot.components then
                    table.insert(bots, bot)
                end
            end
        end
        if #bots == 0 then return end

        -- Pick 1-2 random bots to comment
        local speakers = math.random(1, math.min(2, #bots))
        for i = 1, speakers do
            local bot = bots[math.random(1, #bots)]
            if not (IsValid(bot) and bot.components) then continue end
            local chatter = bot:BotChatter()
            if chatter then
                -- Reset rate-limit for RoundStart so it always fires once per round.
                if chatter.rateLimitTbl then
                    chatter.rateLimitTbl["RoundStart"] = nil
                end
                timer.Simple(math.random(0, 3), function()
                    if not IsValid(bot) then return end
                    chatter:On("RoundStart", {}, false, 0)
                end)
            end
        end
    end)
end)

-- ---------------------------------------------------------------------------
-- OvertimeHaste — bot reacts when overtime/haste activates
-- ---------------------------------------------------------------------------

hook.Add("TTTHaste", "TTTBots.Chatter.OvertimeHaste", function()
    if not TTTBots.Lib.GetConVarBool("emotional_chatter") then return end
    local bots = TTTBots.Lib.GetAliveBots()
    if #bots == 0 then return end

    local bot = bots[math.random(1, #bots)]
    if not (IsValid(bot) and bot.components) then return end
    local chatter = bot:BotChatter()
    if chatter then
        chatter:On("OvertimeHaste", {}, false, 0)
    end
end)

-- Also check via RoundAwareness timer in case TTTHaste doesn't fire
timer.Create("TTTBots.Chatter.OvertimeCheck", 5, 0, function()
    if not TTTBots.Lib.GetConVarBool("emotional_chatter") then return end
    if not TTTBots.Match.RoundActive then return end

    local bots = TTTBots.Lib.GetAliveBots()
    if #bots == 0 then return end

    local bot = bots[math.random(1, #bots)]
    if not (IsValid(bot) and bot.components) then return end
    local ra = bot:BotRoundAwareness()
    if not ra then return end
    local PHASE = TTTBots.Components.RoundAwareness.PHASE
    if ra:GetPhase() ~= PHASE.OVERTIME then return end

    -- Only fire once per overtime entry (track with flag)
    if bot._overtimeChatFired then return end
    bot._overtimeChatFired = true

    local chatter = bot:BotChatter()
    if chatter then chatter:On("OvertimeHaste", {}, false, 0) end
end)

hook.Add("TTTBeginRound", "TTTBots.Chatter.ResetOvertimeFlag", function()
    for _, bot in ipairs(TTTBots.Bots) do
        if IsValid(bot) then bot._overtimeChatFired = nil end
    end
end)

-- ---------------------------------------------------------------------------
-- LastInnocent — bot realizes they are the last innocent alive
-- ---------------------------------------------------------------------------

timer.Create("TTTBots.Chatter.LastInnocent", 3, 0, function()
    if not TTTBots.Lib.GetConVarBool("emotional_chatter") then return end
    if not TTTBots.Match.RoundActive then return end

    local alivePlayers = TTTBots.Match.AlivePlayers or {}
    -- Need exactly 2 alive players to be the "last innocent" scenario
    if #alivePlayers ~= 2 then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and TTTBots.Lib.IsPlayerAlive(bot)) then continue end
        local role = TTTBots.Roles.GetRoleFor(bot)
        if not (role and role:GetUsesSuspicion()) then continue end  -- must be innocent-side

        -- Don't fire more than once
        if bot._lastInnocentFired then continue end
        bot._lastInnocentFired = true

        -- Identify the other alive player as suspect
        local suspect = nil
        for _, ply in ipairs(alivePlayers) do
            if ply ~= bot then suspect = ply; break end
        end
        if not IsValid(suspect) then continue end

        local chatter = bot:BotChatter()
        if chatter then
            chatter:On("LastInnocent", {
                suspect    = suspect:Nick(),
                suspectEnt = suspect,
            }, false, 0)
        end
        break  -- only one bot fires this per sweep
    end
end)

hook.Add("TTTBeginRound", "TTTBots.Chatter.ResetLastInnocentFlag", function()
    for _, bot in ipairs(TTTBots.Bots) do
        if IsValid(bot) then bot._lastInnocentFired = nil end
    end
end)

-- ---------------------------------------------------------------------------
-- QuietRoundComment — nobody has died in a while
-- ---------------------------------------------------------------------------

local QUIET_ROUND_THRESHOLD = 120  -- seconds with no death before "quiet" triggers
local _lastDeathTime = 0

hook.Add("PlayerDeath", "TTTBots.Chatter.QuietRoundTracker", function(victim)
    if TTTBots.Match.RoundActive then
        _lastDeathTime = CurTime()
    end
end)
hook.Add("TTTBeginRound", "TTTBots.Chatter.ResetQuietTimer", function()
    _lastDeathTime = CurTime()
end)

timer.Create("TTTBots.Chatter.QuietRound", 45, 0, function()
    if not TTTBots.Match.RoundActive then return end
    if (CurTime() - _lastDeathTime) < QUIET_ROUND_THRESHOLD then return end

    local bots = lib.GetAliveBots()
    if #bots == 0 then return end

    local speaker = bots[math.random(1, #bots)]
    if not (speaker and IsValid(speaker) and speaker.components) then return end

    -- Only fire once per quiet stretch
    if speaker._quietCommentFired and
       (CurTime() - (speaker._quietCommentFiredTime or 0)) < 90 then return end
    speaker._quietCommentFired = true
    speaker._quietCommentFiredTime = CurTime()

    local chatter = speaker:BotChatter()
    if chatter then
        chatter:On("QuietRoundComment", {}, false, 0)
    end
end)

hook.Add("TTTBeginRound", "TTTBots.Chatter.ResetQuietComment", function()
    for _, bot in ipairs(TTTBots.Bots) do
        if IsValid(bot) then
            bot._quietCommentFired = nil
            bot._quietCommentFiredTime = nil
        end
    end
end)

-- ---------------------------------------------------------------------------
-- PostCombatRelief — bot survived a fight (fires after AttackEnd)
-- ---------------------------------------------------------------------------

hook.Add("TTTBots.AttackEnd", "TTTBots.Chatter.PostCombatRelief", function(attacker, victim)
    if not TTTBots.Lib.GetConVarBool("emotional_chatter") then return end
    if not (IsValid(attacker) and attacker:IsBot()) then return end
    if not TTTBots.Lib.IsPlayerAlive(attacker) then return end

    -- Rate-limit: don't fire more than once per 20s per bot
    if (CurTime() - (attacker._lastPostCombatChat or 0)) < 20 then return end
    attacker._lastPostCombatChat = CurTime()

    local chatter = attacker:BotChatter()
    if not chatter then return end

    -- 50% chance to make a post-combat remark
    if math.random(1, 2) == 1 then
        chatter:On("PostCombatRelief", {}, false, math.random(1, 3))
    end
end)

-- ---------------------------------------------------------------------------
-- NearMissReaction — bot narrowly avoids being shot (EntityTakeDamage with 0)
-- Note: we detect "near miss" via the EntityTakeDamage hook when the dmg is
-- very low (graze) or via a proximity bullet hook if available.
-- ---------------------------------------------------------------------------

hook.Add("EntityTakeDamage", "TTTBots.Chatter.NearMiss", function(target, dmginfo)
    if not TTTBots.Lib.GetConVarBool("emotional_chatter") then return end
    if not (IsValid(target) and target:IsPlayer() and target:IsBot()) then return end
    if not TTTBots.Lib.IsPlayerAlive(target) then return end

    -- Only react to very low damage (graze/near miss), not full hits
    local dmg = dmginfo:GetDamage()
    if dmg == 0 or dmg > 5 then return end  -- graze only

    -- Rate-limit: once per 15s
    if (CurTime() - (target._lastNearMissChat or 0)) < 15 then return end
    target._lastNearMissChat = CurTime()

    local attacker = dmginfo:GetAttacker()
    if not (IsValid(attacker) and attacker:IsPlayer()) then return end
    if attacker == target then return end

    local chatter = target:BotChatter()
    if not chatter then return end

    chatter:On("NearMissReaction", { player = attacker:Nick(), playerEnt = attacker }, false, 0)
end)

-- ---------------------------------------------------------------------------
-- SurvivorRelief — bot survived when all nearby allies died in quick succession
-- ---------------------------------------------------------------------------

hook.Add("PlayerDeath", "TTTBots.Chatter.SurvivorCheck", function(victim, weapon, attacker)
    if not TTTBots.Lib.GetConVarBool("emotional_chatter") then return end
    if not TTTBots.Match.RoundActive then return end

    -- After a death, check if any nearby surviving bots should comment
    timer.Simple(1.5, function()
        local bots = lib.GetAliveBots()
        if #bots == 0 then return end

        for _, bot in ipairs(bots) do
            if not (IsValid(bot) and bot.components) then continue end
            -- Must have been near the victim
            if not IsValid(victim) then continue end
            local dist = bot:GetPos():Distance(victim:GetPos())
            if dist > 600 then continue end  -- only nearby survivors

            -- Rate-limit
            if (CurTime() - (bot._lastSurvivorChat or 0)) < 30 then continue end
            bot._lastSurvivorChat = CurTime()

            if math.random(1, 4) == 1 then  -- 25% chance
                local chatter = bot:BotChatter()
                if chatter then
                    chatter:On("SurvivorRelief", {
                        victim    = IsValid(victim) and victim:Nick() or "someone",
                        victimEnt = victim,
                    }, false, math.random(1, 3))
                end
            end
            break  -- only one bot per death
        end
    end)
end)

-- ---------------------------------------------------------------------------
-- Boredom-driven casual chatter — periodic single-bot casual remarks
-- scaled by each bot's boredom stat
-- ---------------------------------------------------------------------------

local boredCasualPool = {
    "CasualBoredom", "CasualObservation", "CasualQuestion",
    "CasualNervous", "CasualComplaint", "CasualWeather",
}

timer.Create("TTTBots.Chatter.BoredomCasual", 25, 0, function()
    if not TTTBots.Match.RoundActive then return end
    local bots = lib.GetAliveBots()
    if #bots == 0 then return end

    for _, bot in ipairs(bots) do
        if not (IsValid(bot) and bot.components) then continue end
        local personality = bot:BotPersonality()
        if not personality then continue end

        local boredom = personality:GetBoredom() or 0
        if boredom < 0.25 then continue end  -- not bored enough

        local moodMult = personality.GetChatMoodMultiplier
            and personality:GetChatMoodMultiplier() or 1.0
        if moodMult <= 0.05 then continue end

        -- Scale chance: 10% at min boredom → 50% at max boredom
        local chance = 0.10 + (boredom * 0.40)
        chance = chance * moodMult
        if math.random() > chance then continue end

        -- Pick a casual event — weight toward CasualBoredom at high boredom
        local eventName
        if boredom > 0.7 and math.random(1, 2) == 1 then
            eventName = "CasualBoredom"
        else
            eventName = boredCasualPool[math.random(1, #boredCasualPool)]
        end

        local chatter = bot:BotChatter()
        if chatter then
            chatter:On(eventName, {}, false, math.random(0, 4))
        end
        break  -- one bot per sweep
    end
end)

hook.Add("TTTEndRound", "TTTBots.Chatter.TraitorVictory", function(result)
    if not TTTBots.Lib.GetConVarBool("emotional_chatter") then return end
    if result ~= TEAM_TRAITOR then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot.components) then continue end
        local role = TTTBots.Roles.GetRoleFor(bot)
        if not (role and role:GetTeam() == TEAM_TRAITOR) then continue end

        local chatter = bot:BotChatter()
        if chatter and math.random(1, 3) == 1 then
            timer.Simple(math.random(1, 3), function()
                if not IsValid(bot) then return end
                chatter:On("TraitorVictory", {}, true, 0)  -- team-only
            end)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- PostRoundBanter — bots react at the end of every round
-- ---------------------------------------------------------------------------

hook.Add("TTTEndRound", "TTTBots.Chatter.PostRoundBanter", function(result)
    if not TTTBots.Lib.GetConVarBool("emotional_chatter") then return end
    if not TTTBots.Lib.GetConVarBool("chatter_dialogue") then return end

    local allBots = TTTBots.Bots
    if not allBots or #allBots == 0 then return end

    -- Determine winning and losing teams from the round result
    local winTeam = result  -- e.g. TEAM_INNOCENT, TEAM_TRAITOR

    -- Collect winner and loser bots
    local winners = {}
    local losers  = {}
    for _, bot in ipairs(allBots) do
        if not IsValid(bot) then continue end
        local role = TTTBots.Roles.GetRoleFor(bot)
        if not role then continue end
        if role:GetTeam() == winTeam then
            table.insert(winners, bot)
        else
            table.insert(losers, bot)
        end
    end

    if #winners == 0 and #losers == 0 then return end

    -- Pick one winner and one loser (or just random bots if teams unbalanced)
    local winner = #winners > 0 and winners[math.random(1, #winners)] or nil
    local loser  = #losers  > 0 and losers[math.random(1, #losers)]   or nil

    -- Fire a 2-line winner→loser post-round dialog with a short delay
    timer.Simple(math.random(3, 7), function()
        if winner and IsValid(winner) and winner.components then
            local wChatter = winner:BotChatter()
            if wChatter then
                if wChatter.rateLimitTbl then
                    wChatter.rateLimitTbl["DialogPostRoundWinner"] = nil
                end
                wChatter:On("DialogPostRoundWinner", {
                    nextBot = loser and IsValid(loser) and loser:Nick() or "",
                }, false, 0)
            end
        end

        timer.Simple(4, function()
            if loser and IsValid(loser) and loser.components then
                local lChatter = loser:BotChatter()
                if lChatter then
                    if lChatter.rateLimitTbl then
                        lChatter.rateLimitTbl["DialogPostRoundLoser"] = nil
                    end
                    lChatter:On("DialogPostRoundLoser", {
                        lastBot = winner and IsValid(winner) and winner:Nick() or "",
                    }, false, 0)
                end
            end

            timer.Simple(4, function()
                if winner and IsValid(winner) and winner.components then
                    local wChatter = winner:BotChatter()
                    if wChatter then
                        if wChatter.rateLimitTbl then
                            wChatter.rateLimitTbl["DialogPostRoundExplain"] = nil
                        end
                        wChatter:On("DialogPostRoundExplain", {}, false, 0)
                    end
                end
            end)
        end)
    end)
end)
