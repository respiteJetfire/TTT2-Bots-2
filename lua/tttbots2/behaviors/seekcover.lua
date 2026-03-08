--[[
SeekCover — Behavior that makes bots seek cover when under fire with low health.
Triggered when AttackTarget sets bot.coverTarget (the attacker entity).
Bots will find a nearby hiding spot, path to it, then peek and fire from cover.
]]
---@class BSeekCover
TTTBots.Behaviors.SeekCover = {}

local lib = TTTBots.Lib

---@class BSeekCover
local SeekCover = TTTBots.Behaviors.SeekCover
SeekCover.Name = "SeekCover"
SeekCover.Description = "Seeking cover from attacker"
SeekCover.Interruptible = true

local STATUS = TTTBots.STATUS

-- How long (seconds) between cover position rescans.
local COVER_RESCAN_INTERVAL = 2.5
-- Range to search for cover positions via ray casts.
local COVER_RAY_RANGE = 450
-- Minimum cover score to consider a position valid.
local MIN_COVER_SCORE = 2
-- Distance at which we consider ourselves "at cover".
local COVER_ARRIVAL_DIST = 120
-- How long to peek from cover before hiding again.
local PEEK_DURATION = 1.2
-- How long to hide behind cover before peeking again.
local HIDE_DURATION = 1.5
-- Maximum time (seconds) allowed in the whole SeekCover behavior before giving up.
local MAX_COVER_DURATION = 8.0
-- How long (seconds) before SeekCover can be triggered again after completing/failing.
local COVER_COOLDOWN = 5.0
-- How long the attacker can be out of sight before we stop caring about cover.
local ATTACKER_LOS_TIMEOUT = 6.0

--- Cast rays in 8 cardinal/diagonal directions and score positions for cover value.
---@param bot Bot
---@param attacker Player|nil
---@return Vector|nil bestPos
local function FindCoverPos(bot, attacker)
    local eyePos = bot:EyePos()
    local botPos = bot:GetPos()
    local directions = {
        Vector(1, 0, 0),
        Vector(-1, 0, 0),
        Vector(0, 1, 0),
        Vector(0, -1, 0),
        Vector(0.707, 0.707, 0),
        Vector(-0.707, 0.707, 0),
        Vector(0.707, -0.707, 0),
        Vector(-0.707, -0.707, 0),
    }

    local bestPos = nil
    local bestScore = -999

    -- Also try TTT2 hiding spots as candidates.
    local hidingSpot = TTTBots.Spots and TTTBots.Spots.GetNearestSpotOfCategory(botPos, "hiding")
    local candidates = {}

    for _, dir in ipairs(directions) do
        local tr = util.TraceLine({
            start = eyePos,
            endpos = eyePos + dir * COVER_RAY_RANGE,
            filter = bot,
            mask = MASK_SOLID_BRUSHONLY,
        })
        if tr.Hit and tr.HitPos then
            -- Step back slightly from the hit wall so the bot doesn't clip into it.
            local coverPos = tr.HitPos - dir * 40
            coverPos.z = botPos.z -- Keep on the ground plane.
            table.insert(candidates, coverPos)
        end
    end

    -- Add the TTT2 hiding spot if nearby.
    if hidingSpot and botPos:Distance(hidingSpot) < COVER_RAY_RANGE * 1.5 then
        table.insert(candidates, hidingSpot)
    end

    for _, pos in ipairs(candidates) do
        local score = 0

        -- Snap to nearest nav area centre — guarantees the path manager can route here.
        local navArea = navmesh.GetNearestNavArea(pos, false, 200)
        if not IsValid(navArea) then continue end -- Unreachable — skip entirely.
        local snappedPos = navArea:GetCenter()
        snappedPos.z = pos.z  -- Preserve rough ground height.
        pos = snappedPos

        -- +5 base for having a valid nav area.
        score = score + 5

        -- +2 if the nav area has multiple connections (not a dead end).
        if navArea:GetAdjacentCount() >= 2 then
            score = score + 2
        end

        -- +10 if this position blocks LOS to the attacker.
        if attacker and IsValid(attacker) then
            local losTrace = util.TraceLine({
                start = pos + Vector(0, 0, 64),
                endpos = attacker:EyePos(),
                mask = MASK_SOLID_BRUSHONLY,
            })
            if losTrace.Hit then
                score = score + 10
            end
        end

        -- +3 if there's an ally nearby (within 400 units).
        for _, ply in ipairs(player.GetAll()) do
            if ply == bot then continue end
            if not lib.IsPlayerAlive(ply) then continue end
            if TTTBots.Roles and TTTBots.Roles.IsAllies(bot, ply) then
                if pos:Distance(ply:GetPos()) < 400 then
                    score = score + 3
                    break
                end
            end
        end

        -- Must be different enough from the bot's current position to be worth moving.
        if botPos:DistToSqr(pos) < (60 * 60) then continue end

        if score > bestScore then
            bestScore = score
            bestPos = pos
        end
    end

    if bestScore < MIN_COVER_SCORE then return nil end
    return bestPos
end

--- Validate: run when AttackTarget has flagged us for cover-seeking.
function SeekCover.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    -- Hothead personality never takes cover.
    if bot.HasTrait and bot:HasTrait("hothead") then return false end
    -- Respect post-cover cooldown so we don't immediately loop back in.
    if (bot.seekCoverCooldownUntil or 0) > CurTime() then return false end
    -- Only run when AttackTarget requested cover.
    if not IsValid(bot.coverTarget) then return false end
    -- Clear stale cover targets (attacker is dead or not alive).
    if not lib.IsPlayerAlive(bot.coverTarget) then
        bot.coverTarget = nil
        return false
    end
    -- Clear if attacker has been out of LOS too long — bot should re-engage, not hide forever.
    local memory = bot.components and bot.components.memory
    if memory then
        local lastSeen = memory:GetLastSeenTime(bot.coverTarget)
        if (CurTime() - lastSeen) > ATTACKER_LOS_TIMEOUT then
            bot.coverTarget = nil
            return false
        end
    end
    -- Only if alive.
    if not lib.IsPlayerAlive(bot) then return false end
    return true
end

--- Called when the behavior is started.
function SeekCover.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "SeekCover")
    state.seekCoverPos = nil
    state.seekCoverLastScan = 0
    state.seekCoverPeeking = false
    state.seekCoverPeekTime = 0
    state.seekCoverStartTime = CurTime()
    return STATUS.RUNNING
end

--- Called each tick while the behavior is running.
function SeekCover.OnRunning(bot)
    local attacker = bot.coverTarget
    if not IsValid(attacker) then return STATUS.SUCCESS end
    if not lib.IsPlayerAlive(bot) then return STATUS.FAILURE end

    local state = TTTBots.Behaviors.GetState(bot, "SeekCover")
    local loco = bot:BotLocomotor() ---@type CLocomotor
    local botPos = bot:GetPos()
    local now = CurTime()

    -- Escalate to full retreat if health is critically low.
    if bot:Health() < 25 then
        bot.isRetreating = true
        return STATUS.SUCCESS
    end

    -- Hard timeout: if we've been running SeekCover too long, give up.
    if (now - (state.seekCoverStartTime or now)) > MAX_COVER_DURATION then
        return STATUS.FAILURE
    end

    -- If the attacker has been out of LOS for too long, stop hiding and re-engage.
    local memory = bot.components and bot.components.memory
    if memory then
        local lastSeen = memory:GetLastSeenTime(attacker)
        if (now - lastSeen) > ATTACKER_LOS_TIMEOUT then
            bot.coverTarget = nil
            return STATUS.SUCCESS
        end
    end

    -- Periodically rescan for a better cover position.
    if (not state.seekCoverPos) or (now - (state.seekCoverLastScan or 0) > COVER_RESCAN_INTERVAL) then
        local newPos = FindCoverPos(bot, attacker)
        if newPos then
            state.seekCoverPos = newPos
            state.seekCoverLastScan = now
        end
    end

    if not state.seekCoverPos then
        -- No valid cover found — fall back to normal attack behavior.
        return STATUS.FAILURE
    end

    local distToCover = botPos:Distance(state.seekCoverPos)

    if distToCover > COVER_ARRIVAL_DIST then
        -- Haven't reached cover yet — path towards it.
        loco:SetGoal(state.seekCoverPos)
        -- If the path manager says this is impossible, clear and rescan next tick.
        if loco.cantReachGoal then
            loco.cantReachGoal = false
            state.seekCoverPos = nil
            state.seekCoverLastScan = 0
        end
        return STATUS.RUNNING
    end

    -- We're at cover. Do the peek/hide cycle.
    loco:StopMoving()

    if state.seekCoverPeeking then
        -- Currently peeking: look at attacker and start firing.
        loco.stopLookingAround = true
        if IsValid(attacker) then
            loco:LookAt(attacker:EyePos())
            if lib.CanShoot(bot, attacker) then
                loco:StartAttack()
            end
        end
        -- Switch to hiding after PEEK_DURATION.
        if now - state.seekCoverPeekTime > PEEK_DURATION then
            state.seekCoverPeeking = false
            state.seekCoverPeekTime = now
            loco:StopAttack()
            loco.stopLookingAround = false
        end
    else
        -- Currently hiding: stop firing, wait before peeking again.
        loco:StopAttack()
        loco.stopLookingAround = false
        if now - (state.seekCoverPeekTime or 0) > HIDE_DURATION then
            state.seekCoverPeeking = true
            state.seekCoverPeekTime = now
        end
    end

    return STATUS.RUNNING
end

function SeekCover.OnSuccess(bot)
end

function SeekCover.OnFailure(bot)
end

function SeekCover.OnEnd(bot)
    bot.coverTarget = nil
    -- Apply cooldown so AttackTarget doesn't immediately re-trigger SeekCover.
    bot.seekCoverCooldownUntil = CurTime() + COVER_COOLDOWN
    local loco = bot:BotLocomotor()
    if loco then
        loco:StopAttack()
        loco.stopLookingAround = false
    end
    TTTBots.Behaviors.ClearState(bot, "SeekCover")
end
