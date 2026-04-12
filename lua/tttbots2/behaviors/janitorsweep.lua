--- janitorsweep.lua
--- Behavior for Janitor bots: approach and sweep corpses after kills.
---
--- The Janitor's broom has:
---   • Primary fire: sweep (remove) a corpse — 60s cooldown.
---   • Secondary fire: wipe DNA from a corpse — no cooldown.
---
--- Bot strategy:
---   1. After any kill, find the nearest accessible corpse.
---   2. Navigate within 70 units and face it.
---   3. If sweep is off cooldown: primary fire to remove the body.
---   4. If sweep is on cooldown: secondary fire to wipe DNA.
---   5. Once cleaned, return to normal traitor behavior.

if not (TTT2 and ROLE_JANITOR) then return end

---@class BJanitorSweep
TTTBots.Behaviors.JanitorSweep = {}

local lib = TTTBots.Lib

---@class BJanitorSweep
local JSweep = TTTBots.Behaviors.JanitorSweep
JSweep.Name = "JanitorSweep"
JSweep.Description = "Sweep or wipe DNA from corpses after kills"
JSweep.Interruptible = true

local STATUS = TTTBots.STATUS

--- Range at which the broom can interact (from addon: 70 units).
local BROOM_RANGE = 70
--- Search radius for nearby corpses to clean.
local SEEK_RANGE = 1500
--- How long to wait between cleaning the same body (seconds).
local CLEAN_DELAY = 3

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Check if the sweep cooldown is active.
--- The addon uses timer "ttt2_jan_timer_cooldown".
---@return boolean
local function isSweepOnCooldown()
    return timer.Exists("ttt2_jan_timer_cooldown")
end

--- Find the nearest uncleaned corpse within seek range.
---@param bot Player
---@param cleanedSet table<Entity, boolean>
---@return Entity|nil
local function findNearestCorpse(bot, cleanedSet)
    local botPos = bot:GetPos()
    local best, bestDist = nil, SEEK_RANGE

    for _, ent in ipairs(ents.FindInSphere(botPos, SEEK_RANGE)) do
        if not IsValid(ent) then continue end
        if ent:GetClass() ~= "prop_ragdoll" then continue end
        if cleanedSet and cleanedSet[ent] then continue end

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

function JSweep.Validate(bot)
    if not IsValid(bot) then return false end
    if not ROLE_JANITOR then return false end
    if bot:GetSubRole() ~= ROLE_JANITOR then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Only clean if there's actually a corpse to clean
    local state = TTTBots.Behaviors.GetState(bot, "JanitorSweep")
    local cleaned = state.cleanedCorpses or {}
    return findNearestCorpse(bot, cleaned) ~= nil
end

function JSweep.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "JanitorSweep")
    if not state.cleanedCorpses then
        state.cleanedCorpses = {}
    end
    state.target = findNearestCorpse(bot, state.cleanedCorpses)

    -- Announce cleanup
    local chatter = bot:BotChatter()
    if chatter and chatter.On and math.random(1, 2) == 1 then
        chatter:On("JanitorSweeping", {}, true, 0)
    end

    return STATUS.RUNNING
end

function JSweep.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "JanitorSweep")
    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    -- Refresh target if invalid
    if not state.target or not IsValid(state.target) then
        state.target = findNearestCorpse(bot, state.cleanedCorpses)
        if not state.target then return STATUS.FAILURE end
    end

    local corpse = state.target
    local corpsePos = corpse:GetPos()
    local dist = bot:GetPos():Distance(corpsePos)

    -- Navigate toward corpse
    loco:SetGoal(corpsePos)
    loco:LookAt(corpsePos + Vector(0, 0, 30))

    if dist <= BROOM_RANGE and bot:VisibleVec(corpsePos) then
        -- Equip broom
        local broom = bot:GetWeapon("weapon_ttt2_jan_broom")
        if IsValid(broom) then
            bot:SetActiveWeapon(broom)
            inv:PauseAutoSwitch()
        end

        -- Check eye trace — must be looking at the corpse
        local eyeTrace = bot:GetEyeTrace()
        local hitEnt = eyeTrace and eyeTrace.Entity

        if hitEnt == corpse then
            if not isSweepOnCooldown() then
                -- Primary fire: sweep (remove) the body
                loco:StartAttack()
                timer.Simple(0.3, function()
                    if IsValid(bot) then loco:StopAttack() end
                end)
            else
                -- Secondary fire: wipe DNA
                loco:StartSecondaryAttack()
                timer.Simple(0.3, function()
                    if IsValid(bot) then loco:StopAttack() end
                end)
            end

            -- Mark as cleaned regardless (body removed or DNA wiped)
            state.cleanedCorpses[corpse] = true
            state.target = nil

            inv:ResumeAutoSwitch()
            return STATUS.SUCCESS
        end
    end

    return STATUS.RUNNING
end

function JSweep.OnSuccess(bot)
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end
end

function JSweep.OnFailure(bot)
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
end

function JSweep.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "JanitorSweep")
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end
end

-- ---------------------------------------------------------------------------
-- After a kill: trigger the Janitor to route back to the corpse.
-- The PlayerDeath hook notifies Janitor bots of new cleanable bodies.
-- ---------------------------------------------------------------------------
hook.Add("PostPlayerDeath", "TTTBots.JanitorSweep.KillNotify", function(victim)
    if not TTTBots.Match.IsRoundActive() then return end
    if not IsValid(victim) then return end

    -- Clear the victim from cleaned sets so the Janitor can target fresh corpses
    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and bot:IsBot()) then continue end
        if not ROLE_JANITOR then continue end
        if bot:GetSubRole() ~= ROLE_JANITOR then continue end

        local state = TTTBots.Behaviors.GetState(bot, "JanitorSweep")
        -- Don't clear the set — we find by proximity each time.
        -- Just ensure next Validate pass finds the new corpse.
    end
end)

-- Round reset
hook.Add("TTTBeginRound", "TTTBots.JanitorSweep.Reset", function()
    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not IsValid(bot) then continue end
        local state = TTTBots.Behaviors.GetState(bot, "JanitorSweep")
        if state then
            state.cleanedCorpses = {}
            state.target = nil
        end
    end
end)
