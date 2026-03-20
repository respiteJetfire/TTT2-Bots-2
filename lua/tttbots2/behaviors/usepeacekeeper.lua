--- behaviors/usepeacekeeper.lua
--- Uses the Peacekeeper / "High Noon" weapon (weapon_ttt_peacekeeper).
--- This is a McCree-style ultimate: the bot equips it, charges up targets in FOV,
--- then fires lethal homing shots. It's a one-use weapon that slows the user.
--- The bot should only use it when multiple enemies are visible at once.

local lib = TTTBots.Lib
local STATUS = TTTBots.STATUS

---@class BUsePeacekeeper
TTTBots.Behaviors.UsePeacekeeper = {}

local UsePeacekeeper = TTTBots.Behaviors.UsePeacekeeper
UsePeacekeeper.Name = "UsePeacekeeper"
UsePeacekeeper.Description = "Use the Peacekeeper (High Noon) weapon on multiple visible enemies."
UsePeacekeeper.Interruptible = false  -- Once committed, don't abort

--- Minimum visible enemies to justify using this powerful one-shot weapon.
local MIN_VISIBLE_ENEMIES = 2
--- Max time we'll hold before firing if not all tracked targets are ready yet.
local CHARGE_TIME = 4.0
--- Max total behavior duration before we force-fire or fail.
local MAX_DURATION = 10.0
--- How long to hold the primary attack button per press (seconds).
local PRIMARY_PRESS_TIME = 0.3
--- How long to wait after releasing primary before pressing again (seconds).
local PRIMARY_RELEASE_TIME = 0.3
--- Minimum charge time before the bot will even consider firing.
local MIN_CHARGE_BEFORE_FIRE = 1.5

function UsePeacekeeper.HasPeacekeeper(bot)
    return bot:HasWeapon("weapon_ttt_peacekeeper")
end

function UsePeacekeeper.GetPeacekeeper(bot)
    local wep = bot:GetWeapon("weapon_ttt_peacekeeper")
    return IsValid(wep) and wep or nil
end

--- Count enemies visible to the bot within a reasonable FOV/range.
---@param bot Bot
---@return number visibleEnemies, Player[] visibleList
local function CountVisibleEnemies(bot)
    local count = 0
    local visible = {}
    for _, ply in pairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() or ply == bot then continue end
        if ply:IsSpec() then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then continue end
        -- Check if the bot can see them within weapon range
        if bot:GetPos():Distance(ply:GetPos()) > 2000 then continue end
        if bot:Visible(ply) then
            count = count + 1
            table.insert(visible, ply)
        end
    end
    return count, visible
end

---@param wep Weapon|nil
---@return string
local function GetHighNoonState(wep)
    if not IsValid(wep) or not wep.GetHighNoon then return "none" end
    return wep:GetHighNoon() or "none"
end

---@param bot Bot
---@param wep Weapon|nil
---@return Player[]
local function GetTrackedTargets(bot, wep)
    if not IsValid(bot) or not IsValid(wep) then return {} end

    local tracked = {}
    local targets = bot.highnoontargets or {}
    local entIndex = wep:EntIndex()

    for _, ply in pairs(targets) do
        if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then continue end
        if not ply:GetNWBool("HighNoonFOV" .. entIndex, false) then continue end

        table.insert(tracked, ply)
    end

    return tracked
end

---@param trackedTargets Player[]
---@param wep Weapon|nil
---@return boolean
local function AreAllTrackedTargetsReady(trackedTargets, wep)
    if not IsValid(wep) or #trackedTargets == 0 then return false end

    local entIndex = wep:EntIndex()

    for _, ply in ipairs(trackedTargets) do
        local charge = ply:GetNWInt("HighNoonCharged" .. entIndex, 0)
        if charge < ply:Health() then
            return false
        end
    end

    return true
end

function UsePeacekeeper.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if not UsePeacekeeper.HasPeacekeeper(bot) then return false end

    -- If the weapon has already been used (0 clip), don't bother
    local wep = UsePeacekeeper.GetPeacekeeper(bot)
    if wep and wep:Clip1() <= 0 then return false end

    local visibleEnemies = CountVisibleEnemies(bot)
    if visibleEnemies < MIN_VISIBLE_ENEMIES then return false end

    -- Chance gate: ~10% per tick (was 2.5% which was far too low to ever trigger)
    if math.random(1, 10) > 1 then return false end

    return true
end

function UsePeacekeeper.OnStart(bot)
    bot._peacekeeperStart = CurTime()
    bot._peacekeeperChargeStart = nil
    bot._peacekeeperPhase = "equip"  -- equip → start_press → start_release → charging → fire_press → done
    bot._peacekeeperPhaseTime = CurTime()
    bot._peacekeeperFireAttempts = 0
    bot._peacekeeperSawFiringState = false
    bot._peacekeeperEquipped = false
    bot._peacekeeperSweepIndex = 1
    bot._peacekeeperLastSweepTime = 0

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("HighNoon", {}, false)
    end

    return STATUS.RUNNING
end

function UsePeacekeeper.OnRunning(bot)
    if not UsePeacekeeper.HasPeacekeeper(bot) then
        -- Weapon consumed or dropped — we successfully fired (or it was used up)
        return STATUS.SUCCESS
    end

    -- Hard timeout
    if bot._peacekeeperStart and (CurTime() - bot._peacekeeperStart) > MAX_DURATION then
        return STATUS.FAILURE
    end

    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    local wep = UsePeacekeeper.GetPeacekeeper(bot)
    if not wep then return STATUS.FAILURE end

    -- Check if weapon is already spent
    if wep:Clip1() <= 0 then
        return STATUS.SUCCESS
    end

    local highNoonState = GetHighNoonState(wep)

    -- Pause auto weapon switching so inventory doesn't fight us
    inv:PauseAutoSwitch()
    -- Disable attack compatibility (the periodic release) so our clicks aren't eaten
    loco:PauseAttackCompat()

    -- ══════════════════════════════════════════════════════════════════════
    -- Phase: EQUIP — select the weapon and wait for it to be active
    -- ══════════════════════════════════════════════════════════════════════
    if bot._peacekeeperPhase == "equip" then
        local activeWep = bot:GetActiveWeapon()
        if not IsValid(activeWep) or activeWep:GetClass() ~= "weapon_ttt_peacekeeper" then
            -- Use SelectWeapon (not SetActiveWeapon) to properly call Deploy()
            -- which initializes bot.highnoontargets
            bot:SelectWeapon("weapon_ttt_peacekeeper")
            return STATUS.RUNNING
        end
        -- Weapon is equipped, move to next phase
        bot._peacekeeperPhase = "start_press"
        bot._peacekeeperPhaseTime = CurTime()
        bot._peacekeeperEquipped = true
        -- Ensure highnoontargets is initialized (Deploy does this, but be safe)
        if not bot.highnoontargets then
            bot.highnoontargets = {}
        end
    end

    -- Gather visible enemies for aiming
    local _, visibleEnemies = CountVisibleEnemies(bot)
    if #visibleEnemies == 0 and highNoonState ~= "firing" then
        -- Lost sight of everyone and we haven't started firing yet
        return STATUS.FAILURE
    end

    -- Stop moving while using the Peacekeeper (it already slows you to 20%)
    loco:SetHalt(true)

    -- ══════════════════════════════════════════════════════════════════════
    -- If the weapon entered "firing" state, we're done — the SWEP handles
    -- the rest automatically via its Think function.
    -- ══════════════════════════════════════════════════════════════════════
    if highNoonState == "firing" then
        bot._peacekeeperSawFiringState = true
        loco:StopAttack()
        return STATUS.SUCCESS
    end

    -- ══════════════════════════════════════════════════════════════════════
    -- Aiming: During "charging", sweep look across enemies so the SWEP's
    -- Think() can detect them in FOV and add them to highnoontargets.
    -- During other phases, look at the centroid.
    -- ══════════════════════════════════════════════════════════════════════
    if highNoonState == "charging" and #visibleEnemies > 0 then
        -- Sweep: rotate through visible enemies so the SWEP's FOV check
        -- picks each one up. Dwell on each for ~0.3s.
        local sweepIdx = bot._peacekeeperSweepIndex or 1
        local lastSweep = bot._peacekeeperLastSweepTime or 0
        if CurTime() - lastSweep > 0.3 then
            sweepIdx = sweepIdx + 1
            if sweepIdx > #visibleEnemies then sweepIdx = 1 end
            bot._peacekeeperSweepIndex = sweepIdx
            bot._peacekeeperLastSweepTime = CurTime()
        end
        -- Clamp index in case the list shrunk
        if sweepIdx > #visibleEnemies then sweepIdx = 1 end
        local lookTarget = visibleEnemies[sweepIdx]
        if IsValid(lookTarget) then
            local targetPos = lookTarget:EyePos()
            loco:LookAt(targetPos)
        end
    elseif #visibleEnemies > 0 then
        -- Not charging yet — look at centroid of enemies
        local center = Vector(0, 0, 0)
        for _, ply in ipairs(visibleEnemies) do
            center = center + ply:EyePos()
        end
        center = center / #visibleEnemies
        loco:LookAt(center)
    end

    -- ══════════════════════════════════════════════════════════════════════
    -- Phase: START_PRESS — hold primary to initiate High Noon
    -- The SWEP's PrimaryAttack() will call StartHighNoon() when state is "none"
    -- ══════════════════════════════════════════════════════════════════════
    if bot._peacekeeperPhase == "start_press" then
        if highNoonState == "starting" or highNoonState == "charging" then
            -- It worked! Release and move on.
            loco:StopAttack()
            bot._peacekeeperPhase = "start_release"
            bot._peacekeeperPhaseTime = CurTime()
            return STATUS.RUNNING
        end

        -- Press primary attack
        loco:StartAttack()

        -- If we've been pressing for too long without state changing, something is wrong
        if CurTime() - bot._peacekeeperPhaseTime > 2.0 then
            return STATUS.FAILURE
        end

        return STATUS.RUNNING
    end

    -- ══════════════════════════════════════════════════════════════════════
    -- Phase: START_RELEASE — release primary and wait for "charging" state
    -- The SWEP transitions "starting" → "charging" after 1 second
    -- ══════════════════════════════════════════════════════════════════════
    if bot._peacekeeperPhase == "start_release" then
        loco:StopAttack()

        if highNoonState == "charging" then
            bot._peacekeeperPhase = "charging"
            bot._peacekeeperPhaseTime = CurTime()
            bot._peacekeeperChargeStart = CurTime()
            return STATUS.RUNNING
        end

        -- Still in "starting" — just wait
        if highNoonState == "starting" then
            return STATUS.RUNNING
        end

        -- State went back to "none" somehow — try again
        if highNoonState == "none" then
            bot._peacekeeperPhase = "start_press"
            bot._peacekeeperPhaseTime = CurTime()
            return STATUS.RUNNING
        end

        return STATUS.RUNNING
    end

    -- ══════════════════════════════════════════════════════════════════════
    -- Phase: CHARGING — wait for targets to lock on, then fire
    -- The SWEP's Think() adds enemies to highnoontargets when they're in FOV
    -- ══════════════════════════════════════════════════════════════════════
    if bot._peacekeeperPhase == "charging" then
        -- Make sure attack is released during charging (we need a fresh click to fire)
        loco:StopAttack()

        if highNoonState ~= "charging" then
            -- State changed unexpectedly
            if highNoonState == "none" then
                -- High noon ended (maybe timed out) — weapon is spent
                return STATUS.SUCCESS
            end
            return STATUS.RUNNING
        end

        local trackedTargets = GetTrackedTargets(bot, wep)
        local allReady = AreAllTrackedTargetsReady(trackedTargets, wep)
        local chargeElapsed = bot._peacekeeperChargeStart and (CurTime() - bot._peacekeeperChargeStart) or 0

        -- Decide if we should fire:
        -- 1. All locked targets are fully charged, OR
        -- 2. We've been charging long enough and have at least 1 target, OR
        -- 3. We've been charging a very long time (fire with whatever we have)
        local hasTargets = #trackedTargets > 0
        local shouldFire = false

        if chargeElapsed >= MIN_CHARGE_BEFORE_FIRE then
            if allReady and hasTargets then
                shouldFire = true
            elseif chargeElapsed >= CHARGE_TIME and hasTargets then
                shouldFire = true
            elseif chargeElapsed >= CHARGE_TIME + 2.0 then
                -- Emergency: fire even with 0 tracked (SWEP will just end)
                shouldFire = true
            end
        end

        if shouldFire then
            bot._peacekeeperPhase = "fire_press"
            bot._peacekeeperPhaseTime = CurTime()
            return STATUS.RUNNING
        end

        return STATUS.RUNNING
    end

    -- ══════════════════════════════════════════════════════════════════════
    -- Phase: FIRE_PRESS — press primary to fire at locked targets
    -- The SWEP's PrimaryAttack() fires when state == "charging" and
    -- #highnoontargets > 0
    -- ══════════════════════════════════════════════════════════════════════
    if bot._peacekeeperPhase == "fire_press" then
        if highNoonState == "firing" or highNoonState == "none" then
            -- Successfully fired or weapon ended
            loco:StopAttack()
            return STATUS.SUCCESS
        end

        -- Press primary to fire
        loco:StartAttack()

        -- Safety: if we've been trying to fire for too long, abort
        bot._peacekeeperFireAttempts = (bot._peacekeeperFireAttempts or 0) + 1
        if CurTime() - bot._peacekeeperPhaseTime > 3.0 then
            loco:StopAttack()
            return STATUS.FAILURE
        end

        return STATUS.RUNNING
    end

    -- Fallback — shouldn't reach here
    return STATUS.RUNNING
end

function UsePeacekeeper.OnSuccess(bot)
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("PeacekeeperFired", {}, false)
    end
end

function UsePeacekeeper.OnFailure(bot) end

function UsePeacekeeper.OnEnd(bot)
    bot._peacekeeperStart = nil
    bot._peacekeeperChargeStart = nil
    bot._peacekeeperPhase = nil
    bot._peacekeeperPhaseTime = nil
    bot._peacekeeperFireAttempts = nil
    bot._peacekeeperSawFiringState = nil
    bot._peacekeeperEquipped = nil
    bot._peacekeeperSweepIndex = nil
    bot._peacekeeperLastSweepTime = nil
    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if loco then
        loco:StopAttack()
        loco:StopAttack2()
        loco:ResumeAttackCompat()
        loco:SetHalt(false)
    end
    if inv then
        inv:ResumeAutoSwitch()
    end
end
