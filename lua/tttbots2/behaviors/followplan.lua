
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

function FollowPlan.IsPlanFollowerRole(bot)
    return TTTBots.Roles.GetRoleFor(bot):GetCanCoordinate()
end

--- Ignore plans if we aren't evil or have a conflicting personality trait.
function FollowPlan.ShouldIgnorePlans(bot)
    if not FollowPlan.IsPlanFollowerRole(bot) then return true end
    if not FollowPlan.Debug and bot.components.personality:GetIgnoresOrders() then return true end -- ignore plans if we have a conflicting personality trait

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
    return CurTime() < job.ExpiryTime
end

local ACT_VALIDATION_HASH = {
    [ACTIONS.ATTACKANY] = function(job)
        local target = job.TargetObj
        return IsValid(target) and TTTBots.Lib.IsPlayerAlive(target)
    end,
    [ACTIONS.ATTACK] = function(job)
        local target = job.TargetObj
        return IsValid(target) and TTTBots.Lib.IsPlayerAlive(target)
    end,
    [ACTIONS.DEFEND] = function(job)
        return validateJobTime(job)
    end,
    [ACTIONS.DEFUSE] = function(job)
        return false -- Unimplemented
    end,
    [ACTIONS.FOLLOW] = function(job)
        local target = job.TargetObj
        return IsValid(target) and TTTBots.Lib.IsPlayerAlive(target) and validateJobTime(job)
    end,
    [ACTIONS.GATHER] = function(job)
        return validateJobTime(job)
    end,
    [ACTIONS.IGNORE] = function(job) return true end,
    [ACTIONS.PLANT] = function(job)
        return true
    end,
    [ACTIONS.ROAM] = function(job)
        return validateJobTime(job)
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
    if FollowPlan.GetBotJob(bot) then return true end
    if FollowPlan.ShouldIgnorePlans(bot) then
        if validate_debug then print(string.format("%s ignored plans", bot:Nick())) end
        return false
    end
    if not TTTBots.Plans.SelectedPlan then
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
        -- TODO: Implement properly and auto-attack enemy targets that we can see.
        local targetPos = job.TargetObj
        bot:BotLocomotor():SetGoal(targetPos)
        return STATUS.RUNNING
    end,
    [ACTIONS.DEFUSE] = function(bot, job)
        -- TODO: Implement defusing plan (probably never will do this, as traitors do not need to defuse C4)
        printf("Bot %s attempting to perform unimplemented action DEFUSE", bot:Nick())
        return STATUS.FAILURE
    end,
    [ACTIONS.FOLLOW] = function(bot, job)
        -- set the path goal to the TargetObj's :GetPos location.
        -- TODO: This needs to be more subtle.
        local target = job.TargetObj
        if not IsValid(target) then return STATUS.FAILURE end
        local targetPos = target:GetPos()
        if bot == target then
            return STATUS.FAILURE
        end
        bot:BotLocomotor():SetGoal(targetPos)
        return STATUS.RUNNING
    end,
    [ACTIONS.GATHER] = function(bot, job)
        -- set the patch to the TargetObj (which is a vec3) and wander around there.
        local origin = job.TargetObj
        local state = TTTBots.Behaviors.GetState(bot, "FollowPlan")
        state.gatherWanderPos = state.gatherWanderPos or origin

        lib.CallEveryNTicks(bot, function()
            -- state.gatherWanderPos
            local visible = lib.VisibleNavsInRange(origin, 1000)
            if #visible > 0 then
                local randNav = table.Random(visible)
                local randPos = randNav:GetRandomPoint()
                state.gatherWanderPos = randPos
            end
        end, TTTBots.Tickrate * 4)
        bot:BotLocomotor():SetGoal(state.gatherWanderPos)
        return STATUS.RUNNING
    end,
    [ACTIONS.IGNORE] = function(bot, job)
        printf("This should not be getting called. Ever. Called by bot %s", bot:Nick())
        return STATUS.FAILURE
    end,
    [ACTIONS.PLANT] = function(bot, job)
        bot:Give("weapon_ttt_c4")
        return STATUS.SUCCESS
    end,
    [ACTIONS.ROAM] = function(bot, job)
        -- walk directly to the TargetObj (vec3).
        -- TODO: Make this dynamically change the position so we actually roam.
        local targetPos = job.TargetObj
        bot:BotLocomotor():SetGoal(targetPos)
        return STATUS.RUNNING
    end
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
    local status = ACT_RUNNING_HASH[state.Job.Action](bot, state.Job)
    if status == STATUS.RUNNING then
        botChatterWhenJobStart(bot, state.Job)
    elseif status == STATUS.FAILURE or status == STATUS.SUCCESS then
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
    if state.shouldClear then
        TTTBots.Behaviors.ClearState(bot, "FollowPlan")
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

    local newJob = {
        Action = ACTIONS.FOLLOW,
        TargetObj = sender,
        State = TTTBots.Plans.BOTSTATES.IDLE,
        MinDuration = 25,
        MaxDuration = 60
    }
    if bot.components.chatter and bot.components.chatter.On then
        bot.components.chatter:On("FollowRequest", { player = sender:Nick() }, true)
    end

    local state = TTTBots.Behaviors.GetState(bot, "FollowPlan")
    state.followTarget = sender
    state.followEndTime = CurTime() + math.random(25, 60)
    state.Job = newJob
    printf("Follow job assigned for %s -> %s", bot:Nick(), sender:Nick())
end)
