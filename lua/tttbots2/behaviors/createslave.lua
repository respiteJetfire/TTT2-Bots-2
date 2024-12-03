

---@class BSlave
TTTBots.Behaviors.CreateSlave = {}

local lib = TTTBots.Lib

---@class BSlave
local CreateSlave = TTTBots.Behaviors.CreateSlave
CreateSlave.Name = "Slave"
CreateSlave.Description = "Slave a player (or random player) and ultimately kill them."
CreateSlave.Interruptible = false


local STATUS = TTTBots.STATUS

---Give a weight to how isolated 'other' is to us. This is used to determine who to Slave.
---A higher isolation means the player is more isolated, and thus a better target for Slaveing.
---@param bot Bot
---@param other Player
---@return number
function CreateSlave.RateIsolation(bot, other)
    return lib.RateIsolation(bot, other)
end

---Find the best target to Slave, and return it. This is a pretty expensive function, so don't call it too often.
---@param bot Bot
---@return Player?
---@return number
function CreateSlave.FindTarget(bot)
    return lib.FindCloseTarget(bot, nil, false, false, true, true)
end

function CreateSlave.ClearTarget(bot)
    bot.SlaveTarget = nil
end

---@class Bot
---@field SlaveTarget Player?

---Sets the target to target, or if target is nil, then it will find a new target. If you want to clear the target, then see Slave.ClearTarget.
---@see Slave.ClearTarget
---@param bot Bot
---@param target Player?
function CreateSlave.SetTarget(bot, target)
    bot.SlaveTarget = target or CreateSlave.FindTarget(bot)
end

function CreateSlave.GetTarget(bot)
    return bot.SlaveTarget
end

---validate if we can attack the bot's target, or the given target if applicable.
---@param bot Bot
---@param target? Player
---@return boolean
function CreateSlave.ValidateTarget(bot, target)
    local target = target or CreateSlave.GetTarget(bot)
    local valid = target and IsValid(target) and lib.IsPlayerAlive(target)
    -- print("CreateSlave.ValidateTarget", valid)
    return valid
end

---Since situations change quickly, we want to make sure we pick the best target for the situation when we can.
---@param bot Bot
function CreateSlave.CheckForBetterTarget(bot)
    local alternative = CreateSlave.FindTarget(bot)

    if not alternative then return end
    if not CreateSlave.ValidateTarget(bot, alternative) then return end


    CreateSlave.SetTarget(bot, alternative)
end

---Should we start Slaveing? This is only useful for when we don't already have a target. To make the behavior more varied.
---@param bot Bot
---@return boolean
function CreateSlave.ShouldStartSlaveing(bot)
    local chance = math.random(0, 100) <= 2
    return TTTBots.Match.IsRoundActive() and chance
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function CreateSlave.Validate(bot)
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then CreateSlave.GetTarget(bot, bot.attackTarget) end          -- Do not Slave if we're killing someone already.
    local inv = bot:BotInventory()
    if not (inv and inv:GetSlaveGun()) then return false end -- Do not Slave if we don't have a jackal gun.
    return CreateSlave.ValidateTarget(bot) or CreateSlave.ShouldStartSlaveing(bot)
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateSlave.OnStart(bot)
    if not CreateSlave.ValidateTarget(bot) then
        CreateSlave.SetTarget(bot)
    end

    local chatter = bot:BotChatter()
    chatter:On("CreatingSlave", {player = bot.SlaveTarget:Nick()}, true)

    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateSlave.OnRunning(bot)
    if not CreateSlave.ValidateTarget(bot) then return STATUS.FAILURE end
    local target = CreateSlave.GetTarget(bot)
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()

    if not (math.random(1, TTTBots.Tickrate * 2) == 1 and bot:Visible(target)) then
        CreateSlave.CheckForBetterTarget(bot)
        if CreateSlave.GetTarget(bot) ~= target then return STATUS.RUNNING end
    end

    local isClose = bot:Visible(target) and bot:GetPos():Distance(targetPos) <= 1000
    local loco = bot:BotLocomotor()
    local inv = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end
    loco:SetGoal(targetPos)
    if not isClose then return STATUS.RUNNING end
    loco:LookAt(targetEyes)
    loco:SetGoal()
    inv:PauseAutoSwitch()
    local equipped = inv:EquipSlaveGun()
    -- if not equipped then return STATUS.RUNNING end
    local bodyPos = TTTBots.Behaviors.AttackTarget.GetTargetBodyPos(target)
    loco:LookAt(bodyPos)
    local eyeTrace = bot:GetEyeTrace()
    if eyeTrace and eyeTrace.Entity == target then
        loco:StartAttack()
    end
    return STATUS.RUNNING
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function CreateSlave.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function CreateSlave.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function CreateSlave.OnEnd(bot)
    CreateSlave.ClearTarget(bot)
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
