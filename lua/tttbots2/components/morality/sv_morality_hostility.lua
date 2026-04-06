--- sv_morality_hostility.lua
--- Role/team hostility policy: "common sense" functions that determine who to
--- attack or stop attacking based on role flags, cvar settings, and game state.
--- Extracted from sv_morality.lua — all functions here are module-level and
--- operate on a bot parameter (no instance state).

local lib = TTTBots.Lib

---@class CMorality : Component
local BotMorality = TTTBots.Components.Morality

local Arb = TTTBots.Morality  -- arbitration gateway
local PRI = Arb.PRIORITY

-- ===========================================================================
-- Engagement favourability scoring
-- ===========================================================================

--- Composite favourability score for traitor engagement decisions.
--- Returns a 0–100 score indicating how favourable it is for the bot to
--- attack the given target right now. Replaces the old flat random chance
--- so bots only commit to fights when conditions are genuinely good.
---@param bot Bot
---@param target Player
---@return number score 0-100
local function CalculateEngagementFavourability(bot, target)
    if not (IsValid(bot) and IsValid(target)) then return 0 end
    local score = 0

    -- ── 1. Isolation (0-25 pts) ─────────────────────────────────────────
    local nonAllies = TTTBots.Perception and TTTBots.Perception.GetPerceivedNonAllies(bot)
        or TTTBots.Roles.GetNonAllies(bot)
    local nearbyCount = 0
    for _, ply in pairs(nonAllies) do
        if not IsValid(ply) then continue end
        if ply == target or ply == bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end
        if ply:GetPos():Distance(target:GetPos()) <= 800 then
            nearbyCount = nearbyCount + 1
        end
    end
    if nearbyCount == 0 then      score = score + 25
    elseif nearbyCount == 1 then   score = score + 15
    elseif nearbyCount == 2 then   score = score + 5
    end -- 3+ = 0 pts

    -- ── 2. HP advantage (0-20 pts) ─────────────────────────────────────
    local botEHP  = bot:Health() + (bot:Armor() or 0)
    local targEHP = target:Health() + (target.Armor and target:Armor() or 0)
    if targEHP > 0 then
        local ratio = botEHP / targEHP
        if ratio > 1.5 then       score = score + 20
        elseif ratio > 1.0 then   score = score + 12
        elseif ratio > 0.7 then   score = score + 5
        end -- below 0.7 = 0 pts
    end

    -- ── 3. Weapon quality (0-20 pts) ───────────────────────────────────
    local inv = bot:BotInventory()
    if inv then
        local specialPrimary = inv:GetSpecialPrimary()
        local primary = inv:GetPrimary()
        if IsValid(specialPrimary) then
            score = score + 20
        elseif IsValid(primary) then
            score = score + 12
        else
            score = score + 5 -- pistol / melee only
        end
    end

    -- ── 4. Witness count (0-20 pts) ────────────────────────────────────
    -- Count perceived non-allies who can see the bot (excluding target).
    local witnessCount = 0
    for _, ply in pairs(nonAllies) do
        if not IsValid(ply) then continue end
        if ply == target or ply == bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end
        if ply:VisibleVec(bot:GetPos()) then
            witnessCount = witnessCount + 1
        end
    end
    if witnessCount == 0 then      score = score + 20
    elseif witnessCount == 1 then  score = score + 10
    elseif witnessCount == 2 then  score = score + 3
    end -- 3+ = 0 pts

    -- ── 5. Phase bonus (0-15 pts) ──────────────────────────────────────
    local ra = bot.BotRoundAwareness and bot:BotRoundAwareness()
    local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
    if ra and PHASE then
        local phase = ra:GetPhase()
        if phase == PHASE.MID then           score = score + 5
        elseif phase == PHASE.LATE then      score = score + 10
        elseif phase == PHASE.OVERTIME then  score = score + 15
        end -- EARLY = 0 pts
    end

    -- ── Random jitter (±5 pts) to avoid deterministic behaviour ────────
    score = score + math.random(-5, 5)

    return math.Clamp(score, 0, 100)
end

-- ===========================================================================
-- Attack policy functions
-- ===========================================================================

---Keep killing any nearby non-allies if we're red-handed.
--- Phase-aware: in EARLY/MID phases, only continue if the next target is isolated
--- (no point getting caught). KOS-by-all roles always continue.
---@param bot Bot
local function continueMassacre(bot)
    local isRedHanded = bot.redHandedTime and (CurTime() < bot.redHandedTime)
    local roleData = TTTBots.Roles.GetRoleFor(bot)
    local isKillerRole = roleData:GetStartsFights()

    if isRedHanded and isKillerRole then
        local nonAllies = TTTBots.Perception and TTTBots.Perception.GetPerceivedNonAllies(bot) or TTTBots.Roles.GetNonAllies(bot)
        local closest = TTTBots.Lib.GetClosest(nonAllies, bot:GetPos())
        if closest and closest ~= NULL then
            -- KOS-by-all roles always chain-kill (they're already fully exposed)
            local isKOSedByAll = roleData.GetKOSedByAll and roleData:GetKOSedByAll()
            if not isKOSedByAll then
                -- Use favourability scoring: if conditions have deteriorated
                -- after the last kill (score < 30), disengage instead of
                -- chain-killing into a losing fight.
                local favour = CalculateEngagementFavourability(bot, closest)
                if favour < 30 then
                    return -- Conditions unfavourable, disengage
                end
            end
            Arb.RequestAttackTarget(bot, closest, "CONTINUE_MASSACRE", PRI.ROLE_HOSTILITY)
        end
    end
end

--- Opportunistic traitor aggression: traitor-team bots that start fights should
--- autonomously seek out isolated enemies even when they have no plan or their
--- personality causes them to ignore coordinator orders.
--- Phase-aware: during EARLY phase only attacks completely isolated targets;
--- during MID allows 1 witness; LATE/OVERTIME attacks any visible non-ally.
--- Gated by a per-tick random roll so bots don't all lunge at once.
---@param bot Bot
local function traitorOpportunisticAggression(bot)
    -- Only for roles that are supposed to start fights (traitor-like)
    local roleData = TTTBots.Roles.GetRoleFor(bot)
    if not roleData:GetStartsFights() then return end
    -- Don't override an existing target
    if bot.attackTarget ~= nil then return end
    -- Must not already be following a plan job — this is for plan-less bots
    local planState = TTTBots.Behaviors.GetState and TTTBots.Behaviors.GetState(bot, "FollowPlan")
    if planState and planState.Job then return end

    -- Respect the plans minimum delay as an attack delay for early aggression
    if not TTTBots.Match.PlansCanStart() then return end

    -- Find visible non-allies
    local nonAllies = TTTBots.Perception and TTTBots.Perception.GetPerceivedNonAllies(bot)
        or TTTBots.Roles.GetNonAllies(bot)
    local visible = lib.GetAllWitnessesBasic(bot:EyePos(), nonAllies)
    local closest = lib.GetClosest(visible, bot:GetPos())
    if not (closest and closest ~= NULL and lib.IsPlayerAlive(closest)) then return end

    -- ── Composite favourability scoring ─────────────────────────────────
    -- Instead of a flat random chance × phase multiplier, evaluate whether
    -- conditions are genuinely favourable before committing to a fight.
    local favour = CalculateEngagementFavourability(bot, closest)

    -- Personality-based threshold: aggressive bots attack at lower scores.
    -- personalityMod is 0-15 based on the aggression trait multiplier.
    local personality = bot.components and bot.components.personality
    local aggrMult = personality and personality:GetTraitMult("aggression") or 1.0
    local personalityMod = math.Clamp(aggrMult * 10, 0, 15)
    local threshold = 50 - personalityMod

    if favour < threshold then return end -- Conditions not favourable enough

    -- Seed position into memory so AttackTarget.Seek can path immediately
    local mem = bot.components and bot.components.memory
    if mem and mem.UpdateKnownPositionFor then
        mem:UpdateKnownPositionFor(closest, closest:GetPos())
    end
    Arb.RequestAttackTarget(bot, closest, "OPPORTUNISTIC_ATTACK", PRI.OPPORTUNISTIC)
end

--- Attack any player that is in the GetEnemies for our role.
--- Phase-aware: during EARLY/MID phases, deceptive roles only attack isolated enemies.
---@param bot Bot
local function attackEnemies(bot)
    local visible = TTTBots.Lib.GetAllWitnessesBasic(bot:EyePos(), TTTBots.Perception and TTTBots.Perception.GetPerceivedNonAllies(bot) or TTTBots.Roles.GetNonAllies(bot))
    local roleData = TTTBots.Roles.GetRoleFor(bot)
    local isKillerRole = roleData:GetStartsFights()
    local kosEnemies = TTTBots.Lib.GetConVarBool("kos_enemies")

    if isKillerRole or kosEnemies then
        local enemies = TTTBots.Roles.GetEnemies(bot)
        local closest = TTTBots.Lib.GetClosest(enemies, bot:GetPos())
        if closest and closest ~= NULL and TTTBots.Lib.IsPlayerAlive(closest) and table.HasValue(visible, closest) then
            -- Phase-aware gating for deceptive roles
            local isKOSedByAll = roleData.GetKOSedByAll and roleData:GetKOSedByAll()
            if not isKOSedByAll then
                local ra = bot.BotRoundAwareness and bot:BotRoundAwareness()
                local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
                if ra and PHASE then
                    local phase = ra:GetPhase()
                    if phase == PHASE.EARLY or phase == PHASE.MID then
                        local witnessesNearTarget = lib.GetAllWitnessesBasic(
                            closest:GetPos(),
                            TTTBots.Roles.GetNonAllies(bot),
                            bot
                        )
                        local maxWitnesses = (phase == PHASE.EARLY) and 0 or 1
                        if table.Count(witnessesNearTarget) > maxWitnesses then
                            return -- Maintain cover, too many witnesses
                        end
                    end
                end
            end
            Arb.RequestAttackTarget(bot, closest, "ROLE_ENEMY", PRI.ROLE_HOSTILITY)
        end
    end
end

--- Restless bots with a ranged weapon and ammo attack any visible non-ally
--- unconditionally (super-aggressive). Bypasses all phase and witness gates.
---@param bot Bot
local function restlessRangedAggression(bot)
    if not TEAM_RESTLESS then return end
    if bot:GetTeam() ~= TEAM_RESTLESS then return end

    local inv = bot:BotInventory()
    if not inv then return end
    -- Only trigger when the bot actually has a ranged weapon with ammo
    if inv:HasNoWeaponAvailable(false) then return end

    local nonAllies = TTTBots.Perception and TTTBots.Perception.GetPerceivedNonAllies(bot)
        or TTTBots.Roles.GetNonAllies(bot)
    local visible = TTTBots.Lib.GetAllWitnessesBasic(bot:EyePos(), nonAllies)
    local closest = TTTBots.Lib.GetClosest(visible, bot:GetPos())
    if closest and closest ~= NULL and TTTBots.Lib.IsPlayerAlive(closest) then
        Arb.RequestAttackTarget(bot, closest, "RESTLESS_AGGRESSION", PRI.ROLE_HOSTILITY)
    end
end

--- Attack any player that is on TEAM_INFECTED and is a zombie (converted infected).
--- Uses role/team checks instead of fragile model-string comparison.
--- All bots (not just killer roles) attack zombies because infected zombies are KOSedByAll.
---@param bot Bot
local function attackZombies(bot)
    local visible = TTTBots.Lib.GetAllWitnessesBasic(bot:EyePos(), TTTBots.Perception and TTTBots.Perception.GetPerceivedNonAllies(bot) or TTTBots.Roles.GetNonAllies(bot))

    -- Infected zombies are KOSedByAll — every bot should attack them on sight,
    -- not just roles that start fights.  The only exception is allied bots
    -- (e.g. the infected host itself or other infected zombies), which are
    -- already excluded by GetPerceivedNonAllies / GetNonAllies above.
    local bestDist = math.huge
    local bestPly = nil
    for _, ply in pairs(visible) do
        -- Check by team/role first, then fall back to model as a secondary signal
        local isInfectedTeam = TEAM_INFECTED and ply.GetTeam and ply:GetTeam() == TEAM_INFECTED
        local isZombieModel = ply:GetModel() == "models/player/corpse1.mdl"
        local isInfectedZombie = TTTBots.Roles.IsInfectedZombie
            and TTTBots.Roles.IsInfectedZombie(ply)

        if isInfectedTeam or isZombieModel or isInfectedZombie then
            local dist = bot:GetPos():Distance(ply:GetPos())
            if dist < bestDist then
                bestDist = dist
                bestPly = ply
            end
        end
    end
    if bestPly and bestPly ~= NULL and TTTBots.Lib.IsPlayerAlive(bestPly) then
        Arb.RequestAttackTarget(bot, bestPly, "KOS_ZOMBIE", PRI.ROLE_HOSTILITY)
    end
end

--- Attack any player that is in the GetNonAllies for our role.
--- Phase-aware: during EARLY phase, deceptive roles (not KOS-by-all) only attack
--- isolated targets to maintain cover. Infected zombies (melee-only, already exposed)
--- and KOS-by-all roles (Doomguy) always attack openly.
---@param bot Bot
local function attackNonAllies(bot)
    local visible = TTTBots.Lib.GetAllWitnessesBasic(bot:EyePos(), TTTBots.Perception and TTTBots.Perception.GetPerceivedNonAllies(bot) or TTTBots.Roles.GetNonAllies(bot))
    local kosnonallies = TTTBots.Lib.GetConVarBool("kos_nonallies")
    -- Check if this bot is any kind of infected (host OR zombie) via INFECTEDS global
    local isInfectedHost = INFECTEDS and INFECTEDS[bot]
    local isInfectedZombie = TTTBots.Roles.IsInfectedZombie
        and TTTBots.Roles.IsInfectedZombie(bot)
    local isINFECTEDs = isInfectedHost or isInfectedZombie
    local roleData = TTTBots.Roles.GetRoleFor(bot)
    local kosrole = roleData:GetKOSAll()

    if kosnonallies or isINFECTEDs or kosrole then
        local nonAllies = TTTBots.Perception and TTTBots.Perception.GetPerceivedNonAllies(bot) or TTTBots.Roles.GetNonAllies(bot)
        local closest = TTTBots.Lib.GetClosest(nonAllies, bot:GetPos())
        if closest and closest ~= NULL and TTTBots.Lib.IsPlayerAlive(closest) and table.HasValue(visible, closest) then
            -- Phase-aware gating: roles that need deception should wait for isolation.
            -- KOS-by-all roles and already-exposed zombies always attack openly.
            local isKOSedByAll = roleData.GetKOSedByAll and roleData:GetKOSedByAll()
            local alwaysAggressive = isKOSedByAll or isInfectedZombie
            if not alwaysAggressive then
                local ra = bot.BotRoundAwareness and bot:BotRoundAwareness()
                local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
                if ra and PHASE then
                    local phase = ra:GetPhase()
                    if phase == PHASE.EARLY or phase == PHASE.MID then
                        -- Only attack if the target is isolated (few witnesses)
                        local witnessesNearTarget = lib.GetAllWitnessesBasic(
                            closest:GetPos(),
                            nonAllies,
                            bot
                        )
                        local maxWitnesses = (phase == PHASE.EARLY) and 0 or 1
                        if table.Count(witnessesNearTarget) > maxWitnesses then
                            return -- Too many witnesses, maintain cover
                        end
                    end
                end
            end
            Arb.RequestAttackTarget(bot, closest, "KOS_ALL", PRI.ROLE_HOSTILITY)
        end
    end
end

--- Attack any alive player whose role has been publicly confirmed by TTT2
--- (e.g., body searched, resurrected with known role) and whose confirmed role
--- makes them hostile to this bot. Uses TTT2's ply:RoleKnown() API.
--- This ensures bots react to confirmed hostiles even without witnessing them
--- commit any crimes — the game itself has revealed their role publicly.
---
--- Only fires for bots that use the suspicion system (innocent-team, detectives,
--- etc.). Traitor-team bots already have omniscient alliance knowledge.
---@param bot Bot
local function attackConfirmedHostiles(bot)
    -- Only for bots that rely on suspicion (innocent-side) — traitor bots
    -- already know who is on their team via alliance tables.
    local roleData = TTTBots.Roles.GetRoleFor(bot)
    if not roleData:GetUsesSuspicion() then return end

    local morality = bot:BotMorality()
    if not morality then return end

    -- Track which players we've already processed this round to avoid
    -- re-applying the massive suspicion bump every tick.
    morality._confirmedHostilesSeen = morality._confirmedHostilesSeen or {}

    for _, ply in pairs(TTTBots.Match.AlivePlayers or {}) do
        if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end
        if ply == bot then continue end

        -- TTT2 API: is this player's role publicly known?
        if not (ply.RoleKnown and ply:RoleKnown()) then continue end

        -- Skip if we already processed this player's confirmed role
        if morality._confirmedHostilesSeen[ply] then continue end

        -- Get the confirmed player's actual role and team
        local targetRole = TTTBots.Roles.GetRoleFor(ply)
        if not targetRole then continue end

        -- Check if the confirmed player is an ally — if so, boost trust instead
        local isAlly = (TTTBots.Perception and TTTBots.Perception.IsPerceivedAlly(bot, ply))
            or TTTBots.Roles.IsAllies(bot, ply)

        if isAlly then
            -- Confirmed friendly role: boost trust via suspicion reduction
            morality:ChangeSuspicion(ply, "RoleConfirmedAlly")
            morality._confirmedHostilesSeen[ply] = true
            continue
        end

        -- Check for neutral override — don't attack neutral confirmed roles
        if targetRole:GetNeutralOverride() then
            morality._confirmedHostilesSeen[ply] = true
            continue
        end

        -- This player is confirmed and NOT an ally and NOT neutral — they are hostile.
        -- Apply massive suspicion so the suspicion system also catches it.
        morality:ChangeSuspicion(ply, "RoleConfirmedHostile")
        morality._confirmedHostilesSeen[ply] = true

        -- Feed evidence log
        local evidence = bot:BotEvidence()
        if evidence then
            evidence:AddEvidence({
                type    = "ROLE_CONFIRMED",
                subject = ply,
                detail  = string.format("role publicly confirmed as %s (team: %s)",
                    targetRole:GetName() or "unknown",
                    ply:GetTeam() or "unknown"),
            })
        end

        -- Record in memory for LLM context
        local mem = bot:BotMemory()
        if mem and mem.AddWitnessEvent then
            mem:AddWitnessEvent("confirmed", string.format(
                "%s's role confirmed as %s — hostile!",
                ply:Nick(),
                targetRole:GetName() or "unknown"
            ))
        end

        -- Announce KOS via chatter
        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("CallKOS", { player = ply:Nick() })
        end

        -- If the bot can see this confirmed hostile right now, attack immediately
        if bot:Visible(ply) then
            -- Seed position for pathfinding
            local mem2 = bot.components and bot.components.memory
            if mem2 and mem2.UpdateKnownPositionFor then
                mem2:UpdateKnownPositionFor(ply, ply:GetPos())
            end
            Arb.RequestAttackTarget(bot, ply, "CONFIRMED_HOSTILE", PRI.ROLE_HOSTILITY)
        else
            -- Not visible — call KOS so other bots know, and hunt
            TTTBots.Match.CallKOS(bot, ply)
        end
    end
end

--- Innocent-team bots attack the closest visible player who has been KOS'd by a
--- credible caller (in Match.KOSList). The caller is considered credible when the
--- bot's own suspicion of the caller is below the KOS threshold (i.e. the bot
--- doesn't currently believe the caller is the traitor).
--- Only runs for innocent-team bots that use suspicion (standard innocents,
--- detectives, deputies, etc.).
--- This is also exported so morality Think() can call it per-tick for instant
--- on-sight KOS response.
---@param bot Bot
local function attackKOSListed(bot)
    local kosList = TTTBots.Match.KOSList
    if not kosList then return end

    -- Only innocent-team bots react to chat-based KOS
    if bot:GetTeam() ~= TEAM_INNOCENT then return end
    local roleData = TTTBots.Roles.GetRoleFor(bot)
    if not roleData:GetUsesSuspicion() then return end

    local morality = bot:BotMorality()

    -- Search ALL alive players for KOS targets — do NOT restrict to perceived
    -- non-allies. A KOS target may appear innocent to the bot (e.g. a traitor
    -- who hasn't been caught yet), so filtering to non-allies would silently
    -- skip the target. We apply a direct visibility check per-target instead.

    local bestDist   = math.huge
    local bestTarget = nil

    for target, callers in pairs(kosList) do
        if not (IsValid(target) and lib.IsPlayerAlive(target)) then continue end
        if target == bot then continue end

        -- Target must be currently visible to the bot
        if not bot:Visible(target) then continue end

        -- Skip if the bot actually perceives this player as a confirmed ally
        -- (e.g. traitor-side bot accidentally listed as KOS target is filtered here).
        -- Use IsPerceivedAlly so the Spy/Clown perception layer is respected.
        if TTTBots.Perception and TTTBots.Perception.IsPerceivedAlly(bot, target) then
            -- Only skip if the bot has NO suspicion of this player — a KOS call
            -- should override weak ally-perception if suspicion is rising.
            local targetSus = morality and morality:GetSuspicion(target) or 0
            if targetSus < BotMorality.Thresholds.Sus then continue end
        end

        -- Check if at least one caller is credible (not believed to be traitor by this bot)
        local hasCredibleCaller = false
        for caller, _ in pairs(callers) do
            if not IsValid(caller) then continue end
            -- A caller is credible as long as the bot doesn't suspect them of being evil
            local callerSus = morality and morality:GetSuspicion(caller) or 0
            if callerSus < BotMorality.Thresholds.KOS then
                hasCredibleCaller = true
                break
            end
        end
        if not hasCredibleCaller then continue end

        local dist = bot:GetPos():Distance(target:GetPos())
        if dist < bestDist then
            bestDist   = dist
            bestTarget = target
        end
    end

    if bestTarget and bestTarget ~= NULL then
        -- Seed last-known position into memory so AttackTarget's Seek mode can
        -- hunt them down even if they move out of sight immediately after.
        local mem = bot.components and bot.components.memory
        if mem and mem.UpdateKnownPositionFor then
            mem:UpdateKnownPositionFor(bestTarget, bestTarget:GetPos())
        end
        -- Use PLAYER_REQUEST priority (4) for visible KOS targets so the attack
        -- cannot be overridden by low-priority clears (ceasefire, wait, etc.)
        Arb.RequestAttackTarget(bot, bestTarget, "KOS_LIST_TARGET", PRI.PLAYER_REQUEST)
        return
    end

    -- Secondary pass: hunt a KOS target that is NOT currently visible.
    -- Use OPPORTUNISTIC priority so the bot will pursue but won't override
    -- an ongoing engagement or self-defense reaction.
    local huntDist   = math.huge
    local huntTarget = nil

    for target, callers in pairs(kosList) do
        if not (IsValid(target) and lib.IsPlayerAlive(target)) then continue end
        if target == bot then continue end

        -- Skip if the bot has a very high positive perception of this player
        -- AND suspicion is still low (don't chase someone the bot trusts).
        if TTTBots.Perception and TTTBots.Perception.IsPerceivedAlly(bot, target) then
            local targetSus = morality and morality:GetSuspicion(target) or 0
            if targetSus < BotMorality.Thresholds.Sus then continue end
        end

        -- Require at least one credible caller
        local hasCredibleCaller = false
        for caller, _ in pairs(callers) do
            if not IsValid(caller) then continue end
            local callerSus = morality and morality:GetSuspicion(caller) or 0
            if callerSus < BotMorality.Thresholds.KOS then
                hasCredibleCaller = true
                break
            end
        end
        if not hasCredibleCaller then continue end

        local dist = bot:GetPos():Distance(target:GetPos())
        if dist < huntDist then
            huntDist   = dist
            huntTarget = target
        end
    end

    if huntTarget and huntTarget ~= NULL then
        -- Seed position so Seek mode works immediately
        local mem = bot.components and bot.components.memory
        if mem and mem.UpdateKnownPositionFor then
            mem:UpdateKnownPositionFor(huntTarget, huntTarget:GetPos())
        end
        -- Use SUSPICION_THRESHOLD (2) for non-visible KOS targets so the bot
        -- actively hunts them down rather than being easily distracted.
        Arb.RequestAttackTarget(bot, huntTarget, "KOS_LIST_TARGET", PRI.SUSPICION_THRESHOLD)
    end
end

--- Attack the closest player that has the SetKOSedByAll role parameter set to true, only if they happen to see them.
---@param bot Bot
local function attackKOSedByAll(bot)
    local visible = TTTBots.Lib.GetAllWitnessesBasic(bot:EyePos(), TTTBots.Roles.GetNonAllies(bot))
    local players = TTTBots.Roles.GetKOSedByAllPlayers()
    local closest = TTTBots.Lib.GetClosest(players, bot:GetPos())
    if closest and closest ~= NULL and closest ~= bot and TTTBots.Lib.IsPlayerAlive(closest) and table.HasValue(visible, closest) then
        Arb.RequestAttackTarget(bot, closest, "KOSED_BY_ALL", PRI.ROLE_HOSTILITY)
    end
end

--- Attack any player that has the "unknown" role
---@param bot Bot
local function attackUnknowns(bot)
    local cvarKosUnknowns = TTTBots.Lib.GetConVarBool("kos_unknown")
    local roleKosUnknown = TTTBots.Roles.GetRoleFor(bot):GetKOSUnknown()
    if cvarKosUnknowns or roleKosUnknown then
        local unknowns = TTTBots.Roles.GetUnknownPlayers()
        local closest = TTTBots.Lib.GetClosest(unknowns, bot:GetPos())
        if closest and closest ~= NULL and TTTBots.Lib.IsPlayerAlive(closest) then
            Arb.RequestAttackTarget(bot, closest, "KOS_UNKNOWN", PRI.ROLE_HOSTILITY)
        end
    end
end

--- Maximum engagement range for NPC zombies (npc_zombie, npc_fastzombie,
--- npc_poisonzombie). Bots will only attack these NPCs if they are visible
--- AND within this many units. Other hostile NPCs are still attacked on
--- sight without a range limit (headcrabs, etc).
local CV_ZOMBIE_NPC_RANGE = CreateConVar(
    "ttt_bot_zombie_npc_range", "2000", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Max range (units) at which bots engage zombie NPCs spawned in-world (e.g. from Zombie Apocalypse weapon). 0 = unlimited.",
    0, 10000
)

--- NPC classes considered zombie-type; bots apply the range gate only to these.
local ZOMBIE_NPC_CLASSES = {
    npc_zombie        = true,
    npc_fastzombie    = true,
    npc_poisonzombie  = true,
}

--- KOS all non-Bot NPCs (Zombies, Headcrabs, etc).
--- Zombie-type NPCs (npc_zombie / npc_fastzombie / npc_poisonzombie) are only
--- engaged when visible AND within ttt_bot_zombie_npc_range units.
--- All other hostile NPCs (headcrabs, etc.) are attacked on sight with no
--- additional range restriction.
---
--- Apocalypse SWEPs (Zombie Apocalypse, Combine Apocalypse) tag their spawned
--- NPCs with "ttt2_apoc_owner_team".  Bots on the same team as the caster skip
--- those NPCs entirely — they are friendly forces and should not be shot.
--- (A bot may still choose to attack them for deception, but that is handled
--- by higher-level behaviour logic, not the baseline hostility policy.)
---@param bot Bot
local function attackNPCs(bot)
    local npcs = TTTBots.Lib.GetNPCs()
    local closest = nil
    local minDist = math.huge
    local zombieRange = CV_ZOMBIE_NPC_RANGE:GetFloat()
    local botTeam = bot:GetTeam()

    for _, npc in pairs(npcs) do
        if not bot:Visible(npc) then continue end

        -- Skip NPCs that were spawned by an ally's apocalypse SWEP.
        -- The SWEP tags each NPC with the caster's team string so we can
        -- identify friendly forces without needing access to the SWEP's
        -- internal tracking tables.
        local apocTeam = npc:GetNWString("ttt2_apoc_owner_team", "")
        if apocTeam ~= "" and apocTeam == botTeam then continue end

        local dist = bot:GetPos():Distance(npc:GetPos())

        -- Apply range gate for zombie-type NPCs only
        if ZOMBIE_NPC_CLASSES[npc:GetClass()] then
            if zombieRange > 0 and dist > zombieRange then continue end
        end

        if dist < minDist then
            minDist = dist
            closest = npc
        end
    end
    if closest and closest ~= NULL then
        Arb.RequestAttackTarget(bot, closest, "KOS_NPC", PRI.ROLE_HOSTILITY)
    end
end

-- ===========================================================================
-- Prevent (clear) policy functions
-- ===========================================================================

local function preventAttackAlly(bot)
    local attackTarget = bot.attackTarget
    if not IsValid(attackTarget) then return end
    -- Works for both human players and bot targets equally
    if not attackTarget:IsPlayer() then return end
    local role = TTTBots.Roles.GetRoleFor(attackTarget)
    if not role then return end
    local isAllies = (TTTBots.Perception and TTTBots.Perception.IsPerceivedAlly(bot, attackTarget))
        or TTTBots.Roles.IsAllies(bot, attackTarget)
    if isAllies then
        -- Use SELF_DEFENSE priority to clear ally targets so no lower-priority
        -- assignment can keep an ally locked as a target. The self-defense
        -- trigger itself already checks alliance before requesting, so this
        -- won't conflict with legitimate self-defense.
        Arb.RequestClearTarget(bot, "PREVENT_ALLY", PRI.SELF_DEFENSE)
    end
end

local function preventCloaked(bot)
    local attackTarget = bot.attackTarget
    if not IsValid(attackTarget) then return end
    local isCloaked = TTTBots.Match.IsPlayerCloaked(attackTarget)
    if isCloaked then
        Arb.RequestClearTarget(bot, "PREVENT_CLOAKED", PRI.ROLE_HOSTILITY)
    end
end

--- Prevent attacking bots that have the Neutral override parameter set to true
---@param bot Bot
local function preventAttack(bot)
    local attackTarget = bot.attackTarget
    if not IsValid(attackTarget) then return end
    local role = TTTBots.Roles.GetRoleFor(attackTarget)
    if not role then return end
    local isNeutral = role:GetNeutralOverride()
    local bot_zombie_cvar = TTTBots.Lib.GetConVarBool('cheat_bot_zombie')
    if isNeutral or bot_zombie_cvar then
        Arb.RequestClearTarget(bot, "PREVENT_NEUTRAL", PRI.ROLE_HOSTILITY)
    end
end

--- Prevent attacking bots that have used the role checker to determine they are allies
---@param bot Bot
local function preventAttackAllies(bot)
    local attackTarget = bot.attackTarget
    if not IsValid(attackTarget) then return end
    if not attackTarget:IsPlayer() then return end
    local role = TTTBots.Roles.GetRoleFor(attackTarget)
    if not role then return end
    local isAllies = (TTTBots.Perception and TTTBots.Perception.IsPerceivedAlly(bot, attackTarget))
        or TTTBots.Roles.IsAllies(bot, attackTarget)
    local isChecked = TTTBots.Match.CheckedPlayers[attackTarget] or nil
    if isAllies and isChecked then
        Arb.RequestClearTarget(bot, "PREVENT_CHECKED_ALLY", PRI.SELF_DEFENSE)
    end
end

-- ===========================================================================
-- Suspicion-generating observation functions (run as part of hostility tick)
-- ===========================================================================

local PS_RADIUS = 100
local PS_INTERVAL = 5
local function personalSpace(bot)
    bot.personalSpaceTbl = bot.personalSpaceTbl or {}
    local ticked = {}
    if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then return end
    if IsValid(bot.attackTarget) then return end

    local withinPSpace = lib.FilterTable(TTTBots.Match.AlivePlayers, function(other)
        if other == bot then return false end
        if not IsValid(other) then return false end
        if not lib.IsPlayerAlive(other) then return false end
        if not bot:Visible(other) then return false end
        if (TTTBots.Perception and TTTBots.Perception.IsPerceivedAlly(bot, other) or TTTBots.Roles.IsAllies(bot, other)) then return false end

        local dist = bot:GetPos():Distance(other:GetPos())
        if dist > PS_RADIUS then return false end

        return true
    end)

    for i, other in pairs(withinPSpace) do
        bot.personalSpaceTbl[other] = (bot.personalSpaceTbl[other] or 0) + 0.5
        ticked[other] = true
    end

    for other, time in pairs(bot.personalSpaceTbl) do
        if not ticked[other] then
            bot.personalSpaceTbl[other] = math.max(time - 0.5, 0)
        end

        if bot.personalSpaceTbl[other] or 0 <= 0 then
            bot.personalSpaceTbl[other] = nil
        end

        if (bot.personalSpaceTbl[other] or 0) >= PS_INTERVAL then
            bot:BotMorality():ChangeSuspicion(other, "PersonalSpace")
            local _c = bot:BotChatter(); if _c and _c.On then _c:On("PersonalSpace") end
            -- Evidence: suspicious proximity behavior
            local evidence = bot:BotEvidence()
            if evidence then
                evidence:AddEvidence({
                    type    = "SUSPICIOUS_MOVEMENT",
                    subject = other,
                    detail  = "standing too close for too long",
                })
            end
            bot.personalSpaceTbl[other] = nil
        end
    end
end

--- Look at the players around us and see if they are holding any T-weapons.
local function noticeTraitorWeapons(bot)
    if bot.attackTarget ~= nil then return end
    if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then return end

    local visible = TTTBots.Lib.GetAllWitnessesBasic(bot:EyePos(), TTTBots.Perception and TTTBots.Perception.GetPerceivedNonAllies(bot) or TTTBots.Roles.GetNonAllies(bot))
    local filtered = TTTBots.Lib.FilterTable(visible, function(other)
        if TTTBots.Roles.GetRoleFor(other):GetAppearsPolice() then return false end
        local hasTWeapon = TTTBots.Lib.IsHoldingTraitorWep(other)
        if not hasTWeapon then return false end
        local iCanSee = TTTBots.Lib.CanSeeArc(bot, other:GetPos() + Vector(0, 0, 24), 90)
        return iCanSee
    end)

    if table.IsEmpty(filtered) then return end

    local firstEnemy = TTTBots.Lib.GetClosest(filtered, bot:GetPos()) ---@cast firstEnemy Player?

    if not TTTBots.Lib.GetConVarBool("kos_traitorweapons") then return end

    if not firstEnemy then return end
    Arb.RequestAttackTarget(bot, firstEnemy, "TRAITOR_WEAPON", PRI.ROLE_HOSTILITY)
    local _c = bot:BotChatter(); if _c and _c.On then _c:On("HoldingTraitorWeapon", { player = firstEnemy:Nick() }) end
    -- Evidence: witnessed holding a traitor weapon
    local evidence = bot:BotEvidence()
    if evidence then
        local wep = firstEnemy:GetActiveWeapon()
        local wepName = (IsValid(wep) and wep.GetPrintName) and wep:GetPrintName() or "traitor weapon"
        evidence:AddEvidence({
            type   = "TRAITOR_WEAPON",
            subject = firstEnemy,
            detail  = wepName,
        })
    end
end

-- ===========================================================================
-- Ankh-based hostility (Pharaoh / Graverobber integration)
-- ===========================================================================

--- Pharaoh bots attack known ankh threats; Graverobber bots target Pharaohs
--- guarding their ankh when attempting to capture.
---@param bot Bot
local function ankhBasedHostility(bot)
    if not ROLE_PHARAOH then return end

    -- Pharaoh: attack anyone the DefendAnkh monitor has identified as a threat
    if bot:GetSubRole() == ROLE_PHARAOH and bot.ankhThreatSource then
        local threat = bot.ankhThreatSource
        if IsValid(threat) and lib.IsPlayerAlive(threat) and bot:Visible(threat) then
            Arb.RequestAttackTarget(bot, threat, "DEFEND_ANKH", PRI.PLAYER_REQUEST)
        end
    end

    -- Pharaoh: if the Graverobber stole the Pharaoh's ankh, attack the Graverobber
    -- who now owns it (DefendAnkh can't fire because PlayerControlsAnAnkh is false after theft)
    if bot:GetSubRole() == ROLE_PHARAOH then
        local ply_id = bot:SteamID64()
        local ankhData = PHARAOH_HANDLER and PHARAOH_HANDLER.ankhs and PHARAOH_HANDLER.ankhs[ply_id]
        if ankhData and ankhData.current_owner_id ~= ply_id and IsValid(ankhData.ankh) then
            -- Ankh was stolen — find the thief and attack them
            local plys = player.GetAll()
            for i = 1, #plys do
                local ply = plys[i]
                if ply:SteamID64() == ankhData.current_owner_id and lib.IsPlayerAlive(ply) and bot:Visible(ply) then
                    Arb.RequestAttackTarget(bot, ply, "DEFEND_ANKH", PRI.PLAYER_REQUEST)
                    break
                end
            end
        end
    end

    -- Graverobber: target the Pharaoh if they're near the ankh we're trying to capture or own.
    -- NOTE: bot._ankhConvertingEnt is set by CaptureAnkh.UseAnkh (not bot.ankhConvertingEntity).
    if bot:GetSubRole() == ROLE_GRAVEROBBER then
        local targetAnkh = bot.targetAnkh or bot._ankhConvertingEnt
        if IsValid(targetAnkh) then
            local ankhOwner = targetAnkh:GetOwner()
            -- If the ankh is owned by a Pharaoh who is guarding it, attack them
            if IsValid(ankhOwner) and ankhOwner:GetSubRole() == ROLE_PHARAOH
            and lib.IsPlayerAlive(ankhOwner)
            and bot:GetPos():Distance(targetAnkh:GetPos()) < 300
            and bot:Visible(ankhOwner) then
                Arb.RequestAttackTarget(bot, ankhOwner, "ANKH_GUARDIAN_THREAT", PRI.PLAYER_REQUEST)
            end
        end
        -- Also: if we already own the ankh, attack the original Pharaoh who tries to reclaim it
        if PHARAOH_HANDLER and PHARAOH_HANDLER:PlayerControlsAnAnkh(bot) then
            local ankhs = ents.FindByClass("ttt_ankh")
            for _, ankh in pairs(ankhs) do
                if not IsValid(ankh) then continue end
                if ankh:GetOwner() ~= bot then continue end
                local nearbyPlayers = ents.FindInSphere(ankh:GetPos(), 250)
                for _, ent in pairs(nearbyPlayers) do
                    if not (IsValid(ent) and ent:IsPlayer() and ent ~= bot and lib.IsPlayerAlive(ent)) then continue end
                    if ent:GetSubRole() ~= ROLE_PHARAOH then continue end
                    if bot:Visible(ent) then
                        Arb.RequestAttackTarget(bot, ent, "ANKH_GUARDIAN_THREAT", PRI.PLAYER_REQUEST)
                        break
                    end
                end
            end
        end
    end
end

-- ===========================================================================
-- Gun Dealer protection — prevent all bots from targeting gun dealers
-- ===========================================================================

--- Gun Dealers are neutral merchants; no bot should attack them under
--- normal circumstances. This runs at SELF_DEFENSE priority (the highest)
--- so that it overrides opportunistic, suspicion and role-hostility
--- targeting that would otherwise pick a Gun Dealer as a target.
---@param bot Bot
local function preventAttackGunDealer(bot)
    if not ROLE_GUNDEALER then return end
    local attackTarget = bot.attackTarget
    if not IsValid(attackTarget) then return end
    if not attackTarget:IsPlayer() then return end
    if attackTarget:GetSubRole() ~= ROLE_GUNDEALER then return end

    -- Allow self-defence: if the Gun Dealer is actively shooting at us,
    -- the bot may still fight back (handled by the FightBack behavior).
    -- But we clear any *policy-generated* target on the dealer.
    Arb.RequestClearTarget(bot, "PREVENT_GUNDEALER", PRI.SELF_DEFENSE)
end

-- ===========================================================================
-- Combined prevent wrapper
-- ===========================================================================

local function preventAttackAll(bot)
    -- During post-round deathmatch, alliances are dissolved — skip all prevent policies
    if TTTBots.Match.IsPostRoundDM() then return end
    preventAttackAlly(bot)
    preventCloaked(bot)
    preventAttackAllies(bot)
    preventAttack(bot)
    preventAttackGunDealer(bot)
end

-- ===========================================================================
-- Master dispatcher
-- ===========================================================================

--- Run all hostility policy checks on a single bot.
---@param bot Bot
local function runHostilityPolicy(bot)
    -- -----------------------------------------------------------------------
    -- Defector guard: defectors cannot deal gun damage, so all attack policies
    -- are meaningless and would only cause the bot to waste time aiming a
    -- useless weapon. Only run prevent (clear) policies and observation.
    -- -----------------------------------------------------------------------
    if ROLE_DEFECTOR and bot:GetSubRole() == ROLE_DEFECTOR then
        preventAttackAll(bot)
        personalSpace(bot)
        return
    end

    -- Skip if the bot is fighting an NPC that isn't one of our bots
    if not (bot.attackTarget ~= nil and bot.attackTarget:IsNPC() and not table.HasValue(TTTBots.Bots, bot.attackTarget)) then
        restlessRangedAggression(bot)
        attackKOSedByAll(bot)
        attackConfirmedHostiles(bot)
        attackKOSListed(bot)
        attackNPCs(bot)
        attackEnemies(bot)
        attackNonAllies(bot)
        attackZombies(bot)
        attackUnknowns(bot)
        continueMassacre(bot)
        traitorOpportunisticAggression(bot)
        ankhBasedHostility(bot)
        preventAttackAll(bot)
        personalSpace(bot)
        noticeTraitorWeapons(bot)
    end
end

-- Export for the coordinator and per-tick callers
TTTBots.Morality.RunHostilityPolicy        = runHostilityPolicy
TTTBots.Morality.AttackKOSListed           = attackKOSListed
TTTBots.Morality.AttackKOSedByAll          = attackKOSedByAll
TTTBots.Morality.RestlessRangedAggression  = restlessRangedAggression
TTTBots.Morality.AttackConfirmedHostiles   = attackConfirmedHostiles

-- ===========================================================================
-- Anti-grief: Innocent-team bots should not damage friendly ankhs (G-9)
-- ===========================================================================

hook.Add("TTT2PharaohPreventDamageToAnkh", "TTTBots_AntiGriefAnkh", function(attacker)
    if not IsValid(attacker) then return end
    if not attacker:IsBot() then return end
    if attacker:GetTeam() == TEAM_INNOCENT then
        return true -- Prevent damage — innocent bots should not shoot their own team's ankh
    end
end)

-- ===========================================================================
-- Timer — "Common Sense" tick (1 second interval)
-- ===========================================================================

timer.Create("TTTBots.Components.Morality.CommonSense", 1, 0, function()
    if not TTTBots.Match.IsRoundActive() then return end
    for i, bot in pairs(TTTBots.Bots) do
        if not bot or bot == NULL or not IsValid(bot) then continue end
        if not bot.components then continue end
        if not bot.components.chatter or not bot:BotLocomotor() then continue end
        if not lib.IsPlayerAlive(bot) then continue end
        runHostilityPolicy(bot)
    end
end)

-- ===========================================================================
-- Post-Round Deathmatch — FFA targeting (1 second interval)
-- ===========================================================================

--- During post-round deathmatch, all bots enter a free-for-all: they attack
--- the closest alive player regardless of role or team, preferring visible
--- targets but falling back to nearby players within acquisition range.
--- Roles no longer matter — the round is over and PVP damage is enabled.
---@param bot Bot
local function postRoundDMTargeting(bot)
    -- Already fighting someone? Only re-evaluate if the target is dead/invalid.
    if IsValid(bot.attackTarget) and bot.attackTarget:IsPlayer()
        and lib.IsPlayerAlive(bot.attackTarget) then
        return
    end

    -- Find the closest alive player — prefer visible targets, but if none are
    -- visible, fall back to the closest player within NEARBY_RANGE units so
    -- bots actively converge on enemies rather than standing idle.
    local NEARBY_RANGE = 1500  -- units; generous search radius for post-round FFA

    local bestDistVisible = math.huge
    local bestVisible     = nil
    local bestDistNearby  = math.huge
    local bestNearby      = nil
    local botPos = bot:GetPos()
    local alivePlayers = TTTBots.Match.AlivePlayers or {}

    for _, ply in ipairs(alivePlayers) do
        if not IsValid(ply) then continue end
        if ply == bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end
        -- Ghost DM players are in a separate realm — skip them
        if GhostDM and GhostDM.IsGhost and GhostDM.IsGhost(ply) then continue end

        local dist = botPos:Distance(ply:GetPos())

        if bot:Visible(ply) and dist < bestDistVisible then
            bestDistVisible = dist
            bestVisible     = ply
        end

        if dist <= NEARBY_RANGE and dist < bestDistNearby then
            bestDistNearby = dist
            bestNearby     = ply
        end
    end

    -- Prefer visible target; fall back to nearest nearby target
    local bestTarget = bestVisible or bestNearby

    if bestTarget and bestTarget ~= NULL then
        -- Seed position in memory so AttackTarget.Seek can path immediately
        local mem = bot.components and bot.components.memory
        if mem and mem.UpdateKnownPositionFor then
            mem:UpdateKnownPositionFor(bestTarget, bestTarget:GetPos())
        end
        Arb.RequestAttackTarget(bot, bestTarget, "POSTROUND_DM_FFA", PRI.ROLE_HOSTILITY)
    end
end

timer.Create("TTTBots.Components.Morality.PostRoundDM", 1, 0, function()
    if not TTTBots.Match.IsPostRoundDM() then return end
    for _, bot in pairs(TTTBots.Bots) do
        if not bot or bot == NULL or not IsValid(bot) then continue end
        if not bot.components then continue end
        if not bot:BotLocomotor() then continue end
        if not lib.IsPlayerAlive(bot) then continue end
        postRoundDMTargeting(bot)
    end
end)
