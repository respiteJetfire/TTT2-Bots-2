--- behaviors/panicretreat.lua
--- PanicRetreat — Emergency flee behavior for imminent lethal threats.
---
--- The bot drops everything and sprints at maximum speed in the opposite
--- direction, breaking line of sight, until it reaches a safe distance or dies.
---
--- Current triggers (more can be added):
---   a) Spotted an armed C4 with < 5 seconds remaining on its timer.
---   b) Taking damage while unarmed (no weapon, or only a crowbar).

---@class BPanicRetreat
TTTBots.Behaviors.PanicRetreat = {}

local lib = TTTBots.Lib
local STATUS = TTTBots.STATUS

---@class BPanicRetreat
local PanicRetreat = TTTBots.Behaviors.PanicRetreat
PanicRetreat.Name = "PanicRetreat"
PanicRetreat.Description = "Panic-fleeing from an imminent lethal threat"
PanicRetreat.Interruptible = false -- Cannot be interrupted — survival is paramount

-- ---------------------------------------------------------------------------
-- Tuning constants
-- ---------------------------------------------------------------------------

--- C4 time remaining (seconds) to trigger panic flee.
local C4_PANIC_TIME = 5
--- Radius within which a C4 must be to trigger panic (units).
local C4_PANIC_RADIUS = 800
--- Distance (units) the bot must travel from the threat origin to consider itself safe.
local SAFE_DISTANCE = 1200
--- Maximum duration (seconds) before the behavior auto-expires (prevents infinite flee).
local MAX_PANIC_DURATION = 12
--- How far ahead to project the initial flee waypoint (units).
local FLEE_STEP = 1000
--- Cooldown (seconds) after a panic retreat before it can trigger again.
local POST_PANIC_COOLDOWN = 6

-- ---------------------------------------------------------------------------
-- Trigger helpers
-- ---------------------------------------------------------------------------

--- Returns the nearest armed C4 that is about to explode (< C4_PANIC_TIME seconds).
--- The bot must be able to see or be within blast proximity to react.
---@param bot Player
---@return Entity|nil c4, number|nil timeLeft
local function FindDangerousC4(bot)
    local bombs = ents.FindByClass("ttt_c4")
    local botPos = bot:GetPos()
    local bestBomb = nil
    local bestTime = math.huge

    for _, c4 in ipairs(bombs) do
        if not IsValid(c4) then continue end
        if not c4.GetArmed or not c4:GetArmed() then continue end
        if not c4.GetExplodeTime then continue end

        local timeLeft = c4:GetExplodeTime() - CurTime()
        if timeLeft > C4_PANIC_TIME or timeLeft <= 0 then continue end

        local dist = botPos:Distance(c4:GetPos())
        if dist > C4_PANIC_RADIUS then continue end

        -- Bot must be able to see the C4 or be very close (blast radius awareness)
        local canSee = bot:VisibleVec(c4:GetPos() + Vector(0, 0, 16))
        if not canSee and dist > 300 then continue end

        if timeLeft < bestTime then
            bestTime = timeLeft
            bestBomb = c4
        end
    end

    return bestBomb, bestBomb and bestTime or nil
end

--- Returns true if the bot is effectively unarmed (no weapon at all, or only
--- has a crowbar / fists / magneto stick / other melee-only loadout).
---@param bot Player
---@return boolean
local function IsEffectivelyUnarmed(bot)
    local weapons = bot:GetWeapons()
    if not weapons or #weapons == 0 then return true end

    local MELEE_ONLY = {
        ["weapon_zm_improvised"] = true,  -- crowbar
        ["weapon_ttt_unarmed"]   = true,  -- fists
        ["weapon_ttt_wtester"]   = true,  -- tester (non-combat)
        ["weapon_zm_carry"]      = true,  -- magneto stick
        ["weapon_ttt_binoculars"]= true,  -- binoculars
    }

    for _, wep in ipairs(weapons) do
        if not IsValid(wep) then continue end
        local class = wep:GetClass()
        if not MELEE_ONLY[class] then
            return false -- Has at least one real weapon
        end
    end
    return true
end

--- Returns true if the bot is currently taking damage while unarmed.
---@param bot Player
---@return boolean isTakingDamage, Player|nil attacker
local function IsUnarmedAndUnderFire(bot)
    if not IsEffectivelyUnarmed(bot) then return false, nil end

    -- Check if the bot has a recent attacker via the morality/self-defense system
    local attacker = bot.attackTarget
    if IsValid(attacker) and lib.IsPlayerAlive(attacker) then
        local mem = bot.components and bot.components.memory
        if mem then
            local lastSeen = mem:GetLastSeenTime(attacker)
            if lastSeen and (CurTime() - lastSeen) < 5 then
                return true, attacker
            end
        end
    end

    -- Also check the personality pressure system — recent hurt events
    local personality = bot:BotPersonality()
    if personality then
        local pressure = personality:GetPressure()
        if pressure > 0.3 then
            -- Bot is under pressure (recently hurt) and has no weapon
            -- Try to find who is nearby and hostile
            local botPos = bot:GetPos()
            for _, ply in ipairs(player.GetAll()) do
                if ply == bot then continue end
                if not lib.IsPlayerAlive(ply) then continue end
                local dist = botPos:Distance(ply:GetPos())
                if dist < 500 then
                    local eyeTrace = ply:GetEyeTrace()
                    if eyeTrace and eyeTrace.Entity == bot then
                        return true, ply
                    end
                end
            end
            -- Fallback: no specific attacker identified, but still panicking
            if pressure > 0.5 then
                return true, nil
            end
        end
    end

    return false, nil
end

--- Calculate a flee position AWAY from the threat origin, snapped to nav mesh.
---@param bot Player
---@param threatPos Vector
---@return Vector|nil
local function GetPanicFleePos(bot, threatPos)
    local botPos = bot:GetPos()
    local awayDir = (botPos - threatPos):GetNormalized()
    -- Zero-length guard (bot is ON the threat)
    if awayDir:LengthSqr() < 0.01 then
        awayDir = VectorRand()
        awayDir.z = 0
        awayDir:Normalize()
    end

    -- Try the primary direction and several fallback angles
    local angles = { 0, 35, -35, 70, -70, 110, -110 }
    for _, ang in ipairs(angles) do
        local rotated = Vector(awayDir.x, awayDir.y, 0)
        rotated:Rotate(Angle(0, ang, 0))
        local testPos = botPos + rotated * FLEE_STEP

        -- Snap to nav mesh for valid pathing
        local navArea = navmesh.GetNearestNavArea(testPos, false, 300)
        if IsValid(navArea) then
            local snapped = navArea:GetCenter()
            -- Make sure this position is actually farther from the threat
            if snapped:Distance(threatPos) > botPos:Distance(threatPos) then
                return snapped
            end
        end
    end

    -- Last resort: any hiding spot far away
    local hidingSpot = TTTBots.Spots and TTTBots.Spots.GetNearestSpotOfCategory(botPos, "hiding")
    if hidingSpot and hidingSpot:Distance(threatPos) > botPos:Distance(threatPos) + 200 then
        return hidingSpot
    end

    -- Absolute fallback: raw vector away
    return botPos + awayDir * FLEE_STEP
end

-- ---------------------------------------------------------------------------
-- Behavior lifecycle
-- ---------------------------------------------------------------------------

function PanicRetreat.Validate(bot)
    if not lib.IsPlayerAlive(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Respect cooldown
    if (bot.panicRetreatCooldown or 0) > CurTime() then return false end

    -- Already panicking — keep running (state persists)
    local state = TTTBots.Behaviors.GetState(bot, "PanicRetreat")
    if state.running then return true end

    -- ── Trigger A: C4 about to explode ───────────────────────────────
    local c4, timeLeft = FindDangerousC4(bot)
    if c4 then
        state.trigger      = "C4"
        state.threatPos    = c4:GetPos()
        state.threatEntity = c4
        return true
    end

    -- ── Trigger B: Unarmed and taking damage ─────────────────────────
    local unarmedFire, attacker = IsUnarmedAndUnderFire(bot)
    if unarmedFire then
        state.trigger      = "UNARMED_FIRE"
        state.threatPos    = IsValid(attacker) and attacker:GetPos() or bot:GetPos()
        state.threatEntity = attacker
        return true
    end

    -- ── Trigger C: Active SWEP phase detected — fight-or-flight decided "retreat" ──
    -- SwepThreatResponse scans bots every ~0.35s and sets swepThreatTarget +
    -- swepThreatDecision when it sees a Smart-Bullets or High-Noon holder.
    -- We only trigger PanicRetreat when the decision is specifically "retreat";
    -- the "attack" branch is handled by SetAttackTarget in that same system.
    if IsValid(bot.swepThreatTarget) and bot.swepThreatDecision == "retreat"
        and (bot.swepThreatActAt or 0) <= CurTime()
    then
        state.trigger      = "SWEP_THREAT"
        state.threatPos    = bot.swepThreatTarget:GetPos()
        state.threatEntity = bot.swepThreatTarget
        return true
    end

    -- ── Future triggers can be added here ────────────────────────────
    -- e.g. jihad bomb carrier running at the bot, etc.

    return false
end

function PanicRetreat.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "PanicRetreat")
    state.running   = true
    state.startTime = CurTime()
    state.fleePos   = GetPanicFleePos(bot, state.threatPos)

    local loco = bot:BotLocomotor()
    if loco then
        -- Sprint as fast as possible
        loco.shouldSprint = true
        -- Stop any active combat
        loco:StopAttack()
        loco.stopLookingAround = false
        -- Set initial flee destination
        if state.fleePos then
            loco:SetGoal(state.fleePos)
        end
    end

    -- Drop current attack target — survival takes priority over combat
    if bot.attackTarget then
        bot:SetAttackTarget(nil, "PANIC_RETREAT")
    end

    -- Chatter: scream/warn depending on trigger
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        if state.trigger == "C4" then
            chatter:On("SpottedC4", {}, false, 0)
        elseif state.trigger == "UNARMED_FIRE" then
            chatter:On("CallHelp", {
                player = IsValid(state.threatEntity) and state.threatEntity:Nick() or "someone"
            }, false, 1)
        elseif state.trigger == "SWEP_THREAT" then
            chatter:On("CallHelp", {
                player = IsValid(state.threatEntity) and state.threatEntity:Nick() or "someone"
            }, false, 1)
        end
    end

    return STATUS.RUNNING
end

function PanicRetreat.OnRunning(bot)
    if not lib.IsPlayerAlive(bot) then return STATUS.FAILURE end

    local state = TTTBots.Behaviors.GetState(bot, "PanicRetreat")
    local now   = CurTime()
    local loco  = bot:BotLocomotor()

    -- Timeout safety
    if now - (state.startTime or now) > MAX_PANIC_DURATION then
        return STATUS.SUCCESS
    end

    -- Keep sprinting
    if loco then
        loco.shouldSprint = true
        loco:StopAttack()
    end

    -- ── Check if the specific trigger is still relevant ──────────────
    if state.trigger == "C4" then
        local c4 = state.threatEntity
        if IsValid(c4) and c4.GetArmed and c4:GetArmed() then
            -- Update threat position to the C4's current pos (it doesn't move, but be safe)
            state.threatPos = c4:GetPos()
        else
            -- C4 was defused or exploded — we survived
            return STATUS.SUCCESS
        end
    end

    if state.trigger == "UNARMED_FIRE" then
        -- If we found a weapon, stop panicking
        if not IsEffectivelyUnarmed(bot) then
            return STATUS.SUCCESS
        end
        -- Update threat position if attacker is still visible
        local attacker = state.threatEntity
        if IsValid(attacker) and lib.IsPlayerAlive(attacker) then
            state.threatPos = attacker:GetPos()
        end
    end

    if state.trigger == "SWEP_THREAT" then
        local threatEnt = state.threatEntity
        -- Stop fleeing if the SWEP phase ended or the holder died
        if not IsValid(threatEnt) or not lib.IsPlayerAlive(threatEnt) then
            bot.swepThreatTarget   = nil
            bot.swepThreatDecision = nil
            bot.swepThreatActAt    = nil
            return STATUS.SUCCESS
        end
        -- Check if active phase has expired (buff ran out / High Noon ended)
        local wep = threatEnt:GetActiveWeapon()
        local highNoonGone = not (IsValid(wep) and wep:GetClass() == "weapon_ttt_peacekeeper"
            and wep.HighNoonActive and wep:HighNoonActive())
        local smartBulletsGone = not threatEnt.ttt2_smart_bullets_active
        if highNoonGone and smartBulletsGone then
            bot.swepThreatTarget   = nil
            bot.swepThreatDecision = nil
            bot.swepThreatActAt    = nil
            return STATUS.SUCCESS
        end
        -- Track the threat's position
        state.threatPos = threatEnt:GetPos()
    end

    -- ── Check if we reached safe distance ────────────────────────────
    local botPos     = bot:GetPos()
    local threatPos  = state.threatPos or botPos
    local distToThreat = botPos:Distance(threatPos)

    if distToThreat >= SAFE_DISTANCE then
        return STATUS.SUCCESS
    end

    -- ── Update flee position periodically ────────────────────────────
    local arrivedAtFlee = state.fleePos and botPos:Distance(state.fleePos) < 120
    if not state.fleePos or arrivedAtFlee then
        state.fleePos = GetPanicFleePos(bot, threatPos)
    end

    -- Recalculate flee path every ~2 seconds if threat has moved significantly
    if (now - (state.lastRepath or 0)) > 2 then
        state.lastRepath = now
        local newFlee = GetPanicFleePos(bot, threatPos)
        if newFlee then
            state.fleePos = newFlee
        end
    end

    if loco and state.fleePos then
        loco:SetGoal(state.fleePos)

        -- If the path is impossible, try a new flee position immediately
        if loco.cantReachGoal then
            loco.cantReachGoal = false
            state.fleePos = GetPanicFleePos(bot, threatPos)
            if state.fleePos then
                loco:SetGoal(state.fleePos)
            end
        end
    end

    return STATUS.RUNNING
end

function PanicRetreat.OnSuccess(bot) end
function PanicRetreat.OnFailure(bot) end

function PanicRetreat.OnEnd(bot)
    local loco = bot:BotLocomotor()
    if loco then
        loco.shouldSprint = false
        loco:StopAttack()
        loco.stopLookingAround = false
    end
    -- Clear SWEP-threat state so the scanner can issue a fresh decision
    -- next time this bot spots an active SWEP phase.
    bot.swepThreatTarget   = nil
    bot.swepThreatDecision = nil
    bot.swepThreatActAt    = nil
    bot.panicRetreatCooldown = CurTime() + POST_PANIC_COOLDOWN
    TTTBots.Behaviors.ClearState(bot, "PanicRetreat")
end
