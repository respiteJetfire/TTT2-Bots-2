--- behaviors/usetimestop.lua
--- Uses the Time Stop weapon (weapon_ttt_timestop) to freeze nearby enemies.
--- The bot should use this when multiple enemies are near and it has a strategic
--- advantage. This behavior is intentionally stateful because the behavior tree
--- re-validates every tick; once a bot commits to using timestop it must be
--- allowed to finish the activation sequence.

local lib = TTTBots.Lib
local STATUS = TTTBots.STATUS

---@class BUseTimestop
TTTBots.Behaviors.UseTimestop = {}

local UseTimestop = TTTBots.Behaviors.UseTimestop
UseTimestop.Name = "UseTimestop"
UseTimestop.Description = "Use the Time Stop weapon to freeze nearby enemies."
UseTimestop.Interruptible = false

local BEHAVIOR_NAME = "UseTimestop"
local COMMIT_TIMEOUT = 3.0
local SUCCESS_GRACE = 0.25
local PANIC_HEALTH_THRESHOLD = 45
local CLOSE_ENEMY_DISTANCE = 375

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
    if not UseTimestop.HasTimestop(bot) then return false end

    local state = GetState(bot)
    if state.committed then
        return true
    end

    -- Check that the weapon has a charge left
    local wep = UseTimestop.GetTimestop(bot)
    if not wep then return false end
    if wep:Clip1() <= 0 then return false end

    local assessment = AssessNearbyTargets(bot)
    if not ShouldUseTimestop(bot, assessment) then return false end

    state.cachedAssessment = assessment
    return true
end

function UseTimestop.OnStart(bot)
    local state = GetState(bot)
    state.startedAt = CurTime()
    state.committed = true
    state.fired = false

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

    if not UseTimestop.HasTimestop(bot) then
        return state.fired and STATUS.SUCCESS or STATUS.FAILURE
    end

    local wep = UseTimestop.GetTimestop(bot)
    if not wep then return state.fired and STATUS.SUCCESS or STATUS.FAILURE end

    if state.fired then
        if (CurTime() - (state.firedAt or 0)) >= SUCCESS_GRACE then
            return STATUS.SUCCESS
        end

        return STATUS.RUNNING
    end

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
    end

    return STATUS.RUNNING
end

function UseTimestop.OnSuccess(bot)
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("TimestopUsed", {}, true)
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
