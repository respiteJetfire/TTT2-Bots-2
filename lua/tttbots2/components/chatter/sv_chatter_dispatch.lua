--- sv_chatter_dispatch.lua
--- TTS/text routing logic: decides whether a bot speaks via voice (TTS) or typed
--- chat, manages the global speakingBot mutex, and contains the PlayerSay hook
--- that triggers LLM-based replies to human messages.
--- Depends on: sv_chatter_parser.lua, sv_chatter_commands.lua

local lib = TTTBots.Lib
local BotChatter = TTTBots.Components.Chatter

--- Tracks when each bot last spoke via voice (used for rate-limit book-keeping).
speakingPlayers = speakingPlayers or {}

-- ---------------------------------------------------------------------------
-- BotChatter:textorTTS
-- ---------------------------------------------------------------------------

--- Route a generated text string to either TTS voice output or typed chat.
---@param bot Player       the bot that will speak
---@param text string      the message to deliver
---@param teamOnly boolean whether to use team-only chat/voice
---@param event_name string|false  the source event (used for KOS radio calls)
---@param args table|nil   event args (used for KOS radio calls)
---@param wasVoice boolean whether this reply was prompted by voice STT input
function BotChatter:textorTTS(bot, text, teamOnly, event_name, args, wasVoice)
    if not (bot and text) then return end

    teamOnly  = teamOnly  or false
    wasVoice  = wasVoice  or false

    if not bot:Alive()   then return end
    if bot:IsSpec()      then return end

    local voiceChatChance = (TTTBots.Lib.GetConVarFloat("chatter_voice_chance") or 50) / 100

    if math.random() <= voiceChatChance then
        print("SpeakingBot: ", TTTBots.Match.speakingBot)

        -- Another bot is already talking → fall back to text
        if TTTBots.Match.speakingBot and TTTBots.Match.speakingBot ~= bot then
            print("Sending Text chat: " .. text)
            self:Say(text, teamOnly, false, function()
                if event_name == "CallKOS" and args then
                    self:QuickRadio("quick_traitor", args.playerEnt)
                end
            end)
            self:RespondToPlayerMessage(bot, text, teamOnly, math.random(2, 4))
            return
        end

        TTTBots.Match.speakingBot = bot

        -- Rate limiting
        bot.lastReplyTime = bot.lastReplyTime or 0
        local rateLimitTime = wasVoice and 4 or 2
        if CurTime() - bot.lastReplyTime < rateLimitTime then
            print("Bot rate limited: ", bot)
            return nil
        end
        bot.lastReplyTime = CurTime()

        local function onVoiceComplete(duration)
            duration = math.min(duration or 5, 10)
            TTTBots.Match.speakingBot = nil
            timer.Simple(duration + 1, function()
                TTTBots.Match.speakingBot = nil
                self:RespondToPlayerMessage(bot, text, teamOnly, false, true)
            end)
        end

        text = string.gsub(text, "\\", "")
        text = string.gsub(text, "/", "")

        -- Inform alive bots of this message
        for _, aliveBot in ipairs(TTTBots.Lib.GetAliveBots()) do
            aliveBot:BotMemory():UpdateMessages(text, bot)
        end

        TTTBots.Providers.SendVoice(bot, text, { teamOnly = teamOnly }, function(envelope)
            onVoiceComplete(envelope.ok and envelope.text or 1)
        end)

        speakingPlayers[bot] = CurTime()
        print(bot:Nick() .. " [VOICE CHAT]: " .. text)

    else
        -- Text chat path
        self:Say(text, teamOnly, false, function()
            if event_name == "CallKOS" and args then
                self:QuickRadio("quick_traitor", args.playerEnt)
            end
        end)
        self:RespondToPlayerMessage(bot, text, teamOnly, math.random(2, 4))
    end
end

-- ---------------------------------------------------------------------------
-- PlayerSay hook — trigger LLM replies to human chat messages
-- ---------------------------------------------------------------------------

hook.Add("PlayerSay", "TTTBots.ChatGPT.GetResponse", function(ply, text, team)
    BotChatter:RespondToPlayerMessage(ply, text, team, 2)
end)
