--- skshakenade.lua
--- Serial Killer shake nade behavior.
--- The SK can throw a ttt2_shake_nade via secondary fire (IN_ATTACK2) on the SK knife.
--- This is a flashbang-like smoke/shake grenade (screen shake + smoke VFX in 512-unit radius).
--- It has a 12-second cooldown between throws.
---
--- Tactical scenarios to throw:
---   1. **Escape:** Being chased/shot at — throw at own position to disorient pursuers.
---   2. **Pre-kill:** Before engaging a group — throw to disorient then rush in.
---   3. **Cover retreat:** After a knife kill with witnesses approaching — throw between self and witnesses.

---@class BSKShakeNade
TTTBots.Behaviors.SKShakeNade = {}

local lib = TTTBots.Lib
---@class BSKShakeNade
local ShakeNade = TTTBots.Behaviors.SKShakeNade
ShakeNade.Name = "SKShakeNade"
ShakeNade.Description = "Throw SK shake grenade for area denial, escape, or pre-kill distraction."
ShakeNade.Interruptible = true

local STATUS = TTTBots.STATUS
local SK_KNIFE_CLASS = "weapon_ttt_sk_knife"
local COOLDOWN = 13      -- seconds between throws (12s weapon cooldown + 1s buffer)
local MIN_THREATS = 1    -- minimum nearby threats to consider throwing
local THREAT_RADIUS = 700 -- units; scan radius for nearby threats

--- Returns true if this bot is playing the Serial Killer role.
---@param bot Bot
---@return boolean
local function isSerialKiller(bot)
    if not bot then return false end
    local roleStr = bot.GetRoleStringRaw and bot:GetRoleStringRaw() or ""
    return roleStr == "serialkiller"
end

--- Returns the SK knife weapon if the bot has it and it has a grenade ready (Clip1 > 0).
---@param bot Bot
---@return Weapon|nil
local function getSKKnifeWithAmmo(bot)
    if not bot:HasWeapon(SK_KNIFE_CLASS) then return nil end
    local wep = bot:GetWeapon(SK_KNIFE_CLASS)
    if not IsValid(wep) then return nil end
    -- Clip1 > 0 means the shake nade is available (not on cooldown)
    if wep:Clip1() <= 0 then return nil end
    return wep
end

--- Count nearby non-ally threats.
---@param bot Bot
---@return number threatCount
---@return Player? closestThreat
local function countNearbyThreats(bot)
    local botPos = bot:GetPos()
    local threatCount = 0
    local closestDist = math.huge
    local closestThreat = nil

    for _, ply in ipairs(player.GetAll()) do
        if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end
        if ply == bot then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then continue end

        local dist = botPos:Distance(ply:GetPos())
        if dist <= THREAT_RADIUS then
            threatCount = threatCount + 1
            if dist < closestDist then
                closestDist = dist
                closestThreat = ply
            end
        end
    end

    return threatCount, closestThreat
end

--- Determine if the bot is currently being attacked/chased.
---@param bot Bot
---@return boolean
local function isUnderAttack(bot)
    -- Check if the bot has taken recent damage
    local lastDmgTime = bot._lastDamageTime or 0
    return (CurTime() - lastDmgTime) < 3
end

--- Determine the best throw position for the shake nade.
---@param bot Bot
---@param scenario string "escape"|"prekill"|"cover"
---@param closestThreat Player?
---@return Vector throwPos
local function getThrowPosition(bot, scenario, closestThreat)
    local botPos = bot:GetPos()

    if scenario == "escape" then
        -- Throw at our own feet to disorient pursuers
        return botPos + Vector(0, 0, 20)
    elseif scenario == "prekill" and IsValid(closestThreat) then
        -- Throw at the group of targets
        return closestThreat:GetPos() + Vector(0, 0, 40)
    elseif scenario == "cover" and IsValid(closestThreat) then
        -- Throw between self and approaching witnesses
        local midpoint = (botPos + closestThreat:GetPos()) / 2
        return midpoint + Vector(0, 0, 40)
    end

    return botPos + bot:GetAimVector() * 300 + Vector(0, 0, 40)
end

--- Validate: only run as SK, with knife + ammo, off cooldown, with threats nearby.
---@param bot Bot
---@return boolean
function ShakeNade.Validate(bot)
    if not isSerialKiller(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not getSKKnifeWithAmmo(bot) then return false end

    -- Check cooldown
    local lastThrowTime = bot._lastShakeNadeTime or 0
    if (CurTime() - lastThrowTime) < COOLDOWN then return false end

    -- Need threats nearby to justify throwing
    local threatCount, _ = countNearbyThreats(bot)
    if threatCount < MIN_THREATS then return false end

    -- Determine scenario
    local underAttack = isUnderAttack(bot)
    local lowHP = bot:Health() < 50

    -- Only throw in tactical situations:
    -- 1. Under attack (escape)
    -- 2. Multiple threats nearby and about to engage (pre-kill)
    -- 3. Low HP with threats (desperate escape)
    if underAttack or lowHP or threatCount >= 2 then
        return true
    end

    -- Random chance for tactical throw when 1 threat is nearby (pre-kill distraction)
    return math.random(1, 8) == 1
end

--- Called when the behavior starts.
---@param bot Bot
---@return BStatus
function ShakeNade.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "SKShakeNade")
    state.throwPhase = "equip"  -- phases: equip -> aim -> throw -> done
    state.phaseStart = CurTime()

    -- Determine scenario
    local underAttack = isUnderAttack(bot)
    local threatCount, closestThreat = countNearbyThreats(bot)

    if underAttack then
        state.scenario = "escape"
    elseif threatCount >= 2 then
        state.scenario = "prekill"
    else
        state.scenario = "cover"
    end
    state.closestThreat = closestThreat

    return STATUS.RUNNING
end

--- Called each tick while running.
---@param bot Bot
---@return BStatus
function ShakeNade.OnRunning(bot)
    if not isSerialKiller(bot) then return STATUS.FAILURE end
    if not TTTBots.Match.IsRoundActive() then return STATUS.FAILURE end

    local state = TTTBots.Behaviors.GetState(bot, "SKShakeNade")
    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    local phase = state.throwPhase
    local elapsed = CurTime() - (state.phaseStart or CurTime())

    if phase == "equip" then
        -- Equip the SK knife
        inv:PauseAutoSwitch()
        local knife = getSKKnifeWithAmmo(bot)
        if not knife then
            return STATUS.FAILURE
        end
        bot:SelectWeapon(SK_KNIFE_CLASS)

        state.throwPhase = "aim"
        state.phaseStart = CurTime()
        return STATUS.RUNNING

    elseif phase == "aim" then
        -- Aim at throw position
        local throwPos = getThrowPosition(bot, state.scenario, state.closestThreat)
        loco:LookAt(throwPos)

        -- Brief delay to aim (0.3s)
        if elapsed >= 0.3 then
            state.throwPhase = "throw"
            state.phaseStart = CurTime()
        end
        return STATUS.RUNNING

    elseif phase == "throw" then
        -- Fire secondary attack (IN_ATTACK2) to throw the shake nade
        loco:StartAttack2()

        -- Brief hold of attack2 (0.2s)
        if elapsed >= 0.2 then
            loco:StopAttack2()
            bot._lastShakeNadeTime = CurTime()

            state.throwPhase = "done"
            state.phaseStart = CurTime()
        end
        return STATUS.RUNNING

    elseif phase == "done" then
        -- Cleanup and return success after a brief pause
        loco:StopAttack2()
        inv:ResumeAutoSwitch()
        return STATUS.SUCCESS
    end

    return STATUS.FAILURE
end

--- Called on success.
---@param bot Bot
function ShakeNade.OnSuccess(bot)
end

--- Called on failure.
---@param bot Bot
function ShakeNade.OnFailure(bot)
end

--- Called when the behavior ends (success or failure).
---@param bot Bot
function ShakeNade.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "SKShakeNade")
    local loco = bot:BotLocomotor()
    if loco then
        loco:StopAttack2()
    end
    local inv = bot:BotInventory()
    if inv then
        inv:ResumeAutoSwitch()
    end
end

-- ---------------------------------------------------------------------------
-- Damage tracking hook for SK bots (used by isUnderAttack)
-- ---------------------------------------------------------------------------

hook.Add("EntityTakeDamage", "TTTBots.SK.DamageTracker", function(target, dmginfo)
    if not (IsValid(target) and target:IsPlayer() and target:IsBot()) then return end
    target._lastDamageTime = CurTime()
end)

-- ---------------------------------------------------------------------------
-- Shake Nade reaction: non-SK bots detect nearby shake nades and flee
-- ---------------------------------------------------------------------------

hook.Add("OnEntityCreated", "TTTBots.SK.ShakeNadeReaction", function(ent)
    -- Wait a tick for the entity to be fully initialized
    timer.Simple(0, function()
        if not IsValid(ent) then return end
        if ent:GetClass() ~= "ttt2_shake_nade" then return end
        if not TTTBots.Match.RoundActive then return end

        local nadePos = ent:GetPos()
        local SHAKE_NADE_RADIUS = 600  -- slightly larger than actual 512 to give bots time to flee

        -- For each alive non-SK bot within the radius, add danger zone + flee
        for _, bot in ipairs(TTTBots.Bots) do
            if not (IsValid(bot) and TTTBots.Lib.IsPlayerAlive(bot)) then continue end

            -- Skip SK bots — they threw it
            local role = TTTBots.Roles.GetRoleFor(bot)
            if role and role:GetTeam() == TEAM_SERIALKILLER then continue end

            local dist = bot:GetPos():Distance(nadePos)
            if dist > SHAKE_NADE_RADIUS then continue end

            -- Add danger zone to memory so the bot avoids the area
            local memory = bot:BotMemory()
            if memory and type(memory.AddDangerZone) == "function" then
                memory:AddDangerZone(nadePos, SHAKE_NADE_RADIUS, "shake_nade", CurTime() + 10)
            end

            -- Attempt to set locomotor goal away from the nade
            local loco = bot:BotLocomotor()
            if loco then
                local fleeDir = (bot:GetPos() - nadePos):GetNormalized()
                local fleePos = bot:GetPos() + fleeDir * 400
                loco:SetGoal(fleePos)
            end
        end
    end)
end)
