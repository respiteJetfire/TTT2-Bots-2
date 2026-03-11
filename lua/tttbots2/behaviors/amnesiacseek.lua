--- amnesiacseek.lua
--- Dedicated corpse-seeking behavior for Amnesiac bots.
--- Unlike InvestigateCorpse, this behavior:
---   1. Has NO random dice roll — always validates when corpses are available
---   2. Respects ttt2_amnesiac_limit_to_unconfirmed convar
---   3. Uses radar-known corpse positions for non-visible corpse awareness
---   4. Has urgency scaling based on round phase / personality
---   5. Runs at higher priority than InvestigateCorpse in the Amnesiac tree
---
--- The search mechanism is the same (CORPSE.ShowSearch), so the addon's
--- TTTCanSearchCorpse hook handles role conversion automatically.

if not (TTT2 and ROLE_AMNESIAC) then return end

---@class AmnesiacSeek
TTTBots.Behaviors.AmnesiacSeek = {}

local lib = TTTBots.Lib

---@class AmnesiacSeek
local AmnesiacSeek = TTTBots.Behaviors.AmnesiacSeek
AmnesiacSeek.Name = "AmnesiacSeek"
AmnesiacSeek.Description = "Seek and search corpses to acquire a role (Amnesiac)"
AmnesiacSeek.Interruptible = true

local STATUS = TTTBots.STATUS

--- Maximum distance to consider a corpse as a candidate.
local SEEK_MAXDIST = 6000

--- Interaction distance to initiate corpse search.
local INTERACT_DIST = 80

-- ---------------------------------------------------------------------------
-- Convar helpers
-- ---------------------------------------------------------------------------

--- Returns true if the amnesiac is limited to unconfirmed corpses only.
---@return boolean
local function isLimitedToUnconfirmed()
    local cv = GetConVar("ttt2_amnesiac_limit_to_unconfirmed")
    return cv and cv:GetBool() or true
end

-- ---------------------------------------------------------------------------
-- Corpse candidate gathering
-- ---------------------------------------------------------------------------

--- Returns whether a ragdoll is a valid target for the Amnesiac to search.
---@param rag Entity
---@return boolean
local function isValidAmnesiacTarget(rag)
    if not IsValid(rag) then return false end
    if not lib.IsValidBody(rag) then return false end

    -- Check if the corpse is already confirmed (found)
    local found = CORPSE.GetFound(rag, false)
    if found and isLimitedToUnconfirmed() then return false end

    return true
end

--- Get all corpses from the match corpse list that are valid Amnesiac targets.
--- Includes both visible and non-visible corpses (Amnesiac has radar awareness).
---@param bot Bot
---@return table validCorpses
local function getAmnesiacCorpseCandidates(bot)
    local corpses = TTTBots.Match.Corpses
    local candidates = {}
    local botPos = bot:GetPos()

    for _, corpse in pairs(corpses) do
        if not isValidAmnesiacTarget(corpse) then continue end

        local dist = botPos:Distance(corpse:GetPos())
        if dist > SEEK_MAXDIST then continue end

        table.insert(candidates, corpse)
    end

    return candidates
end

--- Select the best corpse candidate for the Amnesiac bot.
--- Scoring: closer corpses are preferred; isolated corpses get a bonus.
---@param bot Bot
---@param candidates table
---@return Entity|nil bestCorpse
local function selectBestCorpse(bot, candidates)
    if #candidates == 0 then return nil end

    local botPos = bot:GetPos()
    local alivePlayers = TTTBots.Match.AlivePlayers or {}
    local bestCorpse = nil
    local bestScore = -math.huge

    for _, corpse in ipairs(candidates) do
        local corpsePos = corpse:GetPos()
        local dist = botPos:Distance(corpsePos)

        -- Base score: inversely proportional to distance
        local score = 10000 - dist

        -- Visibility bonus: prefer corpses we can actually see
        if bot:Visible(corpse) then
            score = score + 2000
        end

        -- Isolation bonus: corpses far from other players are safer to search
        local nearbyCount = 0
        for _, ply in ipairs(alivePlayers) do
            if IsValid(ply) and ply ~= bot and ply:GetPos():Distance(corpsePos) < 500 then
                nearbyCount = nearbyCount + 1
            end
        end
        -- Fewer nearby players = higher score (safer to search)
        score = score + (500 - nearbyCount * 150)

        if score > bestScore then
            bestScore = score
            bestCorpse = corpse
        end
    end

    return bestCorpse
end

-- ---------------------------------------------------------------------------
-- Behavior lifecycle
-- ---------------------------------------------------------------------------

--- Validate: only runs while the bot is still Amnesiac AND corpse targets exist.
--- NO dice roll — this is the Amnesiac's primary objective.
---@param bot Bot
---@return boolean
function AmnesiacSeek.Validate(bot)
    -- Must be Amnesiac
    if not ROLE_AMNESIAC then return false end
    if bot:GetSubRole() ~= ROLE_AMNESIAC then return false end

    -- If we already have a valid target in progress, keep going (no re-roll)
    local state = TTTBots.Behaviors.GetState(bot, "AmnesiacSeek")
    if state.target and isValidAmnesiacTarget(state.target) then
        return true
    end

    -- Find a new target
    local candidates = getAmnesiacCorpseCandidates(bot)
    if #candidates == 0 then return false end

    local best = selectBestCorpse(bot, candidates)
    if not best then return false end

    state.target = best
    return true
end

--- Called when the behavior starts.
---@param bot Bot
---@return BStatus
function AmnesiacSeek.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "AmnesiacSeek")

    -- Fire seeking chatter
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        local name = state.target and CORPSE.GetPlayerNick(state.target) or "someone"
        chatter:On("AmnesiacSeekingCorpse", { corpse = name })
    end

    return STATUS.RUNNING
end

--- Called each tick while running.
---@param bot Bot
---@return BStatus
function AmnesiacSeek.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "AmnesiacSeek")
    local target = state.target

    -- Verify target is still valid
    if not isValidAmnesiacTarget(target) then
        return STATUS.FAILURE
    end

    -- Check if bot is still Amnesiac (conversion may have happened)
    if bot:GetSubRole() ~= ROLE_AMNESIAC then
        return STATUS.SUCCESS
    end

    local loco = bot:BotLocomotor()
    local corpsePos = target:GetPos()
    loco:LookAt(corpsePos)
    loco:SetGoal(corpsePos)

    -- Use XY distance so minor Z differences from ragdoll physics don't
    -- prevent the bot from reaching the interaction threshold.
    local distToBody = lib.DistanceXY(bot:GetPos(), corpsePos)
    if distToBody < INTERACT_DIST then
        loco:StopMoving()

        -- Perform the corpse search — the addon's TTTCanSearchCorpse hook
        -- handles the role conversion automatically.
        CORPSE.ShowSearch(bot, target, false, false)

        -- Only set found if the convar allows confirmation
        local confirmConvar = GetConVar("ttt2_amnesiac_confirm_player")
        if confirmConvar and confirmConvar:GetBool() then
            CORPSE.SetFound(target, true)
        end

        return STATUS.SUCCESS
    end

    return STATUS.RUNNING
end

--- Called on success.
---@param bot Bot
function AmnesiacSeek.OnSuccess(bot)
end

--- Called on failure.
---@param bot Bot
function AmnesiacSeek.OnFailure(bot)
end

--- Called when the behavior ends (success, failure, or interruption).
---@param bot Bot
function AmnesiacSeek.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "AmnesiacSeek")
end
