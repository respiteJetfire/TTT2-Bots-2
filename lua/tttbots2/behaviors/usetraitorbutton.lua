--- Activates traitor buttons on the map when enemies are nearby.

---@class UseTraitorButton
TTTBots.Behaviors.UseTraitorButton = {}

local lib = TTTBots.Lib

---@class UseTraitorButton
local UseTraitorButton = TTTBots.Behaviors.UseTraitorButton
UseTraitorButton.Name = "UseTraitorButton"
UseTraitorButton.Description = "Activating traitor buttons on the map"
UseTraitorButton.Interruptible = true

local STATUS = TTTBots.STATUS

--- Score a traitor button for the given bot. Returns -1 if the button should not be used.
---@param bot Bot
---@param ent Entity
---@return number
local function scoreButton(bot, ent)
	if not IsValid(ent) then return -1 end

	-- Check role can use this button
	if ent.PlayerRoleCanUse and not ent:PlayerRoleCanUse(bot) then return -1 end

	-- Check usability
	local isLocked = ent.GetLocked and ent:GetLocked()
	local nextUse = ent.GetNextUseTime and ent:GetNextUseTime() or 0
	if isLocked or nextUse > CurTime() then return -1 end

	local buttonPos = ent:GetPos()
	local distToBot = bot:GetPos():Distance(buttonPos)

	-- Must be within reasonable range (2000 units)
	if distToBot > 2000 then return -1 end

	-- Score: base on nearby enemies
	local enemiesNear = 0
	for _, ply in pairs(player.GetAll()) do
		if not IsValid(ply) or not ply:Alive() then continue end
		if ply == bot then continue end
		if TTTBots.Roles.IsAllies(bot, ply) then continue end
		if buttonPos:Distance(ply:GetPos()) <= 600 then
			enemiesNear = enemiesNear + 1
		end
	end

	-- Need at least 1 enemy nearby to bother
	if enemiesNear == 0 then return -1 end

	local score = enemiesNear * 5

	-- Penalize if bot has witness risk (enemies can see the button area)
	for _, ply in pairs(player.GetAll()) do
		if not IsValid(ply) or not ply:Alive() then continue end
		if TTTBots.Roles.IsAllies(bot, ply) then continue end
		local tr = util.TraceLine({
			start = ply:EyePos(),
			endpos = buttonPos + Vector(0, 0, 16),
			filter = ply,
			mask = MASK_VISIBLE,
		})
		if not tr.Hit then
			score = score - 3 -- witness can see button area
		end
	end

	-- Prefer closer buttons (up to 10 bonus)
	score = score + math.max(0, 10 - (distToBot / 200))

	return score
end

--- Validate the behavior
function UseTraitorButton.Validate(bot)
	-- Only traitor-team roles
	local role = TTTBots.Roles.GetRoleFor(bot)
	if not (role and role.StartsFights) then return false end

	-- Must be alive
	if not lib.IsPlayerAlive(bot) then return false end

	-- Cooldown: only try every 20 seconds
	if bot.lastTraitorButtonAttempt and CurTime() - bot.lastTraitorButtonAttempt < 20 then return false end

	-- Find a usable button with score > 0
	local buttons = ents.FindByClass("ttt_traitor_button")
	if not buttons or #buttons == 0 then return false end

	local bestScore = 0
	local bestButton = nil
	for _, ent in pairs(buttons) do
		local s = scoreButton(bot, ent)
		if s > bestScore then
			bestScore = s
			bestButton = ent
		end
	end

	if not bestButton then return false end

	bot.traitorButtonTarget = bestButton
	return true
end

--- Called when the behavior is started
function UseTraitorButton.OnStart(bot)
	bot.traitorButtonState = "navigating"
	bot.traitorButtonWaitStart = nil
	return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function UseTraitorButton.OnRunning(bot)
	local button = bot.traitorButtonTarget
	if not IsValid(button) then return STATUS.FAILURE end

	local loco = bot:BotLocomotor()
	if not loco then return STATUS.FAILURE end

	local buttonPos = button:GetPos()
	local distToButton = bot:GetPos():Distance(buttonPos)

	local usableRange = (button.GetUsableRange and button:GetUsableRange()) or 100

	if bot.traitorButtonState == "navigating" then
		loco:SetGoal(buttonPos)
		loco:LookAt(buttonPos + Vector(0, 0, 32))

		if distToButton <= usableRange + 20 then
			bot.traitorButtonState = "waiting"
			bot.traitorButtonWaitStart = CurTime()
		end
		return STATUS.RUNNING
	end

	if bot.traitorButtonState == "waiting" then
		loco:StopMoving()
		loco:LookAt(buttonPos + Vector(0, 0, 32))

		-- Wait up to 4 seconds for enemies to be in range
		local waited = CurTime() - (bot.traitorButtonWaitStart or CurTime())

		-- Count nearby enemies
		local enemiesNear = 0
		for _, ply in pairs(player.GetAll()) do
			if not IsValid(ply) or not ply:Alive() then continue end
			if ply == bot then continue end
			if TTTBots.Roles.IsAllies(bot, ply) then continue end
			if buttonPos:Distance(ply:GetPos()) <= 700 then
				enemiesNear = enemiesNear + 1
			end
		end

		-- Activate if: enemies nearby OR we've waited long enough
		if enemiesNear >= 1 or waited >= 4 then
			-- Give up rather than waste it if nobody arrived after 4s
			if waited >= 4 and enemiesNear == 0 then
				bot.lastTraitorButtonAttempt = CurTime()
				return STATUS.FAILURE
			end

			-- Activate the button
			if button.TraitorUse then
				button:TraitorUse(bot)
			else
				-- Fallback: use the entity directly
				bot:Use(button)
			end

			bot.lastTraitorButtonAttempt = CurTime()

			local chatter = bot:BotChatter()
			if chatter and chatter.On then
				chatter:On("UseTraitorButton", {}, true)
			end

			return STATUS.SUCCESS
		end

		return STATUS.RUNNING
	end

	return STATUS.FAILURE
end

--- Called when the behavior returns a success state
function UseTraitorButton.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function UseTraitorButton.OnFailure(bot)
end

--- Called when the behavior ends
function UseTraitorButton.OnEnd(bot)
	bot.traitorButtonTarget = nil
	bot.traitorButtonState = nil
	bot.traitorButtonWaitStart = nil
end
