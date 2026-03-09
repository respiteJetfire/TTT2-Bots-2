--- plausibleignorance.lua
--- PlausibleIgnorance behavior — Traitor-only.
--- When the traitor's suspicion spikes because they are near a fresh kill,
--- they fire an excuse into chat ("I just got here, I heard shots...") to
--- deflect attention before DefendSelf is needed.

---@class BPlausibleIgnorance
TTTBots.Behaviors.PlausibleIgnorance = {}

local lib = TTTBots.Lib
---@class BPlausibleIgnorance
local PlausibleIgnorance = TTTBots.Behaviors.PlausibleIgnorance
PlausibleIgnorance.Name         = "PlausibleIgnorance"
PlausibleIgnorance.Description  = "Excuse your presence near a fresh kill with a plausible story."
PlausibleIgnorance.Interruptible = true

local STATUS = TTTBots.STATUS

-- How close to a danger zone (recent kill) we must be to trigger
local DANGER_PROXIMITY = 450
-- Cooldown between excuses
local EXCUSE_COOLDOWN  = 30
-- Minimum time after the kill before we bother excusing (don't be first to say something)
local KILL_EXCUSE_DELAY = 4

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function isEnabled()
    return TTTBots.Lib.GetConVarBool("deception_enabled")
end

--- True if bot is a deceptive hostile role — starts fights but isn't publicly known.
---@param bot Bot
local function isDeceptiveHostile(bot)
    local role = TTTBots.Roles.GetRoleFor(bot)
    if not role then return false end
    local startsFights = role:GetStartsFights()
    local isKOSedByAll = role.GetKOSedByAll and role:GetKOSedByAll()
    return startsFights and not isKOSedByAll
end

--- Returns true if there is a non-allied player within witnessing range.
---@param bot Bot
---@return boolean
local function hasWitnesses(bot)
    local witnesses = lib.GetAllWitnessesBasic(bot:GetPos(), TTTBots.Roles.GetNonAllies(bot), bot)
    return witnesses and #witnesses > 0
end

--- True if the bot is currently near a danger zone they are responsible for (i.e., they made the kill)
---@param bot Bot
---@return boolean, Vector? killPos
local function isNearOwnKillZone(bot)
    local memory = bot:BotMemory()
    if not memory then return false, nil end
    local dangerZones = memory.dangerZones
    if not dangerZones then return false, nil end

    -- Check our own recent kills recorded in bot.lastKillPos
    local killPos = bot.lastKillPos
    if not killPos then return false, nil end
    local dist = bot:GetPos():Distance(killPos)
    if dist < DANGER_PROXIMITY then
        return true, killPos
    end
    return false, nil
end

---------------------------------------------------------------------------
-- Behavior Interface
---------------------------------------------------------------------------

function PlausibleIgnorance.Validate(bot)
    if not isEnabled() then return false end
    if not lib.IsPlayerAlive(bot) then return false end
    if not isDeceptiveHostile(bot) then return false end
    if bot.attackTarget then return false end

    -- Cooldown check
    if (CurTime() - (bot.lastExcuseTime or 0)) < EXCUSE_COOLDOWN then return false end

    -- Must be near our own kill zone
    local near, killPos = isNearOwnKillZone(bot)
    if not near then return false end

    -- Must have witnesses to make the excuse worthwhile
    if not hasWitnesses(bot) then return false end

    -- Delay: don't excuse immediately, let witnesses see us first
    local timeSinceKill = CurTime() - (bot.lastKillTime or 0)
    if timeSinceKill < KILL_EXCUSE_DELAY then return false end

    -- 50% chance per validation to keep behavior less predictable
    if not lib.TestPercent(50) then return false end

    local state = TTTBots.Behaviors.GetState(bot, "PlausibleIgnorance")
    state.killPos = killPos
    return true
end

function PlausibleIgnorance.OnStart(bot)
    local state   = TTTBots.Behaviors.GetState(bot, "PlausibleIgnorance")
    local chatter = bot:BotChatter()

    bot.lastExcuseTime = CurTime()

    if chatter and chatter.On then
        -- Optional: look toward witnesses to sell the performance
        local witnesses = lib.GetAllWitnessesBasic(bot:GetPos(), TTTBots.Roles.GetNonAllies(bot), bot)
        local target = witnesses and #witnesses > 0 and witnesses[1]
        if IsValid(target) then
            local loco = bot:BotLocomotor()
            if loco then loco:LookAt(target:EyePos()) end
        end

        chatter:On("PlausibleIgnorance", {}, false, 0)
    end

    return STATUS.SUCCESS  -- one-shot behavior
end

function PlausibleIgnorance.OnRunning(bot)  return STATUS.SUCCESS end
function PlausibleIgnorance.OnSuccess(bot) end
function PlausibleIgnorance.OnFailure(bot) end

function PlausibleIgnorance.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "PlausibleIgnorance")
end

---------------------------------------------------------------------------
-- Hook: record last kill position on kill so we can check proximity
---------------------------------------------------------------------------

hook.Add("PlayerDeath", "TTTBots.PlausibleIgnorance.RecordKillPos", function(victim, weapon, attacker)
    if not (IsValid(attacker) and attacker:IsPlayer() and attacker:IsBot()) then return end
    attacker.lastKillPos = IsValid(victim) and victim:GetPos() or nil
end)
