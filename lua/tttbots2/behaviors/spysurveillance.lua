---@class BSpySurveillance
TTTBots.Behaviors.SpySurveillance = {}

local lib = TTTBots.Lib

---@class BSpySurveillance
local SpySurveillance = TTTBots.Behaviors.SpySurveillance
SpySurveillance.Name = "SpySurveillance"
SpySurveillance.Description = "Spy shadows a suspicious player to gather intel and report their movements."
SpySurveillance.Interruptible = true

---@class Bot
---@field spySurveillanceTarget Player? The player currently under surveillance
---@field spySurveillanceEndTime number The time at which we should stop surveillance

local STATUS = TTTBots.STATUS

local SPY_FOLLOW_DISTANCE = 350  -- Maximum distance in units to maintain from target
local SPY_MIN_DISTANCE = 150     -- Minimum distance; don't get too close
local SPY_MAX_FOLLOW_TIME = 18   -- How long to follow in seconds (max)
local SPY_MIN_FOLLOW_TIME = 8    -- How long to follow in seconds (min)
local SUS_THRESHOLD = 3          -- Minimum suspicion level to begin surveillance (matches Morality.Thresholds.Sus)

--- Get the current suspicion that this bot has on a given player.
---@param bot Bot
---@param target Player
---@return number
function SpySurveillance.GetSuspicion(bot, target)
    local morality = bot.components.Morality
    if not morality then return 0 end
    return morality:GetSuspicion(target)
end

--- Find the most suspicious player worth surveilling.
--- Returns the player with the highest suspicion above the threshold.
---@param bot Bot
---@return Player?
function SpySurveillance.FindSurveillanceTarget(bot)
    local memory = bot.components.memory
    if not memory then return nil end

    local recentPlayers = memory:GetRecentlySeenPlayers(8)
    local bestTarget = nil
    local bestSus = SUS_THRESHOLD -- minimum threshold to qualify

    for _, other in ipairs(recentPlayers) do
        if not lib.IsPlayerAlive(other) then continue end
        if other == bot then continue end
        if TTTBots.Roles.IsAllies(bot, other) then continue end

        local sus = SpySurveillance.GetSuspicion(bot, other)
        if sus > bestSus then
            bestSus = sus
            bestTarget = other
        end
    end

    return bestTarget
end

--- Validate that our current surveillance target is still worth following.
---@param bot Bot
---@return boolean
function SpySurveillance.ValidateCurrentTarget(bot)
    local target = bot.spySurveillanceTarget
    if not target or not IsValid(target) then return false end
    if not lib.IsPlayerAlive(target) then return false end
    -- Drop target if they are no longer suspicious enough
    if SpySurveillance.GetSuspicion(bot, target) < SUS_THRESHOLD then return false end
    return true
end

--- Validate the behavior before we can start it (or continue running).
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function SpySurveillance.Validate(bot)
    if not IsValid(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.attackTarget ~= nil then return false end
    if bot:GetSubRole() ~= ROLE_SPY then return false end

    -- If already surveilling someone and they are still valid, continue
    if SpySurveillance.ValidateCurrentTarget(bot) then return true end

    -- Otherwise look for a new target
    return SpySurveillance.FindSurveillanceTarget(bot) ~= nil
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle.
---@param bot Bot
---@return BStatus
function SpySurveillance.OnStart(bot)
    local target = SpySurveillance.FindSurveillanceTarget(bot)
    if not target then return STATUS.FAILURE end

    bot.spySurveillanceTarget = target
    bot.spySurveillanceEndTime = CurTime() + math.random(SPY_MIN_FOLLOW_TIME, SPY_MAX_FOLLOW_TIME)

    local chatter = bot:BotChatter()
    if chatter then
        chatter:On("SpySurveillance", { player = target:Nick() })
    end

    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING.
---@param bot Bot
---@return BStatus
function SpySurveillance.OnRunning(bot)
    if not SpySurveillance.ValidateCurrentTarget(bot) then
        return STATUS.FAILURE
    end

    if CurTime() > (bot.spySurveillanceEndTime or 0) then
        return STATUS.SUCCESS
    end

    local target = bot.spySurveillanceTarget
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    local targetPos = target:GetPos()
    local distToTarget = bot:GetPos():Distance(targetPos)

    if distToTarget > SPY_FOLLOW_DISTANCE then
        -- Too far away — move closer while keeping eyes on target
        loco:SetGoal(targetPos)
        loco:LookAt(target:EyePos())
    elseif distToTarget < SPY_MIN_DISTANCE then
        -- Too close — back off a little to avoid suspicion
        local awayDir = (bot:GetPos() - targetPos):GetNormalized()
        loco:SetGoal(bot:GetPos() + awayDir * 80)
        loco:LookAt(target:EyePos())
    else
        -- In range — hold position and observe
        loco:SetGoal(bot:GetPos())
        loco:LookAt(target:EyePos())
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state.
---@param bot Bot
function SpySurveillance.OnSuccess(bot)
end

--- Called when the behavior returns a failure state.
---@param bot Bot
function SpySurveillance.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup.
---@param bot Bot
function SpySurveillance.OnEnd(bot)
    bot.spySurveillanceTarget = nil
    bot.spySurveillanceEndTime = nil
end
