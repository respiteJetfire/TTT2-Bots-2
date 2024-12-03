

---@class BLovers
TTTBots.Behaviors.CreateLovers = {}

local lib = TTTBots.Lib

---@class BLovers
local CreateLovers = TTTBots.Behaviors.CreateLovers
CreateLovers.Name = "Lovers"
CreateLovers.Description = "Lovers a player (or random player) and ultimately kill them."
CreateLovers.Interruptible = true

local targets = {}


local STATUS = TTTBots.STATUS

---Find the best target to Lovers, and return it. This is a pretty expensive function, so don't call it too often.
---@param bot Bot
---@return Player?
---@return number
function CreateLovers.FindTarget(bot)
    local Alive = TTTBots.Match.AlivePlayers
    --- find the closest player that is not the bot and is also not in the LoversTargets table.
    local dist = math.huge
    local closest = nil
    for _, ply in ipairs(Alive) do
        if ply == bot then continue end
        if targets[ply] then continue end
        local d = bot:GetPos():Distance(ply:GetPos())
        if d < dist then
            dist = d
            closest = ply
        end
    end
    return closest
end

function CreateLovers.ClearTarget(bot)
    bot.LoversTarget = nil
end

---@class Bot
---@field LoversTarget Player?

---Sets the target to target, or if target is nil, then it will find a new target. If you want to clear the target, then see Lovers.ClearTarget.
---@see Lovers.ClearTarget
---@param bot Bot
---@param target Player?
function CreateLovers.SetTarget(bot, target)
    bot.LoversTarget = target or CreateLovers.FindTarget(bot)
end

function CreateLovers.GetTarget(bot)
    return bot.LoversTarget
end

---validate if we can attack the bot's target, or the given target if applicable.
---@param bot Bot
---@param target? Player
---@return boolean
function CreateLovers.ValidateTarget(bot, target)
    local target = target or CreateLovers.GetTarget(bot)
    local valid = target and IsValid(target) and lib.IsPlayerAlive(target) and not targets[target]
    -- print("CreateLovers.ValidateTarget", valid)
    return valid
end

---Since situations change quickly, we want to make sure we pick the best target for the situation when we can.
---@param bot Bot
function CreateLovers.CheckForBetterTarget(bot)
    local alternative = CreateLovers.FindTarget(bot)

    if not alternative then return end
    if not CreateLovers.ValidateTarget(bot, alternative) then return end


    CreateLovers.SetTarget(bot, alternative)
end

---Should we start Loversing? This is only useful for when we don't already have a target. To make the behavior more varied.
---@param bot Bot
---@return boolean
function CreateLovers.ShouldStartLoversing(bot)
    local chance = math.random(0, 100) <= 2
    return TTTBots.Match.IsRoundActive() and chance
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function CreateLovers.Validate(bot)
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then return false end          -- Do not Lovers if we're killing someone already.
    local inv = bot:BotInventory()
    if not (inv and inv:GetLoversGun()) then return false end -- Do not Lovers if we don't have a jackal gun.
    return CreateLovers.ValidateTarget(bot) or CreateLovers.ShouldStartLoversing(bot)
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateLovers.OnStart(bot)
    if not CreateLovers.ValidateTarget(bot) then
        CreateLovers.SetTarget(bot)
    end

    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateLovers.OnRunning(bot)
    if not CreateLovers.ValidateTarget(bot) then return STATUS.FAILURE end
    local target = CreateLovers.GetTarget(bot)
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()

    if not (math.random(1, TTTBots.Tickrate * 2) == 1 and bot:Visible(target)) then
        CreateLovers.CheckForBetterTarget(bot)
        if CreateLovers.GetTarget(bot) ~= target then return STATUS.RUNNING end
    end

    local isClose = bot:Visible(target) and bot:GetPos():Distance(targetPos) <= 150
    local loco = bot:BotLocomotor()
    local inv = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end
    loco:SetGoal(targetPos)
    if not isClose then return STATUS.RUNNING end
    loco:LookAt(targetEyes)
    loco:SetGoal()
    inv:PauseAutoSwitch()
    local equipped = inv:EquipLoversGun()
    -- if not equipped then return STATUS.RUNNING end
    local bodyPos = TTTBots.Behaviors.AttackTarget.GetTargetBodyPos(target)
    loco:LookAt(bodyPos)
    local eyeTrace = bot:GetEyeTrace()
    if eyeTrace and eyeTrace.Entity == target then
        loco:StartAttack()
        print("Loversing", bot, target)
        targets[target] = true
        return STATUS.SUCCESS
    end
    return STATUS.RUNNING
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function CreateLovers.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function CreateLovers.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function CreateLovers.OnEnd(bot)
    CreateLovers.ClearTarget(bot)
    local loco = bot:BotLocomotor()
    if not loco then return end
    loco:StopAttack()
    bot:SetAttackTarget(nil)
    timer.Simple(1, function()
        if not IsValid(bot) then return end
        local inv = bot:BotInventory()
        if not (inv) then return end
        inv:ResumeAutoSwitch()
    end)
end
