--- spyeavesdrop.lua
--- SpyEavesdrop Behavior — Spy silently observes traitor activity.
---
--- When traitor bots execute plan-related behaviors near the spy, the spy
--- gains intelligence. This is a passive observation behavior — the spy
--- positions itself to overhear/observe traitor coordination without
--- drawing attention.

---@class SpyEavesdrop
TTTBots.Behaviors.SpyEavesdrop = {}

local lib = TTTBots.Lib

---@class SpyEavesdrop
local SpyEavesdrop = TTTBots.Behaviors.SpyEavesdrop
SpyEavesdrop.Name = "SpyEavesdrop"
SpyEavesdrop.Description = "Spy silently observes traitor activity to gather intelligence."
SpyEavesdrop.Interruptible = true

local STATUS = TTTBots.STATUS

--- Find a traitor bot that's currently engaged in suspicious activity.
---@param bot Bot
---@return Player|nil
local function findEavesdropTarget(bot)
    if not TTTBots.Perception then return nil end
    local knownTraitors = TTTBots.Perception.GetKnownTraitors(bot)
    local botPos = bot:GetPos()

    local best, bestDist = nil, math.huge
    for _, traitor in pairs(knownTraitors) do
        if not (IsValid(traitor) and lib.IsPlayerAlive(traitor)) then continue end
        local dist = botPos:Distance(traitor:GetPos())

        -- Prefer nearby traitors (within 600 units)
        if dist < 600 and dist < bestDist then
            -- Check if the traitor is doing something suspicious
            -- (attacking someone, near a body, carrying T weapons, etc.)
            local isSuspicious = false

            -- Check if traitor has an attack target
            if traitor:IsBot() and traitor.attackTarget and IsValid(traitor.attackTarget) then
                isSuspicious = true
            end

            -- Check if traitor is holding a traitor weapon
            if TTTBots.Lib.IsHoldingTraitorWep and TTTBots.Lib.IsHoldingTraitorWep(traitor) then
                isSuspicious = true
            end

            -- Check if traitor is near a corpse
            local corpses = TTTBots.Match.Corpses or {}
            for _, corpse in pairs(corpses) do
                if IsValid(corpse) and traitor:GetPos():Distance(corpse:GetPos()) < 200 then
                    isSuspicious = true
                    break
                end
            end

            -- Even if not suspicious, still valid to eavesdrop (just lower priority)
            if isSuspicious then
                bestDist = dist * 0.5  -- double priority for suspicious traitors
                best = traitor
            elseif dist < bestDist then
                bestDist = dist
                best = traitor
            end
        end
    end

    return best
end

function SpyEavesdrop.Validate(bot)
    if not IsValid(bot) then return false end
    if not TTTBots.Perception then return false end
    if not TTTBots.Perception.IsSpy(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.attackTarget ~= nil then return false end

    -- Don't eavesdrop if cover is blown
    if TTTBots.Perception.IsCoverBlown(bot) then return false end

    local state = TTTBots.Behaviors.GetState(bot, "SpyEavesdrop")
    if state.eavesdropping then return true end

    -- Cooldown: 20s between eavesdrop sessions (modified by personality)
    local mods = TTTBots.Spy and TTTBots.Spy.GetPersonalityModifiers and TTTBots.Spy.GetPersonalityModifiers(bot) or {}
    local eavesdropMod = mods.eavesdropChance or 1.0
    local cooldown = 20 / eavesdropMod  -- higher eavesdrop chance = shorter cooldown
    if (state.lastEavesdropTime or 0) + cooldown > CurTime() then return false end

    -- 10% chance per tick (modified by personality)
    if not lib.TestPercent(10 * eavesdropMod) then return false end

    local target = findEavesdropTarget(bot)
    if not target then return false end

    state.eavesdropTarget = target
    return true
end

function SpyEavesdrop.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "SpyEavesdrop")
    if not state.eavesdropTarget or not IsValid(state.eavesdropTarget) then return STATUS.FAILURE end

    state.eavesdropping = true
    state.startTime = CurTime()
    -- Personality modifies observation duration
    local mods = TTTBots.Spy and TTTBots.Spy.GetPersonalityModifiers and TTTBots.Spy.GetPersonalityModifiers(bot) or {}
    state.duration = math.random(6, 15) * (mods.eavesdropChance or 1.0)

    return STATUS.RUNNING
end

function SpyEavesdrop.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "SpyEavesdrop")
    local target = state.eavesdropTarget

    if not (IsValid(target) and lib.IsPlayerAlive(target)) then return STATUS.FAILURE end

    -- Timeout
    if CurTime() - state.startTime > state.duration then return STATUS.SUCCESS end

    -- Abort if cover is blown
    if TTTBots.Perception.IsCoverBlown(bot) then return STATUS.FAILURE end

    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    local dist = bot:GetPos():Distance(target:GetPos())

    -- Keep a safe observation distance (200-400 units)
    if dist > 400 then
        loco:SetGoal(target:GetPos())
    elseif dist < 150 then
        -- Too close — back off slightly (just stop moving)
        loco:SetGoal()
    else
        -- Good distance — observe
        loco:SetGoal()
        loco:LookAt(target:EyePos())
    end

    -- Gather evidence if we see the traitor doing something suspicious
    if target:IsBot() and target.attackTarget and IsValid(target.attackTarget) then
        local evidence = bot:BotEvidence()
        if evidence then
            evidence:AddEvidence({
                type    = "SPY_INTEL",
                subject = target,
                detail  = "observed preparing to attack " .. (IsValid(target.attackTarget) and target.attackTarget:Nick() or "someone"),
                weight  = 4,
            })
        end
    end

    return STATUS.RUNNING
end

function SpyEavesdrop.OnSuccess(bot)
    -- Occasionally mutter about what we observed
    if math.random(1, 3) == 1 then
        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("SpyEavesdrop", {}, false, math.random(2, 5))
        end
    end
end
function SpyEavesdrop.OnFailure(bot) end

function SpyEavesdrop.OnEnd(bot)
    local state = TTTBots.Behaviors.GetState(bot, "SpyEavesdrop")
    state.lastEavesdropTime = CurTime()
    local lastTime = state.lastEavesdropTime
    TTTBots.Behaviors.ClearState(bot, "SpyEavesdrop")
    TTTBots.Behaviors.GetState(bot, "SpyEavesdrop").lastEavesdropTime = lastTime
end
