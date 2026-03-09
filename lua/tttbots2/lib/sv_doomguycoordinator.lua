--- sv_doomguycoordinator.lua
--- Phase 4 — Doomguy-aware round coordinator.
---
--- This module hooks into round state to make ALL non-Doomguy bots react
--- intelligently to the Doom Slayer's presence.
---
--- Innocent-side reactions:
---   - Spot Doomguy → fire DoomguySpotted event on nearby bots.
---   - Doomguy killed someone visible → fire DoomguyKilledPlayer.
---   - Doomguy appears low health → fire DoomguyWeak (push window).
---   - Innocents increase group-up urgency while Doomguy is alive.
---   - Danger zones around Doomguy last-known position get a severity boost.
---
--- Traitor-side reactions:
---   - Traitors avoid engaging Doomguy directly when at low health.
---   - Traitors can exploit Doomguy-generated chaos for covers.
---
--- This file is auto-included by IncludeDirectory("tttbots2/lib").

local lib = TTTBots.Lib

TTTBots.DoomguyCoordinator = TTTBots.DoomguyCoordinator or {}
local DGC = TTTBots.DoomguyCoordinator

--- Cooldown tables to prevent event spam.
DGC._spottedCooldown    = {}  -- [bot] = last time we fired DoomguySpotted for that bot
DGC._weakCooldown       = 0   -- global, since "weak" is a round-state event
DGC._chasingCooldown    = {}  -- [bot] = last time we fired DoomguyChasingMe
DGC._killCooldown       = 0   -- global, per kill

local SPOTTED_COOLDOWN  = 12   -- seconds between DoomguySpotted fires per bot
local WEAK_COOLDOWN     = 10   -- seconds between DoomguyWeak fires (global)
local CHASING_COOLDOWN  = 8    -- seconds between DoomguyChasingMe fires per bot
local KILL_COOLDOWN     = 5    -- seconds between DoomguyKilledPlayer fires (global)
local DOOMGUY_WEAK_HP   = 50   -- HP threshold for considering Doomguy "weak"

--- Returns a table of all alive players with a Doomguy role.
---@return table<Player>
local function findAllLivingDoomguys()
    local results = {}
    for _, ply in ipairs(player.GetAll()) do
        if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end
        local roleStr = ply.GetRoleStringRaw and ply:GetRoleStringRaw() or ""
        if roleStr == "doomguy" or roleStr == "doomguy_blue" or roleStr == "doomguy_red" then
            results[#results + 1] = ply
        end
    end
    return results
end

--- Returns true if `bot` is a Doomguy variant.
---@param bot Bot
---@return boolean
local function isDoomguy(bot)
    if not IsValid(bot) then return false end
    local roleStr = bot.GetRoleStringRaw and bot:GetRoleStringRaw() or ""
    return (roleStr == "doomguy" or roleStr == "doomguy_blue" or roleStr == "doomguy_red")
end

--- Returns true if the role uses suspicion (innocent-team bots).
---@param bot Bot
---@return boolean
local function isInnocentTeam(bot)
    local rd = TTTBots.Roles and TTTBots.Roles.GetRoleFor(bot)
    return rd and rd.GetUsesSuspicion and rd:GetUsesSuspicion() or false
end

--- Returns true if the role is a traitor.
---@param bot Bot
---@return boolean
local function isTraitorTeam(bot)
    local rd = TTTBots.Roles and TTTBots.Roles.GetRoleFor(bot)
    return rd and rd.GetTeam and rd:GetTeam() == TEAM_TRAITOR or false
end

-- ---------------------------------------------------------------------------
-- Danger zone boost for Doomguy sightings
-- ---------------------------------------------------------------------------

--- Boost or refresh the danger zone around Doomguy's current position for all
--- bots.  Doomguy sightings should be treated with higher persistence/severity.
---@param doomguyPos Vector
local function boostDoomguyDangerZone(doomguyPos)
    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
        local memory = bot:BotMemory()
        if not memory then continue end
        -- AddDangerZone only exists on memory implementations that support it.
        if type(memory.AddDangerZone) == "function" then
            memory:AddDangerZone(doomguyPos, 800, "doomguy_sighting", CurTime() + 30)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Per-bot Doomguy reaction logic
-- ---------------------------------------------------------------------------

--- React to the Doomguy for an individual bot: fire chatter events, record
--- threat position in memory, update danger zones, etc.
---@param bot Bot
---@param doomguy Player
local function reactToSpotted(bot, doomguy)
    local timeNow = CurTime()
    local lastSpotted = DGC._spottedCooldown[bot] or 0
    if timeNow - lastSpotted < SPOTTED_COOLDOWN then return end
    DGC._spottedCooldown[bot] = timeNow

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        local delay = math.random() * 2.0  -- stagger so bots don't all speak at once
        chatter:On("DoomguySpotted", { player = doomguy:Nick() }, false, delay)
    end

    -- Record the sighting in memory using only the confirmed-available API.
    local memory = bot:BotMemory()
    if memory then
        if type(memory.RecordThreatSighting) == "function" then
            memory:RecordThreatSighting(doomguy, doomguy:GetPos())
        end
        if type(memory.SetKnownPosition) == "function" then
            memory:SetKnownPosition(doomguy, doomguy:GetPos())
        end
    end
end

--- React when we are being directly chased by Doomguy.
---@param bot Bot
---@param doomguy Player
local function reactToChasedByDoomguy(bot, doomguy)
    local timeNow = CurTime()
    local lastChasing = DGC._chasingCooldown[bot] or 0
    if timeNow - lastChasing < CHASING_COOLDOWN then return end
    DGC._chasingCooldown[bot] = timeNow

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("DoomguyChasingMe", { player = doomguy:Nick() }, false)
    end
end

-- ---------------------------------------------------------------------------
-- Main per-tick coordination loop
-- ---------------------------------------------------------------------------

--- Coordination tick — runs every 1.5 seconds.
--- Scans for living Doomguy, checks visibility from all bots, fires events.
local function coordinationTick()
    if not TTTBots.Match.IsRoundActive() then return end

    local doomguys = findAllLivingDoomguys()
    if #doomguys == 0 then return end

    local timeNow = CurTime()

    for _, doomguy in ipairs(doomguys) do
        if not IsValid(doomguy) then continue end

        local dgPos = doomguy:GetPos()
        local dgHP  = doomguy:Health()

        -- Boost danger zone around each Doomguy's current position.
        boostDoomguyDangerZone(dgPos)

        -- Check if this Doomguy is "weak" (low HP) — fire push event globally.
        if dgHP < DOOMGUY_WEAK_HP and (timeNow - DGC._weakCooldown) > WEAK_COOLDOWN then
            DGC._weakCooldown = timeNow
            for _, bot in ipairs(TTTBots.Bots or {}) do
                if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
                if isDoomguy(bot) then continue end
                if not bot:Visible(doomguy) then continue end
                local chatter = bot:BotChatter()
                if chatter and chatter.On then
                    local delay = math.random() * 1.5
                    chatter:On("DoomguyWeak", { player = doomguy:Nick() }, false, delay)
                end
            end
        end

        -- Per-bot visibility reactions.
        for _, bot in ipairs(TTTBots.Bots or {}) do
            if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
            if isDoomguy(bot) then continue end

            local canSee = bot:Visible(doomguy)

            if canSee then
                reactToSpotted(bot, doomguy)
            end

            -- Chasing reaction: Doomguy has bot as attack target and is close.
            local isDoomguyChasing = (doomguy.attackTarget == bot) and (dgPos:Distance(bot:GetPos()) < 600)
            if isDoomguyChasing then
                reactToChasedByDoomguy(bot, doomguy)
            end

            -- Traitor-team: if at low health, avoid this Doomguy.
            if isTraitorTeam(bot) and bot:Health() < 40 then
                if IsValid(bot.attackTarget) and bot.attackTarget == doomguy then
                    bot:SetAttackTarget(nil, "DOOMGUY_COORD_RETREAT")
                end
            end
        end
    end

    -- Innocent-team: set a memory flag that a Doomguy is alive (once per tick, not per-doomguy).
    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
        if not isInnocentTeam(bot) then continue end
        local memory = bot:BotMemory()
        if memory and memory.SetFlag then
            memory:SetFlag("doomguy_alive", true)
        end
    end
end

timer.Create("TTTBots.DoomguyCoordinator.Tick", 1.5, 0, coordinationTick)

-- ---------------------------------------------------------------------------
-- PlayerDeath hook — fire DoomguyKilledPlayer when Doomguy gets a kill
-- ---------------------------------------------------------------------------

hook.Add("PlayerDeath", "TTTBots.DoomguyCoordinator.KillReaction", function(victim, inflictor, attacker)
    if not (IsValid(victim) and IsValid(attacker)) then return end
    if not attacker:IsPlayer() then return end

    -- Only care if Doomguy did the killing.
    local attackerRole = attacker.GetRoleStringRaw and attacker:GetRoleStringRaw() or ""
    if attackerRole ~= "doomguy" and attackerRole ~= "doomguy_blue" and attackerRole ~= "doomguy_red" then return end

    local timeNow = CurTime()
    if timeNow - DGC._killCooldown < KILL_COOLDOWN then return end
    DGC._killCooldown = timeNow

    -- Fire on all bots that can see the victim's death position.
    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
        if isDoomguy(bot) then continue end
        if not bot:Visible(victim) and bot:GetPos():Distance(victim:GetPos()) > 1200 then continue end

        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            local delay = math.random() * 2.0
            chatter:On("DoomguyKilledPlayer", { player = victim:Nick() }, false, delay)
        end

        -- Add memory entry so bots treat the kill location as dangerous.
        local memory = bot:BotMemory()
        if memory and type(memory.AddDangerZone) == "function" then
            memory:AddDangerZone(victim:GetPos(), 600, "doomguy_kill", CurTime() + 25)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Round cleanup
-- ---------------------------------------------------------------------------

hook.Add("TTTEndRound", "TTTBots.DoomguyCoordinator.Cleanup", function()
    DGC._spottedCooldown = {}
    DGC._weakCooldown    = 0
    DGC._chasingCooldown = {}
    DGC._killCooldown    = 0
end)

hook.Add("TTTBeginRound", "TTTBots.DoomguyCoordinator.RoundStart", function()
    DGC._spottedCooldown = {}
    DGC._weakCooldown    = 0
    DGC._chasingCooldown = {}
    DGC._killCooldown    = 0
end)
