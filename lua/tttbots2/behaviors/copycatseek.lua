--- copycatseek.lua
--- Dedicated corpse-seeking behavior for Copycat bots.
--- Similar to AmnesiacSeek, but instead of converting on search, the Copycat
--- transcribes the corpse's role into the Copycat Files collection.
--- The addon's TTTCanSearchCorpse hook handles the transcription automatically
--- when the bot searches a corpse while holding weapon_ttt2_copycat_files.
---
--- Key differences from AmnesiacSeek:
---   1. Does NOT convert the bot on search — only adds to the collection
---   2. Prioritizes corpses whose roles haven't been transcribed yet
---   3. No randomness gate — this is the Copycat's primary objective
---   4. Only runs while the bot is still in the base Copycat subrole

if not (TTT2 and ROLE_COPYCAT) then return end

---@class CopycatSeek
TTTBots.Behaviors.CopycatSeek = {}

local lib = TTTBots.Lib

---@class CopycatSeek
local CopycatSeek = TTTBots.Behaviors.CopycatSeek
CopycatSeek.Name = "CopycatSeek"
CopycatSeek.Description = "Seek and search corpses to transcribe roles into the Copycat Files"
CopycatSeek.Interruptible = true

local STATUS = TTTBots.STATUS

--- Maximum distance to consider a corpse as a candidate.
local SEEK_MAXDIST = 6000

--- Interaction distance to initiate corpse search.
local INTERACT_DIST = 80

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Track which roles this bot has already transcribed (server-side cache).
--- The addon tracks this in COPYCAT_FILES_DATA, but we maintain our own
--- lightweight mirror for decision-making.
---@param bot Player
---@return table roleSet  Set of ROLE_* indices that have been transcribed
local function getCollectedRoles(bot)
    if not bot._copycatCollectedRoles then
        bot._copycatCollectedRoles = {}
    end

    -- Sync from addon data if available
    if COPYCAT_FILES_DATA and bot.SteamID64 and bot:SteamID64() then
        local addonData = COPYCAT_FILES_DATA[bot:SteamID64()]
        if addonData then
            for roleId, state in pairs(addonData) do
                if state ~= nil and roleId ~= ROLE_COPYCAT then
                    bot._copycatCollectedRoles[roleId] = true
                end
            end
        end
    end

    return bot._copycatCollectedRoles
end

--- Returns whether a ragdoll is a valid target for the Copycat to search.
---@param bot Player
---@param rag Entity
---@return boolean
local function isValidCopycatTarget(bot, rag)
    if not IsValid(rag) then return false end
    if not lib.IsValidBody(rag) then return false end

    -- Prefer corpses whose roles we haven't transcribed yet
    local collected = getCollectedRoles(bot)
    local corpseRole = rag.was_role
    if corpseRole and collected[corpseRole] then
        -- Already have this role — lower priority but still searchable for confirmation
        return false
    end

    return true
end

--- Returns whether ANY corpse is available (even already-transcribed ones).
--- Used as a fallback when all new roles are collected.
---@param rag Entity
---@return boolean
local function isAnyValidCorpse(rag)
    if not IsValid(rag) then return false end
    if not lib.IsValidBody(rag) then return false end
    return true
end

--- Get all corpses that are valid Copycat targets.
---@param bot Player
---@return table validCorpses
local function getCopycatCorpseCandidates(bot)
    local corpses = TTTBots.Match.Corpses
    local candidates = {}
    local botPos = bot:GetPos()

    for _, corpse in pairs(corpses) do
        if not isValidCopycatTarget(bot, corpse) then continue end

        local dist = botPos:Distance(corpse:GetPos())
        if dist > SEEK_MAXDIST then continue end

        table.insert(candidates, corpse)
    end

    -- If no new-role corpses, fall back to any unconfirmed corpse
    -- (still useful for evidence and policing duty)
    if #candidates == 0 then
        for _, corpse in pairs(corpses) do
            if not isAnyValidCorpse(corpse) then continue end
            local found = CORPSE.GetFound(corpse, false)
            if found then continue end

            local dist = botPos:Distance(corpse:GetPos())
            if dist > SEEK_MAXDIST then continue end

            table.insert(candidates, corpse)
        end
    end

    return candidates
end

--- Select the best corpse candidate for the Copycat bot.
---@param bot Player
---@param candidates table
---@return Entity|nil bestCorpse
local function selectBestCorpse(bot, candidates)
    if #candidates == 0 then return nil end

    local botPos = bot:GetPos()
    local alivePlayers = TTTBots.Match.AlivePlayers or {}
    local collected = getCollectedRoles(bot)
    local bestCorpse = nil
    local bestScore = -math.huge

    for _, corpse in ipairs(candidates) do
        local corpsePos = corpse:GetPos()
        local dist = botPos:Distance(corpsePos)

        -- Base score: inversely proportional to distance
        local score = 10000 - dist

        -- Visibility bonus
        if bot:Visible(corpse) then
            score = score + 2000
        end

        -- New role bonus: strongly prefer corpses with roles we don't have yet
        local corpseRole = corpse.was_role
        if corpseRole and not collected[corpseRole] then
            score = score + 5000
        end

        -- Isolation bonus: fewer nearby players = safer to search
        local nearbyCount = 0
        for _, ply in ipairs(alivePlayers) do
            if IsValid(ply) and ply ~= bot and ply:GetPos():Distance(corpsePos) < 500 then
                nearbyCount = nearbyCount + 1
            end
        end
        score = score + (500 - nearbyCount * 150)

        if score > bestScore then
            bestScore = score
            bestCorpse = corpse
        end
    end

    return bestCorpse
end

-- ---------------------------------------------------------------------------
-- Behavior Lifecycle
-- ---------------------------------------------------------------------------

--- Validate: only runs while the bot is still in the base Copycat subrole.
---@param bot Player
---@return boolean
function CopycatSeek.Validate(bot)
    if not ROLE_COPYCAT then return false end
    if bot:GetSubRole() ~= ROLE_COPYCAT then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- If we already have a target in progress, keep going
    local state = TTTBots.Behaviors.GetState(bot, "CopycatSeek")
    if state.target and isAnyValidCorpse(state.target) then
        return true
    end

    -- Find a new target
    local candidates = getCopycatCorpseCandidates(bot)
    if #candidates == 0 then return false end

    local best = selectBestCorpse(bot, candidates)
    if not best then return false end

    state.target = best
    return true
end

--- Called when the behavior starts.
---@param bot Player
---@return BStatus
function CopycatSeek.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "CopycatSeek")

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        local name = state.target and CORPSE.GetPlayerNick(state.target) or "someone"
        chatter:On("CopycatSeekingCorpse", { corpse = name })
    end

    return STATUS.RUNNING
end

--- Called each tick while running.
---@param bot Player
---@return BStatus
function CopycatSeek.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "CopycatSeek")
    local target = state.target

    -- Verify target is still valid
    if not isAnyValidCorpse(target) then
        return STATUS.FAILURE
    end

    -- Check if bot is still in the base Copycat subrole
    if bot:GetSubRole() ~= ROLE_COPYCAT then
        return STATUS.SUCCESS
    end

    local loco = bot:BotLocomotor()
    local corpsePos = target:GetPos()
    loco:LookAt(corpsePos)
    loco:SetGoal(corpsePos)

    local distToBody = lib.DistanceXY(bot:GetPos(), corpsePos)
    if distToBody < INTERACT_DIST then
        loco:StopMoving()

        -- Perform the corpse search — the addon's TTTCanSearchCorpse hook
        -- handles transcribing the role into the Copycat Files automatically.
        CORPSE.ShowSearch(bot, target, false, false)
        CORPSE.SetFound(target, true)

        -- Update our local tracking of collected roles
        local corpseRole = target.was_role
        if corpseRole then
            local collected = getCollectedRoles(bot)
            collected[corpseRole] = true

            local chatter = bot:BotChatter()
            if chatter and chatter.On then
                local roleName = roles and roles.GetByIndex and roles.GetByIndex(corpseRole)
                local roleStr = roleName and roleName.name or "unknown"
                chatter:On("CopycatTranscribed", { role = roleStr })
            end
        end

        return STATUS.SUCCESS
    end

    return STATUS.RUNNING
end

--- Called on success.
---@param bot Player
function CopycatSeek.OnSuccess(bot)
end

--- Called on failure.
---@param bot Player
function CopycatSeek.OnFailure(bot)
end

--- Called when the behavior ends.
---@param bot Player
function CopycatSeek.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "CopycatSeek")
end
