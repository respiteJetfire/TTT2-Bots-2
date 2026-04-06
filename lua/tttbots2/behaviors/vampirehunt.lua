--- vampirehunt.lua
--- Urgency-based hunting behavior for Vampire bots.
---
--- The Vampire MUST kill at least once every ttt2_vamp_bloodtime seconds.
--- As that timer approaches expiry (and especially once Bloodlust is active),
--- the bot escalates from passive traitor play to aggressive immediate hunting.
---
--- Urgency levels:
---   0.0–0.4  CALM:      Normal traitor behavior — no special urgency.
---   0.4–0.7  UNEASY:    Increase patrol speed; prefer targets over deception.
---   0.7–0.9  URGENT:    Actively seek and attack the nearest enemy now.
---   0.9–1.0  DESPERATE: BLOODLUST active — sprint at nearest target immediately.

if not (TTT2 and ROLE_VAMPIRE) then return end

---@class BVampireHunt
TTTBots.Behaviors.VampireHunt = {}

local lib = TTTBots.Lib

---@class BVampireHunt
local VHunt = TTTBots.Behaviors.VampireHunt
VHunt.Name = "VampireHunt"
VHunt.Description = "Urgency-based hunt for the Vampire's bloodlust timer"
VHunt.Interruptible = true

local STATUS = TTTBots.STATUS

--- Full bloodlust timer duration (seconds). Matches ttt2_vamp_bloodtime default.
local BLOOD_TIMER = 60

-- ---------------------------------------------------------------------------
-- Urgency helpers
-- ---------------------------------------------------------------------------

---@param bot Player
---@return number urgency 0..1
local function getUrgency(bot)
    if TTTBots.Vampire_IsInBloodlust and TTTBots.Vampire_IsInBloodlust(bot) then
        return 1.0 -- Full urgency during bloodlust
    end
    local cvar = GetConVar("ttt2_vamp_bloodtime")
    local total = cvar and cvar:GetInt() or BLOOD_TIMER
    if total <= 0 then return 0 end
    local secsLeft = TTTBots.Vampire_SecsUntilBloodlust and TTTBots.Vampire_SecsUntilBloodlust(bot) or total
    return math.Clamp(1 - (secsLeft / total), 0, 1)
end

--- Find the nearest enemy target for the bot.
---@param bot Player
---@return Player|nil
local function findNearestEnemy(bot)
    local botPos = bot:GetPos()
    local best, bestDist = nil, math.huge

    for _, ply in ipairs(TTTBots.Match.AlivePlayers or {}) do
        if not IsValid(ply) then continue end
        if ply == bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then continue end

        -- Skip exempt jester-team roles that vampires shouldn't care about
        local role = ply.GetRoleStringRaw and ply:GetRoleStringRaw() or ""
        if role == "jester" or role == "swapper" or role == "marker" then continue end

        local dist = botPos:Distance(ply:GetPos())
        if dist < bestDist then
            bestDist = dist
            best = ply
        end
    end

    return best
end

-- ---------------------------------------------------------------------------
-- Behavior interface
-- ---------------------------------------------------------------------------

function VHunt.Validate(bot)
    if not IsValid(bot) then return false end
    if not ROLE_VAMPIRE then return false end
    if bot:GetSubRole() ~= ROLE_VAMPIRE then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    local urgency = getUrgency(bot)
    -- Only activate at UNEASY+ urgency (0.4+)
    return urgency >= 0.4
end

function VHunt.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "VampireHunt")
    state.lastChatterTime = 0
    state.lastTargetRefresh = 0
    return STATUS.RUNNING
end

function VHunt.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "VampireHunt")
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    local urgency = getUrgency(bot)

    -- Below the activation threshold, stop
    if urgency < 0.35 then
        return STATUS.FAILURE
    end

    local inBloodlust = TTTBots.Vampire_IsInBloodlust and TTTBots.Vampire_IsInBloodlust(bot)

    -- Bloodlust chatter
    if inBloodlust and CurTime() - (state.lastChatterTime or 0) > 20 then
        state.lastChatterTime = CurTime()
        local chatter = bot:BotChatter()
        if chatter and chatter.On and math.random(1, 3) == 1 then
            chatter:On("VampireBloodlust", {}, false)
        end
    end

    -- Refresh target periodically or if missing
    if not bot.attackTarget or CurTime() - (state.lastTargetRefresh or 0) > 5 then
        state.lastTargetRefresh = CurTime()
        local target = findNearestEnemy(bot)
        if target then
            local memory = bot.components and bot.components.memory
            if memory then
                memory:UpdateKnownPositionFor(target, target:GetPos())
            end
            -- In bloodlust, use self-defense priority so it won't be easily overridden
            local PRI = TTTBots.Morality and TTTBots.Morality.PRIORITY
            local pri = inBloodlust and (PRI and PRI.SELF_DEFENSE or 5)
                or (PRI and PRI.ROLE_HOSTILITY or 3)
            bot:SetAttackTarget(target, "VAMPIRE_HUNT", pri)
        end
    end

    -- In bloodlust: force sprint toward target
    if inBloodlust and bot.attackTarget and IsValid(bot.attackTarget) then
        loco:SetGoal(bot.attackTarget:GetPos())
    end

    return STATUS.RUNNING
end

function VHunt.OnSuccess(bot)
end

function VHunt.OnFailure(bot)
end

function VHunt.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "VampireHunt")
end

-- ---------------------------------------------------------------------------
-- On kill: note that bloodlust timer was reset by the addon server-side.
-- No extra action needed; VHunt will drop back below urgency threshold.
-- ---------------------------------------------------------------------------
