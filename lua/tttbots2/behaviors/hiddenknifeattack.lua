--- hiddenknifeattack.lua
--- Hidden melee knife-focused kill behavior.
--- The Hidden actively seeks isolated targets and closes distance to engage
--- with the Hidden knife (weapon_ttt_hd_knife).
--- The knife does 60 dmg/hit with auto-attack, and instant-kills at <65 HP.
--- Priorities:
---   1. Stunned targets (hit by stun nade) — easy kills.
---   2. Isolated targets (no nearby witnesses) that are visible.
---   3. Wounded targets (health < 65) for instant-kill execution.
---   4. Targets not facing the bot (backstab advantage with cloak).
--- Does NOT perform the actual attack — it selects a target, equips the knife,
--- and assigns bot.attackTarget once in melee range.

---@class BHiddenKnifeAttack
TTTBots.Behaviors.HiddenKnifeAttack = {}

local lib = TTTBots.Lib
---@class BHiddenKnifeAttack
local HiddenKnife = TTTBots.Behaviors.HiddenKnifeAttack
HiddenKnife.Name = "HiddenKnifeAttack"
HiddenKnife.Description = "Stalk and knife-kill isolated targets as Hidden."
HiddenKnife.Interruptible = true

local STATUS = TTTBots.STATUS
local HD_KNIFE_CLASS = "weapon_ttt_hd_knife"
local KNIFE_ENGAGE_DIST = 120    -- units; melee knife range
local APPROACH_DIST = 800        -- units; start approaching when this close
local RETARGET_INTERVAL = 4.0    -- seconds between target re-evaluations
local MAX_WITNESSES = 0          -- stricter than SK — Hidden relies on stealth

--- Returns true if this bot is the Hidden in stalker mode.
---@param bot Bot
---@return boolean
local function isHiddenStalker(bot)
    if not bot then return false end
    local roleStr = bot.GetRoleStringRaw and bot:GetRoleStringRaw() or ""
    if roleStr ~= "hidden" then return false end
    return bot:GetNWBool("ttt2_hd_stalker_mode", false)
end

--- Returns the Hidden knife weapon if the bot has it.
---@param bot Bot
---@return Weapon|nil
local function getHiddenKnife(bot)
    if not bot:HasWeapon(HD_KNIFE_CLASS) then return nil end
    local wep = bot:GetWeapon(HD_KNIFE_CLASS)
    return IsValid(wep) and wep or nil
end

--- Check if a target is stunned by the Hidden's stun grenade.
---@param target Player
---@return boolean
local function isStunned(target)
    return target:GetNWBool("ttt2_hdnade_stun", false)
end

--- Check if a target is facing away from the bot (backstab opportunity).
---@param bot Bot
---@param target Player
---@return boolean facingAway true if target is NOT looking at the bot
local function isTargetFacingAway(bot, target)
    if not (IsValid(bot) and IsValid(target)) then return false end
    local targetFwd = target:GetAimVector()
    local toBot = (bot:EyePos() - target:EyePos()):GetNormalized()
    local facingAngle = math.deg(math.acos(math.Clamp(targetFwd:Dot(toBot), -1, 1)))
    return facingAngle > 90
end

--- Rate how desirable a target is for Hidden knife kills.
--- Higher = more desirable to pursue now.
---@param bot Bot
---@param target Player
---@return number score
local function rateTarget(bot, target)
    if not (IsValid(target) and lib.IsPlayerAlive(target)) then return -math.huge end
    if TTTBots.Roles.IsAllies(bot, target) then return -math.huge end

    -- Skip targets that we can't "see" due to being a cloaked Hidden ourselves
    -- (this function rates OUR targets, not incoming threats)

    local score = 0
    local botPos    = bot:GetPos()
    local targetPos = target:GetPos()
    local dist      = botPos:Distance(targetPos)

    -- Prefer close targets (knife is melee)
    score = score + math.max(0, 2000 - dist) / 50

    -- Heavily prefer stunned targets (easy kill)
    if isStunned(target) then
        score = score + 40
    end

    -- Heavily prefer wounded targets (instant kill at <65 HP)
    local hp = target:Health()
    if hp < 65 then
        score = score + (65 - hp) * 1.2  -- massive bonus for execute threshold
    elseif hp < 80 then
        score = score + (80 - hp) * 0.3
    end

    -- Prefer targets we can currently see
    if bot:Visible(target) then
        score = score + 15
    end

    -- STRONG bonus for targets facing away (backstab with cloak advantage)
    if isTargetFacingAway(bot, target) then
        score = score + 20
    end

    -- Heavily prefer isolated targets (fewer nearby witnesses = safer knife kill)
    -- Hidden is MORE dependent on isolation than SK due to fragility once revealed
    local nearbyWitnesses = 0
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and lib.IsPlayerAlive(p) and p ~= target and p ~= bot then
            if targetPos:Distance(p:GetPos()) < 600 then
                nearbyWitnesses = nearbyWitnesses + 1
            end
        end
    end
    score = score - nearbyWitnesses * 15  -- stronger penalty than SK

    -- Bonus for targets that are stationary or moving slowly
    local vel = target:GetVelocity():Length()
    if vel < 50 then
        score = score + 10  -- standing still, easy knife target
    elseif vel < 150 then
        score = score + 4
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

--- Validate: only run as Hidden in stalker mode, must have knife, no existing attack target.
---@param bot Bot
---@return boolean
function HiddenKnife.Validate(bot)
    if not isHiddenStalker(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if IsValid(bot.attackTarget) then return false end
    if not getHiddenKnife(bot) then return false end

    local target, score = findBestKnifeTarget(bot)
    return IsValid(target) and score > 0
end

--- Called when the behavior starts.
---@param bot Bot
---@return BStatus
function HiddenKnife.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "HiddenKnifeAttack")
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
function HiddenKnife.OnRunning(bot)
    if not isHiddenStalker(bot) then return STATUS.FAILURE end
    if not TTTBots.Match.IsRoundActive() then return STATUS.FAILURE end

    -- If attack target was assigned (e.g. by FightBack), yield.
    if IsValid(bot.attackTarget) then return STATUS.SUCCESS end

    local state   = TTTBots.Behaviors.GetState(bot, "HiddenKnifeAttack")
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
        -- Target is gone — force immediate retarget instead of waiting for timer
        local target, score = findBestKnifeTarget(bot)
        if IsValid(target) and score > 0 then
            state.huntTarget = target
            state.lastRetargetTime = timeNow
            huntTarget = target
        else
            return STATUS.FAILURE
        end
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
        -- Abort if the target is looking right at us — stealth kill should be a surprise
        -- Exception: if the target is stunned, attack regardless of facing
        local targetFwd = huntTarget:GetAimVector()
        local toBot = (bot:EyePos() - huntTarget:EyePos()):GetNormalized()
        local facingAngle = math.deg(math.acos(math.Clamp(targetFwd:Dot(toBot), -1, 1)))

        if facingAngle <= 45 and not isStunned(huntTarget) then
            -- Target is staring at us — hold off, keep stalking
            return STATUS.RUNNING
        end

        -- FOV-aware + earshot witness check
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

        -- Hidden uses stricter witness threshold than SK
        -- But if target is stunned, allow 1 witness (stun = time-limited opportunity)
        local allowedWitnesses = isStunned(huntTarget) and 1 or MAX_WITNESSES

        if witnessCount <= allowedWitnesses then
            -- Equip knife, pause auto-switch, look at target, attack
            inv:PauseAutoSwitch()
            local knife = getHiddenKnife(bot)
            if knife then
                bot:SelectWeapon(HD_KNIFE_CLASS)
            end

            local targetEyes = huntTarget:EyePos()
            loco:LookAt(targetEyes)
            loco:SetGoal()  -- stop moving, commit to the kill

            -- Assign as attack target — the AttackTarget behavior takes over
            bot:SetAttackTarget(huntTarget, "HIDDEN_KNIFE_ATTACK", 5)

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
function HiddenKnife.OnSuccess(bot)
end

--- Called on failure.
---@param bot Bot
function HiddenKnife.OnFailure(bot)
    TTTBots.Behaviors.ClearState(bot, "HiddenKnifeAttack")
end

--- Called when the behavior ends (success or failure).
---@param bot Bot
function HiddenKnife.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "HiddenKnifeAttack")
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
end
