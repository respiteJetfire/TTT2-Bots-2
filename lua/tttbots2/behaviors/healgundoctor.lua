

---@class BHealgunDoctor
TTTBots.Behaviors.HealgunDoctor = {}

local lib = TTTBots.Lib

---@class BHealgunDoctor
local HealgunDoctor = TTTBots.Behaviors.HealgunDoctor
HealgunDoctor.Name = "HealgunDoctor"
HealgunDoctor.Description = "HealgunDoctor a player (or random player) restore their HP to 100."
HealgunDoctor.Interruptible = true


local STATUS = TTTBots.STATUS

---Give a weight to how isolated 'other' is to us. This is used to determine who to HealgunDoctor.
---A higher isolation means the player is more isolated, and thus a better target for HealgunDoctoring.
---@param bot Bot
---@param other Player
---@return number
function HealgunDoctor.RateIsolation(bot, other)
    return lib.RateIsolation(bot, other)
end

---Find the best target to HealgunDoctor, and return it. This is a pretty expensive function, so don't call it too often.
---@param bot Bot
---@return Player?
---@return number
function HealgunDoctor.FindTarget(bot)
    return lib.FindCloseLowHPTargetSameTeam(bot)
end

function HealgunDoctor.ClearTarget(bot)
    bot.HealgunDoctorTarget = nil
end

---@class Bot
---@field HealgunDoctorTarget Player?

---Sets the target to target, or if target is nil, then it will find a new target. If you want to clear the target, then see HealgunDoctor.ClearTarget.
---@see HealgunDoctor.ClearTarget
---@param bot Bot
---@param target Player?
function HealgunDoctor.SetTarget(bot, target)
    bot.HealgunDoctorTarget = target or HealgunDoctor.FindTarget(bot)
end

function HealgunDoctor.GetTarget(bot)
    return bot.HealgunDoctorTarget
end

---validate if we can attack the bot's target, or the given target if applicable.
---@param bot Bot
---@param target? Player
---@return boolean
function HealgunDoctor.ValidateTarget(bot, target)
    local target = target or HealgunDoctor.GetTarget(bot)
    local valid = target and IsValid(target) and lib.IsPlayerAlive(target)
    -- print("HealgunDoctor.ValidateTarget", valid)
    return valid
end

---Since situations change quickly, we want to make sure we pick the best target for the situation when we can.
---@param bot Bot
function HealgunDoctor.CheckForBetterTarget(bot)
    local alternative = HealgunDoctor.FindTarget(bot)

    if not alternative then return end
    if not HealgunDoctor.ValidateTarget(bot, alternative) then return end


    HealgunDoctor.SetTarget(bot, alternative)
end

---Should we start HealgunDoctoring? This is only useful for when we don't already have a target. To make the behavior more varied.
---@param bot Bot
---@return boolean
function HealgunDoctor.ShouldStartHealgunDoctoring(bot)
    local chance = math.random(0, 100) <= 50
    return TTTBots.Match.IsRoundActive() and chance
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function HealgunDoctor.Validate(bot)
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then return false end          -- Do not HealgunDoctor if we're killing someone already.
    local inv = bot:BotInventory()
    if not (inv and inv:GetStandardMedigun()) then return false end -- Do not HealgunDoctor if we don't have a jackal gun.
    return HealgunDoctor.ValidateTarget(bot) or HealgunDoctor.ShouldStartHealgunDoctoring(bot)
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function HealgunDoctor.OnStart(bot)
    -- print("HealgunDoctor.OnStart")
    if not HealgunDoctor.ValidateTarget(bot) then
        HealgunDoctor.SetTarget(bot)
    end

    return STATUS.RUNNING
end
--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function HealgunDoctor.OnRunning(bot)
    if not HealgunDoctor.ValidateTarget(bot) then return STATUS.FAILURE end
    local target = HealgunDoctor.GetTarget(bot)
    -- print("HealgunDoctor.OnRunning", target)
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()

    if not (math.random(1, TTTBots.Tickrate * 2) == 1 and bot:Visible(target)) then
        HealgunDoctor.CheckForBetterTarget(bot)
        if HealgunDoctor.GetTarget(bot) ~= target then return STATUS.RUNNING end
    end

    -- Check if the bot is still alive
    if not bot:Alive() then
        return STATUS.FAILURE
    end

    local isClose = bot:Visible(target) and bot:GetPos():Distance(targetPos) <= 1000
    local loco = bot:BotLocomotor()
    local inv = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end
    local weapon = bot:GetActiveWeapon()
    loco:SetGoal(targetPos)
    if not isClose then return STATUS.RUNNING end
    loco:LookAt(targetEyes)
    loco:SetGoal()
    inv:PauseAutoSwitch()
    local equipped = inv:EquipStandardMedigun()
    if not equipped then return STATUS.RUNNING end
    local bodyPos = TTTBots.Behaviors.AttackTarget.GetTargetBodyPos(target)
    loco:LookAt(bodyPos)
    local eyeTrace = bot:GetEyeTrace()
    if eyeTrace and eyeTrace.Entity == target then
        loco:StartAttack()
    end

    -- Check if the target's HP is below 100
    if target:Health() < 100 then
        return STATUS.RUNNING
    else
        return STATUS.SUCCESS
    end
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function HealgunDoctor.OnSuccess(bot)
    -- print("HealgunDoctor.OnSuccess")
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function HealgunDoctor.OnFailure(bot)
    -- print("HealgunDoctor.OnFailure")
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function HealgunDoctor.OnEnd(bot)
    -- print("HealgunDoctor.OnEnd")
    HealgunDoctor.ClearTarget(bot)
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
