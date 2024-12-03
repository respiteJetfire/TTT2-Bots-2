

---@class BDefector
TTTBots.Behaviors.CreateDefector = {}

local lib = TTTBots.Lib

---@class BDefector
local CreateDefector = TTTBots.Behaviors.CreateDefector
CreateDefector.Name = "Defector"
CreateDefector.Description = "Defector a player (or random player) and ultimately kill them."
CreateDefector.Interruptible = true


local STATUS = TTTBots.STATUS

---Give a weight to how isolated 'other' is to us. This is used to determine who to Defector.
---A higher isolation means the player is more isolated, and thus a better target for Defectoring.
---@param bot Bot
---@param other Player
---@return number
function CreateDefector.RateIsolation(bot, other)
    return lib.RateIsolation(bot, other)
end

---Find the best target to Defector, and return it. This is a pretty expensive function, so don't call it too often.
---@param bot Bot
---@return Player?
---@return number
function CreateDefector.FindTarget(bot)
    return lib.FindCloseTarget(bot, nil, false, false, true, true)
end

function CreateDefector.ClearTarget(bot)
    bot.DefectorTarget = nil
end

---@class Bot
---@field DefectorTarget Player?

---Sets the target to target, or if target is nil, then it will find a new target. If you want to clear the target, then see Defector.ClearTarget.
---@see Defector.ClearTarget
---@param bot Bot
---@param target Player?
function CreateDefector.SetTarget(bot, target)
    bot.DefectorTarget = target or CreateDefector.FindTarget(bot)
end

function CreateDefector.GetTarget(bot)
    return bot.DefectorTarget
end

---validate if we can attack the bot's target, or the given target if applicable.
---@param bot Bot
---@param target? Player
---@return boolean
function CreateDefector.ValidateTarget(bot, target)
    local target = target or CreateDefector.GetTarget(bot)
    local valid = target and IsValid(target) and lib.IsPlayerAlive(target)
    -- print("CreateDefector.ValidateTarget", valid)
    return valid
end

---Since situations change quickly, we want to make sure we pick the best target for the situation when we can.
---@param bot Bot
function CreateDefector.CheckForBetterTarget(bot)
    local alternative = CreateDefector.FindTarget(bot)

    if not alternative then return end
    if not CreateDefector.ValidateTarget(bot, alternative) then return end


    CreateDefector.SetTarget(bot, alternative)
end

---Should we start Defectoring? This is only useful for when we don't already have a target. To make the behavior more varied.
---@param bot Bot
---@return boolean
function CreateDefector.ShouldStartDefectoring(bot)
    local chance = math.random(0, 100) <= 5
    return TTTBots.Match.IsRoundActive() and chance
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function CreateDefector.Validate(bot)
    if not TTTBots.Lib.IsTTT2() then return false end -- This is TTT2-specific.
    if not TTTBots.Match.IsRoundActive() then return false end
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then CreateDefector.SetTarget(bot, bot.attackTarget) end          -- Do not Defector if we're killing someone already.
    local inv = bot:BotInventory()
    if not (inv and CreateDefector.HasDefectorGun(bot)) then return false end -- Do not Defector if we don't have a jackal gun.
    return CreateDefector.ValidateTarget(bot) or CreateDefector.ShouldStartDefectoring(bot)
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateDefector.OnStart(bot)
    if not CreateDefector.ValidateTarget(bot) then
        CreateDefector.SetTarget(bot)
    end

    local chatter = bot:BotChatter()
    chatter:On("CreatingDefector", {player = bot.DefectorTarget:Nick()}, true)

    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateDefector.OnRunning(bot)
    -- print("CreateDefector.OnRunning")
    if not CreateDefector.ValidateTarget(bot) then return STATUS.FAILURE end
    local target = CreateDefector.GetTarget(bot)
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()

    if not (math.random(1, TTTBots.Tickrate * 2) == 1 and bot:Visible(target)) then
        CreateDefector.CheckForBetterTarget(bot)
        if CreateDefector.GetTarget(bot) ~= target then return STATUS.RUNNING end
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
    defectorgun = CreateDefector.GetDefectorGun(bot)
    local equipped = bot:SetActiveWeapon(defectorgun)
    -- if not equipped then return STATUS.RUNNING end
    local bodyPos = TTTBots.Behaviors.AttackTarget.GetTargetBodyPos(target)
    loco:LookAt(bodyPos)
    local eyeTrace = bot:GetEyeTrace()
    if eyeTrace and eyeTrace.Entity == target then
        -- print("CreateDefector.OnRunning: StartAttack")
        loco:StartAttack()
        target:Give("weapon_ttt_jihad_bomb")
    end
    return STATUS.RUNNING
end

--- Called from externally named HandleRequest(bot, target) which gives a defector gun if the bot doesn't have one already and sets a target (if provided).
---@param bot Bot
---@param target Player
function CreateDefector.HandleRequest(bot, target)
    if not IsValid(bot) then return end
    local inv = bot:BotInventory()
    if not (inv and CreateDefector.HasDefectorGun(bot)) then
        bot:Give("weapon_ttt2_defector_deagle")
    end
    CreateDefector.SetTarget(bot, target)
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function CreateDefector.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function CreateDefector.OnFailure(bot)
end

--- Called to check if the bot has the weapon_ttt2_defector_deagle, returns true if the bot has the weapon.
---@param bot Bot
---@return boolean
function CreateDefector.HasDefectorGun(bot)
    -- if not IsValid(bot) then return false end
    if bot:HasWeapon("weapon_ttt2_defector_deagle") then return true end
end

--- Called to equip the weapon_ttt2_defector_deagle, returns true if the bot has the weapon.
---@param bot Bot
---@return boolean
function CreateDefector.GetDefectorGun(bot)
    -- if not IsValid(bot) then return false end
    local wep = bot:GetWeapon("weapon_ttt2_defector_deagle")
    if IsValid(wep) then return wep end
    return wep
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function CreateDefector.OnEnd(bot)
    CreateDefector.ClearTarget(bot)
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
