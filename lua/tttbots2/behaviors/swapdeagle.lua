

---@class BSwapDeagle
TTTBots.Behaviors.SwapDeagle = {}

local lib = TTTBots.Lib

---@class BSwapDeagle
local SwapDeagle = TTTBots.Behaviors.SwapDeagle
SwapDeagle.Name = "SwapDeagle"
SwapDeagle.Description = "SwapDeagle a player (or random player) and ultimately kill them."
SwapDeagle.Interruptible = true


local STATUS = TTTBots.STATUS

---Give a weight to how isolated 'other' is to us. This is used to determine who to SwapDeagle.
---A higher isolation means the player is more isolated, and thus a better target for SwapDeagleing.
---@param bot Bot
---@param other Player
---@return number
function SwapDeagle.RateIsolation(bot, other)
    return lib.RateIsolation(bot, other)
end

---Find the best target to SwapDeagle, and return it. This is a pretty expensive function, so don't call it too often.
---@param bot Bot
---@return Player?
---@return number
function SwapDeagle.FindTarget(bot)
    return lib.FindCloseTarget(bot, nil, false, false, true, false)
end

function SwapDeagle.ClearTarget(bot)
    bot.SwapDeagleTarget = nil
end

---@class Bot
---@field SwapDeagleTarget Player?

---Sets the target to target, or if target is nil, then it will find a new target. If you want to clear the target, then see SwapDeagle.ClearTarget.
---@see SwapDeagle.ClearTarget
---@param bot Bot
---@param target Player?
function SwapDeagle.SetTarget(bot, target)
    bot.SwapDeagleTarget = target or SwapDeagle.FindTarget(bot)
end

function SwapDeagle.GetTarget(bot)
    return bot.SwapDeagleTarget
end

---validate if we can attack the bot's target, or the given target if applicable.
---@param bot Bot
---@param target? Player
---@return boolean
function SwapDeagle.ValidateTarget(bot, target)
    local target = target or SwapDeagle.GetTarget(bot)
    local valid = target and IsValid(target) and lib.IsPlayerAlive(target)
    -- print("SwapDeagle.ValidateTarget", valid)
    return valid
end

---Since situations change quickly, we want to make sure we pick the best target for the situation when we can.
---@param bot Bot
function SwapDeagle.CheckForBetterTarget(bot)
    local alternative = SwapDeagle.FindTarget(bot)

    if not alternative then return end
    if not SwapDeagle.ValidateTarget(bot, alternative) then return end


    SwapDeagle.SetTarget(bot, alternative)
end

---Should we start SwapDeagleing? This is only useful for when we don't already have a target. To make the behavior more varied.
---@param bot Bot
---@return boolean
function SwapDeagle.ShouldStartSwapDeagleing(bot)
    local chance = math.random(0, 100) <= 2
    return TTTBots.Match.IsRoundActive() and chance
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function SwapDeagle.Validate(bot)
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then return false end          -- Do not SwapDeagle if we're killing someone already.
    local inv = bot:BotInventory()
    if not (inv and inv:GetSwapDeagleGun()) then return false end -- Do not SwapDeagle if we don't have a jackal gun.
    return SwapDeagle.ValidateTarget(bot) or SwapDeagle.ShouldStartSwapDeagleing(bot)
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function SwapDeagle.OnStart(bot)
    -- print("SwapDeagle.OnStart")
    if not SwapDeagle.ValidateTarget(bot) then
        SwapDeagle.SetTarget(bot)
    end

    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function SwapDeagle.OnRunning(bot)
    -- print("SwapDeagle.OnRunning")
    if not SwapDeagle.ValidateTarget(bot) then return STATUS.FAILURE end
    local target = SwapDeagle.GetTarget(bot)
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()

    if not (math.random(1, TTTBots.Tickrate * 2) == 1 and bot:Visible(target)) then
        SwapDeagle.CheckForBetterTarget(bot)
        if SwapDeagle.GetTarget(bot) ~= target then return STATUS.RUNNING end
    end

    -- Check if the bot is still alive
    if not bot:Alive() then
        return STATUS.FAILURE
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
    local equipped = inv:EquipSwapDeagleGun()
    if not equipped then return STATUS.RUNNING end
    local weapon = bot:GetActiveWeapon()
    if weapon and weapon:Clip1() and weapon:Clip1() == 0 then
        return STATUS.FAILURE
    end
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
function SwapDeagle.OnSuccess(bot)
    -- print("SwapDeagle.OnSuccess")
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function SwapDeagle.OnFailure(bot)
    -- print("SwapDeagle.OnFailure")
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function SwapDeagle.OnEnd(bot)
    -- print("SwapDeagle.OnEnd")
    SwapDeagle.ClearTarget(bot)
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
