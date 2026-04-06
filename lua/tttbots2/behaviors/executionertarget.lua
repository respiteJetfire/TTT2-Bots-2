--- executionertarget.lua
--- Dedicated focus-fire behavior for Executioner bots.
---
--- The Executioner's contract assigns a single target that receives 2× damage.
--- Attacking non-target enemies (excluding exempt roles) breaks the contract
--- and halves damage for 60 seconds.
---
--- Bot strategy:
---   1. If a contract target exists and is alive, always attack that target.
---   2. Suppress attacks on non-target enemies (only self-defense allowed).
---   3. During punishment period (no target / contract broken), play defensively.

if not (TTT2 and ROLE_EXECUTIONER) then return end

---@class BExecutionerTarget
TTTBots.Behaviors.ExecutionerTarget = {}

local lib = TTTBots.Lib

---@class BExecutionerTarget
local ExecTarget = TTTBots.Behaviors.ExecutionerTarget
ExecTarget.Name = "ExecutionerTarget"
ExecTarget.Description = "Focus-fire the Executioner's contract target"
ExecTarget.Interruptible = true

local STATUS = TTTBots.STATUS

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Roles that are exempt from the contract (attacking them is safe).
--- Matches the Executioner addon's excluded roles.
local EXEMPT_ROLES = {
    jester = true, swapper = true, cursed = true, amnesiac = true,
    clown = true, drunk = true, marker = true, beggar = true, medic = true,
}

---@param target Player
---@return boolean
local function isExemptRole(target)
    if not IsValid(target) then return false end
    local r = target.GetRoleStringRaw and target:GetRoleStringRaw() or ""
    return EXEMPT_ROLES[r] == true
end

--- Get the contract target for this Executioner bot.
---@param bot Player
---@return Player|nil
local function getContractTarget(bot)
    if TTTBots.Executioner_GetTarget then
        return TTTBots.Executioner_GetTarget(bot)
    end
    return nil
end

--- Returns true if the bot should not initiate attacks (punishment period).
---@param bot Player
---@return boolean
local function isPunished(bot)
    if TTTBots.Executioner_IsPunished then
        return TTTBots.Executioner_IsPunished(bot)
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Behavior interface
-- ---------------------------------------------------------------------------

function ExecTarget.Validate(bot)
    if not IsValid(bot) then return false end
    if not ROLE_EXECUTIONER then return false end
    if bot:GetSubRole() ~= ROLE_EXECUTIONER then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Always validate if there's a live contract target
    local target = getContractTarget(bot)
    if target and IsValid(target) and lib.IsPlayerAlive(target) then
        return true
    end

    -- Also validate during punishment so we can suppress incorrect targeting
    if isPunished(bot) then
        return true
    end

    return false
end

function ExecTarget.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ExecutionerTarget")
    state.lastChatterTime = 0
    return STATUS.RUNNING
end

function ExecTarget.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ExecutionerTarget")
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    local target = getContractTarget(bot)
    local punished = isPunished(bot)

    -- ── Punishment period ──────────────────────────────────────────────────
    -- During punishment, clear any non-self-defense attack target.
    -- The bot will still fight back if shot at (FightBack priority handles that),
    -- but we prevent proactive targeting of non-contract players.
    if punished or not (target and IsValid(target) and lib.IsPlayerAlive(target)) then
        local pri = bot.attackTargetPriority or 0
        local SELF_DEF = TTTBots.Morality and TTTBots.Morality.PRIORITY
            and TTTBots.Morality.PRIORITY.SELF_DEFENSE or 5
        if bot.attackTarget and pri < SELF_DEF then
            local curTarget = bot.attackTarget
            -- If the current attack target is not the contract target and not exempt, clear it
            if IsValid(curTarget) and curTarget ~= target and not isExemptRole(curTarget) then
                bot:SetAttackTarget(nil, "EXECUTIONER_SUPPRESSED")
            end
        end
        -- Occasional chatter about punishment state
        if punished and CurTime() - (state.lastChatterTime or 0) > 30 then
            state.lastChatterTime = CurTime()
            local chatter = bot:BotChatter()
            if chatter and chatter.On then
                chatter:On("ExecutionerPunished", {}, false)
            end
        end
        return STATUS.RUNNING
    end

    -- ── Active contract ────────────────────────────────────────────────────
    -- If the bot doesn't already have the contract target as their attack target,
    -- assign it with high priority.
    if not (bot.attackTarget and IsValid(bot.attackTarget) and bot.attackTarget == target) then
        local memory = bot.components and bot.components.memory
        if memory then
            memory:UpdateKnownPositionFor(target, target:GetPos())
        end
        -- Use ROLE_HOSTILITY priority (3) so it can be overridden by self-defense
        local PRI = TTTBots.Morality and TTTBots.Morality.PRIORITY
        local pri = PRI and PRI.ROLE_HOSTILITY or 3
        bot:SetAttackTarget(target, "EXECUTIONER_CONTRACT", pri)
    end

    -- Periodic "targeting" chatter
    if IsValid(target) and CurTime() - (state.lastChatterTime or 0) > 20 then
        state.lastChatterTime = CurTime()
        local chatter = bot:BotChatter()
        if chatter and chatter.On and math.random(1, 3) == 1 then
            chatter:On("ExecutionerContractTarget", {
                player = target:Nick(), playerEnt = target
            }, false)
        end
    end

    return STATUS.RUNNING
end

function ExecTarget.OnSuccess(bot)
end

function ExecTarget.OnFailure(bot)
end

function ExecTarget.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "ExecutionerTarget")
end

-- ---------------------------------------------------------------------------
-- Contract target updated hook: immediately redirect attack target when
-- the addon assigns a fresh contract target.
-- ---------------------------------------------------------------------------
hook.Add("TTTBots.Executioner.ContractAssigned", "TTTBots.ExecutionerTarget.Redirect",
    function(executionerBot, newTarget)
        if not (IsValid(executionerBot) and executionerBot:IsBot()) then return end
        if not (IsValid(newTarget) and lib.IsPlayerAlive(newTarget)) then return end
        local memory = executionerBot.components and executionerBot.components.memory
        if memory then
            memory:UpdateKnownPositionFor(newTarget, newTarget:GetPos())
        end
        local PRI = TTTBots.Morality and TTTBots.Morality.PRIORITY
        local pri = PRI and PRI.ROLE_HOSTILITY or 3
        executionerBot:SetAttackTarget(newTarget, "EXECUTIONER_CONTRACT", pri)
    end
)
