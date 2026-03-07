---@class TrapPlayer
TTTBots.Behaviors.TrapPlayer = {}

local lib = TTTBots.Lib
local TrapPlayer = TTTBots.Behaviors.TrapPlayer
TrapPlayer.Name = "TrapPlayer"
TrapPlayer.Description = "Locking doors after a kill to trap the body"
TrapPlayer.Interruptible = true

local STATUS = TTTBots.STATUS

--- Find a lockable (unlocked) door near a position
---@param pos Vector
---@param radius number
---@return Entity|nil
local function findLockableDoorNear(pos, radius)
	radius = radius or 300
	local doorClasses = { "func_door", "func_door_rotating", "prop_door_rotating" }
	local bestDoor = nil
	local bestDist = radius

	for _, class in pairs(doorClasses) do
		for _, ent in pairs(ents.FindByClass(class)) do
			if not IsValid(ent) then continue end
			-- Skip already-locked doors
			if ent:GetNWBool("ttt2_door_locked", false) then continue end
			local dist = pos:Distance(ent:GetPos())
			if dist < bestDist then
				bestDoor = ent
				bestDist = dist
			end
		end
	end

	return bestDoor
end

--- Validate: bot is traitor-team, killed recently, there's a nearby unlocked door
---@param bot Bot
---@return boolean
function TrapPlayer.Validate(bot)
	-- Only traitor-team
	local role = TTTBots.Roles.GetRoleFor(bot)
	if not (role and role.StartsFights) then return false end

	if not TTTBots.Lib.IsPlayerAlive(bot) then return false end

	-- Must have killed recently (within 8 seconds)
	local lastKill = bot.lastKillTime or 0
	if CurTime() - lastKill > 8 then return false end

	-- Cooldown: don't spam
	if bot.lastTrapAttempt and CurTime() - bot.lastTrapAttempt < 15 then return false end

	-- Find a lockable door near the bot
	local nearDoor = findLockableDoorNear(bot:GetPos(), 350)
	if not IsValid(nearDoor) then return false end

	bot.trapDoorTarget = nearDoor
	return true
end

---@param bot Bot
---@return BStatus
function TrapPlayer.OnStart(bot)
	bot.trapState = "navigating"
	return STATUS.RUNNING
end

---@param bot Bot
---@return BStatus
function TrapPlayer.OnRunning(bot)
	local doorEnt = bot.trapDoorTarget
	if not IsValid(doorEnt) then return STATUS.FAILURE end

	local loco = bot:BotLocomotor()
	if not loco then return STATUS.FAILURE end

	local doorPos = doorEnt:GetPos()
	local distToDoor = bot:GetPos():Distance(doorPos)

	if bot.trapState == "navigating" then
		loco:SetGoal(doorPos)
		loco:LookAt(doorPos)

		if distToDoor <= 120 then
			bot.trapState = "locking"
		end
		return STATUS.RUNNING
	end

	if bot.trapState == "locking" then
		loco:StopMoving()

		-- Lock the door via TTT2 library
		if loco:LockDoor(doorEnt) then
			bot.lastTrapAttempt = CurTime()
			return STATUS.SUCCESS
		else
			-- Fallback: use entity input directly
			doorEnt:Fire("Lock", "", 0)
			bot.lastTrapAttempt = CurTime()
			return STATUS.SUCCESS
		end
	end

	return STATUS.FAILURE
end

---@param bot Bot
function TrapPlayer.OnSuccess(bot) end

---@param bot Bot
function TrapPlayer.OnFailure(bot) end

---@param bot Bot
function TrapPlayer.OnEnd(bot)
	bot.trapDoorTarget = nil
	bot.trapState = nil
end
