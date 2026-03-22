--- behaviors/usetimestop.lua
--- Uses the Time Stop weapon (weapon_ttt_timestop) to freeze nearby enemies,
--- then hunts down and kills frozen players while time is stopped.
--- Only the caster remains unfrozen, so the bot switches to a real weapon
--- and methodically executes every frozen enemy within range before time
--- resumes.

local lib = TTTBots.Lib
local STATUS = TTTBots.STATUS

---@class BUseTimestop
TTTBots.Behaviors.UseTimestop = {}

local UseTimestop = TTTBots.Behaviors.UseTimestop
UseTimestop.Name = "UseTimestop"
UseTimestop.Description = "Activate Time Stop and kill frozen enemies."
UseTimestop.Interruptible = false

local BEHAVIOR_NAME = "UseTimestop"
local COMMIT_TIMEOUT = 3.0
local SUCCESS_GRACE = 0.25
local PANIC_HEALTH_THRESHOLD = 45
local CLOSE_ENEMY_DISTANCE = 375

--- How close the bot must be to a frozen target before shooting.
local EXECUTION_RANGE = 180
--- Time (seconds) the bot waits after the weapon signals it has fired
--- before transitioning to the hunting phase. This covers the 3-second
--- activation animation of the timestop weapon.
local HUNT_TRANSITION_DELAY = 3.5
--- How long the bot will look at a target before starting to shoot.
local AIM_SETTLE_TIME = 0.25
--- Minimum degrees the eye angle must be within to fire at a frozen target.
local AIM_THRESHOLD_DEG = 12

local function GetState(bot)
    return TTTBots.Behaviors.GetState(bot, BEHAVIOR_NAME)
end

local function GetRange()
    local cvar = GetConVar("ttt_timestop_range")
    if not cvar then return 1024 end

    local range = cvar:GetFloat()
    if range == 0 then return 0 end
    if range < 0 then return math.huge end

    return range
end

local function GetTimestopDuration()
    local cvar = GetConVar("ttt_timestop_time")
    if not cvar then return 5 end
    return cvar:GetFloat()
end

local function GetMinEnemies(bot)
    local awareness = bot.BotRoundAwareness and bot:BotRoundAwareness()
    local phase = awareness and awareness.GetPhase and awareness:GetPhase() or nil
    local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE

    if not (phase and PHASE) then return 2 end
    if phase == PHASE.EARLY then return 2 end
    if phase == PHASE.MID then return 2 end

    return 1
end

local function IsImmuneToTimestop(owner, target)
    if not (IsValid(owner) and IsValid(target) and target:IsPlayer()) then return false end

    local immuneTraitor = GetConVar("ttt_timestop_immune_traitor")
    if immuneTraitor and immuneTraitor:GetBool() and target.IsActiveTraitor and target:IsActiveTraitor() then
        return true
    end

    local immuneDetective = GetConVar("ttt_timestop_immune_detective")
    if immuneDetective and immuneDetective:GetBool() and target.IsActiveDetective and target:IsActiveDetective() then
        return true
    end

    return false
end

--- Check whether a player is currently frozen by Time Stop.
---@param ply Player
---@return boolean
local function IsTimeFrozen(ply)
    if not IsValid(ply) then return false end
    if not ply:IsPlayer() then return false end
    -- The timestop weapon sets NWBool "TimeStopped" on frozen entities
    -- and also calls Freeze(true) on them.  Check both.
    if ply:GetNWBool("TimeStopped", false) then return true end
    if ply.IsFrozen and ply:IsFrozen() then return true end
    return false
end

---@class TimestopAssessment
---@field enemies number
---@field allies number
---@field visibleEnemies number
---@field closeEnemies number
---@field nearestEnemy number
---@field enemyCenter Vector

---@param bot Bot
---@return TimestopAssessment
local function AssessNearbyTargets(bot)
    local range = GetRange()
    local assessment = {
        enemies = 0,
        allies = 0,
        visibleEnemies = 0,
        closeEnemies = 0,
        nearestEnemy = math.huge,
        enemyCenter = Vector(0, 0, 0),
    }

    if range == 0 then
        return assessment
    end

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() or ply == bot then continue end

        local dist = bot:GetPos():Distance(ply:GetPos())
        if dist > range then continue end
        if IsImmuneToTimestop(bot, ply) then continue end

        if TTTBots.Roles.IsAllies(bot, ply) then
            assessment.allies = assessment.allies + 1
        else
            assessment.enemies = assessment.enemies + 1
            assessment.enemyCenter = assessment.enemyCenter + ply:GetPos()
            assessment.nearestEnemy = math.min(assessment.nearestEnemy, dist)

            if dist <= CLOSE_ENEMY_DISTANCE then
                assessment.closeEnemies = assessment.closeEnemies + 1
            end

            if bot:Visible(ply) then
                assessment.visibleEnemies = assessment.visibleEnemies + 1
            end
        end
    end

    if assessment.enemies > 0 then
        assessment.enemyCenter = assessment.enemyCenter / assessment.enemies
    else
        assessment.nearestEnemy = math.huge
        assessment.enemyCenter = bot:GetPos() + bot:GetForward() * 128
    end

    return assessment
end

---@param bot Bot
---@param assessment TimestopAssessment
---@return boolean
local function ShouldUseTimestop(bot, assessment)
    if assessment.enemies <= 0 then return false end

    local minEnemies = GetMinEnemies(bot)
    local panicUse = bot:Health() <= PANIC_HEALTH_THRESHOLD and assessment.closeEnemies >= 1
    local combatUse = IsValid(bot.attackTarget) and assessment.visibleEnemies >= 1
    local surrounded = assessment.enemies >= minEnemies and assessment.enemies > assessment.allies

    if not (panicUse or combatUse or surrounded) then
        return false
    end

    if assessment.allies >= assessment.enemies and not panicUse then
        return false
    end

    local personality = bot.BotPersonality and bot:BotPersonality()
    local chance = 20
    if panicUse then chance = chance + 40 end
    if combatUse then chance = chance + 20 end
    if assessment.enemies >= 3 then chance = chance + 20 end

    if personality then
        if personality.GetTraitBool and personality:GetTraitBool("aggressive") then
            chance = chance + 10
        end
        if personality.GetTraitBool and personality:GetTraitBool("cautious") then
            chance = chance - 5
        end
    end

    return math.random(1, 100) <= math.Clamp(chance, 5, 95)
end

--- Build a priority-sorted list of frozen enemies the bot should hunt.
--- Closest targets come first so the bot wastes minimal travel time.
---@param bot Bot
---@return table<Player> frozenTargets
local function GetFrozenEnemies(bot)
    local range = GetRange()
    local targets = {}

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or ply == bot then continue end
        if not ply:Alive() or ply:IsSpec() then continue end
        if not TTTBots.Lib.IsPlayerAlive(ply) then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then continue end
        if IsImmuneToTimestop(bot, ply) then continue end
        if not IsTimeFrozen(ply) then continue end

        -- Must be within timestop range (or infinite range)
        local dist = bot:GetPos():Distance(ply:GetPos())
        if range ~= math.huge and dist > range then continue end

        table.insert(targets, ply)
    end

    -- Sort by distance — nearest first for efficiency.
    table.sort(targets, function(a, b)
        return bot:GetPos():DistToSqr(a:GetPos()) < bot:GetPos():DistToSqr(b:GetPos())
    end)

    return targets
end

--- Check if the bot has the timestop weapon.
---@param bot Bot
---@return boolean
function UseTimestop.HasTimestop(bot)
    return bot:HasWeapon("weapon_ttt_timestop")
end

--- Get the timestop weapon entity.
---@param bot Bot
---@return Weapon?
function UseTimestop.GetTimestop(bot)
    local wep = bot:GetWeapon("weapon_ttt_timestop")
    return IsValid(wep) and wep or nil
end

function UseTimestop.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end

    local state = GetState(bot)

    -- While hunting, stay valid as long as time is still stopped and we
    -- have frozen enemies left (or the weapon is still active).
    if state.hunting then
        return UseTimestop.ValidateHunting(bot, state)
    end

    if state.committed then
        return true
    end

    if not UseTimestop.HasTimestop(bot) then return false end

    -- Check that the weapon has a charge left
    local wep = UseTimestop.GetTimestop(bot)
    if not wep then return false end
    if wep:Clip1() <= 0 then return false end

    local assessment = AssessNearbyTargets(bot)
    if not ShouldUseTimestop(bot, assessment) then return false end

    state.cachedAssessment = assessment
    return true
end

--- Validate that the hunting phase should continue.
---@param bot Bot
---@param state table
---@return boolean
function UseTimestop.ValidateHunting(bot, state)
    -- Time ran out — stop hunting.
    if state.huntDeadline and CurTime() > state.huntDeadline then
        return false
    end

    -- Check if the timestop weapon still reports time as stopped.
    -- If the weapon entity was removed, fall back on the deadline.
    local wep = UseTimestop.GetTimestop(bot)
    if wep and wep.GetTimeStopped and not wep:GetTimeStopped() and not wep:GetTimeStopping() then
        return false
    end

    -- Are there still frozen enemies alive?
    local frozenTargets = GetFrozenEnemies(bot)
    if #frozenTargets == 0 then
        return false
    end

    return true
end

function UseTimestop.OnStart(bot)
    local state = GetState(bot)
    state.startedAt = CurTime()
    state.committed = true
    state.fired = false
    state.hunting = false
    state.huntTarget = nil
    state.huntKills = 0

    local assessment = state.cachedAssessment or AssessNearbyTargets(bot)
    state.aimPos = assessment.enemyCenter

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("UsingTimestop", {}, true)
    end

    return STATUS.RUNNING
end

function UseTimestop.OnRunning(bot)
    local state = GetState(bot)
    if not state.committed then return STATUS.FAILURE end

    -- ═══════════════════════════════════════════════════════════════════════
    -- PHASE 2: HUNTING — time is stopped, kill frozen enemies
    -- ═══════════════════════════════════════════════════════════════════════
    if state.hunting then
        return UseTimestop.RunHunting(bot, state)
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- PHASE 1: ACTIVATION — fire the timestop weapon
    -- ═══════════════════════════════════════════════════════════════════════

    -- The weapon may have been removed after firing (LimitedStock).
    -- If we already fired, wait for the transition delay then move to hunting.
    if state.fired then
        if (CurTime() - (state.firedAt or 0)) >= HUNT_TRANSITION_DELAY then
            -- Transition to hunting phase
            state.hunting = true
            state.huntDeadline = CurTime() + GetTimestopDuration()
            state.huntSwitchedWeapon = false
            state.aimStartedAt = nil

            local chatter = bot:BotChatter()
            if chatter and chatter.On then
                chatter:On("TimestopUsed", {}, true)
            end

            return STATUS.RUNNING
        end
        return STATUS.RUNNING
    end

    if not UseTimestop.HasTimestop(bot) then
        return STATUS.FAILURE
    end

    local wep = UseTimestop.GetTimestop(bot)
    if not wep then return STATUS.FAILURE end

    -- Timeout
    if state.startedAt and (CurTime() - state.startedAt) > COMMIT_TIMEOUT then
        return STATUS.FAILURE
    end

    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    inv:PauseAutoSwitch()
    loco:PauseAttackCompat()
    loco:SetHalt(true)

    bot:SelectWeapon("weapon_ttt_timestop")

    local aimPos = state.aimPos
    if IsValid(bot.attackTarget) then
        aimPos = bot.attackTarget:EyePos()
    elseif not aimPos then
        aimPos = bot:GetPos() + bot:GetForward() * 128
    end

    loco:LookAt(aimPos, 0.2)

    if bot:GetActiveWeapon() ~= wep then
        loco:StopAttack()
        return STATUS.RUNNING
    end

    loco:StartAttack()

    if wep:Clip1() <= 0 or (wep.GetTimeStopping and wep:GetTimeStopping()) or (wep.GetTimeStopped and wep:GetTimeStopped()) then
        state.fired = true
        state.firedAt = CurTime()
        loco:StopAttack()
        loco:SetHalt(false)
    end

    return STATUS.RUNNING
end

--- The hunting phase: bot walks to frozen enemies and shoots them.
---@param bot Bot
---@param state table
---@return BStatus
function UseTimestop.RunHunting(bot, state)
    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    -- Keep inventory paused so the bot doesn't swap away from our chosen weapon
    inv:PauseAutoSwitch()
    loco:PauseAttackCompat()

    -- Step 1: Switch to a combat weapon (only once)
    if not state.huntSwitchedWeapon then
        loco:StopAttack()
        loco:SetHalt(false)
        inv:ResumeAutoSwitch()

        -- Let the inventory system pick the best weapon for one tick
        -- by forcing an auto-manage cycle, then immediately re-pause.
        inv:AutoManageInventory()
        inv:PauseAutoSwitch()

        -- Fallback: if the bot still has the timestop weapon selected (or nothing),
        -- try to find any gun or crowbar.
        local held = bot:GetActiveWeapon()
        if not IsValid(held) or held:GetClass() == "weapon_ttt_timestop" then
            local weapons = bot:GetWeapons()
            for _, w in ipairs(weapons) do
                if IsValid(w) and w:GetClass() ~= "weapon_ttt_timestop" then
                    bot:SelectWeapon(w:GetClass())
                    break
                end
            end
        end

        state.huntSwitchedWeapon = true
        state.huntTarget = nil
        state.aimStartedAt = nil
        return STATUS.RUNNING
    end

    -- Step 2: Pick a frozen target
    local target = state.huntTarget
    if not IsValid(target) or not TTTBots.Lib.IsPlayerAlive(target) or not IsTimeFrozen(target) then
        -- Current target is dead or unfrozen — pick the next one
        local frozenTargets = GetFrozenEnemies(bot)
        if #frozenTargets == 0 then
            -- All frozen enemies are dead — mission accomplished
            return STATUS.SUCCESS
        end
        target = frozenTargets[1]
        state.huntTarget = target
        state.aimStartedAt = nil

        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("TimestopHunting", { target = target:Nick() }, true)
        end
    end

    -- Step 3: Navigate to the target and shoot them
    local targetPos = target:EyePos()
    local targetBodyPos = target:GetPos() + Vector(0, 0, 48) -- chest height
    local dist = bot:GetPos():Distance(target:GetPos())

    -- Look at the target's head
    local headBone = target:LookupBone("ValveBiped.Bip01_Head1")
    local aimPoint = targetPos
    if headBone then
        local headPos = target:GetBonePosition(headBone)
        if headPos then
            aimPoint = headPos
        end
    end

    loco:LookAt(aimPoint, 0.1)

    if dist > EXECUTION_RANGE then
        -- Walk toward the frozen target
        loco:StopAttack()
        loco:SetHalt(false)
        loco:SetGoal(target:GetPos())
        state.aimStartedAt = nil
        return STATUS.RUNNING
    end

    -- We're close enough — stop moving, aim, and fire
    loco:SetHalt(true)
    loco:SetGoal()

    -- Check aim angle before firing
    local degDiff = math.abs(loco:GetEyeAngleDiffTo(aimPoint))
    if degDiff > AIM_THRESHOLD_DEG then
        -- Still swinging aim toward target — don't fire yet
        loco:StopAttack()
        state.aimStartedAt = nil
        return STATUS.RUNNING
    end

    -- Brief settle time before pulling the trigger (looks more natural)
    if not state.aimStartedAt then
        state.aimStartedAt = CurTime()
    end

    if (CurTime() - state.aimStartedAt) < AIM_SETTLE_TIME then
        loco:StopAttack()
        return STATUS.RUNNING
    end

    -- FIRE!
    loco:StartAttack()

    -- Track kills for chatter
    if not TTTBots.Lib.IsPlayerAlive(target) then
        state.huntKills = (state.huntKills or 0) + 1
        state.huntTarget = nil
        state.aimStartedAt = nil
        loco:StopAttack()

        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("TimestopKill", { target = target:Nick(), kills = state.huntKills }, true)
        end
    end

    return STATUS.RUNNING
end

function UseTimestop.OnSuccess(bot)
    local state = GetState(bot)
    local kills = state.huntKills or 0
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        if kills > 0 then
            chatter:On("TimestopMassacre", { kills = kills }, true)
        else
            chatter:On("TimestopUsed", {}, true)
        end
    end
end

function UseTimestop.OnFailure(bot) end

function UseTimestop.OnEnd(bot)
    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if loco then
        loco:StopAttack()
        loco:SetHalt(false)
        loco:ResumeAttackCompat()
    end
    if inv then
        inv:ResumeAutoSwitch()
    end

    TTTBots.Behaviors.ClearState(bot, BEHAVIOR_NAME)
end
