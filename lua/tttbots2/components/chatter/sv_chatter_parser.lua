--- sv_chatter_parser.lua
--- Text-matching utilities: typo engine, name matching, Levenshtein distance,
--- and helpers that locate bots / players referenced in a chat message.
--- Consumed by sv_chatter_core.lua (via BotChatter) and sv_chatter_commands.lua.

local lib = TTTBots.Lib

-- ---------------------------------------------------------------------------
-- Keyboard-adjacency table (QWERTY, lowercase only)
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- BotChatter:TypoText  (method added onto the shared BotChatter table)
-- ---------------------------------------------------------------------------

local BotChatter = TTTBots.Components.Chatter

--- Intentionally inject typos into the text based on the chatter_typo_chance convars
---@param text string
---@return string result
function BotChatter:TypoText(text)
    local chance = lib.GetConVarFloat("chatter_typo_chance")

    local typoFuncs = {
        removeCharacter    = function(last, this, next) return "" end,
        duplicateCharacter = function(last, this, next) return this .. this end,
        capitalizeCharacter = function(last, this, next) return string.upper(this) end,
        lowercaseCharacter  = function(last, this, next) return string.lower(this) end,
        switchWithNext      = function(last, this, next) return next .. this end,
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

-- ---------------------------------------------------------------------------
-- Module-level helpers (exposed via TTTBots.ChatterParser so other modules
-- don't need to re-declare them).
-- ---------------------------------------------------------------------------
TTTBots.ChatterParser = TTTBots.ChatterParser or {}
local Parser = TTTBots.ChatterParser

--- Calculate the Levenshtein distance between two strings.
---@param str1 string
---@param str2 string
---@return integer
function Parser.levenshtein(str1, str2)
    local len1, len2 = #str1, #str2
    local matrix = {}

    for i = 0, len1 do
        matrix[i] = { [0] = i }
    end
    for j = 0, len2 do
        matrix[0][j] = j
    end

    for i = 1, len1 do
        for j = 1, len2 do
            local cost = (str1:sub(i, i) == str2:sub(j, j)) and 0 or 1
            matrix[i][j] = math.min(
                matrix[i - 1][j] + 1,
                matrix[i][j - 1] + 1,
                matrix[i - 1][j - 1] + cost
            )
        end
    end

    return matrix[len1][len2]
end

--- Check if the bot's name (or a similar string) appears in a message.
---@param bot Player
---@param message string (lowercase)
---@return boolean
function Parser.isNameInMessage(bot, message)
    local botName = bot:Nick():lower():gsub("%W", "")
    local words = {}
    for word in message:gmatch("%w+") do
        table.insert(words, word:lower())
    end

    local messageString = table.concat(words, "")

    if string.find(messageString, botName) or string.find(botName, messageString) then
        return true
    end

    for _, word in ipairs(words) do
        local maxLen = math.max(#botName, #word)
        local distance = Parser.levenshtein(botName, word)
        local similarity = (maxLen - distance) / maxLen
        if similarity >= 0.6 then
            return true
        end
    end

    return false
end

--- Find the single best bot to respond to a given message (distance + name match).
---@param ply Player sender
---@param bots table<Player> candidate bots
---@param fulltxt string lowercase full message
---@param wasVoice boolean
---@param teamOnly boolean
---@return Player|nil
function Parser.findBestBot(ply, bots, fulltxt, wasVoice, teamOnly)
    local bestDist = math.huge
    local bot      = nil

    local chatterMult  = TTTBots.Lib.GetConVarFloat("chatter_reply_chance_multi")
    local forceReply   = TTTBots.Lib.GetConVarBool("chatter_voice_force_reply_player")

    local chance
    for _, b in ipairs(bots) do
        if IsValid(b) then
            local dist = ply:GetPos():Distance(b:GetPos())
            if Parser.isNameInMessage(b, fulltxt) and b ~= ply then
                chance = 100
                bot    = b
                break
            elseif dist < bestDist and b ~= ply then
                chance   = math.max(5, 60 - ((dist / 500) * 55))
                bestDist = dist
                bot      = b
            elseif teamOnly and b ~= ply and not ply:IsBot() and b:GetTeam() == ply:GetTeam() then
                chance = 100
                bot    = b
            end
        end
    end

    if bot and ((not ply:IsBot() and not wasVoice) or (not ply:IsBot() and forceReply)) then return bot end
    if not (chance and bot) then return end
    chance = chance * chatterMult
    if math.random(1, 100) > chance then return nil end
    return bot
end

--- Return up to two alive players whose names appear in the message text.
---@param fulltxt string lowercase full message
---@return table<Player>
function Parser.findPlayersInText(fulltxt)
    local foundPlayers = {}
    for _, player in ipairs(TTTBots.Lib.GetAlivePlayers()) do
        if Parser.isNameInMessage(player, fulltxt) then
            table.insert(foundPlayers, player)
            if #foundPlayers == 2 then break end
        end
    end
    return foundPlayers
end
