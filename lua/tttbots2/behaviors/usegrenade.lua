--[[
UseGrenade — Situationally throws a grenade based on grenade type and context.
Sits in the Grenades priority group, evaluated after SelfDefense.
]]
---@class BUseGrenade
TTTBots.Behaviors.UseGrenade = {}

local lib = TTTBots.Lib

---@class BUseGrenade
local UseGrenade = TTTBots.Behaviors.UseGrenade
UseGrenade.Name = "UseGrenade"
UseGrenade.Description = "Throw a grenade situationally"
UseGrenade.Interruptible = true

local STATUS = TTTBots.STATUS

local GRENADE_COOLDOWN = 18       -- seconds between throws
local AIM_DOT_THRESHOLD = 0.85    -- ~30 degrees
local ENEMY_SCAN_RADIUS = 800     -- units to scan for enemies
local CLUSTER_RADIUS = 150        -- units between enemies to count as a cluster
local LEDGE_DROP_THRESHOLD = 200  -- units of vertical drop to consider an edge dangerous
local THROW_HOLD_DURATION = 0.6   -- seconds to hold IN_ATTACK before releasing to throw

--- Determine the logical grenade type from a weapon classname.
---@param classname string
---@return string grenadeType "incendiary"|"smoke"|"discombob"|"generic"
local function GetGrenadeType(classname)
	if not classname then return "generic" end
	local c = string.lower(classname)
	if string.find(c, "confgrenade") or string.find(c, "discombob") then
		return "discombob"
	elseif string.find(c, "smokegrenade") or string.find(c, "smoke") then
		return "smoke"
	elseif string.find(c, "firegrenade") or string.find(c, "fire") or string.find(c, "incendiary") then
		return "incendiary"
	end
	return "generic"
end

--- Collect all living non-ally players within radius of a position.
---@param bot Player
---@param radius number
---@return table enemies
local function getNearbyEnemies(bot, radius)
	local result = {}
	local myPos = bot:GetPos()
	for _, ply in pairs(player.GetAll()) do
		if not IsValid(ply) then continue end
		if not ply:Alive() then continue end
		if ply == bot then continue end
		if TTTBots.Roles.IsAllies(bot, ply) then continue end
		if myPos:Distance(ply:GetPos()) <= radius then
			result[#result + 1] = ply
		end
	end
	return result
end

--- Find the best throw position and reason for the bot's current grenade.
--- Returns a table {throwPos=Vector, type=string, reason=string} or nil.
---@param bot Player
---@return table|nil throwReason
function UseGrenade.GetBestThrowReason(bot)
	local inv = bot:BotInventory()
	if not inv then return nil end

	local wep, wepInfo = inv:GetGrenade()
	if not wep or not wepInfo then return nil end

	local grenadeType = GetGrenadeType(wepInfo.class)

	-- ── Incendiary ──────────────────────────────────────────────────────────────
	if grenadeType == "incendiary" then
		local enemies = getNearbyEnemies(bot, ENEMY_SCAN_RADIUS)

		-- Find a cluster of 2+ enemies within CLUSTER_RADIUS of each other.
		for i = 1, #enemies do
			local clusterMembers = { enemies[i] }
			for j = 1, #enemies do
				if i == j then continue end
				if enemies[i]:GetPos():Distance(enemies[j]:GetPos()) <= CLUSTER_RADIUS then
					clusterMembers[#clusterMembers + 1] = enemies[j]
				end
			end

			if #clusterMembers >= 2 then
				-- Compute centroid of cluster.
				local center = Vector(0, 0, 0)
				for _, e in ipairs(clusterMembers) do
					center = center + e:GetPos()
				end
				center = center / #clusterMembers
				return { throwPos = center, type = "incendiary", reason = "enemy_cluster" }
			end
		end

		-- Fallback: throw at feet of current attack target.
		local target = bot.attackTarget
		if IsValid(target) then
			return { throwPos = target:GetPos(), type = "incendiary", reason = "attack_target" }
		end

		return nil
	end

	-- ── Smoke ────────────────────────────────────────────────────────────────────
	if grenadeType == "smoke" then
		local attacker = bot.attackTarget

		-- Retreating: throw between self and attacker.
		if bot.isRetreating and IsValid(attacker) then
			local midpoint = (bot:GetPos() + attacker:GetPos()) * 0.5
			return { throwPos = midpoint, type = "smoke", reason = "retreating" }
		end

		-- Traitor who killed recently: obscure the area.
		local lastKillTime = bot.lastKillTime or 0
		local role = TTTBots.Roles.GetRoleFor(bot)
		local isTraitor = role and role.StartsFights
		if isTraitor and (CurTime() - lastKillTime) < 10 then
			return { throwPos = bot:GetPos(), type = "smoke", reason = "cover_kill" }
		end

		-- Late-round / overtime: throw toward nearest enemy group.
		local awareness = bot:BotRoundAwareness()
		local phase = awareness and awareness:GetPhase()
		if phase == "LATE" or phase == "OVERTIME" then
			local enemies = getNearbyEnemies(bot, ENEMY_SCAN_RADIUS)
			if #enemies > 0 then
				-- Pick the closest enemy.
				local closest = lib.GetClosest(enemies, bot:GetPos())
				if IsValid(closest) then
					return { throwPos = closest:GetPos(), type = "smoke", reason = "late_round" }
				end
			end
		end

		return nil
	end

	-- ── Discombob ────────────────────────────────────────────────────────────────
	if grenadeType == "discombob" then
		local target = bot.attackTarget
		if not IsValid(target) then return nil end

		-- Check if there is a significant drop near the target.
		local targetPos = target:GetPos()
		local probePos = targetPos + Vector(50, 0, 0)
		local traceResult = util.TraceLine({
			start  = probePos,
			endpos = probePos + Vector(0, 0, -500),
			mask   = MASK_SOLID_BRUSHONLY,
		})

		local dropDistance = (probePos - traceResult.HitPos):Length()
		if dropDistance > LEDGE_DROP_THRESHOLD then
			return { throwPos = targetPos, type = "discombob", reason = "near_ledge" }
		end

		return nil
	end

	-- ── Generic ──────────────────────────────────────────────────────────────────
	local target = bot.attackTarget
	if IsValid(target) then
		return { throwPos = target:GetPos(), type = "generic", reason = "attack_target" }
	end

	return nil
end

--- Validate the behavior: bot is alive, has a grenade, has a throw reason, and is off cooldown.
function UseGrenade.Validate(bot)
	if not TTTBots.Lib.IsPlayerAlive(bot) then return false end

	local inv = bot:BotInventory()
	if not inv then return false end

	local wep, wepInfo = inv:GetGrenade()
	if not wep then return false end

	-- Reject grenades with bogus ammo values (-1/-1 clip and 0 reserve).
	-- Some addon weapons (e.g. weapon_holyhand_grenade) report -1 clip and
	-- -1 max ammo, causing UseGrenade to loop endlessly because the grenade
	-- is never consumed. Skip these entirely.
	if wepInfo then
		local clip = wepInfo.clip or 0
		local maxAmmo = wepInfo.max_ammo or 0
		local reserveAmmo = wepInfo.ammo or 0
		if clip < 0 and maxAmmo < 0 and reserveAmmo <= 0 then return false end
	end

	-- Cooldown check.
	local lastToss = bot.lastGrenadeToss
	if lastToss and (CurTime() - lastToss) < GRENADE_COOLDOWN then return false end

	-- Anti-thrash: don't throw grenades unless the bot is already actively
	-- fighting (AttackTarget running) or retreating.  Without this check,
	-- FollowPlan's ATTACKANY sets bot.attackTarget which immediately makes
	-- UseGrenade valid, causing a constant FollowPlan→UseGrenade→Retreat loop.
	-- IMPORTANT: If UseGrenade is already the active behavior (mid-throw),
	-- skip this check so the throw can complete across multiple ticks.
	local lastBehavior = bot.lastBehavior
	local isSelf = lastBehavior and lastBehavior.Name == "UseGrenade"
	if not isSelf then
		local inCombat = lastBehavior and (
			lastBehavior.Name == "AttackTarget"
			or lastBehavior.Name == "SeekCover"
			or lastBehavior.Name == "Retreat"
		)
		if not inCombat then return false end
	end

	-- Validate that a sensible throw reason exists.
	local reason = UseGrenade.GetBestThrowReason(bot)
	if not reason then return false end

	return true
end

--- Called when the behavior first starts.
function UseGrenade.OnStart(bot)
	local inv = bot:BotInventory()
	if not inv then return STATUS.RUNNING end

	local loco = bot:BotLocomotor()

	-- Cache the throw reason so OnRunning doesn't recompute on every tick.
	bot.grenadeThrowReason = UseGrenade.GetBestThrowReason(bot)

	-- Record when we started so we can abort if the throw takes too long
	-- (e.g. weapon doesn't respond to IN_ATTACK due to unusual ammo setup).
	bot.grenadeStartTime = CurTime()

	-- Prevent AutoManageInventory from switching away from the grenade mid-throw.
	inv:PauseAutoSwitch()
	inv:EquipGrenade()

	-- Pause the attack-compatibility mechanic that periodically drops IN_ATTACK
	-- for modded gun support — it interrupts the grenade pin-pull hold.
	if loco then
		loco:PauseAttackCompat()
	end

	return STATUS.RUNNING
end

--- Called every tick while this behavior is running.
function UseGrenade.OnRunning(bot)
	if not TTTBots.Lib.IsPlayerAlive(bot) then return STATUS.FAILURE end

	local reason = bot.grenadeThrowReason
	if not reason then return STATUS.FAILURE end

	-- Timeout: if the throw has been running for more than 5 seconds, the
	-- weapon probably isn't responding to IN_ATTACK. Abort to avoid an
	-- infinite UseGrenade ↔ FollowPlan loop.
	if bot.grenadeStartTime and (CurTime() - bot.grenadeStartTime) > 5 then
		-- Put this grenade on extended cooldown so we don't immediately retry
		bot.lastGrenadeToss = CurTime() + 30
		return STATUS.FAILURE
	end

	local inv = bot:BotInventory()
	if not inv then return STATUS.FAILURE end

	local loco = bot:BotLocomotor()
	if not loco then return STATUS.FAILURE end

	-- Ensure grenade is equipped; wait if not yet in hand.
	local heldInfo = inv:GetHeldWeaponInfo()
	if not heldInfo or heldInfo.slot ~= "grenade" then
		inv:EquipGrenade()
		return STATUS.RUNNING
	end

	local throwPos = reason.throwPos
	if not throwPos then return STATUS.FAILURE end

	-- Face the throw position.
	loco:LookAt(throwPos)
	loco:StopMoving()

	-- Check if we are roughly aimed at the target position.
	local aimDir = (throwPos - bot:GetShootPos()):GetNormalized()
	local eyeDir = bot:GetAimVector()
	local dot = aimDir:Dot(eyeDir)

	if dot > AIM_DOT_THRESHOLD then
		-- Phase 1: hold IN_ATTACK to pull the pin.
		if not bot.grenadeHoldStart then
			bot.grenadeHoldStart = CurTime()
			loco:StartAttack()
		elseif (CurTime() - bot.grenadeHoldStart) >= THROW_HOLD_DURATION then
			-- Phase 2: release IN_ATTACK to throw.
			loco:StopAttack()
			bot.lastGrenadeToss = CurTime()
			bot.grenadeHoldStart = nil

			-- Fire chatter event (no-op if the event doesn't exist yet).
			local chatter = bot:BotChatter()
			if chatter and chatter.On then
				chatter:On("ThrowGrenade", {}, false)
			end

			return STATUS.SUCCESS
		end
	else
		-- Not aimed yet — stop any premature attack and keep turning.
		bot.grenadeHoldStart = nil
		loco:StopAttack()
	end

	-- Still turning to face (or holding pin) — keep running.
	return STATUS.RUNNING
end

--- Called when the behavior succeeds.
function UseGrenade.OnSuccess(bot)
end

--- Called when the behavior fails.
function UseGrenade.OnFailure(bot)
end

--- Called when the behavior ends (success or failure).
function UseGrenade.OnEnd(bot)
	bot.grenadeThrowReason = nil
	bot.grenadeHoldStart = nil
	bot.grenadeStartTime = nil
	local inv = bot:BotInventory()
	if inv then inv:ResumeAutoSwitch() end
	local loco = bot:BotLocomotor()
	if loco then
		loco:StopAttack()
		loco:ResumeAttackCompat()
	end
end
