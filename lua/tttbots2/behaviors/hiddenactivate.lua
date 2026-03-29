--- hiddenactivate.lua
--- Hidden transformation decision behavior.
--- The Hidden bot must decide the optimal moment to permanently transform
--- from disguised mode into stalker mode by pressing Reload (IN_RELOAD).
--- Once transformed, there is no going back — so the decision is critical.
---
--- Decision factors (weighted):
---   - Alive player count (fewer = better)
---   - Isolation (no witnesses nearby)
---   - Round phase (prefer MID/LATE)
---   - Bot health (prefer full HP for max boost)
---   - Random chance gate (adds variety)
---   - Fallback: force-transform after 180s
---
--- After pressing Reload, the server-side KeyPress hook in sh_hd_handler.lua
--- handles the actual transformation. We verify success via NWBool.

---@class BHiddenActivate
TTTBots.Behaviors.HiddenActivate = {}

local lib = TTTBots.Lib
---@class BHiddenActivate
local Activate = TTTBots.Behaviors.HiddenActivate
Activate.Name = "HiddenActivate"
Activate.Description = "Decide when to transform into Hidden stalker mode."
Activate.Interruptible = true

local STATUS = TTTBots.STATUS
local MIN_ROUND_TIME = 15       -- Don't transform in the first 15 seconds
local FORCE_TRANSFORM_TIME = 180 -- Force-transform after 180 seconds regardless
local READINESS_THRESHOLD = 40   -- Score needed to trigger transformation
local VALIDATE_CHANCE = 20       -- 1-in-N chance per validate tick (5%)

--- Returns true if this bot is playing the Hidden role.
---@param bot Bot
---@return boolean
local function isHidden(bot)
    if not bot then return false end
    local roleStr = bot.GetRoleStringRaw and bot:GetRoleStringRaw() or ""
    return roleStr == "hidden"
end

--- Returns true if the bot is already in stalker mode.
---@param bot Bot
---@return boolean
local function isInStalkerMode(bot)
    return bot:GetNWBool("ttt2_hd_stalker_mode", false)
end

--- Count nearby players who could witness the transformation.
---@param bot Bot
---@param radius number
---@return number witnessCount
local function countNearbyWitnesses(bot, radius)
    local botPos = bot:GetPos()
    local count = 0

    for _, ply in ipairs(player.GetAll()) do
        if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end
        if ply == bot then continue end

        local dist = botPos:Distance(ply:GetPos())
        if dist <= radius then
            -- FOV-aware check: only count if they could actually see us
            if dist <= 300 then
                -- Very close — they'd hear/see regardless
                count = count + 1
            elseif lib.CanSeeArc and lib.CanSeeArc(ply, botPos, 120) then
                count = count + 1
            end
        end
    end

    return count
end

--- Calculate the "readiness score" — how ready the bot is to transform.
---@param bot Bot
---@return number score
local function calculateReadiness(bot)
    local score = 0

    -- Factor 1: Alive player count (fewer = more aggressive to transform)
    local aliveCount = #(TTTBots.Match.AlivePlayers or {})
    if aliveCount <= 6 then score = score + 20 end
    if aliveCount <= 4 then score = score + 30 end
    if aliveCount <= 3 then score = score + 15 end

    -- Factor 2: Isolation (no witnesses within 800 units)
    local witnesses = countNearbyWitnesses(bot, 800)
    if witnesses == 0 then
        score = score + 25
    elseif witnesses == 1 then
        score = score + 10
    else
        score = score - witnesses * 8  -- Penalty for too many witnesses
    end

    -- Factor 3: Health (prefer transforming at full HP for max boost)
    local hp = bot:Health()
    if hp >= 90 then
        score = score + 10
    elseif hp < 50 then
        score = score - 10  -- Wounded = worse time to transform
    end

    -- Factor 4: Round phase
    local ra = bot.BotRoundAwareness and bot:BotRoundAwareness()
    if ra then
        local PHASE = TTTBots.Components.RoundAwareness
            and TTTBots.Components.RoundAwareness.PHASE
        if PHASE then
            local phase = ra:GetPhase()
            if phase == PHASE.LATE then
                score = score + 20
            elseif phase == PHASE.OVERTIME then
                score = score + 40
            elseif phase == PHASE.MID then
                score = score + 5
            end
        end
    end

    -- Factor 5: Round time elapsed (bonus for patience)
    local roundStart = TTTBots.Match.RoundStart or 0
    local elapsed = CurTime() - roundStart
    if elapsed > 120 then
        score = score + 15
    elseif elapsed > 60 then
        score = score + 5
    end

    return score
end

--- Validate: only run as Hidden, not already in stalker mode, round active, time gate.
---@param bot Bot
---@return boolean
function Activate.Validate(bot)
    if not isHidden(bot) then return false end
    if isInStalkerMode(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Time gate: don't transform in the first 15 seconds
    local roundStart = TTTBots.Match.RoundStart or 0
    local elapsed = CurTime() - roundStart
    if elapsed < MIN_ROUND_TIME then return false end

    -- Force-transform fallback: if 180s have passed, always validate
    if elapsed >= FORCE_TRANSFORM_TIME then return true end

    -- Random chance gate: 5% per validate tick (adds variety)
    return math.random(1, VALIDATE_CHANCE) == 1
end

--- Called when the behavior starts.
---@param bot Bot
---@return BStatus
function Activate.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "HiddenActivate")
    state.pressedReload = false
    state.pressTime = 0
    return STATUS.RUNNING
end

--- Called each tick while running.
---@param bot Bot
---@return BStatus
function Activate.OnRunning(bot)
    if not isHidden(bot) then return STATUS.FAILURE end
    if not TTTBots.Match.IsRoundActive() then return STATUS.FAILURE end

    -- If already transformed, we're done
    if isInStalkerMode(bot) then return STATUS.SUCCESS end

    local state = TTTBots.Behaviors.GetState(bot, "HiddenActivate")
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    -- If we already pressed Reload, wait for the NWBool to confirm
    if state.pressedReload then
        -- Give 1 second for the server to process
        if CurTime() - state.pressTime > 1.0 then
            if isInStalkerMode(bot) then
                return STATUS.SUCCESS
            else
                -- Failed to transform — reset and try again
                state.pressedReload = false
            end
        end
        return STATUS.RUNNING
    end

    -- Check if force-transform time has been reached
    local roundStart = TTTBots.Match.RoundStart or 0
    local elapsed = CurTime() - roundStart
    local forceTransform = elapsed >= FORCE_TRANSFORM_TIME

    -- Calculate readiness score
    local readiness = calculateReadiness(bot)

    if readiness >= READINESS_THRESHOLD or forceTransform then
        -- Press IN_RELOAD to trigger transformation
        -- Stop moving briefly so the transformation can process cleanly
        loco:SetGoal()

        -- Simulate pressing Reload via the locomotor's key press
        -- The bot framework uses bot:SetButtons() or direct input injection
        bot:SetButtons(bit.bor(bot:GetButtons() or 0, IN_RELOAD))

        state.pressedReload = true
        state.pressTime = CurTime()

        return STATUS.RUNNING
    end

    -- Not ready yet — continue evaluating
    return STATUS.RUNNING
end

--- Called on success.
---@param bot Bot
function Activate.OnSuccess(bot)
end

--- Called on failure.
---@param bot Bot
function Activate.OnFailure(bot)
    TTTBots.Behaviors.ClearState(bot, "HiddenActivate")
end

--- Called when the behavior ends (success or failure).
---@param bot Bot
function Activate.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "HiddenActivate")
end
