--- astronautmeeting.lua
--- Behavior for Astronaut bots: approach a corpse and hold primary fire to call a meeting.
---
--- The Astronaut's Meeting Maker weapon (weapon_ast_meeting):
---   • PRIMARY FIRE (held): hold on a ragdoll within 64 units for `ttt_astronaut_meeting_charge_time`
---     seconds to call a community vote to kill one living player.
---   • Each corpse can only be used to start one meeting (tracked in UsedPlayers server-side).
---   • After a meeting is called, a ~20s cooldown (`meetingcool`) applies before the next.
---   • Meeting charges: each meeting costs `ttt_astronaut_meeting_chargeuse` charges (default 3).
---     The weapon starts with `ttt_astronaut_meeting_charges` total charges (default 6).
---   • Non-traitor kills earn 1 extra meeting charge via the PlayerDeath hook.
---
--- Bot strategy:
---   1. After any player dies, look for an unused corpse (ragdoll) within range.
---   2. Navigate to within 64 units of the corpse.
---   3. Equip weapon_ast_meeting and face the corpse.
---   4. Hold primary fire for the charge time to call the meeting.
---   5. After a successful meeting, back off and return to detective behavior.
---   6. Skip if: no charges left, meeting already in progress, on cooldown.

if not (TTT2 and ROLE_ASTRONAUT) then return end

---@class BAstronautMeeting
TTTBots.Behaviors.AstronautMeeting = {}

local lib = TTTBots.Lib

---@class BAstronautMeeting
local AMeet = TTTBots.Behaviors.AstronautMeeting
AMeet.Name = "AstronautMeeting"
AMeet.Description = "Approach a corpse and call a community vote meeting"
AMeet.Interruptible = true

local STATUS = TTTBots.STATUS

--- Range at which the Meeting Maker can target a corpse (from addon source: 64 units).
local MEETING_RANGE = 64
--- How long the bot holds primary fire (read from GlobalInt; fall back to default of 2s).
local DEFAULT_CHARGE_TIME = 2
--- Corpse search radius — no hard limit in the addon, but keep it sane.
local SEEK_RANGE = 2000
--- Track which corpses the bot has already used for meetings (per-bot state).
--- A cooldown interval before the bot re-evaluates after a meeting attempt.
local POST_MEETING_COOLDOWN = 35  -- seconds; slightly longer than the server meetingcool (~20s)

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Get the current meeting charge time (from the server GlobalInt the addon sets).
---@return number
local function getMeetingChargeTime()
    local gv = GetGlobalInt("ttt_astronaut_meeting_charge_time", DEFAULT_CHARGE_TIME)
    return math.max(1, gv)
end

--- Check if the weapon has enough charges and a meeting is not already running.
--- We rely on ammo count; we cannot directly inspect the server-side `meetingprog` or
--- `meetingcool` flags, so we use a post-meeting timer to self-impose the cooldown.
---@param bot Player
---@return boolean
local function canCallMeeting(bot)
    local wep = bot:GetWeapon("weapon_ast_meeting")
    if not IsValid(wep) then return false end

    -- Need at least ttt_astronaut_meeting_chargeuse ammo in clip
    local chargeUse = math.max(1, GetConVar("ttt_astronaut_meeting_chargeuse") and
        GetConVar("ttt_astronaut_meeting_chargeuse"):GetInt() or 3)
    if wep:Clip1() < chargeUse then return false end

    return true
end

--- Find the nearest corpse (ragdoll) the bot has not yet used for a meeting.
---@param bot Player
---@param usedCorpses table<Entity, boolean>
---@return Entity|nil
local function findNearestUnusedCorpse(bot, usedCorpses)
    local botPos = bot:GetPos()
    local best, bestDist = nil, SEEK_RANGE

    for _, ent in ipairs(ents.FindInSphere(botPos, SEEK_RANGE)) do
        if not IsValid(ent) then continue end
        if ent:GetClass() ~= "prop_ragdoll" then continue end
        if usedCorpses and usedCorpses[ent] then continue end

        -- Verify this is a player corpse (has a player nick bound to it)
        if CORPSE and CORPSE.GetPlayerNick then
            if CORPSE.GetPlayerNick(ent, false) == false then continue end
        end

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

function AMeet.Validate(bot)
    if not IsValid(bot) then return false end
    if not ROLE_ASTRONAUT then return false end
    if bot:GetSubRole() ~= ROLE_ASTRONAUT then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    local state = TTTBots.Behaviors.GetState(bot, "AstronautMeeting")

    -- Self-imposed post-meeting cooldown (the server imposes ~20s; we wait a bit longer
    -- to avoid spamming attempts while the server cooldown is still active).
    if state.cooldownUntil and CurTime() < state.cooldownUntil then return false end

    -- Must have enough charges in the weapon
    if not canCallMeeting(bot) then return false end

    -- Must have an unused corpse in range
    local used = state.usedCorpses or {}
    return findNearestUnusedCorpse(bot, used) ~= nil
end

function AMeet.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "AstronautMeeting")
    if not state.usedCorpses then
        state.usedCorpses = {}
    end
    state.target = findNearestUnusedCorpse(bot, state.usedCorpses)
    state.holdStart = nil
    state.holding = false
    return STATUS.RUNNING
end

function AMeet.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "AstronautMeeting")
    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    -- Still on cooldown? (re-checked here in case Validate wasn't called this tick)
    if state.cooldownUntil and CurTime() < state.cooldownUntil then
        return STATUS.FAILURE
    end

    -- Re-check charge availability
    if not canCallMeeting(bot) then return STATUS.FAILURE end

    -- Refresh target if it was removed
    if not state.target or not IsValid(state.target) then
        state.target = findNearestUnusedCorpse(bot, state.usedCorpses)
        if not state.target then return STATUS.FAILURE end
        state.holdStart = nil
        state.holding = false
    end

    local corpse   = state.target
    local corpsePos = corpse:GetPos()
    local lookPos  = corpsePos + Vector(0, 0, 20)
    local dist     = bot:GetPos():Distance(corpsePos)

    -- Navigate toward the corpse
    loco:SetGoal(corpsePos)
    loco:LookAt(lookPos)

    -- Once in range and looking at it, equip the megaphone and hold fire
    if dist <= MEETING_RANGE and bot:VisibleVec(corpsePos) then
        -- Equip Meeting Maker
        local wep = bot:GetWeapon("weapon_ast_meeting")
        if IsValid(wep) and bot:GetActiveWeapon() ~= wep then
            bot:SetActiveWeapon(wep)
            inv:PauseAutoSwitch()
        end

        -- Verify eye trace is on the corpse
        local eyeTrace = bot:GetEyeTrace()
        local hitEnt   = eyeTrace and eyeTrace.Entity

        if hitEnt == corpse then
            local chargeTime = getMeetingChargeTime()

            if not state.holding then
                -- Begin holding primary fire
                loco:StartAttack()
                state.holdStart = CurTime()
                state.holding = true
            else
                -- Check if we've held long enough
                local elapsed = CurTime() - (state.holdStart or CurTime())
                if elapsed >= chargeTime then
                    -- Meeting called! Release fire and impose cooldown.
                    loco:StopAttack()
                    state.usedCorpses[corpse] = true
                    state.target = nil
                    state.holding = false
                    state.holdStart = nil
                    state.cooldownUntil = CurTime() + POST_MEETING_COOLDOWN
                    inv:ResumeAutoSwitch()
                    return STATUS.SUCCESS
                end
                -- Still holding — keep attack pressed
                loco:StartAttack()
            end
        else
            -- Lost sight / aim — release and retry next tick
            if state.holding then
                loco:StopAttack()
                state.holding = false
                state.holdStart = nil
            end
        end
    else
        -- Not in range yet — release fire if we were holding (don't initiate early)
        if state.holding then
            loco:StopAttack()
            state.holding = false
            state.holdStart = nil
        end
    end

    return STATUS.RUNNING
end

function AMeet.OnSuccess(bot)
    local state = TTTBots.Behaviors.GetState(bot, "AstronautMeeting")
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end
    -- Keep usedCorpses so we don't re-attempt the same body after the cooldown
end

function AMeet.OnFailure(bot)
    local state = TTTBots.Behaviors.GetState(bot, "AstronautMeeting")
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end
    if state then
        state.holding = false
        state.holdStart = nil
    end
end

function AMeet.OnEnd(bot)
    local state = TTTBots.Behaviors.GetState(bot, "AstronautMeeting")
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end
    -- Preserve usedCorpses and cooldownUntil across tree runs; only clear target/hold state.
    if state then
        state.target  = nil
        state.holding = false
        state.holdStart = nil
    end
end

-- ---------------------------------------------------------------------------
-- Round reset: clear used-corpse tracking and cooldowns at round start.
-- ---------------------------------------------------------------------------
hook.Add("TTTBeginRound", "TTTBots.AstronautMeeting.Reset", function()
    for _, bot in ipairs(player.GetBots()) do
        if not IsValid(bot) then continue end
        if not ROLE_ASTRONAUT then continue end
        if bot:GetSubRole() ~= ROLE_ASTRONAUT then continue end

        local state = TTTBots.Behaviors.GetState(bot, "AstronautMeeting")
        if state then
            state.usedCorpses  = {}
            state.target       = nil
            state.holding      = false
            state.holdStart    = nil
            state.cooldownUntil = nil
        end
    end
end)
