--- sv_swep_threat_response.lua
--- Periodic scan that makes bots react to nearby players wielding
--- high-danger active SWEPs:
---   • Smart Bullets buff   (ttt2_smart_bullets_active)
---   • Peacekeeper High Noon (weapon_ttt_peacekeeper + HighNoonActive())
---
--- For each bot the scan:
---   1. Detects any visible hostile holding an active SWEP phase.
---   2. Applies a reaction delay scaled by difficulty + personality.
---   3. Makes a fight-or-flight decision based on personality traits,
---      difficulty, health, and distance.
---   4. Writes the result onto the bot:
---        bot.swepThreatTarget   = <Entity|nil>  the threatening player
---        bot.swepThreatDecision = "attack"|"retreat"|nil
---      PanicRetreat and AttackTarget read these fields each tick.

if not SERVER then return end

TTTBots.SwepThreatResponse = TTTBots.SwepThreatResponse or {}
local STR = TTTBots.SwepThreatResponse
local lib = TTTBots.Lib

--- How often (in seconds) the full scan runs across all bots.
--- Kept coarse so it doesn't add measurable overhead.
local SCAN_INTERVAL = 0.35

--- Distance (units) within which a SWEP threat triggers a reaction.
--- Outside this, bots don't care (they can't see the glow anyway).
local THREAT_RADIUS = 2000

--- After detecting a threat, bots wait this many seconds before acting.
--- The actual value is scaled further by difficulty and personality.
local BASE_REACTION_DELAY = 0.4  -- seconds at difficulty 3, neutral personality

--- Difficulty → reaction delay multiplier (mirrors locomotor scaling).
local DIFFICULTY_REACTION_MULT = {
    [1] = 3.5,   -- Very easy: very slow to notice/decide
    [2] = 2.0,   -- Easy
    [3] = 1.0,   -- Normal: baseline
    [4] = 0.45,  -- Hard: fast
    [5] = 0.0,   -- Very hard: instant
}

--- Returns true if the given player is currently in an active dangerous SWEP phase.
--- Works on both human players and bots.
---@param ply Player
---@return boolean isActive, string|nil threatType
local function IsInActiveSWEPPhase(ply)
    if not IsValid(ply) then return false, nil end
    if not ply:Alive() then return false, nil end

    -- Smart Bullets buff (server-side flag set by weapon_ttt2_smart_bullets)
    if ply.ttt2_smart_bullets_active then
        return true, "SMART_BULLETS"
    end

    -- Peacekeeper / High Noon
    local wep = ply:GetActiveWeapon()
    if IsValid(wep) and wep:GetClass() == "weapon_ttt_peacekeeper" then
        if wep.HighNoonActive and wep:HighNoonActive() then
            return true, "HIGH_NOON"
        end
    end

    return false, nil
end

--- Compute the personalised reaction delay for a bot.
---@param bot Player
---@return number delaySeconds
local function GetReactionDelay(bot)
    local difficulty = lib.GetConVarInt("difficulty") or 3
    local diffMult = DIFFICULTY_REACTION_MULT[difficulty] or 1.0

    -- Personality modifiers
    local extraMult = 1.0
    if bot.HasTrait then
        if bot:HasTrait("hothead")    then extraMult = extraMult * 0.4 end  -- hotheads react instantly
        if bot:HasTrait("aggressive") then extraMult = extraMult * 0.6 end
        if bot:HasTrait("tryhard")    then extraMult = extraMult * 0.5 end
        if bot:HasTrait("cautious")   then extraMult = extraMult * 1.4 end  -- cautious → more nervous = actually faster
        if bot:HasTrait("cowardly")   then extraMult = extraMult * 1.6 end  -- cowardly → froze with fear, slow
    end

    -- Add a small random jitter (±20%) so all bots don't react at the same frame
    local jitter = math.Rand(0.8, 1.2)

    return BASE_REACTION_DELAY * diffMult * extraMult * jitter
end

--- Decide whether this bot should fight or flee from the threat.
--- Returns "attack" or "retreat".
---@param bot Player
---@param threat Player
---@param threatType string "SMART_BULLETS"|"HIGH_NOON"
---@return string decision
local function MakeFightOrFlightDecision(bot, threat, threatType)
    local difficulty = lib.GetConVarInt("difficulty") or 3
    local hp = bot:Health()
    local dist = bot:GetPos():Distance(threat:GetPos())

    -- ── Hard gates ────────────────────────────────────────────────────
    -- Critically low HP → always flee regardless of personality
    if hp < 20 then return "retreat" end

    -- Hothead never retreats
    if bot.HasTrait and bot:HasTrait("hothead") then return "attack" end

    -- Unarmed bots → always flee
    local inv = bot:BotInventory and bot:BotInventory()
    if inv and inv.HasNoWeaponAvailable and inv:HasNoWeaponAvailable(false) then
        return "retreat"
    end

    -- ── Personality score ─────────────────────────────────────────────
    -- Positive score → prefer attack; negative → prefer retreat.
    -- Range is roughly [-4, +4] before difficulty scaling.
    local score = 0

    if bot.HasTrait then
        if bot:HasTrait("aggressive")  then score = score + 2   end
        if bot:HasTrait("tryhard")     then score = score + 2   end
        if bot:HasTrait("risktaker")   then score = score + 1   end
        if bot:HasTrait("hothead")     then score = score + 2   end  -- redundant but fine
        if bot:HasTrait("cautious")    then score = score - 1   end
        if bot:HasTrait("cowardly")    then score = score - 2   end
        if bot:HasTrait("fearful")     then score = score - 2   end
    end

    -- Higher difficulty → bots are better at assessing the threat, so
    -- they make a more "correct" decision. At diff 5 the scoring is pure;
    -- at diff 1 it's heavily randomised.
    local diffNoise = math.Rand(-1, 1) * (5 - difficulty) * 0.8
    score = score + diffNoise

    -- Low health makes bots more risk-averse
    if hp < 50 then score = score - 1 end
    if hp < 35 then score = score - 1 end

    -- Close-range with High Noon → more dangerous (harder to dodge bullets)
    if threatType == "HIGH_NOON" and dist < 600 then score = score - 1 end

    -- Traitors / killer-roles fight back more readily (they have better weapons)
    local role = TTTBots.Roles and TTTBots.Roles.GetRoleFor(bot)
    local isKiller = role and role.GetTeamName
        and role:GetTeamName() ~= "innocent"
        and role:GetTeamName() ~= "none"
    if isKiller then score = score + 1 end

    return score >= 0 and "attack" or "retreat"
end

--- Main per-bot scan: detects active SWEP phases in range and sets
--- bot.swepThreatTarget / bot.swepThreatDecision.
---@param bot Player
local function ScanBotForSwepThreat(bot)
    if not IsValid(bot) then return end
    if not lib.IsPlayerAlive(bot) then return end
    if not TTTBots.Match.IsRoundActive() then return end

    local botPos = bot:GetPos()
    local now = CurTime()

    -- If we already have a threat assigned and haven't acted yet, just wait
    -- for the reaction timer to expire (don't overwrite with a new threat).
    if IsValid(bot.swepThreatTarget) and (bot.swepThreatActAt or 0) > now then
        return
    end

    -- Scan all alive players for active SWEP phases
    local chosenThreat = nil
    local chosenType   = nil
    local chosenDist   = math.huge

    local alivePlayers = TTTBots.Match.AlivePlayers or {}
    for _, ply in ipairs(alivePlayers) do
        if not IsValid(ply) then continue end
        if ply == bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end

        -- Must not be an ally
        if TTTBots.Roles and TTTBots.Roles.IsAllies(bot, ply) then continue end

        -- Must be within detection radius
        local dist = botPos:Distance(ply:GetPos())
        if dist > THREAT_RADIUS then continue end

        -- Must be in an active dangerous phase
        local active, threatType = IsInActiveSWEPPhase(ply)
        if not active then continue end

        -- Bot must be able to see the threat (or be very close — they see the glow)
        local canSee = bot:VisibleVec(ply:GetPos() + Vector(0, 0, 40))
        if not canSee and dist > 600 then continue end

        -- Closest visible threat wins
        if dist < chosenDist then
            chosenDist   = dist
            chosenThreat = ply
            chosenType   = threatType
        end
    end

    -- No threat found → clear any stale data
    if not chosenThreat then
        -- Only clear if the old threat is no longer active
        if IsValid(bot.swepThreatTarget) then
            local stillActive = IsInActiveSWEPPhase(bot.swepThreatTarget)
            if not stillActive then
                bot.swepThreatTarget   = nil
                bot.swepThreatDecision = nil
                bot.swepThreatActAt    = nil
            end
        end
        return
    end

    -- Same threat already pending — don't reset the timer
    if bot.swepThreatTarget == chosenThreat then return end

    -- New threat detected: record it and set a reaction delay
    local delay = GetReactionDelay(bot)
    bot.swepThreatTarget   = chosenThreat
    bot.swepThreatDecision = MakeFightOrFlightDecision(bot, chosenThreat, chosenType)
    bot.swepThreatActAt    = now + delay

    -- Debug
    if lib.GetDebugFor and lib.GetDebugFor("swepthreat") then
        print(string.format(
            "[SwepThreat] %s detected %s (%s) → %s in %.2fs",
            bot:Nick(), chosenThreat:Nick(), chosenType,
            bot.swepThreatDecision, delay
        ))
    end
end

--- Apply the pending decision once the reaction timer has elapsed.
--- Called every scan interval AFTER ScanBotForSwepThreat.
---@param bot Player
local function ApplyPendingDecision(bot)
    if not IsValid(bot) then return end
    if not bot.swepThreatTarget then return end
    if not bot.swepThreatDecision then return end
    if (bot.swepThreatActAt or 0) > CurTime() then return end -- still in reaction window

    local threat   = bot.swepThreatTarget
    local decision = bot.swepThreatDecision

    -- Verify the threat is still alive and active
    if not IsValid(threat) or not lib.IsPlayerAlive(threat) then
        bot.swepThreatTarget   = nil
        bot.swepThreatDecision = nil
        bot.swepThreatActAt    = nil
        return
    end

    local stillActive = IsInActiveSWEPPhase(threat)
    if not stillActive then
        bot.swepThreatTarget   = nil
        bot.swepThreatDecision = nil
        bot.swepThreatActAt    = nil
        return
    end

    -- ATTACK: elevate threat to attackTarget so AttackTarget behavior runs
    if decision == "attack" then
        -- Only override if we don't already have a higher-priority target
        local Arb = TTTBots.Morality
        local REACT_PRI = Arb and Arb.PRIORITY and Arb.PRIORITY.SELF_DEFENSE or 5
        -- Use a mid-range priority: more urgent than ambient suspicion,
        -- less than direct self-defense (being shot at)
        local SWEP_ATTACK_PRI = math.max((REACT_PRI - 1), 1)
        local curPri = bot.attackTargetPriority or 0

        if not IsValid(bot.attackTarget) or curPri < SWEP_ATTACK_PRI then
            bot:SetAttackTarget(threat, "SWEP_THREAT")
        end

        -- Clear after committing so we don't re-fire every tick
        bot.swepThreatTarget   = nil
        bot.swepThreatDecision = nil
        bot.swepThreatActAt    = nil

    -- RETREAT: mark for PanicRetreat to pick up via its SWEP_THREAT trigger
    elseif decision == "retreat" then
        -- swepThreatTarget stays set — PanicRetreat.Validate reads it.
        -- It will be cleared by PanicRetreat.OnEnd or when the threat
        -- disappears on the next scan.
    end
end

--- Periodic timer that drives the threat scan for all bots.
timer.Create("TTTBots_SwepThreatScan", SCAN_INTERVAL, 0, function()
    if not TTTBots.Bots then return end
    for _, bot in ipairs(TTTBots.Bots) do
        if not IsValid(bot) then continue end
        if not bot.components then continue end
        local ok, err = pcall(function()
            ScanBotForSwepThreat(bot)
            ApplyPendingDecision(bot)
        end)
        if not ok then
            -- Swallow errors silently so one bad bot doesn't halt everyone
            ErrorNoHaltWithStack(err)
        end
    end
end)

--- Clean up threat state when the round ends.
hook.Add("TTTPrepareRound", "TTTBots_SwepThreatReset", function()
    if not TTTBots.Bots then return end
    for _, bot in ipairs(TTTBots.Bots) do
        if not IsValid(bot) then continue end
        bot.swepThreatTarget   = nil
        bot.swepThreatDecision = nil
        bot.swepThreatActAt    = nil
    end
end)
