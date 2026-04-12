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
local FollowInnocentPlan = TTTBots.Behaviors.FollowInnocentPlan
FollowInnocentPlan.Name         = "FollowInnocentPlan"
FollowInnocentPlan.Description  = "Execute an innocent-coordination job (buddy up, patrol, tester queue, perimeter, last stand)."
FollowInnocentPlan.Interruptible = true
FollowInnocentPlan.Debug         = false

local STATUS = TTTBots.STATUS

--- Lazy accessor — InnocentCoordinator is server-only and may not exist at file-load time.
local function getIC()
    return TTTBots.InnocentCoordinator
end

--- Lazy accessor for the ACTIONS enum.
local function getACTIONS()
    local ic = TTTBots.InnocentCoordinator
    return ic and ic.ACTIONS or {}
end

--- Lazy accessor for the round-phase enum.
local function getPHASE()
    return TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
end

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
    local IC = getIC()
    if not IC then return true end
    if not IC.IsParticipant(bot) then return true end
    local personality = bot.components and bot.components.personality
    if personality and personality:GetIgnoresOrders() then
        -- Don't hard-disable innocent coordination for "ignore orders" personalities.
        -- Use phase-scaled compliance so they eventually commit instead of fallback-cycling.
        local complianceChance = 0.15
        local ra = bot.BotRoundAwareness and bot:BotRoundAwareness()
        local PHASE = getPHASE()
        if ra and PHASE then
            local phase = ra:GetPhase()
            if phase == PHASE.MID then complianceChance = 0.35
            elseif phase == PHASE.LATE then complianceChance = 0.60
            elseif phase == PHASE.OVERTIME then complianceChance = 0.85 end
        end
        if math.random() > complianceChance then return true end
    end
    return false
end

--- Snap a desired goal to a nearby reachable nav point and set locomotor goal.
--- Returns true if a usable goal was set.
---@param bot Bot
---@param desired Vector
---@return boolean
local function setReachableGoal(bot, desired)
    if not isvector(desired) then return false end
    local loco = bot:BotLocomotor()
    if not loco then return false end

    local nav = navmesh.GetNearestNavArea(desired)
    if nav then
        loco:SetGoal(nav:GetClosestPointOnArea(desired) or nav:GetCenter())
        return true
    end

    local fallback = navmesh.GetNearestNavArea(bot:GetPos())
    if fallback then
        loco:SetGoal(fallback:GetCenter())
        return true
    end

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
    local IC = getIC()
    if not IC then return false end
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
    local IC = getIC()
    if not IC then return STATUS.FAILURE end
    local job = IC.GetJobFor(bot)
    if not job then return STATUS.FAILURE end
    debugPrint("%s starting job %s", bot:Nick(), tostring(job.Action))
    return STATUS.RUNNING
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Per-action handlers
-- ─────────────────────────────────────────────────────────────────────────────

--- BUDDY_UP: path toward the assigned buddy and stay within 200 units.
--- Keeps running rather than succeeding so the bot doesn't go jobless.
local function runBuddyUp(bot, job)
    local buddy = job.TargetObj
    if not (IsValid(buddy) and lib.IsPlayerAlive(buddy)) then
        return STATUS.FAILURE
    end
    local dist = bot:GetPos():Distance(buddy:GetPos())

    -- Register as travel companion when nearby
    if dist <= 250 then
        local evidence = bot.components and bot.components.evidence
        if evidence and evidence.AddTravelCompanion then
            evidence:AddTravelCompanion(buddy)
        end
        -- Don't return SUCCESS — let the job expire naturally so the bot keeps following
        return STATUS.RUNNING
    end

    local loco = bot:BotLocomotor()
    if loco then
        setReachableGoal(bot, buddy:GetPos())
        loco:LookAt(buddy:GetPos())
    end
    return STATUS.RUNNING
end

--- PATROL_ZONE: wander near the assigned zone centre.
--- Picks a new wander position every ~4s or once the bot gets close to the current one.
local function runPatrolZone(bot, job)
    local origin = job.TargetObj
    if not origin then return STATUS.FAILURE end

    local botPos = bot:GetPos()

    -- Re-roll wander position if we've arrived or don't have one yet
    local needsNewPos = not job._wanderPos
    if job._wanderPos then
        local distToWander = botPos:Distance(job._wanderPos)
        needsNewPos = distToWander < 80
    end

    if needsNewPos then
        -- Pick a random nav area within 900 units of the zone centre for broad coverage
        local searchRadius = 900
        local nav = navmesh.GetNearestNavArea(origin + Vector(
            math.random(-searchRadius, searchRadius),
            math.random(-searchRadius, searchRadius),
            0
        ))
        if nav then
            job._wanderPos = nav:GetRandomPoint()
        else
            job._wanderPos = origin
        end
    end

    local goal = job._wanderPos or origin
    setReachableGoal(bot, goal)
    return STATUS.RUNNING
end

--- QUEUE_TEST: walk to the tester and wait; bot with queue position 1 uses it immediately.
local function runQueueTest(bot, job)
    local IC = getIC()
    if not IC then return STATUS.FAILURE end
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
        setReachableGoal(bot, testerPos)
        if distToTester < 80 then
            -- Attempt to interact with the tester entity
            -- Support both ttt_traitorchecker (DiskFragger's checker) and ttt_role_checker
            local tester = nil
            for _, ent in ipairs(ents.FindInSphere(testerPos, 100)) do
                if IsValid(ent) then
                    local cls = ent:GetClass()
                    if cls == "ttt_traitorchecker" or cls == "ttt_role_checker" then
                        tester = ent
                        break
                    end
                end
            end
            if tester then
                -- Make the bot look directly at the tester entity before using it
                -- (the tester's Use function checks the player's eye trace)
                local loco = bot:BotLocomotor()
                if loco then loco:LookAt(tester:GetPos()) end
                tester:Use(bot, bot, USE_ON, 0)
                -- Mark as checked so bots don't re-queue via UseRoleChecker
                TTTBots.Match.CheckedPlayers[bot] = TTTBots.Match.CheckedPlayers[bot] or {}
                TTTBots.Match.CheckedPlayers[bot][bot:GetSubRole()] = true

                -- Determine the tester result based on the bot's actual team
                local isInnocent = (bot:GetTeam() == TEAM_INNOCENT)
                local resultStr = isInnocent and "innocent" or "traitor"

                -- Fire the hook so nearby bots update their suspicion/memory
                hook.Run("TTTBots.UseRoleChecker.Result", bot, bot, resultStr)

                -- If innocent: update own suspicion, evidence, memory
                if isInnocent then
                    local morality = bot:BotMorality()
                    if morality then
                        morality:SetTestedClean(bot)
                    end

                    local evidence = bot:BotEvidence()
                    if evidence then
                        evidence:ConfirmInnocent(bot, "passed_role_tester_self")
                    end

                    local mem = bot:BotMemory()
                    if mem then
                        mem:AddWitnessEvent("tester", bot:Nick() .. " passed the role tester and is confirmed innocent")
                    end

                    local chatter = bot:BotChatter()
                    if chatter and chatter.On then
                        chatter:On("DeclareInnocent", { player = bot:Nick() })
                    end
                end

                IC.DequeueBot(bot)
                IC.ClearJobFor(bot)
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
        local distToWait = bot:GetPos():Distance(waitPos)

        if distToWait > 80 then
            -- Still walking to the wait spot
            setReachableGoal(bot, waitPos)
        else
            -- Already at the wait spot — stop moving and look toward the tester
            -- so the bot looks natural (watching the queue) rather than frozen.
            local loco = bot:BotLocomotor()
            if loco then
                loco:SetGoal()  -- clear goal so locomotor doesn't fight itself
                loco:LookAt(testerPos)
            end
        end
    end

    return STATUS.RUNNING
end

--- HOLD_PERIMETER: stand at assigned perimeter point and watch.
local function runHoldPerimeter(bot, job)
    local IC = getIC()
    local holdPos = job.TargetObj
    if not holdPos then return STATUS.FAILURE end
    local loco = bot:BotLocomotor()
    if loco then
        setReachableGoal(bot, holdPos)
        -- Look toward the corpse centre
        if IC and IC.PerimeterTarget then
            loco:LookAt(IC.PerimeterTarget)
        end
    end
    return STATUS.RUNNING
end

--- HOLD_LAST_STAND: move to stronghold position; once there, stop moving and face threats.
local function runHoldLastStand(bot, job)
    local IC = getIC()
    local stronghold = job.TargetObj
    if not stronghold then return STATUS.FAILURE end

    local dist = bot:GetPos():Distance(stronghold)
    local loco = bot:BotLocomotor()

    if dist > 120 then
        setReachableGoal(bot, stronghold)
        return STATUS.RUNNING
    end

    -- At the stronghold: look toward the nearest non-ally threat
    local threat = nil
    local bestDist = math.huge
    for _, ply in ipairs(TTTBots.Match.AlivePlayers) do
        if not lib.IsPlayerAlive(ply) then continue end
        if IC and IC.IsParticipant(ply) then continue end
        local d = bot:GetPos():Distance(ply:GetPos())
        if d < bestDist then bestDist = d; threat = ply end
    end
    if threat and loco then
        loco:LookAt(threat:GetPos())
    end

    return STATUS.RUNNING
end

--- INVESTIGATE_AREA: detective actively searches an unpopular/quiet area.
--- Navigates to the target, looks around upon arrival, then succeeds.
--- 🟢 12: Personality-modulated search behavior.
local function runInvestigateArea(bot, job)
    local target = job.TargetObj
    if not target then return STATUS.FAILURE end

    local dist = bot:GetPos():Distance(target)
    local loco = bot:BotLocomotor()

    if dist > 150 then
        -- 🟢 12: Talkative archetypes announce their investigation
        if not job._investigateAnnounced then
            local personality = bot.components and bot.components.personality
            local archetype = personality and personality:GetClosestArchetype() or "Default"
            local A = TTTBots.Archetypes
            local chatter = bot:BotChatter()
            if chatter and chatter.On and (archetype == A.Tryhard or archetype == A.Hothead
                or archetype == A.Teamer or archetype == A.Nice) then
                chatter:On("InvestigateNoise", {}, false, 0)
            end
            job._investigateAnnounced = true
        end
        setReachableGoal(bot, target)
        return STATUS.RUNNING
    end

    -- Arrived: look around to simulate searching the area
    if not job._arrivedAt then
        job._arrivedAt = CurTime()
    end

    -- 🟢 12: Search radius and linger time vary by archetype
    local personality = bot.components and bot.components.personality
    local archetype = personality and personality:GetClosestArchetype() or "Default"
    local A = TTTBots.Archetypes
    local searchRadius = 300
    local lingerTime = 3
    if archetype == A.Tryhard or archetype == A.Hothead then
        searchRadius = 400
        lingerTime = 4  -- thorough search
    elseif archetype == A.Stoic then
        searchRadius = 350
        lingerTime = 5  -- very methodical
    elseif archetype == A.Dumb then
        searchRadius = 150
        lingerTime = 2  -- barely looks around
    elseif archetype == A.Casual then
        searchRadius = 200
        lingerTime = 2  -- doesn't care much
    end

    if loco then
        local lookOffset = Vector(math.random(-searchRadius, searchRadius), math.random(-searchRadius, searchRadius), 60)
        loco:LookAt(target + lookOffset)
    end

    if (CurTime() - job._arrivedAt) > lingerTime then
        return STATUS.SUCCESS
    end

    return STATUS.RUNNING
end

--- GUARD_TESTER: detective stays near the tester to supervise testing.
--- Watches for suspicious behavior and looks at whoever is currently using the tester.
--- 🟢 12: Personality-modulated leadership chatter while guarding.
local function runGuardTester(bot, job)
    local IC = getIC()
    if not IC then return STATUS.FAILURE end
    local testerPos = job.TargetObj
    if not testerPos then return STATUS.FAILURE end

    -- Refresh tester position in case it moved or was re-discovered
    local freshPos = IC._FindTesterPos()
    if freshPos then testerPos = freshPos end

    local dist = bot:GetPos():Distance(testerPos)
    local loco = bot:BotLocomotor()

    -- Stand ~100-200 units from the tester (close enough to watch, not blocking)
    if dist > 200 then
        setReachableGoal(bot, testerPos)
        return STATUS.RUNNING
    elseif dist < 80 then
        -- Too close, step back slightly
        local backoff = (bot:GetPos() - testerPos):GetNormalized() * 150
        setReachableGoal(bot, testerPos + backoff)
        return STATUS.RUNNING
    end

    -- Watch the tester area: look at whoever is near the tester (queue position 1)
    if loco then
        local watchTarget = nil
        if IC.TesterQueue and #IC.TesterQueue > 0 then
            local firstInQueue = IC.TesterQueue[1]
            if IsValid(firstInQueue) and lib.IsPlayerAlive(firstInQueue) then
                watchTarget = firstInQueue:GetPos()
            end
        end
        loco:LookAt(watchTarget or testerPos)
    end

    -- 🟢 12: Leadership chatter — periodically prompt players to use the tester.
    -- Frequency depends on personality archetype.
    if not bot._guardChatterNext then bot._guardChatterNext = CurTime() + 5 end
    if CurTime() >= bot._guardChatterNext then
        local personality = bot.components and bot.components.personality
        local archetype = personality and personality:GetClosestArchetype() or "Default"
        local A = TTTBots.Archetypes
        local chatter = bot:BotChatter()

        -- Determine chatter interval based on archetype
        local interval = 25  -- default
        if archetype == A.Teamer or archetype == A.Tryhard then
            interval = 15  -- chatty leaders, frequent callouts
        elseif archetype == A.Hothead then
            interval = 18  -- impatient, demands compliance
        elseif archetype == A.Stoic then
            interval = 40  -- rarely speaks, lets actions speak
        elseif archetype == A.Nice then
            interval = 20  -- politely encourages testing
        elseif archetype == A.Casual then
            interval = 35  -- low-energy
        elseif archetype == A.Dumb then
            interval = 30  -- forgets to call out
        end

        if chatter and chatter.On then
            if IC.TesterQueue and #IC.TesterQueue > 0 and IsValid(IC.TesterQueue[1]) then
                chatter:On("RequestRoleCheck", { player = IC.TesterQueue[1]:Nick() }, false, 0)
            end
        end
        bot._guardChatterNext = CurTime() + interval
    end

    return STATUS.RUNNING
end

--- DEPLOY_CHECKER: detective walks to a strategic spot and fires the role-checker weapon to place it.
local DEPLOY_CHECKER_TIMEOUT = 12 -- seconds before giving up on placement

local function runDeployChecker(bot, job)
    local deployPos = job.TargetObj
    if not deployPos then return STATUS.FAILURE end

    -- If the checker is already on the map (someone else placed it or a previous attempt succeeded),
    -- or the detective no longer has the weapon, consider the job done.
    if not bot:HasWeapon("weapon_ttt_traitorchecker") then
        IC.DetectiveDeployedChecker = true
        -- Invalidate tester cache so the coordinator discovers the newly placed entity
        IC._cachedTesterPos = nil
        IC._testerCacheTime = 0
        -- Force strategy re-evaluation so TesterQueue activates immediately
        IC.SelectedStrategy = nil
        local loco = bot:BotLocomotor()
        if loco then loco:StopAttack() end
        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("DeployedRoleChecker", {})
        end
        return STATUS.SUCCESS
    end

    -- Safety: give up after timeout so the detective doesn't get stuck.
    if not job._deployStartedAt then
        job._deployStartedAt = CurTime()
    elseif (CurTime() - job._deployStartedAt) > DEPLOY_CHECKER_TIMEOUT then
        local loco = bot:BotLocomotor()
        if loco then loco:StopAttack() end
        return STATUS.FAILURE
    end

    local loco = bot:BotLocomotor()
    local dist  = bot:GetPos():Distance(deployPos)

    if dist > 80 then
        if loco then
            setReachableGoal(bot, deployPos)
            loco:LookAt(deployPos)
        end
        return STATUS.RUNNING
    end

    -- Close enough — equip the weapon and aim at the ground to place.
    bot:SelectWeapon("weapon_ttt_traitorchecker")
    if loco then
        -- Look at a point on the ground ahead so the placement trace succeeds.
        local eyePos = bot:EyePos()
        local fwd = bot:GetForward()
        local groundTarget = eyePos + fwd * 80 - Vector(0, 0, 40)
        loco:LookAt(groundTarget, 2)
        loco:StartAttack()
    end

    -- Keep running — we succeed once HasWeapon becomes false (weapon consumed by placement).
    return STATUS.RUNNING
end

-- Dispatch table keyed by IC.ACTIONS values
local ACT_RUNNING_HASH = {}

-- Populate after ACTIONS enum is available (deferred by the return value of require)
local function buildDispatch()
    local ACTIONS = getACTIONS()
    ACT_RUNNING_HASH[ACTIONS.BUDDY_UP]        = runBuddyUp
    ACT_RUNNING_HASH[ACTIONS.PATROL_ZONE]     = runPatrolZone
    ACT_RUNNING_HASH[ACTIONS.QUEUE_TEST]      = runQueueTest
    ACT_RUNNING_HASH[ACTIONS.HOLD_PERIMETER]  = runHoldPerimeter
    ACT_RUNNING_HASH[ACTIONS.HOLD_LAST_STAND] = runHoldLastStand
    ACT_RUNNING_HASH[ACTIONS.DEPLOY_CHECKER]  = runDeployChecker
    ACT_RUNNING_HASH[ACTIONS.INVESTIGATE_AREA] = runInvestigateArea
    ACT_RUNNING_HASH[ACTIONS.GUARD_TESTER]    = runGuardTester
end

-- ─────────────────────────────────────────────────────────────────────────────
-- OnRunning
-- ─────────────────────────────────────────────────────────────────────────────

function FollowInnocentPlan.OnRunning(bot)
    if not TTTBots.Match.RoundActive then return STATUS.FAILURE end

    local IC = getIC()
    if not IC then return STATUS.FAILURE end

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
    local IC = getIC()
    if IC then IC.ClearJobFor(bot) end
end

function FollowInnocentPlan.OnFailure(bot)
    local IC = getIC()
    if IC then IC.ClearJobFor(bot) end
end

function FollowInnocentPlan.OnEnd(bot)
    -- Intentionally do NOT clear the job here — IC.Tick() manages lifetime.
    -- This lets the behavior be restarted on the next tick with the same job.
    bot._guardChatterNext = nil  -- 🟢 12: cleanup guard-tester chatter timer
end
