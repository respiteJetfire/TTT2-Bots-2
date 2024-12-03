

---@class BHealgunMedic
TTTBots.Behaviors.HealgunMedic = {}

local lib = TTTBots.Lib

---@class BHealgunMedic
local HealgunMedic = TTTBots.Behaviors.HealgunMedic
HealgunMedic.Name = "HealgunMedic"
HealgunMedic.Description = "HealgunMedic a player (or random player) restore their HP to 100."
HealgunMedic.Interruptible = true


local STATUS = TTTBots.STATUS

---Give a weight to how isolated 'other' is to us. This is used to determine who to HealgunMedic.
---A higher isolation means the player is more isolated, and thus a better target for HealgunMedicing.
---@param bot Bot
---@param other Player
---@return number
function HealgunMedic.RateIsolation(bot, other)
    return lib.RateIsolation(bot, other)
end

---Find the best target to HealgunMedic, and return it. This is a pretty expensive function, so don't call it too often.
---@param bot Bot
---@return Player?
---@return number
function HealgunMedic.FindTarget(bot)
    return lib.FindCloseLowHPTarget(bot)
end

function HealgunMedic.ClearTarget(bot)
    bot.HealgunMedicTarget = nil
end

---@class Bot
---@field HealgunMedicTarget Player?

---Sets the target to target, or if target is nil, then it will find a new target. If you want to clear the target, then see HealgunMedic.ClearTarget.
---@see HealgunMedic.ClearTarget
---@param bot Bot
---@param target Player?
function HealgunMedic.SetTarget(bot, target)
    bot.HealgunMedicTarget = target or HealgunMedic.FindTarget(bot)
end

function HealgunMedic.GetTarget(bot)
    return bot.HealgunMedicTarget
end

---validate if we can attack the bot's target, or the given target if applicable.
---@param bot Bot
---@param target? Player
---@return boolean
function HealgunMedic.ValidateTarget(bot, target)
    local target = target or HealgunMedic.GetTarget(bot)
    local valid = target and IsValid(target) and lib.IsPlayerAlive(target)
    -- print("HealgunMedic.ValidateTarget", valid)
    return valid
end

---Since situations change quickly, we want to make sure we pick the best target for the situation when we can.
---@param bot Bot
function HealgunMedic.CheckForBetterTarget(bot)
    local alternative = HealgunMedic.FindTarget(bot)

    if not alternative then return end
    if not HealgunMedic.ValidateTarget(bot, alternative) then return end


    HealgunMedic.SetTarget(bot, alternative)
end

---Should we start HealgunMedicing? This is only useful for when we don't already have a target. To make the behavior more varied.
---@param bot Bot
---@return boolean
function HealgunMedic.ShouldStartHealgunMedicing(bot)
    local chance = true
    return TTTBots.Match.IsRoundActive() and chance
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function HealgunMedic.Validate(bot)
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then return false end          -- Do not HealgunMedic if we're killing someone already.
    local inv = bot:BotInventory()
    if not (inv and inv:GetMedicMedigun()) then return false end -- Do not HealgunMedic if we don't have a jackal gun.
    if not HealgunMedic.ShouldStartHealgunMedicing(bot) then return false end
    return HealgunMedic.ValidateTarget(bot)
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function HealgunMedic.OnStart(bot)
    print("HealgunMedic.OnStart")
    if not HealgunMedic.ValidateTarget(bot) then
        HealgunMedic.SetTarget(bot)
    end

    return STATUS.RUNNING
end
--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function HealgunMedic.OnRunning(bot)
    -- print("HealgunMedic.OnRunning")
    if not HealgunMedic.ValidateTarget(bot) then return STATUS.FAILURE end
    local target = HealgunMedic.GetTarget(bot)
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()

    if not (math.random(1, TTTBots.Tickrate * 2) == 1 and bot:Visible(target)) then
        HealgunMedic.CheckForBetterTarget(bot)
        if HealgunMedic.GetTarget(bot) ~= target then return STATUS.RUNNING end
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
    local equipped = inv:EquipMedicMedigun()
    if not equipped then return STATUS.RUNNING end
    local bodyPos = TTTBots.Behaviors.AttackTarget.GetTargetBodyPos(target)
    loco:LookAt(bodyPos)
    local eyeTrace = bot:GetEyeTrace()
    if eyeTrace and eyeTrace.Entity == target then
        loco:StartAttack()
    end

    -- Check if the target's HP is below their max health
    if target:Health() < target:GetMaxHealth() then
        return STATUS.RUNNING
    else
        return STATUS.SUCCESS
    end
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function HealgunMedic.OnSuccess(bot)
    -- print("HealgunMedic.OnSuccess")
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function HealgunMedic.OnFailure(bot)
    -- print("HealgunMedic.OnFailure")
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function HealgunMedic.OnEnd(bot)
    print("HealgunMedic.OnEnd")
    HealgunMedic.ClearTarget(bot)
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
