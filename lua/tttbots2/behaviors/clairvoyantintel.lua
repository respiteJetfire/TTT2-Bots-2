---@class BClairvoyantIntel
TTTBots.Behaviors.ClairvoyantIntel = {}

local lib = TTTBots.Lib
---@class BClairvoyantIntel
local ClairvoyantIntel = TTTBots.Behaviors.ClairvoyantIntel
ClairvoyantIntel.Name = "ClairvoyantIntel"
ClairvoyantIntel.Description = "Gather and strategically reveal intel about special-role players as the Clairvoyant."
ClairvoyantIntel.Interruptible = true

local STATUS = TTTBots.STATUS

--- Namespace for Clairvoyant personality modifiers and configuration, accessible externally.
TTTBots.Clairvoyant = TTTBots.Clairvoyant or {}

--- Personality archetype modifiers for clairvoyant intel pacing.
-- revealEagerness:    multiplier on how quickly the bot wants to reveal targets
-- cautionLevel:       multiplier on self-preservation threshold checks
-- intelProcessDelay:  multiplier on the base cooldown between revelations
-- suspicionBonus:     multiplier on additional suspicion weight added on reveal
TTTBots.Clairvoyant.PersonalityModifiers = {
    Tryhard = { revealEagerness = 1.4, cautionLevel = 1.3, intelProcessDelay = 0.7, suspicionBonus = 1.3 },
    Hothead = { revealEagerness = 1.6, cautionLevel = 0.5, intelProcessDelay = 0.4, suspicionBonus = 1.5 },
    Stoic   = { revealEagerness = 0.6, cautionLevel = 1.5, intelProcessDelay = 1.5, suspicionBonus = 0.8 },
    Nice    = { revealEagerness = 1.2, cautionLevel = 1.0, intelProcessDelay = 1.0, suspicionBonus = 0.7 },
    Casual  = { revealEagerness = 0.8, cautionLevel = 0.8, intelProcessDelay = 1.3, suspicionBonus = 0.9 },
    Bad     = { revealEagerness = 0.5, cautionLevel = 0.6, intelProcessDelay = 0.8, suspicionBonus = 1.1 },
    Dumb    = { revealEagerness = 1.3, cautionLevel = 0.3, intelProcessDelay = 0.5, suspicionBonus = 0.6 },
    Sus     = { revealEagerness = 0.7, cautionLevel = 1.6, intelProcessDelay = 1.4, suspicionBonus = 1.4 },
    Teamer  = { revealEagerness = 1.5, cautionLevel = 1.1, intelProcessDelay = 0.8, suspicionBonus = 1.0 },
    Default = { revealEagerness = 1.0, cautionLevel = 1.0, intelProcessDelay = 1.0, suspicionBonus = 1.0 },
}

--- Base cooldown range (seconds) between revelations.
local BASE_COOLDOWN_MIN = 25
local BASE_COOLDOWN_MAX = 70

--- Evidence weight for initial clairvoyant intel entries.
local INTEL_EVIDENCE_WEIGHT = 3

--- Evidence weight for the small bump added when a target is actively revealed.
local REVEAL_BUMP_WEIGHT = 1

--- HP threshold for self-preservation delay.
local SELF_PRESERVE_HP = 50

--- Roles to exclude from intel gathering (standard roles the Clairvoyant already knows).
local EXCLUDED_ROLES = {}

--- Lazily populate the excluded roles table once role constants are available.
local function GetExcludedRoles()
    if #EXCLUDED_ROLES == 0 then
        local roles = { ROLE_INNOCENT, ROLE_DETECTIVE, ROLE_TRAITOR, ROLE_CLAIRVOYANT }
        for _, r in ipairs(roles) do
            if r then
                EXCLUDED_ROLES[r] = true
            end
        end
    end
    return EXCLUDED_ROLES
end

--- Retrieve the personality modifier table for the given bot.
---@param bot Player
---@return table
local function GetModifiers(bot)
    local personality = bot.BotPersonality and bot:BotPersonality()
    local archetype = personality and personality.GetClosestArchetype and personality:GetClosestArchetype() or "Default"
    return TTTBots.Clairvoyant.PersonalityModifiers[archetype]
        or TTTBots.Clairvoyant.PersonalityModifiers["Default"]
end

--- Compute the cooldown (in seconds) before the next revelation.
---@param bot Player
---@return number
local function ComputeCooldown(bot)
    local mods = GetModifiers(bot)
    local base = math.random(BASE_COOLDOWN_MIN, BASE_COOLDOWN_MAX)
    local cooldown = base * mods.intelProcessDelay

    -- Dumb bots get erratic jitter (±30 %)
    if mods == TTTBots.Clairvoyant.PersonalityModifiers["Dumb"] then
        cooldown = cooldown * (0.7 + math.random() * 0.6)
    end

    return math.max(5, cooldown)
end

--- Check whether a player is a valid intel target.
---@param ply Player
---@return boolean
local function IsValidTarget(ply)
    if not IsValid(ply) then return false end
    if not ply:IsPlayer() then return false end
    if not ply:Alive() then return false end
    if ply:IsSpec() then return false end

    local subrole = ply.GetSubRole and ply:GetSubRole()
    if not subrole then return false end

    local excluded = GetExcludedRoles()
    if excluded[subrole] then return false end

    return true
end

--- Gather initial intel targets for this round.
---@param bot Player
---@param state table
local function GatherIntelTargets(bot, state)
    local allPlayers = player.GetAll()
    local candidates = {}

    for _, ply in ipairs(allPlayers) do
        if ply ~= bot and IsValidTarget(ply) then
            candidates[#candidates + 1] = ply
        end
    end

    -- Apply ttt2_cv_visible percentage ConVar (default 100).
    local cvVisible = GetConVar("ttt2_cv_visible")
    local pct = cvVisible and cvVisible:GetInt() or 100
    pct = math.Clamp(pct, 0, 100)

    local count = math.ceil(#candidates * pct / 100)

    -- Shuffle candidates and take the first `count`.
    for i = #candidates, 2, -1 do
        local j = math.random(1, i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    state.intelTargets = {}
    for i = 1, math.min(count, #candidates) do
        state.intelTargets[#state.intelTargets + 1] = candidates[i]
    end

    state.revealedTargets = {}
    state.intelGathered = true

    -- Add initial CLAIRVOYANT_INTEL evidence for each target.
    local evidence = bot.BotEvidence and bot:BotEvidence()
    if evidence and evidence.AddEvidence then
        for _, target in ipairs(state.intelTargets) do
            evidence:AddEvidence({
                type    = "CLAIRVOYANT_INTEL",
                subject = target,
                detail  = "detected as special role (clairvoyant intel)",
                weight  = INTEL_EVIDENCE_WEIGHT,
            })
        end
    end
end

--- Return a table of unrevealed intel targets.
---@param state table
---@return table
local function GetUnrevealedTargets(state)
    if not state.intelTargets then return {} end

    local revealedSet = {}
    if state.revealedTargets then
        for _, ply in ipairs(state.revealedTargets) do
            revealedSet[ply] = true
        end
    end

    local unrevealed = {}
    for _, target in ipairs(state.intelTargets) do
        if IsValid(target) and target:Alive() and not revealedSet[target] then
            unrevealed[#unrevealed + 1] = target
        end
    end

    return unrevealed
end

--- Score and select the best target to reveal.
---@param bot Player
---@param unrevealed table
---@return Player|nil
local function SelectBestTarget(bot, unrevealed)
    if #unrevealed == 0 then return nil end

    local botPos = bot:GetPos()
    local bestTarget = nil
    local bestScore = -math.huge

    for _, target in ipairs(unrevealed) do
        if IsValid(target) and target:Alive() then
            local score = 0

            -- Factor 1: Existing suspicion / evidence weight on target (compound intel).
            local morality = bot.BotMorality and bot:BotMorality()
            if morality and morality.GetSuspicion then
                local susp = morality:GetSuspicion(target)
                if susp then
                    score = score + susp * 2
                end
            end

            -- Factor 2: Proximity — closer targets score higher for natural conversation feel.
            local dist = botPos:Distance(target:GetPos())
            local proxScore = math.max(0, 3000 - dist) / 1000 -- 0-3 bonus for within 3000 units
            score = score + proxScore

            -- Factor 3: Recently seen — check if bot can see the target right now.
            local canSee = lib.CanSeeArc and lib.CanSeeArc(bot, target:GetPos() + Vector(0, 0, 48), 90)
            if canSee then
                score = score + 1.5
            end

            -- Small random jitter to break ties.
            score = score + math.random() * 0.5

            if score > bestScore then
                bestScore = score
                bestTarget = target
            end
        end
    end

    return bestTarget or unrevealed[math.random(#unrevealed)]
end

---------------------------------------------------------------------------
-- Behavior lifecycle
---------------------------------------------------------------------------

--- Validate whether this behavior should activate.
---@param bot Player
---@return boolean
function ClairvoyantIntel.Validate(bot)
    if not IsValid(bot) then return false end
    if not bot:Alive() or (bot:Health() <= 0) then return false end

    -- Must be the Clairvoyant role.
    if not ROLE_CLAIRVOYANT then return false end
    if not bot.GetSubRole or bot:GetSubRole() ~= ROLE_CLAIRVOYANT then return false end

    local state = TTTBots.Behaviors.GetState(bot, "ClairvoyantIntel")

    -- If we haven't gathered intel yet this round, we should activate.
    if not state.intelGathered then return true end

    -- If there are still unrevealed targets, check cooldown.
    local unrevealed = GetUnrevealedTargets(state)
    if #unrevealed == 0 then return false end

    -- Respect cooldown timer.
    if state.nextRevealTime and CurTime() < state.nextRevealTime then return false end

    return true
end

--- Called when the behavior starts.
---@param bot Player
---@return number STATUS
function ClairvoyantIntel.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ClairvoyantIntel")

    -- Gather intel on first activation this round.
    if not state.intelGathered then
        GatherIntelTargets(bot, state)

        -- Set a small initial delay before the first reveal based on personality.
        local mods = GetModifiers(bot)
        local initialDelay = math.random(5, 15) * mods.intelProcessDelay
        state.nextRevealTime = CurTime() + initialDelay
    end

    return STATUS.RUNNING
end

--- Called each tick while the behavior is running.
---@param bot Player
---@return number STATUS
function ClairvoyantIntel.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ClairvoyantIntel")

    -- Safety: ensure intel has been gathered.
    if not state.intelGathered then
        GatherIntelTargets(bot, state)
        state.nextRevealTime = CurTime() + math.random(5, 15)
        return STATUS.RUNNING
    end

    -- Check cooldown.
    if state.nextRevealTime and CurTime() < state.nextRevealTime then
        return STATUS.RUNNING
    end

    -- Self-preservation: delay if low HP and high caution.
    local mods = GetModifiers(bot)
    if mods.cautionLevel >= 1.3 and bot:Health() < SELF_PRESERVE_HP then
        -- Push the next reveal time back a bit.
        state.nextRevealTime = CurTime() + math.random(10, 25)
        return STATUS.RUNNING
    end

    -- Get unrevealed targets.
    local unrevealed = GetUnrevealedTargets(state)
    if #unrevealed == 0 then
        -- Fire intel-complete chatter when all targets have been revealed
        local completeChatter = bot.BotChatter and bot:BotChatter()
        if completeChatter and completeChatter.On then
            completeChatter:On("ClairvoyantIntelComplete", {})
        end
        return STATUS.SUCCESS
    end

    -- Select and reveal the best target.
    local target = SelectBestTarget(bot, unrevealed)
    if not target or not IsValid(target) then
        return STATUS.FAILURE
    end

    -- Fire chatter event.
    local chatter = bot.BotChatter and bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("ClairvoyantReveal", { name = target:Nick() })
    end

    -- Mark target as revealed.
    state.revealedTargets = state.revealedTargets or {}
    state.revealedTargets[#state.revealedTargets + 1] = target

    -- Add a small suspicion bump on reveal.
    local evidence = bot.BotEvidence and bot:BotEvidence()
    if evidence and evidence.AddEvidence then
        evidence:AddEvidence({
            type    = "CLAIRVOYANT_INTEL",
            subject = target,
            detail  = "actively revealed by clairvoyant intel",
            weight  = math.ceil(REVEAL_BUMP_WEIGHT * mods.suspicionBonus),
        })
    end

    -- Set cooldown for next revelation.
    state.nextRevealTime = CurTime() + ComputeCooldown(bot)

    return STATUS.SUCCESS
end

--- Called when the behavior completes successfully.
---@param bot Player
function ClairvoyantIntel.OnSuccess(bot)
end

--- Called when the behavior fails.
---@param bot Player
function ClairvoyantIntel.OnFailure(bot)
end

--- Called when the behavior ends (success or failure). Clears transient state but preserves persistent intel.
---@param bot Player
function ClairvoyantIntel.OnEnd(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ClairvoyantIntel")

    -- Preserve persistent intel data across behavior re-entries within the same round.
    -- Only clear truly transient fields; intelTargets, revealedTargets, and nextRevealTime
    -- are kept so the bot resumes where it left off.

    -- If all targets have been revealed, clean up fully.
    if state.intelGathered then
        local unrevealed = GetUnrevealedTargets(state)
        if #unrevealed == 0 then
            TTTBots.Behaviors.ClearState(bot, "ClairvoyantIntel")
        end
    end
end

--- Hook: clear clairvoyant intel state at the start of each round.
hook.Add("TTTBeginRound", "TTTBots.ClairvoyantIntel.RoundReset", function()
    for _, bot in ipairs(player.GetBots()) do
        TTTBots.Behaviors.ClearState(bot, "ClairvoyantIntel")
    end
end)
