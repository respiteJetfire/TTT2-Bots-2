---@class CChatter : Component
TTTBots.Components.Chatter = TTTBots.Components.Chatter or {}

local lib = TTTBots.Lib
---@class CChatter : Component
local BotChatter = TTTBots.Components.Chatter

function BotChatter:New(bot)
    local newChatter = {}
    setmetatable(newChatter, {
        __index = function(t, k) return BotChatter[k] end,
    })
    newChatter:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        print("Initialized Chatter for bot " .. bot:Nick())
    end

    return newChatter
end

speakingPlayers = {}



function BotChatter:Initialize(bot)
    -- print("Initializing")
    bot.components = bot.components or {}
    bot.components.Chatter = self

    self.componentID = string.format("Chatter (%s)", lib.GenerateID()) -- Component ID, used for debugging

    self.tick = 0                                                      -- Tick counter
    self.bot = bot
    self.rateLimitTbl = {}
end

--- Check the rate limit table for if we can say the line. If so, then return true and update the rate limit tbl.
---@param event string
---@return boolean
function BotChatter:CanSayEvent(event)
    local rateLimitTime = lib.GetConVarFloat("chatter_minrepeat")
    local lastSpeak = self.rateLimitTbl[event] or -math.huge

    if lastSpeak + rateLimitTime < CurTime() then
        self.rateLimitTbl[event] = CurTime()
        return true
    end

    return false
end

function BotChatter:SayRaw(text, teamOnly)
    if not IsValid(self.bot) then return end
    self.bot:Say(text, teamOnly)
end

local keyboardLayout = {
    ['q'] = { 'w', 'a' },
    ['w'] = { 'q', 'e', 's', 'a' },
    ['e'] = { 'w', 'r', 'd', 's' },
    ['r'] = { 'e', 't', 'f', 'd' },
    ['t'] = { 'r', 'y', 'g', 'f' },
    ['y'] = { 't', 'u', 'h', 'g' },
    ['u'] = { 'y', 'i', 'j', 'h' },
    ['i'] = { 'u', 'o', 'k', 'j' },
    ['o'] = { 'i', 'p', 'l', 'k' },
    ['p'] = { 'o', 'l' },
    ['a'] = { 'q', 'w', 's', 'z' },
    ['s'] = { 'w', 'e', 'd', 'a', 'z', 'x' },
    ['d'] = { 'e', 'r', 'f', 's', 'x', 'c' },
    ['f'] = { 'r', 't', 'g', 'd', 'c', 'v' },
    ['g'] = { 't', 'y', 'h', 'f', 'v', 'b' },
    ['h'] = { 'y', 'u', 'j', 'g', 'b', 'n' },
    ['j'] = { 'u', 'i', 'k', 'h', 'n', 'm' },
    ['k'] = { 'i', 'o', 'l', 'j', 'm' },
    ['l'] = { 'o', 'p', 'k' },
    ['z'] = { 'a', 's', 'x' },
    ['x'] = { 'z', 's', 'd', 'c' },
    ['c'] = { 'x', 'd', 'f', 'v' },
    ['v'] = { 'c', 'f', 'g', 'b' },
    ['b'] = { 'v', 'g', 'h', 'n' },
    ['n'] = { 'b', 'h', 'j', 'm' },
    ['m'] = { 'n', 'j', 'k' },
}

local missKey = function(last, this, next)
    local typoOptions = keyboardLayout[this]
    if typoOptions then
        return typoOptions[math.random(#typoOptions)]
    else
        return this
    end
end

--- Intentionally inject typos into the text based on the chatter_typo_chance convars
---@param text string
---@return string result
function BotChatter:TypoText(text)
    local chance = lib.GetConVarFloat("chatter_typo_chance")

    local typoFuncs = {
        removeCharacter = function(last, this, next) return "" end,
        duplicateCharacter = function(last, this, next) return this .. this end,
        capitalizeCharacter = function(last, this, next) return string.upper(this) end,
        lowercaseCharacter = function(last, this, next) return string.lower(this) end,
        switchWithNext = function(last, this, next) return next .. this end,
        insertRandomCharacter = function(last, this, next) return this .. string.char(math.random(97, 122)) end,
        missKey = missKey
    }

    ---@type table<WeightedTable>
    local typoFuncsWeighted = {
        TTTBots.Lib.SetWeight(typoFuncs.removeCharacter, 20),
        TTTBots.Lib.SetWeight(typoFuncs.duplicateCharacter, 7),
        TTTBots.Lib.SetWeight(typoFuncs.capitalizeCharacter, 4),
        TTTBots.Lib.SetWeight(typoFuncs.lowercaseCharacter, 7),
        TTTBots.Lib.SetWeight(typoFuncs.switchWithNext, 12),
        TTTBots.Lib.SetWeight(typoFuncs.insertRandomCharacter, 14),
        TTTBots.Lib.SetWeight(typoFuncs.missKey, 30)
    }

    local result = ""
    local textLength = string.len(text)
    for i = 1, textLength do
        local char = string.sub(text, i, i)
        local last = i > 1 and string.sub(text, i - 1, i - 1) or ""
        local next = i < textLength and string.sub(text, i + 1, i + 1) or ""

        if math.random(0, 100) < chance then
            local typoFunc = lib.RandomWeighted(typoFuncsWeighted)
            char = typoFunc(last, char, next)
        end

        result = result .. char
    end

    return result
end

--- Order the bot to say a string of text in chat. This function is rate limited and types messages out at a somewhat random speed.
---@param text string The raw string of text to put in chat.
---@param teamOnly boolean|nil (OPTIONAL, =FALSE) Should the bot place the message in the team chat?
---@param ignoreDeath boolean|nil (OPTIONAL, =FALSE) Should the bot say the text despite being dead?
---@param callback nil|function (OPTIONAL) A callback function to call when the bot is done speaking.
---@return boolean chatting Returns true if we just ordered the bot to speak, otherwise returns false.
function BotChatter:Say(text, teamOnly, ignoreDeath, callback)
    if self.typing then return false end
    local cps = lib.GetConVarFloat("chatter_cps")
    local delay = (string.len(text) / cps) * (math.random(75, 150) / 100)
    self.typing = true
    -- remove "[BOT] " and "[bot] " occurences from the text
    text = string.gsub(text, "%[BOT%] ", "")
    text = string.gsub(text, "%[bot%] ", "")
    --- remove any '' or "" from the text
    text = string.gsub(text, "'", "")
    text = string.gsub(text, '"', "")
    text = self:TypoText(text)
    timer.Simple(delay, function()
        if self.bot == NULL or not IsValid(self.bot) then return end
        if ignoreDeath or lib.IsPlayerAlive(self.bot) then
            self:SayRaw(text, teamOnly)
            self.typing = false
            if callback then callback() end
        end
    end)
    return true
end

local RADIO = {
    quick_traitor = "%s is a Traitor!",
    quick_suspect = "%s acts suspicious."
}
function BotChatter:QuickRadio(msgName, msgTarget)
    local txt = RADIO[msgName]
    if not txt then ErrorNoHaltWithStack("Unknown message type " .. msgName) end
    hook.Run("TTTPlayerRadioCommand", self.bot, msgName, msgTarget)
end

--- A generic wrapper for when an event happens, to be implemented further in the future
---@param event_name string
---@param args table<any>? A table of arguments passed to the event
---@param teamOnly boolean? Should the message be team only
---@param delay number? Optional delay before executing the event
function BotChatter:On(event_name, args, teamOnly, delay)
    local dvlpr = lib.GetConVarBool("debug_misc")
    if dvlpr then
        print(string.format("Event %s called with %d args.", event_name, args and #args))
    end

    if not self:CanSayEvent(event_name) then return false end

    if event_name == "CallKOS" then
        local target = args and args.playerEnt
        if target and IsValid(target) then
            if (target.lastKOSTime or 0) + 5 > CurTime() then return false end
            target.lastKOSTime = CurTime()
        end
    end

    --- if statement to handle this chatter:On("Kill", { victim = victim:Nick(), victimEnt = victim, attacker = attacker:Nick(), attackerEnt = attacker })
    if event_name == "Kill" then
        local victim = args and args.victim
        local attacker = args and args.attacker
        if not victim or not attacker then return false end
        local victimEnt = args.victimEnt
        local attackerEnt = args.attackerEnt
        if not victimEnt or not attackerEnt then return false end
    end

    local difficulty = lib.GetConVarInt("difficulty")
    local ChanceMult = lib.GetConVarFloat("chatter_chance_multi") or 1
    local chatGPTChance = lib.GetConVarFloat("chatter_gpt_chance") or 0.25

    --- Base chances to react to the events via chat
    local chancesOf100 = {
        InvestigateNoise = 15,
        InvestigateCorpse = 15,
        DeclareInnocent = 25,
        DeclareSuspicious = 20,
        DeclareTrustworthy = 15,
        WaitStart = 40,
        WaitEnd = 40,
        WaitRefuse = 40,
        FollowMe = 40,
        FollowMeRefuse = 40,
        FollowMeEnd = 40,
        LifeCheck = 65,
        Kill = 25,
        CallKOS = 15 * difficulty,
        FollowStarted = 10,
        ServerConnected = 45,
        SillyChat = 30,
        SillyChatDead = 15,
        AttackStart = 80,
        AttackRefuse = 80,
        CreatingCursed = 80,
        CreatingDefector = 80,
        CreatingMedic = 80,
        CreatingDoctor = 80,
        CreatingSidekick = 80,
        CreatingDeputy = 80,
        CreatingSlave = 60,
        CeaseFireStart = 60,
        CeaseFireRefuse = 60,
        CeaseFireEnd = 60,
        HealAccepted = 80,
        HealRefused = 50,
        RoleCheckerRequestAccepted = 90,
        UsingRoleChecker = 50,
        ComeHereStart = 75,
        ComeHereRefuse = 50,
        ComeHereEnd = 50,
        InvestigateCorpse = 65,
        JihadBombWarn = 75,
        JihadBombUse = 100,
        PlacedAnkh = 75,
        NewContract = 75,
        ContractAccepted = 75,
        FollowMe = 20,
    }

    local personality = self.bot.components.personality --- @type CPersonality
    if chancesOf100[event_name] then
        local chance = chancesOf100[event_name]
        if math.random(0, 100) > (chance * personality:GetTraitMult("textchat") * ChanceMult) then return false end
    end
    local localizedString = nil
    local function handleChatResponse(response)
        if response then
            localizedString = TTTBots.Locale.FormatArgsIntoTxt(response, args)
            print("ChatGPT response: ", localizedString)
        else
            localizedString = TTTBots.Locale.GetLocalizedLine(event_name, self.bot, args)
            print("ChatGPT failed, using default response: ", localizedString)
            if not localizedString then
                localizedString = "I don't know what to say."
            end
        end
        -- Process the localizedString as needed
    end
    
    if math.random() < chatGPTChance then
        TTTBots.ChatGPT.SendRequest(TTTBots.Locale.GetChatGPTPrompt(event_name, self.bot, args, teamOnly, true), self.bot, teamOnly, false, function(response)
            handleChatResponse(response)
        end)
    else
        localizedString = TTTBots.Locale.GetLocalizedLine(event_name, self.bot, args)
        if not localizedString then
            TTTBots.ChatGPT.SendRequest(TTTBots.Locale.GetChatGPTPrompt(event_name, self.bot, args, teamOnly, true), self.bot, teamOnly, false, function(response)
                handleChatResponse(response)
            end)
        end
    end
    
    local isCasual = personality:GetClosestArchetype() == TTTBots.Archetypes.Casual
    if localizedString then
        if isCasual then localizedString = string.lower(localizedString) end
        -- print("TeamOnly: ", teamOnly)
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

function BotChatter:textorTTS(bot, text, teamOnly, event_name, args, wasVoice)
    --- function that takes the text and player as inputs, decides if the bot will say it via text or TTS.
    if bot and text then
        teamOnly = teamOnly or false

        wasVoice = wasVoice or false

        -- print("Bot " .. bot:Nick() .. " says: " .. text)
        local voiceChatChance = (TTTBots.Lib.GetConVarFloat("chatter_voice_chance") or 50) / 100

        --- if the bot is dead then we should return
        if not bot:Alive() then return end
        --- if the bot is spectating then we should return
        if bot:IsSpec() then return end

        local personality = bot:BotPersonality()
        local voicetype = personality.voice.type

        -- Rate limiting
        bot.lastReplyTime = bot.lastReplyTime or 0
        local rateLimitTime
        if wasVoice then
            rateLimitTime = 4
        else
            rateLimitTime = 2
        end
        if CurTime() - bot.lastReplyTime < rateLimitTime then
            print("Bot rate limited: ", bot)
            return nil
        end
        bot.lastReplyTime = CurTime()

        if not (speakingPlayers[bot] and (CurTime() - speakingPlayers[bot] < 5)) and math.random() <= voiceChatChance then
            -- print("Sending Voice chat: " .. text)
                if voicetype == "elevenlabs" then
                    -- print("Sending Voice chat to ElevenLabs")
                    TTTBots.TTS.ElevenLabsSendRequest(bot, text, teamOnly)
                elseif voicetype == "Azure" then
                    -- print("Sending Voice chat to Azure")
                    TTTBots.TTS.AzureTTSSendRequest(bot, text, teamOnly)
                else
                    -- print("Sending Voice chat to FreeTTS")
                    TTTBots.TTS.FreeTTSSendRequest(bot, text, teamOnly)
                end 
                speakingPlayers[bot] = CurTime()
                self:RespondToPlayerMessage(bot, text, teamOnly, math.random(3, 6))
        else
            -- print("Sending Text chat: " .. text)
            self:Say(text, teamOnly, false, function()
                if event_name == "CallKOS" and args then
                    self:QuickRadio("quick_traitor", args.playerEnt)
                end
            end)
        end
    end
end

function BotChatter:Think()
end

-- hook for GM:PlayerCanSeePlayersChat(text, taemOnly, listener, sender)
hook.Add("PlayerCanSeePlayersChat", "TTTBots_PlayerCanSeePlayersChat", function(text, teamOnly, listener, sender)
    if not (IsValid(sender) and sender:IsBot() and teamOnly) then
        return
    end

    if not lib.IsPlayerAlive(sender) then
        return false
    end

    if listener:IsInTeam(sender) then
        return true
    end

    return false
end)


-- Define a hash table to hold our keywords and their corresponding events
local keywordEvents = {
    ["life check"] = "LifeCheck",
    ["who is alive"] = "LifeCheck",
    -- ["kos"] = "KOSCallout",
}

local keywordEventsCustom = {
    ["follow me"] = "FollowRequest",
    ["stand still"] = "StandStill",
    ["wait"] = "StandStill",
    ["kos"] = "CallKOS",
    ["kill"] = "CallKOS"
}

-- Helper function to handle the chat events
local function handleEvent(eventName)
    for i, v in pairs(TTTBots.Bots) do
        ---@cast v Bot
        local chatter = v:BotChatter()
        if not chatter then continue end
        chatter:On(eventName, {}, false)
    end
end

hook.Add("PlayerSay", "TTTBots.Chatter.PromptResponse", function(sender, text, teamChat)
    local text2 = string.lower(text) -- Convert text to lowercase for case-insensitive comparison

    for keyword, event in pairs(keywordEvents) do
        if string.find(text2, keyword) then
            handleEvent(event) -- Pass the full chat message to handleEvent
        end
    end
end)

-- Function to calculate the Levenshtein distance between two strings
local function levenshtein(str1, str2)
    local len1, len2 = #str1, #str2
    local matrix = {}

    -- Initialize the matrix
    for i = 0, len1 do
        matrix[i] = { [0] = i }
    end
    for j = 0, len2 do
        matrix[0][j] = j
    end

    -- Compute the Levenshtein distance
    for i = 1, len1 do
        for j = 1, len2 do
            local cost = (str1:sub(i, i) == str2:sub(j, j)) and 0 or 1
            matrix[i][j] = math.min(
                matrix[i - 1][j] + 1,      -- Deletion
                matrix[i][j - 1] + 1,      -- Insertion
                matrix[i - 1][j - 1] + cost -- Substitution
            )
        end
    end

    return matrix[len1][len2]
end

-- Function to check if the bot's name or a similar string is in the message
local function isNameInMessage(bot, message)
    local botName = bot:Nick():lower():gsub("%W", "") -- Remove non-alphanumeric characters
    local words = {}
    for word in message:gmatch("%w+") do
        table.insert(words, word:lower())
    end

    local messageString = table.concat(words, "") -- Concatenate words to form a single string

    if string.find(messageString, botName) or string.find(botName, messageString) then
        return true
    end

    for _, word in ipairs(words) do
        -- Check for 60% similarity using Levenshtein distance
        local maxLen = math.max(#botName, #word)
        local distance = levenshtein(botName, word)
        local similarity = (maxLen - distance) / maxLen
        if similarity >= 0.6 then
            return true
        end
    end

    return false
end

local function findBestBot(ply, bots, fulltxt, wasVoice, teamOnly)
    -- print("Finding best bot", ply, bots, fulltxt)
    local bestDist = math.huge
    local bot = nil

    local chatterMult = TTTBots.Lib.GetConVarFloat("chatter_reply_chance_multi")
    local forceReply = TTTBots.Lib.GetConVarBool("chatter_voice_force_reply_player")

    local chance
    for _, b in ipairs(bots) do
        if IsValid(b) then
            local dist = ply:GetPos():Distance(b:GetPos())
            --- Check if the bot's name or a similar string is in the message
            if isNameInMessage(b, fulltxt) and b ~= ply then
                -- print("Bot mentioned by name: ", b)
                chance = 100 --- If bot is mentioned by name it should always reply
                bot = b
                break
            elseif dist < bestDist and b ~= ply then
                chance = math.max(5, 60 - ((dist / 500) * 55)) -- Quicker drop off
                bestDist = dist
                bot = b
            elseif teamOnly and b ~= ply and not ply:IsBot() and b:GetTeam() == ply:GetTeam() then
                chance = 100
                bot = b
            end
        end
    end

    if bot and ((not ply:IsBot() and not wasVoice) or (not ply:IsBot() and forceReply)) then return bot end
    if not (chance and bot) then return end -- If no chance or bot is set, then return
    chance = chance * chatterMult
    -- print("Chance: ", chance)
    if math.random(1, 100) > chance then return nil end -- If the random number is greater than the chance, then return nil
    -- print("Best bot: ", bot)
    return bot
end

local function findPlayersInText(fulltxt)
    local foundPlayers = {}
    for _, player in ipairs(TTTBots.Lib.GetAlivePlayers()) do
        if isNameInMessage(player, fulltxt) then
            table.insert(foundPlayers, player)
            -- print("Found player: ", player)
            if #foundPlayers == 2 then
                break
            end
        end
    end
    return foundPlayers
end

local keywordEventsCallDefend = {
    ["defend"] = "CallDefend",
    ["hold the line"] = "CallDefend",
    ["protect this area"] = "CallDefend",
    ["guard this spot"] = "CallDefend",
    ["secure the area"] = "CallDefend",
    ["hold position"] = "CallDefend",
    ["defend here"] = "CallDefend",
    ["keep them out"] = "CallDefend",
    ["don't let them pass"] = "CallDefend",
    ["fortify this position"] = "CallDefend",
}

local keywordEventsCallCursed = {
    ["curse"] = "CallCursed",
}

local keywordEventsCallDefector = {
    ["defect"] = "CallDefector",
}

local keywordeventsCallHeal = {
    ["healer"] = "CallHeal",
    ["health"] = "CallHeal",
    ["heal me"] = "CallHeal",
}

local keywordeventsCallMedic = {
    ["medic"] = "CallMedic",
}

local keywordeventCeaseFire = {
    ["cease fire"] = "CallCeaseFire",
    ["stop shooting"] = "CallCeaseFire",
    ["don't shoot"] = "CallCeaseFire",
}


local keywordEventsKOS = {
    ["kos"] = "CallKOS",
    ["k.o.s"] = "CallKOS",
}

local keywordEventsCallWait = {
    ["wait"] = "CallWait",
    ["stay"] = "CallWait",
    ["freeze"] = "CallWait",
    ["stop right there"] = "CallWait",
    ["stop moving"] = "CallWait",
    ["halt"] = "CallWait",
    ["stand still"] = "CallWait",
}

local keywordEventFollowMe = {
    --- keywords to look for to trigger the FollowMe behavior
    ["follow me"] = "FollowMe",
    ["come with me"] = "FollowMe",
    ["don't leave me alone"] = "FollowMe",
    ["stick with me"] = "FollowMe",
    ["stay close"] = "FollowMe",
    ["let's go"] = "FollowMe",
    ["right behind me"] = "FollowMe",
    ["stay with me"] = "FollowMe",
    ["follow my lead"] = "FollowMe",
    ["let's move"] = "FollowMe",
    ["come along"] = "FollowMe",
    ["keep up"] = "FollowMe",
    ["don't fall behind"] = "FollowMe",
}

local keywordEventsCallAttack = {
    --- keywords to look for to trigger the attack request behavior
    ["attack"] = "CallAttack",
    ["kill"] = "CallAttack",
    ["shoot"] = "CallAttack",
    ["fire"] = "CallAttack",
    ["take out"] = "CallAttack",
    ["take care of"] = "CallAttack",
    ["eliminate"] = "CallAttack",
    ["destroy"] = "CallAttack",
    ["neutralize"] = "CallAttack",
    ["terminate"] = "CallAttack",
    ["wipe out"] = "CallAttack",
    ["exterminate"] = "CallAttack",
    ["annihilate"] = "CallAttack",
    ["obliterate"] = "CallAttack",
    ["eradicate"] = "CallAttack",
    ["dispatch"] = "CallAttack",
    ["eliminate"] = "CallAttack",
    ["take down"] = "CallAttack",
    ["dispose of"] = "CallAttack",
}

local keywordEventsRoleChecker = {
    ["role checker"] = "RequestUseRoleChecker",
    ["check role"] = "RequestUseRoleChecker",
    ["role check"] = "RequestUseRoleChecker",
    ["what is your role"] = "RequestUseRoleChecker",
}

local keywordEventComeHere = {
    --- keywords to look for to trigger the ComeHere behavior
    ["come here"] = "ComeHere",
    ["over here"] = "ComeHere",
    ["this way"] = "ComeHere",
    ["look at this"] = "ComeHere",
}

local keywordEventsCallBackup = {
    ["backup"] = "CallBackup",
    ["need backup"] = "CallBackup",
    ["assist me"] = "CallBackup",
    ["help me"] = "CallBackup",
    ["i need help"] = "CallBackup",
    ["support me"] = "CallBackup",
    ["i need support"] = "CallBackup",
    ["cover me"] = "CallBackup",
    ["i need cover"] = "CallBackup",
    ["reinforce me"] = "CallBackup",
}

local function handleKOS(ply, fulltxt)
    --- get a list of all players (minus the player who sent the message)
    local players = TTTBots.Lib.GetAlivePlayers()
    --- get the player who sent the message
    local sender = ply
    --- get the player who is the target of the KOS callout by calling isNameInMessage and returning the first alive player who's name is in the message
    for _, player in ipairs(players) do
        if isNameInMessage(player, fulltxt) and player ~= sender then
            print("KOS callout target: ", player)
            return TTTBots.Match.CallKOS(sender, player)
        end
    end
    return false
end

local function handleCeaseFire(ply, fulltxt)
    local CeaseFire = TTTBots.Behaviors.RequestCeaseFire
    -- print("Handling CeaseFire", ply, fulltxt)
    if ply and IsValid(ply) then
        CeaseFire.HandleRequest(ply, fulltxt)
    end
end

local function handleHeal(ply, fulltxt)
    local Heal = TTTBots.Behaviors.Healgun
    -- print("Handling Heal", ply, fulltxt)
    if ply and IsValid(ply) then
        Heal.HandleRequest(ply, fulltxt)
    end
end

local function handleFollowMe(bot, ply, teamOnly)
    local FollowMe = TTTBots.Behaviors.FollowMe
    -- print("Handling FollowMe", bot, ply)
    if bot and IsValid(bot) then
        FollowMe.InitiateFollow(bot, ply, teamOnly)
    end
end

local function handleComeHere(bot, ply, teamOnly)
    local ComeHere = TTTBots.Behaviors.ComeHere
    -- print("Handling ComeHere", bot, ply)
    if bot and IsValid(bot) then
        ComeHere.InitiateFollow(bot, ply, teamOnly)
    end
end

local function handleWait(bot, ply, teamOnly)
    local Wait = TTTBots.Behaviors.Wait
    -- print("Handling Wait", bot, ply)
    if bot and IsValid(bot) then
        Wait.RequestWait(bot, ply, teamOnly)
    end
end

local function handleRoleChecker(bot, ply, teamOnly)
    local RoleChecker = TTTBots.Behaviors.RequestUseRoleChecker
    -- print("Handling RoleChecker", bot, ply)
    if bot and IsValid(bot) then
        RoleChecker.HandleRequest(bot, ply, teamOnly)
    end
end

local function handleAttack(bot, ply, target)
    local Attack = TTTBots.Behaviors.RequestAttack
    -- print("Handling Attack", bot, ply, target)
    if bot and IsValid(bot) and target and IsValid(target) then
        Attack.RequestAttack(bot, ply, target, teamOnly)
    end
end

local function handleCursed(bot, ply, target, teamOnly)
    local Cursed = TTTBots.Behaviors.CreateCursed
    -- print("Handling Cursed", bot, target)
    if bot and IsValid(bot) then
        Cursed.HandleRequest(bot, target)
    end
end

local function handleDefector(bot, ply, target, teamOnly)
    local Defector = TTTBots.Behaviors.CreateDefector
    -- print("Handling Defector", bot, target)
    if bot and IsValid(bot) then
        Defector.HandleRequest(bot, target)
    end
end

local function handleMedic(bot, ply, target, teamOnly)
    local Medic = TTTBots.Behaviors.CreateMedic
    -- print("Handling Medic", bot, target)
    if bot and IsValid(bot) then
        Medic.HandleRequest(bot, target)
    end
end

local timeWindow = 60 -- Define the time window in seconds

local function checkTranscriptionsLocal()
    -- print("Checking transcriptions")
    local folderPath = "transcribed"
    local allFiles = file.Find(folderPath .. "/*", "DATA")
    local currentTime = os.time()

    local timeWindow = 60 -- Define the time window in seconds
    for _, fileName in ipairs(allFiles) do
        -- print("Checking file: ", fileName)
        local steamID, timestamp = fileName:match("user_(%d+)_(%d+).txt")
        if steamID and timestamp then
            -- print("SteamID: ", steamID)
            local fileTime = tonumber(timestamp)
            if currentTime - (fileTime) <= timeWindow then
                -- print("File is within time window")
                local textFilePath = folderPath .. "/user_" .. steamID .. "_" .. timestamp .. ".txt"
                if file.Exists(textFilePath, "DATA") then
                    -- print("File exists")
                    local text = file.Read(textFilePath, "DATA")
                    if text then
                        print("Transcription Detected, Text: ", text)
                        local ply = player.GetBySteamID64(steamID)
                        if IsValid(ply) then
                            --- sanitise the text
                            -- Function to sanitize text
                            local function sanitizeText(text)
                                -- Remove non-alphanumeric characters except spaces
                                text = string.gsub(text, "[^%w%s]", "")
                                -- Convert text to lowercase
                                text = string.lower(text)
                                -- Replace multiple spaces with a single space
                                text = string.gsub(text, "%s+", " ")
                                return text
                            end
                            -- Example usage
                            local sanitizedText = sanitizeText(text)
                            BotChatter:RespondToPlayerMessage(ply, sanitizedText, false, false, true)
                            print("Responding to player voice chat")

                            -- Delete the log file after processing
                            file.Delete(textFilePath)
                        end
                    end
                end
            end
        end
    end
end

local checkInterval = 0.5
--- if the cvar chatter_local_stt is set to 1, then create a timer to check for transcriptions
-- if GetConVar("ttt_bot_chatter_voice_local_stt"):GetBool() then
    -- print("Convar chatter_local_stt = ", GetConVar("ttt_bot_chatter_voice_local_stt"):GetBool())
    -- print("Creating timer to check for local transcriptions")
timer.Create("CheckTranscriptionsLocal", checkInterval, 0, checkTranscriptionsLocal)
-- elseif GetConVar("ttt_bot_chatter_voice_azure_stt"):GetBool() then
--     print("Creating timer to check for Azure transcriptions")
--     timer.Create("CheckTranscriptionsAzure", checkInterval, 0, checkTranscriptionsAzure)
-- end

function BotChatter:RespondToPlayerMessage(ply, text, team, delay, wasVoice)
    if not IsValid(ply) or not ply:Alive() then return end
    --- delay is the time in seconds before the bot responds to the message
    -- print("Responding to player message")
    wasVoice = wasVoice or false
    if delay then
        timer.Simple(delay, function()
            self:RespondToPlayerMessage(ply, text, team, false, wasVoice)
        end)
        return
    end
    local teamOnly = team or false
    local fulltxt = string.lower(text)
    if string.sub(fulltxt, 1, 1) == "!" then return end

    --- check if any keyword from the keywordEventsKOS table is in the message
    for keyword, event in pairs(keywordEventsKOS) do
        if string.find(fulltxt, keyword) then
            handleKOS(ply, fulltxt)
        end
    end

    local bots
    if teamOnly then
        -- print("Getting alive allies")
        bots = TTTBots.Lib.GetAliveAllies(ply)
    else
        -- print("Getting alive bots")
        bots = TTTBots.Lib.GetAliveBots()
    end
    -- print("Bots: ", bots)

    local bot = findBestBot(ply, bots, fulltxt, wasVoice, teamOnly)
    
    local plyName = ply:Nick()

    local function handleKeywordEvents(keywordEvents, handlerFunction, ply, fulltxt, bot, teamOnly, bots)
        for keyword, event in pairs(keywordEvents) do
            if string.find(fulltxt, keyword) then
                if string.find(fulltxt, "someone") then
                    local targets = bots
                    local target = table.Random(targets)
                    while target == ply do
                        target = table.Random(targets)
                    end
                    handlerFunction(target, ply)
                    return true
                elseif string.find(fulltxt, "me") then
                    -- print("Handling me event")
                    handlerFunction(bot, ply)
                    return true
                elseif not string.find(fulltxt, "everyone") then
                    if not bot and ply then return end
                    handlerFunction(bot, ply, teamOnly)
                    return true
                else
                    for _, bot in ipairs(bots) do
                        handlerFunction(bot, ply, teamOnly)
                    end
                    return true
                end
            end
        end
    end

    if handleKeywordEvents(keywordeventCeaseFire, handleCeaseFire, ply, fulltxt, bot, teamOnly, bots) then return end
    if handleKeywordEvents(keywordeventsCallHeal, handleHeal, ply, fulltxt, bot, teamOnly, bots) then return end
    if handleKeywordEvents(keywordEventComeHere, handleComeHere, ply, fulltxt, bot, teamOnly, bots) then return end
    if handleKeywordEvents(keywordEventsRoleChecker, handleRoleChecker, ply, fulltxt, bot, teamOnly, bots) then return end
    if handleKeywordEvents(keywordEventFollowMe, handleFollowMe, ply, fulltxt, bot, teamOnly, bots) then return end
    if handleKeywordEvents(keywordEventsCallWait, handleWait, ply, fulltxt, bot, teamOnly, bots) then return end

    local targets = {}

    if bot then
        if teamOnly then
            for _, player in ipairs(TTTBots.Lib.GetAlivePlayers()) do
                if player:GetTeam() ~= bot:GetTeam() and player ~= bot and player ~= ply then
                table.insert(targets, player)
                end
            end
        else
            for _, player in ipairs(TTTBots.Lib.GetAlivePlayers()) do
                if player ~= bot and player ~= ply then
                    table.insert(targets, player)
                end
            end
        end
    end

    local function handleKeywordEventsAttack(keywordEvents, handlerFunction, ply, fulltxt, bot, teamOnly, bots, targets)
        for keyword, event in pairs(keywordEvents) do
            if string.find(fulltxt, keyword) then
                -- print("Handling attack for keyword: ", keyword)
                
                if string.find(fulltxt, "me") then
                    -- print("Handling me attack")
                    local target = ply
                    handlerFunction(bot, ply, target, teamOnly)
                    return true
                elseif string.find(fulltxt, "someone") then
                    -- print("Handling someone attack")
                    local target = table.Random(targets)
                    while target == ply do
                        target = table.Random(targets)
                    end
                    handlerFunction(bot, ply, target, teamOnly)
                    return true
                elseif string.find(fulltxt, "everyone") then
                    -- print("Handling everyone attack")
                    local botTargets = findPlayersInText(fulltxt)
                    for _, bot in ipairs(targets) do
                        local target = botTargets[1]
                        if not target then return end
                        local botTeam = bot:GetTeam()
                        local targetTeam = target:GetTeam()
                        local check = bot == target or (botTeam == targetTeam and botTeam ~= TEAM_INNOCENT)
                        if not check then
                            handlerFunction(bot, ply, target, teamOnly)
                        end
                    end
                    return true
                elseif teamOnly then
                    -- print("Handling team only attack")
                    --- select a random teammate that is not the player (if one exists)
                    --- then select a random non-team and not the player target
                    local bot = table.Random(bots)
                    -- print("Bot: ", bot)
                    local target = nil
                    for _, player in ipairs(TTTBots.Lib.GetAlivePlayers()) do
                        if player ~= ply and player:GetTeam() ~= ply:GetTeam() then
                            target = player
                            -- print("Target: ", target)
                            break
                        end
                    end
                    if not (target and bot) then return end
                    handlerFunction(bot, ply, target, teamOnly)
                    return true
                elseif not string.find(fulltxt, "everyone") then
                    -- print("Handling single attack")
                    local botTargets = findPlayersInText(fulltxt)
                    local target = botTargets[2]
                    if not target and ply then return end
                    local botTeam = bot:GetTeam()
                    local targetTeam = target:GetTeam()
                    if bot == target or (botTeam == targetTeam and botTeam ~= TEAM_INNOCENT) then return end
                    handlerFunction(bot, ply, target, teamOnly)
                    return true
                end
            end
        end
    end
    
    if bot then
        if handleKeywordEventsAttack(keywordEventsCallAttack, handleAttack, ply, fulltxt, bot, teamOnly, bots, targets) then return end
        if handleKeywordEventsAttack(keywordEventsCallCursed, handleCursed, ply, fulltxt, bot, teamOnly, bots, targets) then return end
        if handleKeywordEventsAttack(keywordEventsCallDefector, handleDefector, ply, fulltxt, bot, teamOnly, bots, targets) then return end
        if handleKeywordEventsAttack(keywordeventsCallMedic, handleMedic, ply, fulltxt, bot, teamOnly, bots, targets) then return end

        local chatter = bot:BotChatter()
        local fulltxt = TTTBots.Locale.GetChatGPTPromptResponse(bot, text, teamOnly, ply)
        local maxLength = 1000
        local startIndex = 1
        -- while startIndex <= #fulltxt do
        --     local endIndex = math.min(startIndex + maxLength - 1, #fulltxt)
        --     print("Sending request to ChatGPT API...", fulltxt:sub(startIndex, endIndex))
        --     startIndex = endIndex + 1
        -- end
        TTTBots.ChatGPT.SendRequest(fulltxt, bot, teamOnly, wasVoice, function(response)
            if response then
                response = response:gsub('"', '\\"')
                chatter:textorTTS(bot, response, teamOnly, false, wasVoice)
            else
                print("ChatGPT request returned nil")
            end
        end)
    end
end

hook.Add("PlayerSay", "TTTBots.ChatGPT.GetResponse", function(ply, text, team)
    -- print("Player " .. ply:Nick() .. " said: " .. text)
    BotChatter:RespondToPlayerMessage(ply, text, team, 2)
end)

function BotChatter:GetPlayers()
    local tbl = {}
    for _, ply in ipairs(player.GetAll()) do
        table.insert(tbl, ply)
    end

    return tbl
end

function BotChatter:WriteDataEL(teamOnly, ply, IsOnePart, FileID, FileData, FileCurrentPart, FileLastPart)
    local FileSize = #FileData
    local MaxChunkSize = 60000 -- Adjusted chunk size to avoid exceeding net.WriteData limit

    net.Start("SayTTSEL")
        net.WriteBool(IsOnePart)
        net.WriteBool(teamOnly)
        net.WriteString(FileID)
        net.WriteEntity(ply)

        if IsOnePart then
            net.WriteUInt(FileSize, 16) -- Increased to 32 bits to handle larger sizes
            net.WriteData(FileData, FileSize)
        else
            -- Send in what queue is in the file
            net.WriteUInt(FileCurrentPart, 16) -- Increased to 32 bits to handle larger sizes
            net.WriteUInt(FileLastPart, 16) -- Increased to 32 bits to handle larger sizes

            -- Send FileData in chunks
            local chunks = math.ceil(FileSize / MaxChunkSize)
            net.WriteUInt(chunks, 16) -- Increased to 32 bits to handle larger sizes
            for i = 1, chunks do
                local startIdx = (i - 1) * MaxChunkSize + 1
                local endIdx = math.min(i * MaxChunkSize, FileSize)
                local chunkData = string.sub(FileData, startIdx, endIdx)
                local chunkSize = #chunkData
                net.WriteUInt(chunkSize, 16) -- Increased to 32 bits to handle larger sizes
                net.WriteData(chunkData, chunkSize)
            end
        end

    net.Broadcast()
    -- print("Sent TTS data to clients.")
end

function BotChatter:WriteDataFree(teamOnly, ply, IsOnePart, FileID, FileData, FileCurrentPart, FileLastPart)
    local FileSize = #FileData
    local MaxChunkSize = 60000 -- Adjusted chunk size to avoid exceeding net.WriteData limit

    net.Start("SayTTSBad")
        net.WriteBool(IsOnePart)
        net.WriteBool(teamOnly)
        net.WriteString(FileID)
        net.WriteEntity(ply)

        if IsOnePart then
            net.WriteUInt(FileSize, 16) -- Increased to 32 bits to handle larger sizes
            net.WriteData(FileData, FileSize)
        else
            -- Send in what queue is in the file
            net.WriteUInt(FileCurrentPart, 16) -- Increased to 32 bits to handle larger sizes
            net.WriteUInt(FileLastPart, 16) -- Increased to 32 bits to handle larger sizes

            -- Send FileData in chunks
            local chunks = math.ceil(FileSize / MaxChunkSize)
            net.WriteUInt(chunks, 16) -- Increased to 32 bits to handle larger sizes
            for i = 1, chunks do
                local startIdx = (i - 1) * MaxChunkSize + 1
                local endIdx = math.min(i * MaxChunkSize, FileSize)
                local chunkData = string.sub(FileData, startIdx, endIdx)
                local chunkSize = #chunkData
                net.WriteUInt(chunkSize, 16) -- Increased to 32 bits to handle larger sizes
                net.WriteData(chunkData, chunkSize)
            end
        end

    net.Broadcast()
    -- print("Sent TTS data to clients.")
end
    
    

timer.Create("TTTBots.Chatter.SillyChat", 20, 0, function()
    if math.random(1, 9) > 1 then return end -- Should average to about once every 3 minutes
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

---@class Player
local plyMeta = FindMetaTable("Player")
function plyMeta:BotChatter()
    ---@cast self Bot
    local comp = self.components.chatter
    return comp
end
