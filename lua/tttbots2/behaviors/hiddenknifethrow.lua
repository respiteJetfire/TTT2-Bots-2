--- hiddenknifethrow.lua
--- Hidden thrown knife behavior.
--- Uses M2 (secondary fire) on weapon_ttt_hd_knife to throw the knife as a projectile.
--- The knife projectile does 50+ damage (scales with distance) and instant-kills
--- targets below the damage threshold. After throwing, the knife is on a 15s cooldown.
---
--- Only throw when:
---   1. Target is wounded but fleeing (out of melee range)
---   2. Target is at medium range (150-500 units) and visible
---   3. Target is stunned (easy hit, guaranteed value)
---   4. No melee target is available (melee is always preferred — no cooldown on M1)
---
--- The 15s cooldown means wasting a throw is very costly.

---@class BHiddenKnifeThrow
TTTBots.Behaviors.HiddenKnifeThrow = {}

local lib = TTTBots.Lib
---@class BHiddenKnifeThrow
local KnifeThrow = TTTBots.Behaviors.HiddenKnifeThrow
KnifeThrow.Name = "HiddenKnifeThrow"
KnifeThrow.Description = "Throw knife at wounded/distant targets as Hidden."
KnifeThrow.Interruptible = true

local STATUS = TTTBots.STATUS
local HD_KNIFE_CLASS = "weapon_ttt_hd_knife"
local THROW_MIN_DIST = 150   -- minimum distance — prefer melee if closer
local THROW_MAX_DIST = 500   -- maximum distance — projectile accuracy falls off
local THROW_HP_THRESHOLD = 60 -- only throw at targets below this HP (unless stunned)

--- Returns true if this bot is the Hidden in stalker mode.
---@param bot Bot
---@return boolean
local function isHiddenStalker(bot)
    if not bot then return false end
    local roleStr = bot.GetRoleStringRaw and bot:GetRoleStringRaw() or ""
    if roleStr ~= "hidden" then return false end
    return bot:GetNWBool("ttt2_hd_stalker_mode", false)
end

--- Returns the Hidden knife weapon if the bot has it.
---@param bot Bot
---@return Weapon|nil
local function getHiddenKnife(bot)
    if not bot:HasWeapon(HD_KNIFE_CLASS) then return nil end
    local wep = bot:GetWeapon(HD_KNIFE_CLASS)
    return IsValid(wep) and wep or nil
end

--- Check if a target is stunned by the Hidden's stun grenade.
---@param target Player
---@return boolean
local function isStunned(target)
    return target:GetNWBool("ttt2_hdnade_stun", false)
end

--- Check if there's a viable melee target nearby (if so, don't throw — melee is better).
---@param bot Bot
---@return boolean hasMeleeTarget
local function hasMeleeTarget(bot)
    local botPos = bot:GetPos()
    for _, ply in ipairs(player.GetAll()) do
        if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end
        if ply == bot then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then continue end

        local dist = botPos:Distance(ply:GetPos())
        if dist <= 150 and bot:Visible(ply) then
            return true
        end
    end
    return false
end

--- Find the best target for a thrown knife.
---@param bot Bot
---@return Player? target
---@return number score
local function findBestThrowTarget(bot)
    local bestTarget = nil
    local bestScore  = -math.huge
    local botPos = bot:GetPos()

    for _, ply in ipairs(player.GetAll()) do
        if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end
        if ply == bot then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then continue end

        local targetPos = ply:GetPos()
        local dist = botPos:Distance(targetPos)

        -- Must be in throw range
        if dist < THROW_MIN_DIST or dist > THROW_MAX_DIST then continue end

        -- Must be visible (can't throw through walls)
        if not bot:Visible(ply) then continue end

        local hp = ply:Health()
        local stunned = isStunned(ply)

        -- Only throw at wounded targets or stunned targets
        if hp >= THROW_HP_THRESHOLD and not stunned then continue end

        local score = 0

        -- Prefer lower HP targets (more likely to die from throw)
        score = score + math.max(0, THROW_HP_THRESHOLD - hp) * 1.5

        -- Big bonus for stunned targets (they can't dodge)
        if stunned then
            score = score + 35
        end

        -- Prefer targets at medium range (sweet spot for thrown knife)
        -- Closest to 250 units is optimal
        local rangeDelta = math.abs(dist - 250)
        score = score + math.max(0, 200 - rangeDelta) / 10

        -- Prefer targets moving slowly or standing still (easier to hit)
        local vel = ply:GetVelocity():Length()
        if vel < 50 then
            score = score + 15
        elseif vel < 150 then
            score = score + 5
        else
            score = score - 10  -- fast-moving targets are hard to hit
        end

        if score > bestScore then
            bestScore = score
            bestTarget = ply
        end
    end

    return bestTarget, bestScore
end

--- Validate: only run as Hidden in stalker mode, must have knife, no melee target available.
---@param bot Bot
---@return boolean
function KnifeThrow.Validate(bot)
    if not isHiddenStalker(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if IsValid(bot.attackTarget) then return false end
    if not getHiddenKnife(bot) then return false end

    -- Don't throw if there's a melee target — melee is always preferred
    if hasMeleeTarget(bot) then return false end

    local target, score = findBestThrowTarget(bot)
    return IsValid(target) and score > 0
end

--- Called when the behavior starts.
---@param bot Bot
---@return BStatus
function KnifeThrow.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "HiddenKnifeThrow")
    state.throwPhase = "equip"   -- phases: equip -> aim -> throw -> done
    state.phaseStart = CurTime()
    state.throwTarget = nil

    local target, _ = findBestThrowTarget(bot)
    if IsValid(target) then
        state.throwTarget = target
    end

    return STATUS.RUNNING
end

--- Called each tick while running.
---@param bot Bot
---@return BStatus
function KnifeThrow.OnRunning(bot)
    if not isHiddenStalker(bot) then return STATUS.FAILURE end
    if not TTTBots.Match.IsRoundActive() then return STATUS.FAILURE end

    local state = TTTBots.Behaviors.GetState(bot, "HiddenKnifeThrow")
    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    local throwTarget = state.throwTarget
    if not (IsValid(throwTarget) and lib.IsPlayerAlive(throwTarget)) then
        return STATUS.FAILURE
    end

    local phase = state.throwPhase
    local elapsed = CurTime() - (state.phaseStart or CurTime())

    if phase == "equip" then
        -- Equip the Hidden knife
        inv:PauseAutoSwitch()
        local knife = getHiddenKnife(bot)
        if not knife then
            return STATUS.FAILURE
        end
        bot:SelectWeapon(HD_KNIFE_CLASS)

        -- Stop moving to aim
        loco:SetGoal()

        state.throwPhase = "aim"
        state.phaseStart = CurTime()
        return STATUS.RUNNING

    elseif phase == "aim" then
        -- Re-validate target is still throwable before committing
        if not (IsValid(throwTarget) and lib.IsPlayerAlive(throwTarget)) then
            return STATUS.FAILURE
        end
        local aimDist = bot:GetPos():Distance(throwTarget:GetPos())
        if aimDist < THROW_MIN_DIST or aimDist > THROW_MAX_DIST or not bot:Visible(throwTarget) then
            -- Target moved out of range or behind cover — abort to save the throw
            return STATUS.FAILURE
        end

        -- Aim at target — aim slightly above center mass to compensate for projectile arc
        local targetPos = throwTarget:GetPos() + Vector(0, 0, 40)
        loco:LookAt(targetPos)

        -- Brief delay to aim (0.3s)
        if elapsed >= 0.3 then
            state.throwPhase = "throw"
            state.phaseStart = CurTime()
        end
        return STATUS.RUNNING

    elseif phase == "throw" then
        -- Fire secondary attack (M2) to throw the knife
        loco:StartAttack2()

        -- Brief hold of attack2 (0.2s)
        if elapsed >= 0.2 then
            loco:StopAttack2()

            state.throwPhase = "done"
            state.phaseStart = CurTime()
        end
        return STATUS.RUNNING

    elseif phase == "done" then
        -- Cleanup and return success
        loco:StopAttack2()
        inv:ResumeAutoSwitch()
        return STATUS.SUCCESS
    end

    return STATUS.FAILURE
end

--- Called on success.
---@param bot Bot
function KnifeThrow.OnSuccess(bot)
end

--- Called on failure.
---@param bot Bot
function KnifeThrow.OnFailure(bot)
end

--- Called when the behavior ends (success or failure).
---@param bot Bot
function KnifeThrow.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "HiddenKnifeThrow")
    local loco = bot:BotLocomotor()
    if loco then
        loco:StopAttack2()
    end
    local inv = bot:BotInventory()
    if inv then
        inv:ResumeAutoSwitch()
    end
end
