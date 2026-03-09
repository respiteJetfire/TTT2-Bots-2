--- zombieprotectmaster.lua
--- Zombie behavior: stay near the necromancer master.
--- If the zombie has no enemies in sight, it paths back toward its master
--- and stays within a comfortable escort distance. Adapted from protecthost.lua.

---@class BZombieProtectMaster
TTTBots.Behaviors.ZombieProtectMaster = {}

local lib = TTTBots.Lib

---@class BZombieProtectMaster
local Protect = TTTBots.Behaviors.ZombieProtectMaster
Protect.Name = "ZombieProtectMaster"
Protect.Description = "Stay near and protect the necromancer master."
Protect.Interruptible = true

local STATUS = TTTBots.STATUS

--- How far the zombie will stray from the master before pathing back.
local MAX_DISTANCE = 600
--- Ideal escort distance to hover around.
local IDEAL_DISTANCE = 200

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Check if the bot is a necromancer zombie (not the master).
---@param bot Bot
---@return boolean
local function isNecroZombie(bot)
    if not IsValid(bot) then return false end
    if TTTBots.Roles.IsNecroZombie then
        return TTTBots.Roles.IsNecroZombie(bot)
    end
    return ROLE_ZOMBIE and bot:GetSubRole() == ROLE_ZOMBIE
end

--- Get the master (necromancer) entity for this zombie.
---@param bot Bot
---@return Player?
local function getMaster(bot)
    -- First check the zombieMaster field set by AddZombie()
    if IsValid(bot.zombieMaster) then
        return bot.zombieMaster
    end

    -- Fallback: use the helper function if available
    if TTTBots.Roles.GetNecroMaster then
        return TTTBots.Roles.GetNecroMaster(bot)
    end

    -- Last resort: find a living necromancer on the same team
    if ROLE_NECROMANCER then
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:GetSubRole() == ROLE_NECROMANCER and lib.IsPlayerAlive(ply) then
                return ply
            end
        end
    end

    return nil
end

-- ---------------------------------------------------------------------------
-- Behavior interface
-- ---------------------------------------------------------------------------

function Protect.Validate(bot)
    if not IsValid(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Only zombies protect the master
    if not isNecroZombie(bot) then return false end

    -- Don't path to master if we're already fighting
    if bot.attackTarget ~= nil then return false end

    local master = getMaster(bot)
    if not IsValid(master) or not lib.IsPlayerAlive(master) then return false end

    -- Only activate when we've strayed too far
    local dist = bot:GetPos():Distance(master:GetPos())
    return dist > MAX_DISTANCE
end

function Protect.OnStart(bot)
    return STATUS.RUNNING
end

function Protect.OnRunning(bot)
    local master = getMaster(bot)
    if not IsValid(master) or not lib.IsPlayerAlive(master) then
        return STATUS.FAILURE
    end

    local dist = bot:GetPos():Distance(master:GetPos())
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    if dist <= IDEAL_DISTANCE then
        -- Close enough, stop and idle near master
        loco:SetGoal()
        return STATUS.SUCCESS
    end

    -- Path toward the master
    loco:SetGoal(master:GetPos())
    loco:LookAt(master:EyePos())

    return STATUS.RUNNING
end

function Protect.OnSuccess(bot)
end

function Protect.OnFailure(bot)
end

function Protect.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "ZombieProtectMaster")
end
