--- skknifeattack.lua
--- Serial Killer knife-focused kill behavior.
--- The SK actively seeks isolated targets and closes distance to engage
--- with the silent SK knife (weapon_ttt_sk_knife).
--- The knife does 40 dmg/hit with auto-attack, and instant-kills at <50 HP.
--- Priorities:
---   1. Isolated targets (no nearby witnesses) that are visible.
---   2. Wounded targets (health < 50) for instant-kill execution.
---   3. Closest reachable non-ally as fallback.
--- Does NOT perform the actual ranged attack — it selects a target, equips the knife,
--- and assigns bot.attackTarget once in melee range.

---@class BSKKnifeAttack
TTTBots.Behaviors.SKKnifeAttack = {}

local lib = TTTBots.Lib
---@class BSKKnifeAttack
local SKKnife = TTTBots.Behaviors.SKKnifeAttack
SKKnife.Name = "SKKnifeAttack"
SKKnife.Description = "Stalk and knife-kill isolated targets as Serial Killer."
SKKnife.Interruptible = true

local STATUS = TTTBots.STATUS
local SK_KNIFE_CLASS = "weapon_ttt_sk_knife"
local KNIFE_ENGAGE_DIST = 120    -- units; melee knife range
local APPROACH_DIST = 800        -- units; start approaching when this close
local RETARGET_INTERVAL = 4.0    -- seconds between target re-evaluations
local MAX_WITNESSES = 1          -- max witnesses allowed before committing to attack

--- Returns true if this bot is playing the Serial Killer role.
---@param bot Bot
---@return boolean
local function isSerialKiller(bot)
    if not bot then return false end
    local roleStr = bot.GetRoleStringRaw and bot:GetRoleStringRaw() or ""
    return roleStr == "serialkiller"
end

--- Returns the SK knife weapon if the bot has it.
---@param bot Bot
---@return Weapon|nil
local function getSKKnife(bot)
    if not bot:HasWeapon(SK_KNIFE_CLASS) then return nil end
    local wep = bot:GetWeapon(SK_KNIFE_CLASS)
    return IsValid(wep) and wep or nil
end

--- Rate how desirable a target is for SK knife kills.
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

    -- Prefer close targets (knife is melee)
    score = score + math.max(0, 2000 - dist) / 50

    -- Heavily prefer wounded targets (instant kill at <50 HP)
    local hp = target:Health()
    if hp < 50 then
        score = score + (50 - hp) * 1.0  -- massive bonus for execute threshold
    elseif hp < 70 then
        score = score + (70 - hp) * 0.3
    end

    -- Prefer targets we can currently see
    if bot:Visible(target) then
        score = score + 15
    end

    -- Heavily prefer isolated targets (fewer nearby witnesses = safer knife kill)
    local nearbyWitnesses = 0
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and lib.IsPlayerAlive(p) and p ~= target and p ~= bot then
            if targetPos:Distance(p:GetPos()) < 600 then
                nearbyWitnesses = nearbyWitnesses + 1
            end
        end
    end
    score = score - nearbyWitnesses * 12  -- strong penalty per witness

    -- Bonus for targets that are stationary or moving slowly
    local vel = target:GetVelocity():Length()
    if vel < 50 then
        score = score + 8  -- standing still, easy knife target
    elseif vel < 150 then
        score = score + 3
    end

    return score
end

--- Find the best target for a knife kill.
---@param bot Bot
---@return Player? target
---@return number score
local function findBestKnifeTarget(bot)
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

--- Validate: only run as SK, only during active round, must have knife, no existing attack target.
---@param bot Bot
---@return boolean
function SKKnife.Validate(bot)
    if not isSerialKiller(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if IsValid(bot.attackTarget) then return false end
    if not getSKKnife(bot) then return false end

    local target, score = findBestKnifeTarget(bot)
    return IsValid(target) and score > 0
end

--- Called when the behavior starts.
---@param bot Bot
---@return BStatus
function SKKnife.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "SKKnifeAttack")
    state.lastRetargetTime = 0
    state.huntTarget = nil

    -- Find initial target
    local target, score = findBestKnifeTarget(bot)
    if IsValid(target) then
        state.huntTarget = target
    end

    return STATUS.RUNNING
end

--- Called each tick while running.
---@param bot Bot
---@return BStatus
function SKKnife.OnRunning(bot)
    if not isSerialKiller(bot) then return STATUS.FAILURE end
    if not TTTBots.Match.IsRoundActive() then return STATUS.FAILURE end

    -- If attack target was assigned (e.g. by FightBack), yield.
    if IsValid(bot.attackTarget) then return STATUS.SUCCESS end

    local state   = TTTBots.Behaviors.GetState(bot, "SKKnifeAttack")
    local timeNow = CurTime()

    -- Re-evaluate target periodically.
    if timeNow - (state.lastRetargetTime or 0) >= RETARGET_INTERVAL then
        state.lastRetargetTime = timeNow
        local target, score = findBestKnifeTarget(bot)
        if IsValid(target) and score > 0 then
            state.huntTarget = target
        elseif not IsValid(state.huntTarget) then
            return STATUS.FAILURE
        end
    end

    local huntTarget = state.huntTarget
    if not (IsValid(huntTarget) and lib.IsPlayerAlive(huntTarget)) then
        state.huntTarget = nil
        return STATUS.RUNNING  -- will re-find on next retarget tick
    end

    local loco = bot:BotLocomotor() ---@type CLocomotor
    local inv  = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    local botPos    = bot:GetPos()
    local targetPos = huntTarget:GetPos()
    local dist      = botPos:Distance(targetPos)

    -- Navigate toward target
    loco:SetGoal(targetPos)

    -- If close enough and visible, attempt knife engagement
    if dist <= KNIFE_ENGAGE_DIST and bot:Visible(huntTarget) then
        -- Abort if the target is looking right at us — a knife stalk should be a surprise
        local targetFwd = huntTarget:GetAimVector()
        local toBot = (bot:EyePos() - huntTarget:EyePos()):GetNormalized()
        local facingAngle = math.deg(math.acos(math.Clamp(targetFwd:Dot(toBot), -1, 1)))
        if facingAngle <= 45 then
            -- Target is staring at us — hold off, keep stalking
            return STATUS.RUNNING
        end

        -- FOV-aware + earshot witness check (replaces old 360° VisibleVec)
        local EARSHOT = 550
        local FOV_ARC = 120
        local nonAllies = TTTBots.Roles.GetNonAllies(bot)
        local witnessSet = {}
        for _, ply in pairs(nonAllies) do
            if ply == NULL or not IsValid(ply) then continue end
            if ply == bot or ply == huntTarget then continue end
            if not lib.IsPlayerAlive(ply) then continue end
            local d = ply:GetPos():Distance(bot:EyePos())
            if d <= EARSHOT then
                witnessSet[ply] = true
            elseif d <= TTTBots.Lib.BASIC_VIS_RANGE then
                if lib.CanSeeArc and lib.CanSeeArc(ply, bot:EyePos(), FOV_ARC) then
                    witnessSet[ply] = true
                end
            end
            -- Also check witnesses at the target's position
            local dt = ply:GetPos():Distance(targetPos)
            if dt <= EARSHOT then
                witnessSet[ply] = true
            elseif dt <= TTTBots.Lib.BASIC_VIS_RANGE then
                if lib.CanSeeArc and lib.CanSeeArc(ply, targetPos, FOV_ARC) then
                    witnessSet[ply] = true
                end
            end
        end
        local witnessCount = table.Count(witnessSet)

        if witnessCount <= MAX_WITNESSES then
            -- Equip knife, pause auto-switch, look at target, attack
            inv:PauseAutoSwitch()
            local knife = getSKKnife(bot)
            if knife then
                bot:SelectWeapon(SK_KNIFE_CLASS)
            end

            local targetEyes = huntTarget:EyePos()
            loco:LookAt(targetEyes)
            loco:SetGoal()  -- stop moving, commit to the kill

            -- Assign as attack target — the AttackTarget behavior takes over
            bot:SetAttackTarget(huntTarget, "SK_KNIFE_ATTACK", 5)

            -- Fire chatter event for knife kill intent
            local chatter = bot:BotChatter()
            if chatter and chatter.On and math.random(1, 4) == 1 then
                chatter:On("SKHunting", {}, true)
            end

            return STATUS.SUCCESS
        else
            -- Too many witnesses — back off, don't commit
            loco:StopAttack()
            inv:ResumeAutoSwitch()
            return STATUS.RUNNING
        end
    elseif dist <= APPROACH_DIST and bot:Visible(huntTarget) then
        -- Approaching — look at target to track them
        loco:LookAt(huntTarget:EyePos())
    end

    return STATUS.RUNNING
end

--- Called on success.
---@param bot Bot
function SKKnife.OnSuccess(bot)
end

--- Called on failure.
---@param bot Bot
function SKKnife.OnFailure(bot)
    TTTBots.Behaviors.ClearState(bot, "SKKnifeAttack")
end

--- Called when the behavior ends (success or failure).
---@param bot Bot
function SKKnife.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "SKKnifeAttack")
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
end
