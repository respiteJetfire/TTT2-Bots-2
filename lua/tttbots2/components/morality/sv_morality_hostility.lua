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
---@param bot Bot
local function continueMassacre(bot)
    local isRedHanded = bot.redHandedTime and (CurTime() < bot.redHandedTime)
    local isKillerRole = TTTBots.Roles.GetRoleFor(bot):GetStartsFights()

    if isRedHanded and isKillerRole then
        local nonAllies = TTTBots.Roles.GetNonAllies(bot)
        local closest = TTTBots.Lib.GetClosest(nonAllies, bot:GetPos())
        if closest and closest ~= NULL then
            Arb.RequestAttackTarget(bot, closest, "CONTINUE_MASSACRE", PRI.ROLE_HOSTILITY)
        end
    end
end

--- Attack any player that is in the GetEnemies for our role
---@param bot Bot
local function attackEnemies(bot)
    local visible = TTTBots.Lib.GetAllWitnessesBasic(bot:EyePos(), TTTBots.Roles.GetNonAllies(bot))
    local isKillerRole = TTTBots.Roles.GetRoleFor(bot):GetStartsFights()
    local kosEnemies = TTTBots.Lib.GetConVarBool("kos_enemies")

    if isKillerRole or kosEnemies then
        local enemies = TTTBots.Roles.GetEnemies(bot)
        local closest = TTTBots.Lib.GetClosest(enemies, bot:GetPos())
        if closest and closest ~= NULL and TTTBots.Lib.IsPlayerAlive(closest) and table.HasValue(visible, closest) then
            Arb.RequestAttackTarget(bot, closest, "ROLE_ENEMY", PRI.ROLE_HOSTILITY)
        end
    end
end

--- Attack any player that is on TEAM_INFECTED and has a zombie player model
---@param bot Bot
local function attackZombies(bot)
    local visible = TTTBots.Lib.GetAllWitnessesBasic(bot:EyePos(), TTTBots.Roles.GetNonAllies(bot))
    local isKillerRole = TTTBots.Roles.GetRoleFor(bot):GetStartsFights()
    local kosZombies = TTTBots.Lib.GetConVarBool("kos_enemies")

    local bestDist = math.huge
    local bestPly = nil
    if isKillerRole or kosZombies then
        for _, ply in pairs(visible) do
            if ply:GetModel() == "models/player/corpse1.mdl" then
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

--- Attack any player that is in the GetNonAllies for our role
---@param bot Bot
local function attackNonAllies(bot)
    local visible = TTTBots.Lib.GetAllWitnessesBasic(bot:EyePos(), TTTBots.Roles.GetNonAllies(bot))
    local kosnonallies = TTTBots.Lib.GetConVarBool("kos_nonallies")
    local isINFECTEDs = INFECTEDS and INFECTEDS[bot]
    local kosrole = TTTBots.Roles.GetRoleFor(bot):GetKOSAll()

    if kosnonallies or isINFECTEDs or kosrole then
        local nonAllies = TTTBots.Roles.GetNonAllies(bot)
        local closest = TTTBots.Lib.GetClosest(nonAllies, bot:GetPos())
        if closest and closest ~= NULL and TTTBots.Lib.IsPlayerAlive(closest) and table.HasValue(visible, closest) then
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
    local isAllies = TTTBots.Roles.IsAllies(bot, attackTarget)
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
        if TTTBots.Roles.IsAllies(bot, other) then return false end

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

    local visible = TTTBots.Lib.GetAllWitnessesBasic(bot:EyePos(), TTTBots.Roles.GetNonAllies(bot))
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
