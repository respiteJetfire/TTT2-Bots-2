---@class UseDNAScanner
TTTBots.Behaviors.UseDNAScanner = {}

local lib = TTTBots.Lib
---@class UseDNAScanner
local UseDNAScanner = TTTBots.Behaviors.UseDNAScanner
UseDNAScanner.Name = "UseDNAScanner"
UseDNAScanner.Description = "Navigate to corpses and scan them with the DNA scanner; then react if the radar marker points to something visible"
UseDNAScanner.Interruptible = true

local STATUS = TTTBots.STATUS

-- Distance constants
local DNA_MAXDIST    = 3000  -- Won't consider a corpse farther than this
local DNA_NEARBYIST  = 500   -- Corpse must be visible OR closer than this
local DNA_SCANRADIUS = 120   -- How close the bot needs to be to fire the scanner at a corpse
local DNA_FIRE_RANGE = 175   -- Max trace range of weapon_ttt_wtester (matches SWEP.Range)
local DNA_AIM_DOT    = 0.96  -- Minimum dot product to consider "aimed at corpse"

-- How long to wait after firing before accepting the sample was taken
local DNA_FIRE_COOLDOWN = 1.2

-- How often (seconds) the background Think checks active scanner slots for visible targets
local DNA_RADAR_CHECK_INTERVAL = 30

-- Distance within which an entity pointed at by a slot marker is considered "in sight"
local DNA_MARKER_SIGHT_DIST = 1200

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Return the bot's DNA scanner weapon entity, or nil.
---@param bot Player
---@return Entity|nil
local function GetScanner(bot)
	return bot:HasWeapon("weapon_ttt_wtester") and bot:GetWeapon("weapon_ttt_wtester") or nil
end

--- Returns the closest unscanned corpse this bot should scan, or nil.
---@param bot Player
---@return Entity|nil
function UseDNAScanner.GetUnscannedCorpse(bot)
	local corpses = TTTBots.Match.Corpses
	local scanned = bot.dnaScannedCorpses or {}
	local botPos  = bot:GetPos()
	local best, bestDist = nil, math.huge

	for _, corpse in pairs(corpses) do
		if not IsValid(corpse) then continue end
		if not lib.IsValidBody(corpse) then continue end
		-- Skip corpses whose DNA is already in the scanner slots
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

--- Returns the number of used scanner slots on the bot's DNA scanner.
---@param scanner Entity
---@return number
local function GetUsedSlotCount(scanner)
	local count = 0
	for _, v in pairs(scanner.ItemSamples or {}) do
		if v then count = count + 1 end
	end
	return count
end

--- Returns the max slot count for the scanner (server global, defaults to 4).
---@return number
local function GetMaxSlots()
	return GetGlobalBool("ttt2_dna_scanner_slots") or 4
end

--- True if the scanner has room for at least one more sample.
---@param scanner Entity
---@return boolean
local function ScannerHasRoom(scanner)
	return GetUsedSlotCount(scanner) < GetMaxSlots()
end

--- Check visibility via a traceline from the bot's eye to the target's OBB center.
---@param bot Player
---@param targetEnt Entity
---@return boolean
local function BotCanSeeEnt(bot, targetEnt)
	if not IsValid(targetEnt) then return false end
	local start = bot:EyePos()
	local dest  = targetEnt:LocalToWorld(targetEnt:OBBCenter())
	local tr = util.TraceLine({
		start  = start,
		endpos = dest,
		filter = { bot, targetEnt },
		mask   = MASK_VISIBLE_AND_NPCS,
	})
	return tr.Fraction > 0.98
end

-- ---------------------------------------------------------------------------
-- Background radar-reaction hook
-- Runs every DNA_RADAR_CHECK_INTERVAL seconds; looks at all detective bots'
-- DNA scanners and checks if any CachedTarget is currently visible.
-- ---------------------------------------------------------------------------

local _lastRadarCheck = 0

hook.Add("Think", "TTTBots_DNAScanner_RadarCheck", function()
	if not SERVER then return end
	if not TTTBots.Match.RoundActive then return end
	if CurTime() - _lastRadarCheck < DNA_RADAR_CHECK_INTERVAL then return end
	_lastRadarCheck = CurTime()

	for _, bot in pairs(TTTBots.Bots or {}) do
		if not IsValid(bot) then continue end
		if not lib.IsPlayerAlive(bot) then continue end

		local scanner = GetScanner(bot)
		if not IsValid(scanner) then continue end

		local slots     = GetMaxSlots()
		local evidence  = bot:BotEvidence()
		local morality  = bot:BotMorality()
		local chatter   = bot:BotChatter()
		local botPos    = bot:GetPos()
		local botRole   = TTTBots.Roles.GetRoleFor(bot)

		for i = 1, slots do
			local suspect = scanner.ItemSamples and scanner.ItemSamples[i]
			local target  = scanner.CachedTargets and scanner.CachedTargets[i]

			if not IsValid(suspect) then continue end
			if not IsValid(target) then continue end

			local targetPos  = target:LocalToWorld(target:OBBCenter())
			local dist       = botPos:Distance(targetPos)
			if dist > DNA_MARKER_SIGHT_DIST then continue end

			-- Determine what the target actually is:
			--   a) Alive player   → murderer still alive, strong evidence
			--   b) Ragdoll/prop   → murder weapon or dead suspect, moderate evidence
			local isAlivePlayer = target:IsPlayer() and lib.IsPlayerAlive(target) and target ~= bot
			local isRagdollOrProp = (not target:IsPlayer()) and IsValid(target)

			if not (isAlivePlayer or isRagdollOrProp) then continue end

			-- Line-of-sight check
			if not BotCanSeeEnt(bot, target) then continue end

			-- Same-team guard
			if isAlivePlayer then
				local sameTeam = botRole and botRole:GetTeam() == TTTBots.Roles.GetRoleFor(target):GetTeam()
				if sameTeam then continue end
			end

			local victimName = IsValid(suspect) and suspect:Nick() or "unknown"

			-- ── a) Alive suspect spotted via marker ──────────────────────────
			if isAlivePlayer then
				if evidence then
					evidence:AddEvidence({
						type    = "DNA_MATCH",
						subject = target,
						detail  = "DNA scanner marker locked onto " .. target:Nick() .. " (linked to death of " .. victimName .. ")",
						weight  = 10,
					})

					-- Share with any nearby allies
					for _, ally in pairs(TTTBots.Bots or {}) do
						if IsValid(ally) and ally ~= bot and lib.IsPlayerAlive(ally) then
							local allyRole = TTTBots.Roles.GetRoleFor(ally)
							if allyRole and allyRole:GetTeam() == botRole:GetTeam() then
								local allyEvidence = ally:BotEvidence()
								if allyEvidence then allyEvidence:AddEvidence({
									type    = "DNA_MATCH",
									subject = target,
									detail  = "DNA scanner (shared): " .. target:Nick() .. " linked to death of " .. victimName,
									weight  = 8,
								}) end
							end
						end
					end
				end

				if morality then
					morality:ChangeSuspicion(target, "Kill", 2)
				end

				if chatter and chatter.On then
					chatter:On("DNAMatch", {
						suspect    = target:Nick(),
						victim     = victimName,
						suspectEnt = target,
					}, false)
				end

			-- ── b) Murder weapon / ragdoll spotted via marker ─────────────────
			elseif isRagdollOrProp then
				-- The weapon/ragdoll itself doesn't add suspect evidence directly,
				-- but we log it so the bot knows where to look / investigate.
				if evidence and IsValid(suspect) and suspect:IsPlayer() then
					evidence:AddEvidence({
						type    = "DNA_MATCH",
						subject = suspect,
						detail  = "DNA scanner marker pointed to murder weapon / remains near " .. suspect:Nick() .. "'s linked scene",
						weight  = 6,
					})
				end

				if chatter and chatter.On then
					chatter:On("SpottedMurderWeapon", {
						victim = victimName,
					}, false)
				end
			end
		end
	end
end)

-- ---------------------------------------------------------------------------
-- TTTFoundDNA hook — fired by weapon_ttt_wtester itself when a sample is stored
-- ---------------------------------------------------------------------------

hook.Add("TTTFoundDNA", "TTTBots_DNAScanner_SampleLogged", function(finder, suspect, scannedEnt)
	if not (IsValid(finder) and finder:IsBot()) then return end
	if not IsValid(suspect) then return end

	local evidence = finder:BotEvidence()
	local chatter  = finder:BotChatter()
	local botRole  = TTTBots.Roles.GetRoleFor(finder)

	local victimName = (IsValid(scannedEnt) and scannedEnt:IsPlayerRagdoll())
		and (CORPSE.GetPlayerNick(scannedEnt) or "unknown")
		or  (IsValid(scannedEnt) and scannedEnt:GetClass() or "unknown")

	-- Mark this corpse/entity as "scanned" so the behavior doesn't re-approach it
	finder.dnaScannedCorpses = finder.dnaScannedCorpses or {}
	if scannedEnt:IsPlayerRagdoll() then
		finder.dnaScannedCorpses[scannedEnt] = true
	end

	if not evidence then return end
	if not IsValid(suspect) or not suspect:IsPlayer() then return end
	if suspect == finder then return end

	local sameTeam = botRole and botRole:GetTeam() == TTTBots.Roles.GetRoleFor(suspect):GetTeam()
	if sameTeam then return end

	evidence:AddEvidence({
		type    = "DNA_MATCH",
		subject = suspect,
		detail  = "DNA scanner linked " .. suspect:Nick() .. " to " .. victimName,
		weight  = 10,
	})

	if evidence.ShareEvidence then
		evidence:ShareEvidence(suspect)
	end

	if chatter and chatter.On then
		chatter:On("DNAMatch", {
			suspect    = suspect:Nick(),
			victim     = victimName,
			suspectEnt = suspect,
		}, false)
	end
end)

-- ---------------------------------------------------------------------------
-- Behavior: scan nearby corpses with the DNA scanner
-- ---------------------------------------------------------------------------

--- Validate the behavior: must be alive, detective-like, have the scanner, have room + unscanned corpses.
function UseDNAScanner.Validate(bot)
	if not lib.IsPlayerAlive(bot) then return false end

	local role     = TTTBots.Roles.GetRoleFor(bot)
	local isPolice = (role and role.AppearsPolice) or (bot:GetRoleStringRaw() == "detective")
	if not isPolice then return false end

	local scanner = GetScanner(bot)
	if not IsValid(scanner) then return false end

	-- Don't re-scan if slots are full
	if not ScannerHasRoom(scanner) then return false end

	if not UseDNAScanner.GetUnscannedCorpse(bot) then return false end

	return true
end

--- Called when the behavior is first selected.
function UseDNAScanner.OnStart(bot)
	bot.dnaScannedCorpses = bot.dnaScannedCorpses or {}
	bot.dnaState          = "navigating"
	bot.dnaScanTarget     = UseDNAScanner.GetUnscannedCorpse(bot)
	bot.dnaFireTime       = nil  -- timestamp of last primary fire attempt

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

	local loco   = bot:BotLocomotor()
	local distTo = bot:GetPos():Distance(target:GetPos())

	-- ── NAVIGATING ─────────────────────────────────────────────────────────
	if bot.dnaState == "navigating" then
		loco:SetGoal(target:GetPos())
		loco:LookAt(target:GetPos())

		if distTo < DNA_SCANRADIUS then
			bot.dnaState = "scanning"
			-- Make sure we have the scanner equipped when we arrive
			bot:SelectWeapon("weapon_ttt_wtester")
		end

		return STATUS.RUNNING
	end

	-- ── SCANNING ───────────────────────────────────────────────────────────
	if bot.dnaState == "scanning" then
		loco:StopMoving()

		local scanner = GetScanner(bot)
		if not IsValid(scanner) then return STATUS.FAILURE end

		-- If slots got full while we were walking, bail
		if not ScannerHasRoom(scanner) then return STATUS.FAILURE end

		-- Equip the scanner
		if bot:GetActiveWeapon() ~= scanner then
			bot:SelectWeapon("weapon_ttt_wtester")
			return STATUS.RUNNING
		end

		-- Aim at the corpse's OBB center
		local aimPos = target:LocalToWorld(target:OBBCenter())
		loco:LookAt(aimPos)

		-- Check if we are aimed well enough
		local aimDir = (aimPos - bot:EyePos()):GetNormalized()
		local eyeDir = bot:GetAimVector()
		local dot    = aimDir:Dot(eyeDir)

		-- Also verify we are close enough for the scanner's trace
		if distTo > DNA_FIRE_RANGE then
			-- Back to navigating if corpse was too far
			bot.dnaState = "navigating"
			return STATUS.RUNNING
		end

		-- Wait for previous fire cooldown before firing again
		local fireTime = bot.dnaFireTime or 0
		if dot >= DNA_AIM_DOT and (CurTime() - fireTime) > DNA_FIRE_COOLDOWN then
			-- Fire primary attack (weapon_ttt_wtester:PrimaryAttack traces and calls GatherDNA)
			loco:StartAttack()
			bot.dnaFireTime = CurTime()
			-- Let the weapon/hook feedback handle marking the corpse as scanned.
			-- We mark it locally too so we don't spin here forever.
			bot.dnaScannedCorpses[target] = true
			return STATUS.SUCCESS
		end

		return STATUS.RUNNING
	end

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
	bot.dnaFireTime   = nil
end

-- ---------------------------------------------------------------------------
-- Round reset — clear the scanned-corpse tables at the start of each round
-- ---------------------------------------------------------------------------

hook.Add("TTTBeginRound", "TTTBots_DNAScanner_Reset", function()
	_lastRadarCheck = 0
	for _, bot in pairs(TTTBots.Bots or {}) do
		if IsValid(bot) then
			bot.dnaScannedCorpses = {}
		end
	end
end)
