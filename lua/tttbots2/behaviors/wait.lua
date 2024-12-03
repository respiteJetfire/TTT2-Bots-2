--- This file is a base behavior meta file. It is not used in code, and is merely present for Intellisense and prototyping.
---@meta

---@class BWait : BBase
TTTBots.Behaviors.Wait = {}

local lib = TTTBots.Lib

---@class BWait : BBase
local BehaviorWait = TTTBots.Behaviors.Wait
BehaviorWait.Name = "Wait"
BehaviorWait.Description = "Wait for a random duration between 5 and 15 seconds"
BehaviorWait.Interruptible = false


local STATUS = TTTBots.STATUS

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function BehaviorWait.Validate(bot)
    -- print(bot:Nick() .. " is validating waiting.")
    -- print("Is bot waiting? " .. tostring(bot.wait))
    return bot.wait and bot.waitEndTime and CurTime() < bot.waitEndTime
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function BehaviorWait.OnStart(bot)
    
    print(bot:Nick() .. " is now waiting.")
    local chatter = bot:BotChatter()
    --- if the bot is attacking a target while waiting, stop attacking the target
    if bot.attackTarget then
        bot:SetAttackTarget(nil)
    end
    --- if the bot is the same team as a non innocent we will use the teamOnly parameter to accept the request
    local teamOnly = (bot:GetTeam() == bot.waitRequester:GetTeam() and bot:GetTeam() ~= TEAM_INNOCENT) or false
    chatter:On("WaitStart", { target = bot.waitRequester:Nick() }, teamOnly, math.random(1, 4))
    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function BehaviorWait.OnRunning(bot)
    if CurTime() >= bot.waitEndTime then
        print(bot:Nick() .. " has finished waiting.")
        return STATUS.SUCCESS
    end
    local loco = bot:BotLocomotor()
    loco:SetGoal() -- reset goal to stop moving
    loco:PauseAttackCompat()
    loco:PauseRepel()
    return STATUS.RUNNING
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function BehaviorWait.OnSuccess(bot)
    print(bot:Nick() .. " has finished waiting.")
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function BehaviorWait.OnFailure(bot)
    print(bot:Nick() .. " failed to wait.")
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function BehaviorWait.OnEnd(bot)
    bot.waitEndTime = nil
    bot.wait = false
    local loco = bot:BotLocomotor()
    loco:ResumeAttackCompat()
    loco:SetHalt(false)
    loco:ResumeRepel()
    local chatter = bot:BotChatter()
    chatter:On("WaitEnd", { target = bot.waitRequester:Nick() }, false, math.random(1, 4))
    bot.waitRequester = nil
end

--- Request the bot to wait for a random duration between 5 and 15 seconds
---@param bot Bot
---@param player Player
function BehaviorWait.RequestWait(bot, player, teamOnly)
    local playerIsPolice = TTTBots.Roles.GetRoleFor(player):GetAppearsPolice()
    local roleDisablesSuspicion = not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion()
    local chatter = bot:BotChatter()
    local Morality = bot:BotMorality()
    local playerSus = Morality:GetSuspicion(player) or 0
    --- calculate chance of acceptance and time based on player's suspicion level (0% and 5 seconds at -10, 100% and 20 seconds at 10 but player can exceed both), or a base 50% if not using suspicion 
    --- if the player is a public role, the bot will always accept local targetIsPolice = TTTBots.Roles.GetRoleFor(target):GetAppearsPolice()
    local chance = 0.5
    local time = 5
    if playerIsPolice then
        chance = 1
        time = 10
    elseif not roleDisablesSuspicion then
        local sus = math.Clamp(playerSus, -10, 10)
        chance = math.Clamp((10 - sus) / 20, 0, 1)
        time = math.Clamp((10 - sus) / 20 * 15 + 5, 5, 5)
    end
    if teamOnly and not bot:GetTeam() == player:GetTeam() then
        --ignore
        print(bot:Nick() .. " refused to wait for " .. player:Nick())
        return
    end
    if math.random() > chance * 100 then
        print(bot:Nick() .. " refused to wait for " .. player:Nick())
        chatter:On("WaitRefuse", { target = player:Nick() }, teamOnly, math.random(1, 4))
        return
    end
    bot.waitEndTime = CurTime() + time
    bot.wait = true
    bot.waitRequester = player
    print(bot:Nick() .. " is now waiting as requested by " .. player:Nick())
end