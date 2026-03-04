--- This file is a base behavior meta file. It is not used in code, and is merely present for Intellisense and prototyping.
---@meta



---@class BBase
TTTBots.Behaviors.Base = {}

local lib = TTTBots.Lib

---@class BBase
local BehaviorBase = TTTBots.Behaviors.Base
BehaviorBase.Name = "Base"
BehaviorBase.Description = "Change me"
BehaviorBase.Interruptible = true


local STATUS = TTTBots.STATUS

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function BehaviorBase.Validate(bot)
    return true
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function BehaviorBase.OnStart(bot)
    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function BehaviorBase.OnRunning(bot)
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function BehaviorBase.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function BehaviorBase.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function BehaviorBase.OnEnd(bot)
end

--- Returns the per-bot state table for a given behavior name, creating it if it does not exist.
--- Usage: local state = TTTBots.Behaviors.GetState(bot, "MyBehavior")
---@param bot Bot
---@param behaviorName string
---@return table
function TTTBots.Behaviors.GetState(bot, behaviorName)
    bot.behaviorState = bot.behaviorState or {}
    bot.behaviorState[behaviorName] = bot.behaviorState[behaviorName] or {}
    return bot.behaviorState[behaviorName]
end

--- Clears the per-bot state table for a given behavior name.
--- Should be called from OnEnd to avoid stale state between runs.
---@param bot Bot
---@param behaviorName string
function TTTBots.Behaviors.ClearState(bot, behaviorName)
    if bot.behaviorState then
        bot.behaviorState[behaviorName] = nil
    end
end
