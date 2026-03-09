--- infectedrush.lua
--- Aggressive melee-only rush behavior for Infected Zombies.
--- Zombies have only weapon_ttt_inf_fists — they charge the nearest
--- non-allied player with no witness checks or phase gates.
--- This behavior sits in the zombie tree above ProtectHost and Patrol,
--- ensuring zombies always pursue the closest visible enemy.

---@class BInfectedRush
TTTBots.Behaviors.InfectedRush = {}

local lib = TTTBots.Lib

---@class BInfectedRush
local Rush = TTTBots.Behaviors.InfectedRush
Rush.Name = "InfectedRush"
Rush.Description = "Rush the closest enemy with fists (zombie melee charge)."
Rush.Interruptible = true

local STATUS = TTTBots.STATUS

--- The maximum distance (in units) at which we'll begin rushing a target.
local RUSH_RANGE = 2000
--- Within this distance we try to start attacking.
local MELEE_ENGAGE_RANGE = 100
--- How often (in ticks) to re-evaluate the best target.
local RETARGET_INTERVAL = 3

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

--- Find the closest visible non-allied player to rush.
---@param bot Bot
---@return Player?
---@return number distance
local function findRushTarget(bot)
    local nonAllies = TTTBots.Roles.GetNonAllies(bot)
    local bestTarget = nil
    local bestDist = math.huge

    for _, ply in ipairs(nonAllies) do
        if not IsValid(ply) then continue end
        if not lib.IsPlayerAlive(ply) then continue end

        local dist = bot:GetPos():Distance(ply:GetPos())
        if dist > RUSH_RANGE then continue end
        if dist < bestDist then
            bestDist = dist
            bestTarget = ply
        end
    end

    return bestTarget, bestDist
end

-- ---------------------------------------------------------------------------
-- Behavior interface
-- ---------------------------------------------------------------------------

function Rush.Validate(bot)
    if not IsValid(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Only for infected zombies
    if not isZombie(bot) then return false end

    -- Don't rush if we're already in a fight via AttackTarget
    if bot.attackTarget ~= nil then return false end

    -- Must have at least one reachable enemy
    local target = findRushTarget(bot)
    return target ~= nil
end

function Rush.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "InfectedRush")
    state.target = nil
    state.retargetTick = 0

    -- Make sure we're holding fists
    local inv = bot:BotInventory()
    if inv then
        local fists = bot:GetWeapon("weapon_ttt_inf_fists")
        if IsValid(fists) then
            bot:SelectWeapon("weapon_ttt_inf_fists")
        end
    end

    return STATUS.RUNNING
end

function Rush.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "InfectedRush")
    state.retargetTick = (state.retargetTick or 0) + 1

    -- Periodically re-evaluate target
    if not IsValid(state.target) or not lib.IsPlayerAlive(state.target) or (state.retargetTick % RETARGET_INTERVAL == 0) then
        local newTarget, dist = findRushTarget(bot)
        if not newTarget then return STATUS.FAILURE end
        state.target = newTarget
    end

    local target = state.target
    local targetPos = target:GetPos()
    local dist = bot:GetPos():Distance(targetPos)

    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    -- Always look at the target and move toward them
    loco:SetGoal(targetPos)
    loco:LookAt(target:EyePos())

    -- When close enough, request an attack through the morality system
    if dist <= MELEE_ENGAGE_RANGE then
        bot:SetAttackTarget(target, "INFECTED_RUSH", 4)
        return STATUS.SUCCESS
    end

    return STATUS.RUNNING
end

function Rush.OnSuccess(bot)
end

function Rush.OnFailure(bot)
end

function Rush.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "InfectedRush")
end
