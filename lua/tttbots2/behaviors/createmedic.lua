

---@class BMedic
TTTBots.Behaviors.CreateMedic = {}

local lib = TTTBots.Lib

---@class BMedic
local CreateMedic = TTTBots.Behaviors.CreateMedic
CreateMedic.Name = "Medic"
CreateMedic.Description = "Medic a player (or random player) and ultimately kill them."
CreateMedic.Interruptible = true


local STATUS = TTTBots.STATUS

---Give a weight to how isolated 'other' is to us. This is used to determine who to Medic.
---A higher isolation means the player is more isolated, and thus a better target for Medicing.
---@param bot Bot
---@param other Player
---@return number
function CreateMedic.RateIsolation(bot, other)
    return lib.RateIsolation(bot, other)
end

---Find the best target to Medic, and return it. This is a pretty expensive function, so don't call it too often.
---@param bot Bot
---@return Player?
---@return number
function CreateMedic.FindTarget(bot)
    return lib.FindCloseTarget(bot, nil, false, false, true, true)
end

function CreateMedic.ClearTarget(bot)
    bot.MedicTarget = nil
end

---@class Bot
---@field MedicTarget Player?

---Sets the target to target, or if target is nil, then it will find a new target. If you want to clear the target, then see Medic.ClearTarget.
---@see Medic.ClearTarget
---@param bot Bot
---@param target Player?
function CreateMedic.SetTarget(bot, target)
    bot.MedicTarget = target or CreateMedic.FindTarget(bot)
end

function CreateMedic.GetTarget(bot)
    return bot.MedicTarget
end

---validate if we can attack the bot's target, or the given target if applicable.
---@param bot Bot
---@param target? Player
---@return boolean
function CreateMedic.ValidateTarget(bot, target)
    local target = target or CreateMedic.GetTarget(bot)
    local valid = target and IsValid(target) and lib.IsPlayerAlive(target)
    -- print("CreateMedic.ValidateTarget", valid)
    return valid
end

---Since situations change quickly, we want to make sure we pick the best target for the situation when we can.
---@param bot Bot
function CreateMedic.CheckForBetterTarget(bot)
    local alternative = CreateMedic.FindTarget(bot)

    if not alternative then return end
    if not CreateMedic.ValidateTarget(bot, alternative) then return end


    CreateMedic.SetTarget(bot, alternative)
end

---Should we start Medicing? This is only useful for when we don't already have a target. To make the behavior more varied.
---@param bot Bot
---@return boolean
function CreateMedic.ShouldStartMedicing(bot)
    local chance = math.random(0, 100) <= 5
    return TTTBots.Match.IsRoundActive() and chance
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function CreateMedic.Validate(bot)
    if not TTTBots.Lib.IsTTT2() then return false end -- This is TTT2-specific.
    if not TTTBots.Match.IsRoundActive() then return false end
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then CreateMedic.SetTarget(bot, bot.attackTarget) end          -- Do not Medic if we're killing someone already.
    local inv = bot:BotInventory()
    if not (inv and CreateMedic.HasMedicGun(bot)) then return false end -- Do not Medic if we don't have a jackal gun.
    return CreateMedic.ValidateTarget(bot) or CreateMedic.ShouldStartMedicing(bot)
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateMedic.OnStart(bot)
    if not CreateMedic.ValidateTarget(bot) then
        CreateMedic.SetTarget(bot)
    end
    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateMedic.OnRunning(bot)
    -- print("CreateMedic.OnRunning")
    if not CreateMedic.ValidateTarget(bot) then return STATUS.FAILURE end
    local target = CreateMedic.GetTarget(bot)
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()

    if not (math.random(1, TTTBots.Tickrate * 2) == 1 and bot:Visible(target)) then
        CreateMedic.CheckForBetterTarget(bot)
        if CreateMedic.GetTarget(bot) ~= target then return STATUS.RUNNING end
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
    medicgun = CreateMedic.GetMedicGun(bot)
    local equipped = bot:SetActiveWeapon(medicgun)
    -- if not equipped then return STATUS.RUNNING end
    local bodyPos = TTTBots.Behaviors.AttackTarget.GetTargetBodyPos(target)
    loco:LookAt(bodyPos)
    local eyeTrace = bot:GetEyeTrace()
    if eyeTrace and eyeTrace.Entity == target then
        -- print("Medic.StartAttack")
        loco:StartAttack()
    end
    return STATUS.RUNNING
end

--- Called from externally named HandleRequest(bot, target) which gives a Medic gun if the bot doesn't have one already and sets a target (if provided).
---@param bot Bot
---@param target Player?
function CreateMedic.HandleRequest(bot, target)
    local inv = bot:BotInventory()
    if not (inv and CreateMedic.HasMedicGun(bot)) then
        bot:Give("weapon_ttt2_medic_deagle")
    end
    CreateMedic.SetTarget(bot, target)
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function CreateMedic.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function CreateMedic.OnFailure(bot)
end

--- Called to check if the bot has the weapon_ttt2_medic_deagle, returns true if the bot has the weapon.
---@param bot Bot
---@return boolean
function CreateMedic.HasMedicGun(bot)
    -- if not IsValid(bot) then return false end
    if bot:HasWeapon("weapon_ttt2_medic_deagle") then return true end
end

--- Called to equip the weapon_ttt2_medic_deagle, returns true if the bot has the weapon.
---@param bot Bot
---@return boolean
function CreateMedic.GetMedicGun(bot)
    -- if not IsValid(bot) then return false end
    local wep = bot:GetWeapon("weapon_ttt2_medic_deagle")
    if IsValid(wep) then return wep end
    return wep
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function CreateMedic.OnEnd(bot)
    CreateMedic.ClearTarget(bot)
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
