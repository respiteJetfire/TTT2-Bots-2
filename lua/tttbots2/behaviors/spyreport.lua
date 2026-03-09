--- spyreport.lua
--- SpyReport Behavior — Spy shares traitor intelligence with innocent players.
---
--- When the spy has observed traitor behavior (kills, C4 plant, suspicious movement),
--- they move toward a trusted innocent and share their intel via chatter.
--- The spy's evidence carries extra weight (SPY_INTEL type).

---@class SpyReport
TTTBots.Behaviors.SpyReport = {}

local lib = TTTBots.Lib

---@class SpyReport
local SpyReport = TTTBots.Behaviors.SpyReport
SpyReport.Name = "SpyReport"
SpyReport.Description = "Spy reports traitor intelligence to innocent players."
SpyReport.Interruptible = true

local STATUS = TTTBots.STATUS

--- Find the best innocent to report to (prefer detectives, then nearby innocents).
---@param bot Bot
---@return Player|nil
local function findReportTarget(bot)
    local bestTarget = nil
    local bestScore = -math.huge
    local botPos = bot:GetPos()

    for _, ply in pairs(TTTBots.Match.AlivePlayers or {}) do
        if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end
        if ply == bot then continue end
        if not (ply:GetTeam() == TEAM_INNOCENT) then continue end

        -- Don't report to a traitor we know about
        if TTTBots.Perception and TTTBots.Perception.IsTraitorTeam(ply) then continue end

        local dist = botPos:Distance(ply:GetPos())
        if dist > 1500 then continue end  -- too far

        local score = 1000 - dist  -- closer = better

        -- Prefer detectives
        local role = TTTBots.Roles.GetRoleFor(ply)
        if role and role:GetAppearsPolice() then
            score = score + 500
        end

        if score > bestScore then
            bestScore = score
            bestTarget = ply
        end
    end

    return bestTarget
end

--- Check if the spy has enough evidence worth reporting.
---@param bot Bot
---@return Player|nil  The traitor suspect with the most evidence
local function getReportableSuspect(bot)
    local evidence = bot:BotEvidence()
    if not evidence then return nil end

    local suspects = evidence:GetSuspects(5)  -- lower threshold for spy intel
    if not suspects or #suspects == 0 then return nil end

    -- Find the top suspect that's actually a traitor (spy knows who's traitor)
    local best, bestW = nil, -math.huge
    for _, s in ipairs(suspects) do
        if not (IsValid(s) and lib.IsPlayerAlive(s)) then continue end
        if TTTBots.Perception and TTTBots.Perception.IsTraitorTeam(s) then
            local w = evidence:EvidenceWeight(s)
            if w > bestW then bestW = w; best = s end
        end
    end

    return best
end

function SpyReport.Validate(bot)
    if not IsValid(bot) then return false end
    if not TTTBots.Perception then return false end
    if not TTTBots.Perception.IsSpy(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.attackTarget ~= nil then return false end

    local state = TTTBots.Behaviors.GetState(bot, "SpyReport")
    if state.reporting then return true end

    -- Cooldown: don't spam reports (modified by personality eagerness)
    local mods = TTTBots.Spy and TTTBots.Spy.GetPersonalityModifiers and TTTBots.Spy.GetPersonalityModifiers(bot) or {}
    local eagerness = mods.reportEagerness or 1.0
    local cooldown = 60 / eagerness  -- higher eagerness = shorter cooldown
    if (state.lastReportTime or 0) + cooldown > CurTime() then return false end

    -- Need a suspect to report and someone to report to
    local suspect = getReportableSuspect(bot)
    if not suspect then return false end

    local reportTarget = findReportTarget(bot)
    if not reportTarget then return false end

    state.suspect = suspect
    state.reportTarget = reportTarget
    return true
end

function SpyReport.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "SpyReport")
    if not (IsValid(state.reportTarget) and IsValid(state.suspect)) then return STATUS.FAILURE end

    state.reporting = true
    state.startTime = CurTime()
    state.reported = false

    return STATUS.RUNNING
end

function SpyReport.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "SpyReport")
    local reportTarget = state.reportTarget
    local suspect = state.suspect

    if not (IsValid(reportTarget) and lib.IsPlayerAlive(reportTarget)) then return STATUS.FAILURE end
    if not (IsValid(suspect) and lib.IsPlayerAlive(suspect)) then return STATUS.SUCCESS end

    -- Timeout after 15s
    if CurTime() - state.startTime > 15 then return STATUS.SUCCESS end

    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    local dist = bot:GetPos():Distance(reportTarget:GetPos())

    -- Move toward report target
    if dist > 300 then
        loco:SetGoal(reportTarget:GetPos())
        return STATUS.RUNNING
    end

    -- Close enough — deliver the report
    if not state.reported then
        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("SpyReportIntel", {
                player = suspect:Nick(),
                playerEnt = suspect,
                target = reportTarget:Nick(),
            }, false, 0)
        end

        -- Share evidence with the report target if they're a bot
        if reportTarget:IsBot() then
            local myEvidence = bot:BotEvidence()
            if myEvidence then
                myEvidence:ShareEvidence(reportTarget)
            end
        end

        state.reported = true
        state.lastReportTime = CurTime()
        return STATUS.SUCCESS
    end

    return STATUS.RUNNING
end

function SpyReport.OnSuccess(bot) end
function SpyReport.OnFailure(bot) end

function SpyReport.OnEnd(bot)
    local state = TTTBots.Behaviors.GetState(bot, "SpyReport")
    local lastReport = state.lastReportTime
    TTTBots.Behaviors.ClearState(bot, "SpyReport")
    -- Preserve the cooldown timer across behavior cycles
    if lastReport then
        TTTBots.Behaviors.GetState(bot, "SpyReport").lastReportTime = lastReport
    end
end
