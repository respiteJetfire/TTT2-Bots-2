

---@class BCursed
TTTBots.Behaviors.CreateCursed = {}

local lib = TTTBots.Lib

---@class BCursed
local CreateCursed = TTTBots.Behaviors.CreateCursed
CreateCursed.Name = "Cursed"
CreateCursed.Description = "Cursed a player (or random player) and ultimately kill them."
CreateCursed.Interruptible = false


local STATUS = TTTBots.STATUS

---Give a weight to how isolated 'other' is to us. This is used to determine who to Cursed.
---A higher isolation means the player is more isolated, and thus a better target for Curseding.
---@param bot Bot
---@param other Player
---@return number
function CreateCursed.RateIsolation(bot, other)
    return lib.RateIsolation(bot, other)
end

---Find the best target to Cursed, and return it. This is a pretty expensive function, so don't call it too often.
---@param bot Bot
---@return Player?
---@return number
function CreateCursed.FindTarget(bot)
    return lib.FindCloseTarget(bot, nil, false, false, true, true)
end

function CreateCursed.ClearTarget(bot)
    bot.CursedTarget = nil
end

---@class Bot
---@field CursedTarget Player?

---Sets the target to target, or if target is nil, then it will find a new target. If you want to clear the target, then see Cursed.ClearTarget.
---@see Cursed.ClearTarget
---@param bot Bot
---@param target Player?
function CreateCursed.SetTarget(bot, target)
    local newTarget = target or CreateCursed.FindTarget(bot)
    if newTarget then
        bot.CursedTarget = newTarget
    else
        bot.CursedTarget = nil
    end
end

function CreateCursed.GetTarget(bot)
    return bot.CursedTarget
end

---validate if we can attack the bot's target, or the given target if applicable.
---@param bot Bot
---@param target? Player
---@return boolean
function CreateCursed.ValidateTarget(bot, target)
    local target = target or CreateCursed.GetTarget(bot)
    local valid = target and IsValid(target) and lib.IsPlayerAlive(target)
    -- print("CreateCursed.ValidateTarget", valid)
    return valid
end

---Since situations change quickly, we want to make sure we pick the best target for the situation when we can.
---@param bot Bot
function CreateCursed.CheckForBetterTarget(bot)
    local alternative = CreateCursed.FindTarget(bot)

    if not alternative then return end
    if not CreateCursed.ValidateTarget(bot, alternative) then return end


    CreateCursed.SetTarget(bot, alternative)
end

---Should we start Curseding? This is only useful for when we don't already have a target. To make the behavior more varied.
---@param bot Bot
---@return boolean
function CreateCursed.ShouldStartCurseding(bot)
    local chance = math.random(0, 100) <= 5
    return TTTBots.Match.IsRoundActive() and chance
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function CreateCursed.Validate(bot)
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then CreateCursed.SetTarget(bot.attackTarget) end          -- Do not Cursed if we're killing someone already.
    local inv = bot:BotInventory()
    if not (inv and inv:GetCursedGun()) then return false end -- Do not Cursed if we don't have a jackal gun.
    return CreateCursed.ValidateTarget(bot) or CreateCursed.ShouldStartCurseding(bot)
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateCursed.OnStart(bot)
    if not CreateCursed.ValidateTarget(bot) then
        CreateCursed.SetTarget(bot)
    end

    local chatter = bot:BotChatter()
    chatter:On("CreatingCursed", {player = bot.CursedTarget:Nick()}, true)

    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateCursed.OnRunning(bot)
    if not CreateCursed.ValidateTarget(bot) then return STATUS.FAILURE end
    local target = CreateCursed.GetTarget(bot)
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()

    if not (math.random(1, TTTBots.Tickrate * 2) == 1 and bot:Visible(target)) then
        CreateCursed.CheckForBetterTarget(bot)
        if CreateCursed.GetTarget(bot) ~= target then return STATUS.RUNNING end
    end

    local isClose = bot:Visible(target) and bot:GetPos():Distance(targetPos) >= 300 and bot:GetPos():Distance(targetPos) <= 1000
    local loco = bot:BotLocomotor()
    local inv = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end
    loco:SetGoal(targetPos)
    if not isClose then return STATUS.RUNNING end
    loco:LookAt(targetEyes)
    loco:SetGoal()
    inv:PauseAutoSwitch()
    local equipped = inv:EquipCursedGun()
    -- if not equipped then return STATUS.RUNNING end
    local bodyPos = TTTBots.Behaviors.AttackTarget.GetTargetBodyPos(target)
    loco:LookAt(bodyPos)
    local eyeTrace = bot:GetEyeTrace()
    if eyeTrace and eyeTrace.Entity == target then
        -- print("Cursed.StartAttack")
        loco:StartAttack()
    end
    return STATUS.RUNNING
end

--- Called from externally named HandleRequest(bot, target) which gives a Cursed gun if the bot doesn't have one already and sets a target (if provided).
---@param bot Bot
---@param target Player?
function CreateCursed.HandleRequest(bot, target)
    local inv = bot:BotInventory()
    if not inv then return end
    if not inv:GetCursedGun() then
        bot:Give("weapon_ttt2_cursed_deagle")
    end
    CreateCursed.SetTarget(bot, target)
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function CreateCursed.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function CreateCursed.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function CreateCursed.OnEnd(bot)
    CreateCursed.ClearTarget(bot)
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
