--- protectlover.lua
--- Post-link Cupid/Lover behavior: stay near the lover partner.
---
--- When lovers are linked via the Cupid system, they share death — if one dies,
--- the other follows 5 seconds later. This makes protecting your lover partner
--- an act of self-preservation. This behavior:
---   - Follows the lover partner, staying within escort distance
---   - Reacts to attacks on the lover via PlayerHurt hook (like Bodyguard)
---   - Coordinates combat to prioritize threats near the lover
---
--- Similar in structure to protecthost.lua (Infected zombie → host escort).

if not (TTT2 and ROLE_CUPID) then return end

---@class BProtectLover : BBase
TTTBots.Behaviors.ProtectLover = {}

local lib = TTTBots.Lib

---@class BProtectLover
local Protect = TTTBots.Behaviors.ProtectLover
Protect.Name = "ProtectLover"
Protect.Description = "Stay near and protect the lover partner (shared death = self-preservation)."
Protect.Interruptible = true

local STATUS = TTTBots.STATUS

--- How far the bot will stray before pathing back to the lover.
local MAX_DISTANCE = 500
--- Ideal escort distance to hover around.
local IDEAL_DISTANCE = 200
--- How often to fire team coordination chatter (seconds).
local COORD_CHAT_INTERVAL = 45

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Get the lover partner for a given bot.
---@param bot Player
---@return Player?
local function getLoverPartner(bot)
    return TTTBots.Roles.GetCupidLover and TTTBots.Roles.GetCupidLover(bot) or nil
end

--- Check if the bot is currently a lover (linked).
---@param bot Player
---@return boolean
local function isLover(bot)
    if not IsValid(bot) then return false end
    return bot.inLove == true
end

-- ---------------------------------------------------------------------------
-- Behavior interface
-- ---------------------------------------------------------------------------

function Protect.Validate(bot)
    if not IsValid(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Only for bots who are lovers
    if not isLover(bot) then return false end

    -- Don't path to lover if we're already fighting
    if bot.attackTarget ~= nil then return false end

    local lover = getLoverPartner(bot)
    if not IsValid(lover) or not lib.IsPlayerAlive(lover) then return false end

    -- Only activate when we've strayed too far
    local dist = bot:GetPos():Distance(lover:GetPos())
    return dist > MAX_DISTANCE
end

function Protect.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ProtectLover")
    state.lastCoordChat = 0
    return STATUS.RUNNING
end

function Protect.OnRunning(bot)
    local lover = getLoverPartner(bot)
    if not IsValid(lover) or not lib.IsPlayerAlive(lover) then
        return STATUS.FAILURE
    end

    local dist = bot:GetPos():Distance(lover:GetPos())
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    -- Periodic team coordination chatter
    local state = TTTBots.Behaviors.GetState(bot, "ProtectLover")
    if CurTime() - (state.lastCoordChat or 0) > COORD_CHAT_INTERVAL then
        state.lastCoordChat = CurTime()
        local chatter = bot:BotChatter()
        if chatter then
            chatter:On("CupidTeamCoordinate", { player = lover:Nick() }, true)
        end
    end

    if dist <= IDEAL_DISTANCE then
        -- Close enough, stop and idle near lover
        loco:SetGoal()
        return STATUS.SUCCESS
    end

    -- Path toward the lover
    loco:SetGoal(lover:GetPos())
    loco:LookAt(lover:EyePos())

    return STATUS.RUNNING
end

function Protect.OnSuccess(bot)
end

function Protect.OnFailure(bot)
end

function Protect.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "ProtectLover")
    local loco = bot:BotLocomotor()
    if loco then
        loco:EnableAvoid()
    end
end

-- ---------------------------------------------------------------------------
-- PlayerHurt hook — lover bots defend each other (like Bodyguard)
-- ---------------------------------------------------------------------------

local function fullValidatePlayer(player)
    return player and IsValid(player) and player:IsPlayer() and lib.IsPlayerAlive(player)
end

hook.Add("PlayerHurt", "TTTBots.ProtectLover.PlayerHurt", function(victim, attacker)
    if not TTTBots.Match.IsRoundActive() then return end
    if not fullValidatePlayer(victim) then return end
    if not fullValidatePlayer(attacker) then return end
    if not victim.inLove then return end

    -- Find lover bots who should defend the victim
    local lover = TTTBots.Roles.GetCupidLover and TTTBots.Roles.GetCupidLover(victim)
    if not lover then return end
    if not (IsValid(lover) and lover:IsBot() and lib.IsPlayerAlive(lover)) then return end

    -- Don't set attack target if they already have one
    if lover.attackTarget then return end

    -- Set the attacker as the lover bot's attack target
    lover:SetAttackTarget(attacker, "LOVER_DEFEND", 4)
    local mem = lover:BotMemory()
    if mem then
        mem:UpdateKnownPositionFor(attacker, attacker:GetPos())
    end

    -- Panic chatter
    local chatter = lover:BotChatter()
    if chatter then
        chatter:On("CupidLoverPanic", {
            player = victim:Nick(),
            attacker = attacker:Nick(),
        }, false, 0)
    end
end)
