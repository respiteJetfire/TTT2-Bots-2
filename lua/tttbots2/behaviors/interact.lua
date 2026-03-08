--- This is a more fluff-related module that make bots feel more alive.
--- It lets them nod, shake their head, and do silly actions next to one another/humans.
--- Enhanced with semantic animation selection (Tier 6 Personality & Immersion).



---@class BInteract
TTTBots.Behaviors.Interact = {}

local lib = TTTBots.Lib

---@class BInteract
local Interact = TTTBots.Behaviors.Interact
Interact.Name = "Interact"
Interact.Description = "Interact with another bot or player we can see"
Interact.Interruptible = true

Interact.MinTimeBetween = 24 -- Minimum seconds between all interactions.
Interact.MaxDistance = 200  -- Maximum distance before an interaction is considered
Interact.BaseChancePct = 4  -- Base chance of interacting with a player within our range, considered per tick

---@class Bot
---@field interactTarget Player?
---@field interactAnimationKeyframe integer? The current keyframe of the animation
---@field lastInteractionTime number The last time we interacted with someone
---@field nextKeyframeTime number The time the next keyframe should be played

local STATUS = TTTBots.STATUS

local intensity = 20

---@class KeyFrame
---@field target string
---@field direction string?
---@field amount number?
---@field action string?
---@field minTime number
---@field maxTime number

---@type table<table<KeyFrame>>
Interact.Animations = {
    Nod = {
        { target = "head", direction = "up",   amount = intensity, minTime = 0.4, maxTime = 0.6 },
        { target = "head", direction = "down", amount = intensity, minTime = 0.4, maxTime = 0.6 },
        { target = "head", direction = "up",   amount = intensity, minTime = 0.4, maxTime = 0.6 },
        { target = "head", direction = "down", amount = intensity, minTime = 0.4, maxTime = 0.6 },
        { target = "head", minTime = 0.7,      maxTime = 1.2 }, -- stare for a sec or so
    },
    Shake = {
        { target = "head", direction = "left",  amount = intensity, minTime = 0.4, maxTime = 0.6 },
        { target = "head", direction = "right", amount = intensity, minTime = 0.4, maxTime = 0.6 },
        { target = "head", direction = "left",  amount = intensity, minTime = 0.4, maxTime = 0.6 },
        { target = "head", direction = "right", amount = intensity, minTime = 0.4, maxTime = 0.6 },
        { target = "head", minTime = 0.7,       maxTime = 1.2 }, -- stare for a sec or so
    },
    LookUpDown = {
        { target = "head", minTime = 0.6, maxTime = 1.0 },
        { target = "feet", minTime = 0.6, maxTime = 1.0 },
        { target = "head", minTime = 0.6, maxTime = 1.0 },
        { target = "feet", minTime = 0.6, maxTime = 1.0 },
        { target = "head", minTime = 0.7, maxTime = 1.2 }, -- stare for a sec or so
    },
    Jump = {
        { target = "head", action = "jump", minTime = 0.3, maxTime = 0.4 },
        { target = "head", minTime = 0.4,   maxTime = 6 },                  -- stop jumping for a sec
        { target = "head", action = "jump", minTime = 0.3, maxTime = 0.4 }, -- jump again
        { target = "head", minTime = 0.4,   maxTime = 6 },                  -- finish it off with a stare
    },
    Crouch = {
        { target = "head", action = "crouch", minTime = 0.3, maxTime = 0.4 },
        { target = "head", minTime = 0.4,     maxTime = 6 },                  -- stop crouching for a sec
        { target = "head", action = "crouch", minTime = 0.3, maxTime = 0.4 }, -- crouch again
        { target = "head", minTime = 0.4,     maxTime = 6 },                  -- finish it off with a stare
    },
    -- Peek cautiously: crouch-approach gesture used near danger zones
    CrouchPeek = {
        { target = "head", action = "crouch", minTime = 0.5, maxTime = 0.8 },
        { target = "head", direction = "forward", amount = 10, minTime = 0.4, maxTime = 0.6 },
        { target = "head", action = "crouch", minTime = 0.4, maxTime = 0.6 },
        { target = "head", minTime = 0.6, maxTime = 1.0 },
    },
    -- Look away: avert gaze (traitor deception)
    LookAway = {
        { target = "head", direction = "left",  amount = intensity, minTime = 0.5, maxTime = 0.8 },
        { target = "head", direction = "down",  amount = intensity * 0.5, minTime = 0.4, maxTime = 0.6 },
        { target = "head", direction = "left",  amount = intensity, minTime = 0.5, maxTime = 0.8 },
        { target = "head", minTime = 0.8, maxTime = 1.5 },
    }
}

function Interact.GetNextKeyframeTime(keyframe)
    return CurTime() + (math.random(keyframe.minTime * 100, keyframe.maxTime * 100) / 100)
end

function Interact.SetAnimation(bot, value)
    if not value then
        bot.interactAnimation = nil
        bot.interactAnimationKeyframe = nil
        bot.nextKeyframeTime = nil
        return
    end

    local animation = type(value) == "string" and Interact.Animations[value] or value
    local keyframe = 1
    local minTime, maxTime = animation[keyframe].minTime, animation[keyframe].maxTime
    local nextKeyframeTime = Interact.GetNextKeyframeTime(animation[keyframe])

    bot.interactAnimation = animation
    bot.interactAnimationKeyframe = keyframe
    bot.nextKeyframeTime = nextKeyframeTime

    return animation, keyframe, nextKeyframeTime
end

function Interact.GetBotAnimation(bot)
    return bot.interactAnimation, bot.interactAnimationKeyframe, bot.nextKeyframeTime
end

function Interact.IsAnimationOver(bot)
    local animation, keyframe, nextKeyframeTime = Interact.GetBotAnimation(bot)

    if not (animation) then return true end
    if keyframe > #animation then return true end
    if (keyframe == #animation and nextKeyframeTime < CurTime() + 0.1) then return true end

    return false
end

function Interact.GetKeyframePos(other, keyframe)
    local direction = keyframe.direction or "up"
    local magnitude = keyframe.amount or 1

    local originHash = {
        head = lib.GetHeadPos(other) or other:EyePos(),
        feet = other:GetPos()
    }

    local right = other:GetRight()
    local forward = other:GetForward()

    local directionHash = {
        up = Vector(0, 0, 1),
        down = Vector(0, 0, -1),
        left = right * -1,
        right = right,
        forward = forward,
        backward = forward * -1
    }

    local origin = originHash[keyframe.target] or other:EyePos()
    local direction = directionHash[direction] or Vector(0, 0, 1)

    return origin + (direction * magnitude)
end

function Interact.TestTimer(bot)
    local lastTime = bot.lastInteractionTime or 0
    local interval = Interact.MinTimeBetween

    return (lastTime + interval) < CurTime()
end

function Interact.TestLookingAtEachOther(bot, other)
    local eyeTraceBot = bot:GetEyeTrace()
    local eyeTraceOther = other:GetEyeTrace()

    return (eyeTraceBot.Entity == other) or (eyeTraceOther.Entity == bot)
end

---Returns the first other that is close enough and/or looking at us. Prefers those we are looking at, or vice versa.
---@param bot Bot
---@return Player target?
---@return number targetDist?
function Interact.FindOther(bot)
    local target, targetDist = nil, math.huge
    local others = TTTBots.Match.AlivePlayers
    local maxDist = Interact.MaxDistance
    local maxDistSqr = maxDist * maxDist

    for _, other in pairs(others) do
        if other == bot then continue end
        if not lib.CanSee(bot, other) then continue end

        local distTo = bot:GetPos():DistToSqr(other:GetPos())
        if distTo > maxDistSqr then continue end
        if Interact.TestLookingAtEachOther(bot, other) then
            return other, distTo -- Always prefer those that are looking at us, or vice versa
        end

        if not target or distTo < targetDist then
            target = other
            targetDist = distTo
        end
    end

    return target, targetDist
end

---Validate the target of bot
---@param bot Bot
---@param target Player
---@return boolean
function Interact.ValidateTarget(bot, target)
    local valid = IsValid(target) and lib.IsPlayerAlive(target)
    if not valid then return false end

    local dist = bot:GetPos():DistToSqr(target:GetPos())
    local TOOFAR = Interact.MaxDistance * Interact.MaxDistance * 1.5
    if dist > TOOFAR then return false end

    return true
end

function Interact.HasTarget(bot)
    return Interact.ValidateTarget(bot, bot.interactTarget)
end

function Interact.TestChance(_bot)
    return lib.TestPercent(Interact.BaseChancePct)
end

-- ---------------------------------------------------------------------------
-- Semantic animation selection (Tier 6 — Personality & Immersion)
-- ---------------------------------------------------------------------------

--- Picks a contextually appropriate animation based on what's happening in the game.
--- Falls back to random if semantic animations are disabled or no context matches.
---@param bot Bot
---@return table animation
function Interact.PickSemanticAnimation(bot)
    if not TTTBots.Lib.GetConVarBool("semantic_animations") then
        return table.Random(Interact.Animations)
    end

    local role       = TTTBots.Roles.GetRoleFor(bot)
    local isTraitor  = role and role:GetTeam() == TEAM_TRAITOR
    local target     = bot.interactTarget

    -- 1. Near a danger zone → CrouchPeek
    local memory = bot:BotMemory()
    if memory and memory:IsDangerZone(bot:GetPos()) then
        return Interact.Animations.CrouchPeek
    end

    -- 2. Traitor doing deception chatter or near own kill → LookAway
    if isTraitor and bot.lastKillPos then
        local dist = bot:GetPos():Distance(bot.lastKillPos)
        if dist < 500 and (CurTime() - (bot.lastKillTime or 0)) < 30 then
            return Interact.Animations.LookAway
        end
    end

    -- 3. Someone was recently KOS'd or accused — look toward the accused if nearby
    local kosList = TTTBots.Match.KOSList
    if kosList and IsValid(target) then
        if kosList[target] and not table.IsEmpty(kosList[target]) then
            -- The player we're interacting with was KOS'd — nod (agreement)
            local evidence = bot.BotEvidence and bot:BotEvidence()
            if evidence and evidence:EvidenceWeight(target) >= 5 then
                return Interact.Animations.Nod
            else
                return Interact.Animations.Shake  -- disagree with the KOS
            end
        end
    end

    -- 4. Recent accusation context: nod if we agree with the accused's suspect, shake if not
    if bot.recentAccusationTarget and IsValid(target) then
        if bot.recentAccusationTarget == target then
            return Interact.Animations.Nod
        end
    end

    -- 5. Default: random (original behavior)
    return table.Random(Interact.Animations)
end

--- Try to holster to melee/crowbar when near non-hostile players.
--- Reverts when we leave Interact's max distance.
---@param bot Bot
function Interact.TryHolsterWeapon(bot)
    if not TTTBots.Lib.GetConVarBool("semantic_animations") then return end
    if bot.attackTarget and IsValid(bot.attackTarget) then return end  -- in combat, don't holster

    -- Find melee weapon
    local crowbar = bot:GetWeapon("weapon_crowbar")
    if not IsValid(crowbar) then return end

    local activeWep = bot:GetActiveWeapon()
    if not IsValid(activeWep) then return end

    -- Don't holster if already using crowbar
    if activeWep:GetClass() == "weapon_crowbar" then return end

    -- Record current weapon so we can restore it
    if not bot.preHolsterWeapon then
        bot.preHolsterWeapon = activeWep:GetClass()
    end

    bot:SelectWeapon("weapon_crowbar")
end

--- Restore the weapon we holstered when interact ends.
---@param bot Bot
function Interact.RestoreWeapon(bot)
    if not bot.preHolsterWeapon then return end
    local wep = bot:GetWeapon(bot.preHolsterWeapon)
    if IsValid(wep) then
        bot:SelectWeapon(bot.preHolsterWeapon)
    end
    bot.preHolsterWeapon = nil
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function Interact.Validate(bot)
    if not lib.IsPlayerAlive(bot) then return false end
    if not Interact.TestTimer(bot) then return false end
    if Interact.HasTarget(bot) then return true end
    if not Interact.TestChance(bot) then return false end -- can't get a new target bc failed random chance

    local target = Interact.FindOther(bot)
    if not Interact.ValidateTarget(bot, target) then return false end

    bot.interactTarget = target

    return true
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function Interact.OnStart(bot)
    local animation = Interact.PickSemanticAnimation(bot)
    Interact.SetAnimation(bot, animation)

    -- Weapon holster: switch to melee when near friendly players (non-hostile)
    if TTTBots.Lib.GetConVarBool("semantic_animations") then
        Interact.TryHolsterWeapon(bot)
    end

    return STATUS.RUNNING
end

---do actions
---@param loco CLocomotor
---@param keyObj KeyFrame
function Interact.DoAction(loco, keyObj)
    local shouldJump = keyObj.action == "jump"
    local shouldCrouch = keyObj.action == "crouch"

    loco:Jump(shouldJump)
    loco:Crouch(shouldCrouch)
end

function Interact.StopActions(loco)
    loco:Jump(false)
    loco:Crouch(false)
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function Interact.OnRunning(bot)
    if Interact.IsAnimationOver(bot) then
        -- print("Animation has concluded for " .. bot:Nick())
        return STATUS.SUCCESS
    end

    local animation, keyframe, nextKeyframeTime = Interact.GetBotAnimation(bot)
    local target = bot.interactTarget

    if not (target and Interact.ValidateTarget(bot, target)) then
        -- print("Target is no longer valid for " .. bot:Nick())
        return STATUS.FAILURE
    end

    local keyTbl = animation[keyframe]
    local keyframePos = Interact.GetKeyframePos(target, keyTbl)
    local loco = bot:BotLocomotor()

    if not loco then
        -- print("Locomotor is nil for " .. bot:Nick())
        return STATUS.FAILURE
    end

    loco:LookAt(keyframePos)
    loco:SetGoal(nil) -- Stay in place

    Interact.DoAction(loco, keyTbl)

    if nextKeyframeTime < CurTime() then
        bot.interactAnimationKeyframe = keyframe + 1
        bot.nextKeyframeTime = Interact.GetNextKeyframeTime(animation[keyframe + 1])
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function Interact.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function Interact.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function Interact.OnEnd(bot)
    Interact.SetAnimation(bot, nil)
    bot.lastInteractionTime = CurTime()
    local loco = bot:BotLocomotor()
    Interact.StopActions(loco)
    Interact.RestoreWeapon(bot)
end

-- ---------------------------------------------------------------------------
-- Flashlight toggle — cosmetic immersion in dark areas
-- ---------------------------------------------------------------------------

--- Returns true if the position is indoors / has no open sky above it.
--- Uses a vertical sky-trace: if the ray reaches the skybox unobstructed the
--- area is considered bright; if it hits solid geometry first it is dark.
---@param pos Vector
---@param bot Player
---@return boolean
local function IsDarkAt(pos, bot)
    local traceUp = util.TraceLine({
        start  = pos + Vector(0, 0, 16),
        endpos = pos + Vector(0, 0, 8192),
        filter = bot,
        mask   = MASK_SOLID_BRUSHONLY,
    })
    -- Hit something solid before reaching the sky → indoors/dark.
    return traceUp.Hit
end

timer.Create("TTTBots.Interact.Flashlight", 3, 0, function()
    if not TTTBots.Lib.GetConVarBool("semantic_animations") then return end
    if not TTTBots.Match.RoundActive then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and TTTBots.Lib.IsPlayerAlive(bot)) then continue end

        local isDark = IsDarkAt(bot:GetPos(), bot)

        local flOn = bot:FlashlightIsOn()
        if isDark and not flOn then
            bot:Flashlight(true)
        elseif not isDark and flOn then
            bot:Flashlight(false)
        end
    end
end)
