

---@class BDoctor
TTTBots.Behaviors.CreateDoctor = {}

local lib = TTTBots.Lib

---@class BDoctor
local CreateDoctor = TTTBots.Behaviors.CreateDoctor
CreateDoctor.Name = "Doctor"
CreateDoctor.Description = "Doctor a player (or random player) and ultimately kill them."
CreateDoctor.Interruptible = true


local STATUS = TTTBots.STATUS

---Give a weight to how isolated 'other' is to us. This is used to determine who to Doctor.
---A higher isolation means the player is more isolated, and thus a better target for Doctoring.
---@param bot Bot
---@param other Player
---@return number
function CreateDoctor.RateIsolation(bot, other)
    return lib.RateIsolation(bot, other)
end

---Find the best target to Doctor, and return it. This is a pretty expensive function, so don't call it too often.
---@param bot Bot
---@return Player?
---@return number
function CreateDoctor.FindTarget(bot)
    return lib.FindCloseTarget(bot, nil, false, false, true, false)
end

function CreateDoctor.ClearTarget(bot)
    bot.DoctorTarget = nil
end

---@class Bot
---@field DoctorTarget Player?

---Sets the target to target, or if target is nil, then it will find a new target. If you want to clear the target, then see Doctor.ClearTarget.
---@see Doctor.ClearTarget
---@param bot Bot
---@param target Player?
function CreateDoctor.SetTarget(bot, target)
    bot.DoctorTarget = target or CreateDoctor.FindTarget(bot)
end

function CreateDoctor.GetTarget(bot)
    return bot.DoctorTarget
end

---validate if we can attack the bot's target, or the given target if applicable.
---@param bot Bot
---@param target? Player
---@return boolean
function CreateDoctor.ValidateTarget(bot, target)
    local target = target or CreateDoctor.GetTarget(bot)
    local valid = target and IsValid(target) and lib.IsPlayerAlive(target)
    -- print("CreateDoctor.ValidateTarget", valid)
    return valid
end

---Since situations change quickly, we want to make sure we pick the best target for the situation when we can.
---@param bot Bot
function CreateDoctor.CheckForBetterTarget(bot)
    local alternative = CreateDoctor.FindTarget(bot)

    if not alternative then return end
    if not CreateDoctor.ValidateTarget(bot, alternative) then return end


    CreateDoctor.SetTarget(bot, alternative)
end

---Should we start Doctoring? This is only useful for when we don't already have a target. To make the behavior more varied.
---@param bot Bot
---@return boolean
function CreateDoctor.ShouldStartDoctoring(bot)
    local chance = math.random(0, 100) <= 2
    return TTTBots.Match.IsRoundActive() and chance
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function CreateDoctor.Validate(bot)
    if not TTTBots.Lib.IsTTT2() then return false end -- This is TTT2-specific.
    if not TTTBots.Match.IsRoundActive() then return false end
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then CreateDoctor.SetTarget(bot, bot.attackTarget) end          -- Do not Doctor if we're killing someone already.
    local inv = bot:BotInventory()
    if not (inv and CreateDoctor.HasDoctorGun(bot)) then return false end -- Do not Doctor if we don't have a jackal gun.
    return CreateDoctor.ValidateTarget(bot) or CreateDoctor.ShouldStartDoctoring(bot)
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateDoctor.OnStart(bot)
    if not CreateDoctor.ValidateTarget(bot) then
        CreateDoctor.SetTarget(bot)
    end

    local chatter = bot:BotChatter()
    chatter:On("CreatingDoctor", {player = bot.DoctorTarget:Nick()})

    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateDoctor.OnRunning(bot)
    -- print("CreateDoctor.OnRunning")
    if not CreateDoctor.ValidateTarget(bot) then return STATUS.FAILURE end
    local target = CreateDoctor.GetTarget(bot)
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()

    if not (math.random(1, TTTBots.Tickrate * 2) == 1 and bot:Visible(target)) then
        CreateDoctor.CheckForBetterTarget(bot)
        if CreateDoctor.GetTarget(bot) ~= target then return STATUS.RUNNING end
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
    doctorgun = CreateDoctor.GetDoctorGun(bot)
    hasDoctorGun = CreateDoctor.HasDoctorGun(bot)
    if not hasDoctorGun then return STATUS.FAILURE end
    local equipped = bot:SetActiveWeapon(doctorgun)
    -- if not equipped then return STATUS.RUNNING end
    local bodyPos = TTTBots.Behaviors.AttackTarget.GetTargetBodyPos(target)
    loco:LookAt(bodyPos)
    local eyeTrace = bot:GetEyeTrace()
    if eyeTrace and eyeTrace.Entity == target then
        -- print("Doctoring", target)
        loco:StartAttack()
    end
    return STATUS.RUNNING
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function CreateDoctor.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function CreateDoctor.OnFailure(bot)
end

--- Called to check if the bot has the weapon_ttt2_doctor_deagle, returns true if the bot has the weapon.
---@param bot Bot
---@return boolean
function CreateDoctor.HasDoctorGun(bot)
    -- if not IsValid(bot) then return false end
    if bot:HasWeapon("weapon_ttt2_doctor_deagle") then return true end
end

--- Called to equip the weapon_ttt2_doctor_deagle, returns true if the bot has the weapon.
---@param bot Bot
---@return boolean
function CreateDoctor.GetDoctorGun(bot)
    -- if not IsValid(bot) then return false end
    local wep = bot:GetWeapon("weapon_ttt2_doctor_deagle")
    if IsValid(wep) then return wep end
    return wep
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function CreateDoctor.OnEnd(bot)
    CreateDoctor.ClearTarget(bot)
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
