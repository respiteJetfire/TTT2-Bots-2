--- doomguyhunt.lua
--- Doomguy-specific active hunt behavior.
--- The Doom Slayer actively seeks out visible, wounded, or isolated non-ally targets
--- and closes distance to engage with the super shotgun.
--- Priorities:
---   1. Wounded targets (health < 70) within LOS — pursue immediately.
---   2. Isolated targets (no nearby allies) that are visible.
---   3. Fallback: closest reachable non-ally.
--- Does NOT perform the actual attack — it selects and assigns bot.attackTarget.
--- AttackTarget behavior takes over once the target is assigned.

---@class BDoomguyHunt
TTTBots.Behaviors.DoomguyHunt = {}

local lib = TTTBots.Lib
---@class BDoomguyHunt
local Hunt = TTTBots.Behaviors.DoomguyHunt
Hunt.Name = "DoomguyHunt"
Hunt.Description = "Actively hunt and pressure the nearest non-ally as Doomguy."
Hunt.Interruptible = true

local STATUS = TTTBots.STATUS

--- Returns true if this bot is playing the Doomguy role.
---@param bot Bot
---@return boolean
local function isDoomguy(bot)
    if not bot then return false end
    local roleStr = bot.GetRoleStringRaw and bot:GetRoleStringRaw() or ""
    return (roleStr == "doomguy" or roleStr == "doomguy_blue" or roleStr == "doomguy_red")
end

--- Rate how desirable a target is from Doomguy's perspective.
--- Higher = more desirable to pursue now.
---@param bot Bot
---@param target Player
---@return number score
local function rateTarget(bot, target)
    if not (IsValid(target) and lib.IsPlayerAlive(target)) then return -math.huge end
    if TTTBots.Roles.IsAllies(bot, target) then return -math.huge end

    local score = 0
    local botPos    = bot:GetPos()
    local targetPos = target:GetPos()
    local dist      = botPos:Distance(targetPos)

    -- Prefer close targets
    score = score + math.max(0, 2000 - dist) / 100

    -- Heavily prefer wounded targets
    local hp = target:Health()
    if hp < 70 then
        score = score + (70 - hp) * 0.5
    end

    -- Prefer targets we can currently see
    if bot:Visible(target) then
        score = score + 20
    end

    -- Prefer isolated targets (fewer nearby defenders)
    local nearbyAlliesOfTarget = 0
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and lib.IsPlayerAlive(p) and p ~= target and p ~= bot then
            if TTTBots.Roles.IsAllies(target, p) then
                if targetPos:Distance(p:GetPos()) < 600 then
                    nearbyAlliesOfTarget = nearbyAlliesOfTarget + 1
                end
            end
        end
    end
    score = score - nearbyAlliesOfTarget * 5

    return score
end

--- Find the best target to hunt.
---@param bot Bot
---@return Player? target
---@return number score
local function findBestHuntTarget(bot)
    local bestTarget = nil
    local bestScore  = -math.huge

    for _, ply in ipairs(player.GetAll()) do
        if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end
        if ply == bot then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then continue end

        local score = rateTarget(bot, ply)
        if score > bestScore then
            bestScore  = score
            bestTarget = ply
        end
    end

    return bestTarget, bestScore
end

--- Validate: only run as Doomguy, only during active round, no existing attack target.
---@param bot Bot
---@return boolean
function Hunt.Validate(bot)
    if not isDoomguy(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    -- Don't override an existing attack target — AttackTarget handles that.
    if IsValid(bot.attackTarget) then return false end
    -- Need at least one valid non-ally alive.
    local target, _ = findBestHuntTarget(bot)
    return IsValid(target)
end

--- Called when the behavior starts.
---@param bot Bot
---@return BStatus
function Hunt.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "DoomguyHunt")
    state.lastRetargetTime = 0
    state.lastHuntChatter = 0

    -- Hunting chatter
    local chatter = bot:BotChatter()
    if chatter and chatter.On and math.random(1, 3) == 1 then
        chatter:On("DoomguyHunting", {}, false, 0)
    end

    return STATUS.RUNNING
end

local RETARGET_INTERVAL = 3.0  -- seconds between target re-evaluations

--- Called each tick while running.
---@param bot Bot
---@return BStatus
function Hunt.OnRunning(bot)
    if not isDoomguy(bot) then return STATUS.FAILURE end
    if not TTTBots.Match.IsRoundActive() then return STATUS.FAILURE end

    -- If attack target was assigned (e.g. by FightBack seeing us), yield.
    if IsValid(bot.attackTarget) then return STATUS.SUCCESS end

    local state   = TTTBots.Behaviors.GetState(bot, "DoomguyHunt")
    local timeNow = CurTime()

    -- Re-evaluate target periodically.
    if timeNow - (state.lastRetargetTime or 0) >= RETARGET_INTERVAL then
        state.lastRetargetTime = timeNow
        local target, score = findBestHuntTarget(bot)
        if not IsValid(target) then return STATUS.FAILURE end
        state.huntTarget = target
    end

    local huntTarget = state.huntTarget
    if not (IsValid(huntTarget) and lib.IsPlayerAlive(huntTarget)) then
        state.huntTarget = nil
        return STATUS.RUNNING  -- will re-find on next retarget tick
    end

    -- If we can see and shoot the target, escalate to AttackTarget by assigning attackTarget.
    local canShoot = lib.CanShoot(bot, huntTarget)
    if canShoot then
        bot:SetAttackTarget(huntTarget, "DOOMGUY_HUNT", 4)
        return STATUS.SUCCESS
    end

    -- Otherwise, path toward the target's last known position.
    local loco = bot:BotLocomotor() ---@type CLocomotor
    if not loco then return STATUS.FAILURE end

    local memory = bot:BotMemory() ---@type CMemory
    local targetPos = memory and (memory:GetKnownPositionFor(huntTarget) or huntTarget:GetPos()) or huntTarget:GetPos()

    -- Doomguy always moves forward — no seeking cover during hunt.
    loco:SetGoal(targetPos)
    loco:LookAt(targetPos + Vector(0, 0, 40))

    return STATUS.RUNNING
end

--- Called on success.
---@param bot Bot
function Hunt.OnSuccess(bot)
end

--- Called on failure.
---@param bot Bot
function Hunt.OnFailure(bot)
    TTTBots.Behaviors.ClearState(bot, "DoomguyHunt")
end

--- Called when the behavior ends (success or failure).
---@param bot Bot
function Hunt.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "DoomguyHunt")
end
