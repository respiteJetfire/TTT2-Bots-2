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
    --- UNLESS it's a high-priority target (self-defense, KOS'd enemy, etc.)
    if bot.attackTarget then
        local pri = bot.attackTargetPriority or 0
        if pri >= (TTTBots.Morality and TTTBots.Morality.PRIORITY and TTTBots.Morality.PRIORITY.SUSPICION_THRESHOLD or 2) then
            -- High-priority target — refuse to wait
            return STATUS.FAILURE
        end
        bot:SetAttackTarget(nil, "BEHAVIOR_END")
    end
    --- if the bot is the same team as a non innocent we will use the teamOnly parameter to accept the request
    local teamOnly = (bot:GetTeam() == bot.waitRequester:GetTeam() and bot:GetTeam() ~= TEAM_INNOCENT) or false
    if chatter and chatter.On then chatter:On("WaitStart", { target = bot.waitRequester:Nick() }, teamOnly, math.random(1, 4)) end
    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function BehaviorWait.OnRunning(bot)
    -- Abort waiting if the bot has an active attack target (self-defense)
    if bot.attackTarget ~= nil then
        return STATUS.FAILURE
    end
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
    if chatter and chatter.On then
        chatter:On("WaitEnd", { target = bot.waitRequester:Nick() }, false, math.random(1, 4))
    end
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

    -- Reject wait from KOS'd players — a KOS'd traitor should not be able
    -- to freeze everyone in place while they escape or attack.
    local kosList = TTTBots.Match.KOSList
    if kosList and kosList[player] and not table.IsEmpty(kosList[player]) then
        print(bot:Nick() .. " refused wait from KOS'd player " .. player:Nick())
        if chatter and chatter.On then chatter:On("WaitRefuse", { target = player:Nick() }, teamOnly, math.random(1, 4)) end
        return
    end

    -- Reject wait from highly suspicious players
    if not roleDisablesSuspicion and playerSus >= (Morality.Thresholds and Morality.Thresholds.KOS or 7) then
        print(bot:Nick() .. " refused wait from suspicious player " .. player:Nick())
        if chatter and chatter.On then chatter:On("WaitRefuse", { target = player:Nick() }, teamOnly, math.random(1, 4)) end
        return
    end

    --- calculate chance of acceptance and time based on player's suspicion level
    local chance = 0.5
    local time = 5
    if playerIsPolice then
        chance = 1
        time = 10
    elseif not roleDisablesSuspicion then
        local sus = math.Clamp(playerSus, -10, 10)
        chance = math.Clamp((10 - sus) / 20, 0, 1)
        time = math.Clamp((10 - sus) / 20 * 15 + 5, 5, 15)
    end
    -- FIX: operator precedence — 'not' binds tighter than '=='
    if teamOnly and bot:GetTeam() ~= player:GetTeam() then
        --ignore
        print(bot:Nick() .. " refused to wait for " .. player:Nick())
        return
    end
    -- FIX: math.random() returns 0-1 float, compare directly against chance (also 0-1)
    if math.random() > chance then
        print(bot:Nick() .. " refused to wait for " .. player:Nick())
        if chatter and chatter.On then chatter:On("WaitRefuse", { target = player:Nick() }, teamOnly, math.random(1, 4)) end
        return
    end
    bot.waitEndTime = CurTime() + time
    bot.wait = true
    bot.waitRequester = player
    print(bot:Nick() .. " is now waiting as requested by " .. player:Nick())
end