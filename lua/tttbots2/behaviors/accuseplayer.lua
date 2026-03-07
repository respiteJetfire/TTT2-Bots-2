--- accuseplayer.lua
--- AccusePlayer Behavior — Evidence-driven player accusation.
---
--- Priority: "Accuse" group (between Chatter and FightBack)
---
--- Validate: bot has enough evidence weight against a suspect, is not in combat,
---           hasn't accused this player recently, and personality allows it.
--- OnStart:  Look at suspect, choose accusation tier (KOS / sus / soft).
--- OnRunning: Request role-checker test; escalate / retract based on responses.

---@class AccusePlayer
TTTBots.Behaviors.AccusePlayer = {}

local lib = TTTBots.Lib
---@class AccusePlayer
local AccusePlayer = TTTBots.Behaviors.AccusePlayer
AccusePlayer.Name         = "AccusePlayer"
AccusePlayer.Description  = "Accuse a player based on gathered evidence"
AccusePlayer.Interruptible = true

local STATUS = TTTBots.STATUS

-- ===========================================================================
-- Internal helpers
-- ===========================================================================

--- Return the accusation threshold for this bot, modulated by archetype/traits.
---@param bot Bot
---@return number
local function getAccuseThreshold(bot)
    local personality = bot:BotPersonality()
    if not personality then return lib.GetConVarInt("evidence_accuse_threshold") or 7 end
    local archetype = personality:GetClosestArchetype()
    local A = TTTBots.Archetypes
    local base = lib.GetConVarInt("evidence_accuse_threshold") or 7

    -- Lower threshold → accuses more readily
    if archetype == A.Hothead or archetype == A.Sus then return math.max(base - 3, 2) end
    -- Higher threshold → only accuses on strong evidence
    if archetype == A.Nice or archetype == A.Teamer then return base + 3 end
    if archetype == A.Dumb then return math.max(base - 2, 2) end  -- dumb bots accuse inaccurately but readily
    return base
end

--- Pick the best suspect based on evidence weight and alibi status.
--- Returns the top suspect whose weight exceeds threshold, or nil.
---@param bot Bot
---@param threshold number
---@return Player|nil
local function pickBestSuspect(bot, threshold)
    local evidence = bot:BotEvidence()
    if not evidence then return nil end

    local suspects = evidence:GetSuspects(threshold)
    if not suspects or #suspects == 0 then return nil end

    -- Filter: only accuse players who are alive, not our ally, not ourselves
    local valid = {}
    for _, s in ipairs(suspects) do
        if not (IsValid(s) and lib.IsPlayerAlive(s)) then continue end
        if s == bot then continue end
        if TTTBots.Roles.IsAllies(bot, s) and bot:GetTeam() ~= TEAM_INNOCENT then continue end
        table.insert(valid, s)
    end

    if #valid == 0 then return nil end

    -- Dumb archetype: 20% chance to accidentally pick the wrong alive player
    local personality = bot:BotPersonality()
    local archetype = personality and personality:GetClosestArchetype() or "Default"
    if archetype == TTTBots.Archetypes.Dumb and math.random(1, 100) <= 20 then
        local alivePlayers = TTTBots.Match.AlivePlayers or {}
        local others = {}
        for _, p in ipairs(alivePlayers) do
            if p ~= bot and not TTTBots.Roles.IsAllies(bot, p) then
                table.insert(others, p)
            end
        end
        if #others > 0 then
            return others[math.random(1, #others)]
        end
    end

    -- Return highest-weight suspect
    local best, bestW = nil, -math.huge
    for _, s in ipairs(valid) do
        local w = evidence:EvidenceWeight(s)
        if w > bestW then bestW = w; best = s end
    end
    return best
end

--- Compose a chatter event name and arguments based on evidence strength.
---@param bot Bot
---@param suspect Player
---@param weight number
---@return string eventName, table args
local function buildAccusationChat(bot, suspect, weight)
    local evidence    = bot:BotEvidence()
    local strongest   = evidence and evidence:GetStrongestEvidence(suspect)
    local args = { player = suspect:Nick(), playerEnt = suspect }

    if strongest then
        args.reason   = strongest.detail or strongest.type
        args.location = strongest.location
        if strongest.victim and IsValid(strongest.victim) then
            args.victim = strongest.victim:Nick()
        end
    end

    local kosThreshold    = lib.GetConVarInt("evidence_kos_threshold") or 14
    local accuseThreshold = lib.GetConVarInt("evidence_accuse_threshold") or 7

    if weight >= kosThreshold then
        -- Strong evidence → full KOS with reason
        return "AccuseKOS", args
    elseif weight >= accuseThreshold then
        -- Medium evidence → declare suspicious with explanation
        return "AccuseMedium", args
    else
        -- Weak → soft hint
        return "AccuseSoft", args
    end
end

-- ===========================================================================
-- Behavior implementation
-- ===========================================================================

function AccusePlayer.Validate(bot)
    if not lib.IsPlayerAlive(bot) then return false end
    if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then return false end
    -- Don't accuse while in combat
    if bot.attackTarget and IsValid(bot.attackTarget) then return false end

    local threshold = getAccuseThreshold(bot)
    local suspect   = pickBestSuspect(bot, threshold)
    if not suspect then return false end

    local evidence = bot:BotEvidence()
    if not evidence then return false end

    -- Cooldown: don't accuse the same person twice within configurable window
    local cooldown = lib.GetConVarInt("evidence_accuse_cooldown") or 60
    if evidence:HasAccusedRecently(suspect, cooldown) then return false end

    -- Personality gate: must be able to explain suspicion (Sus archetype bypasses)
    if not evidence:CanExplainSuspicion(suspect) then return false end

    -- Store the chosen target in behavior state
    local state = TTTBots.Behaviors.GetState(bot, "AccusePlayer")
    state.suspect   = suspect
    state.weight    = evidence:EvidenceWeight(suspect)
    state.startTime = CurTime()
    state.phase     = "start"

    return true
end

function AccusePlayer.OnStart(bot)
    local state   = TTTBots.Behaviors.GetState(bot, "AccusePlayer")
    local suspect = state.suspect
    if not (IsValid(suspect) and lib.IsPlayerAlive(suspect)) then return STATUS.FAILURE end

    local evidence = bot:BotEvidence()
    evidence:RecordAccusation(suspect)

    -- Look at the suspect
    local loco = bot:BotLocomotor()
    if loco and suspect then
        loco:LookAt(suspect:EyePos())
    end

    local eventName, args = buildAccusationChat(bot, suspect, state.weight)
    local chatter = bot:BotChatter()
    if chatter then
        chatter:On(eventName, args, false, 0)
        -- Strong evidence: also fire the KOS pipeline
        local kosThreshold = lib.GetConVarInt("evidence_kos_threshold") or 14
        if state.weight >= kosThreshold then
            TTTBots.Match.CallKOS(bot, suspect)
        end
    end

    -- Notify suspect so they can trigger DefendSelf
    hook.Run("TTTBots.AccusePlayer", bot, suspect)

    state.phase = "watching"
    return STATUS.RUNNING
end

function AccusePlayer.OnRunning(bot)
    local state   = TTTBots.Behaviors.GetState(bot, "AccusePlayer")
    local suspect = state.suspect

    -- Guard: suspect must still be a valid alive player
    if not (IsValid(suspect) and lib.IsPlayerAlive(suspect)) then
        return STATUS.SUCCESS -- they died, accusation done
    end

    local evidence = bot:BotEvidence()
    if not evidence then return STATUS.FAILURE end

    -- Check if suspect has since been confirmed innocent (tested clean, alibi vouched)
    local tn = evidence.trustNetwork
    if tn.confirmedInnocent[suspect] then
        -- Retract accusation
        local chatter = bot:BotChatter()
        if chatter then
            chatter:On("AccuseRetract", { player = suspect:Nick() }, false, 0)
        end
        local morality = bot:BotMorality()
        if morality then
            morality.suspicions[suspect] = math.min(morality:GetSuspicion(suspect), 2)
        end
        return STATUS.SUCCESS
    end

    -- Escalate if evidence grew while watching
    local newWeight   = evidence:EvidenceWeight(suspect)
    local kosThreshold = lib.GetConVarInt("evidence_kos_threshold") or 14
    if newWeight > state.weight + 5 and state.weight < kosThreshold then
        state.weight = newWeight
        local chatter = bot:BotChatter()
        if chatter and newWeight >= kosThreshold then
            TTTBots.Match.CallKOS(bot, suspect)
            chatter:On("AccuseKOS", { player = suspect:Nick(), playerEnt = suspect }, false, 0)
        end
    end

    -- If suspect is nearby, request they use the role checker (once per accusation)
    if not state.requestedTest then
        local dist = bot:GetPos():Distance(suspect:GetPos())
        if dist < 500 then
            local chatter = bot:BotChatter()
            if chatter then
                chatter:On("RequestRoleCheck", { player = suspect:Nick() }, false, 0)
            end
            state.requestedTest = true
        end
    end

    -- Accusation expires after 20s of running without resolution
    if (CurTime() - state.startTime) > 20 then
        return STATUS.SUCCESS
    end

    return STATUS.RUNNING
end

function AccusePlayer.OnSuccess(bot)
end

function AccusePlayer.OnFailure(bot)
end

function AccusePlayer.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "AccusePlayer")
end
