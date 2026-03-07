---@class UseDNAScanner
TTTBots.Behaviors.UseDNAScanner = {}

local lib = TTTBots.Lib
---@class UseDNAScanner
local UseDNAScanner = TTTBots.Behaviors.UseDNAScanner
UseDNAScanner.Name = "UseDNAScanner"
UseDNAScanner.Description = "Using DNA scanner on corpses"
UseDNAScanner.Interruptible = true

local STATUS = TTTBots.STATUS

local DNA_MAXDIST      = 3000
local DNA_NEARBYIST    = 500
local DNA_SCANRADIUS   = 80

--- Returns the closest unscanned corpse this bot should scan, or nil.
function UseDNAScanner.GetUnscannedCorpse(bot)
	local corpses  = TTTBots.Match.Corpses
	local scanned  = bot.dnaScannedCorpses or {}
	local botPos   = bot:GetPos()
	local best, bestDist = nil, math.huge

	for _, corpse in pairs(corpses) do
		if not IsValid(corpse) then continue end
		if not lib.IsValidBody(corpse) then continue end
		if scanned[corpse] then continue end

		local dist = botPos:Distance(corpse:GetPos())
		if dist > DNA_MAXDIST then continue end

		local visible = bot:Visible(corpse)
		if not visible and dist > DNA_NEARBYIST then continue end

		if dist < bestDist then
			best     = corpse
			bestDist = dist
		end
	end

	return best
end

--- Validate the behavior: must be alive, detective-like, have the scanner, and have unscanned corpses.
function UseDNAScanner.Validate(bot)
	if not lib.IsPlayerAlive(bot) then return false end

	local role = TTTBots.Roles.GetRoleFor(bot)
	local isPolice = (role and role.AppearsPolice) or (bot:GetRoleStringRaw() == "detective")
	if not isPolice then return false end

	if not bot:HasWeapon("weapon_ttt_cse") then return false end

	if not UseDNAScanner.GetUnscannedCorpse(bot) then return false end

	return true
end

--- Called when the behavior is first selected.
function UseDNAScanner.OnStart(bot)
	bot.dnaScannedCorpses = bot.dnaScannedCorpses or {}
	bot.dnaState          = "navigating"
	bot.dnaScanTarget     = UseDNAScanner.GetUnscannedCorpse(bot)

	local chatter = bot:BotChatter()
	if chatter then
		chatter:On("ScanningBody", {}, false)
	end

	return STATUS.RUNNING
end

--- Called every tick while the behavior is running.
function UseDNAScanner.OnRunning(bot)
	local target = bot.dnaScanTarget
	if not (IsValid(target) and lib.IsValidBody(target)) then
		return STATUS.FAILURE
	end

	local loco    = bot:BotLocomotor()
	local distTo  = bot:GetPos():Distance(target:GetPos())

	-- ── NAVIGATING ───────────────────────────────────────────────────────────
	if bot.dnaState == "navigating" then
		loco:SetGoal(target:GetPos())
		loco:LookAt(target:GetPos())

		if distTo < DNA_SCANRADIUS then
			bot.dnaState = "scanning"
		end

		return STATUS.RUNNING
	end

	-- ── SCANNING ─────────────────────────────────────────────────────────────
	if bot.dnaState == "scanning" then
		loco:StopMoving()
		loco:LookAt(target:GetPos())

		-- Equip the DNA scanner
		bot:SelectWeapon("weapon_ttt_cse")

		-- Read corpse DNA data directly
		local killerEnt  = CORPSE.GetPlayer(target, "killer")
		local victimEnt  = CORPSE.GetPlayer(target)
		local victimName = CORPSE.GetPlayerNick(target) or "unknown"

		-- Mark this corpse as scanned before anything else
		bot.dnaScannedCorpses[target] = true

		-- Trigger discovery display
		CORPSE.ShowSearch(bot, target, false, false)

		-- Add evidence if killer is a valid, living enemy player
		if IsValid(killerEnt) and killerEnt:IsPlayer() and killerEnt ~= bot then
			local sameTeam = TTTBots.Roles.GetRoleFor(bot):GetTeam() == TTTBots.Roles.GetRoleFor(killerEnt):GetTeam()
			if not sameTeam then
				local evidence = bot:BotEvidence()
				if evidence then
					evidence:AddEvidence({
						type    = "DNA_MATCH",
						subject = killerEnt,
						victim  = victimEnt,
						detail  = "DNA scanner linked " .. killerEnt:Nick() .. " to " .. victimName,
						weight  = 10,
					})

					-- Share with teammates if supported
					if evidence.ShareEvidence then
						evidence:ShareEvidence(killerEnt)
					end
				end

				local chatter = bot:BotChatter()
				if chatter then
					chatter:On("DNAMatch", {
						suspect    = killerEnt:Nick(),
						victim     = victimName,
						suspectEnt = killerEnt,
					}, false)
				end
			end
		end

		return STATUS.SUCCESS
	end

	-- Fallback: shouldn't be reached
	return STATUS.FAILURE
end

--- Called on behavior success.
function UseDNAScanner.OnSuccess(bot)
end

--- Called on behavior failure.
function UseDNAScanner.OnFailure(bot)
end

--- Called when the behavior ends (either success or failure).
function UseDNAScanner.OnEnd(bot)
	bot.dnaScanTarget = nil
	bot.dnaState      = nil
end

-- ---------------------------------------------------------------------------
-- Round reset — clear the scanned-corpse tables at the start of each round
-- ---------------------------------------------------------------------------

hook.Add("TTTBeginRound", "TTTBots_DNAScanner_Reset", function()
	for _, bot in pairs(TTTBots.Bots or {}) do
		if IsValid(bot) then
			bot.dnaScannedCorpses = {}
		end
	end
end)
