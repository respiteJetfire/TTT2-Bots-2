--- alibibuilding.lua
--- AlibiBuilding behavior — Traitor-only.
--- During the EARLY phase, the traitor actively stays near groups of innocents
--- to be "seen" by as many witnesses as possible, building a false alibi.

---@class BAlibiBuilding
TTTBots.Behaviors.AlibiBuilding = {}

local lib = TTTBots.Lib
---@class BAlibiBuilding
local AlibiBuilding = TTTBots.Behaviors.AlibiBuilding
AlibiBuilding.Name         = "AlibiBuilding"
AlibiBuilding.Description  = "Hang around innocents during the early round to build a false alibi."
AlibiBuilding.Interruptible = true

local STATUS = TTTBots.STATUS

-- How many seconds the bot waits before chattering about alibi activities
local CHATTER_COOLDOWN  = 45
-- Maximum distance from the group to be considered "near" them
local NEAR_DIST         = 350

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

--- Returns true when the alibi-building feature is enabled.
local function isEnabled()
    return TTTBots.Lib.GetConVarBool("deception_enabled")
end

--- True if bot is a traitor.
---@param bot Bot
local function isTraitor(bot)
    local role = TTTBots.Roles.GetRoleFor(bot)
    return role and role:GetTeam() == TEAM_TRAITOR
end

--- Return the closest group of non-allied players (i.e., innocents from the traitor's perspective).
--- We want the densest cluster to maximize "witnesses."
---@param bot Bot
---@return Player? target  The best player to loiter near
local function findGroupCenter(bot)
    local nonAllies = TTTBots.Roles.GetNonAllies(bot)
    if not nonAllies or #nonAllies == 0 then return nil end

    local best, bestScore = nil, -1
    for _, ply in ipairs(nonAllies) do
        if not lib.IsPlayerAlive(ply) then continue end
        -- Score = number of other players within 500 units of this player
        local pos = ply:GetPos()
        local nearCount = 0
        for _, other in ipairs(TTTBots.Match.AlivePlayers) do
            if other ~= bot and other ~= ply and pos:DistToSqr(other:GetPos()) < 500 * 500 then
                nearCount = nearCount + 1
            end
        end
        if nearCount > bestScore then
            bestScore = nearCount
            best = ply
        end
    end
    return best
end

---------------------------------------------------------------------------
-- Behavior Interface
---------------------------------------------------------------------------

function AlibiBuilding.Validate(bot)
    if not isEnabled() then return false end
    if not lib.IsPlayerAlive(bot) then return false end
    if not isTraitor(bot) then return false end
    if bot.attackTarget then return false end  -- don't loiter while in combat

    -- Only active in the EARLY phase
    local ra = bot:BotRoundAwareness()
    if not ra then return false end
    local PHASE = TTTBots.Components.RoundAwareness.PHASE
    if ra:GetPhase() ~= PHASE.EARLY then return false end

    -- Don't run if we already have a fresh alibi target set and we're close to them
    local state = TTTBots.Behaviors.GetState(bot, "AlibiBuilding")
    if state.target and IsValid(state.target) and
       bot:GetPos():DistToSqr(state.target:GetPos()) < NEAR_DIST * NEAR_DIST then
        return true  -- keep running
    end

    local target = findGroupCenter(bot)
    if not target then return false end
    state.target = target
    return true
end

function AlibiBuilding.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "AlibiBuilding")
    state.startTime    = CurTime()
    state.lastChatter  = 0
    return STATUS.RUNNING
end

function AlibiBuilding.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "AlibiBuilding")

    -- Refresh target periodically (every 8 s)
    if not state.target or not IsValid(state.target) or
       (CurTime() - (state.refreshTime or 0)) > 8 then
        state.target      = findGroupCenter(bot)
        state.refreshTime = CurTime()
    end

    if not state.target or not IsValid(state.target) then
        return STATUS.FAILURE
    end

    -- Re-validate phase
    local ra = bot:BotRoundAwareness()
    if ra then
        local PHASE = TTTBots.Components.RoundAwareness.PHASE
        if ra:GetPhase() ~= PHASE.EARLY then
            return STATUS.SUCCESS
        end
    end

    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    local targetPos = state.target:GetPos()
    local distSqr   = bot:GetPos():DistToSqr(targetPos)

    if distSqr > NEAR_DIST * NEAR_DIST then
        -- Walk toward the group
        loco:SetGoal(targetPos)
    else
        -- We're near the group — stop and look at them to be noticed
        loco:SetGoal(nil)
        loco:LookAt(state.target:EyePos())

        -- Occasional chatter to make our presence known
        local chatter = bot:BotChatter()
        if chatter and chatter.On and (CurTime() - (state.lastChatter or 0)) > CHATTER_COOLDOWN then
            chatter:On("AlibiBuilding", { player = state.target:Nick() }, false, 0)
            state.lastChatter = CurTime()
        end
    end

    return STATUS.RUNNING
end

function AlibiBuilding.OnSuccess(bot) end
function AlibiBuilding.OnFailure(bot) end

function AlibiBuilding.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "AlibiBuilding")
end
