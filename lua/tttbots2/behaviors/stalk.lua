

---@class BStalk
TTTBots.Behaviors.Stalk = {}

local lib = TTTBots.Lib

---@class Bot
---@field StalkTarget Player? The target to stalk
---@field StalkScore number The isolation score of the target

---@class BStalk
local Stalk = TTTBots.Behaviors.Stalk
Stalk.Name = "Stalk"
Stalk.Description = "Stalk a player (or random player) and ultimately kill them."
Stalk.Interruptible = true


local STATUS = TTTBots.STATUS

---Give a weight to how isolated 'other' is to us. This is used to determine who to stalk.
---A higher isolation means the player is more isolated, and thus a better target for stalking.
---@param bot Bot
---@param other Player
---@return number
function Stalk.RateIsolation(bot, other)
    return lib.RateIsolation(bot, other)
end

---Find the best target to stalk, and return it. This is a pretty expensive function, so don't call it too often.
---@param bot Bot
---@return Player?
---@return number
function Stalk.FindTarget(bot)
    if bot:GetSubRole() == ROLE_SERIALKILLER then
        return Stalk.FindSerialKillerTarget(bot)
    end
    return lib.FindIsolatedTarget(bot)
end

---Score a single player as a serial killer target. Higher = higher priority to kill.
---Factors in: police/detective roles (immediate threat), player health (wounded = easier),
---and witness count (fewer bystanders = safer opportunity). Uses actual positions since
---serial killers are omniscient via GetKnowsAllPositions.
---@param bot Bot
---@param ply Player
---@return number score
function Stalk.RateSerialKillerTarget(bot, ply)
    if not IsValid(ply) then return -math.huge end
    if not lib.IsPlayerAlive(ply) then return -math.huge end

    local score = 0

    -- Police roles (detective, sheriff, deputy) are the highest-priority targets —
    -- they have the tools and authority to identify and counter the serial killer.
    local role = TTTBots.Roles.GetRoleFor(ply)
    if role and role:GetAppearsPolice() then
        score = score + 10
    end

    -- Players with a higher base role threat: traitors may fight back or call KOS.
    local baseRole = ply:GetBaseRole()
    if baseRole == ROLE_TRAITOR then
        score = score + 3
    end

    -- Wounded players are easier to eliminate.
    local healthRatio = math.Clamp(ply:Health() / math.max(ply:GetMaxHealth(), 1), 0, 1)
    score = score + (1 - healthRatio) * 2 -- up to +2 for nearly-dead targets

    -- Witnesses penalty: fewer bystanders = safer to commit the kill.
    -- Since serial killers know all positions, this uses a lightweight nearby check.
    local witnesses = lib.GetAllWitnessesBasic(ply:GetPos(), TTTBots.Roles.GetNonAllies(bot), bot)
    score = score - (table.Count(witnesses) * 0.5)

    -- Distance penalty: closer targets can be reached faster.
    local dist = bot:GetPos():Distance(ply:GetPos())
    score = score - (dist * 0.0005) -- 1000 hu ≈ -0.5

    return score
end

---Find the highest-value target for a serial killer bot using omniscient position knowledge.
---@param bot Bot
---@return Player?
---@return number
function Stalk.FindSerialKillerTarget(bot)
    local nonAllies = TTTBots.Roles.GetNonAllies(bot)
    local bestScore = -math.huge
    local bestTarget = nil

    for _, ply in ipairs(nonAllies) do
        local score = Stalk.RateSerialKillerTarget(bot, ply)
        if score > bestScore then
            bestScore = score
            bestTarget = ply
        end
    end

    return bestTarget, bestScore
end

function Stalk.ClearTarget(bot)
    bot.StalkTarget = nil
end

---Sets the target to target, or if target is nil, then it will find a new target. If you want to clear the target, then see Stalk.ClearTarget.
---@see Stalk.ClearTarget
---@param bot Bot
---@param target Player?
---@param score number? Pre-computed target score (isolation score or serial killer value score). Computed automatically if nil.
function Stalk.SetTarget(bot, target, score)
    local isSerialKiller = bot:GetSubRole() == ROLE_SERIALKILLER
    bot.StalkTarget = target or Stalk.FindTarget(bot)
    if score then
        bot.StalkScore = score
    elseif isSerialKiller then
        bot.StalkScore = bot.StalkTarget and Stalk.RateSerialKillerTarget(bot, bot.StalkTarget) or -math.huge
    else
        bot.StalkScore = bot.StalkTarget and Stalk.RateIsolation(bot, bot.StalkTarget) or -math.huge
    end
end

function Stalk.GetTarget(bot)
    return bot.StalkTarget
end

---validate if we can attack the bot's target, or the given target if applicable.
---@param bot Bot
---@param target? Player
---@return boolean
function Stalk.ValidateTarget(bot, target)
    local target = target or Stalk.GetTarget(bot)
    local valid = target and IsValid(target) and lib.IsPlayerAlive(target)
    return valid
end

---Should we start stalking? This is only useful for when we don't already have a target. To make the behavior more varied.
---@param bot Bot
---@return boolean
function Stalk.ShouldStartStalking(bot)
    -- local chance = math.random(0, 100) <= 2
    return TTTBots.Match.IsRoundActive() -- and chance
end

---Since situations change quickly, we want to make sure we pick the best target for the situation when we can.
---@param bot Bot
function Stalk.CheckForBetterTarget(bot)
    local currentScore = bot.StalkScore or -math.huge
    local alternative, altScore = Stalk.FindTarget(bot)

    if not alternative then return end
    if not Stalk.ValidateTarget(bot, alternative) then return end

    -- check for a difference of at least +1
    if altScore and altScore - currentScore >= 1 then
        Stalk.SetTarget(bot, alternative, altScore)
    end
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function Stalk.Validate(bot)
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then return false end -- Do not stalk if we're killing someone already.
    return Stalk.ValidateTarget(bot) or Stalk.ShouldStartStalking(bot)
end

---Compute an urgency value [0, 1] for serial killer bots based on dead-player ratio and elapsed round time.
---A higher urgency means fewer players remain alive or more time has passed, warranting bolder action.
---@param bot Bot
---@return number urgency
function Stalk.GetSerialKillerUrgency(bot)
    local Match = TTTBots.Match
    local aliveCount = #Match.AlivePlayers
    local startingCount = math.max(table.Count(Match.PlayersInRound), 1)
    local deadRatio = 1 - (aliveCount / startingCount)

    local elapsed = Match.Time()
    -- Use the server's round time limit if available, otherwise assume 8-minute rounds
    local roundTimeCVar = GetConVar("ttt2_round_timelimit") or GetConVar("ttt_roundtime")
    local roundSecs = (roundTimeCVar and roundTimeCVar:GetInt() * 60) or 480
    local timeRatio = math.Clamp(elapsed / math.max(roundSecs, 1), 0, 1)

    return math.Clamp((deadRatio * 0.5) + (timeRatio * 0.5), 0, 1)
end

---Return the maximum number of witnesses the serial killer will tolerate before committing to a kill.
---Scales from 1 (stealthy, early round) up to 3 (desperate, late round / few survivors) inclusive.
---@param bot Bot
---@return number maxWitnesses
function Stalk.GetMaxWitnessesForSerialKiller(bot)
    local urgency = Stalk.GetSerialKillerUrgency(bot)
    return math.floor(1 + urgency * 2) -- [1, 3] inclusive
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function Stalk.OnStart(bot)
    if not Stalk.ValidateTarget(bot) then
        Stalk.SetTarget(bot)
    end

    if bot:GetSubRole() == ROLE_SERIALKILLER then
        local chatter = bot:BotChatter()
        local target = Stalk.GetTarget(bot)
        if chatter and target then
            chatter:On("SerialKillerStalking", { player = target:Nick() }, false, math.random(1, 6))
        end
    end

    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function Stalk.OnRunning(bot)
    local isSerialKiller = bot:GetSubRole() == ROLE_SERIALKILLER

    -- Serial killers re-evaluate their target every cycle using omniscient knowledge,
    -- so they always pursue the highest-value prey on the map.
    if isSerialKiller then
        Stalk.CheckForBetterTarget(bot)
    end

    if not Stalk.ValidateTarget(bot) then return STATUS.FAILURE end
    local target = Stalk.GetTarget(bot)
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()

    -- Serial killers always know the target's real position; navigate directly to it.
    -- Other roles use their memory of last-known position if they can't see the target.
    local navigatePos
    if isSerialKiller then
        navigatePos = targetPos
    else
        local memory = bot.components and bot.components.memory
        navigatePos = (memory and memory:GetKnownPositionFor(target)) or targetPos
    end
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end
    loco:SetGoal(navigatePos)

    local isClose = bot:Visible(target) and bot:GetPos():Distance(targetPos) <= 150
    if not isClose then return STATUS.RUNNING end
    loco:LookAt(targetEyes)
    loco:SetGoal()

    local maxWitnesses = isSerialKiller and Stalk.GetMaxWitnessesForSerialKiller(bot) or 1

    local witnesses = lib.GetAllWitnessesBasic(targetPos, TTTBots.Roles.GetNonAllies(bot), bot)
    if table.Count(witnesses) <= maxWitnesses then
        if math.random(1, 3) == 1 then -- Just some extra randomness for fun!
            if isSerialKiller then
                local chatter = bot:BotChatter()
                local urgency = Stalk.GetSerialKillerUrgency(bot)
                if chatter and urgency >= 0.65 then
                    chatter:On("SerialKillerClosingIn", {}, false, math.random(1, 5))
                end
            end
            bot:SetAttackTarget(target)
            return STATUS.SUCCESS
        end
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function Stalk.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function Stalk.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function Stalk.OnEnd(bot)
    Stalk.ClearTarget(bot)
end
