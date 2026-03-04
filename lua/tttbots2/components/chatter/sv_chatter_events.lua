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

    if math.random() < chatGPTChance then
        TTTBots.Providers.SendText(prompt, self.bot, { teamOnly = teamOnly, wasVoice = false }, function(envelope)
            setLocalizedString(envelope.ok and envelope.text or nil)
        end)
    else
        localizedString = TTTBots.Locale.GetLocalizedLine(event_name, self.bot, args)
        if not localizedString then
            TTTBots.Providers.SendText(prompt, self.bot, { teamOnly = teamOnly, wasVoice = false }, function(envelope)
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
