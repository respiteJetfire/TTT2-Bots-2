--- spyblend.lua
--- SpyBlend Behavior — Spy blends in with nearby traitors to maintain cover.
---
--- Priority: Between FollowInnocentPlan and Support in the spy behavior tree.
---
--- Validate: Bot is a spy, a known traitor is nearby and visible, cover not blown.
--- OnStart:  Move toward a traitor, adopt casual posture.
--- OnRunning: Stay near the traitor, occasionally chat. Avoid attacking innocents.
---            If traitor starts attacking, the spy may need to decide whether to
---            join in (risky) or find an excuse to leave.

---@class SpyBlend
TTTBots.Behaviors.SpyBlend = {}

local lib = TTTBots.Lib

---@class SpyBlend
local SpyBlend = TTTBots.Behaviors.SpyBlend
SpyBlend.Name = "SpyBlend"
SpyBlend.Description = "Blend in with traitors to maintain spy cover."
SpyBlend.Interruptible = true

local STATUS = TTTBots.STATUS

--- Validate the behavior before we can start it (or continue running).
---@param bot Bot
---@return boolean
function SpyBlend.Validate(bot)
    if not IsValid(bot) then return false end
    if not TTTBots.Perception then return false end
    if not TTTBots.Perception.IsSpy(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.attackTarget ~= nil then return false end

    -- Don't blend if cover is already blown
    if TTTBots.Perception.IsCoverBlown(bot) then return false end

    -- Check if there's a nearby traitor to blend with
    local knownTraitors = TTTBots.Perception.GetKnownTraitors(bot)
    if #knownTraitors == 0 then return false end

    -- Only blend occasionally (15% chance per tick)
    local state = TTTBots.Behaviors.GetState(bot, "SpyBlend")
    if state.blending then return true end  -- continue if already blending
    if not lib.TestPercent(15) then return false end

    -- Find a visible traitor
    for _, traitor in pairs(knownTraitors) do
        if not (IsValid(traitor) and lib.IsPlayerAlive(traitor)) then continue end
        local dist = bot:GetPos():Distance(traitor:GetPos())
        if dist < 800 and bot:Visible(traitor) then
            state.blendTarget = traitor
            return true
        end
    end

    return false
end

---@param bot Bot
---@return BStatus
function SpyBlend.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "SpyBlend")
    if not state.blendTarget or not IsValid(state.blendTarget) then return STATUS.FAILURE end

    state.blending = true
    state.startTime = CurTime()

    -- Apply personality modifiers
    local mods = TTTBots.Spy and TTTBots.Spy.GetPersonalityModifiers and TTTBots.Spy.GetPersonalityModifiers(bot) or {}
    local durationMod = mods.coverDuration or 1.0
    state.duration = math.random(8, 20) * durationMod
    state.blendDistMod = mods.blendDistance or 1.0
    state.chatted = false

    return STATUS.RUNNING
end

---@param bot Bot
---@return BStatus
function SpyBlend.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "SpyBlend")
    local target = state.blendTarget

    -- Guard: target must still be valid and alive
    if not (IsValid(target) and lib.IsPlayerAlive(target)) then
        return STATUS.FAILURE
    end

    -- Check duration — don't blend too long
    if CurTime() - state.startTime > state.duration then
        return STATUS.SUCCESS
    end

    -- Abort if cover is blown
    if TTTBots.Perception.IsCoverBlown(bot) then
        return STATUS.FAILURE
    end

    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    local dist = bot:GetPos():Distance(target:GetPos())

    -- Move toward the traitor but keep a comfortable "blend" distance
    local blendMod = state.blendDistMod or 1.0
    local farThreshold = 300 * blendMod
    local nearThreshold = 100 * blendMod
    if dist > farThreshold then
        loco:SetGoal(target:GetPos())
    elseif dist < nearThreshold then
        -- Too close, stop moving
        loco:SetGoal()
    else
        -- In the sweet spot — just stay here
        loco:SetGoal()
    end

    -- Occasionally chat to build cover
    if not state.chatted and math.random(1, 5) == 1 then
        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("SpyBlendIn", { player = target:Nick() }, false, math.random(1, 3))
        end
        state.chatted = true
    end

    return STATUS.RUNNING
end

function SpyBlend.OnSuccess(bot) end
function SpyBlend.OnFailure(bot) end

function SpyBlend.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "SpyBlend")
end
