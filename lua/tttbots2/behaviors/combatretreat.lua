--- behaviors/combatretreat.lua
--- CombatRetreat — Fighting withdrawal under fire with low health.
---
--- Unlike the existing Retreat (which stops firing and just runs) and
--- SeekCover (peek/hide cycle near cover), CombatRetreat makes the bot:
---   1. Run AWAY from the threat to break line of sight.
---   2. Keep FACING the threat direction and shoot back at any hostile
---      targets while retreating (backpedal / strafe retreat).
---   3. Sprint when not actively firing.
---
--- This is the "I'm losing this fight but I'm not going to turn my back"
--- behavior — a controlled tactical withdrawal.
---
--- Triggers:
---   • Being shot at (has an attackTarget or coverTarget) AND health is
---     critically low (below configurable threshold).
---   • Distinct from Retreat: the bot returns fire during withdrawal.
---
--- End conditions: bot reaches safe distance, threat dies, or timeout.

---@class BCombatRetreat
TTTBots.Behaviors.CombatRetreat = {}

local lib    = TTTBots.Lib
local STATUS = TTTBots.STATUS

---@class BCombatRetreat
local CombatRetreat = TTTBots.Behaviors.CombatRetreat
CombatRetreat.Name         = "CombatRetreat"
CombatRetreat.Description  = "Fighting retreat while returning fire"
CombatRetreat.Interruptible = true

-- ---------------------------------------------------------------------------
-- Tuning constants
-- ---------------------------------------------------------------------------

--- Health threshold for a normal bot to enter combat retreat.
local RETREAT_HEALTH_NORMAL  = 35
--- Cautious bots retreat earlier.
local RETREAT_HEALTH_CAUTIOUS = 50
--- Hothead bots never combat-retreat (they go down swinging).
--- (Checked in Validate.)

--- Minimum distance (units) to consider the retreat successful.
local SAFE_DISTANCE   = 900
--- How far ahead (units) to project the retreat waypoint each step.
local RETREAT_STEP    = 700
--- Maximum behavior duration (seconds) before auto-expire.
local MAX_RETREAT_DURATION = 15
--- Cooldown (seconds) after CombatRetreat ends before it can re-trigger.
local POST_RETREAT_COOLDOWN = 8

--- HP threshold below which coordinated / plan attacks still allow retreat.
local COORD_ATTACK_RETREAT_HP = 20

--- How often (seconds) to recalculate the retreat destination.
local REPATH_INTERVAL = 1.5

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Get the health threshold for this bot.
---@param bot Player
---@return number
local function GetHealthThreshold(bot)
    -- Detectives retreat earlier — their survival is strategically important.
    local role = TTTBots.Roles.GetRoleFor(bot)
    local isPolice = role and role.GetAppearsPolice and role:GetAppearsPolice()

    if isPolice then
        return (bot.HasTrait and bot:HasTrait("cautious")) and 60 or 50
    end

    if bot.HasTrait and bot:HasTrait("cautious") then
        return RETREAT_HEALTH_CAUTIOUS
    end
    return RETREAT_HEALTH_NORMAL
end

--- True if the bot is in a coordinated / plan-based attack.
---@param bot Player
---@return boolean
local function IsInCoordinatedAttack(bot)
    local reason = bot.attackTargetReason
    if reason == "COORD_ATTACK_STRIKE" or reason == "FOLLOW_PLAN_ATTACK" then
        return true
    end
    local fpState = TTTBots.Behaviors.GetState(bot, "FollowPlan")
    local job = fpState and fpState.Job
    if job then
        local ACTIONS = TTTBots.Plans and TTTBots.Plans.ACTIONS
        if ACTIONS then
            local act = job.Action
            if act == ACTIONS.COORD_ATTACK or act == ACTIONS.ATTACK or act == ACTIONS.ATTACKANY then
                return true
            end
        end
    end
    return false
end

--- Identify the primary threat the bot is retreating from.
---@param bot Player
---@return Player|Entity|nil
local function GetThreat(bot)
    -- Prefer the active attack target, then cover target
    local target = bot.attackTarget
    if IsValid(target) and lib.IsPlayerAlive(target) then return target end
    local cover = bot.coverTarget
    if IsValid(cover) and lib.IsPlayerAlive(cover) then return cover end
    return nil
end

--- Find a retreat position that moves the bot away from the threat while
--- trying to break line of sight (prefers positions behind walls).
---@param bot Player
---@param threatPos Vector
---@return Vector|nil
local function GetCombatRetreatPos(bot, threatPos)
    local botPos  = bot:GetPos()
    local awayDir = (botPos - threatPos):GetNormalized()

    -- Guard zero-length direction
    if awayDir:LengthSqr() < 0.01 then
        awayDir = VectorRand()
        awayDir.z = 0
        awayDir:Normalize()
    end

    local candidates = {}
    local angles = { 0, 30, -30, 60, -60, 90, -90 }

    for _, ang in ipairs(angles) do
        local rotated = Vector(awayDir.x, awayDir.y, 0)
        rotated:Rotate(Angle(0, ang, 0))
        local testPos = botPos + rotated * RETREAT_STEP

        local navArea = navmesh.GetNearestNavArea(testPos, false, 300)
        if not IsValid(navArea) then continue end
        local snapped = navArea:GetCenter()

        -- Must be farther from the threat than current position
        if snapped:Distance(threatPos) <= botPos:Distance(threatPos) then continue end

        -- Score: prefer positions that break LOS to the threat
        local score = 0
        local losTrace = util.TraceLine({
            start  = snapped + Vector(0, 0, 64),
            endpos = threatPos + Vector(0, 0, 64),
            mask   = MASK_SOLID_BRUSHONLY,
        })
        if losTrace.Hit then
            score = score + 10 -- Position breaks LOS — very desirable
        end

        -- Bonus for nav areas with multiple exits (not a dead end)
        if navArea:GetAdjacentCount() >= 2 then
            score = score + 3
        end

        -- Bonus for distance from threat
        score = score + snapped:Distance(threatPos) / 200

        table.insert(candidates, { pos = snapped, score = score })
    end

    -- Also consider hiding spots
    local hidingSpot = TTTBots.Spots and TTTBots.Spots.GetNearestSpotOfCategory(botPos, "hiding")
    if hidingSpot and hidingSpot:Distance(threatPos) > botPos:Distance(threatPos) then
        local losTrace = util.TraceLine({
            start  = hidingSpot + Vector(0, 0, 64),
            endpos = threatPos + Vector(0, 0, 64),
            mask   = MASK_SOLID_BRUSHONLY,
        })
        local score = losTrace.Hit and 12 or 2
        table.insert(candidates, { pos = hidingSpot, score = score })
    end

    -- Pick the best candidate
    table.sort(candidates, function(a, b) return a.score > b.score end)
    if #candidates > 0 then
        return candidates[1].pos
    end

    -- Absolute fallback
    return botPos + awayDir * RETREAT_STEP
end

--- Find any hostile-marked target the bot can currently see and shoot,
--- to enable return fire while retreating.
---@param bot Player
---@return Player|nil
local function FindShootableHostile(bot)
    -- Primary: the bot's current attack target
    local target = bot.attackTarget
    if IsValid(target) and lib.IsPlayerAlive(target) and lib.CanShoot(bot, target) then
        return target
    end

    -- Secondary: any non-ally that is currently visible and close
    local botPos = bot:GetPos()
    local morality = bot.components and bot.components.morality
    local susThreshold = TTTBots.Components.Morality
        and TTTBots.Components.Morality.Thresholds
        and TTTBots.Components.Morality.Thresholds.Sus or 3

    local alivePlayers = TTTBots.Match.AlivePlayers or {}
    for _, ply in ipairs(alivePlayers) do
        if not IsValid(ply) or ply == bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end
        if TTTBots.Roles and TTTBots.Roles.IsAllies(bot, ply) then continue end

        -- Only shoot at players we suspect or who are aiming at us
        local isSuspected = morality and morality:GetSuspicion(ply) >= susThreshold
        local isAimingAtUs = false
        if not isSuspected then
            local eyeTrace = ply:GetEyeTrace()
            isAimingAtUs = eyeTrace and eyeTrace.Entity == bot
        end

        if (isSuspected or isAimingAtUs) and lib.CanShoot(bot, ply) then
            return ply
        end
    end

    return nil
end

-- ---------------------------------------------------------------------------
-- Behavior lifecycle
-- ---------------------------------------------------------------------------

function CombatRetreat.Validate(bot)
    if not lib.IsPlayerAlive(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Hothead/aggressive bots never do a fighting retreat — they stand and fight.
    if bot.HasTrait and (bot:HasTrait("hothead") or bot:HasTrait("aggressive")) then return false end

    -- Respect cooldown
    if (bot.combatRetreatCooldown or 0) > CurTime() then return false end

    -- If already in combat retreat, keep running
    local state = TTTBots.Behaviors.GetState(bot, "CombatRetreat")
    if state.running then
        -- Re-check: did the threat die?
        local threat = GetThreat(bot)
        if not threat then return false end
        return true
    end

    -- Must have a known threat (being attacked / has a cover target)
    local threat = GetThreat(bot)
    if not threat then return false end

    -- Must be low health
    local hp        = bot:Health()
    local threshold = GetHealthThreshold(bot)
    if hp > threshold then return false end

    -- Coordinated attacks suppress retreat unless HP is critical
    if IsInCoordinatedAttack(bot) and hp >= COORD_ATTACK_RETREAT_HP then return false end

    -- KOSedByAll targets: suppress retreat — the team needs to fight these.
    local targetRole = TTTBots.Roles.GetRoleFor(threat)
    if targetRole and targetRole.GetKOSedByAll and targetRole:GetKOSedByAll() then return false end

    -- Confirmed-hostile targets at high priority: only retreat if truly critical
    local pri = bot.attackTargetPriority or 0
    local PRI = TTTBots.Morality and TTTBots.Morality.PRIORITY
    local suspicionPri = PRI and PRI.SUSPICION_THRESHOLD or 2
    local role = TTTBots.Roles.GetRoleFor(bot)
    local isPolice = role and role.GetAppearsPolice and role:GetAppearsPolice()
    if not isPolice and pri >= suspicionPri and hp >= COORD_ATTACK_RETREAT_HP then return false end

    return true
end

function CombatRetreat.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "CombatRetreat")
    local threat = GetThreat(bot)

    state.running    = true
    state.startTime  = CurTime()
    state.threat     = threat
    state.threatPos  = IsValid(threat) and threat:GetPos() or bot:GetPos()
    state.retreatPos = GetCombatRetreatPos(bot, state.threatPos)
    state.lastRepath = CurTime()

    local loco = bot:BotLocomotor()
    if loco then
        loco.shouldSprint = true
        loco.stopLookingAround = true -- We control look direction manually
        if state.retreatPos then
            loco:SetGoal(state.retreatPos)
        end
    end

    -- Chatter: call for help
    local chatter = bot:BotChatter()
    if chatter and chatter.On and IsValid(threat) then
        chatter:On("CallHelp", { player = threat:Nick() }, false, 1)
    end

    return STATUS.RUNNING
end

function CombatRetreat.OnRunning(bot)
    if not lib.IsPlayerAlive(bot) then return STATUS.FAILURE end

    local state = TTTBots.Behaviors.GetState(bot, "CombatRetreat")
    local now   = CurTime()
    local loco  = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    -- Timeout
    if now - (state.startTime or now) > MAX_RETREAT_DURATION then
        return STATUS.SUCCESS
    end

    -- Update threat reference
    local threat = GetThreat(bot)
    if not threat then
        -- Threat is gone — we survived the encounter
        return STATUS.SUCCESS
    end
    state.threat = threat
    if IsValid(threat) then
        state.threatPos = threat:GetPos()
    end

    -- ── Check safe distance ──────────────────────────────────────────
    local botPos      = bot:GetPos()
    local distToThreat = botPos:Distance(state.threatPos)
    if distToThreat >= SAFE_DISTANCE then
        return STATUS.SUCCESS
    end

    -- ── Retreat movement ─────────────────────────────────────────────
    -- Recalculate retreat path periodically
    if (now - (state.lastRepath or 0)) > REPATH_INTERVAL
        or not state.retreatPos
        or (state.retreatPos and botPos:Distance(state.retreatPos) < 120)
    then
        state.lastRepath = now
        state.retreatPos = GetCombatRetreatPos(bot, state.threatPos)
    end

    if state.retreatPos then
        loco:SetGoal(state.retreatPos)

        -- Handle impossible paths
        if loco.cantReachGoal then
            loco.cantReachGoal = false
            state.retreatPos = GetCombatRetreatPos(bot, state.threatPos)
            if state.retreatPos then
                loco:SetGoal(state.retreatPos)
            end
        end
    end

    -- ── Return fire while retreating ─────────────────────────────────
    -- Face the threat and shoot at any hostile target we can see.
    local shootTarget = FindShootableHostile(bot)

    if shootTarget then
        -- Look at the target and fire
        local aimPos
        if shootTarget.LookupBone then
            local spineIdx = shootTarget:LookupBone("ValveBiped.Bip01_Spine2")
            if spineIdx then
                local spinePos = shootTarget:GetBonePosition(spineIdx)
                aimPos = spinePos or shootTarget:EyePos()
            else
                aimPos = shootTarget:EyePos()
            end
        else
            aimPos = shootTarget:EyePos()
        end

        loco:LookAt(aimPos)
        loco.stopLookingAround = true

        -- Check we won't teamkill before firing
        local willTeamkill = false
        if TTTBots.Behaviors.AttackTarget and TTTBots.Behaviors.AttackTarget.WillShootingTeamkill then
            willTeamkill = TTTBots.Behaviors.AttackTarget.WillShootingTeamkill(bot, shootTarget)
        end

        if not willTeamkill and TTTBots.Behaviors.AttackTarget
            and TTTBots.Behaviors.AttackTarget.LookingCloseToTarget
            and TTTBots.Behaviors.AttackTarget.LookingCloseToTarget(bot, shootTarget)
        then
            loco:StartAttack()
            -- Stop sprinting while firing for better accuracy
            loco.shouldSprint = false
        else
            loco:StopAttack()
            loco.shouldSprint = true
        end
    else
        -- No shootable target — just face the threat direction and sprint
        loco:StopAttack()
        loco.shouldSprint = true
        loco.stopLookingAround = true

        -- Look back toward the threat to keep awareness
        if IsValid(threat) then
            loco:LookAt(threat:EyePos())
        end
    end

    -- ── Reload during brief lulls (when not firing) ──────────────────
    if not shootTarget then
        local inv = bot:BotInventory()
        if inv then
            local heldInfo = inv:GetHeldWeaponInfo()
            if heldInfo and not heldInfo.is_clipless then
                inv:ReloadIfNecessary()
            end
        end
    end

    -- ── Periodic help chatter ────────────────────────────────────────
    lib.CallEveryNTicks(bot, function()
        local chatter = bot:BotChatter()
        if chatter and chatter.On and IsValid(threat) then
            chatter:On("CallHelp", { player = threat:Nick() }, false, 1)
        end
    end, math.ceil(TTTBots.Tickrate * 5))

    return STATUS.RUNNING
end

function CombatRetreat.OnSuccess(bot) end
function CombatRetreat.OnFailure(bot) end

function CombatRetreat.OnEnd(bot)
    local loco = bot:BotLocomotor()
    if loco then
        loco.shouldSprint = false
        loco:StopAttack()
        loco.stopLookingAround = false
    end
    bot.combatRetreatCooldown = CurTime() + POST_RETREAT_COOLDOWN
    TTTBots.Behaviors.ClearState(bot, "CombatRetreat")
end
