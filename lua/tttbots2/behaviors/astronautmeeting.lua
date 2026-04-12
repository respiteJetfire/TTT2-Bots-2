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
---   7. If the bot fails to get its eye trace on the corpse after MAX_INTERACTION_ATTEMPTS,
---      force the meeting via the weapon's DoMeeting/Meet server-side function.

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
--- A cooldown interval before the bot re-evaluates after a meeting attempt.
local POST_MEETING_COOLDOWN = 35  -- seconds; slightly longer than the server meetingcool (~20s)
--- Maximum number of times the bot will attempt to aim at the corpse before forcing.
--- Each "attempt" is a full cycle of: getting in range → losing eye trace on the corpse.
local MAX_INTERACTION_ATTEMPTS = 3
--- Maximum time (seconds) the bot may spend trying to interact once in range before forcing.
--- Prevents indefinite loops when the bot is in range but can't get its trace on the ragdoll.
local MAX_INTERACTION_TIME = 10
--- Expanded range for approaching (walk a bit closer than the weapon requires for reliability).
local APPROACH_RANGE = 48

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

--- Attempt to get a good look-at position for a ragdoll by sampling physics bones.
--- Ragdolls have irregular collision meshes; looking at GetPos() + a fixed offset
--- often misses. This tries multiple bone positions to find one that's valid.
---@param bot Player
---@param corpse Entity
---@return Vector
local function getBestCorpseLookPos(bot, corpse)
    -- Try physics bones first (ragdolls have per-bone physics objects)
    local boneCount = corpse:GetPhysicsObjectCount()
    if boneCount and boneCount > 0 then
        -- Gather bone positions and pick the one closest to the bot's eye line
        local eyePos = bot:EyePos()
        local eyeDir = bot:EyeAngles():Forward()
        local bestPos = nil
        local bestDot = -1

        for i = 0, boneCount - 1 do
            local bone = corpse:GetPhysicsObjectNum(i)
            if IsValid(bone) then
                local bonePos = bone:GetPos()
                local toTarget = (bonePos - eyePos):GetNormalized()
                local dot = eyeDir:Dot(toTarget)
                if dot > bestDot then
                    bestDot = dot
                    bestPos = bonePos
                end
            end
        end

        if bestPos then return bestPos end
    end

    -- Fallback: try OBB center (accounts for model bounding box)
    local obbCenter = corpse:LocalToWorld(corpse:OBBCenter())
    if obbCenter then return obbCenter end

    -- Last resort: base position with a small Z offset
    return corpse:GetPos() + Vector(0, 0, 10)
end

--- Force the meeting server-side, bypassing the hold-fire interaction.
--- Used when the bot has failed to interact normally after MAX_INTERACTION_ATTEMPTS.
--- Calls weapon_ast_meeting's server-side functions directly.
---@param bot Player
---@param corpse Entity
---@return boolean success
local function forceMeeting(bot, corpse)
    local wep = bot:GetWeapon("weapon_ast_meeting")
    if not IsValid(wep) or not IsValid(corpse) then return false end

    -- Try the weapon's Meet() function (sets UsedPlayers + calls DoMeeting).
    -- Meet() expects wep.Target to be set to the corpse entity.
    if wep.Meet and wep.DoMeeting then
        wep.Target = corpse
        local ok, err = pcall(function() wep:Meet() end)
        if ok then
            print("[TTT Bots 2] Astronaut bot " .. tostring(bot:Nick())
                .. " force-called meeting on corpse (Meet bypassed hold-fire).")
            return true
        else
            -- Meet() failed — try DoMeeting() directly as last resort
            print("[TTT Bots 2] Astronaut bot " .. tostring(bot:Nick())
                .. " Meet() failed (" .. tostring(err) .. "), trying DoMeeting directly.")
            local ok2, err2 = pcall(function() wep:DoMeeting(corpse) end)
            if ok2 then
                print("[TTT Bots 2] Astronaut bot " .. tostring(bot:Nick())
                    .. " force-called meeting on corpse (DoMeeting direct).")
                return true
            else
                print("[TTT Bots 2] Astronaut bot " .. tostring(bot:Nick())
                    .. " DoMeeting also failed: " .. tostring(err2))
            end
        end
    elseif wep.DoMeeting then
        -- Only DoMeeting exists
        local ok, err = pcall(function() wep:DoMeeting(corpse) end)
        if ok then
            print("[TTT Bots 2] Astronaut bot " .. tostring(bot:Nick())
                .. " force-called meeting on corpse (DoMeeting only).")
            return true
        else
            print("[TTT Bots 2] Astronaut bot " .. tostring(bot:Nick())
                .. " DoMeeting failed: " .. tostring(err))
        end
    end

    return false
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
    state.interactionAttempts = 0    -- how many times we got in range but lost the trace
    state.inRangeStartTime = nil     -- when we first arrived in range of this corpse
    state.weaponEquipped = false     -- track if we've already equipped the weapon
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
        state.interactionAttempts = 0
        state.inRangeStartTime = nil
        state.weaponEquipped = false
    end

    local corpse   = state.target
    local corpsePos = corpse:GetPos()
    local lookPos  = getBestCorpseLookPos(bot, corpse)
    local dist     = bot:GetPos():Distance(corpsePos)

    -- Navigate toward the corpse — use tighter approach range for reliability
    loco:SetGoal(corpsePos)
    loco:LookAt(lookPos)

    -- Once in range, begin the interaction sequence
    if dist <= APPROACH_RANGE and bot:VisibleVec(corpsePos) then
        -- Record when we first got in range (for timeout tracking)
        if not state.inRangeStartTime then
            state.inRangeStartTime = CurTime()
        end

        -- Stop moving so we can aim precisely
        loco:StopMoving()

        -- Check if we've exceeded the interaction time or attempt limit → force meeting
        local timeInRange = CurTime() - state.inRangeStartTime
        if state.interactionAttempts >= MAX_INTERACTION_ATTEMPTS
            or timeInRange >= MAX_INTERACTION_TIME then
            -- Too many failed attempts or timed out — force the meeting server-side
            loco:StopAttack()
            state.holding = false
            state.holdStart = nil

            if forceMeeting(bot, corpse) then
                state.usedCorpses[corpse] = true
                state.target = nil
                state.interactionAttempts = 0
                state.inRangeStartTime = nil
                state.cooldownUntil = CurTime() + POST_MEETING_COOLDOWN
                inv:ResumeAutoSwitch()
                return STATUS.SUCCESS
            else
                -- Force also failed — mark corpse as used to avoid infinite retry
                print("[TTT Bots 2] Astronaut bot " .. tostring(bot:Nick())
                    .. " giving up on corpse after " .. state.interactionAttempts
                    .. " attempts and " .. string.format("%.1f", timeInRange) .. "s.")
                state.usedCorpses[corpse] = true
                state.target = nil
                state.interactionAttempts = 0
                state.inRangeStartTime = nil
                inv:ResumeAutoSwitch()
                return STATUS.FAILURE
            end
        end

        -- Equip Meeting Maker (use SelectWeapon with classname for proper deploy)
        local wep = bot:GetWeapon("weapon_ast_meeting")
        if IsValid(wep) then
            if bot:GetActiveWeapon() ~= wep then
                bot:SelectWeapon("weapon_ast_meeting")
                inv:PauseAutoSwitch()
                state.weaponEquipped = true
                -- Give one frame for the weapon to deploy before checking traces
                return STATUS.RUNNING
            end
        else
            return STATUS.FAILURE
        end

        -- Continuously update look position with best bone target
        loco:LookAt(lookPos, 0.5)

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
                if elapsed >= chargeTime + 0.5 then
                    -- Charge time exceeded with margin — meeting should have been called.
                    -- Release fire and impose cooldown.
                    loco:StopAttack()
                    state.usedCorpses[corpse] = true
                    state.target = nil
                    state.holding = false
                    state.holdStart = nil
                    state.interactionAttempts = 0
                    state.inRangeStartTime = nil
                    state.cooldownUntil = CurTime() + POST_MEETING_COOLDOWN
                    inv:ResumeAutoSwitch()
                    return STATUS.SUCCESS
                end
                -- Still holding — keep attack pressed
                loco:StartAttack()
            end
        else
            -- Eye trace missed the corpse — release fire and count this as a failed attempt
            if state.holding then
                loco:StopAttack()
                state.holding = false
                state.holdStart = nil
                state.interactionAttempts = (state.interactionAttempts or 0) + 1
            end

            -- Try to jiggle the look position slightly on retries for better coverage
            -- Offset varies per attempt to try different parts of the ragdoll
            local attempt = state.interactionAttempts or 0
            local jiggle = Vector(
                math.sin(CurTime() * 3 + attempt) * 8,
                math.cos(CurTime() * 3 + attempt) * 8,
                math.sin(CurTime() * 2) * 6
            )
            loco:LookAt(lookPos + jiggle, 0.3)
        end
    else
        -- Not in range yet — release fire if we were holding
        if state.holding then
            loco:StopAttack()
            state.holding = false
            state.holdStart = nil
        end
        -- Reset in-range timer since we're not in range
        state.inRangeStartTime = nil
    end

    return STATUS.RUNNING
end

function AMeet.OnSuccess(bot)
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
        state.interactionAttempts = 0
        state.inRangeStartTime = nil
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
        state.interactionAttempts = 0
        state.inRangeStartTime = nil
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
            state.interactionAttempts = 0
            state.inRangeStartTime = nil
            state.weaponEquipped = false
        end
    end
end)
