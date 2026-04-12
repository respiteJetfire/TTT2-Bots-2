--- vultureeat.lua
--- Behavior for Vulture bots: seek and "eat" nearby corpses to progress toward
--- their win condition. The Vulture uses weapon_ttt_vult_knife with secondary
--- fire to eat a corpse (triggering the sh_vulture_handler VULTURE_DATA:AddEaten logic).
---
--- Bot strategy:
---   1. Find the nearest visible corpse (ragdoll) within search range.
---   2. Navigate to within knife range (~80 units) and face it.
---   3. Use primary fire (talon attack / eat secondary) to consume the body.
---   4. After each eat, check if still hungry (VULTURE_DATA.amount_eaten < amount_to_win).
---   5. Return SUCCESS after consuming a corpse; FAILURE if none accessible.

if not (TTT2 and ROLE_VULTURE) then return end

---@class BVultureEat
TTTBots.Behaviors.VultureEat = {}

local lib = TTTBots.Lib

---@class BVultureEat
local VEat = TTTBots.Behaviors.VultureEat
VEat.Name = "VultureEat"
VEat.Description = "Seek and eat corpses to win as the Vulture"
VEat.Interruptible = true

local STATUS = TTTBots.STATUS

--- Range at which the vulture knife can eat a corpse.
local KNIFE_RANGE = 100
--- Search radius for corpses (vultures can see all corpses via marker vision).
local SEEK_RANGE = 2000
--- Track which corpses have been eaten this approach cycle.
local eatenCorpses = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Check if Vulture still needs to eat more corpses.
---@return boolean
local function needsToEat()
    if not VULTURE_DATA then return false end
    if VULTURE_DATA.amount_to_win == nil then return false end
    return VULTURE_DATA.amount_eaten < VULTURE_DATA.amount_to_win
end

--- Find the nearest uneaten corpse within seek range.
---@param bot Player
---@return Entity|nil
local function findNearestCorpse(bot)
    local botPos = bot:GetPos()
    local best, bestDist = nil, SEEK_RANGE

    for _, ent in ipairs(ents.FindInSphere(botPos, SEEK_RANGE)) do
        if not IsValid(ent) then continue end
        if ent:GetClass() ~= "prop_ragdoll" then continue end
        if eatenCorpses[ent] then continue end

        local dist = botPos:Distance(ent:GetPos())
        if dist < bestDist then
            bestDist = dist
            best = ent
        end
    end

    return best
end

-- ---------------------------------------------------------------------------
-- Behavior interface
-- ---------------------------------------------------------------------------

function VEat.Validate(bot)
    if not IsValid(bot) then return false end
    if not ROLE_VULTURE then return false end
    if bot:GetSubRole() ~= ROLE_VULTURE then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not needsToEat() then return false end

    -- Check there's actually a corpse nearby to eat
    return findNearestCorpse(bot) ~= nil
end

function VEat.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "VultureEat")
    state.target = findNearestCorpse(bot)

    -- Feeding chatter
    local chatter = bot:BotChatter()
    if chatter and chatter.On and math.random(1, 2) == 1 then
        chatter:On("VultureFeeding", {}, false, 0)
    end

    return STATUS.RUNNING
end

function VEat.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "VultureEat")
    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    -- Check win condition
    if not needsToEat() then return STATUS.SUCCESS end

    -- Refresh target if invalid
    if not state.target or not IsValid(state.target) then
        state.target = findNearestCorpse(bot)
        if not state.target then return STATUS.FAILURE end
    end

    local corpse = state.target
    local corpsePos = corpse:GetPos()
    local dist = bot:GetPos():Distance(corpsePos)

    -- Navigate toward corpse
    loco:SetGoal(corpsePos)
    loco:LookAt(corpsePos + Vector(0, 0, 20))

    if dist <= KNIFE_RANGE and bot:VisibleVec(corpsePos) then
        -- Equip vulture knife
        local knife = bot:GetWeapon("weapon_ttt_vult_knife")
        if IsValid(knife) then
            bot:SetActiveWeapon(knife)
            inv:PauseAutoSwitch()
        end

        local eyeTrace = bot:GetEyeTrace()
        local hitEnt = eyeTrace and eyeTrace.Entity

        if hitEnt == corpse then
            -- Primary fire to use the knife on the corpse (talon / eat mechanic)
            loco:StartAttack()
            timer.Simple(0.3, function()
                if IsValid(bot) then loco:StopAttack() end
            end)

            -- Mark as eaten and move on
            eatenCorpses[corpse] = true
            state.target = nil
            inv:ResumeAutoSwitch()
            return STATUS.SUCCESS
        end
    end

    return STATUS.RUNNING
end

function VEat.OnSuccess(bot)
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end
end

function VEat.OnFailure(bot)
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
end

function VEat.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "VultureEat")
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end
end

-- Reset eaten set at round start
hook.Add("TTTBeginRound", "TTTBots.VultureEat.Reset", function()
    eatenCorpses = {}
    for _, bot in ipairs(player.GetBots()) do
        if not IsValid(bot) then continue end
        local state = TTTBots.Behaviors.GetState(bot, "VultureEat")
        if state then
            state.target = nil
        end
    end
end)
