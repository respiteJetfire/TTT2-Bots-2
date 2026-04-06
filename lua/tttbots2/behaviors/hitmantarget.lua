--- hitmantarget.lua
--- Dedicated focus-fire behavior for Hitman bots.
---
--- The Hitman is assigned a random contract target at round start that is NOT
--- on their team. Killing the target awards bonus credits; killing non-targets
--- (optionally) reveals the Hitman.
---
--- Bot strategy:
---   1. If the Hitman has a contract target (GetTargetPlayer()), prioritise it.
---   2. Play as a normal traitor otherwise — full traitor tree handles the rest.

if not (TTT2 and ROLE_HITMAN) then return end

---@class BHitmanTarget
TTTBots.Behaviors.HitmanTarget = {}

local lib = TTTBots.Lib

---@class BHitmanTarget
local HitmanTarget = TTTBots.Behaviors.HitmanTarget
HitmanTarget.Name = "HitmanTarget"
HitmanTarget.Description = "Focus-fire the Hitman's assigned contract target."
HitmanTarget.Interruptible = true

local STATUS = TTTBots.STATUS

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Returns the Hitman's current contract target via the addon API or NW entity.
---@param bot Player
---@return Player|nil
local function getContractTarget(bot)
    if not IsValid(bot) then return nil end

    -- Prefer the addon's own GetTargetPlayer() method added to the player meta
    if bot.GetTargetPlayer then
        local t = bot:GetTargetPlayer()
        if IsValid(t) and lib.IsPlayerAlive(t) then return t end
    end

    -- NW entity fallback (addon syncs "hit_target" to the hitman)
    local t = bot:GetNWEntity("hit_target", nil)
    if IsValid(t) and lib.IsPlayerAlive(t) then return t end

    return nil
end

-- ---------------------------------------------------------------------------
-- Behavior interface
-- ---------------------------------------------------------------------------

function HitmanTarget.Validate(bot)
    if not IsValid(bot) then return false end
    if not ROLE_HITMAN then return false end
    if bot:GetSubRole() ~= ROLE_HITMAN then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    local target = getContractTarget(bot)
    return target ~= nil
end

function HitmanTarget.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "HitmanTarget")
    state.lastChatterTime = 0
    return STATUS.RUNNING
end

function HitmanTarget.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "HitmanTarget")

    local target = getContractTarget(bot)
    if not (target and IsValid(target) and lib.IsPlayerAlive(target)) then
        -- No contract target — yield to normal traitor behaviour
        return STATUS.FAILURE
    end

    -- Assign the contract target as attack target with ROLE_HOSTILITY priority
    -- so it can still be overridden by self-defence.
    local PRI = TTTBots.Morality and TTTBots.Morality.PRIORITY
    local pri = PRI and PRI.ROLE_HOSTILITY or 3

    if not (bot.attackTarget and IsValid(bot.attackTarget) and bot.attackTarget == target) then
        local memory = bot.components and bot.components.memory
        if memory then
            memory:UpdateKnownPositionFor(target, target:GetPos())
        end
        bot:SetAttackTarget(target, "HITMAN_CONTRACT", pri)
    end

    -- Periodic chatter so team-mates know we are on the target
    if CurTime() - (state.lastChatterTime or 0) > 25 then
        state.lastChatterTime = CurTime()
        local chatter = bot:BotChatter()
        if chatter and chatter.On and math.random(1, 3) == 1 then
            chatter:On("HitmanOnTarget", { player = target:Nick(), playerEnt = target }, false)
        end
    end

    return STATUS.RUNNING
end

function HitmanTarget.OnSuccess(bot) end
function HitmanTarget.OnFailure(bot) end

function HitmanTarget.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "HitmanTarget")
end
