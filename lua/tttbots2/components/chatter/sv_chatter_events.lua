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
}

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
    local chatGPTChance= lib.GetConVarFloat("chatter_gpt_chance")   or 0.25

    -- Dynamic CallKOS probability
    local dynamicChances = table.Copy(chancesOf100)
    dynamicChances.CallKOS = 15 * difficulty

    local personality = self.bot.components.personality ---@type CPersonality
    if dynamicChances[event_name] then
        local chance = dynamicChances[event_name]
        if math.random(0, 100) > (chance * personality:GetTraitMult("textchat") * ChanceMult) then
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
        local isCasual  = personality:GetClosestArchetype() == TTTBots.Archetypes.Casual
        if localizedString then
            if isCasual then localizedString = string.lower(localizedString) end
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
            setLocalizedString(envelope.ok and envelope.text or nil)
        end)
    else
        localizedString = TTTBots.Locale.GetLocalizedLine(event_name, self.bot, args)
        if not localizedString then
            TTTBots.Providers.SendText(prompt, self.bot, sendOpts, function(envelope)
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
