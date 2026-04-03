--[[
This module is not intended to store everything bot-related, but instead store bot-specific stuff that
is refreshed every round. Things like where the bot last saw each player, etc.
]]
---@class CMemory : Component
TTTBots.Components.Memory = {}
TTTBots = TTTBots or {}

TTTBots.Sound = {
    DetectionInfo = {
        Gunshot = {
            Distance = 1250,
            Keywords = { "gun", "shoot", "shot", "bang", "pew",
                "fiveseven", "mac10", "deagle", "shotgun", "rifle", "pistol", "xm1014", "m249", "scout", "m4a1",
                "glock"
            }
        },
        Footstep = {
            Distance = 350,
            Keywords = { "footstep", "glass_sheet_step" }
        },
        Melee = {
            Distance = 600,
            Keywords = { "swing", "hit", "punch", "slash", "stab" }
        },
        Death = {
            Distance = 1250,
            Keywords = { "pain", "death", "die", "dead", "ouch", "male01" }
        },
        C4Beep = {
            Distance = 600,
            Keywords = { "beep" }
        },
        Explosion = {
            Distance = 1500,
            Keywords = { "ball_zap", "explode" }
        }
    },
    SoundBlacklist = {
        "medshot" -- health stations create items/medshot__.wav, which overlaps with "shot" above
    }
}

local lib = TTTBots.Lib
---@class CMemory : Component
local Memory = TTTBots.Components.Memory
local DEAD = "DEAD"
local ALIVE = "ALIVE"

-- Door activity tracking: detect door camping
Memory.DoorActivityLog = Memory.DoorActivityLog or {} -- [entIndex] = {uses=0, lastActivity=0, usersNearby={}}
Memory.DOOR_CAMP_THRESHOLD = 4  -- 4+ use events in 10 seconds = suspicious
Memory.DOOR_CAMP_WINDOW = 10    -- seconds
local FORGET = {
    Base = 30,
    Variance = 5,
    Traits = {
        -- Personality traits that multiply Base
        cautious = 1.1,
        sniper = 1.2,
        camper = 1.3,
        aggressive = 0.9,
        doesntcare = 0.5,
        bodyguard = 1.1,
        lovescrowds = 0.8,
        teamplayer = 0.9,
        loner = 1.1,
        -- The big traits:
        veryobservant = 2.0,
        observant = 1.5,
        oblivious = 0.8,
        veryoblivious = 0.4,
    },
}

FORGET.GetRememberTime = function(ply)
    local traits = ply.components.personality.traits
    local base = FORGET.Base
    local variance = FORGET.Variance
    local multiplier = 1
    for i, trait in pairs(traits) do
        if FORGET.Traits[trait] then
            multiplier = multiplier * FORGET.Traits[trait]
        end
    end
    return base * multiplier + math.random(-variance, variance)
end


function Memory:New(bot)
    local newMemory = {}
    setmetatable(newMemory, {
        __index = function(t, k) return Memory[k] end,
    })
    newMemory:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        print("Initialized Memory for bot " .. bot:Nick())
    end

    return newMemory
end

local function shouldUseRadar()
    local rand = math.random(1, 100)
    local cv = GetConVar("ttt_bot_radar_chance"):GetInt()

    if rand <= cv then
        return true
    end
    return false
end

-- Maximum number of chat messages to retain in the conversation buffer.
Memory.MAX_MESSAGES = 30
-- Maximum number of recent witness events to retain (ring buffer for LLM context).
Memory.MAX_WITNESS_EVENTS = 5

function Memory:ResetMemory()
    self.playerKnownPositions = {}   -- List of where this bot last saw each player and how long ago
    self.PlayerLifeStates = {}       -- List of what this bot understands each bot's current life state to be
    self.UseRadar = shouldUseRadar() -- Whether or not this bot should use radar
    self.messages = {}               -- List of messages this bot has received (capped, timestamped)

    self.m_genericmemory = { game = {}, round = {} }
    self.visitedNavAreas = {}  -- [navID] = CurTime() timestamp of last visit

    -- Ring buffer of recent notable in-game events for LLM context (9.1)
    self.recentWitnessEvents = {}
    -- Per-bot conversation state for multi-turn memory (9.2)
    self.conversationPartner = nil
    self.lastConversationTime = 0
end

hook.Add("TTTEndRound", "TTTBots.Memory.ClearRoundMemory", function()
    for i, bot in pairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot:BotMemory()) then continue end
        local mem = bot:BotMemory()
        -- Full reset: wipe known positions, life states, sounds, witness events,
        -- danger zones, nav visits, messages, and conversation state.
        -- Preserves "game" scope memory (cross-round) but clears everything else.
        local savedGameMemory = mem.m_genericmemory and mem.m_genericmemory.game or {}
        mem:ResetMemory()
        mem.m_genericmemory.game = savedGameMemory
        -- Also clear recent sounds
        mem.recentSounds = {}
    end
end)

hook.Add("TTTPrepareRound", "TTTBots.Memory.PrepareRoundMemory", function()
    for i, bot in pairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot:BotMemory()) then continue end
        local mem = bot:BotMemory()
        local savedGameMemory = mem.m_genericmemory and mem.m_genericmemory.game or {}
        mem:ResetMemory()
        mem.m_genericmemory.game = savedGameMemory
        mem.recentSounds = {}
    end
end)

---Set the state of memory with certain keyvalue pairs
---@param state "game"|"round"
---@param key any
---@param value any
function Memory:SetMemory(state, key, value)
    self.m_genericmemory[state][key] = value
end

---Get the state of memory with certain keyvalue pairs, else default
---@param state "game"|"round"
---@param key any
---@param default any
---@return any
function Memory:GetMemory(state, key, default)
    return self.m_genericmemory[state][key] or default
end

function Memory:Initialize(bot)
    bot.components = bot.components or {}
    bot.components.memory = self

    self.ThinkRate = 2 -- Run every 2nd tick (~2.5Hz)
    self.bot = bot
    self.tick = 0
    ---@type table<table>
    self.recentSounds = {}
    self.forgetTime = FORGET.GetRememberTime(self.bot)
    self.messages = {}

    self:ResetMemory()
end

--- Simulates radar scanning the position of ply
function Memory:UpdateRadar(ply)
    if self.UseRadar and self.tick % 300 ~= 69 then return end -- Nice
    if not TTTBots.Roles.GetRoleFor(ply):GetCanHaveRadar() then return end
    if not TTTBots.Lib.IsPlayerAlive(ply) then return end

    local pos = ply:GetPos()
    self:UpdateKnownPositionFor(ply, pos)
end

--- Updates messages in the bot's memory with the given message, and sender if applicable.
--- Stores a timestamp and caps the buffer at Memory.MAX_MESSAGES (FIFO eviction).
---@param message string The message to add to the bot's memory.
---@param ply Player|nil The player that sent the message, if applicable.
function Memory:UpdateMessages(message, ply)
    -- Update conversation-partner tracking (9.2)
    if IsValid(ply) and ply ~= self.bot then
        self.conversationPartner   = ply
        self.lastConversationTime  = CurTime()
    end

    table.insert(self.messages, {
        message = message,
        ply     = ply,          -- canonical field name used by prompt formatters
        time    = CurTime(),    -- absolute timestamp for recency filtering
    })

    -- Enforce FIFO cap
    while #self.messages > Memory.MAX_MESSAGES do
        table.remove(self.messages, 1)
    end
end

--- Returns all messages in the bot's memory (may be up to MAX_MESSAGES long).
---@return table<table> messages
function Memory:GetLastMessages()
    return self.messages
end

--- Returns messages received within the last `maxAge` seconds (default 60),
--- limited to the most recent `maxCount` entries (default 10).
--- Used by LLM prompt builders to inject a concise conversation history (9.2).
---@param maxAge number|nil  Seconds of recency window (default 60)
---@param maxCount number|nil Maximum entries to return (default 10)
---@return table<table> messages
function Memory:GetRecentMessages(maxAge, maxCount)
    maxAge   = maxAge   or 60
    maxCount = maxCount or 10
    local cutoff = CurTime() - maxAge
    local result = {}
    for i = #self.messages, 1, -1 do
        local m = self.messages[i]
        if m.time and m.time < cutoff then break end
        table.insert(result, 1, m)
        if #result >= maxCount then break end
    end
    return result
end

--- Returns true if the conversation with the current partner has gone stale
--- (no messages for more than `timeout` seconds, default 60).
---@param timeout number|nil
---@return boolean
function Memory:IsConversationStale(timeout)
    timeout = timeout or 60
    return (CurTime() - self.lastConversationTime) > timeout
end

--- Record a recent witness event (kill, KOS call, body found) for LLM context.
--- Maintains a capped ring buffer of the last Memory.MAX_WITNESS_EVENTS entries.
---@param eventType string  Short label, e.g. "kill", "kos", "body"
---@param description string  Human-readable summary, e.g. "Alice killed Bob"
function Memory:AddWitnessEvent(eventType, description)
    table.insert(self.recentWitnessEvents, {
        eventType   = eventType,
        description = description,
        time        = CurTime(),
    })
    while #self.recentWitnessEvents > Memory.MAX_WITNESS_EVENTS do
        table.remove(self.recentWitnessEvents, 1)
    end
end

--- Returns the recent witness event list, most-recent last.
---@return table<table>
function Memory:GetRecentWitnessEvents()
    return self.recentWitnessEvents or {}
end

function Memory:HandleUnseenPlayer(ply)
    if not IsValid(ply) then return end
    -- Update radar if applicable
    self:UpdateRadar(ply)

    -- Check if we have any memory of this player, if we shouldForget() then delete it
    local pnp = self.playerKnownPositions[ply:Nick()]
    if not pnp then return end
    if pnp.shouldForget() then
        self.playerKnownPositions[ply:Nick()] = nil
    end
end

--- Get the last known position of the given player, if we have any.
---@param ply Player
---@return Vector|nil
function Memory:GetKnownPositionFor(ply)
    if not IsValid(ply) then return nil end
    local nick = ply:IsPlayer() and ply:Nick() or tostring(ply)
    local pnp = self.playerKnownPositions[nick]
    if not pnp then return nil end
    return pnp.pos
end

---Get the CurTime we last saw the player at
---@param ply Player
---@return number
function Memory:GetLastSeenTime(ply)
    if not IsValid(ply) then return 0 end
    if ply:IsNPC() and not TTTBots.Bots[ply] then return 0 end
    local nick = ply and ply:Nick()
    if not nick then return 0 end
    local playerPosition = self.playerKnownPositions[nick] or nil
    if not playerPosition then return 0 end
    return playerPosition.time
end

--- Parse through our recent sound memory for any sounds tied to ply's entity. Returns the position vector, else nil.
---@param ply Player
---@return Vector|nil
function Memory:GetSuspectedPositionFor(ply)
    if not IsValid(ply) then return nil end
    ---@type table<table>
    local recentSounds = self:GetRecentSoundsFromPly(ply)
    if #recentSounds == 0 then return end
    -- sort by time field
    table.sort(recentSounds, function(a, b) return a.time > b.time end)
    -- return the most recent sound
    return recentSounds[1].pos
end

--- Get the last known position of the given player, if we have any. This differs from GetKnownPositionFor
--- in that it will either return ply:GetPos() if lib.CanSee(self.bot, ply), or the last known position.
---@param ply any
---@return Vector|nil Pos, boolean CanSee
function Memory:GetCurrentPosOf(ply)
    if not IsValid(ply) then return nil, false end
    local canSee = self.bot:Visible(ply) -- lib.CanSee(self.bot)
    if canSee then
        self:UpdateKnownPositionFor(ply, ply:GetPos())
        return ply:GetPos(), canSee
    end
    return self:GetKnownPositionFor(ply), canSee
end

--- Update the known position in our database for the given player to their current position, or pos if provided.
---@param ply Player The player object of the target
---@param pos Vector|nil If nil then ply:GetPos() will be used, else this will be used.
---@return table knownPos The updated known position entry for this player
function Memory:UpdateKnownPositionFor(ply, pos)
    if not IsValid(ply) then return end
    -- Get the current time
    local ct = CurTime()

    -- Create the knownPos entry
    local knownPos = {
        ply = ply,                                    -- The player object
        nick = ply:IsPlayer() and ply:Nick() or nil,  -- The player's nickname if it's a player
        pos = pos or ply:GetPos(),                    -- The position of the player
        inferred = (pos and true) or false,           -- Whether or not this position is inferred (and probably not accurate)
        time = ct,                                    -- The time this position was last updated
        forgetTime = FORGET.GetRememberTime(self.bot) -- How many seconds to remember this position for
    }

    -- Function to get how long ago this position was last updated
    function knownPos.timeSince()
        return CurTime() - knownPos.time
    end

    -- Function to check whether or not we should forget this position
    function knownPos.shouldForget()
        -- Calculate the elapsed time since the last update
        local ts = CurTime() - knownPos.time

        -- Get the corresponding known position of the player
        local pKP = self.playerKnownPositions[ply:IsPlayer() and ply:Nick() or ply]

        -- If this player is our active attack target, only forget by time —
        -- never by VisibleVec. Arriving at their last-known corner and seeing
        -- the empty spot should NOT wipe the entry; the target likely just
        -- ducked around the next corner, and we need to keep chasing.
        local isAttackTarget = IsValid(ply) and (self.bot.attackTarget == ply)
        if isAttackTarget then
            return ts > pKP.forgetTime
        end

        -- Return whether the elapsed time is greater than the forget time,
        -- OR we can see the remembered position (meaning the target isn't there).
        return (ts > pKP.forgetTime) or (pKP and self.bot:VisibleVec(pKP.pos))
    end

    -- Update the known position for this player
    self.playerKnownPositions[ply:IsPlayer() and ply:Nick() or ply] = knownPos

    return knownPos
end

--- Updates the positions of every player in the game.
--- Handles forgetting players that we can no longer see according to memory rules.
function Memory:UpdateKnownPositions()
    local AlivePlayers = lib.GetAlivePlayers()
    local RoundActive = TTTBots.Match.RoundActive
    local PostRoundDM = TTTBots.Match.IsPostRoundDM()
    if not RoundActive and not PostRoundDM then
        self.playerKnownPositions = {}
        return false
    end

    for i, ply in pairs(AlivePlayers) do
        if ply == self.bot then continue end
        if not lib.CanSee(self.bot, ply) then
            self:HandleUnseenPlayer(ply)
            continue
        end
        self:UpdateKnownPositionFor(ply)
    end
end

-- Setup the player states at the start of the round.
-- Automatically bounces attempt if round is not active
function Memory:SetupPlayerLifeStates()
    local ConfirmedDead = TTTBots.Match.ConfirmedDead
    local PlayersInRound = TTTBots.Match.PlayersInRound
    local RoundActive = TTTBots.Match.RoundActive
    if not RoundActive then return false end

    for ply, _ in pairs(PlayersInRound) do
        self:SetPlayerLifeState(ply, ConfirmedDead[ply] and DEAD or ALIVE)
    end
end

function Memory:GetPlayerLifeState(ply)
    return self.PlayerLifeStates[ply:Nick()]
end

function Memory:SetPlayerLifeState(ply, state)
    if not ply or type(ply) == "boolean" or not IsValid(ply) then return end
    local nick = (type(ply) == "string" and ply) or ply:Nick()
    self.PlayerLifeStates[nick] = state
end

function Memory:UpdatePlayerLifeStates()
    local CurrentlyAlive = lib.GetAlivePlayers()
    local ConfirmedDead = TTTBots.Match.ConfirmedDead
    local RoundActive = TTTBots.Match.RoundActive
    local PostRoundDM = TTTBots.Match.IsPostRoundDM()
    local isOmniscient = TTTBots.Roles.GetRoleFor(self.bot):GetKnowsLifeStates()
    local bot = self.bot

    if not RoundActive and not PostRoundDM then
        self.PlayerLifeStates = {}
        self:SetupPlayerLifeStates()
        return
    end

    -- Round is active but life-state memory may still be empty at round start.
    -- Seed once so KnownAlive isn't stuck at 0 until someone dies.
    if next(self.PlayerLifeStates) == nil then
        self:SetupPlayerLifeStates()
    end

    for plyname, value in pairs(ConfirmedDead) do
        self:SetPlayerLifeState(plyname, DEAD)
    end

    if isOmniscient then
        -- Traitors know who is dead and who is alive, so first set everyone to dead.
        for i, ply in pairs(player.GetAll()) do
            if ply == bot then continue end
            self:SetPlayerLifeState(ply, DEAD)
        end

        -- Then set everyone that is alive to alive.
        for i, ply in pairs(CurrentlyAlive) do
            if ply == bot then continue end
            self:SetPlayerLifeState(ply, ALIVE)
        end
    end
end

function Memory:SawPlayerRecently(ply)
    local pnp = self.playerKnownPositions[ply:Nick()]
    if not pnp then return false end
    return pnp.timeSince() < 5
end

function Memory:GetRecentlySeenPlayers(withinSecs)
    local withinSecs = withinSecs or 5
    local players = {}
    for i, ply in pairs(player.GetAll()) do
        if self:SawPlayerRecently(ply) then
            table.insert(players, ply)
        end
    end
    return players
end

--- Gets a list of positions of players that we have seen recently.
---@return table<Vector> positions [Player]=Vector
function Memory:GetKnownPlayersPos()
    local positions = {}
    for i, ply in pairs(player.GetAll()) do
        local pnp = self.playerKnownPositions[ply:Nick()]
        if not pnp then continue end
        positions[ply] = pnp.pos
    end
    return positions
end

--- Gets a list of every player we think is alive.
---@return table<Player> players
function Memory:GetKnownAlivePlayers()
    local players = {}
    for i, ply in pairs(player.GetAll()) do
        if self:GetPlayerLifeState(ply) == ALIVE then
            table.insert(players, ply)
        end
    end
    return players
end

--- Gets actually alive players irrespective of what we think.
---@return table<Player> players
function Memory:GetActualAlivePlayers()
    local players = {}
    for i, ply in pairs(player.GetAll()) do
        if lib.IsPlayerAlive(ply) then
            table.insert(players, ply)
        end
    end
    return players
end

function Memory:Think()
    self.tick = self.tick + 1

    self:UpdateKnownPositions()
    self:UpdatePlayerLifeStates()
    self:CullDangerZones()
end

--- Returns (and sets, if applicable) the hearing multiplier for this bot.
function Memory:GetHearingMultiplier()
    if self.HearingMultiplier then return self.HearingMultiplier end
    local bot = self.bot
    local mult = bot:GetTraitMult("hearing")

    self.HearingMultiplier = mult
    return mult
end

--- Returns a table of the recent sounds emitted by a player or an entity owned by a player.
---@param ply Player The player to get the recent sounds of.
---@return table<table> sounds
function Memory:GetRecentSoundsFromPly(ply)
    local sounds = {}
    for i, sound in pairs(self.recentSounds) do
        if sound.ply == ply then
            table.insert(sounds, sound)
        end
    end
    return sounds
end

--- Record that this bot has visited the given nav area.
---@param navArea CNavArea
function Memory:RecordNavVisit(navArea)
    if not IsValid(navArea) then return end
    self.visitedNavAreas[navArea:GetID()] = CurTime()
end

--- Returns true if the bot has visited this nav area within the last `withinSecs` seconds (default 90).
---@param navArea CNavArea
---@param withinSecs number?
---@return boolean
function Memory:HasVisitedNavRecently(navArea, withinSecs)
    if not IsValid(navArea) then return false end
    withinSecs = withinSecs or 90
    local t = self.visitedNavAreas[navArea:GetID()]
    if not t then return false end
    return (CurTime() - t) < withinSecs
end

--- Returns true if the given position is in a known danger zone (recent kill nearby).
---@param pos Vector
---@return boolean
function Memory:IsDangerZone(pos)
    for _, zone in ipairs(self.dangerZones or {}) do
        local radius = zone.radius or 400
        if pos:Distance(zone.pos) < radius then
            return true
        end
    end
    return false
end

--- Record a danger zone at the given position.
---@param pos Vector
---@param radius number|nil   Danger radius in units (default 400)
---@param label  string|nil   Optional identifier tag (default "generic")
---@param expiry number|nil   CurTime() at which this zone expires (default CurTime()+120)
function Memory:AddDangerZone(pos, radius, label, expiry)
    radius = radius or 400
    label  = label  or "generic"
    expiry = expiry or (CurTime() + 120)
    self.dangerZones = self.dangerZones or {}
    -- Avoid duplicates within the zone's radius
    for _, zone in ipairs(self.dangerZones) do
        if zone.pos:Distance(pos) < radius then
            zone.time   = CurTime()
            zone.expiry = expiry
            zone.radius = radius
            zone.label  = label
            return
        end
    end
    table.insert(self.dangerZones, { pos = pos, time = CurTime(), radius = radius, label = label, expiry = expiry })
end

--- Prune danger zones that have passed their expiry time.
function Memory:CullDangerZones()
    if not self.dangerZones then return end
    local now   = CurTime()
    local fresh = {}
    for _, zone in ipairs(self.dangerZones) do
        local exp = zone.expiry or (zone.time + 120)
        if now < exp then
            table.insert(fresh, zone)
        end
    end
    self.dangerZones = fresh
end

function Memory:GetHeardC4Sounds()
    local sounds = {}
    for i, sound in pairs(self.recentSounds) do
        if sound.sound == "C4Beep" then
            table.insert(sounds, sound)
        end
    end
    return sounds
end

--- Handles incoming sounds.
--- Determines if the bot can hear the noise, then adds it to the components sound memory.
---@param info SoundInfo My custom sound info table.
---@param soundData table The original GLua sound table.
---@return boolean IsUseful Whether or not the sound was useful, basically false if did not hear.
function Memory:HandleSound(info, soundData)
    local bot = self.bot ---@type Bot
    local soundPos = info.Pos
    assert(soundPos, "Sound position is nil")
    local standardRange = info.Distance
    local botHearingMult = self:GetHearingMultiplier()

    local distTo = bot:GetPos():Distance(soundPos)
    local canHear = distTo <= standardRange * botHearingMult

    if not canHear then
        return false
    end

    local tbl = {
        time = CurTime(),
        sound = info.SoundName,
        pos = soundPos,
        info = info,
        ent = info.EntInfo.Entity or info.EntInfo.Owner,
        sourceIsPly = info.EntInfo.EntityIsPlayer or info.EntInfo.OwnerIsPlayer,
        ply = (info.EntInfo.EntityIsPlayer and info.EntInfo.Entity) or
            (info.EntInfo.OwnerIsPlayer and info.EntInfo.Owner),
        soundData = soundData,
        dist = distTo,
    }
    if tbl.ply == bot then return false end
    -- if tbl.dist > 600 and not bot:VisibleVec(tbl.pos) then
    --     tbl.ply = nil -- scrub the player if they are too far away and not visible for balancing reasons
    -- end
    table.insert(self.recentSounds, tbl)

    local pressureHash = {
        ["Gunshot"] = "HearGunshot",
        ["Death"] = "HearDeath",
        ["Explosion"] = "HearExplosion",
    }
    local hashedName = pressureHash[info.SoundName]
    if hashedName then
        local personality = bot:BotPersonality()
        personality:OnPressureEvent(hashedName)
    end

    return true
end

--- Automatically culls old sounds from self.recentSounds
function Memory:CullSoundMemory()
    local recentSounds = self.recentSounds
    if not recentSounds then return end
    local curTime = CurTime()
    for i, sound in ipairs(recentSounds) do
        local timeSince = curTime - sound.time
        if timeSince > 5 then
            table.remove(recentSounds, i)
        elseif timeSince > 0.5 and lib.CanSeeArc(self.bot, sound.pos, 75) then
            table.remove(recentSounds, i) -- we don't need to remember sounds that we can see the source of
        end
    end
end

--[[
    time
    sound -- soundname, e.g. "Gunshot"
    pos -- vec3
    info -- soundinfo
    ent -- ent|nil
    sourceIsPly -- bool
    ply -- player|nil
    soundData -- glua sound table
    dist -- number
]]
---@return table<table> recentSounds
function Memory:GetRecentSounds()
    return self.recentSounds
end

timer.Create("TTTBots_CullSoundMemory", 1, 0, function()
    for i, v in pairs(TTTBots.Bots) do
        if not (v and v.components and v.components.memory) then continue end
        v.components.memory:CullSoundMemory()
    end
end)

--- Executes :HandleSound for every living bot in the game.
---@param info SoundInfo
---@param soundData table
function Memory.HandleSoundForAllBots(info, soundData)
    for i, v in pairs(TTTBots.Bots) do
        if not lib.IsPlayerAlive(v) then continue end
        if not (v and v.components and v.components.memory) then continue end
        local mem = v.components.memory

        -- local hasAgent = info.EntInfo.Entity or info.EntInfo.Owner
        -- if not hasAgent then continue end

        mem:HandleSound(info, soundData)
    end
end

---@class SoundInfo My custom sound info table.
---@field SoundName string The category of the sound.
---@field FoundKeyword string The keyword that was found in the sound name.
---@field Distance number The standard detection distance for this sound.
---@field Pos Vector|nil The position of the sound, if any.
---@field EntInfo SoundEntInfo The entity info table of the sound, if any.
---@class SoundEntInfo Sound entity info table inside of the SoundInfo table.
---@field Entity Entity|nil The entity that made the sound, if any.
---@field EntityIsPlayer boolean|nil Whether or not the entity is a player.
---@field OwnerIsPlayer boolean|nil Whether or not the owner of the entity is a player.
---@field Class string|nil The class of the entity.
---@field Name string|nil The name of the entity.
---@field Nick string|nil The nick of the entity, if it is a player.
---@field Owner Entity|nil The owner of the entity, if any.

local function findFirstKeyword(str, keywordTbl)
    for i, keyword in pairs(keywordTbl) do
        if string.find(str, keyword) then
            return keyword
        end
    end
    return nil
end

-- GM:EntityEmitSound(table data)
hook.Add("EntityEmitSound", "TTTBots.EntityEmitSound", function(data)
    local MODULE_ENABLED = lib.GetConVarBool("noise_enable")
    if not MODULE_ENABLED then return end

    -- TTTBots.DebugServer.DrawCross(data.Pos, 5, Color(0, 0, 0), 1)
    local sn = data.SoundName
    local f = string.find

    if not (IsValid(data.Entity)) then return end

    for k, v in pairs(TTTBots.Sound.DetectionInfo) do
        local keywords = v.Keywords

        local keyword = findFirstKeyword(sn, keywords)
        local blacklistKeyword = findFirstKeyword(sn, TTTBots.Sound.SoundBlacklist)

        if blacklistKeyword then return end -- Don't process blacklisted sounds.
        if not keyword then continue end

        Memory.HandleSoundForAllBots(
            {
                SoundName = k,
                FoundKeyword = keyword,
                Distance = v.Distance,
                Pos = data.Pos or (data.Entity:GetPos()),
                EntInfo = {
                    Entity = data.Entity,
                    EntityIsPlayer = data.Entity:IsPlayer(),
                    OwnerIsPlayer = data.Entity:GetOwner() and data.Entity:GetOwner():IsPlayer(),
                    Class = data.Entity:GetClass(),
                    Name = data.Entity:GetName(),
                    Nick = data.Entity:IsPlayer() and data.Entity:Nick(),
                    Owner = data.Entity:GetOwner(),
                }
            },
            data
        )
        return
    end

    -- print("Unknown sound: " .. sn)
end)


-- ===========================================================================
-- Location-based reasoning hooks
-- ===========================================================================

if SERVER then
    -- When a body is found, check which players were last seen near that location
    -- and generate NEAR_BODY evidence against them.
    hook.Add("TTTBodyFound", "TTTBots.Memory.NearBodyReasoning", function(discoverer, deceased, ragdoll)
        if not TTTBots.Match.RoundActive then return end
        if not (IsValid(deceased) and deceased:IsPlayer()) then return end
        local corpsePos = deceased:GetPos()
        -- Find the estimated death time: look for the most recent damage log entry for this player
        local deathTime = CurTime()
        for _, log in ipairs(TTTBots.Match.DamageLogs or {}) do
            if log.victim == deceased and log.time > (deathTime - 120) then
                deathTime = math.max(deathTime, log.time)
            end
        end

        -- For each alive bot that uses suspicion, check who was near the corpse around death time
        for _, bot in ipairs(TTTBots.Bots or {}) do
            if not (IsValid(bot) and bot.components and bot.components.memory) then continue end
            if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then continue end
            local mem = bot.components.memory
            local evidence = bot:BotEvidence()
            if not evidence then continue end

            -- Check all players we have position records for
            for nick, pnp in pairs(mem.playerKnownPositions) do
                local ply = pnp.ply
                if not (IsValid(ply) and ply:IsPlayer()) then continue end
                if ply == deceased then continue end
                if ply == bot then continue end
                -- Check if last-seen position was within 700 units of the corpse
                -- AND the last-seen time was within ±20 seconds of death time
                local dist = pnp.pos:Distance(corpsePos)
                local timeDiff = math.abs(pnp.time - deathTime)
                if dist < 700 and timeDiff < 20 then
                    local navArea = navmesh.GetNearestNavArea(corpsePos)
                    local location = (navArea and navArea.GetPlace and navArea:GetPlace() ~= "") and navArea:GetPlace() or "unknown"
                    evidence:AddEvidence({
                        type     = "NEAR_BODY",
                        subject  = ply,
                        detail   = string.format("was near %s around time of death", location),
                        location = location,
                    })
                end
            end
        end
    end)

    -- When a player dies, record danger zone in all living bot memories
    hook.Add("PlayerDeath", "TTTBots.Memory.DangerZone", function(victim, weapon, attacker)
        if not TTTBots.Match.RoundActive then return end
        if not (IsValid(victim) and victim:IsPlayer()) then return end
        local deathPos = victim:GetPos()
        for _, bot in ipairs(TTTBots.Bots or {}) do
            if not (IsValid(bot) and bot.components and bot.components.memory) then continue end
            bot.components.memory:AddDangerZone(deathPos)
        end
    end)

    -- Suspicious movement: if a player emerges from the direction of recent gunshots,
    -- generate SUSPICIOUS_MOVEMENT evidence.
    timer.Create("TTTBots.Memory.SuspiciousMovement", 2, 0, function()
        if not TTTBots.Match.RoundActive then return end

        for _, bot in ipairs(TTTBots.Bots or {}) do
            if not (IsValid(bot) and bot.components and bot.components.memory) then continue end
            if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then continue end
            local mem = bot.components.memory
            local evidence = bot:BotEvidence()
            if not evidence then continue end

            -- Get recent gunshot sounds this bot heard
            local gunshots = {}
            for _, snd in ipairs(mem.recentSounds) do
                if snd.sound == "Gunshot" then
                    table.insert(gunshots, snd)
                end
            end
            if #gunshots == 0 then continue end

            -- For each known player position, check if they appear to be moving FROM a gunshot area
            for nick, pnp in pairs(mem.playerKnownPositions) do
                local ply = pnp.ply
                if not (IsValid(ply) and ply:IsPlayer()) then continue end
                if ply == bot then continue end
                -- Check distance from player's last-known pos to any gunshot position
                for _, snd in ipairs(gunshots) do
                    local distFromShot = pnp.pos:Distance(snd.pos)
                    -- Player was within 400 units of the gunshot sound location recently
                    if distFromShot < 400 and (CurTime() - snd.time) < 10 then
                        evidence:AddEvidence({
                            type    = "SUSPICIOUS_MOVEMENT",
                            subject = ply,
                            detail  = "emerged from direction of recent gunshots",
                        })
                        break  -- one entry per player per sweep
                    end
                end
            end
        end
    end)
end

-- Track door activity for camping detection
hook.Add("PlayerUse", "TTTBots_Memory_DoorCamping", function(ply, ent)
	if not IsValid(ent) then return end
	local class = ent:GetClass()
	if class ~= "func_door" and class ~= "func_door_rotating" and class ~= "prop_door_rotating" then return end

	local idx = ent:EntIndex()
	Memory.DoorActivityLog[idx] = Memory.DoorActivityLog[idx] or { uses = 0, lastActivity = 0, usersNearby = {} }
	local log = Memory.DoorActivityLog[idx]

	-- Reset counters if the activity window has expired
	if CurTime() - log.lastActivity > Memory.DOOR_CAMP_WINDOW then
		log.uses = 0
		log.usersNearby = {}
	end

	log.uses = log.uses + 1
	log.lastActivity = CurTime()

	-- Track who's nearby
	if IsValid(ply) and not table.HasValue(log.usersNearby, ply) then
		table.insert(log.usersNearby, ply)
	end
end)

--- Check if a door entity has suspicious activity (door camping).
---@param doorEnt Entity
---@return boolean
function Memory.IsDoorSuspicious(doorEnt)
	if not IsValid(doorEnt) then return false end
	local idx = doorEnt:EntIndex()
	local log = Memory.DoorActivityLog[idx]
	if not log then return false end

	-- Window expired?
	if CurTime() - log.lastActivity > Memory.DOOR_CAMP_WINDOW then return false end

	return log.uses >= Memory.DOOR_CAMP_THRESHOLD
end

-- Clean up old entries periodically
timer.Create("TTTBots_Memory_DoorActivityCleanup", 30, 0, function()
	local now = CurTime()
	for idx, log in pairs(Memory.DoorActivityLog) do
		if now - log.lastActivity > Memory.DOOR_CAMP_WINDOW * 3 then
			Memory.DoorActivityLog[idx] = nil
		end
	end
end)

-- Clear door activity between rounds
hook.Add("TTTEndRound", "TTTBots.Memory.ClearDoorActivity", function()
    Memory.DoorActivityLog = {}
end)

---@class Bot
local plyMeta = FindMetaTable("Player")
function plyMeta:BotMemory()
    return self.components and self.components.memory
end
