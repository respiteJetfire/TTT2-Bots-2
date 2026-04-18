--[[
    sv_innocentcoordinator.lua
    Innocent-side strategic coordination, parallel to PlanCoordinator but for TEAM_INNOCENT
    (and DetectiveLike roles).

    Strategies:
      "BuddySystem"   — Pair up bots with a nearby confirmed innocent / travel companion
      "PatrolRoutes"  — Divide map into zones (popular / unpopular navs), assign coverage
      "TesterQueue"   — Organise orderly role-checker use; detective issues the queue
      "BodyRecovery"  — Form a perimeter around a freshly-found corpse
      "LastStand"     — Turtle in the most defensible spot when innocents are critically low

    Detective Leadership actions emitted as chatter events:
      IC.DETECTIVE_ACTIONS = { GROUPUP, ASSIGN_TEST, DISPATCH_INVESTIGATE, KOS_AUTHORITATIVE }

    Only roles with GetCanCoordinateInnocent() == true participate. This excludes
    non-innocent allies (jesters, neutral killers) by design.
]]

TTTBots.InnocentCoordinator = TTTBots.InnocentCoordinator or {}
local IC = TTTBots.InnocentCoordinator
local lib = TTTBots.Lib

-- ─────────────────────────────────────────────────────────────────────────────
-- Constants & enums
-- ─────────────────────────────────────────────────────────────────────────────

IC.STRATEGIES = {
    BUDDY_SYSTEM   = "BuddySystem",
    PATROL_ROUTES  = "PatrolRoutes",
    TESTER_QUEUE   = "TesterQueue",
    BODY_RECOVERY  = "BodyRecovery",
    LAST_STAND     = "LastStand",
}

IC.BOTSTATES = {
    IDLE       = "Idle",
    INPROGRESS = "InProgress",
    FINISHED   = "Finished",
}

-- Job actions consumed by the FollowInnocentPlan behavior
IC.ACTIONS = {
    BUDDY_UP        = "BuddyUp",       -- Path toward and stay near a buddy
    PATROL_ZONE     = "PatrolZone",    -- Wander through an assigned nav zone
    QUEUE_TEST      = "QueueTest",     -- Walk to tester and wait for turn
    HOLD_PERIMETER  = "HoldPerimeter", -- Guard a position near a corpse
    HOLD_LAST_STAND = "HoldLastStand", -- Defend a stronghold position
    DEPLOY_CHECKER  = "DeployChecker", -- Detective deploys role-checker device at a strategic spot
    INVESTIGATE_AREA = "InvestigateArea", -- Detective searches an unpopular/quiet map area
    GUARD_TESTER    = "GuardTester",   -- Detective stays near the deployed tester to supervise testing
}

-- Detective-issued leadership signals (emitted as chatter events)
IC.DETECTIVE_ACTIONS = {
    GROUPUP              = "IC_GroupUp",
    ASSIGN_TEST          = "IC_AssignTest",
    DISPATCH_INVESTIGATE = "IC_DispatchInvestigate",
    KOS_AUTHORITATIVE    = "IC_KOSAuthoritative",
}

-- ─────────────────────────────────────────────────────────────────────────────
-- State
-- ─────────────────────────────────────────────────────────────────────────────

IC.SelectedStrategy      = nil   -- The active strategy table, nil when no round active
IC.BotJobs               = {}    -- [bot] = job table
IC.BuddyPairs            = {}    -- [bot] = buddy player (mutual)
IC.TesterQueue           = {}    -- Ordered list of bots waiting to use the tester
IC.PerimeterTarget       = nil   -- Vector — center of current body-recovery perimeter
IC.LastStandPosition     = nil   -- Vector — best defensible spot this round
IC.DetectiveDeployedChecker = false -- Whether the detective has already deployed a role checker this round

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers — participant filtering
-- ─────────────────────────────────────────────────────────────────────────────

--- Returns true if `ply` should participate in innocent coordination.
--- Requires GetCanCoordinateInnocent() == true AND alive AND on TEAM_INNOCENT.
--- This explicitly excludes non-innocent allies (jesters, neutral killers, etc.)
---@param ply Player
---@return boolean
function IC.IsParticipant(ply)
    if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then return false end
    local role = TTTBots.Roles.GetRoleFor(ply)
    if not role then return false end
    -- Must be flagged for innocent coordination AND strictly on the innocent team
    return role:GetCanCoordinateInnocent() == true and ply:GetTeam() == TEAM_INNOCENT
end

--- Returns all alive bots that can participate in innocent coordination.
---@return table<Bot>
function IC.GetParticipantBots()
    local result = {}
    for _, bot in ipairs(TTTBots.Bots) do
        if IC.IsParticipant(bot) then
            table.insert(result, bot)
        end
    end
    return result
end

--- Returns the first alive detective-role bot, or nil.
---@return Bot|nil
function IC.GetDetectiveBot()
    for _, bot in ipairs(TTTBots.Bots) do
        if not lib.IsPlayerAlive(bot) then continue end
        local role = TTTBots.Roles.GetRoleFor(bot)
        if role and role:GetAppearsPolice() then
            return bot
        end
    end
    return nil
end

--- Returns true if a human detective is alive (bots follow human detective directives more eagerly)
---@return Player|nil
function IC.GetHumanDetective()
    for _, ply in ipairs(TTTBots.Match.AlivePlayers) do
        if ply:IsBot() then continue end
        local role = TTTBots.Roles.GetRoleFor(ply)
        if role and role:GetAppearsPolice() then return ply end
    end
    return nil
end

--- Returns true if the detective bot is alive and carries an undeployed role-checker weapon.
---@return Bot|nil detectiveBot or nil
function IC.GetDetectiveBotWithChecker()
    if IC.DetectiveDeployedChecker then return nil end
    local det = IC.GetDetectiveBot()
    if not det then return nil end
    if det:HasWeapon("weapon_ttt_traitorchecker") then return det end
    return nil
end

--- Returns alive alive innocent player count (humans + bots, coordinator-eligible only)
---@return number
function IC.GetParticipantCount()
    local count = 0
    for _, ply in ipairs(TTTBots.Match.AlivePlayers) do
        if IC.IsParticipant(ply) then count = count + 1 end
    end
    return count
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Strategy selection
-- ─────────────────────────────────────────────────────────────────────────────

--- Select the appropriate strategy based on current game state.
---@return string strategyName one of IC.STRATEGIES
function IC.SelectStrategy()
    local S = IC.STRATEGIES
    local nParticipants = IC.GetParticipantCount()

    -- Last Stand: only when critically outnumbered — 1 innocent remaining, or
    -- 2 innocents vs at least 2 estimated traitors. Avoids freezing mid-round.
    local nExpectedTraitors = TTTBots.Match.GetExpectedRemainingTraitors
        and TTTBots.Match.GetExpectedRemainingTraitors() or 0
    if nParticipants <= 1
        or (nParticipants <= 2 and nExpectedTraitors >= 2)
    then
        return S.LAST_STAND
    end

    -- Body Recovery: a body was recently found (within 15 seconds)
    if IC.PerimeterTarget and (CurTime() - (IC.PerimeterActivatedAt or 0)) < 15 then
        return S.BODY_RECOVERY
    end

    -- Tester Queue: if a role checker exists on the map OR the detective still
    -- needs to deploy one, organise bots into an orderly testing queue.
    -- This takes priority over patrol when a tester is available — but only
    -- while there are still untested bots waiting.  Once the queue empties
    -- (everyone has been tested), fall through to patrol so bots don't idle.
    local testerExists = IC._FindTesterPos() ~= nil
    local detNeedsDeploy = IC.GetDetectiveBotWithChecker() ~= nil
    if testerExists or detNeedsDeploy then
        -- Count bots that still need testing
        local participants = IC.GetParticipantBots()
        local needsTest = 0
        for _, bot in ipairs(participants) do
            local role = bot.GetSubRole and bot:GetSubRole()
            local alreadyChecked = TTTBots.Match.CheckedPlayers[bot]
                and (role == nil or TTTBots.Match.CheckedPlayers[bot][role])
            local evidence = bot.components and bot.components.evidence
            local alreadyConfirmed = evidence and evidence.trustNetwork
                and evidence.trustNetwork.confirmedInnocent[bot] ~= nil
            if not alreadyChecked and not alreadyConfirmed then
                needsTest = needsTest + 1
            end
        end
        if needsTest > 0 or detNeedsDeploy then
            return S.TESTER_QUEUE
        end
        -- Queue is empty — fall through to patrol
    end

    -- 200-damage knife mod awareness: when installed, innocents should spread
    -- out and patrol aggressively.  Grouped-up innocents are easy knife targets
    -- (one stab kills).  Prefer patrol over buddy system at lower thresholds.
    local knifeModActive = TTTBots.Behaviors and TTTBots.Behaviors.KnifeStalk
        and TTTBots.Behaviors.KnifeStalk.IsKnifeModInstalled
        and TTTBots.Behaviors.KnifeStalk.IsKnifeModInstalled()

    -- Patrol Routes: primary active strategy — keeps bots moving around the map.
    -- With knife mod: patrol even with just 2 participants (spread out is safer).
    -- Without knife mod: patrol with 3+ participants.
    local patrolThreshold = knifeModActive and 2 or 3
    if nParticipants >= patrolThreshold then
        return S.PATROL_ROUTES
    end

    -- Default fallback for very small innocent teams: pair up and move together
    return S.BUDDY_SYSTEM
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Tester location finder
-- ─────────────────────────────────────────────────────────────────────────────

IC._cachedTesterPos = nil
IC._testerCacheTime = 0

--- Find the world position of a role-checker entity, with 10s cache.
--- Supports both custom ttt_traitorchecker and any future ttt_role_checker entities.
---@return Vector|nil
function IC._FindTesterPos()
    if (CurTime() - IC._testerCacheTime) < 10 and IC._cachedTesterPos then
        return IC._cachedTesterPos
    end
    -- Search for known role-checker / tester entity classes
    local checkerClasses = {
        "ttt_traitorchecker",
        "ttt_role_checker",
    }
    for _, cls in ipairs(checkerClasses) do
        for _, ent in ipairs(ents.FindByClass(cls)) do
            if IsValid(ent) then
                IC._cachedTesterPos  = ent:GetPos()
                IC._testerCacheTime  = CurTime()
                return IC._cachedTesterPos
            end
        end
    end
    IC._cachedTesterPos = nil
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Role-checker deployment position finder
-- ─────────────────────────────────────────────────────────────────────────────

IC._cachedCheckerDeployPos  = nil
IC._checkerDeployPosTime    = 0

--- Find a good position to place the role-checker device.
--- Prefers the most popular nav area (high foot-traffic) so many players can use it.
---@return Vector
function IC._FindCheckerDeployPos()
    if (CurTime() - IC._checkerDeployPosTime) < 30 and IC._cachedCheckerDeployPos then
        return IC._cachedCheckerDeployPos
    end
    local popular = TTTBots.Lib.GetTopNPopularNavs and TTTBots.Lib.GetTopNPopularNavs(1) or {}
    if popular[1] then
        local nav = navmesh.GetNavAreaByID(popular[1][1])
        if nav then
            IC._cachedCheckerDeployPos = nav:GetCenter()
            IC._checkerDeployPosTime   = CurTime()
            return IC._cachedCheckerDeployPos
        end
    end
    -- Fallback: use the current detective bot's position
    local det = IC.GetDetectiveBot()
    if det then
        IC._cachedCheckerDeployPos = det:GetPos()
        IC._checkerDeployPosTime   = CurTime()
        return IC._cachedCheckerDeployPos
    end
    return Vector(0, 0, 0)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Defensible-position finder (Last Stand)
-- ─────────────────────────────────────────────────────────────────────────────

--- Returns the best defensible Vector on the map for a last-stand position.
--- Uses hiding spots from sv_spots; falls back to a popular nav centre.
---@return Vector|nil
function IC._FindDefensiblePosition()
    if IC.LastStandPosition then return IC.LastStandPosition end

    local hiding = TTTBots.Spots and TTTBots.Spots.GetSpotsInCategory("hiding") or {}
    if #hiding > 0 then
        -- Prefer spots far from known danger zones
        local best, bestScore = nil, -math.huge
        for _, pos in ipairs(hiding) do
            -- Simple score: distance from centroid of all alive traitor threats
            local score = 0
            for _, ply in ipairs(TTTBots.Match.AlivePlayers) do
                if not IC.IsParticipant(ply) and lib.IsPlayerAlive(ply) then
                    score = score + pos:Distance(ply:GetPos())
                end
            end
            if score > bestScore then
                bestScore = score
                best = pos
            end
        end
        if best then
            IC.LastStandPosition = best
            return best
        end
    end

    -- Fallback: nearest hiding nav centre
    local topUnpop = TTTBots.Lib.GetTopNUnpopularNavs and TTTBots.Lib.GetTopNUnpopularNavs(1) or {}
    if topUnpop[1] then
        local nav = navmesh.GetNavAreaByID(topUnpop[1][1])
        if nav then
            IC.LastStandPosition = nav:GetCenter()
            return IC.LastStandPosition
        end
    end

    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Patrol zone assignment
-- ─────────────────────────────────────────────────────────────────────────────

IC._patrolZones = {}  -- [bot] = { center = Vector, radius = number }

--- Divide the map into N zones and assign one to each bot.
--- Maximizes distance between assigned zones so bots spread across the map.
--- When the 200-damage knife mod is detected, the zone radius is expanded and
--- more candidate nav areas are considered for wider spread.
---@param bots table<Bot>
function IC._AssignPatrolZones(bots)
    IC._patrolZones = {}
    local n = #bots
    if n == 0 then return end

    -- 200-damage knife mod: wider patrol radius to avoid clustering
    local knifeModActive = TTTBots.Behaviors and TTTBots.Behaviors.KnifeStalk
        and TTTBots.Behaviors.KnifeStalk.IsKnifeModInstalled
        and TTTBots.Behaviors.KnifeStalk.IsKnifeModInstalled()
    local zoneRadius = knifeModActive and 1200 or 800
    local candidateCount = knifeModActive and 80 or 60

    -- Build a large pool of candidate nav centres from the whole nav mesh.
    -- Mix popular (high-traffic) and random navs for good coverage.
    local popular = TTTBots.Lib.GetTopNPopularNavs and TTTBots.Lib.GetTopNPopularNavs(math.min(n * 2, 20)) or {}
    local centres = {}
    for _, entry in ipairs(popular) do
        local nav = navmesh.GetNavAreaByID(entry[1])
        if nav then table.insert(centres, nav:GetCenter()) end
    end

    -- Pad with random nav areas spread across the map
    local allNavs = navmesh.GetAllNavAreas and navmesh.GetAllNavAreas() or {}
    for i = 1, math.min(#allNavs, candidateCount) do
        local nav = allNavs[math.random(#allNavs)]
        if nav then table.insert(centres, nav:GetCenter()) end
    end

    -- Greedy assignment: each bot picks the candidate that is farthest from
    -- all previously-assigned zones, ensuring maximum spread across the map.
    local used = {}
    local assignedCentres = {}  -- List of already-assigned zone centres
    for _, bot in ipairs(bots) do
        local best, bestScore = nil, -math.huge
        for i, centre in ipairs(centres) do
            if used[i] then continue end
            -- Score = minimum distance to any already-assigned zone
            -- Higher is better (farther from other bots' zones)
            local minDistToAssigned = math.huge
            for _, assigned in ipairs(assignedCentres) do
                local d = centre:Distance(assigned)
                if d < minDistToAssigned then
                    minDistToAssigned = d
                end
            end
            -- For the first bot, use distance from the bot itself as tiebreaker
            if #assignedCentres == 0 then
                minDistToAssigned = 0 -- All are equal; just pick any
            end
            if minDistToAssigned > bestScore then
                bestScore = minDistToAssigned
                best = i
            end
        end
        local centre = best and centres[best] or bot:GetPos()
        if best then used[best] = true end
        table.insert(assignedCentres, centre)
        IC._patrolZones[bot] = { center = centre, radius = zoneRadius }
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Buddy pairing
-- ─────────────────────────────────────────────────────────────────────────────

--- Pair bots together. Prioritises pairing with confirmed-innocent travel companions;
--- falls back to closest participant. Pairs are mutual (A→B, B→A).
---@param bots table<Bot>
function IC._BuildBuddyPairs(bots)
    IC.BuddyPairs = {}
    local unpaired = {}
    for _, bot in ipairs(bots) do
        table.insert(unpaired, bot)
    end

    -- Greedy nearest-neighbour pairing
    local paired = {}
    for _, bot in ipairs(unpaired) do
        if paired[bot] then continue end

        local evidence = bot.components and bot.components.evidence
        local bestBuddy, bestScore = nil, -math.huge

        for _, other in ipairs(unpaired) do
            if other == bot or paired[other] then continue end
            local score = 0

            -- Boost for confirmed innocent
            if evidence and evidence.trustNetwork then
                if evidence.trustNetwork.confirmedInnocent[other] then
                    score = score + 100
                end
                if evidence.trustNetwork.travelCompanions[other] then
                    score = score + 50
                end
            end

            -- Proximity bonus (closer = more natural pairing)
            local dist = bot:GetPos():Distance(other:GetPos())
            score = score - (dist * 0.01)

            if score > bestScore then
                bestScore = score
                bestBuddy = other
            end
        end

        if bestBuddy then
            IC.BuddyPairs[bot]      = bestBuddy
            IC.BuddyPairs[bestBuddy] = bot
            paired[bot]      = true
            paired[bestBuddy] = true
        end
        -- Odd-one-out: the unpaired bot will get a patrol-style fallback job
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Tester queue
-- ─────────────────────────────────────────────────────────────────────────────

--- Build a fresh tester queue from all participants that haven't been tested yet.
---@param bots table<Bot>
function IC._BuildTesterQueue(bots)
    IC.TesterQueue = {}
    for _, bot in ipairs(bots) do
        -- Primary filter: bot already used a role-checker this round
        local role = bot.GetSubRole and bot:GetSubRole()
        local alreadyChecked = TTTBots.Match.CheckedPlayers[bot]
            and (role == nil or TTTBots.Match.CheckedPlayers[bot][role])
        if alreadyChecked then continue end

        -- Secondary filter: bot was confirmed innocent via evidence network
        local alreadyConfirmed = false
        local evidence = bot.components and bot.components.evidence
        if evidence and evidence.trustNetwork then
            alreadyConfirmed = evidence.trustNetwork.confirmedInnocent[bot] ~= nil
        end
        if alreadyConfirmed then continue end

        table.insert(IC.TesterQueue, bot)
    end
    -- Shuffle queue
    for i = #IC.TesterQueue, 2, -1 do
        local j = math.random(i)
        IC.TesterQueue[i], IC.TesterQueue[j] = IC.TesterQueue[j], IC.TesterQueue[i]
    end
end

--- Returns the position in the tester queue for `bot`, or nil if not queued.
---@param bot Bot
---@return number|nil
function IC.GetTesterQueuePosition(bot)
    for i, b in ipairs(IC.TesterQueue) do
        if b == bot then return i end
    end
    return nil
end

--- Remove `bot` from the tester queue (called after the bot finishes testing).
---@param bot Bot
function IC.DequeueBot(bot)
    for i, b in ipairs(IC.TesterQueue) do
        if b == bot then
            table.remove(IC.TesterQueue, i)
            return
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Job construction
-- ─────────────────────────────────────────────────────────────────────────────

--- Build and assign a job table to every participant bot based on the active strategy.
---@param strategy string IC.STRATEGIES value
function IC._AssignJobsForStrategy(strategy)
    IC.BotJobs = {}
    local bots = IC.GetParticipantBots()
    local S    = IC.STRATEGIES
    local A    = IC.ACTIONS
    local now  = CurTime()

    if strategy == S.BUDDY_SYSTEM then
        IC._BuildBuddyPairs(bots)
        for _, bot in ipairs(bots) do
            local buddy = IC.BuddyPairs[bot]
            if buddy and IsValid(buddy) then
                IC.BotJobs[bot] = {
                    Action     = A.BUDDY_UP,
                    TargetObj  = buddy,
                    AssignTime = now,
                    ExpiryTime = now + math.random(30, 90),
                    State      = IC.BOTSTATES.IDLE,
                }
            else
                -- Unpaired: fall back to a patrol position
                IC.BotJobs[bot] = IC._MakePatrolJob(bot, now)
            end
        end

    elseif strategy == S.PATROL_ROUTES then
        IC._AssignPatrolZones(bots)
        for _, bot in ipairs(bots) do
            -- 🟡 6: Detective gets investigation jobs instead of generic patrol
            local role = TTTBots.Roles.GetRoleFor(bot)
            if role and role:GetAppearsPolice() then
                IC.BotJobs[bot] = IC._MakeInvestigateJob(bot, now)
            else
                IC.BotJobs[bot] = IC._MakePatrolJob(bot, now)
            end
        end

    elseif strategy == S.TESTER_QUEUE then
        IC._BuildTesterQueue(bots)
        local testerPos = IC._FindTesterPos()
        -- Check whether the detective should deploy their role-checker device first
        local detWithChecker = IC.GetDetectiveBotWithChecker()
        for _, bot in ipairs(bots) do
            if bot == detWithChecker then
                -- Detective deploys the checker at a popular area before the queue forms
                local deployPos = IC._FindCheckerDeployPos()
                IC.BotJobs[bot] = {
                    Action     = A.DEPLOY_CHECKER,
                    TargetObj  = deployPos,
                    AssignTime = now,
                    ExpiryTime = now + 60,
                    State      = IC.BOTSTATES.IDLE,
                }
            elseif testerPos then
                -- 🟡 7: Detective guards the tester instead of queuing (they don't need testing)
                local role = TTTBots.Roles.GetRoleFor(bot)
                if role and role:GetAppearsPolice() then
                    IC.BotJobs[bot] = {
                        Action     = A.GUARD_TESTER,
                        TargetObj  = testerPos,
                        AssignTime = now,
                        ExpiryTime = now + 60,
                        State      = IC.BOTSTATES.IDLE,
                    }
                else
                    local qPos = IC.GetTesterQueuePosition(bot)
                    if qPos then
                        IC.BotJobs[bot] = {
                            Action     = A.QUEUE_TEST,
                            TargetObj  = testerPos,
                            QueuePos   = qPos,
                            AssignTime = now,
                            ExpiryTime = now + 120,
                            State      = IC.BOTSTATES.IDLE,
                        }
                    else
                        -- Already confirmed; just buddy up while waiting
                        IC.BotJobs[bot] = IC._MakeBuddyJob(bot, bots, now)
                    end
                end
            else
                -- No tester on map yet; just buddy up
                IC.BotJobs[bot] = IC._MakeBuddyJob(bot, bots, now)
            end
        end
        -- Detective leadership: emit an ASSIGN_TEST chatter event
        IC._DetectiveEmit(IC.DETECTIVE_ACTIONS.ASSIGN_TEST)

    elseif strategy == S.BODY_RECOVERY then
        local perimCenter = IC.PerimeterTarget
        if not perimCenter then
            -- Fallback: just buddy up
            IC._AssignJobsForStrategy(S.BUDDY_SYSTEM)
            return
        end
        -- Spread bots around the perimeter in angular offsets
        local radius = 250
        local n = math.max(#bots, 1)
        for idx, bot in ipairs(bots) do
            local angle = (360 / n) * (idx - 1)
            local offset = Vector(
                math.cos(math.rad(angle)) * radius,
                math.sin(math.rad(angle)) * radius,
                0
            )
            local holdPos = perimCenter + offset
            IC.BotJobs[bot] = {
                Action     = A.HOLD_PERIMETER,
                TargetObj  = holdPos,
                AssignTime = now,
                ExpiryTime = now + 20,
                State      = IC.BOTSTATES.IDLE,
            }
        end
        -- Detective leadership: dispatch investigator
        IC._DetectiveEmit(IC.DETECTIVE_ACTIONS.DISPATCH_INVESTIGATE)

    elseif strategy == S.LAST_STAND then
        local stronghold = IC._FindDefensiblePosition()
        -- Guard: if no defensible position was found, use a popular nav area
        if not stronghold then
            local popular = TTTBots.Lib.GetTopNPopularNavs and TTTBots.Lib.GetTopNPopularNavs(1) or {}
            if popular[1] then
                local nav = navmesh.GetNavAreaByID(popular[1][1])
                if nav then stronghold = nav:GetCenter() end
            end
        end
        -- Final fallback: use the first bot's current position
        if not stronghold and bots[1] then
            stronghold = bots[1]:GetPos()
        end
        for _, bot in ipairs(bots) do
            IC.BotJobs[bot] = {
                Action     = A.HOLD_LAST_STAND,
                TargetObj  = stronghold,
                AssignTime = now,
                ExpiryTime = now + 9999, -- Hold indefinitely
                State      = IC.BOTSTATES.IDLE,
            }
        end
        -- Detective leadership: group-up call
        IC._DetectiveEmit(IC.DETECTIVE_ACTIONS.GROUPUP)
    end
end

--- Build a PATROL_ZONE job for `bot` using its assigned zone.
--- When a patrol job expires, the bot gets a completely new zone assignment
--- so it moves to a different part of the map.
---@param bot Bot
---@param now number CurTime()
---@return table job
function IC._MakePatrolJob(bot, now)
    -- Reassign this bot to a new zone far from other bots' current zones
    IC._AssignPatrolZones({ bot })
    local zone  = IC._patrolZones[bot]
    local center = zone and zone.center or bot:GetPos()

    -- 200-damage knife mod awareness: shorter patrol windows so innocents keep
    -- moving (stationary targets are easy knife kills) and wider wander radii
    -- to cover more map area and spot threats earlier.
    local knifeModActive = TTTBots.Behaviors and TTTBots.Behaviors.KnifeStalk
        and TTTBots.Behaviors.KnifeStalk.IsKnifeModInstalled
        and TTTBots.Behaviors.KnifeStalk.IsKnifeModInstalled()

    local minDuration = knifeModActive and 6 or 10
    local maxDuration = knifeModActive and 14 or 20

    return {
        Action     = IC.ACTIONS.PATROL_ZONE,
        TargetObj  = center,
        AssignTime = now,
        ExpiryTime = now + math.random(minDuration, maxDuration),
        State      = IC.BOTSTATES.IDLE,
        _wanderPos = nil,
    }
end

--- Build an INVESTIGATE_AREA job for detective bots. Directs them to unpopular
--- nav areas to actively search for evidence rather than aimless patrol.
---@param bot Bot
---@param now number CurTime()
---@return table job
function IC._MakeInvestigateJob(bot, now)
    local A = IC.ACTIONS
    local unpopNavs = TTTBots.Lib.GetTopNUnpopularNavs and TTTBots.Lib.GetTopNUnpopularNavs(5) or {}
    local target = nil

    if #unpopNavs > 0 then
        local pick = unpopNavs[math.random(1, #unpopNavs)]
        local navArea = navmesh.GetNavAreaByID(pick[1])
        if navArea then
            target = navArea:GetCenter()
        end
    end

    -- Fallback: pick a random nav area
    if not target then
        local allNavs = navmesh.GetAllNavAreas()
        if allNavs and #allNavs > 0 then
            local nav = allNavs[math.random(1, #allNavs)]
            if nav then target = nav:GetCenter() end
        end
    end

    -- Final fallback
    target = target or bot:GetPos()

    return {
        Action     = A.INVESTIGATE_AREA,
        TargetObj  = target,
        AssignTime = now,
        ExpiryTime = now + math.random(15, 30),
        State      = IC.BOTSTATES.IDLE,
    }
end

--- Build a BUDDY_UP job falling back to the nearest other participant.
--- If no valid buddy can be found, returns a patrol job instead so the bot
--- is never left with a nil-target BUDDY_UP job that instantly fails.
---@param bot Bot
---@param bots table<Bot>
---@param now number
---@return table job
function IC._MakeBuddyJob(bot, bots, now)
    local buddy = nil
    local bestDist = math.huge
    for _, other in ipairs(bots) do
        if other == bot then continue end
        if not (IsValid(other) and lib.IsPlayerAlive(other)) then continue end
        local d = bot:GetPos():Distance(other:GetPos())
        if d < bestDist then
            bestDist = d
            buddy = other
        end
    end
    -- No valid buddy found — fall back to a patrol job so the bot keeps moving
    if not buddy then
        return IC._MakePatrolJob(bot, now)
    end
    return {
        Action     = IC.ACTIONS.BUDDY_UP,
        TargetObj  = buddy,
        AssignTime = now,
        ExpiryTime = now + math.random(20, 45), -- shorter window; stuck-detection re-assigns if needed
        State      = IC.BOTSTATES.IDLE,
    }
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Detective leadership chatter
-- ─────────────────────────────────────────────────────────────────────────────

IC._lastDetectiveEmitTime = {}

--- Emit a leadership chatter event from the detective bot (or the best candidate).
--- Rate-limited to once per event type per 30 seconds.
---@param eventKey string IC.DETECTIVE_ACTIONS value
function IC._DetectiveEmit(eventKey)
    local now = CurTime()
    local lastTime = IC._lastDetectiveEmitTime[eventKey] or 0
    if (now - lastTime) < 30 then return end
    IC._lastDetectiveEmitTime[eventKey] = now

    local detBot = IC.GetDetectiveBot()
    if not (detBot and detBot.components and detBot.components.chatter) then return end
    if not detBot.components.chatter.On then return end

    detBot.components.chatter:On(eventKey, {}, true)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API — job access for FollowInnocentPlan
-- ─────────────────────────────────────────────────────────────────────────────

--- Returns the current job assigned to `bot`, or nil.
---@param bot Bot
---@return table|nil
function IC.GetJobFor(bot)
    return IC.BotJobs[bot]
end

--- Clears the job for `bot` (e.g., called from OnEnd).
---@param bot Bot
function IC.ClearJobFor(bot)
    IC.BotJobs[bot] = nil
end

--- Returns true if the coordinator has an active strategy and bot has a job.
---@param bot Bot
---@return boolean
function IC.BotHasJob(bot)
    return IC.BotJobs[bot] ~= nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Round hooks — body found → trigger perimeter
-- ─────────────────────────────────────────────────────────────────────────────

hook.Add("TTTBodyFound", "IC.BodyFound", function(finder, deadPly, ragdoll)
    if not IsValid(ragdoll) then return end
    IC.PerimeterTarget     = ragdoll:GetPos()
    IC.PerimeterActivatedAt = CurTime()
    -- Force immediate re-evaluation so BodyRecovery can activate
    IC.SelectedStrategy = nil
end)

hook.Add("TTTEndRound", "IC.Cleanup", function()
    IC.SelectedStrategy         = nil
    IC.BotJobs                  = {}
    IC.BuddyPairs               = {}
    IC.TesterQueue              = {}
    IC.PerimeterTarget          = nil
    IC.PerimeterActivatedAt     = nil
    IC.LastStandPosition        = nil
    IC.DetectiveDeployedChecker = false
    IC._patrolZones             = {}
    IC._cachedTesterPos         = nil
    IC._testerCacheTime         = 0
    IC._cachedCheckerDeployPos  = nil
    IC._checkerDeployPosTime    = 0
    IC._lastDetectiveEmitTime   = {}
    IC._botLastPos              = {}
    IC._botLastPosTime          = {}
    IC._botNearBuddySince       = {}
end)

hook.Add("TTTPrepareRound", "IC.PrepareRound", function()
    IC.SelectedStrategy         = nil
    IC.BotJobs                  = {}
    IC.BuddyPairs               = {}
    IC.TesterQueue              = {}
    IC.PerimeterTarget          = nil
    IC.PerimeterActivatedAt     = nil
    IC.LastStandPosition        = nil
    IC.DetectiveDeployedChecker = false
    IC._patrolZones             = {}
    IC._cachedCheckerDeployPos  = nil
    IC._checkerDeployPosTime    = 0
    IC._lastDetectiveEmitTime   = {}
    IC._botLastPos              = {}
    IC._botLastPosTime          = {}
    IC._botNearBuddySince       = {}
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Tick — called from PlanCoordinator.Tick() → sh_tttbots2.lua timer
-- ─────────────────────────────────────────────────────────────────────────────

IC._lastStrategyEvalTime = 0
IC.STRATEGY_EVAL_INTERVAL = 8 -- Re-evaluate strategy at most every 8 seconds

-- Stuck-bot detection: tracks last-known position and when the bot last moved.
IC._botLastPos      = {}   -- [bot] = Vector
IC._botLastPosTime  = {}   -- [bot] = CurTime when position was last meaningfully updated
IC._botNearBuddySince = {} -- [bot] = CurTime when we first detected the bot was within buddy range
IC.STUCK_MOVE_THRESHOLD = 60  -- units; less than this counts as "not moved"
IC.STUCK_TIME_LIMIT     = 12  -- seconds without meaningful movement before job is force-expired
IC.BUDDY_STANDSTILL_LIMIT = 8 -- seconds both buddy-pair bots can be within 250u before job shortens

--- Main tick function. Called once per server tick cycle.
function IC.Tick()
    if not TTTBots.Match.RoundActive then return end
    if not TTTBots.Match.PlansCanStart() then return end

    local now = CurTime()

    -- Re-evaluate strategy on interval or when forced (SelectedStrategy == nil)
    if IC.SelectedStrategy == nil or (now - IC._lastStrategyEvalTime) >= IC.STRATEGY_EVAL_INTERVAL then
        local newStrategy = IC.SelectStrategy()
        local strategyChanged = (newStrategy ~= IC.SelectedStrategy)
        IC.SelectedStrategy = newStrategy
        IC._lastStrategyEvalTime = now

        if strategyChanged then
            -- Rebuild all job assignments
            IC._AssignJobsForStrategy(IC.SelectedStrategy)
        end
    end

    -- Validate existing jobs and reassign stale/expired ones
    for bot, job in pairs(IC.BotJobs) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then
            IC.BotJobs[bot] = nil
            continue
        end
        -- Expire check
        if job.ExpiryTime and now > job.ExpiryTime then
            IC.BotJobs[bot] = nil
            -- Give the bot a fresh job immediately
            local fresh = IC._BuildSingleJob(bot, IC.SelectedStrategy, now)
            if fresh then IC.BotJobs[bot] = fresh end
        end
        -- Buddy validity: buddy may have died
        if job.Action == IC.ACTIONS.BUDDY_UP then
            local buddy = job.TargetObj
            if not (IsValid(buddy) and lib.IsPlayerAlive(buddy)) then
                IC.BotJobs[bot] = nil
                IC.BuddyPairs[bot] = nil
            end
        end
    end

    -- ── Stuck-bot detection ────────────────────────────────────────────────
    -- If a bot hasn't moved more than STUCK_MOVE_THRESHOLD units in
    -- STUCK_TIME_LIMIT seconds, force-expire its job so it gets a fresh one.
    -- Also detect mutual buddy-pair standstill (both within 250 units for too
    -- long) and shorten the remaining expiry to break the freeze early.
    for bot, job in pairs(IC.BotJobs) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end

        local botPos = bot:GetPos()
        local lastPos  = IC._botLastPos[bot]
        local lastTime = IC._botLastPosTime[bot] or now

        if lastPos and botPos:Distance(lastPos) > IC.STUCK_MOVE_THRESHOLD then
            -- Bot has moved — reset tracking
            IC._botLastPos[bot]     = botPos
            IC._botLastPosTime[bot] = now
            IC._botNearBuddySince[bot] = nil
        elseif not lastPos then
            IC._botLastPos[bot]     = botPos
            IC._botLastPosTime[bot] = now
        elseif (now - lastTime) >= IC.STUCK_TIME_LIMIT then
            -- Bot has been almost stationary for too long — force-expire job
            IC.BotJobs[bot] = nil
            IC._botLastPos[bot]     = nil
            IC._botLastPosTime[bot] = nil
            IC._botNearBuddySince[bot] = nil
            continue
        end

        -- Buddy-pair mutual standstill: if both bots are within 250 units of
        -- each other and have been for BUDDY_STANDSTILL_LIMIT seconds, shorten
        -- both their jobs' ExpiryTime so they move on quickly.
        if job and job.Action == IC.ACTIONS.BUDDY_UP then
            local buddy = job.TargetObj
            if IsValid(buddy) and lib.IsPlayerAlive(buddy) then
                local dist = botPos:Distance(buddy:GetPos())
                if dist <= 250 then
                    if not IC._botNearBuddySince[bot] then
                        IC._botNearBuddySince[bot] = now
                    elseif (now - IC._botNearBuddySince[bot]) >= IC.BUDDY_STANDSTILL_LIMIT then
                        -- Both are near each other for too long — shorten expiry
                        job.ExpiryTime = math.min(job.ExpiryTime, now + 2)
                        local buddyJob = IC.BotJobs[buddy]
                        if buddyJob and buddyJob.Action == IC.ACTIONS.BUDDY_UP then
                            buddyJob.ExpiryTime = math.min(buddyJob.ExpiryTime, now + 2)
                        end
                        IC._botNearBuddySince[bot] = nil
                    end
                else
                    -- Moved apart — reset buddy proximity timer
                    IC._botNearBuddySince[bot] = nil
                end
            end
        end
    end

    -- Assign jobs to any participant bots that currently have none
    for _, bot in ipairs(IC.GetParticipantBots()) do
        if not IC.BotJobs[bot] then
            local job = IC._BuildSingleJob(bot, IC.SelectedStrategy, now)
            if job then IC.BotJobs[bot] = job end
        end
    end
end

--- Build a single job for one bot under the active strategy (for incremental assignment).
---@param bot Bot
---@param strategy string
---@param now number
---@return table|nil
function IC._BuildSingleJob(bot, strategy, now)
    local S = IC.STRATEGIES
    local A = IC.ACTIONS

    if strategy == S.BUDDY_SYSTEM then
        local bots = IC.GetParticipantBots()
        return IC._MakeBuddyJob(bot, bots, now)

    elseif strategy == S.PATROL_ROUTES then
        -- 🟡 6: Detective gets investigation jobs, not patrol
        local role = TTTBots.Roles.GetRoleFor(bot)
        if role and role:GetAppearsPolice() then
            return IC._MakeInvestigateJob(bot, now)
        end
        if not IC._patrolZones[bot] then
            IC._AssignPatrolZones({ bot }) -- Assign a zone for just this bot
        end
        return IC._MakePatrolJob(bot, now)

    elseif strategy == S.TESTER_QUEUE then
        -- If this bot is the detective and they still need to deploy their checker, do that first
        local detWithChecker = IC.GetDetectiveBotWithChecker()
        if bot == detWithChecker then
            local deployPos = IC._FindCheckerDeployPos()
            return {
                Action     = A.DEPLOY_CHECKER,
                TargetObj  = deployPos,
                AssignTime = now,
                ExpiryTime = now + 60,
                State      = IC.BOTSTATES.IDLE,
            }
        end
        -- 🟡 7: Detective guards the tester instead of queuing
        local testerPos = IC._FindTesterPos()
        local role = TTTBots.Roles.GetRoleFor(bot)
        if role and role:GetAppearsPolice() and testerPos then
            return {
                Action     = A.GUARD_TESTER,
                TargetObj  = testerPos,
                AssignTime = now,
                ExpiryTime = now + 60,
                State      = IC.BOTSTATES.IDLE,
            }
        end
        local qPos = IC.GetTesterQueuePosition(bot)
        if qPos and testerPos then
            return {
                Action     = A.QUEUE_TEST,
                TargetObj  = testerPos,
                QueuePos   = qPos,
                AssignTime = now,
                ExpiryTime = now + 120,
                State      = IC.BOTSTATES.IDLE,
            }
        else
            local bots = IC.GetParticipantBots()
            return IC._MakeBuddyJob(bot, bots, now)
        end

    elseif strategy == S.BODY_RECOVERY then
        local perimCenter = IC.PerimeterTarget
        if perimCenter then
            local angle = math.random(360)
            local offset = Vector(
                math.cos(math.rad(angle)) * 250,
                math.sin(math.rad(angle)) * 250,
                0
            )
            return {
                Action     = A.HOLD_PERIMETER,
                TargetObj  = perimCenter + offset,
                AssignTime = now,
                ExpiryTime = now + 20,
                State      = IC.BOTSTATES.IDLE,
            }
        end

    elseif strategy == S.LAST_STAND then
        local pos = IC._FindDefensiblePosition()
        -- Guard: nil defensible position falls back to a popular nav area
        if not pos then
            local popular = TTTBots.Lib.GetTopNPopularNavs and TTTBots.Lib.GetTopNPopularNavs(1) or {}
            if popular[1] then
                local nav = navmesh.GetNavAreaByID(popular[1][1])
                if nav then pos = nav:GetCenter() end
            end
        end
        if not pos then pos = bot:GetPos() end
        return {
            Action     = A.HOLD_LAST_STAND,
            TargetObj  = pos,
            AssignTime = now,
            ExpiryTime = now + 9999,
            State      = IC.BOTSTATES.IDLE,
        }
    end

    return nil
end
