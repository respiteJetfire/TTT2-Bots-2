

---@class BMarker
TTTBots.Behaviors.CreateMarker = {}

local lib = TTTBots.Lib

---@class BMarker
local CreateMarker = TTTBots.Behaviors.CreateMarker
CreateMarker.Name = "Marker"
CreateMarker.Description = "Marker a player (or random player) that is not marked already."
CreateMarker.Interruptible = true


local STATUS = TTTBots.STATUS

---Find the best target to Marker, and return it. This is a pretty expensive function, so don't call it too often.
---@param bot Bot
---@return Player?
---@return number
function CreateMarker.FindTarget(bot)
    local target = lib.FindCloseTarget(bot, nil, false, true, true, true)
    -- print("CreateMarker.FindTarget", target)
    return target
end

function CreateMarker.ClearTarget(bot)
    bot.MarkerTarget = nil
end

---@class Bot
---@field MarkerTarget Player?

---Sets the target to target, or if target is nil, then it will find a new target. If you want to clear the target, then see Marker.ClearTarget.
---@see Marker.ClearTarget
---@param bot Bot
---@param target Player?
function CreateMarker.SetTarget(bot, target)
    bot.MarkerTarget = target or CreateMarker.FindTarget(bot)
end

function CreateMarker.GetTarget(bot)
    return bot.MarkerTarget
end

---validate if we can attack the bot's target, or the given target if applicable.
---@param bot Bot
---@param target? Player
---@return boolean
function CreateMarker.ValidateTarget(bot, target)
    local target = target or CreateMarker.GetTarget(bot)
    local valid = target and IsValid(target) and lib.IsPlayerAlive(target)
    -- print("CreateMarker.ValidateTarget", valid)
    return valid
end

---Since situations change quickly, we want to make sure we pick the best target for the situation when we can.
---@param bot Bot
function CreateMarker.CheckForBetterTarget(bot)
    local alternative = CreateMarker.FindTarget(bot)

    if not alternative then return end
    if not CreateMarker.ValidateTarget(bot, alternative) then return end


    CreateMarker.SetTarget(bot, alternative)
end

---Should we start Markering? This is only useful for when we don't already have a target. To make the behavior more varied.
---@param bot Bot
---@return boolean
function CreateMarker.ShouldStartMarkering(bot)
    local chance = true
    return TTTBots.Match.IsRoundActive() and chance
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function CreateMarker.Validate(bot)
    if not TTTBots.Lib.IsTTT2() then return false end -- This is TTT2-specific.
    if not TTTBots.Match.IsRoundActive() then return false end
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then return false end          -- Do not Marker if we're killing someone already.
    local inv = bot:BotInventory()
    if not (inv and CreateMarker.HasMarkerGun(bot)) then
        -- print("CreateMarker.NoGun")
        return false
    end -- Do not Marker if we don't have a jackal gun.
    -- print("CreateMarker.Validate", true)
    --- add a chance component to prevent bots from markering forever
    local chance = math.random(0, 100) <= 95
    if not chance then return false end
    return CreateMarker.ValidateTarget(bot) or CreateMarker.ShouldStartMarkering(bot)
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateMarker.OnStart(bot)
    if not CreateMarker.ValidateTarget(bot) then
        CreateMarker.SetTarget(bot)
    end

    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CreateMarker.OnRunning(bot)
    -- print("CreateMarker.OnRunning")
    if not CreateMarker.ValidateTarget(bot) then return STATUS.FAILURE end
    local target = CreateMarker.GetTarget(bot)
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()

    if not (math.random(1, TTTBots.Tickrate * 2) == 1 and bot:Visible(target)) then
        CreateMarker.CheckForBetterTarget(bot)
        if CreateMarker.GetTarget(bot) ~= target then return STATUS.RUNNING end
    end

    local isClose = bot:Visible(target) and bot:GetPos():Distance(targetPos) <= 350
    local loco = bot:BotLocomotor()
    local inv = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end
    loco:SetGoal(targetPos)
    if not isClose then return STATUS.RUNNING end
    loco:LookAt(targetEyes)
    loco:SetGoal()
    inv:PauseAutoSwitch()
    markergun = CreateMarker.GetMarkerGun(bot)
    hasMarkerGun = CreateMarker.HasMarkerGun(bot)
    if not hasMarkerGun then return STATUS.FAILURE end
    local equipped = bot:SetActiveWeapon(markergun)
    -- print("Equipped", equipped)
    -- if not equipped then return STATUS.RUNNING end
    local bodyPos = TTTBots.Behaviors.AttackTarget.GetTargetBodyPos(target)
    loco:LookAt(bodyPos)
    local eyeTrace = bot:GetEyeTrace()

    if eyeTrace and eyeTrace.Entity == target and bot:Visible(target) then
        loco:StartAttack()
    end
    return STATUS.RUNNING
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function CreateMarker.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function CreateMarker.OnFailure(bot)
end

--- Called to check if the bot has the 'weapon_ttt2_markergun', returns true if the bot has the weapon.
---@param bot Bot
---@return boolean
function CreateMarker.HasMarkerGun(bot)
    -- if not IsValid(bot) then return false end
    if bot:HasWeapon("weapon_ttt2_markergun") then return true end
end

--- Called to equip the 'weapon_ttt2_markergun', returns true if the bot has the weapon.
---@param bot Bot
---@return boolean
function CreateMarker.GetMarkerGun(bot)
    -- if not IsValid(bot) then return false end
    local wep = bot:GetWeapon("weapon_ttt2_markergun")
    if IsValid(wep) then return wep end
    return wep
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function CreateMarker.OnEnd(bot)
    CreateMarker.ClearTarget(bot)
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
