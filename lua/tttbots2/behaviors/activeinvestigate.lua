--- activeinvestigate.lua
--- ActiveInvestigate Behavior — Detective proactively searches quiet areas.
---
--- When too much time passes without any deaths (IsTooQuiet), the detective
--- navigates to unpopular / unvisited parts of the map to look for hidden
--- bodies or catch traitors who are lurking. This prevents the detective from
--- passively standing around when there are no immediate leads.
---
--- Only validates for police roles (detective, sheriff, etc.) that use
--- the innocent behavior tree and have round-awareness indicating "too quiet".

---@class ActiveInvestigate
TTTBots.Behaviors.ActiveInvestigate = {}

local lib = TTTBots.Lib

---@class ActiveInvestigate
local ActiveInvestigate = TTTBots.Behaviors.ActiveInvestigate
ActiveInvestigate.Name          = "ActiveInvestigate"
ActiveInvestigate.Description   = "Detective proactively searches quiet/unvisited map areas"
ActiveInvestigate.Interruptible = true

local STATUS = TTTBots.STATUS

--- Base minimum seconds between active investigation attempts to prevent spam.
local INVESTIGATE_COOLDOWN_BASE = 30
--- How long (seconds) the bot will spend navigating toward the target area before giving up.
local INVESTIGATE_TIMEOUT  = 25
--- How close (units) to the target position before we consider it "reached".
local ARRIVE_DISTANCE      = 200

--- 🟢 12: Return an archetype-modulated investigation cooldown.
--- Aggressive archetypes investigate more frequently; passive ones less so.
---@param bot Bot
---@return number
local function getInvestigateCooldown(bot)
    local personality = bot.components and bot.components.personality
    if not personality then return INVESTIGATE_COOLDOWN_BASE end
    local archetype = personality:GetClosestArchetype()
    local A = TTTBots.Archetypes

    if archetype == A.Hothead then return 18 end  -- aggressive, investigates quickly
    if archetype == A.Tryhard then return 20 end  -- proactive, short cooldown
    if archetype == A.Sus     then return 22 end  -- suspicious nature, wants to check things
    if archetype == A.Stoic   then return 35 end  -- methodical, waits for evidence
    if archetype == A.Nice    then return 38 end  -- prefers staying with group
    if archetype == A.Dumb    then return 45 end  -- doesn't think to investigate often
    if archetype == A.Casual  then return 40 end  -- laid-back, no urgency
    if archetype == A.Teamer  then return 32 end  -- wants to coordinate, moderate
    if archetype == A.Bad     then return 25 end  -- reckless but active
    return INVESTIGATE_COOLDOWN_BASE
end

-- ===========================================================================
-- Internal helpers
-- ===========================================================================

--- Pick a random unpopular nav area to investigate. Returns a world position
--- or nil if no suitable area can be found.
---@param bot Bot
---@return Vector|nil
local function pickInvestigationTarget(bot)
    -- Try unpopular nav areas first — places nobody has visited recently
    local unpopNavs = TTTBots.Lib.GetTopNUnpopularNavs and TTTBots.Lib.GetTopNUnpopularNavs(5) or {}

    if #unpopNavs > 0 then
        -- Pick a random one from the top 5 least popular
        local pick = unpopNavs[math.random(1, #unpopNavs)]
        local navArea = navmesh.GetNavAreaByID(pick[1])
        if navArea then
            return navArea:GetCenter()
        end
    end

    -- Fallback: pick a random nav area from the map
    local allNavs = navmesh.GetAllNavAreas()
    if allNavs and #allNavs > 0 then
        local randomNav = allNavs[math.random(1, #allNavs)]
        if randomNav then
            return randomNav:GetCenter()
        end
    end

    return nil
end

-- ===========================================================================
-- Behavior implementation
-- ===========================================================================

function ActiveInvestigate.Validate(bot)
    -- Must be alive and in an active round
    if not lib.IsPlayerAlive(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Only detective/police roles should proactively investigate
    local role = TTTBots.Roles.GetRoleFor(bot)
    if not role then return false end
    if not role:GetAppearsPolice() then return false end

    -- Don't investigate while in combat
    if bot.attackTarget and IsValid(bot.attackTarget) then return false end

    -- Check round awareness: only trigger when it's been "too quiet"
    local awareness = bot:BotRoundAwareness()
    if not awareness then return false end
    if not awareness:IsTooQuiet() then return false end

    -- Cooldown: don't spam investigations (archetype-modulated)
    local state = TTTBots.Behaviors.GetState(bot, "ActiveInvestigate")
    local cooldown = getInvestigateCooldown(bot)
    if state.lastInvestigateTime and (CurTime() - state.lastInvestigateTime) < cooldown then
        return false
    end

    -- Must not be in EARLY phase — let the round develop first
    local phase = awareness:GetPhase()
    if phase == "EARLY" then return false end

    return true
end

function ActiveInvestigate.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ActiveInvestigate")

    local targetPos = pickInvestigationTarget(bot)
    if not targetPos then return STATUS.FAILURE end

    state.targetPos           = targetPos
    state.startTime           = CurTime()
    state.lastInvestigateTime = CurTime()

    -- Set locomotor goal
    local loco = bot:BotLocomotor()
    if loco then
        loco:SetGoal(targetPos)
    end

    -- Announce investigation via chatter
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("InvestigateNoise", {})  -- Reuse existing "investigating" chatter
    end

    return STATUS.RUNNING
end

function ActiveInvestigate.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ActiveInvestigate")

    -- Timeout: give up after INVESTIGATE_TIMEOUT seconds
    if (CurTime() - state.startTime) > INVESTIGATE_TIMEOUT then
        return STATUS.SUCCESS
    end

    -- If we've arrived at the target area, look around then succeed
    if state.targetPos and bot:GetPos():Distance(state.targetPos) < ARRIVE_DISTANCE then
        -- 🟢 12: Archetype-modulated investigation at the target area
        local loco = bot:BotLocomotor()
        if loco then
            local personality = bot.components and bot.components.personality
            local archetype = personality and personality:GetClosestArchetype() or "Default"
            local A = TTTBots.Archetypes

            -- How wide the detective searches the area varies by personality
            local searchRadius = 200
            if archetype == A.Tryhard or archetype == A.Hothead then
                searchRadius = 350  -- sweeps a wider area, more thorough
            elseif archetype == A.Dumb then
                searchRadius = 100  -- barely looks around
            elseif archetype == A.Stoic then
                searchRadius = 250  -- careful, measured search
            end

            local lookOffset = Vector(math.random(-searchRadius, searchRadius), math.random(-searchRadius, searchRadius), 60)
            loco:LookAt(state.targetPos + lookOffset)

            -- Stoic detectives linger an extra moment (don't immediately return SUCCESS)
            if archetype == A.Stoic and not state.lingerStarted then
                state.lingerStarted = true
                state.lingerEndTime = CurTime() + 2  -- 2 extra seconds
                return STATUS.RUNNING
            end
            if state.lingerStarted and CurTime() < state.lingerEndTime then
                return STATUS.RUNNING
            end
        end
        return STATUS.SUCCESS
    end

    -- If a corpse becomes visible while en route, let InvestigateCorpse take over
    -- (higher priority in tree will preempt us naturally)

    -- Keep navigating
    local loco = bot:BotLocomotor()
    if loco and state.targetPos then
        loco:SetGoal(state.targetPos)
    end

    return STATUS.RUNNING
end

function ActiveInvestigate.OnSuccess(bot)
end

function ActiveInvestigate.OnFailure(bot)
end

function ActiveInvestigate.OnEnd(bot)
    -- Preserve lastInvestigateTime for cooldown across cycles
    local state = TTTBots.Behaviors.GetState(bot, "ActiveInvestigate")
    local lastTime = state.lastInvestigateTime
    TTTBots.Behaviors.ClearState(bot, "ActiveInvestigate")
    -- Re-store the cooldown timestamp so the next Validate respects it
    if lastTime then
        local newState = TTTBots.Behaviors.GetState(bot, "ActiveInvestigate")
        newState.lastInvestigateTime = lastTime
    end
end
