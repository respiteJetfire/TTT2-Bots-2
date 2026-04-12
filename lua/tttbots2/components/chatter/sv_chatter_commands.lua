--- sv_chatter_commands.lua
--- All keyword tables and their associated command-handler functions.
--- Also contains the two dispatchers (handleKeywordEvents / handleKeywordEventsAttack)
--- and the top-level RespondToPlayerMessage method.
--- Depends on: sv_chatter_parser.lua (TTTBots.ChatterParser)

local lib    = TTTBots.Lib
local Parser = TTTBots.ChatterParser
local BotChatter = TTTBots.Components.Chatter

-- ---------------------------------------------------------------------------
-- Keyword → event-name tables
-- ---------------------------------------------------------------------------

local keywordEventsKOS = {
    ["kos"]   = "CallKOS",
    ["k.o.s"] = "CallKOS",
}

local keywordEventsCallDefend = {
    ["defend"]                = "CallDefend",
    ["hold the line"]         = "CallDefend",
    ["protect this area"]     = "CallDefend",
    ["guard this spot"]       = "CallDefend",
    ["secure the area"]       = "CallDefend",
    ["hold position"]         = "CallDefend",
    ["defend here"]           = "CallDefend",
    ["keep them out"]         = "CallDefend",
    ["don't let them pass"]   = "CallDefend",
    ["fortify this position"] = "CallDefend",
}

local keywordEventsCallCursed = {
    ["curse"] = "CallCursed",
}

local keywordEventsCallDefector = {
    ["defect"] = "CallDefector",
}

local keywordeventsCallHeal = {
    ["healer"]  = "CallHeal",
    ["health"]  = "CallHeal",
    ["heal me"] = "CallHeal",
}

local keywordeventsCallMedic = {
    ["medic"] = "CallMedic",
}

local keywordeventCeaseFire = {
    ["cease fire"]    = "CallCeaseFire",
    ["stop shooting"] = "CallCeaseFire",
    ["don't shoot"]   = "CallCeaseFire",
}

local keywordEventsCallWait = {
    ["wait"]            = "CallWait",
    ["stay"]            = "CallWait",
    ["freeze"]          = "CallWait",
    ["stop right there"]= "CallWait",
    ["stop moving"]     = "CallWait",
    ["halt"]            = "CallWait",
    ["stand still"]     = "CallWait",
}

local keywordEventFollowMe = {
    ["follow me"]          = "FollowMe",
    ["come with me"]       = "FollowMe",
    ["don't leave me alone"]= "FollowMe",
    ["stick with me"]      = "FollowMe",
    ["stay close"]         = "FollowMe",
    ["let's go"]           = "FollowMe",
    ["right behind me"]    = "FollowMe",
    ["stay with me"]       = "FollowMe",
    ["follow my lead"]     = "FollowMe",
    ["let's move"]         = "FollowMe",
    ["come along"]         = "FollowMe",
    ["keep up"]            = "FollowMe",
    ["don't fall behind"]  = "FollowMe",
}

local keywordEventsCallAttack = {
    ["attack"]     = "CallAttack",
    ["kill"]       = "CallAttack",
    ["shoot"]      = "CallAttack",
    ["fire"]       = "CallAttack",
    ["take out"]   = "CallAttack",
    ["take care of"]= "CallAttack",
    ["eliminate"]  = "CallAttack",
    ["destroy"]    = "CallAttack",
    ["neutralize"] = "CallAttack",
    ["terminate"]  = "CallAttack",
    ["wipe out"]   = "CallAttack",
    ["exterminate"]= "CallAttack",
    ["annihilate"] = "CallAttack",
    ["obliterate"] = "CallAttack",
    ["eradicate"]  = "CallAttack",
    ["dispatch"]   = "CallAttack",
    ["take down"]  = "CallAttack",
    ["dispose of"] = "CallAttack",
}

local keywordEventsRoleChecker = {
    ["role checker"]    = "RequestUseRoleChecker",
    ["check role"]      = "RequestUseRoleChecker",
    ["role check"]      = "RequestUseRoleChecker",
    ["what is your role"]= "RequestUseRoleChecker",
}

local keywordEventComeHere = {
    ["come here"] = "ComeHere",
    ["over here"] = "ComeHere",
    ["this way"]  = "ComeHere",
    ["look at this"]= "ComeHere",
}

local keywordEventsCallBackup = {
    ["backup"]         = "CallBackup",
    ["need backup"]    = "CallBackup",
    ["assist me"]      = "CallBackup",
    ["help me"]        = "CallBackup",
    ["i need help"]    = "CallBackup",
    ["support me"]     = "CallBackup",
    ["i need support"] = "CallBackup",
    ["cover me"]       = "CallBackup",
    ["i need cover"]   = "CallBackup",
    ["reinforce me"]   = "CallBackup",
}

-- ---------------------------------------------------------------------------
-- Individual command handler functions
-- ---------------------------------------------------------------------------

local function handleKOS(ply, fulltxt)
    local players = TTTBots.Lib.GetAlivePlayers()
    for _, player in ipairs(players) do
        if Parser.isNameInMessage(player, fulltxt) and player ~= ply then
            print("KOS callout target: ", player)
            return TTTBots.Match.CallKOS(ply, player)
        end
    end
    return false
end

local function handleCeaseFire(ply, fulltxt)
    local CeaseFire = TTTBots.Behaviors.RequestCeaseFire
    if ply and IsValid(ply) then
        CeaseFire.HandleRequest(ply, fulltxt)
    end
end

local function handleHeal(ply, fulltxt)
    local Heal = TTTBots.Behaviors.Healgun
    if ply and IsValid(ply) then
        Heal.HandleRequest(ply, fulltxt)
    end
end

local function handleFollowMe(bot, ply, teamOnly)
    local FollowMe = TTTBots.Behaviors.FollowMe
    if bot and IsValid(bot) then
        FollowMe.InitiateFollow(bot, ply, teamOnly)
    end
end

local function handleComeHere(bot, ply, teamOnly)
    local ComeHere = TTTBots.Behaviors.ComeHere
    if bot and IsValid(bot) then
        ComeHere.InitiateFollow(bot, ply, teamOnly)
    end
end

local function handleWait(bot, ply, teamOnly)
    local Wait = TTTBots.Behaviors.Wait
    if bot and IsValid(bot) then
        Wait.RequestWait(bot, ply, teamOnly)
    end
end

local function handleRoleChecker(bot, ply, teamOnly)
    local RoleChecker = TTTBots.Behaviors.RequestUseRoleChecker
    if bot and IsValid(bot) then
        RoleChecker.HandleRequest(bot, ply, teamOnly)
    end
end

local function handleAttack(bot, ply, target, teamOnly)
    local Attack = TTTBots.Behaviors.RequestAttack
    if bot and IsValid(bot) and target and IsValid(target) then
        Attack.RequestAttack(bot, ply, target, teamOnly)
    end
end

local function handleCursed(bot, ply, target, teamOnly)
    local Cursed = TTTBots.Behaviors.CreateCursed
    if bot and IsValid(bot) then
        Cursed.HandleRequest(bot, target)
    end
end

local function handleDefector(bot, ply, target, teamOnly)
    local Defector = TTTBots.Behaviors.CreateDefector
    if bot and IsValid(bot) then
        Defector.HandleRequest(bot, target)
    end
end

local function handleMedic(bot, ply, target, teamOnly)
    local Medic = TTTBots.Behaviors.CreateMedic
    if bot and IsValid(bot) then
        Medic.HandleRequest(bot, target)
    end
end

-- ---------------------------------------------------------------------------
-- Generic keyword-event dispatcher
-- ---------------------------------------------------------------------------

local function handleKeywordEvents(keywordTbl, handlerFunction, ply, fulltxt, bot, teamOnly, bots)
    for keyword, event in pairs(keywordTbl) do
        if string.find(fulltxt, keyword) then
            if string.find(fulltxt, "someone") then
                local target = table.Random(bots)
                while target == ply do
                    target = table.Random(bots)
                end
                handlerFunction(target, ply)
                return true
            elseif string.find(fulltxt, "me") then
                handlerFunction(bot, ply)
                return true
            elseif not string.find(fulltxt, "everyone") then
                if not bot and ply then return end
                handlerFunction(bot, ply, teamOnly)
                return true
            else
                for _, b in ipairs(bots) do
                    handlerFunction(b, ply, teamOnly)
                end
                return true
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Attack-specific keyword-event dispatcher (needs target resolution)
-- ---------------------------------------------------------------------------

local function handleKeywordEventsAttack(keywordTbl, handlerFunction, ply, fulltxt, bot, teamOnly, bots, targets)
    for keyword, event in pairs(keywordTbl) do
        if string.find(fulltxt, keyword) then
            if teamOnly then
                local randomBot = table.Random(bots)
                local target    = nil
                for _, player in ipairs(TTTBots.Lib.GetAlivePlayers()) do
                    if player ~= ply and player:GetTeam() ~= ply:GetTeam() then
                        target = player
                        break
                    end
                end
                if not (target and randomBot) then return end
                handlerFunction(randomBot, ply, target, teamOnly)
                return true

            elseif string.find(fulltxt, "me") then
                handlerFunction(bot, ply, ply, teamOnly)
                return true

            elseif string.find(fulltxt, "someone") then
                local target = table.Random(targets)
                while target == ply do
                    target = table.Random(targets)
                end
                handlerFunction(bot, ply, target, teamOnly)
                return true

            elseif string.find(fulltxt, "everyone") then
                local botTargets = Parser.findPlayersInText(fulltxt)
                for _, b in ipairs(targets) do
                    local target = botTargets[1]
                    if not target then return end
                    local check = b == target or (b:GetTeam() == target:GetTeam() and b:GetTeam() ~= TEAM_INNOCENT)
                    if not check then
                        handlerFunction(b, ply, target, teamOnly)
                    end
                end
                return true

            elseif not string.find(fulltxt, "everyone") then
                local botTargets = Parser.findPlayersInText(fulltxt)
                local target = botTargets[2]
                if not target and ply then return end
                if bot == target or (bot:GetTeam() == target:GetTeam() and bot:GetTeam() ~= TEAM_INNOCENT) then return end
                handlerFunction(bot, ply, target, teamOnly)
                return true
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- BotChatter:RespondToPlayerMessage  (main command router)
-- ---------------------------------------------------------------------------

--- Route a player's message to the appropriate bot command handlers and LLM reply.
---@param ply Player  the human (or voice STT) sender
---@param text string raw message text
---@param team boolean team-only flag
---@param delay number|false optional seconds before responding
---@param wasVoice boolean true if this came from STT
function BotChatter:RespondToPlayerMessage(ply, text, team, delay, wasVoice)
    if not IsValid(ply) or not ply:Alive() then return end
    wasVoice = wasVoice or false

    if delay then
        timer.Simple(delay, function()
            self:RespondToPlayerMessage(ply, text, team, false, wasVoice)
        end)
        return
    end

    local teamOnly = team or false
    local fulltxt  = string.lower(text)
    if string.sub(fulltxt, 1, 1) == "!" then return end

    -- KOS callouts are global (affect all bots)
    for keyword, _ in pairs(keywordEventsKOS) do
        if string.find(fulltxt, keyword) then
            handleKOS(ply, fulltxt)
        end
    end

    local bots
    if teamOnly then
        bots = TTTBots.Lib.GetAliveAllies(ply)
    else
        bots = TTTBots.Lib.GetAliveBots()
    end

    -- Proximity chat: only bots within range of the speaker can hear the message
    if TTTBots.Proximity and TTTBots.Proximity.IsActive() then
        bots = TTTBots.Proximity.FilterRecipients(ply, bots, teamOnly)
    end

    local bot = Parser.findBestBot(ply, bots, fulltxt, wasVoice, teamOnly)

    -- Non-attack keyword commands
    if handleKeywordEvents(keywordeventCeaseFire,    handleCeaseFire,  ply, fulltxt, bot, teamOnly, bots) then return end
    if handleKeywordEvents(keywordeventsCallHeal,    handleHeal,       ply, fulltxt, bot, teamOnly, bots) then return end
    if handleKeywordEvents(keywordEventComeHere,     handleComeHere,   ply, fulltxt, bot, teamOnly, bots) then return end
    if handleKeywordEvents(keywordEventsRoleChecker, handleRoleChecker,ply, fulltxt, bot, teamOnly, bots) then return end
    if handleKeywordEvents(keywordEventFollowMe,     handleFollowMe,   ply, fulltxt, bot, teamOnly, bots) then return end
    if handleKeywordEvents(keywordEventsCallWait,    handleWait,       ply, fulltxt, bot, teamOnly, bots) then return end

    -- Build target list for attack-style commands
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

    if bot then
        if handleKeywordEventsAttack(keywordEventsCallAttack,  handleAttack,   ply, fulltxt, bot, teamOnly, bots, targets) then return end
        if handleKeywordEventsAttack(keywordEventsCallCursed,  handleCursed,   ply, fulltxt, bot, teamOnly, bots, targets) then return end
        if handleKeywordEventsAttack(keywordEventsCallDefector,handleDefector, ply, fulltxt, bot, teamOnly, bots, targets) then return end
        if handleKeywordEventsAttack(keywordeventsCallMedic,   handleMedic,    ply, fulltxt, bot, teamOnly, bots, targets) then return end

        -- Fall through to LLM conversational reply
        local chatter    = bot:BotChatter()
        local promptData = TTTBots.ChatGPTPrompts.GetChatGPTPromptResponse(bot, text, teamOnly, ply)
        local prompt     = promptData.prompt or promptData  -- backward compat: accept string or table
        local sendOpts = {
            teamOnly = teamOnly,
            wasVoice = wasVoice,
            systemPrompt = promptData.system,  -- system role message for cloud providers
            -- Extra context for adapters that build their own prompts (e.g. Ollama/llama)
            replyText = text,
            replyPly  = ply,
        }

        TTTBots.Providers.SendText(prompt, bot, sendOpts, function(envelope)
            if not envelope.ok then
                local message = tostring(envelope.message or "")
                if string.find(message, "LLM is disabled", 1, true) then
                    return
                end
                print("LLM request failed: " .. message)
                return
            end
            local response = TTTBots.Providers.StripQuotes(envelope.text)
            -- Strip any unresolved {{...}} placeholders the LLM may have echoed
            response = response:gsub("{{.-}}", "")
            response = response:gsub("%s%s+", " ")
            response = response:match("^%s*(.-)%s*$") or response
            if response == "" then return end
            chatter:textorTTS(bot, response, teamOnly, false, wasVoice)
        end)
    end
end
