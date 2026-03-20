
--[[
This behavior is not responsible for finding a target. It is responsible for attacking a target.

**It will only stop itself once the target is dead or nil. It must not be interrupted by another behavior.**
]]
---@class BAttack
TTTBots.Behaviors.AttackTarget = {}

local lib = TTTBots.Lib

---@class BAttack
local Attack = TTTBots.Behaviors.AttackTarget
Attack.Name = "AttackTarget"
Attack.Description = "Attacking target"
Attack.Interruptible = true

local STATUS = TTTBots.STATUS

local AGGRESSIVE_WEAPON_CLASSES = {
    ["ttt_smart_pistol"] = true,
    ["m9k_minigun"] = true,
}

local AGGRESSIVE_APPROACH_DISTS = {
    ["ttt_smart_pistol"] = 575,
    ["m9k_minigun"] = 450,
}

local AGGRESSIVE_BACKPEDAL_DISTS = {
    ["ttt_smart_pistol"] = 60,
    ["m9k_minigun"] = 40,
}

local DEFAULT_APPROACH_DIST = 200

---@enum ATTACKMODE
local ATTACKMODE = {
    Seeking = 2,  -- We have a target and we saw them recently or can see them but not shoot them
    Engaging = 3, -- We have a target and we know where they are, and we trying to shoot
}

--- Count local witnesses (non-ally alive players who can see the bot's position).
--- Used for ammo-sufficiency calculations.
---@param bot Bot
---@return number witnessCount
local function CountLocalWitnesses(bot)
    local pos = bot:GetPos()
    local count = 0
    local alivePlayers = TTTBots.Match.AlivePlayers or {}
    for _, ply in ipairs(alivePlayers) do
        if not IsValid(ply) then continue end
        if ply == bot then continue end
        if not TTTBots.Lib.IsPlayerAlive(ply) then continue end
        -- Only count players who are not allies and can see the bot's position
        if TTTBots.Roles and TTTBots.Roles.IsAllies(bot, ply) then continue end
        if ply:VisibleVec(pos) then
            count = count + 1
        end
    end
    return count
end

--- Check whether the bot has enough ammo to take on its current attack target.
--- If not, attempt a traitor deferred-buy, then flag a flee-from-target retreat.
--- Returns true if ammo is sufficient (or the check is waived), false to abort.
---@param bot Bot
---@return boolean sufficient
local function CheckAmmoSufficiency(bot)
    local target = bot.attackTarget
    if not IsValid(target) then return true end -- No target → nothing to check

    local inv = bot:BotInventory()
    if not inv then return true end

    -- If the bot has NO ranged weapon at all, the existing out-of-ammo path
    -- in OnRunning handles this. Only do the pre-check when we DO have a gun.
    if inv:HasNoWeaponAvailable(false) then return true end

    local witnessCount = CountLocalWitnesses(bot)
    if inv:HasEnoughAmmoToKill(target, witnessCount) then return true end

    -- ── Insufficient ammo ──────────────────────────────────────────────────
    -- Hothead bots charge regardless.
    if bot.HasTrait and bot:HasTrait("hothead") then return true end

    -- Traitor bots try to buy a weapon before giving up.
    local isTraitor = bot.GetRoleStringRaw and bot:GetRoleStringRaw() == "traitor"
    if isTraitor and TTTBots.Buyables then
        local bought = TTTBots.Buyables.TryDeferredBuy(bot, "LOW_AMMO")
        if bought then
            -- Got a fresh weapon — re-check ammo with the new loadout
            if inv:HasEnoughAmmoToKill(target, witnessCount) then return true end
        end
    end

    -- Coordinated / plan attacks: suppress ammo-flee unless HP is critical.
    -- This prevents the retreat→re-engage loop during coordinated strikes.
    local reason = bot.attackTargetReason
    local inCoordAttack = (reason == "COORD_ATTACK_STRIKE" or reason == "FOLLOW_PLAN_ATTACK")
    if not inCoordAttack then
        local fpState = TTTBots.Behaviors.GetState(bot, "FollowPlan")
        local job = fpState and fpState.Job
        if job then
            local ACTIONS = TTTBots.Plans and TTTBots.Plans.ACTIONS
            if ACTIONS then
                local act = job.Action
                if act == ACTIONS.COORD_ATTACK or act == ACTIONS.ATTACK or act == ACTIONS.ATTACKANY then
                    inCoordAttack = true
                end
            end
        end
    end
    if inCoordAttack and bot:Health() >= 20 then
        -- Committed to the coordinated attack — keep fighting even with low ammo.
        return true
    end

    -- Not enough ammo: flee from target until we rearm.
    bot.isRetreating = true
    bot.fleeFromTarget = target
    bot.fleeFromTargetUntil = CurTime() + 20
    bot:SetAttackTarget(nil, "LOW_AMMO")
    return false
end

--- Validate the behavior
function Attack.Validate(bot)
    -- Respawn grace: suppress attacking so the bot can equip weapons first.
    -- Exception: self-defense targets (priority 5) override the grace period.
    if (bot.respawnGraceUntil or 0) > CurTime() then
        local pri = bot.attackTargetPriority or 0
        if pri < (TTTBots.Morality and TTTBots.Morality.PRIORITY and TTTBots.Morality.PRIORITY.SELF_DEFENSE or 5) then
            return false
        end
    end
    -- If the bot fled because it ran out of ammo, don't re-engage the same
    -- target until the cooldown expires or the bot has a ranged weapon again.
    if IsValid(bot.attackTarget) and IsValid(bot.fleeFromTarget)
        and bot.attackTarget == bot.fleeFromTarget
        and (bot.fleeFromTargetUntil or 0) > CurTime() then
        local inv = bot:BotInventory()
        if inv and inv:HasNoWeaponAvailable(true) then
            bot:SetAttackTarget(nil, "STILL_UNARMED")
            return false
        else
            -- Bot found a weapon — clear the flee state.
            bot.fleeFromTarget = nil
            bot.fleeFromTargetUntil = nil
        end
    end
    -- Pre-engagement ammo check: ensure we have enough ammo to kill the target
    -- given the current witness pressure before committing to the fight.
    if not CheckAmmoSufficiency(bot) then return false end
    return Attack.ValidateTarget(bot)
end

--- Called when the behavior is started
function Attack.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "AttackTarget")
    state.wasPathing = true -- set this to true here for the first tick, despite the name being misleading
    return STATUS.RUNNING
end

function Attack.Seek(bot, targetPos)
    local target = bot.attackTarget
    local loco = bot:BotLocomotor() ---@type CLocomotor
    local inv = bot:BotInventory() ---@type CInventory
    if not (loco and inv) then return end
    local state = TTTBots.Behaviors.GetState(bot, "AttackTarget")
    bot:BotLocomotor().stopLookingAround = false
    loco:StopAttack()
    -- Only reload during seek if the weapon actually uses a clip. Clipless weapons
    -- (e.g. Doomguy SSG that fires directly from reserve ammo) should never be
    -- reloaded, and calling ReloadIfNecessary on them causes constant reload spam.
    local heldInfo = inv and inv:GetHeldWeaponInfo()
    if not (heldInfo and heldInfo.is_clipless) then
        inv:ReloadIfNecessary()
    end

    ---@type CMemory
    local memory = bot.components.memory
    local lastKnownPos = memory:GetSuspectedPositionFor(target) or memory:GetKnownPositionFor(target)
    local lastSeenTime = memory:GetLastSeenTime(target)
    local timeNow = CurTime()
    local secsSince = lastSeenTime > 0 and (timeNow - lastSeenTime) or 0
    local isAlive = target:Health() > 0 and not target:IsSpec() and TTTBots.Lib.IsPlayerAlive(target)
    if not isAlive then
        bot:SetAttackTarget(nil, "BEHAVIOR_END")
        return
    end

    -- If the target was assigned without ever being seen (lastSeenTime==0, e.g. from
    -- FollowPlan coordinator), seed their current position so the bot actually hunts
    -- them rather than treating CurTime()-0 as a 45+ second stale and aborting.
    if lastSeenTime == 0 and IsValid(target) then
        local memory = bot.components.memory
        if memory then
            memory:UpdateKnownPositionFor(target, target:GetPos())
            lastKnownPos = target:GetPos()
            secsSince = 0
        end
    end

    if secsSince > 45 then
        -- If we have not seen the target in 45 seconds, call off the attack.
        bot:SetAttackTarget(nil, "BEHAVIOR_END")
    elseif lastKnownPos then
        local distToKnown = bot:GetPos():Distance(lastKnownPos)
        if distToKnown <= 200 then
            -- We have arrived at (or are very near) the last-known position but
            -- the target isn't visible. Sweep nearby nav areas to flush them out
            -- rather than jumping to a random wander destination.
            -- Ensure the bot always has a sweep goal, even before the first
            -- CallEveryNTicks fires, so it doesn't stand still staring.
            if not state.hasSweepGoal then
                local currentArea = navmesh.GetNearestNavArea(bot:GetPos())
                local nearbyAreas = currentArea and currentArea:GetAdjacentAreas() or {}
                if #nearbyAreas > 0 then
                    loco:SetGoal(nearbyAreas[math.random(1, #nearbyAreas)]:GetCenter())
                end
                state.hasSweepGoal = true
            end
            lib.CallEveryNTicks(
                bot,
                function()
                    local currentArea = navmesh.GetNearestNavArea(bot:GetPos())
                    local nearbyAreas = currentArea and currentArea:GetAdjacentAreas() or {}
                    -- Filter to areas that the bot hasn't visited recently
                    local candidates = {}
                    for _, area in ipairs(nearbyAreas) do
                        if IsValid(area) then
                            table.insert(candidates, area)
                        end
                    end
                    if #candidates > 0 then
                        local sweepArea = candidates[math.random(1, #candidates)]
                        loco:SetGoal(sweepArea:GetCenter())
                    else
                        -- Fall back to any random nav if no adjacents available
                        local wanderArea = TTTBots.Behaviors.Wander.GetAnyRandomNav(bot)
                        if IsValid(wanderArea) then
                            loco:SetGoal(wanderArea:GetCenter())
                        end
                    end
                    state.hasSweepGoal = true
                end,
                math.ceil(TTTBots.Tickrate * 2)
            )
        else
            -- Path to last known position.
            -- If locomotor signalled cantReachGoal (truly impossible nav pair), evict the
            -- cache entry so the pathfinder retries, and walk toward an adjacent nav instead.
            local isImpossible = loco.cantReachGoal
            if isImpossible then
                lib.CallEveryNTicks(
                    bot,
                    function()
                        -- Evict the impossible-path entry so the pathfinder retries.
                        local startArea  = navmesh.GetNearestNavArea(bot:GetPos())
                        local finishArea = navmesh.GetNearestNavArea(lastKnownPos)
                        if startArea and finishArea then
                            local pathID = startArea:GetID() .. "to" .. finishArea:GetID()
                            TTTBots.PathManager.impossiblePaths[pathID] = nil
                            TTTBots.PathManager.cachedPaths[pathID]     = nil
                        end
                        -- Meanwhile walk toward an adjacent nav area near the target.
                        local targetArea = finishArea or navmesh.GetNearestNavArea(lastKnownPos)
                        if not IsValid(targetArea) then return end
                        local adj = targetArea:GetAdjacentAreas()
                        if adj and #adj > 0 then
                            local candidate = adj[math.random(1, #adj)]
                            if IsValid(candidate) then
                                loco:SetGoal(candidate:GetCenter())
                            end
                        end
                    end,
                    math.ceil(TTTBots.Tickrate * 5) -- retry every 5 s
                )
            else
                loco:SetGoal(lastKnownPos)
                loco:LookAt(lastKnownPos + Vector(0, 0, 40)) -- around hip/abdomen level
            end
        end
    else
        -- No known position at all — wander to find them.
        -- Immediately set a wander goal so the bot doesn't stand idle waiting for
        -- the first CallEveryNTicks to fire.
        if not state.hasWanderGoal then
            local wanderArea = TTTBots.Behaviors.Wander.GetAnyRandomNav(bot)
            if IsValid(wanderArea) then
                loco:SetGoal(wanderArea:GetCenter())
            end
            state.hasWanderGoal = true
        end
        lib.CallEveryNTicks(
            bot,
            function()
                local wanderArea = TTTBots.Behaviors.Wander.GetAnyRandomNav(bot)
                if not IsValid(wanderArea) then return end
                loco:SetGoal(wanderArea:GetCenter())
                state.hasWanderGoal = true
            end,
            math.ceil(TTTBots.Tickrate * 5)
        )
    end

    state.wasPathing = true --- Used to one-time stop loco when we start engaging
end

function Attack.GetTargetHeadPos(targetPly)
    local fallback = targetPly:EyePos()

    local head_bone_index = targetPly:LookupBone("ValveBiped.Bip01_Head1")
    if not head_bone_index then
        print("Returning fallback; no bone index for target.")
        return fallback
    end

    local head_pos, head_ang = targetPly:GetBonePosition(head_bone_index)

    if head_pos then
        return head_pos
    else
        print("Returning fallback, couldn't retrieve head_pos from bone index " .. head_bone_index)
        return fallback
    end
end

function Attack.GetTargetBodyPos(targetPly)
    local fallback = targetPly:GetPos() + Vector(0, 0, 0)

    local spine_bone_index = targetPly:LookupBone("ValveBiped.Bip01_Spine2")
    if not spine_bone_index then
        print("Returning fallback; no bone index for target.")
        return fallback
    end

    local spine_pos, spine_ang = targetPly:GetBonePosition(spine_bone_index)

    if spine_pos then
        return spine_pos
    else
        print("Returning fallback, couldn't retrieve spine_pos from bone index " .. spine_bone_index)
        return fallback
    end
end

function Attack.ShouldLookAtBody(bot, weapon)
    local personality = bot:BotPersonality() ---@type CPersonality
    local isBodyShotter = not (personality.isHeadshotter or false)
    if weapon and weapon.class == "ttt_smart_pistol" then
        return true
    end
    return isBodyShotter or (weapon.is_shotgun or weapon.is_melee)
end

---@param weapon WeaponInfo?
---@return boolean
function Attack.IsAggressiveWeapon(weapon)
    return weapon and AGGRESSIVE_WEAPON_CLASSES[weapon.class] or false
end

---@param weapon WeaponInfo?
---@return number
function Attack.GetIdealApproachDistance(weapon)
    if not weapon then return DEFAULT_APPROACH_DIST end
    return AGGRESSIVE_APPROACH_DISTS[weapon.class] or DEFAULT_APPROACH_DIST
end

--- Tells loco to strafe
---@param weapon WeaponInfo
---@param loco CLocomotor
function Attack.StrafeIfNecessary(bot, weapon, loco)
    local state = TTTBots.Behaviors.GetState(bot, "AttackTarget")
    if state.canStrafe == false then return false end
    if not (bot.attackTarget and bot.attackTarget.GetPos) then return false end
    if weapon.is_melee then return false end
    if weapon.class == "m9k_minigun" then return false end

    -- Do not strafe if we are on a cliff. We will fall off.
    local isCliffed = loco:IsCliffed()
    if isCliffed then return false end

    local distToTarget = bot:GetPos():Distance(bot.attackTarget:GetPos())
    local shouldStrafe = (
        distToTarget > 200
    -- and
    )

    if not shouldStrafe then return false end

    local strafeDir = math.random(0, 1) == 0 and "left" or "right"
    loco:Strafe(strafeDir)

    return true -- We are strafing
end

function Attack.ShouldApproachWith(bot, weapon)
    return weapon.is_shotgun or weapon.is_melee or Attack.IsAggressiveWeapon(weapon)
end

--- Tests if the target is next to an explosive barrel, if so, returns the barrel.
---@param bot Bot
---@param target Player
---@return Entity|nil barrel
function Attack.TargetNextToBarrel(bot, target)
    local lastBarrelTime = target.lastBarrelCheck or 0
    local targetBarrel = target.lastBarrel or nil
    local TIME_BETWEEN_BARREL_CHECKS = 3 -- 3 seconds

    if lastBarrelTime + TIME_BETWEEN_BARREL_CHECKS > CurTime() then return targetBarrel end

    local barrel = lib.GetClosestBarrel(target)
    target.lastBarrel = barrel
    return barrel
end

function Attack.ApproachIfNecessary(bot, weapon, loco)
    if not (bot.attackTarget and bot.attackTarget.GetPos) then return false end
    if not Attack.ShouldApproachWith(bot, weapon) then return false end

    local distToTarget = bot:GetPos():Distance(bot.attackTarget:GetPos())
    local idealDist = Attack.GetIdealApproachDistance(weapon)
    local shouldApproach = (
        distToTarget > idealDist
    )
    local forceStop = (
        distToTarget < idealDist
    )
    if forceStop then
        loco:SetForceForward(false)
        return false
    end -- Stop forcing forward if we are close enough
    if not shouldApproach then return false end

    loco:SetForceForward(true)

    return true -- We are approaching
end

--- Handles strafing, moving towards/away from our target, etc.
---@param weapon WeaponInfo
---@param loco CLocomotor
function Attack.HandleAttackMovement(bot, weapon, loco)
    Attack.StrafeIfNecessary(bot, weapon, loco)
    Attack.ApproachIfNecessary(bot, weapon, loco)
end

--- Set bot.coverTarget to trigger SeekCover when conditions are met.
---@param bot Bot
---@param target Player
function Attack.CheckCoverConditions(bot, target)
    local state = TTTBots.Behaviors.GetState(bot, "AttackTarget")
    -- Hothead never seeks cover.
    if bot.HasTrait and bot:HasTrait("hothead") then return end
    -- Already in cover-seeking mode — signal is on bot so SeekCover can read it cross-behavior.
    if IsValid(bot.coverTarget) then return end
    -- Respect post-cover cooldown to prevent instant re-triggering after SeekCover ends.
    if (bot.seekCoverCooldownUntil or 0) > CurTime() then return end

    -- Coordinated / plan attacks: suppress cover-seeking unless HP is critical (< 20%).
    -- This prevents bots from breaking off coordinated strikes to seek cover.
    if bot:Health() >= 20 then
        local reason = bot.attackTargetReason
        local inCoordAttack = (reason == "COORD_ATTACK_STRIKE" or reason == "FOLLOW_PLAN_ATTACK")
        if not inCoordAttack then
            local fpState = TTTBots.Behaviors.GetState(bot, "FollowPlan")
            local job = fpState and fpState.Job
            if job then
                local ACTIONS = TTTBots.Plans and TTTBots.Plans.ACTIONS
                if ACTIONS then
                    local act = job.Action
                    if act == ACTIONS.COORD_ATTACK or act == ACTIONS.ATTACK or act == ACTIONS.ATTACKANY then
                        inCoordAttack = true
                    end
                end
            end
        end
        if inCoordAttack then return end
    end

    local hp = bot:Health()
    local lowHealth = hp < 60

    -- Check if outgunned: target has a weapon with higher DPS.
    local outgunned = false
    if IsValid(target) then
        local inv = bot:BotInventory()
        local myInfo = inv and inv:GetHeldWeaponInfo()
        local targetInv = bot.components and bot.components.inventory
        local targetInfo = targetInv and targetInv:GetHeldWeaponInfo(target)
        if myInfo and targetInfo and targetInfo.dps and myInfo.dps then
            outgunned = targetInfo.dps > myInfo.dps * 1.5
        end
    end

    -- Tryhard/cautious bots use cover aggressively (lower threshold).
    local coverThreshold = 60
    if bot.HasTrait and (bot:HasTrait("cautious") or bot:HasTrait("tryhard")) then
        coverThreshold = 75
    end

    local myInfo = bot:BotInventory() and bot:BotInventory():GetHeldWeaponInfo() or nil
    if Attack.IsAggressiveWeapon(myInfo) then
        coverThreshold = coverThreshold - 20
        lowHealth = hp < 40
    end

    if (hp < coverThreshold and lowHealth) or outgunned then
        bot.coverTarget = target
    end
end

function Attack.GetPreferredBodyTarget(bot, wep, target)
    local body, head = Attack.GetTargetBodyPos(target), Attack.GetTargetHeadPos(target)
    if Attack.ShouldLookAtBody(bot, wep) then
        return body
    end

    return head
end

function Attack.Engage(bot, targetPos)
    local target = bot.attackTarget
    local inv = bot.components.inventory ---@type CInventory
    local weapon = inv:GetHeldWeaponInfo()
    if not weapon then return end
    local usingMelee = not weapon.is_gun
    local loco = bot:BotLocomotor() ---@type CLocomotor
    loco.stopLookingAround = true
    local state = TTTBots.Behaviors.GetState(bot, "AttackTarget")

    -- If we're forced to melee because all guns are empty, signal cover/retreat.
    -- (The actual abort happens in OnRunning's ammo check, but this gives an
    -- early "coverTarget" signal so SeekCover can start routing.)
    if usingMelee and inv:HasNoWeaponAvailable(false) then
        local isHothead = bot.HasTrait and bot:HasTrait("hothead")
        if not isHothead then
            bot.coverTarget = target
        end
    end

    local tooFarToAttack = false --- Used to prevent attacking when we are using a melee weapon and are too far away
    local distToTarget = bot:GetPos():Distance(target:GetPos())
    if state.wasPathing and not usingMelee then
        loco:StopMoving()
        state.wasPathing = false
    elseif usingMelee then
        tooFarToAttack = distToTarget > 160
        if distToTarget < 70 then
            loco:StopMoving()
            state.wasPathing = false
        else
            loco:SetGoal(targetPos)
            state.wasPathing = true
        end
    end

    -- Backpedal away if there is a bad guy near us.
    local backpedalDist = AGGRESSIVE_BACKPEDAL_DISTS[weapon.class] or 100
    if not usingMelee and distToTarget < backpedalDist then
        loco:SetForceBackward(true)
    else
        loco:SetForceBackward(false)
    end

    if not tooFarToAttack then
        if (Attack.LookingCloseToTarget(bot, target)) then
            if not Attack.WillShootingTeamkill(bot, target) then -- make sure we aren't about to teamkill by mistake!!
                loco:StartAttack()
            else
                -- Bystander in line of fire — stop shooting and strafe to find a clear angle
                loco:StopAttack()
                loco:Strafe()
            end
        end
    else
        loco:StopAttack()
        loco:Strafe()
    end

    local dvlpr = lib.GetDebugFor("attack")
    if dvlpr then
        TTTBots.DebugServer.DrawLineBetween(
            bot:EyePos(),
            targetPos,
            Color(255, 0, 0),
            0.1,
            bot:Nick() .. ".attack"
        )
    end

    local aimPoint = Attack.GetPreferredBodyTarget(bot, weapon, target)

    if not usingMelee then
        local barrel = Attack.TargetNextToBarrel(bot, target)
        if barrel
            and target:VisibleVec(barrel:GetPos())
            and bot:VisibleVec(barrel:GetPos())
        then
            aimPoint = barrel:GetPos() + barrel:OBBCenter()
        end
    end

    Attack.HandleAttackMovement(bot, weapon, loco)

    -- Check if we should retreat to cover based on health/outgunned status.
    Attack.CheckCoverConditions(bot, target)

    -- During reload, backpedal toward cover direction.
    -- Clipless weapons (e.g. Doomguy SSG) never truly reload, so skip this.
    if weapon.should_reload and not weapon.is_clipless then
        loco:SetForceBackward(true)
    end

    local predictedPoint = aimPoint + Attack.PredictMovement(target, 0.4)
    local inaccuracyTarget = predictedPoint + Attack.CalculateInaccuracy(bot, aimPoint, target)
    loco:LookAt(inaccuracyTarget)
end

local INACCURACY_BASE = 9  --- The higher this is, the more inaccurate the bots will be.
local INACCURACY_SMOKE = 5 --- The inaccuracy modifier when the bot or its target is in smoke.
--- Calculate the inaccuracy of agent 'bot' according to a) its personality and b) diff setts
---@param bot Bot The bot that is shooting.
---@param origin Vector The original aim point.
---@param target Player The target that is being shot at.
function Attack.CalculateInaccuracy(bot, origin, target)
    local heldWeapon = bot:BotInventory() and bot:BotInventory():GetHeldWeaponInfo() or nil
    if heldWeapon and heldWeapon.class == "ttt_smart_pistol" then
        return VectorRand() * 0.35
    end

    local personality = bot:BotPersonality()
    local difficulty = lib.GetConVarInt("difficulty") -- int [0,5]
    if not (difficulty or personality) then return Vector(0, 0, 0) end

    local dist = bot:GetPos():Distance(origin)
    local distFactor = math.max((dist / 64) ^ 1.5, 0.5)
    local pressure = personality:GetPressure()   -- float [0,1]
    local rage = (personality:GetRage() * 2) + 1 -- float [1,3]

    local isTraitorFactor =
        (bot:GetRoleStringRaw() == "traitor" and lib.GetConVarBool("cheat_traitor_accuracy"))
        and 0.5 or 1

    local focus_factor = (1 - (TTTBots.Behaviors.GetState(bot, "AttackTarget").attackFocus or 0.01)) * 1.5

    local targetMoveFactor = 1
    local selfMoveFactor = bot:GetVelocity():LengthSqr() > 100 and 1.25 or 0.75
    if not (IsValid(target) and target:IsPlayer()) then
        targetMoveFactor = 0.5
    else
        local vel = target:GetVelocity():LengthSqr()
        targetMoveFactor = vel > 100 and 1.0 or 0.5
    end

    local smokeFn = TTTBots.Match.IsPlyNearSmoke
    local isInSmoke = (smokeFn(bot) or smokeFn(bot.attackTarget)) and INACCURACY_SMOKE or 1

    local inaccuracy_mod = (pressure / difficulty) -- The more pressure we have, the more inaccurate we are; decreased by difficulty
        * distFactor                               -- The further away we are, the more inaccurate we are
        * INACCURACY_BASE                          -- Obviously, multiply by a constant to make it more inaccurate
        * rage                                     -- The more rage we have, the more inaccurate we are
        * focus_factor                             -- The less focus we have, the more inaccurate we are
        * isInSmoke                                -- If we are in smoke, we are more inaccurate
        * isTraitorFactor                          -- Reduce aim difficulty if the cheat cvar is enabled
        * targetMoveFactor                         -- Reduce aim difficulty if the target is immobile

    if heldWeapon and heldWeapon.class == "m9k_minigun" then
        inaccuracy_mod = inaccuracy_mod * 0.55
    end

    inaccuracy_mod = math.max(inaccuracy_mod, 0.1)

    local rand = VectorRand() * inaccuracy_mod
    -- TTTBots.DebugServer.DrawCross(origin + rand, 8, Color(0, 255, 0), 0.1, bot:Nick() .. ".attack.inaccuracy")
    return rand
end

---Predict the (relative) movement of the target player using basic linear prediction
---@param target Player
---@return Vector predictedMovement
function Attack.PredictMovement(target, mult)
    local vel = target:GetVelocity()
    local predictionSecs = 1.0 / TTTBots.Tickrate
    local predictionMultSalt = math.random(95, 105) / 100.0
    local predictionMult = (1 + predictionMultSalt) * (mult or 0.5)
    local predictionRelative = (vel * predictionSecs * predictionMult)

    local dvlpr = lib.GetDebugFor("attack")
    if dvlpr then
        -- Draw a cross at the predicted position
        if target:IsPlayer() then
            TTTBots.DebugServer.DrawCross(target:GetPos() + predictionRelative, 8, Color(255, 0, 0), predictionSecs,
                target:Nick() .. ".attack.prediction")
        end
    end

    return predictionRelative
end

--- The minimum distance (in units) a bystander must be from the line of fire
--- to be considered "in the way".
local LOF_RADIUS = 48 -- roughly player half-width

--- Returns true if shooting now risks hitting an unsuspected bystander.
--- Checks the full line of fire between the bot's eyes and the target, not
--- just the single eye-trace hit.  Players the bot already suspects
--- (suspicion >= Sus threshold) are ignored — the bot is willing to shoot
--- through someone it considers likely hostile.
---
--- When the bot is actively defending itself (SELF_DEFENSE priority) or
--- attacking a confirmed-hostile KOSedByAll / infected-zombie target, the
--- teamkill check is relaxed so the bot doesn't freeze up in a crowd.
function Attack.WillShootingTeamkill(bot, target)
    if not (IsValid(bot) and IsValid(target)) then return false end

    -- High-priority combat: relax the bystander check so the bot actually
    -- shoots back at someone who is shooting them, or fires on a KOSedByAll
    -- target even if another player is partly in the way.
    local pri = bot.attackTargetPriority or 0
    local Arb = TTTBots.Morality
    local SELF_DEF = Arb and Arb.PRIORITY and Arb.PRIORITY.SELF_DEFENSE or 5
    local ROLE_HOST = Arb and Arb.PRIORITY and Arb.PRIORITY.ROLE_HOSTILITY or 3
    if pri >= SELF_DEF then
        -- Self-defense: only stop if an actual *ally* is in the path.
        -- We still run the ally check below but skip the "unknown bystander" hesitation.
        -- Fall through with a narrowed check by forcing a direct trace-only path.
        local eyeTrace = bot:GetEyeTrace()
        local hitEnt   = eyeTrace.Entity
        if hitEnt == target then return false end
        if not (IsValid(hitEnt) and hitEnt:IsPlayer() and hitEnt ~= target) then return false end
        if not TTTBots.Lib.IsPlayerAlive(hitEnt) then return false end
        local isPerceivedAlly = (TTTBots.Perception and TTTBots.Perception.IsPerceivedAlly(bot, hitEnt))
            or TTTBots.Roles.IsAllies(bot, hitEnt)
        return isPerceivedAlly  -- only block if a true ally is directly in the way
    end

    -- KOSedByAll targets (Doomguy, infected zombies): allow shooting through
    -- unknown bystanders — hesitate only for perceived allies.
    local targetRole = TTTBots.Roles.GetRoleFor(target)
    local targetIsKOSedByAll = targetRole and targetRole.GetKOSedByAll and targetRole:GetKOSedByAll()
    local targetIsZombie = TTTBots.Roles.IsInfectedZombie and TTTBots.Roles.IsInfectedZombie(target)
    if targetIsKOSedByAll or targetIsZombie then
        local eyeTrace = bot:GetEyeTrace()
        local hitEnt   = eyeTrace.Entity
        if hitEnt == target then return false end
        if not (IsValid(hitEnt) and hitEnt:IsPlayer() and hitEnt ~= target) then return false end
        if not TTTBots.Lib.IsPlayerAlive(hitEnt) then return false end
        local isPerceivedAlly = (TTTBots.Perception and TTTBots.Perception.IsPerceivedAlly(bot, hitEnt))
            or TTTBots.Roles.IsAllies(bot, hitEnt)
        return isPerceivedAlly
    end

    -- 1) Quick check: direct eye-trace hit
    local eyeTrace = bot:GetEyeTrace()
    local hitEnt = eyeTrace.Entity

    -- If the trace hit our target directly, nothing is in the way.
    if hitEnt == target then return false end

    -- 2) Gather geometry for the line-of-fire corridor
    local origin = bot:EyePos()
    local targetPos = Attack.GetPreferredBodyTarget(bot, bot:BotInventory():GetHeldWeaponInfo() or {}, target)
    local fireDir = (targetPos - origin)
    local fireDist = fireDir:Length()
    if fireDist < 1 then return false end
    fireDir:Normalize()

    -- 3) Get suspicion thresholds & morality once
    local morality = bot.components and bot.components.morality
    local susThreshold = TTTBots.Components.Morality
        and TTTBots.Components.Morality.Thresholds
        and TTTBots.Components.Morality.Thresholds.Sus or 3

    -- 4) Check every alive player (except bot & target) for proximity to the
    --    line of fire.  We project each player onto the ray and see if they
    --    fall within LOF_RADIUS of it AND are between the bot and the target.
    local alivePlayers = TTTBots.Match.AlivePlayers or {}
    for _, ply in ipairs(alivePlayers) do
        if not IsValid(ply) then continue end
        if ply == bot or ply == target then continue end
        if not TTTBots.Lib.IsPlayerAlive(ply) then continue end

        local plyCenter = ply:WorldSpaceCenter() or (ply:GetPos() + Vector(0, 0, 36))
        local toPlayer = plyCenter - origin

        -- How far along the shot direction is this player?
        local projDist = toPlayer:Dot(fireDir)
        -- Must be between us and the target (with a small margin behind the target)
        if projDist < 0 or projDist > fireDist + 32 then continue end

        -- Perpendicular distance from the line of fire
        local closestPointOnRay = origin + fireDir * projDist
        local perpDist = (plyCenter - closestPointOnRay):Length()
        if perpDist > LOF_RADIUS then continue end

        -- This player IS in the line of fire. Decide if we care.
        -- NPCs in the way — always hesitate (could be a friendly NPC).
        if not ply:IsPlayer() then return true end

        -- If this bystander is someone we already suspect, we don't hesitate.
        if morality then
            local sus = morality:GetSuspicion(ply)
            if sus >= susThreshold then continue end
        end

        -- Allies (perceived) — always hesitate.
        local isPerceivedAlly = (TTTBots.Perception and TTTBots.Perception.IsPerceivedAlly(bot, ply))
            or TTTBots.Roles.IsAllies(bot, ply)
        if isPerceivedAlly then return true end

        -- Unknown / low-suspicion player in the line of fire — hesitate.
        -- The bot doesn't suspect them enough to risk friendly fire.
        return true
    end

    -- 5) Also catch the simple case: direct trace hit a live player who isn't
    --    our target and isn't suspected.  (Belt-and-suspenders with the ray
    --    check above, but handles edge cases in hull geometry.)
    if IsValid(hitEnt) and hitEnt:IsPlayer() and hitEnt ~= target then
        if not TTTBots.Lib.IsPlayerAlive(hitEnt) then return false end
        if morality then
            local sus = morality:GetSuspicion(hitEnt)
            if sus >= susThreshold then return false end
        end
        local isPerceivedAlly = (TTTBots.Perception and TTTBots.Perception.IsPerceivedAlly(bot, hitEnt))
            or TTTBots.Roles.IsAllies(bot, hitEnt)
        if isPerceivedAlly then return true end
        return true -- unknown player, don't risk it
    end

    return false
end

function Attack.LookingCloseToTarget(bot, target)
    local targetPos = target:GetPos()
    ---@type CLocomotor
    local locomotor = bot:BotLocomotor()
    local degDiff = math.abs(locomotor:GetEyeAngleDiffTo(targetPos))

    local THRESHOLD = 10
    local heldWeapon = bot:BotInventory() and bot:BotInventory():GetHeldWeaponInfo() or nil
    local threshold = THRESHOLD
    if heldWeapon and heldWeapon.class == "ttt_smart_pistol" then
        threshold = 18
    elseif heldWeapon and heldWeapon.class == "m9k_minigun" then
        threshold = 14
    end

    local isLookingClose = degDiff < threshold

    return isLookingClose
end

--- Determine what mode of attack (attackMode) we are in.
---@param bot Bot
---@return ATTACKMODE mode
function Attack.RunningAttackLogic(bot)
    ---@type CMemory
    local memory = bot.components.memory
    local target = bot.attackTarget
    local targetPos, canSee = memory:GetCurrentPosOf(target)
    local isAlive = bot.attackTarget:Health() > 0
    local mode = ATTACKMODE.Seeking -- Default to seeking
    local canShoot = lib.CanShoot(bot, target)
    -- print("Can bot ".. bot:Nick() .. " shoot target? " .. tostring(canShoot))

    if canShoot and isAlive then mode = ATTACKMODE.Engaging end -- We can shoot them, we are engaging

    local switchcase = {
        [ATTACKMODE.Seeking] = Attack.Seek,
        [ATTACKMODE.Engaging] = Attack.Engage,
    }
    switchcase[mode](bot, targetPos) -- Call the function
    return mode
end

local function FormatAttackValidationEntity(ent)
    if ent == nil then return "nil" end
    if ent == NULL then return "NULL" end
    if not IsValid(ent) then return "invalid:" .. tostring(ent) end

    if ent:IsPlayer() then
        local role = ent.GetRoleStringRaw and ent:GetRoleStringRaw() or "unknown"
        local steamID = ent.SteamID64 and ent:SteamID64() or (ent.SteamID and ent:SteamID() or "unknown")
        return string.format(
            "player nick=%s steamid=%s role=%s hp=%s alive=%s pos=%s",
            tostring(ent:Nick()),
            tostring(steamID),
            tostring(role),
            tostring(ent:Health()),
            tostring(TTTBots.Lib.IsPlayerAlive(ent)),
            tostring(ent:GetPos())
        )
    end

    if ent:IsNPC() then
        return string.format(
            "npc class=%s hp=%s pos=%s",
            tostring(ent:GetClass()),
            tostring(ent:Health()),
            tostring(ent:GetPos())
        )
    end

    return tostring(ent)
end

local function PrintAttackValidationFailure(bot, info)
    print(string.format("[TTTBots][AttackTarget] %s failed to validate attack target behavior.", tostring(bot:Nick())))
    print(string.format("  bot: %s", FormatAttackValidationEntity(bot)))
    print(string.format("  target: %s", FormatAttackValidationEntity(info.target)))
    print(string.format(
        "  checks: hasTarget=%s targetIsValid=%s botIsAlive=%s targetIsAlive=%s targetIsPlayer=%s targetIsNPC=%s targetIsPlayerAndAlive=%s targetIsNPCAndAlive=%s targetIsPlayerOrNPCAndAlive=%s notSeenRecently=%s isAlly=%s checkPassed=%s npcPass=%s",
        tostring(info.hasTarget),
        tostring(info.targetIsValid),
        tostring(info.botIsAlive),
        tostring(info.targetIsAlive),
        tostring(info.targetIsPlayer),
        tostring(info.targetIsNPC),
        tostring(info.targetIsPlayerAndAlive),
        tostring(info.targetIsNPCAndAlive),
        tostring(info.targetIsPlayerOrNPCAndAlive),
        tostring(info.notSeenRecently),
        tostring(info.isAlly),
        tostring(info.checkPassed),
        tostring(info.NPCPass)
    ))
    print(string.format(
        "  timing: curTime=%s lastSeenTime=%s attackTargetPriority=%s attackBehaviorMode=%s",
        tostring(CurTime()),
        tostring(info.lastSeenTime),
        tostring(bot.attackTargetPriority),
        tostring(info.attackBehaviorMode)
    ))
end

--- Validates if the target is extant and alive. True if valid.
---@param bot Bot
---@return boolean isValid
function Attack.ValidateTarget(bot)
    local target = bot.attackTarget

    local hasTarget = (target and target ~= NULL) and true or false
    if target == NULL or not IsValid(target) then return false end
    local targetIsValid = target and target:IsValid() or false
    local lastSeenTime = bot.components.memory:GetLastSeenTime(target)
    -- 0 means "never recorded in memory" (e.g. target assigned via SELF_DEFENSE without LOS).
    -- Only treat the target as stale when we have a real last-seen timestamp and it is old.
    local notSeenRecently = lastSeenTime > 0 and (lastSeenTime + 30 < CurTime())
    local botIsAlive = bot and bot:Health() > 0 or false
    local targetIsAlive = target and target:IsPlayer() and target:Health() > 0 or false
    local targetIsPlayer = target and target:IsPlayer() or false
    local targetIsNPC = (target and target:IsNPC() and not table.HasValue(TTTBots, target)) or false
    local targetIsPlayerAndAlive = targetIsPlayer and TTTBots.Lib.IsPlayerAlive(target) or false
    local targetIsNPCAndAlive = targetIsNPC and target:Health() > 0 or false
    local targetIsPlayerOrNPCAndAlive = (targetIsPlayerAndAlive or targetIsNPCAndAlive) and targetIsAlive or false
    local baseRole = target:IsPlayer() and target:GetBaseRole() or nil
    local isAlly = (TTTBots.Roles.IsAllies(bot, target) and (baseRole ~= ROLE_INNOCENT)) or baseRole == ROLE_MEDIC

    -- print(bot:Nick() .. " validating attack target behavior:")
    -- print("| hasTarget: " .. tostring(hasTarget))
    -- print("| targetName: " .. tostring(target:Nick()))
    -- print("| targetIsValid: " .. tostring(targetIsValid))
    -- if targetIsNPCAndAlive then
    --     print("| targetNPCName: " .. tostring(target:GetClass()))
    -- end
    -- if targetIsPlayerAndAlive then
    --     print("| targetName: " .. tostring(target:Nick()))
    -- end
    -- print("| targetIsAlive: " .. tostring(targetIsAlive))
    -- print("| targetIsPlayer: " .. tostring(targetIsPlayer))
    -- print("| targetIsNPC: " .. tostring(targetIsNPC))
    -- print("| targetIsPlayerAndAlive: " .. tostring(targetIsPlayerAndAlive))
    -- print("| targetIsNPCAndAlive: " .. tostring(targetIsNPCAndAlive))
    -- print("| targetIsPlayerOrNPCAndAlive: " .. tostring(targetIsPlayerOrNPCAndAlive))
    -- print("------------------")

    local checkPassed = (
        hasTarget
        and targetIsValid
        and botIsAlive
        and targetIsAlive
        and targetIsPlayerOrNPCAndAlive
        and not notSeenRecently
        and not isAlly
    )

    local NPCPass = (
        hasTarget
        and targetIsValid
        and botIsAlive
        and targetIsNPCAndAlive
    )

    if not (checkPassed or NPCPass) then
        local state = TTTBots.Behaviors.GetState(bot, "AttackTarget")
        PrintAttackValidationFailure(bot, {
            target = target,
            hasTarget = hasTarget,
            targetIsValid = targetIsValid,
            botIsAlive = botIsAlive,
            targetIsAlive = targetIsAlive,
            targetIsPlayer = targetIsPlayer,
            targetIsNPC = targetIsNPC,
            targetIsPlayerAndAlive = targetIsPlayerAndAlive,
            targetIsNPCAndAlive = targetIsNPCAndAlive,
            targetIsPlayerOrNPCAndAlive = targetIsPlayerOrNPCAndAlive,
            lastSeenTime = lastSeenTime,
            notSeenRecently = notSeenRecently,
            isAlly = isAlly,
            checkPassed = checkPassed,
            NPCPass = NPCPass,
            attackBehaviorMode = state.attackBehaviorMode,
        })
        bot:SetAttackTarget(nil, "BEHAVIOR_END")
        if state.attackBehaviorMode == ATTACKMODE.Engaging then
            bot:BotLocomotor():StopAttack()
        end
        if bot.attackTarget then
            bot.attackTarget = nil
            -- print(bot:Nick() .. " cleared attack target.")
        end
    end

    return checkPassed or NPCPass
end

function Attack.IsTargetAlly(bot)
    --- if bot.attackTarget is an NPC, return false
    if not (IsValid(bot.attackTarget) and bot.attackTarget:IsNPC()) then return false end
    if not (IsValid(bot.attackTarget) and bot.attackTarget:IsPlayer()) then return false end
    return TTTBots.Roles.IsAllies(bot, bot.attackTarget)
end

--- Called when the behavior's last state is running
---@param bot Bot
---@return BStatus status
function Attack.OnRunning(bot)
    local target = bot.attackTarget
    -- print("Bot " .. bot:Nick() .. " is attacking " .. tostring(target))
    -- We could probably do Attack.Validate but this is more explicit:
    if not Attack.ValidateTarget(bot) then return STATUS.FAILURE end -- Target is not valid
    if Attack.IsTargetAlly(bot) then return STATUS.FAILURE end       -- Target is an ally. No attack!
    if target == bot then
        bot:SetAttackTarget(nil, "BEHAVIOR_END")
        return STATUS.FAILURE
    end

    -- ── Out-of-ammo abort ──────────────────────────────────────────────────
    -- If the bot has no ranged weapon with ammo and is forced to melee,
    -- abort the fight so it can retreat and find a weapon instead.
    -- "Hothead" bots will keep swinging regardless.
    -- Coordinated / plan attacks: keep fighting even with melee unless HP < 20%.
    local inv = bot:BotInventory()
    if inv and inv:HasNoWeaponAvailable(true) then
        local isHothead = bot.HasTrait and bot:HasTrait("hothead")
        local suppressRetreat = false
        if not isHothead then
            local reason = bot.attackTargetReason
            local inCoordAttack = (reason == "COORD_ATTACK_STRIKE" or reason == "FOLLOW_PLAN_ATTACK")
            if not inCoordAttack then
                local fpState = TTTBots.Behaviors.GetState(bot, "FollowPlan")
                local job = fpState and fpState.Job
                if job then
                    local ACTIONS = TTTBots.Plans and TTTBots.Plans.ACTIONS
                    if ACTIONS then
                        local act = job.Action
                        if act == ACTIONS.COORD_ATTACK or act == ACTIONS.ATTACK or act == ACTIONS.ATTACKANY then
                            inCoordAttack = true
                        end
                    end
                end
            end
            if inCoordAttack and bot:Health() >= 20 then
                suppressRetreat = true
            end
        end
        if not isHothead and not suppressRetreat then
            -- Flag the bot as retreating so the Retreat behavior picks up.
            bot.isRetreating = true
            -- Remember who we were fighting so we can avoid them while unarmed.
            bot.fleeFromTarget = target
            bot.fleeFromTargetUntil = CurTime() + 20
            bot:SetAttackTarget(nil, "OUT_OF_AMMO")
            return STATUS.FAILURE
        end
    end

    local isNPC = target:IsNPC()
    local isPlayer = target:IsPlayer()
    if not isNPC and not isPlayer then
        ErrorNoHaltWithStack("Wtf has bot.attackTarget been assigned to? Not NPC nor player... target: " ..
            tostring(bot.attackTarget))
    end -- Target is not a player or NPC

    local attack = Attack.RunningAttackLogic(bot)
    TTTBots.Behaviors.GetState(bot, "AttackTarget").attackBehaviorMode = attack

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state
function Attack.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function Attack.OnFailure(bot)
end

--- Called when the behavior ends
function Attack.OnEnd(bot)
    local lastTarget = bot.attackTarget  -- capture before clearing
    bot:SetAttackTarget(nil, "BEHAVIOR_END")
    bot:BotLocomotor().stopLookingAround = false
    bot:BotLocomotor():StopAttack()
    TTTBots.Behaviors.ClearState(bot, "AttackTarget")
    -- Fire the AttackEnd hook so chatter (PostCombatRelief) can respond.
    if IsValid(lastTarget) then
        hook.Run("TTTBots.AttackEnd", bot, lastTarget)
    end
end

local FOCUS_DECAY = 0.02
function Attack.UpdateFocus(bot)
    local state = TTTBots.Behaviors.GetState(bot, "AttackTarget")
    local factor = -FOCUS_DECAY
    factor = factor * (bot.attackTarget ~= nil and -2.5 or 1)
    factor = factor * (bot:GetTraitMult("focus") or 1)
    state.attackFocus = (state.attackFocus or 0.1) + factor
    state.attackFocus = math.Clamp(state.attackFocus, 0.1, 1)
end

timer.Create("TTTBots_AttackFocus", 1 / TTTBots.Tickrate, 0, function()
    for _, bot in ipairs(TTTBots.Bots) do
        if not IsValid(bot) then continue end
        if not bot.components then continue end
        Attack.UpdateFocus(bot)
    end
end)
