

---@class BDeputy
TTTBots.Behaviors.CreateDeputy = {}

local lib = TTTBots.Lib

---@class BDeputy
local CreateDeputy = TTTBots.Behaviors.CreateDeputy
CreateDeputy.Name = "Deputy"
CreateDeputy.Description = "Deputy a player (or random player) and ultimately kill them."
CreateDeputy.Interruptible = true


local STATUS = TTTBots.STATUS

---Give a weight to how isolated 'other' is to us. This is used to determine who to Deputy.
---A higher isolation means the player is more isolated, and thus a better target for Deputying.
---@param bot Bot
---@param other Player
---@return number
function CreateDeputy.RateIsolation(bot, other)
    return lib.RateIsolation(bot, other)
end

---Find the best target to Deputy, and return it. This is a pretty expensive function, so don't call it too often.
---@param bot Bot
---@return Player?
---@return number
function CreateDeputy.FindTarget(bot)
    return lib.FindCloseTarget(bot, nil, false, false, true, false)
end

function CreateDeputy.ClearTarget(bot)
    bot.DeputyTarget = nil
end

---@class Bot
---@field DeputyTarget Player?

---Sets the target to target, or if target is nil, then it will find a new target. If you want to clear the target, then see Deputy.ClearTarget.
---@see Deputy.ClearTarget
---@param bot Bot
---@param target Player?
function CreateDeputy.SetTarget(bot, target)
    bot.DeputyTarget = target or CreateDeputy.FindTarget(bot)
end

function CreateDeputy.GetTarget(bot)
    return bot.DeputyTarget
end

---validate if we can attack the bot's target, or the given target if applicable.
---@param bot Bot
---@param target? Player
---@return boolean
function CreateDeputy.ValidateTarget(bot, target)
    local target = target or CreateDeputy.GetTarget(bot)
    local valid = target and IsValid(target) and lib.IsPlayerAlive(target)
    -- print("CreateDeputy.ValidateTarget", valid)
    return valid
end

---Since situations change quickly, we want to make sure we pick the best target for the situation when we can.
---@param bot Bot
function CreateDeputy.CheckForBetterTarget(bot)
    local alternative = CreateDeputy.FindTarget(bot)

    if not alternative then return end
    if not CreateDeputy.ValidateTarget(bot, alternative) then return end


    CreateDeputy.SetTarget(bot, alternative)
end

---Should we start Deputying? This is only useful for when we don't already have a target. To make the behavior more varied.
---@param bot Bot
---@return boolean
function CreateDeputy.ShouldStartDeputying(bot)
    local chance = math.random(0, 100) <= 2
    return TTTBots.Match.IsRoundActive() and chance
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function CreateDeputy.Validate(bot)
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then CreateDeputy.SetTarget(bot, bot.attackTarget) end          -- Do not Deputy if we're killing someone already.
    local inv = bot:BotInventory()
    if not (inv and inv:GetDeputyGun()) then return false end -- Do not Deputy if we don't have a jackal gun.
    return CreateDeputy.ValidateTarget(bot) or CreateDeputy.ShouldStartDeputying(bot)
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateDeputy.OnStart(bot)
    if not CreateDeputy.ValidateTarget(bot) then
        CreateDeputy.SetTarget(bot)
    end

    local chatter = bot:BotChatter()
    chatter:On("CreatingDeputy", {player = bot.DeputyTarget:Nick()})

    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateDeputy.OnRunning(bot)
    if not CreateDeputy.ValidateTarget(bot) then return STATUS.FAILURE end
    local target = CreateDeputy.GetTarget(bot)
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()

    if not (math.random(1, TTTBots.Tickrate * 2) == 1 and bot:Visible(target)) then
        CreateDeputy.CheckForBetterTarget(bot)
        if CreateDeputy.GetTarget(bot) ~= target then return STATUS.RUNNING end
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
    local equipped = inv:EquipDeputyGun()
    if not equipped then return STATUS.FAILURE end
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
function CreateDeputy.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function CreateDeputy.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function CreateDeputy.OnEnd(bot)
    CreateDeputy.ClearTarget(bot)
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
