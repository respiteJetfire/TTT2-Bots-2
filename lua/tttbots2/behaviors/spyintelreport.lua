---@class BSpyIntelReport
TTTBots.Behaviors.SpyIntelReport = {}

local lib = TTTBots.Lib

---@class BSpyIntelReport
local SpyIntelReport = TTTBots.Behaviors.SpyIntelReport
SpyIntelReport.Name = "SpyIntelReport"
SpyIntelReport.Description = "Spy approaches the nearest detective (or trusted ally) to report surveillance findings."
SpyIntelReport.Interruptible = true

---@class Bot
---@field spyIntelTarget Player? The last surveilled target; populated by SpySurveillance on success
---@field spyIntelSuspicion number The suspicion level of spyIntelTarget when surveillance ended
---@field spyIntelReportee Player? The detective/trusted player the spy is walking toward

local STATUS = TTTBots.STATUS

local REPORT_RANGE = 200       -- Maximum distance in Source/Hammer units to deliver the intel report
local DEFAULT_KOS_THRESHOLD = 7 -- Fallback KOS threshold if TTTBots.Components.Morality is not yet loaded

--- Find the nearest alive police/detective player the spy can report to.
---@param bot Bot
---@return Player?
function SpyIntelReport.FindReportTarget(bot)
    local alivePlayers = lib.GetAlivePlayers()
    local bestTarget = nil
    local bestDist = math.huge

    for _, other in ipairs(alivePlayers) do
        if not lib.IsPlayerAlive(other) then continue end
        if other == bot then continue end
        local role = TTTBots.Roles.GetRoleFor(other)
        if not role then continue end
        if not role:GetAppearsPolice() then continue end
        local dist = bot:GetPos():Distance(other:GetPos())
        if dist < bestDist then
            bestDist = dist
            bestTarget = other
        end
    end

    return bestTarget
end

--- Validate the behavior.
---@param bot Bot
---@return boolean
function SpyIntelReport.Validate(bot)
    if not IsValid(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.attackTarget ~= nil then return false end
    if bot:GetSubRole() ~= ROLE_SPY then return false end
    -- We need pending intel (set by SpySurveillance.OnSuccess)
    if not bot.spyIntelTarget or not IsValid(bot.spyIntelTarget) then return false end
    -- Make sure the target is still worth reporting (not dead)
    if not lib.IsPlayerAlive(bot.spyIntelTarget) then
        bot.spyIntelTarget = nil
        return false
    end
    -- There must be a detective alive to report to
    return SpyIntelReport.FindReportTarget(bot) ~= nil
end

--- Called when the behavior is started.
---@param bot Bot
---@return BStatus
function SpyIntelReport.OnStart(bot)
    local reportee = SpyIntelReport.FindReportTarget(bot)
    if not reportee then return STATUS.FAILURE end
    bot.spyIntelReportee = reportee
    return STATUS.RUNNING
end

--- Called when the behavior is running.
---@param bot Bot
---@return BStatus
function SpyIntelReport.OnRunning(bot)
    local target = bot.spyIntelTarget
    local reportee = bot.spyIntelReportee

    if not target or not IsValid(target) then return STATUS.FAILURE end
    if not reportee or not IsValid(reportee) then return STATUS.FAILURE end
    if not lib.IsPlayerAlive(reportee) then return STATUS.FAILURE end

    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    local distToReportee = bot:GetPos():Distance(reportee:GetPos())
    if distToReportee > REPORT_RANGE then
        loco:SetGoal(reportee:GetPos())
        loco:LookAt(reportee:EyePos())
        return STATUS.RUNNING
    end

    -- Close enough — deliver the report
    loco:SetGoal(bot:GetPos())
    loco:LookAt(reportee:EyePos())

    local chatter = bot:BotChatter()
    if chatter then
        local suspicionLevel = bot.spyIntelSuspicion or 0
        local kosThreshold = (TTTBots.Components.Morality and TTTBots.Components.Morality.Thresholds and TTTBots.Components.Morality.Thresholds.KOS) or DEFAULT_KOS_THRESHOLD
        if suspicionLevel >= kosThreshold then
            chatter:On("SpyIntelReportKOS", { player = target:Nick(), detective = reportee:Nick() })
        else
            chatter:On("SpyIntelReport", { player = target:Nick(), detective = reportee:Nick() })
        end
    end

    bot.spyIntelTarget = nil
    bot.spyIntelSuspicion = nil
    return STATUS.SUCCESS
end

--- Called when the behavior returns a success state.
---@param bot Bot
function SpyIntelReport.OnSuccess(bot)
end

--- Called when the behavior returns a failure state.
---@param bot Bot
function SpyIntelReport.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup.
---@param bot Bot
function SpyIntelReport.OnEnd(bot)
    bot.spyIntelReportee = nil
end
