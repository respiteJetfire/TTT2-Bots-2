--- sv_karma_awareness.lua
--- Karma awareness helpers for the bot morality system.
--- Provides pre-attack karma checks so bots avoid auto-kick from RDM penalties.

TTTBots.Morality = TTTBots.Morality or {}
local KarmaAwareness = TTTBots.Morality

local Arb = TTTBots.Morality

-- ---------------------------------------------------------------------------
-- Karma helpers
-- ---------------------------------------------------------------------------

--- Return the bot's current live karma, or 1000 if the KARMA system is unavailable.
---@param bot Player
---@return number
function KarmaAwareness.GetLiveKarma(bot)
	if KARMA and KARMA.GetLiveKarma then
		return KARMA.GetLiveKarma(bot) or 1000
	end
	return 1000
end

--- Return a risk level string based on the bot's current karma and personality traits.
--- Possible values: "normal", "cautious", "recovery"
---@param bot Player
---@return string
function KarmaAwareness.GetKarmaRiskLevel(bot)
	-- If karma system is disabled, there is no risk.
	local karmaConVar = GetConVar("ttt_karma")
	if karmaConVar and karmaConVar:GetInt() == 0 then
		return "normal"
	end

	local karma = KarmaAwareness.GetLiveKarma(bot)

	-- Base thresholds
	local lowAmount = 450
	local karmaLowConVar = GetConVar("ttt_karma_low_amount")
	if karmaLowConVar then
		lowAmount = karmaLowConVar:GetInt()
	end

	local recoveryThreshold = lowAmount + 100  -- default 550
	local cautiousThreshold = 700

	-- Personality trait adjustments
	-- rdmer and Hothead care less — raise thresholds by +100 (harder to trigger caution)
	-- cautious and pacifist care more — lower thresholds by -50 (easier to trigger caution)
	local traitOffset = 0
	if IsValid(bot) then
		if bot:HasTrait("rdmer")   then traitOffset = traitOffset + 100 end
		if bot:HasTrait("Hothead") then traitOffset = traitOffset + 100 end
		if bot:HasTrait("cautious") then traitOffset = traitOffset - 50 end
		if bot:HasTrait("pacifist") then traitOffset = traitOffset - 50 end
	end

	recoveryThreshold = recoveryThreshold + traitOffset
	cautiousThreshold = cautiousThreshold + traitOffset

	if karma < recoveryThreshold then
		return "recovery"
	elseif karma < cautiousThreshold then
		return "cautious"
	end
	return "normal"
end

--- Return the minimum Arb.PRIORITY tier required for an attack to be allowed,
--- based on the bot's current karma risk level.
---@param bot Player
---@return number
function KarmaAwareness.GetMinimumPriorityForAttack(bot)
	local riskLevel = KarmaAwareness.GetKarmaRiskLevel(bot)
	if riskLevel == "recovery" then
		return Arb.PRIORITY.SELF_DEFENSE       -- 5 — only self-defense
	elseif riskLevel == "cautious" then
		return Arb.PRIORITY.SUSPICION_THRESHOLD -- 2 — need evidence
	end
	return Arb.PRIORITY.OPPORTUNISTIC           -- 1 — can attack freely
end

--- Estimate the karma penalty the bot would incur for killing the given target.
---@param bot Player
---@param target Player
---@return number
function KarmaAwareness.EstimateKillPenalty(bot, target)
	if KARMA and KARMA.GetKillPenalty then
		local targetKarma = KarmaAwareness.GetLiveKarma(target)
		local penalty = KARMA.GetKillPenalty(targetKarma)
		if penalty then return penalty end
	end
	-- Fallback: ~2% of target karma, minimum 25
	local targetKarma = (KARMA and KARMA.GetLiveKarma and KARMA.GetLiveKarma(target)) or 1000
	return math.max(25, math.floor(targetKarma * 0.02))
end

--- Returns true if killing `target` would drop the bot's karma below the auto-kick threshold.
---@param bot Player
---@param target Player
---@return boolean
function KarmaAwareness.WouldKillTriggerAutoKick(bot, target)
	-- If auto-kick on low karma is disabled, never block.
	local autokickConVar = GetConVar("ttt_karma_low_autokick")
	if autokickConVar and autokickConVar:GetInt() == 0 then
		return false
	end

	local lowAmount = 450
	local karmaLowConVar = GetConVar("ttt_karma_low_amount")
	if karmaLowConVar then
		lowAmount = karmaLowConVar:GetInt()
	end

	local currentKarma = KarmaAwareness.GetLiveKarma(bot)
	local penalty      = KarmaAwareness.EstimateKillPenalty(bot, target)
	return (currentKarma - penalty) < lowAmount
end

--- Central pre-attack gate. Call before any attack is committed.
--- Returns true to allow the attack, false to block it.
---@param bot Player
---@param requestedPriority number
---@return boolean
function KarmaAwareness.CheckPreAttack(bot, requestedPriority)
	-- If karma system is disabled, never interfere.
	local karmaConVar = GetConVar("ttt_karma")
	if karmaConVar and karmaConVar:GetInt() == 0 then
		return true
	end

	local minPriority = KarmaAwareness.GetMinimumPriorityForAttack(bot)

	-- Block if the attack priority is below the karma-adjusted minimum.
	if requestedPriority < minPriority then
		return false
	end

	-- In recovery mode, also block any non-self-defense attack that would trigger auto-kick.
	local riskLevel = KarmaAwareness.GetKarmaRiskLevel(bot)
	local inRecoveryNonSD = (riskLevel == "recovery") and (requestedPriority < Arb.PRIORITY.SELF_DEFENSE)
	if inRecoveryNonSD and IsValid(bot) then
		local attackTarget = bot.attackTarget
		if IsValid(attackTarget) and KarmaAwareness.WouldKillTriggerAutoKick(bot, attackTarget) then
			return false
		end
	end

	return true
end
