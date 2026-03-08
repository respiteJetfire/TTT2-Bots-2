--[[
    followinnocentplan.lua
    Behavior node for innocent-side bots to execute jobs assigned by InnocentCoordinator.

    Sits in the innocent / detective behavior trees between Accuse and Investigate,
    so it runs after evidence-driven actions but before unstructured wandering.

    Validate: bot is alive, coordinator is active, bot has (or can get) a job.
    OnRunning: dispatch to per-action handler; return SUCCESS/FAILURE/RUNNING.
]]

TTTBots.Behaviors.FollowInnocentPlan = {}

local lib  = TTTBots.Lib
local IC   = TTTBots.InnocentCoordinator
local FollowInnocentPlan = TTTBots.Behaviors.FollowInnocentPlan
FollowInnocentPlan.Name         = "FollowInnocentPlan"
FollowInnocentPlan.Description  = "Execute an innocent-coordination job (buddy up, patrol, tester queue, perimeter, last stand)."
FollowInnocentPlan.Interruptible = true
FollowInnocentPlan.Debug         = false

local STATUS = TTTBots.STATUS
local ACTIONS = IC and IC.ACTIONS or {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function debugPrint(fmt, ...)
    if FollowInnocentPlan.Debug then
        print(string.format("[FollowInnocentPlan] " .. fmt, ...))
    end
end

--- Returns true if the bot should skip innocent plans (personality / role check).
---@param bot Bot
---@return boolean
local function shouldSkip(bot)
    if not IC.IsParticipant(bot) then return true end
    local personality = bot.components and bot.components.personality
    if personality and personality:GetIgnoresOrders() then return true end
    return false
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Validate
-- ─────────────────────────────────────────────────────────────────────────────

function FollowInnocentPlan.Validate(bot)
    if not lib.IsPlayerAlive(bot) then return false end
    if not TTTBots.Match.PlansCanStart() then return false end
    if not TTTBots.Match.RoundActive then return false end
    if shouldSkip(bot) then return false end
    if not IC.SelectedStrategy then return false end

    -- Already has a valid job?
    local job = IC.GetJobFor(bot)
    if job then return true end

    -- No job yet — IC.Tick() will assign one; we can't start yet
    return false
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Lifecycle
-- ─────────────────────────────────────────────────────────────────────────────

function FollowInnocentPlan.OnStart(bot)
    local job = IC.GetJobFor(bot)
    if not job then return STATUS.FAILURE end
    debugPrint("%s starting job %s", bot:Nick(), tostring(job.Action))
    return STATUS.RUNNING
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Per-action handlers
-- ─────────────────────────────────────────────────────────────────────────────

--- BUDDY_UP: path toward the assigned buddy and stay within 300 units.
local function runBuddyUp(bot, job)
    local buddy = job.TargetObj
    if not (IsValid(buddy) and lib.IsPlayerAlive(buddy)) then
        return STATUS.FAILURE
    end
    local dist = bot:GetPos():Distance(buddy:GetPos())
    if dist <= 300 then
        -- Close enough — briefly register as travel companion
        local evidence = bot.components and bot.components.evidence
        if evidence then evidence:AddTravelCompanion(buddy) end
        return STATUS.SUCCESS
    end
    local loco = bot:BotLocomotor()
    if loco then
        loco:SetGoal(buddy:GetPos())
        loco:LookAt(buddy:GetPos())
    end
    return STATUS.RUNNING
end

--- PATROL_ZONE: wander near the assigned zone centre, regenerating a wander pos every 5 ticks.
local function runPatrolZone(bot, job)
    local origin = job.TargetObj
    if not origin then return STATUS.FAILURE end

    lib.CallEveryNTicks(bot, function()
        local visible = lib.VisibleNavsInRange(origin, 900)
        if #visible > 0 then
            local nav = table.Random(visible)
            job._wanderPos = nav:GetRandomPoint()
        end
    end, TTTBots.Tickrate * 5)

    local goal = job._wanderPos or origin
    local loco = bot:BotLocomotor()
    if loco then loco:SetGoal(goal) end
    return STATUS.RUNNING
end

--- QUEUE_TEST: walk to the tester and wait; bot with queue position 1 uses it immediately.
local function runQueueTest(bot, job)
    local testerPos = job.TargetObj
    if not testerPos then return STATUS.FAILURE end

    local qPos = IC.GetTesterQueuePosition(bot)
    if not qPos then
        -- Already dequeued / tested — done
        return STATUS.SUCCESS
    end

    local distToTester = bot:GetPos():Distance(testerPos)

    if qPos == 1 then
        -- Our turn — walk up and try to use the tester
        local loco = bot:BotLocomotor()
        if loco then loco:SetGoal(testerPos) end
        if distToTester < 80 then
            -- Attempt to interact with the tester entity
            local tester = nil
            for _, ent in ipairs(ents.FindInSphere(testerPos, 100)) do
                if IsValid(ent) and string.find(ent:GetClass(), "ttt_role_checker", 1, true) then
                    tester = ent
                    break
                end
            end
            if tester then
                bot:KeyPress(IN_USE)
                IC.DequeueBot(bot)
                return STATUS.SUCCESS
            end
        end
    else
        -- Wait at a slight offset based on queue position so bots don't stack
        local waitAngle  = (360 / math.max(#IC.TesterQueue, 1)) * (qPos - 1)
        local waitOffset = Vector(
            math.cos(math.rad(waitAngle)) * (80 + qPos * 30),
            math.sin(math.rad(waitAngle)) * (80 + qPos * 30),
            0
        )
        local waitPos = testerPos + waitOffset
        local loco = bot:BotLocomotor()
        if loco then loco:SetGoal(waitPos) end
    end

    return STATUS.RUNNING
end

--- HOLD_PERIMETER: stand at assigned perimeter point and watch.
local function runHoldPerimeter(bot, job)
    local holdPos = job.TargetObj
    if not holdPos then return STATUS.FAILURE end
    local loco = bot:BotLocomotor()
    if loco then
        loco:SetGoal(holdPos)
        -- Look toward the corpse centre
        if IC.PerimeterTarget then
            loco:LookAt(IC.PerimeterTarget)
        end
    end
    return STATUS.RUNNING
end

--- HOLD_LAST_STAND: move to stronghold position; once there, stop moving and face threats.
local function runHoldLastStand(bot, job)
    local stronghold = job.TargetObj
    if not stronghold then return STATUS.FAILURE end

    local dist = bot:GetPos():Distance(stronghold)
    local loco = bot:BotLocomotor()

    if dist > 120 then
        if loco then loco:SetGoal(stronghold) end
        return STATUS.RUNNING
    end

    -- At the stronghold: look toward the nearest non-ally threat
    local threat = nil
    local bestDist = math.huge
    for _, ply in ipairs(TTTBots.Match.AlivePlayers) do
        if not lib.IsPlayerAlive(ply) then continue end
        if IC.IsParticipant(ply) then continue end
        local d = bot:GetPos():Distance(ply:GetPos())
        if d < bestDist then bestDist = d; threat = ply end
    end
    if threat and loco then
        loco:LookAt(threat:GetPos())
    end

    return STATUS.RUNNING
end

--- DEPLOY_CHECKER: detective walks to a strategic spot and fires the role-checker weapon to place it.
local function runDeployChecker(bot, job)
    local deployPos = job.TargetObj
    if not deployPos then return STATUS.FAILURE end

    -- If the checker is already on the map (someone else placed it or a previous attempt succeeded),
    -- or the detective no longer has the weapon, consider the job done.
    if not bot:HasWeapon("weapon_ttt_traitorchecker") then
        IC.DetectiveDeployedChecker = true
        return STATUS.SUCCESS
    end

    local loco = bot:BotLocomotor()
    local dist  = bot:GetPos():Distance(deployPos)

    if dist > 80 then
        if loco then
            loco:SetGoal(deployPos)
            loco:LookAt(deployPos)
        end
        return STATUS.RUNNING
    end

    -- Close enough — equip and fire to place the checker
    bot:SelectWeapon("weapon_ttt_traitorchecker")
    if loco then loco:StartAttack() end
    -- Mark as deployed after a brief placement tick
    if not job._placedAt then
        job._placedAt = CurTime()
    elseif (CurTime() - job._placedAt) > 0.5 then
        if loco then loco:StopAttack() end
        IC.DetectiveDeployedChecker = true
        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("DeployedRoleChecker", {})
        end
        return STATUS.SUCCESS
    end

    return STATUS.RUNNING
end

-- Dispatch table keyed by IC.ACTIONS values
local ACT_RUNNING_HASH = {}

-- Populate after ACTIONS enum is available (deferred by the return value of require)
local function buildDispatch()
    ACT_RUNNING_HASH[IC.ACTIONS.BUDDY_UP]        = runBuddyUp
    ACT_RUNNING_HASH[IC.ACTIONS.PATROL_ZONE]     = runPatrolZone
    ACT_RUNNING_HASH[IC.ACTIONS.QUEUE_TEST]      = runQueueTest
    ACT_RUNNING_HASH[IC.ACTIONS.HOLD_PERIMETER]  = runHoldPerimeter
    ACT_RUNNING_HASH[IC.ACTIONS.HOLD_LAST_STAND] = runHoldLastStand
    ACT_RUNNING_HASH[IC.ACTIONS.DEPLOY_CHECKER]  = runDeployChecker
end

-- ─────────────────────────────────────────────────────────────────────────────
-- OnRunning
-- ─────────────────────────────────────────────────────────────────────────────

function FollowInnocentPlan.OnRunning(bot)
    if not TTTBots.Match.RoundActive then return STATUS.FAILURE end

    -- Build dispatch table lazily (ensures IC is fully loaded)
    if not next(ACT_RUNNING_HASH) then buildDispatch() end

    local job = IC.GetJobFor(bot)
    if not job then return STATUS.FAILURE end

    -- Expiry check
    if job.ExpiryTime and CurTime() > job.ExpiryTime then
        IC.ClearJobFor(bot)
        return STATUS.FAILURE
    end

    local handler = ACT_RUNNING_HASH[job.Action]
    if not handler then
        debugPrint("%s has unknown action %s", bot:Nick(), tostring(job.Action))
        IC.ClearJobFor(bot)
        return STATUS.FAILURE
    end

    return handler(bot, job)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Lifecycle callbacks
-- ─────────────────────────────────────────────────────────────────────────────

function FollowInnocentPlan.OnSuccess(bot)
    IC.ClearJobFor(bot)
end

function FollowInnocentPlan.OnFailure(bot)
    IC.ClearJobFor(bot)
end

function FollowInnocentPlan.OnEnd(bot)
    -- Intentionally do NOT clear the job here — IC.Tick() manages lifetime.
    -- This lets the behavior be restarted on the next tick with the same job.
end
