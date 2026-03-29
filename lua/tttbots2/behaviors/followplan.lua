
TTTBots.Behaviors.FollowPlan = {}

local lib = TTTBots.Lib

local FollowPlan = TTTBots.Behaviors.FollowPlan
FollowPlan.Name = "FollowPlan"
FollowPlan.Description = "Follow the plan assigned to us by the game coordinator."
FollowPlan.Interruptible = true
-- When debugging the component and you want to print extra info, use this:
FollowPlan.Debug = false

---@class Bot
---@field Job table?
---@field followTarget Player? for the plan system
---@field followEndTime number for the plan system

local STATUS = TTTBots.STATUS
local Plans = TTTBots.Plans
local ACTIONS = Plans.ACTIONS

--- Distance at which the FOLLOW action stops approaching the target and idles.
local FOLLOW_STOP_RANGE = 140
--- How far the goal must drift before we call SetGoal again (prevents path thrashing).
local GOAL_CHANGE_THRESHOLD = 200
--- Seconds between stall-detection samples.
local STALL_REPATH_INTERVAL = 2
--- Minimum distance bot must have moved between samples to count as "making progress".
local STALL_MIN_PROGRESS = 24

local function jobHasVectorTarget(job)
    return job and isvector(job.TargetObj)
end

local function jobHasPlayerTarget(job)
    return job and IsValid(job.TargetObj) and lib.IsPlayerAlive(job.TargetObj)
end

function FollowPlan.IsPlanFollowerRole(bot)
    return TTTBots.Roles.GetRoleFor(bot):GetCanCoordinate()
end

--- Ignore plans if we aren't evil or have a conflicting personality trait.
--- Bots with ignoreOrders personality traits have a reduced (but not zero) chance
--- of following plans. The chance scales with round phase pressure so that even
--- loner/oblivious bots will eventually start attacking as the round progresses.
function FollowPlan.ShouldIgnorePlans(bot)
    if not FollowPlan.IsPlanFollowerRole(bot) then return true end
    if not FollowPlan.Debug and bot.components.personality:GetIgnoresOrders() then
        -- Instead of always ignoring, give a phase-scaled chance to comply.
        -- EARLY: 30% comply, MID: 50%, LATE: 70%, OVERTIME: 90%
        local complianceChance = 0.30
        local ra = bot.BotRoundAwareness and bot:BotRoundAwareness()
        local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
        if ra and PHASE then
            local phase = ra:GetPhase()
            if phase == PHASE.MID then complianceChance = 0.50
            elseif phase == PHASE.LATE then complianceChance = 0.70
            elseif phase == PHASE.OVERTIME then complianceChance = 0.90
            end
        end
        if math.random() > complianceChance then return true end
    end

    return false
end

function FollowPlan.GetBotJob(bot)
    return TTTBots.Behaviors.GetState(bot, "FollowPlan").Job
end

function FollowPlan.GetJobState(bot)
    local job = FollowPlan.GetBotJob(bot)
    return (job and job.State) or TTTBots.Plans.BOTSTATES.IDLE
end

--- Grabs an available job from the PlanCoordinator and assigns it to the bot.
---@param bot Bot the bot to assign a job to
---@return boolean|table false if no job was assigned, otherwise the job
function FollowPlan.AssignNextAvailableJob(bot)
    local state = TTTBots.Behaviors.GetState(bot, "FollowPlan")
    state.Job = nil
    local job = TTTBots.PlanCoordinator.GetNextJob(true, bot)
    if not job then
        if FollowPlan.Debug then print("No jobs remaining for bot " .. bot:Nick()) end
        return false
    end
    job.State = TTTBots.Plans.BOTSTATES.IDLE
    state.Job = job
    return job
end

local function validateJobTime(job)
    return isnumber(job.ExpiryTime) and CurTime() < job.ExpiryTime
end

--- Smartly sets the locomotor goal only when the desired position has changed
--- significantly from the position we last told the locomotor to go to.
--- This prevents calling SetGoal every tick with a slightly different position,
--- which causes the locomotor to continuously abandon its current path, queue a
--- new one, and leave the bot standing still while the new path resolves.
---@param bot Bot
---@param goalPos Vector the desired destination
---@param threshold number? distance before we consider the goal "changed" (default GOAL_CHANGE_THRESHOLD)
local function smartSetGoal(bot, goalPos, threshold)
    if not isvector(goalPos) then return end
    threshold = threshold or GOAL_CHANGE_THRESHOLD

    local loco = bot:BotLocomotor()
    if not loco then return end

    local state = TTTBots.Behaviors.GetState(bot, "FollowPlan")
    local currentGoal = loco:GetRawGoal() or loco:GetGoal()

    -- If the locomotor has no goal at all, always set one.
    if not currentGoal then
        loco:SetGoal(goalPos)
        state.lastSetGoalPos = goalPos
        state.lastSetGoalTime = CurTime()
        return
    end

    -- If the desired position is close to what we already told the locomotor,
    -- don't thrash the pathfinder — let the bot keep following its current path.
    local drift = currentGoal:Distance(goalPos)
    if drift < threshold then
        return
    end

    -- Goal has drifted far enough — update it.
    loco:SetGoal(goalPos)
    state.lastSetGoalPos = goalPos
    state.lastSetGoalTime = CurTime()
end

--- Detect when the bot is stalled (has a distant goal but isn't making physical
--- progress) and force a full path reset so the locomotor can re-plan.
---@param bot Bot
---@param goalPos Vector
local function maybeRecoverMovement(bot, goalPos)
    local loco = bot:BotLocomotor()
    if not loco then return end
    if not isvector(goalPos) then return end

    local state = TTTBots.Behaviors.GetState(bot, "FollowPlan")
    local now = CurTime()
    local botPos = bot:GetPos()

    -- Don't run stall detection if we're already close to the goal.
    if botPos:Distance(goalPos) <= 150 then
        state.stallSamplePos = nil
        state.stallSampleTime = nil
        return
    end

    -- First sample — just record it.
    if not state.stallSamplePos then
        state.stallSamplePos = botPos
        state.stallSampleTime = now
        return
    end

    -- Wait for the sample interval to elapse.
    if (now - (state.stallSampleTime or 0)) < STALL_REPATH_INTERVAL then return end

    local movedDist = botPos:Distance(state.stallSamplePos)
    state.stallSamplePos = botPos
    state.stallSampleTime = now

    -- If the bot made enough progress, nothing to do.
    if movedDist >= STALL_MIN_PROGRESS then return end

    -- Bot is stalled — nuke the locomotor state so the next tick's SetGoal
    -- will force a completely fresh path request.
    loco:StopMoving()
    state.lastSetGoalPos = nil
    state.lastSetGoalTime = nil

    -- Also clear ephemeral wander positions so they get re-rolled.
    state.gatherWanderPos = nil
    state.roamPos = nil

    if FollowPlan.Debug then
        print(string.format("[FollowPlan] Stall recovery for %s — cleared path", bot:Nick()))
    end
end

local ACT_VALIDATION_HASH = {
    [ACTIONS.ATTACKANY] = function(job)
        return jobHasPlayerTarget(job)
    end,
    [ACTIONS.ATTACK] = function(job)
        return jobHasPlayerTarget(job)
    end,
    [ACTIONS.COORD_ATTACK] = function(job)
        return jobHasPlayerTarget(job) and validateJobTime(job)
    end,
    [ACTIONS.DEFEND] = function(job)
        return jobHasVectorTarget(job) and validateJobTime(job)
    end,
    [ACTIONS.DEFUSE] = function(job)
        return false -- Unimplemented
    end,
    [ACTIONS.FOLLOW] = function(job)
        return jobHasPlayerTarget(job) and validateJobTime(job)
    end,
    [ACTIONS.GATHER] = function(job)
        return jobHasVectorTarget(job) and validateJobTime(job)
    end,
    [ACTIONS.IGNORE] = function(job) return true end,
    [ACTIONS.PLANT] = function(job)
        return jobHasVectorTarget(job) and validateJobTime(job)
    end,
    [ACTIONS.ROAM] = function(job)
        return jobHasVectorTarget(job) and validateJobTime(job)
    end,
}

function FollowPlan.ValidateJob(bot, job)
    if not job then return false end
    local act = job.Action
    if not ACT_VALIDATION_HASH[act] then
        print("Attempt to do invalid job act! Type: '" .. tostring(job.Action) .. "'")
        return false
    end
    return ACT_VALIDATION_HASH[act](job)
end

--- Finds a new job if one isn't already set. Doesn't impact anything if the bot is doing a job already; otherwise, assigns a job using AssignNextAvailableJob
---@param bot Bot the bot to assign a job to
---@return boolean|table false if no job was assigned, otherwise the job
function FollowPlan.FindNewJobIfAvailable(bot)
    local job = FollowPlan.GetBotJob(bot)
    local jobValid = FollowPlan.ValidateJob(bot, job)
    if jobValid then return false end

    return FollowPlan.AssignNextAvailableJob(bot)
end

--- Validate the behavior
function FollowPlan.Validate(bot)
    local isCoordinatorEnabled = lib.GetConVarBool("coordinator")
    if not isCoordinatorEnabled then return false end

    local validate_debug = false
    if not TTTBots.Match.PlansCanStart() then
        if validate_debug then print(string.format("%s ignored plans due to round not being able to start", bot:Nick())) end
        return false
    end
    if not TTTBots.Match.RoundActive and FollowPlan.GetBotJob(bot) then
        TTTBots.Behaviors.GetState(bot, "FollowPlan").Job = nil
        if validate_debug then print(string.format("%s cleared job due to round not being active", bot:Nick())) end
    end

    local existingJob = FollowPlan.GetBotJob(bot)
    if existingJob and FollowPlan.ValidateJob(bot, existingJob) then
        return true
    elseif existingJob then
        local state = TTTBots.Behaviors.GetState(bot, "FollowPlan")
        state.Job = nil
        state.shouldClear = nil
        state.gatherWanderPos = nil
    end

    if FollowPlan.ShouldIgnorePlans(bot) then
        if validate_debug then print(string.format("%s ignored plans", bot:Nick())) end
        return false
    end
    -- Check for a plan matching this bot's team (per-team system)
    local botTeam = bot.GetTeam and bot:GetTeam()
    local teamPlan = botTeam and TTTBots.Plans.GetPlanForTeam(botTeam)
    if not teamPlan and not TTTBots.Plans.SelectedPlan then
        if validate_debug then print(string.format("%s no selected plan", bot:Nick())) end
        return false
    end
    local jobAvailable = FollowPlan.FindNewJobIfAvailable(bot)
    if not jobAvailable then return false end
    return true
end

local printf = function(str, ...) print(string.format(str, ...)) end
local f = string.format

--- Called when the behavior is started
function FollowPlan.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "FollowPlan")
    if not state.Job then
        ErrorNoHaltWithStack("FollowPlan.OnStart called without a job assigned to the bot!")
        return STATUS.FAILURE
    end
    -- Reset tracking state for a fresh job.
    state.stallSamplePos = nil
    state.stallSampleTime = nil
    state.lastSetGoalPos = nil
    state.lastSetGoalTime = nil
    if FollowPlan.Debug then
        printf("FollowPlan. JOB '%s' assigned to bot %s (For plan %s)",
            state.Job.Action, bot:Nick(), TTTBots.Plans.GetName())
    end
    return STATUS.RUNNING
end

local function botChatterWhenJobStart(bot, job)
    if not lib.IsPlayerAlive(bot) then return end
    local chatter = bot.components.chatter
    if job.HasChatted then return end
    if not chatter or not chatter.On then return end
    local tobj = job.TargetObj
    local plyName = IsValid(tobj) and tobj:IsPlayer() and tobj:Nick() or "<unresolved>"
    chatter:On(f("Plan.%s", job.Action), { target = job.TargetObj, player = plyName }, true)
    job.HasChatted = true
    return true
end

local ACT_RUNNING_HASH = {
    [ACTIONS.ATTACKANY] = function(bot, job)
        local target = job.TargetObj
        if not (IsValid(target) and lib.IsPlayerAlive(target)) then
            if FollowPlan.Debug then print(string.format("%s's target is invalid or dead.", bot:Nick())) end
            return STATUS.FAILURE
        end
        -- Seed the target's position into memory so AttackTarget.Seek has a
        -- last-known position to path toward and won't immediately abort.
        local memory = bot.components and bot.components.memory
        if memory and memory:GetLastSeenTime(target) == 0 then
            memory:UpdateKnownPositionFor(target, target:GetPos())
        end
        bot:SetAttackTarget(target, "FOLLOW_PLAN_ATTACK", 4)
        return STATUS.RUNNING
    end,
    [ACTIONS.DEFEND] = function(bot, job)
        -- path to the TargetObj (which is a Vec3) and stand there
        local targetPos = job.TargetObj
        if not isvector(targetPos) then return STATUS.FAILURE end
        local loco = bot:BotLocomotor()
        if not loco then return STATUS.FAILURE end
        smartSetGoal(bot, targetPos)
        maybeRecoverMovement(bot, targetPos)
        return STATUS.RUNNING
    end,
    [ACTIONS.DEFUSE] = function(bot, job)
        -- TODO: Implement defusing plan (probably never will do this, as traitors do not need to defuse C4)
        printf("Bot %s attempting to perform unimplemented action DEFUSE", bot:Nick())
        return STATUS.FAILURE
    end,
    [ACTIONS.FOLLOW] = function(bot, job)
        local target = job.TargetObj
        if not IsValid(target) then return STATUS.FAILURE end
        if bot == target then
            return STATUS.FAILURE
        end

        local loco = bot:BotLocomotor()
        if not loco then return STATUS.FAILURE end

        local botPos = bot:GetPos()
        local targetPos = target:GetPos()
        local dist = botPos:Distance(targetPos)

        -- Close enough — stop moving and just look at the target.
        if dist <= FOLLOW_STOP_RANGE then
            -- Don't clear the goal if we're already standing still — just idle.
            -- Only clear if we actually had a goal so the locomotor doesn't thrash.
            if loco:GetGoal() then
                loco:SetGoal(nil)
            end
            loco:LookAt(target:EyePos(), 0.2)
            local state = TTTBots.Behaviors.GetState(bot, "FollowPlan")
            state.stallSamplePos = nil
            state.stallSampleTime = nil
            return STATUS.RUNNING
        end

        -- Use the target's position as the goal.
        -- smartSetGoal will only actually call SetGoal when the target has moved
        -- far enough from the previous goal to warrant a re-path.
        smartSetGoal(bot, targetPos)
        loco:LookAt(target:EyePos(), 0.2)
        maybeRecoverMovement(bot, targetPos)
        return STATUS.RUNNING
    end,
    [ACTIONS.GATHER] = function(bot, job)
        -- set the path to the TargetObj (which is a vec3) and wander around there.
        local origin = job.TargetObj
        if not isvector(origin) then return STATUS.FAILURE end
        local state = TTTBots.Behaviors.GetState(bot, "FollowPlan")
        local loco = bot:BotLocomotor()
        if not loco then return STATUS.FAILURE end

        -- Pick an initial wander point, or a new one when we arrive at the old one.
        if not state.gatherWanderPos then
            state.gatherWanderPos = origin
        end

        local needsNewPos = bot:GetPos():Distance(state.gatherWanderPos) < 80

        if needsNewPos then
            local visible = lib.VisibleNavsInRange(origin, 1000)
            if #visible > 0 then
                local randNav = table.Random(visible)
                state.gatherWanderPos = randNav:GetRandomPoint()
            else
                state.gatherWanderPos = origin
            end
            -- Wander target changed — force the goal update through.
            state.lastSetGoalPos = nil
        end

        lib.CallEveryNTicks(bot, function()
            local visible = lib.VisibleNavsInRange(origin, 1000)
            if #visible > 0 then
                local randNav = table.Random(visible)
                state.gatherWanderPos = randNav:GetRandomPoint()
                state.lastSetGoalPos = nil -- force re-path
            end
        end, TTTBots.Tickrate * 4)

        smartSetGoal(bot, state.gatherWanderPos)
        maybeRecoverMovement(bot, state.gatherWanderPos)
        return STATUS.RUNNING
    end,
    [ACTIONS.IGNORE] = function(bot, job)
        printf("This should not be getting called. Ever. Called by bot %s", bot:Nick())
        return STATUS.FAILURE
    end,
    [ACTIONS.PLANT] = function(bot, job)
        local targetPos = job.TargetObj
        if not isvector(targetPos) then return STATUS.FAILURE end
        local loco = bot:BotLocomotor()
        if not loco then return STATUS.FAILURE end
        if not loco:IsCloseEnough(targetPos) then
            smartSetGoal(bot, targetPos)
            maybeRecoverMovement(bot, targetPos)
            return STATUS.RUNNING
        end
        bot:Give("weapon_ttt_c4")
        return STATUS.SUCCESS
    end,
    [ACTIONS.ROAM] = function(bot, job)
        -- walk directly to the TargetObj (vec3).
        local origin = job.TargetObj
        if not isvector(origin) then return STATUS.FAILURE end

        local state = TTTBots.Behaviors.GetState(bot, "FollowPlan")
        local loco = bot:BotLocomotor()
        if not loco then return STATUS.FAILURE end

        local needsNewPos = not state.roamPos
        if state.roamPos then
            needsNewPos = bot:GetPos():Distance(state.roamPos) < 80
        end

        if needsNewPos then
            local visible = lib.VisibleNavsInRange(origin, 1400)
            if #visible > 0 then
                local randNav = table.Random(visible)
                state.roamPos = randNav:GetRandomPoint()
            else
                state.roamPos = origin
            end
            -- Roam target changed — force the goal update through.
            state.lastSetGoalPos = nil
        end

        smartSetGoal(bot, state.roamPos)
        maybeRecoverMovement(bot, state.roamPos)
        return STATUS.RUNNING
    end,
    --- Coordinated Attack: all assigned traitors converge near the shared target,
    --- then attack simultaneously once enough allies are staged nearby.
    --- Falls back to solo attack after the staging timer expires.
    [ACTIONS.COORD_ATTACK] = function(bot, job)
        local target = job.TargetObj
        if not (IsValid(target) and lib.IsPlayerAlive(target)) then
            return STATUS.FAILURE
        end

        local state = TTTBots.Behaviors.GetState(bot, "FollowPlan")
        local loco = bot:BotLocomotor()
        if not loco then return STATUS.FAILURE end

        local targetPos = target:GetPos()
        local botPos = bot:GetPos()
        local distToTarget = botPos:Distance(targetPos)

        --- How close a traitor must be to the target to count as "staged".
        local STAGE_RADIUS = 800
        --- How many staged allies (including this one) trigger the simultaneous attack.
        --- Only count bots that are actual allies (same team), not just any coordinator.
        --- This prevents a solo traitor from waiting for a necromancer that doesn't
        --- share the same plan.
        local aliveAlliedCoordinators = TTTBots.Lib.FilterTable(TTTBots.Match.AlivePlayers, function(ply)
            return ply:IsBot()
                and TTTBots.Roles.GetRoleFor(ply):GetCanCoordinate()
                and TTTBots.Roles.IsAllies(bot, ply)
        end)
        -- If we're the only allied coordinator, don't wait for anyone — attack solo.
        local convergenceThreshold = 0.45
        local minBotsReady = 2
        local requiredStaged = #aliveAlliedCoordinators <= 1
            and 1
            or math.max(2, math.ceil(#aliveAlliedCoordinators * convergenceThreshold))

        -- Count how many allied coordinators are already near the target.
        local stagedCount = 0
        for _, ally in ipairs(aliveAlliedCoordinators) do
            if not lib.IsPlayerAlive(ally) then continue end
            if ally:GetPos():Distance(targetPos) <= STAGE_RADIUS then
                stagedCount = stagedCount + 1
            end
        end

        -- Initialize staging timer on first tick.
        if not state.coordStagingStart then
            state.coordStagingStart = CurTime()
        end
        -- Track when this bot first entered COORD_ATTACK for the hard timeout.
        if not state.coordAttackStartTime then
            state.coordAttackStartTime = CurTime()
        end

        -- Staging timeout: after 75% of the job duration, attack regardless.
        local jobDuration = (job.MaxDuration or 30)
        local stagingDeadline = state.coordStagingStart + (jobDuration * 0.75)
        local timeExpired = CurTime() >= stagingDeadline

        -- Hard timeout: force attack after 15s of staging regardless of convergence.
        local hardTimeout = (CurTime() - state.coordAttackStartTime) > 15

        -- Enough traitors staged (threshold OR minimum count) OR timer ran out → everyone attacks.
        local enoughConverged = (stagedCount >= requiredStaged) or (stagedCount >= minBotsReady)
        if enoughConverged or timeExpired or hardTimeout then
            -- Seed memory so AttackTarget.Seek has a last-known position.
            local memory = bot.components and bot.components.memory
            if memory and memory:GetLastSeenTime(target) == 0 then
                memory:UpdateKnownPositionFor(target, targetPos)
            end
            bot:SetAttackTarget(target, "COORD_ATTACK_STRIKE", 4)
            return STATUS.RUNNING
        end

        -- Not enough traitors in position yet — keep approaching the target area.
        -- Stay just outside comfortable engagement range so we don't spook the victim.
        -- Mark as non-interruptible during staging so low-priority behaviors
        -- cannot preempt plan execution. Self-defense (priority 5) already
        -- overrides non-interruptible behaviors in sv_tree.lua.
        FollowPlan.Interruptible = false

        local approachPos = targetPos
        if distToTarget <= 400 then
            -- Close enough — hold position and look at target.
            if loco:GetGoal() then
                loco:SetGoal(nil)
            end
            loco:LookAt(target:EyePos(), 0.2)
            state.stallSamplePos = nil
            state.stallSampleTime = nil
            return STATUS.RUNNING
        end

        smartSetGoal(bot, approachPos)
        maybeRecoverMovement(bot, approachPos)
        return STATUS.RUNNING
    end,
}
ACT_RUNNING_HASH[ACTIONS.ATTACK] = ACT_RUNNING_HASH[ACTIONS.ATTACKANY]
--- Called when the behavior's last state is running
function FollowPlan.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "FollowPlan")
    if TTTBots.Match.RoundActive == false then
        state.shouldClear = true
        return STATUS.FAILURE
    end
    if state.Job == nil then
        state.shouldClear = true
        return STATUS.FAILURE
    end
    -- Default to interruptible; the COORD_ATTACK handler will set it to false
    -- when in staging phase. This ensures all other actions remain interruptible.
    FollowPlan.Interruptible = true

    local status = ACT_RUNNING_HASH[state.Job.Action](bot, state.Job)
    if status == STATUS.RUNNING then
        botChatterWhenJobStart(bot, state.Job)
    elseif status == STATUS.FAILURE or status == STATUS.SUCCESS then
        FollowPlan.Interruptible = true -- restore on completion
        state.shouldClear = true
    end
    -- printf("Running job %s for bot %s. Status is %s", state.Job.Action, bot:Nick(), tostring(status))
    return status
end

--- Called when the behavior returns a success state
function FollowPlan.OnSuccess(bot)
    -- Job completed normally — mark for cleanup.
    TTTBots.Behaviors.GetState(bot, "FollowPlan").shouldClear = true
end

--- Called when the behavior returns a failure state
function FollowPlan.OnFailure(bot)
    -- The tree engine also calls OnFailure when the behavior is preempted by a
    -- higher-priority node.  We only want to wipe the job when OnRunning itself
    -- returned FAILURE, not when we were merely interrupted.  OnRunning sets
    -- shouldClear = true before returning FAILURE; preemption does not.
end

--- Called when the behavior ends (could be success, failure, OR interruption).
--- Only clear state when the behavior completed/failed on its own.  If it was
--- preempted, preserve the job so the bot can resume it later instead of
--- fetching a brand-new ATTACKANY every time, which causes a
--- FollowPlan→UseGrenade→Retreat thrashing loop.
function FollowPlan.OnEnd(bot)
    local state = TTTBots.Behaviors.GetState(bot, "FollowPlan")
    -- Always restore interruptibility when the behavior ends.
    FollowPlan.Interruptible = true
    if state.shouldClear then
        TTTBots.Behaviors.ClearState(bot, "FollowPlan")
    else
        -- Interrupted — keep the job but reset tracking so we re-evaluate on resume.
        state.stallSamplePos = nil
        state.stallSampleTime = nil
        state.lastSetGoalPos = nil
        state.lastSetGoalTime = nil
        -- Keep coordStagingStart and coordAttackStartTime so timers survive interruptions.
    end
end

-- Hook for PlayerSay to force give ourselves a follow job if a teammate traitor says in team chat to "follow"
hook.Add("PlayerSay", "TTTBots_FollowPlan_PlayerSay", function(sender, text, teamChat)
    if not TTTBots.Match.IsRoundActive() then return end
    if sender:IsBot() then return end
    -- printf("PlayerSay %s: %s (%s)", sender:Nick(), text, teamChat and "team" or "global")
    if not teamChat then return end
    if not (lib.IsPlayerAlive(sender) and FollowPlan.IsPlanFollowerRole(sender)) then return end
    if not string.find(string.lower(text), "follow", 1, true) then return end

    local bot = TTTBots.Lib.GetClosest(TTTBots.Lib.GetAliveAllies(sender), sender:GetPos())
    ---@cast bot Bot
    if not (bot) then return end
    if not (bot.components and bot.components.chatter) then return end
    local chatter = bot:BotChatter()

    local duration = math.random(25, 60)
    local newJob = {
        Action = ACTIONS.FOLLOW,
        TargetObj = sender,
        State = TTTBots.Plans.BOTSTATES.IDLE,
        MinDuration = 25,
        MaxDuration = 60,
        ExpiryTime = CurTime() + duration
    }
    if bot.components.chatter and bot.components.chatter.On then
        bot.components.chatter:On("FollowRequest", { player = sender:Nick() }, true)
    end

    local state = TTTBots.Behaviors.GetState(bot, "FollowPlan")
    state.followTarget = sender
    state.followEndTime = CurTime() + duration
    state.Job = newJob
    printf("Follow job assigned for %s -> %s", bot:Nick(), sender:Nick())
end)
