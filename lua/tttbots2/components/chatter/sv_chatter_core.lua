--- sv_chatter_core.lua
--- Core chatter component: class declaration, New(), Initialize(), CanSayEvent(),
--- SayRaw(), Say(), QuickRadio(), Think(), WriteDataFree(), and the Player meta
--- accessor.  All heavy lifting lives in the sub-modules included below.

---@class CChatter : Component
TTTBots.Components.Chatter = TTTBots.Components.Chatter or {}

local lib = TTTBots.Lib
---@class CChatter : Component
local BotChatter = TTTBots.Components.Chatter

-- ---------------------------------------------------------------------------
-- Sub-module includes  (order matters — later files reference earlier ones)
-- ---------------------------------------------------------------------------
include("tttbots2/components/chatter/sv_chatter_parser.lua")
include("tttbots2/components/chatter/sv_chatter_commands.lua")
include("tttbots2/components/chatter/sv_chatter_dispatch.lua")
include("tttbots2/components/chatter/sv_chatter_events.lua")
include("tttbots2/components/chatter/sv_chatter_stt_evidence.lua") -- Tier 8: STT evidence extraction (9.4)
include("tttbots2/components/chatter/sv_chatter_stt.lua")

-- ---------------------------------------------------------------------------
-- Component lifecycle
-- ---------------------------------------------------------------------------

function BotChatter:New(bot)
    local newChatter = {}
    setmetatable(newChatter, {
        __index = function(t, k) return BotChatter[k] end,
    })
    newChatter:Initialize(bot)

    if lib.GetConVarBool("debug_misc") then
        print("Initialized Chatter for bot " .. bot:Nick())
    end

    return newChatter
end

function BotChatter:Initialize(bot)
    bot.components       = bot.components or {}
    bot.components.chatter = self

    self.componentID = string.format("Chatter (%s)", lib.GenerateID())
    self.ThinkRate   = 2 -- Run every 2nd tick (~2.5Hz)
    self.tick        = 0
    self.bot         = bot
    self.rateLimitTbl = {}
end

-- ---------------------------------------------------------------------------
-- Rate limiting
-- ---------------------------------------------------------------------------

--- Return true and stamp the event if the rate-limit window has elapsed.
---@param event string
---@return boolean
function BotChatter:CanSayEvent(event)
    local rateLimitTime = lib.GetConVarFloat("chatter_minrepeat")
    local lastSpeak     = self.rateLimitTbl[event] or -math.huge

    if lastSpeak + rateLimitTime < CurTime() then
        self.rateLimitTbl[event] = CurTime()
        return true
    end

    return false
end

-- ---------------------------------------------------------------------------
-- Low-level speak helpers
-- ---------------------------------------------------------------------------

--- Send a raw string directly into chat (bypasses typing simulation).
---@param text string
---@param teamOnly boolean|nil
function BotChatter:SayRaw(text, teamOnly)
    if not IsValid(self.bot) then return end
    self.bot:Say(text, teamOnly)

    -- When proximity chat is active, only nearby bots "hear" this message
    local aliveBots = TTTBots.Lib.GetAliveBots()
    local hearingBots = TTTBots.Proximity
        and TTTBots.Proximity.FilterRecipients(self.bot, aliveBots, teamOnly)
        or aliveBots

    for _, bot in ipairs(hearingBots) do
        local mem = bot:BotMemory()
        if mem then
            mem:UpdateMessages(text, self.bot)
        end
    end
end

local RADIO = {
    quick_traitor = "%s is a Traitor!",
    quick_suspect = "%s acts suspicious.",
}

--- Fire a quick-radio message for this bot.
---@param msgName string
---@param msgTarget Player
function BotChatter:QuickRadio(msgName, msgTarget)
    local txt = RADIO[msgName]
    if not txt then ErrorNoHaltWithStack("Unknown message type " .. msgName) end
    hook.Run("TTTPlayerRadioCommand", self.bot, msgName, msgTarget)
end

--- Queue a typed chat message, simulating typing delay and injecting typos.
---@param text string
---@param teamOnly boolean|nil
---@param ignoreDeath boolean|nil
---@param callback function|nil
---@return boolean  true if queued, false if already typing
function BotChatter:Say(text, teamOnly, ignoreDeath, callback)
    if self.typing then return false end

    local cps   = lib.GetConVarFloat("chatter_cps")
    local delay = (string.len(text) / cps) * (math.random(75, 150) / 100)

    self.typing = true

    text = string.gsub(text, "%[BOT%] ", "")
    text = string.gsub(text, "%[bot%] ", "")
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

-- ---------------------------------------------------------------------------
-- Component Think (placeholder — extended by sub-systems as needed)
-- ---------------------------------------------------------------------------

function BotChatter:Think()
end

-- ---------------------------------------------------------------------------
-- Utility helpers
-- ---------------------------------------------------------------------------

--- Return all current players.
---@return table<Player>
function BotChatter:GetPlayers()
    local tbl = {}
    for _, ply in ipairs(player.GetAll()) do
        table.insert(tbl, ply)
    end
    return tbl
end

--- Send chunked FreeTTS audio data to all clients over the network.
function BotChatter:WriteDataFree(teamOnly, ply, IsOnePart, FileID, FileData, FileCurrentPart, FileLastPart)
    local FileSize     = #FileData
    local MaxChunkSize = 60000

    net.Start("SayTTSBad")
        net.WriteBool(IsOnePart)
        net.WriteBool(teamOnly)
        net.WriteString(FileID)
        net.WriteEntity(ply)

        if IsOnePart then
            net.WriteUInt(FileSize, 16)
            net.WriteData(FileData, FileSize)
        else
            net.WriteUInt(FileCurrentPart, 16)
            net.WriteUInt(FileLastPart, 16)

            local chunks = math.ceil(FileSize / MaxChunkSize)
            net.WriteUInt(chunks, 16)
            for i = 1, chunks do
                local startIdx  = (i - 1) * MaxChunkSize + 1
                local endIdx    = math.min(i * MaxChunkSize, FileSize)
                local chunkData = string.sub(FileData, startIdx, endIdx)
                local chunkSize = #chunkData
                net.WriteUInt(chunkSize, 16)
                net.WriteData(chunkData, chunkSize)
            end
        end

    -- Proximity chat: send only to nearby human players when active
    local recipients = TTTBots.Proximity
        and TTTBots.Proximity.GetHumanRecipients(ply, teamOnly)
        or nil

    if recipients and #recipients > 0 then
        net.Send(recipients)
    elseif not recipients then
        net.Broadcast()
    end
    -- If recipients is an empty table (no one in range), don't send at all
end

-- ---------------------------------------------------------------------------
-- Player meta accessor
-- ---------------------------------------------------------------------------

---@class Player
local plyMeta = FindMetaTable("Player")

function plyMeta:BotChatter()
    ---@cast self Bot
    return self.components and self.components.chatter
end
