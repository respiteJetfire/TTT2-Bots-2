

---@class BHealgun
TTTBots.Behaviors.Healgun = {}

local lib = TTTBots.Lib

---@class BHealgun
local Healgun = TTTBots.Behaviors.Healgun
Healgun.Name = "Healgun"
Healgun.Description = "Healgun a player (or random player) restore their HP to Max Health."
Healgun.Interruptible = true


local STATUS = TTTBots.STATUS

---Find the best target to Healgun, and return it. This is a pretty expensive function, so don't call it too often.
---@param bot Bot
---@return Player?
---@return number
function Healgun.FindTarget(bot)
    --- if bot team == NONE then just FindCloseLowHPTarget
    if bot:GetTeam() == TEAM_NONE then
        -- print("Healgun.FindTarget: ", bot, "TEAM_NONE")
        target = TTTBots.Lib.FindCloseLowHPTarget(bot, false, 1000, 500)
        -- print("Healgun.FindTarget: ", bot, "TEAM_NONE", target)
        return target
    else
        return TTTBots.Lib.FindCloseLowHPTarget(bot, true, 600, 300)
    end
end

function Healgun.ClearTarget(bot)
    bot.HealgunTarget = nil
end

---@class Bot
---@field HealgunTarget Player?

---Sets the target to target, or if target is nil, then it will find a new target. If you want to clear the target, then see Healgun.ClearTarget.
---@see Healgun.ClearTarget
---@param bot Bot
---@param target Player?
function Healgun.SetTarget(bot, target)
    bot.HealgunTarget = target or Healgun.FindTarget(bot)
    -- print("Healgun.SetTarget", bot.HealgunTarget)
end

function Healgun.GetTarget(bot)
    return bot.HealgunTarget
end

---validate if we can attack the bot's target, or the given target if applicable.
---@param bot Bot
---@param target? Player
---@return boolean
function Healgun.ValidateTarget(bot, target)
    local target = target or Healgun.GetTarget(bot)
    local valid = target and IsValid(target) and lib.IsPlayerAlive(target)
    -- print("Healgun.ValidateTarget", valid)
    return valid
end

---Since situations change quickly, we want to make sure we pick the best target for the situation when we can.
---@param bot Bot
function Healgun.CheckForBetterTarget(bot)
    local alternative = Healgun.FindTarget(bot)

    if not alternative then return end
    if not Healgun.ValidateTarget(bot, alternative) then return end


    Healgun.SetTarget(bot, alternative)
end

---Should we start Healguning? This is only useful for when we don't already have a target. To make the behavior more varied.
---@param bot Bot
---@return boolean
function Healgun.ShouldStartHealguning(bot)
    local chance = true
    return TTTBots.Match.IsRoundActive() and chance
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function Healgun.Validate(bot)
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then return false end          -- Do not Healgun if we're killing someone already.
    local inv = bot:BotInventory()
    if not (inv and inv:GetMedicMedigun()) then return false end -- Do not Healgun if we don't have a jackal gun.
    if not Healgun.ShouldStartHealguning(bot) then return false end
    return Healgun.ValidateTarget(bot) or Healgun.SetTarget(bot)
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function Healgun.OnStart(bot)
    -- print("Healgun.OnStart")
    if not Healgun.ValidateTarget(bot) then
        Healgun.SetTarget(bot)
    end
    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function Healgun.OnRunning(bot)
    -- print("Healgun.OnRunning")
    if not Healgun.ValidateTarget(bot) then return STATUS.FAILURE end
    local target = Healgun.GetTarget(bot)
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()

    if not (math.random(1, TTTBots.Tickrate * 2) == 1 and bot:Visible(target)) then
        Healgun.CheckForBetterTarget(bot)
        if Healgun.GetTarget(bot) ~= target then return STATUS.RUNNING end
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
    local equipped = inv:EquipMedigun()
    -- if not equipped then return STATUS.RUNNING end
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

--- Called in the sv_chatter function when a bot is requested to healgun a player.
---@param bot Bot
---@param target Player
function Healgun.HandleRequest(bot, target)
    local response = true
    if not IsValid(target) then response = false end
    local inv = bot:BotInventory()
    if not (inv and inv:GetMedicMedigun()) then response = false end
    --- if the target is not less than max HP, then we don't need to healgun them.
    if target:Health() >= target:GetMaxHealth() then response = false end
    --- validate target
    if not Healgun.ValidateTarget(bot, target) then response = false end
    if response then
        local chatter = bot:BotChatter()
        local teamOnly = (bot:GetTeam() == target:GetTeam() and bot:GetTeam() ~= TEAM_INNOCENT) or false
        chatter:On("HealAccepted", { player = target:Nick() }, teamOnly, math.random(1, 4))
        Healgun.SetTarget(bot, target)
    else
        local chatter = bot:BotChatter()
        local teamOnly = (bot:GetTeam() == target:GetTeam() and bot:GetTeam() ~= TEAM_INNOCENT) or false
        chatter:On("HealRefused", { player = target:Nick() }, teamOnly, math.random(1, 4))
    end
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function Healgun.OnSuccess(bot)
    -- print("Healgun.OnSuccess")
    Healgun.ClearTarget(bot)
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

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function Healgun.OnFailure(bot)
    -- print("Healgun.OnFailure")
    Healgun.ClearTarget(bot)
    bot:SetAttackTarget(nil)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function Healgun.OnEnd(bot)
    -- print("Healgun.OnEnd")
end
