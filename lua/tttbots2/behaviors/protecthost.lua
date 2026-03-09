--- protecthost.lua
--- Zombie behavior: stay near the host infected player.
--- If the zombie has no enemies in sight, it paths back toward its host
--- and stays within a comfortable escort distance. This keeps the swarm
--- together and makes the host harder to pick off.

---@class BProtectHost
TTTBots.Behaviors.ProtectHost = {}

local lib = TTTBots.Lib

---@class BProtectHost
local Protect = TTTBots.Behaviors.ProtectHost
Protect.Name = "ProtectHost"
Protect.Description = "Stay near and protect the infected host."
Protect.Interruptible = true

local STATUS = TTTBots.STATUS

--- How far the zombie will stray from the host before pathing back.
local MAX_DISTANCE = 600
--- Ideal escort distance to hover around.
local IDEAL_DISTANCE = 200

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Check if the bot is an infected zombie (not the host).
---@param bot Bot
---@return boolean
local function isZombie(bot)
    if not IsValid(bot) then return false end
    return TTTBots.Roles.IsInfectedZombie and TTTBots.Roles.IsInfectedZombie(bot) or false
end

--- Get the host entity for this zombie.
---@param bot Bot
---@return Player?
local function getHost(bot)
    return TTTBots.Roles.GetInfectedHost and TTTBots.Roles.GetInfectedHost(bot) or nil
end

-- ---------------------------------------------------------------------------
-- Behavior interface
-- ---------------------------------------------------------------------------

function Protect.Validate(bot)
    if not IsValid(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Only zombies protect the host
    if not isZombie(bot) then return false end

    -- Don't path to host if we're already fighting
    if bot.attackTarget ~= nil then return false end

    local host = getHost(bot)
    if not IsValid(host) or not lib.IsPlayerAlive(host) then return false end

    -- Only activate when we've strayed too far
    local dist = bot:GetPos():Distance(host:GetPos())
    return dist > MAX_DISTANCE
end

function Protect.OnStart(bot)
    return STATUS.RUNNING
end

function Protect.OnRunning(bot)
    local host = getHost(bot)
    if not IsValid(host) or not lib.IsPlayerAlive(host) then
        return STATUS.FAILURE
    end

    local dist = bot:GetPos():Distance(host:GetPos())
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    if dist <= IDEAL_DISTANCE then
        -- Close enough, stop and idle near host
        loco:SetGoal()
        return STATUS.SUCCESS
    end

    -- Path toward the host
    loco:SetGoal(host:GetPos())
    loco:LookAt(host:EyePos())

    return STATUS.RUNNING
end

function Protect.OnSuccess(bot)
end

function Protect.OnFailure(bot)
end

function Protect.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "ProtectHost")
end
