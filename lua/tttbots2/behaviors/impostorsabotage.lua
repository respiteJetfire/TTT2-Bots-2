--- impostorsabotage.lua
--- Proactive sabotage behavior for Impostor bots.
---
--- The Impostor can activate sabotages (Lights, Comms, O2, Reactor) via V key.
--- Each sabotage has a 120-second cooldown.
---
--- Bot strategy:
---   • Prefer O2 sabotage early (passive HP drain to all enemies).
---   • Use Reactor sabotage later in the round when the win condition is hard.
---   • Avoid Lights/Comms sabotages (less useful to bots without HUD dependency).
---   • Only sabotage when out of direct combat (it's a strategic, not tactical, tool).

if not (TTT2 and ROLE_IMPOSTOR) then return end

---@class BImpostorSabotage
TTTBots.Behaviors.ImpostorSabotage = {}

local lib = TTTBots.Lib

---@class BImpostorSabotage
local ISabo = TTTBots.Behaviors.ImpostorSabotage
ISabo.Name = "ImpostorSabotage"
ISabo.Description = "Activate sabotages proactively as the Impostor"
ISabo.Interruptible = true

local STATUS = TTTBots.STATUS

--- Sabotage type IDs matching the addon's IMPO_SABO_TYPE enum.
local SABO_O2     = "O2"
local SABO_REACT  = "REACT"
local SABO_COMMS  = "COMMS"
local SABO_LIGHTS = "LIGHTS"

--- Minimum seconds into the round before using Reactor sabotage.
local REACTOR_MIN_ROUND_TIME = 90

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Check if a sabotage type is currently off cooldown.
---@param saboType string
---@return boolean
local function isSaboReady(saboType)
    if not (IMPO_SABO_DATA and IMPO_SABO_DATA.COOLDOWN_TABLE) then
        -- Fallback: check the timer names
        return not timer.Exists("ttt2_impo_sabo_cooldown_" .. saboType)
    end
    local cooldown = IMPO_SABO_DATA.COOLDOWN_TABLE[saboType]
    return not cooldown or cooldown <= CurTime()
end

--- Check if a sabotage is currently active.
---@param saboType string
---@return boolean
local function isSaboActive(saboType)
    if not IMPO_SABO_DATA then return false end
    if IMPO_SABO_DATA.ACTIVE_SABO then
        return IMPO_SABO_DATA.ACTIVE_SABO == saboType
    end
    -- Check NW value if available
    return false
end

--- Select the best sabotage to activate.
---@param bot Player
---@return string|nil
local function selectBestSabotage(bot)
    -- Don't sabotage if another is already active
    if IMPO_SABO_DATA and IMPO_SABO_DATA.ACTIVE_SABO and IMPO_SABO_DATA.ACTIVE_SABO ~= "" then
        return nil
    end

    local roundTime = TTTBots.Match.GetRoundElapsedTime and TTTBots.Match.GetRoundElapsedTime() or 0
    local aliveCount = #(TTTBots.Match.AlivePlayers or {})

    -- Reactor: only in late game with 4+ alive; high-risk/reward
    if roundTime >= REACTOR_MIN_ROUND_TIME and aliveCount >= 4 and isSaboReady(SABO_REACT) then
        if math.random(1, 4) == 1 then  -- 25% chance to pick reactor
            return SABO_REACT
        end
    end

    -- O2: good passive pressure when many players alive
    if aliveCount >= 3 and isSaboReady(SABO_O2) then
        return SABO_O2
    end

    return nil
end

--- Activate a sabotage by simulating the bind key.
--- The addon uses cmd bind "V" to toggle the sabotage menu.
---@param bot Player
---@param saboType string
local function activateSabotage(bot, saboType)
    if not IsValid(bot) then return end

    -- If the addon exposes a direct activation function, prefer it
    if IMPO_SABO_DATA and IMPO_SABO_DATA.ActivateSabotage then
        IMPO_SABO_DATA.ActivateSabotage(bot, saboType)
        return
    end

    -- Fallback: fire the net message the client would send
    -- ttt2_impo_activate_sabo net message: {type=saboType}
    if net and net.Start then
        net.Start("ttt2_impo_activate_sabo")
            net.WriteString(saboType)
        net.SendToServer()
    end
end

-- ---------------------------------------------------------------------------
-- Behavior interface
-- ---------------------------------------------------------------------------

function ISabo.Validate(bot)
    if not IsValid(bot) then return false end
    if not ROLE_IMPOSTOR then return false end
    if bot:GetSubRole() ~= ROLE_IMPOSTOR then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Don't sabotage during active combat
    if bot.attackTarget and IsValid(bot.attackTarget) then return false end

    -- Don't sabotage while venting
    if TTTBots.Impostor_IsVenting and TTTBots.Impostor_IsVenting(bot) then return false end

    return selectBestSabotage(bot) ~= nil
end

function ISabo.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ImpostorSabotage")
    state.selectedSabo = selectBestSabotage(bot)
    state.triggered = false
    return STATUS.RUNNING
end

function ISabo.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ImpostorSabotage")

    if state.triggered then
        return STATUS.SUCCESS
    end

    local sabo = state.selectedSabo
    if not sabo then
        sabo = selectBestSabotage(bot)
        state.selectedSabo = sabo
    end

    if not sabo then return STATUS.FAILURE end

    -- Activate the sabotage
    activateSabotage(bot, sabo)
    state.triggered = true

    -- Chatter
    local chatter = bot:BotChatter()
    if chatter and chatter.On and math.random(1, 2) == 1 then
        chatter:On("ImpostorSabotage", { sabo = sabo }, false)
    end

    return STATUS.SUCCESS
end

function ISabo.OnSuccess(bot)
end

function ISabo.OnFailure(bot)
end

function ISabo.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "ImpostorSabotage")
end
