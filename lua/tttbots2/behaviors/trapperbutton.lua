--- trapperbutton.lua
--- Behavior for Trapper bots: find and activate traitor buttons.
---
--- The Trapper's unique ability is activating Traitor Buttons (func_button /
--- ttt_traitor_button entities). Pressing a button may trigger traps,
--- environmental effects, or teleporters that harm traitors.
---
--- Strategy:
---   1. Locate all traitor buttons on the map via ents.FindByClass.
---   2. Navigate to the nearest unactivated button.
---   3. Press it via +use.
---   4. Track notified positions from other button presses to aid investigation.
---   5. After pressing, wait for the global cooldown before seeking another.

if not (TTT2 and ROLE_TRAPPER) then return end

---@class BTrapperButton
TTTBots.Behaviors.TrapperButton = {}

local lib = TTTBots.Lib

---@class BTrapperButton
local TButton = TTTBots.Behaviors.TrapperButton
TButton.Name = "TrapperButton"
TButton.Description = "Find and activate traitor buttons as the Trapper"
TButton.Interruptible = true

local STATUS = TTTBots.STATUS

--- How close the bot needs to be to press a button.
local USE_DIST = 100
--- Seconds to wait after pressing before seeking another button.
local PRESS_COOLDOWN = 20
--- Maximum distance to consider a button.
local SEEK_MAXDIST = 8000

-- ---------------------------------------------------------------------------
-- Button discovery
-- ---------------------------------------------------------------------------

--- Find all traitor-button entities on the map.
--- Supports both func_button (generic) and ttt_traitor_button class names.
---@return Entity[]
local function findAllButtons()
    local buttons = {}
    for _, ent in ipairs(ents.FindByClass("func_button")) do
        if IsValid(ent) then
            -- Only traitor buttons — those tagged with TTT traitor button markers
            -- The addon marks them; we check for the TTT button key or class alias.
            table.insert(buttons, ent)
        end
    end
    for _, ent in ipairs(ents.FindByClass("ttt_traitor_button")) do
        if IsValid(ent) then
            table.insert(buttons, ent)
        end
    end
    return buttons
end

--- Find the nearest usable button.
---@param bot Player
---@param pressedSet table<Entity, boolean>
---@return Entity|nil
local function findNearestButton(bot, pressedSet)
    local botPos = bot:GetPos()
    local best, bestDist = nil, SEEK_MAXDIST

    for _, btn in ipairs(findAllButtons()) do
        if not IsValid(btn) then continue end
        if pressedSet[btn] then continue end

        local dist = botPos:Distance(btn:GetPos())
        if dist < bestDist then
            bestDist = dist
            best = btn
        end
    end

    return best
end

-- ---------------------------------------------------------------------------
-- Behavior interface
-- ---------------------------------------------------------------------------

function TButton.Validate(bot)
    if not IsValid(bot) then return false end
    if not ROLE_TRAPPER then return false end
    if bot:GetSubRole() ~= ROLE_TRAPPER then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Only run if we're not still in the press cooldown
    local state = TTTBots.Behaviors.GetState(bot, "TrapperButton")
    if (state.cooldownUntil or 0) > CurTime() then return false end

    -- Only run if there are buttons to press
    local pressed = state.pressedButtons or {}
    local btn = findNearestButton(bot, pressed)
    return btn ~= nil
end

function TButton.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "TrapperButton")
    if not state.pressedButtons then
        state.pressedButtons = {}
    end
    state.target = findNearestButton(bot, state.pressedButtons)
    return STATUS.RUNNING
end

function TButton.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "TrapperButton")
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    local btn = state.target
    if not btn or not IsValid(btn) then
        -- Try to find another
        btn = findNearestButton(bot, state.pressedButtons or {})
        if not btn then return STATUS.FAILURE end
        state.target = btn
    end

    local btnPos = btn:GetPos()
    local dist = bot:GetPos():Distance(btnPos)

    loco:SetGoal(btnPos)
    loco:LookAt(btnPos + Vector(0, 0, 40))

    if dist <= USE_DIST and bot:VisibleVec(btnPos) then
        -- Press the button via USE key
        bot:ConCommand("+use")
        timer.Simple(0.15, function()
            if IsValid(bot) then bot:ConCommand("-use") end
        end)

        -- Mark as pressed and start cooldown
        state.pressedButtons[btn] = true
        state.cooldownUntil = CurTime() + PRESS_COOLDOWN
        state.target = nil

        -- Chatter: activated a button
        local chatter = bot:BotChatter()
        if chatter and chatter.On and math.random(1, 3) == 1 then
            chatter:On("TrapperButtonPressed", {}, false)
        end

        return STATUS.SUCCESS
    end

    return STATUS.RUNNING
end

function TButton.OnSuccess(bot)
    local loco = bot:BotLocomotor()
    if loco then loco:StopMoving() end
end

function TButton.OnFailure(bot)
end

function TButton.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "TrapperButton")
end

-- ---------------------------------------------------------------------------
-- Hook: When the Trapper receives a button-ping notification (another player
-- pressed a button), investigate that position.
-- The addon sends "TrapperButtonUsed" net message to Trappers with the position.
-- ---------------------------------------------------------------------------
hook.Add("TTTBots.TrapperButtonNotified", "TTTBots.TrapperButton.Investigate",
    function(trapperBot, buttonPos)
        if not (IsValid(trapperBot) and trapperBot:IsBot()) then return end
        if not ROLE_TRAPPER then return end
        if trapperBot:GetSubRole() ~= ROLE_TRAPPER then return end

        -- Add to memory as a known hostile-activity position
        if trapperBot.components and trapperBot.components.memory then
            -- Record as a "suspicious position" — someone hostile used a traitor button
            local memory = trapperBot.components.memory
            if memory.AddSuspiciousPosition then
                memory:AddSuspiciousPosition(buttonPos)
            end
        end
    end
)

-- Round reset: clear pressed button cache
hook.Add("TTTBeginRound", "TTTBots.TrapperButton.Reset", function()
    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not IsValid(bot) then continue end
        local state = TTTBots.Behaviors.GetState(bot, "TrapperButton")
        if state then
            state.pressedButtons = {}
            state.cooldownUntil = 0
            state.target = nil
        end
    end
end)
