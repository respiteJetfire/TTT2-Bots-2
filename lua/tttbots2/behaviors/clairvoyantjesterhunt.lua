--- clairvoyantjesterhunt.lua
--- Clairvoyant Jester → Sidekick conversion behavior.
---
--- When both the Jester and Sidekick addons are installed, the Clairvoyant can
--- intentionally kill the Jester to convert them into a loyal Sidekick. This is
--- a high-risk, high-reward play: the bot must correctly identify the Jester
--- among special-role players using behavioral heuristics derived from
--- ClairvoyantIntel's intel targets.

if not TTTBots.Lib.IsTTT2() then return false end
if not JESTER then return false end
if not SIDEKICK then return false end
if not ROLE_JESTER then return false end
if not ROLE_SIDEKICK then return false end

---@class BClairvoyantJesterHunt
TTTBots.Behaviors.ClairvoyantJesterHunt = {}

local lib = TTTBots.Lib

---@class BClairvoyantJesterHunt
local JesterHunt = TTTBots.Behaviors.ClairvoyantJesterHunt
JesterHunt.Name = "ClairvoyantJesterHunt"
JesterHunt.Description = "Identify and kill the Jester to convert them into a Sidekick."
JesterHunt.Interruptible = true

local STATUS = TTTBots.STATUS

--- Cooldown between hunt attempts (seconds).
local HUNT_COOLDOWN = 60

--- Maximum time to pursue a target before giving up (seconds).
local HUNT_TIMEOUT = 30

--- Minimum jester-likelihood score to attempt the hunt.
local JESTER_SCORE_THRESHOLD = 0.3

--- Distance at which the bot begins engaging the target.
local ENGAGE_DIST = 150

--- Personality archetype modifiers for the jester hunt chance.
--- Base chance is 40%; multiply by this modifier.
TTTBots.Clairvoyant = TTTBots.Clairvoyant or {}
TTTBots.Clairvoyant.PersonalityModifiers = TTTBots.Clairvoyant.PersonalityModifiers or {}

local JesterHuntChance = {
    Default = 1.0,
    Tryhard = 1.5,
    Hothead = 1.8,
    Stoic   = 0.8,
    Nice    = 0.4,
    Casual  = 0.6,
    Bad     = 1.3,
    Dumb    = 0.9,
    Sus     = 0.7,
    Teamer  = 1.0,
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

--- Retrieve the personality archetype string for the given bot.
---@param bot Player
---@return string
local function GetArchetype(bot)
    local personality = bot.BotPersonality and bot:BotPersonality()
    local archetype = personality and personality.GetClosestArchetype and personality:GetClosestArchetype() or "Default"
    return archetype
end

--- Get the jesterHuntChance multiplier for the bot's personality.
---@param bot Player
---@return number
local function GetHuntChanceMult(bot)
    local archetype = GetArchetype(bot)
    return JesterHuntChance[archetype] or JesterHuntChance["Default"]
end

--- Retrieve the intel targets gathered by ClairvoyantIntel for this bot.
--- Returns a flat table of player entities, or nil if none.
---@param bot Player
---@return table|nil
local function GetIntelTargets(bot)
    -- Primary source: ClairvoyantIntel behavior state
    local ciState = TTTBots.Behaviors.GetState(bot, "ClairvoyantIntel")
    if ciState and ciState.intelTargets and #ciState.intelTargets > 0 then
        return ciState.intelTargets
    end

    -- Fallback: direct field on the bot (design doc reference)
    if bot._cvIntelTargets and #bot._cvIntelTargets > 0 then
        return bot._cvIntelTargets
    end

    return nil
end

--- Check whether any living Sidekick already exists on the server.
---@return boolean
local function SidekickExists()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and not ply:IsSpec() then
            local sub = ply.GetSubRole and ply:GetSubRole()
            if sub and sub == ROLE_SIDEKICK then
                return true
            end
        end
    end
    return false
end

--- Check if a player has been KOS'd by anyone.
---@param target Player
---@return boolean
local function IsKOSed(target)
    local kosList = TTTBots.Match and TTTBots.Match.KOSList
    if not kosList then return false end
    return kosList[target] ~= nil and next(kosList[target]) ~= nil
end

--- Score a candidate as a likely Jester. Higher = more likely.
--- Returns a value in [0, 1].
---@param bot Player
---@param target Player
---@return number score
local function ScoreJesterLikelihood(bot, target)
    if not IsValid(target) or not target:Alive() or target:IsSpec() then
        return 0
    end

    local score = 0

    -- Factor 1: Must be in our intel targets (confirmed special role).
    -- This is a prerequisite; if not present, score stays 0.
    local intelTargets = GetIntelTargets(bot)
    if not intelTargets then return 0 end

    local isIntel = false
    for _, ply in ipairs(intelTargets) do
        if ply == target then
            isIntel = true
            break
        end
    end
    if not isIntel then return 0 end

    -- Base score for being an intel target.
    score = score + 0.15

    -- Factor 2: Low suspicion from us (jesters typically don't trigger suspicion).
    local morality = bot.components and bot.components.morality
    if morality and morality.GetSuspicion then
        local sus = morality:GetSuspicion(target)
        if sus <= 0 then
            score = score + 0.2
        elseif sus <= 2 then
            score = score + 0.1
        end
        -- High suspicion is bad — probably not a jester.
        if sus >= 5 then
            score = score - 0.15
        end
    end

    -- Factor 3: Has not been KOS'd (jesters usually aren't KOS'd because they want to be killed).
    if not IsKOSed(target) then
        score = score + 0.1
    end

    -- Factor 4: NeutralOverride on their role data (jesters have this set).
    if TTTBots.Roles and TTTBots.Roles.GetRoleFor then
        local roleData = TTTBots.Roles.GetRoleFor(target)
        if roleData then
            if roleData.GetNeutralOverride and roleData:GetNeutralOverride() then
                score = score + 0.25
            end
            -- Check if this role starts fights (jesters do — they want to provoke).
            if roleData.GetStartsFights and roleData:GetStartsFights() then
                score = score + 0.1
            end
        end
    end

    -- Factor 5: Doesn't use weapons aggressively — check if we've witnessed them attacking.
    -- Use evidence log if available.
    local evidence = bot.BotEvidence and bot:BotEvidence()
    if evidence and evidence.log then
        local hasKillEvidence = false
        for _, entry in ipairs(evidence.log) do
            if entry.subject == target then
                local t = entry.type or ""
                if t == "WITNESSED_KILL" then
                    hasKillEvidence = true
                    break
                end
            end
        end
        if not hasKillEvidence then
            score = score + 0.1
        else
            score = score - 0.2
        end
    else
        -- No evidence system — small bonus for lack of data.
        score = score + 0.05
    end

    -- Factor 6: Proximity — closer candidates are easier to evaluate.
    local dist = bot:GetPos():Distance(target:GetPos())
    if dist < 1500 then
        score = score + 0.1
    end

    return math.Clamp(score, 0, 1)
end

--- Find the best Jester candidate from the bot's intel targets.
---@param bot Player
---@return Player|nil candidate
---@return number bestScore
local function FindJesterCandidate(bot)
    local intelTargets = GetIntelTargets(bot)
    if not intelTargets then return nil, 0 end

    local bestCandidate = nil
    local bestScore = -1

    for _, target in ipairs(intelTargets) do
        if IsValid(target) and target:Alive() and not target:IsSpec() and target ~= bot then
            local score = ScoreJesterLikelihood(bot, target)
            if score > bestScore then
                bestScore = score
                bestCandidate = target
            end
        end
    end

    if bestScore < JESTER_SCORE_THRESHOLD then
        return nil, bestScore
    end

    return bestCandidate, bestScore
end

---------------------------------------------------------------------------
-- Behavior lifecycle
---------------------------------------------------------------------------

--- Validate whether this behavior should activate.
---@param bot Player
---@return boolean
function JesterHunt.Validate(bot)
    if not IsValid(bot) then return false end
    if not bot:Alive() or bot:Health() <= 0 then return false end
    if bot:IsSpec() then return false end

    -- Must be the Clairvoyant role.
    if not ROLE_CLAIRVOYANT then return false end
    if not bot.GetSubRole or bot:GetSubRole() ~= ROLE_CLAIRVOYANT then return false end

    -- JESTER and SIDEKICK globals must exist (already checked at file top, but be safe).
    if not JESTER or not SIDEKICK then return false end
    if not ROLE_JESTER or not ROLE_SIDEKICK then return false end

    -- Don't hunt if a Sidekick already exists (conversion already happened).
    if SidekickExists() then return false end

    -- Must have intel targets from ClairvoyantIntel.
    local intelTargets = GetIntelTargets(bot)
    if not intelTargets or #intelTargets == 0 then return false end

    local state = TTTBots.Behaviors.GetState(bot, "ClairvoyantJesterHunt")

    -- If already actively hunting, keep validating.
    if state.target and IsValid(state.target) and state.target:Alive() and not state.target:IsSpec() then
        return true
    end

    -- Cooldown check.
    if state.nextHuntTime and CurTime() < state.nextHuntTime then return false end

    -- Personality chance gate: base 40% * modifier.
    local chanceMult = GetHuntChanceMult(bot)
    local huntChance = 0.4 * chanceMult
    if math.random() > huntChance then
        -- Failed the dice roll; set a short cooldown so we don't spam.
        state.nextHuntTime = CurTime() + math.random(15, 30)
        return false
    end

    -- Identify a Jester candidate.
    local candidate, score = FindJesterCandidate(bot)
    if not candidate then return false end

    return true
end

--- Called when the behavior starts.
---@param bot Player
---@return number STATUS
function JesterHunt.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ClairvoyantJesterHunt")

    -- Identify the Jester candidate.
    local candidate, score = FindJesterCandidate(bot)
    if not candidate then
        return STATUS.FAILURE
    end

    state.target = candidate
    state.startTime = CurTime()
    state.score = score

    -- Fire chatter event.
    local chatter = bot.BotChatter and bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("ClairvoyantJesterHunt", { name = candidate:Nick() })
    end

    return STATUS.RUNNING
end

--- Called each tick while the behavior is running.
---@param bot Player
---@return number STATUS
function JesterHunt.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ClairvoyantJesterHunt")
    local target = state.target

    -- Target validity checks.
    if not IsValid(target) or not target:IsPlayer() then
        return STATUS.SUCCESS -- Target gone; conversion may have happened.
    end

    if not target:Alive() or target:IsSpec() then
        return STATUS.SUCCESS -- Target died; conversion handled by addon.
    end

    -- If a Sidekick now exists, the conversion worked.
    if SidekickExists() then
        return STATUS.SUCCESS
    end

    -- Timeout — give up after HUNT_TIMEOUT seconds.
    if state.startTime and (CurTime() - state.startTime) > HUNT_TIMEOUT then
        return STATUS.FAILURE
    end

    -- Verify bot is still Clairvoyant (role could change mid-round).
    if not bot.GetSubRole or bot:GetSubRole() ~= ROLE_CLAIRVOYANT then
        return STATUS.FAILURE
    end

    local dist = bot:GetPos():Distance(target:GetPos())

    if dist > ENGAGE_DIST then
        -- Move toward the target.
        local loco = bot:BotLocomotor()
        if loco then
            loco:SetGoal(target:GetPos())
        end
        return STATUS.RUNNING
    end

    -- Within attack range — engage the target.
    bot:SetAttackTarget(target, "CLAIRVOYANT_JESTER_HUNT", 3)

    return STATUS.RUNNING
end

--- Called when the behavior completes successfully.
---@param bot Player
function JesterHunt.OnSuccess(bot)
    -- Fire sidekick conversion chatter if applicable
    if SidekickExists() then
        local chatter = bot.BotChatter and bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("ClairvoyantSidekickSuccess", {})
        end
    end
end

--- Called when the behavior fails.
---@param bot Player
function JesterHunt.OnFailure(bot)
end

--- Called when the behavior ends (success, failure, or interruption).
---@param bot Player
function JesterHunt.OnEnd(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ClairvoyantJesterHunt")

    -- Set cooldown for next hunt attempt.
    state.nextHuntTime = CurTime() + HUNT_COOLDOWN

    -- Clear the attack target if it was set by us.
    if IsValid(bot) and bot.attackTarget then
        local target = state.target
        if bot.attackTarget == target then
            bot.attackTarget = nil
        end
    end

    -- Preserve the cooldown but clear transient state.
    local cooldown = state.nextHuntTime
    TTTBots.Behaviors.ClearState(bot, "ClairvoyantJesterHunt")

    -- Restore cooldown after clear.
    local freshState = TTTBots.Behaviors.GetState(bot, "ClairvoyantJesterHunt")
    freshState.nextHuntTime = cooldown
end

--- Hook: clear jester hunt state at the start of each round.
hook.Add("TTTBeginRound", "TTTBots.ClairvoyantJesterHunt.RoundReset", function()
    for _, bot in ipairs(player.GetBots()) do
        TTTBots.Behaviors.ClearState(bot, "ClairvoyantJesterHunt")
    end
end)

return true
