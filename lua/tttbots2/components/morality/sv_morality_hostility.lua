--- sv_morality_hostility.lua
--- Role/team hostility policy: "common sense" functions that determine who to
--- attack or stop attacking based on role flags, cvar settings, and game state.
--- Extracted from sv_morality.lua — all functions here are module-level and
--- operate on a bot parameter (no instance state).

local lib = TTTBots.Lib

local Arb = TTTBots.Morality  -- arbitration gateway
local PRI = Arb.PRIORITY

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
            -- Phase-aware gating: deceptive roles should flee after a kill, not chain-attack in crowds
            local isKOSedByAll = roleData.GetKOSedByAll and roleData:GetKOSedByAll()
            if not isKOSedByAll then
                local ra = bot.BotRoundAwareness and bot:BotRoundAwareness()
                local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
                if ra and PHASE then
                    local phase = ra:GetPhase()
                    if phase == PHASE.EARLY or phase == PHASE.MID then
                        -- Only continue the massacre if the next target is isolated
                        local witnessesNearTarget = lib.GetAllWitnessesBasic(
                            closest:GetPos(), nonAllies, bot
                        )
                        if table.Count(witnessesNearTarget) > 1 then
                            return -- Disengage and flee rather than chain-kill in a crowd
                        end
                    end
                end
            end
            Arb.RequestAttackTarget(bot, closest, "CONTINUE_MASSACRE", PRI.ROLE_HOSTILITY)
        end
    end
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

--- Attack any player that is on TEAM_INFECTED and is a zombie (converted infected).
--- Uses role/team checks instead of fragile model-string comparison.
---@param bot Bot
local function attackZombies(bot)
    local visible = TTTBots.Lib.GetAllWitnessesBasic(bot:EyePos(), TTTBots.Perception and TTTBots.Perception.GetPerceivedNonAllies(bot) or TTTBots.Roles.GetNonAllies(bot))
    local isKillerRole = TTTBots.Roles.GetRoleFor(bot):GetStartsFights()
    local kosZombies = TTTBots.Lib.GetConVarBool("kos_enemies")

    local bestDist = math.huge
    local bestPly = nil
    if isKillerRole or kosZombies then
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

--- KOS all non-Bot NPCs (Zombies, Headcrabs, etc)
---@param bot Bot
local function attackNPCs(bot)
    local npcs = TTTBots.Lib.GetNPCs()
    local closest = nil
    local minDist = math.huge
    for _, npc in pairs(npcs) do
        if bot:Visible(npc) then
            local dist = bot:GetPos():Distance(npc:GetPos())
            if dist < minDist then
                minDist = dist
                closest = npc
            end
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
    local role = TTTBots.Roles.GetRoleFor(attackTarget)
    if not role then return end
    local isAllies = TTTBots.Perception and TTTBots.Perception.IsPerceivedAlly(bot, attackTarget) or TTTBots.Roles.IsAllies(bot, attackTarget)
    if isAllies then
        Arb.RequestClearTarget(bot, "PREVENT_ALLY", PRI.ROLE_HOSTILITY)
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
    local role = TTTBots.Roles.GetRoleFor(attackTarget)
    if not role then return end
    local isAllies = TTTBots.Roles.IsAllies(bot, attackTarget)
    local isChecked = TTTBots.Match.CheckedPlayers[attackTarget] or nil
    if isAllies and isChecked then
        Arb.RequestClearTarget(bot, "PREVENT_CHECKED_ALLY", PRI.ROLE_HOSTILITY)
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
-- Combined prevent wrapper
-- ===========================================================================

local function preventAttackAll(bot)
    preventAttackAlly(bot)
    preventCloaked(bot)
    preventAttackAllies(bot)
    preventAttack(bot)
end

-- ===========================================================================
-- Master dispatcher
-- ===========================================================================

--- Run all hostility policy checks on a single bot.
---@param bot Bot
local function runHostilityPolicy(bot)
    -- Skip if the bot is fighting an NPC that isn't one of our bots
    if not (bot.attackTarget ~= nil and bot.attackTarget:IsNPC() and not table.HasValue(TTTBots.Bots, bot.attackTarget)) then
        attackKOSedByAll(bot)
        attackNPCs(bot)
        attackEnemies(bot)
        attackNonAllies(bot)
        attackZombies(bot)
        attackUnknowns(bot)
        continueMassacre(bot)
        preventAttackAll(bot)
        personalSpace(bot)
        noticeTraitorWeapons(bot)
    end
end

-- Export for the coordinator
TTTBots.Morality.RunHostilityPolicy = runHostilityPolicy

-- ===========================================================================
-- Timer — "Common Sense" tick (1 second interval)
-- ===========================================================================

timer.Create("TTTBots.Components.Morality.CommonSense", 1, 0, function()
    if not TTTBots.Match.IsRoundActive() then return end
    for i, bot in pairs(TTTBots.Bots) do
        if not bot or bot == NULL or not IsValid(bot) then continue end
        if not bot.components.chatter or not bot:BotLocomotor() then continue end
        if not lib.IsPlayerAlive(bot) then continue end
        runHostilityPolicy(bot)
    end
end)
