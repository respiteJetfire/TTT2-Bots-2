--[[
    GhostDM Wander Behavior for TTT2 Bots (fallback)
    When in Ghost DM with no target to fight, wander around the map.
    This acts as the leaf/fallback behavior in the ghost DM behavior tree.
]]

TTTBots.Behaviors.GhostDMWander = {}

local lib = TTTBots.Lib

---@class BGhostDMWander
local GhostDMWander = TTTBots.Behaviors.GhostDMWander
GhostDMWander.Name = "GhostDMWander"
GhostDMWander.Description = "Wandering around in Ghost Deathmatch"
GhostDMWander.Interruptible = true

local STATUS = TTTBots.STATUS

--- Check if the GhostDM addon is loaded and this bot is a ghost
---@param bot Bot
---@return boolean
local function IsGhostBot(bot)
    if not GhostDM then return false end
    if not GhostDM.IsGhost then return false end
    return GhostDM.IsGhost(bot)
end

--- Validate the behavior
function GhostDMWander.Validate(bot)
    if not IsGhostBot(bot) then return false end
    if not bot:Alive() then return false end
    return true
end

--- Called when the behavior is started
function GhostDMWander.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "GhostDMWander")
    state.nextGoalTime = 0
    return STATUS.RUNNING
end

--- Called when the behavior is running
function GhostDMWander.OnRunning(bot)
    if not IsGhostBot(bot) then return STATUS.FAILURE end

    local state = TTTBots.Behaviors.GetState(bot, "GhostDMWander")
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    loco:StopAttack()
    loco.stopLookingAround = false

    local curTime = CurTime()
    if curTime > (state.nextGoalTime or 0) then
        local randomNav = TTTBots.Behaviors.Wander.GetAnyRandomNav(bot)
        if IsValid(randomNav) then
            loco:SetGoal(randomNav:GetCenter())
        end
        state.nextGoalTime = curTime + math.random(4, 10)
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state
function GhostDMWander.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function GhostDMWander.OnFailure(bot)
end

--- Called when the behavior ends
function GhostDMWander.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "GhostDMWander")
end

return true
