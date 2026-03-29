TTTBots.Plans = {
    PLANSTATES = {
        START = "Starting",    --- Initializing the plan.
        RUNNING = "Running",   --- Plan is in action.
        FINISHED = "Finished", --- Plan finished, everyone do your own thing.
        FAILED = "Failed",     --- Plan failed, everyone do your own thing.
        WAITING = "Waiting"    --- Waiting for round to start.
    },
    --- What a bot reports as its current state on its assigned ACTION
    BOTSTATES = {
        IDLE = "Idle/Preparing",   --- Idle or preparing to perform the assigned action.
        INPROGRESS = "InProgress", --- Attempting to perform the assigned action.
        FINISHED = "Finished",     --- Either failed or completed the action.
    },
    --- The actions assigned to a bot by the coordinator.
    ACTIONS = {
        PLANT = "PlantC4",       --- Plant C$ in a discreet location determined by the assigned bot.
        DEFUSE = "DefuseC4",     --- Defuse C4
        FOLLOW = "FollowPly",    --- Follow a target player peacefully (either a teammate or a future victim)
        GATHER = "Gather",       --- Gather with traitors around a position.
        ATTACK = "Attack",       --- Attack a certain target, or the nearest innocent if none specified.
        ATTACKANY = "AttackAny", --- Attack any player you can see that are on the enemy team.
        DEFEND = "Defend",       --- Defend a position from intruders, used after an attack order if we know others are around.
        ROAM = "Roam",           --- Roam around the map, primarily to be used for hunting players at low player counts.
        COORD_ATTACK = "CoordAttack", --- Coordinated attack: all assigned traitors converge near the target then attack simultaneously when enough are in position.
        IGNORE = "Ignore",       --- Ignore orders. This is seldom used and is mainly for bots who ignore orders. (personality quirk)
    },
    --- A list of all things/people that can be targeted by a bot. Mosly calculated at runtime
    PLANTARGETS = {
        RAND_POPULAR_AREA = "CalculatedPopularArea",     --- The most popular area, calculated by the coordinator.
        RAND_UNPOPULAR_AREA = "CalculatedUnpopularArea", --- The least popular area, calculated by the coordinator.
        ANY_BOMBSPOT = "CalculatedBombSpot",             --- The best calculated bomb spot, calculated by the coordinator.
        RAND_FRIENDLY = "RandomFriendly",                --- A friendly player, selected randomly
        RAND_FRIENDLY_HUMAN = "RandomFriendlyHuman",     --- A friendly human player, selected randomly
        RAND_ENEMY = "RandomEnemy",                      --- A non-traitor player, selected randomly
        RAND_POLICE = "RandomPolice",                    --- A police player, selected randomly
        NEAREST_ENEMY = "NearestEnemy",                  --- The nearest enemy player
        NEAREST_HIDINGSPOT = "NearestHidingSpot",        --- The nearest hiding spot
        FARTHEST_HIDINGSPOT = "FarthestHidingSpot",      --- The farthest hiding spot
        NEAREST_SNIPERSPOT = "NearestSniperSpot",        --- The nearest sniper spot
        FARTHEST_SNIPERSPOT = "FarthestSniperSpot",      --- The farthest sniper spot
        SHARED_ENEMY = "SharedEnemy",                      --- A single enemy chosen once per plan cycle; every traitor assigned this target gets the SAME player.
        SHARED_ISOLATED_ENEMY = "SharedIsolatedEnemy",    --- The most isolated enemy, cached per plan cycle so all traitors converge on the same victim.
        NEAREST_CORPSE_AREA = "NearestCorpseArea",        --- The area nearest a revivable corpse — used for revival-focused plans.
        NOT_APPLICABLE = "N/A",                          --- Not applicable, used for actions that don't require a target.
    },
    BotStatuses = {},
    CurrentPlanState = "",
    SelectedPlan = nil,
    --- Per-team plan state: { [teamName] = { SelectedPlan, CurrentPlanState, PlanStartTime, ... } }
    TeamPlans = {},
}
include("tttbots2/data/sv_planpresets.lua") --- Load data into TTTBots.Plans.PRESETS

--- When a bot wants to share the status with this module (bot->server), it will call this function.
function TTTBots.Plans.BotUpdateStatus(bot, status)
    local tbl = {
        bot = bot,
        status = status,
    }
    TTTBots.Plans.BotStatuses[bot] = tbl
end

--- Return the BOTSTATUS string of the bot's table within BotStatuses, else nil.
function TTTBots.Plans.GetBotState(bot)
    local tbl = TTTBots.Plans.BotStatuses[bot]
    if not tbl then return nil end
    return tbl.status
end

function TTTBots.Plans.Cleanup()
    TTTBots.Plans.BotStatuses = {}
    TTTBots.Plans.CurrentPlanState = "Waiting"
    TTTBots.Plans.SelectedPlan = nil
    TTTBots.Plans.PlanStartTime = 0
    TTTBots.Plans.SharedTargetCache = {} --- Reset per-job shared targets each round
    TTTBots.Plans.LastReEvalTime = 0
    TTTBots.Plans.LastCoordinatorCount = 0
    TTTBots.Plans.CachedLoadout = nil
    TTTBots.Plans.CachedEnemyDist = nil
    TTTBots.Plans.TeamPlans = {} --- Reset per-team plan state
end

TTTBots.Plans.Cleanup() -- Call when this script is first executed

---------------------------------------------------------------------------
-- Team Loadout Analysis
--
-- Inspects what weapons/items the coordinating team actually bought so that
-- plan selection can factor in the team's ACTUAL combat capabilities rather
-- than just player counts and role flags.
---------------------------------------------------------------------------

--- Weapon categories for loadout analysis. Each entry maps weapon classnames
--- to a capability tag. A coordinator having ANY weapon in the list sets that tag.
TTTBots.Plans.WeaponCategories = {
    HeavyFirepower = {
        "m9k_minigun", "weapon_ttt2_arsonthrower", "weapon_ttt_peacekeeper",
        "melonlauncher", "swep_orbitalfriendshipbeam",
    },
    StealthWeapons = {
        "weapon_ttt2_poison_dart", "weapon_ttt_deadringer",
    },
    SmartWeapons = {
        "ttt_smart_pistol", "weapon_ttt2_smart_bullets",
    },
    Explosives = {
        "weapon_ttt_c4", "weapon_ttt_jihad_bomb", "weapon_holyhand_grenade",
        "weapon_ttt_beenade", "weapon_ttt_banana", "weapon_ttt_artillerymarker",
        "weapon_ttt_ttt2_minethrower",
    },
    AreaDenial = {
        "weapon_ttt_turret", "weapon_ttt2_gravity_mine", "weapon_ttt_c4",
        "weapon_ttt_killersnail", "ttt_weeping_angel",
    },
    RevivalWeapons = {
        "weapon_ttt_defib_traitor", "weapon_ttt_mesdefi", "weapon_ttt2_markerdefi",
        "weapon_ttth_necrodefi", "weapon_ttt_defibrillator", "weapon_ttt2_medic_defibrillator",
    },
    ConversionWeapons = {
        "weapon_ttt2_sidekick_deagle", "weapon_ttt2_medic_deagle",
        "weapon_ttt2_doctor_deagle", "weapon_ttt2_cursed_deagle",
        "weapon_ttt_defector_jihad",
    },
    GrenadeWeapons = {
        "weapon_ttt2_emp_grenade", "weapon_ttt2_gravity_mine",
        "weapon_ttt_reveal_nade", "weapon_ttt_beenade",
        "weapon_holyhand_grenade", "weapon_ttt_banana",
        "weapon_ttt_ttt2_minethrower",
    },
    DisruptionWeapons = {
        "weapon_ttt2_emp_grenade", "weapon_ttt_timestop",
        "weapon_ttt_dancegun", "weapon_ttt2_hologram_decoy",
    },
    SurvivalItems = {
        "item_ttt_armor", "item_ttt_disguiser", "item_ttt_infinishoot",
    },
    HealingWeapons = {
        "weapon_ttt_medigun", "weapon_ttt_health_station",
    },
}

--- Analyze the loadout of all alive coordinators and return a structured
--- report of team capabilities, credit reserves, and weapon synergies.
--- @return table loadout analysis data
function TTTBots.Plans.AnalyzeTeamLoadout()
    local cats = TTTBots.Plans.WeaponCategories
    local aliveCoordinators = TTTBots.Lib.FilterTable(TTTBots.Match.AlivePlayers, function(ply)
        return TTTBots.Roles.GetRoleFor(ply):GetCanCoordinate()
    end)

    local loadout = {
        --- Boolean flags: does ANY coordinator carry a weapon in this category?
        HasHeavyFirepower   = false,
        HasStealthWeapons   = false,
        HasSmartWeapons     = false,
        HasExplosives       = false,
        HasAreaDenial       = false,
        HasRevivalWeapons   = false,
        HasConversionWeapons = false,
        HasGrenades         = false,
        HasDisruption       = false,
        HasSurvivalItems    = false,
        HasHealing          = false,
        --- Counts: how many coordinators carry weapons in each category
        HeavyFirepowerCount   = 0,
        StealthWeaponsCount   = 0,
        SmartWeaponsCount     = 0,
        ExplosivesCount       = 0,
        AreaDenialCount       = 0,
        RevivalWeaponsCount   = 0,
        ConversionWeaponsCount = 0,
        GrenadeCount          = 0,
        DisruptionCount       = 0,
        SurvivalItemsCount    = 0,
        HealingCount          = 0,
        --- Team resource stats
        TotalCreditsRemaining = 0,
        CoordinatorsWithCredits = 0,
        TotalCoordinators     = #aliveCoordinators,
        --- Aggregated combat strength estimate (0-100)
        TeamFirepowerScore    = 0,
        TeamStealthScore      = 0,
        TeamUtilityScore      = 0,
    }

    local firepowerScore = 0
    local stealthScore = 0
    local utilityScore = 0

    for _, coord in ipairs(aliveCoordinators) do
        if not IsValid(coord) then continue end

        -- Credit tracking
        local credits = coord.GetCredits and coord:GetCredits() or 0
        loadout.TotalCreditsRemaining = loadout.TotalCreditsRemaining + credits
        if credits > 0 then
            loadout.CoordinatorsWithCredits = loadout.CoordinatorsWithCredits + 1
        end

        -- Check each weapon category
        local function checkCategory(catName, flagName, countName)
            local classes = cats[catName]
            if not classes then return end
            for _, cls in ipairs(classes) do
                if coord:HasWeapon(cls) then
                    loadout[flagName] = true
                    loadout[countName] = loadout[countName] + 1
                    return -- one match per coordinator per category
                end
            end
        end

        checkCategory("HeavyFirepower",     "HasHeavyFirepower",    "HeavyFirepowerCount")
        checkCategory("StealthWeapons",     "HasStealthWeapons",    "StealthWeaponsCount")
        checkCategory("SmartWeapons",       "HasSmartWeapons",      "SmartWeaponsCount")
        checkCategory("Explosives",         "HasExplosives",        "ExplosivesCount")
        checkCategory("AreaDenial",         "HasAreaDenial",        "AreaDenialCount")
        checkCategory("RevivalWeapons",     "HasRevivalWeapons",    "RevivalWeaponsCount")
        checkCategory("ConversionWeapons",  "HasConversionWeapons", "ConversionWeaponsCount")
        checkCategory("GrenadeWeapons",     "HasGrenades",          "GrenadeCount")
        checkCategory("DisruptionWeapons",  "HasDisruption",        "DisruptionCount")
        checkCategory("SurvivalItems",      "HasSurvivalItems",     "SurvivalItemsCount")
        checkCategory("HealingWeapons",     "HasHealing",           "HealingCount")

        -- Per-coordinator combat scoring
        local weps = coord:GetWeapons()
        for _, wep in ipairs(weps) do
            if not IsValid(wep) then continue end
            local cls = wep:GetClass()
            -- Heavy weapons contribute raw firepower
            if table.HasValue(cats.HeavyFirepower, cls) then
                firepowerScore = firepowerScore + 20
            elseif table.HasValue(cats.SmartWeapons, cls) then
                firepowerScore = firepowerScore + 15
            end
            -- Stealth weapons contribute stealth
            if table.HasValue(cats.StealthWeapons, cls) then
                stealthScore = stealthScore + 18
            end
            -- Utility
            if table.HasValue(cats.AreaDenial, cls) then
                utilityScore = utilityScore + 12
            end
            if table.HasValue(cats.DisruptionWeapons, cls) then
                utilityScore = utilityScore + 10
            end
            if table.HasValue(cats.RevivalWeapons, cls) then
                utilityScore = utilityScore + 15
            end
            if table.HasValue(cats.ConversionWeapons, cls) then
                utilityScore = utilityScore + 15
            end
            if table.HasValue(cats.GrenadeWeapons, cls) then
                utilityScore = utilityScore + 8
            end
        end
    end

    -- Normalize scores to 0-100 range based on team size
    local divisor = math.max(#aliveCoordinators, 1)
    loadout.TeamFirepowerScore = math.Clamp(firepowerScore / divisor * 3, 0, 100)
    loadout.TeamStealthScore   = math.Clamp(stealthScore / divisor * 3, 0, 100)
    loadout.TeamUtilityScore   = math.Clamp(utilityScore / divisor * 2, 0, 100)

    return loadout
end

--- Enemy distribution analysis: how spread out or grouped are the enemies?
--- Returns a table with isolation stats useful for choosing between ambush
--- and direct-assault plans.
--- @return table enemy distribution data
function TTTBots.Plans.AnalyzeEnemyDistribution()
    local aliveCoordinators = TTTBots.Lib.FilterTable(TTTBots.Match.AlivePlayers, function(ply)
        return TTTBots.Roles.GetRoleFor(ply):GetCanCoordinate()
    end)
    local enemies = TTTBots.Lib.FilterTable(TTTBots.Match.AlivePlayers, function(ply)
        for _, coord in ipairs(aliveCoordinators) do
            if TTTBots.Roles.IsAllies(coord, ply) then return false end
        end
        return true
    end)

    local result = {
        TotalEnemies     = #enemies,
        IsolatedEnemies  = 0,   -- enemies with no other enemy within 1200u
        ClusteredEnemies = 0,   -- enemies with 2+ others within 800u
        AvgEnemyGroupSize = 1,
        HasPoliceCluster = false, -- are police grouped with others?
    }

    if #enemies == 0 then return result end

    local clusterThreshold = 800
    local isolationThreshold = 1200
    local totalNearby = 0

    for _, enemy in ipairs(enemies) do
        if not IsValid(enemy) then continue end
        local nearbyCount = 0
        local ePos = enemy:GetPos()
        for _, other in ipairs(enemies) do
            if other == enemy or not IsValid(other) then continue end
            local dist = ePos:Distance(other:GetPos())
            if dist <= clusterThreshold then
                nearbyCount = nearbyCount + 1
            end
        end
        totalNearby = totalNearby + nearbyCount

        if nearbyCount == 0 then
            -- Check full isolation range
            local isolated = true
            for _, other in ipairs(enemies) do
                if other == enemy or not IsValid(other) then continue end
                if ePos:Distance(other:GetPos()) <= isolationThreshold then
                    isolated = false
                    break
                end
            end
            if isolated then
                result.IsolatedEnemies = result.IsolatedEnemies + 1
            end
        elseif nearbyCount >= 2 then
            result.ClusteredEnemies = result.ClusteredEnemies + 1
        end

        -- Check if this is a police player in a cluster
        if nearbyCount >= 1 then
            local isPolice = false
            if enemy:GetRoleStringRaw() == "detective" then isPolice = true end
            if enemy.GetSubRoleData then
                local rd = enemy:GetSubRoleData()
                if rd and rd.isPolicingRole then isPolice = true end
            end
            if isPolice then result.HasPoliceCluster = true end
        end
    end

    result.AvgEnemyGroupSize = 1 + (totalNearby / math.max(#enemies, 1))

    return result
end

--- Cache for loadout/distribution analysis — refreshed once per plan selection.
TTTBots.Plans.CachedLoadout = nil
TTTBots.Plans.CachedEnemyDist = nil

--- Build (or return cached) analysis data for the current round state.
function TTTBots.Plans.GetAnalysisData()
    -- Only recompute if cache is nil (cleared on plan selection or round reset)
    if not TTTBots.Plans.CachedLoadout then
        TTTBots.Plans.CachedLoadout = TTTBots.Plans.AnalyzeTeamLoadout()
    end
    if not TTTBots.Plans.CachedEnemyDist then
        TTTBots.Plans.CachedEnemyDist = TTTBots.Plans.AnalyzeEnemyDistribution()
    end
    return TTTBots.Plans.CachedLoadout, TTTBots.Plans.CachedEnemyDist
end

--- Invalidate cached analysis (called on plan changes/round reset).
function TTTBots.Plans.InvalidateAnalysisCache()
    TTTBots.Plans.CachedLoadout = nil
    TTTBots.Plans.CachedEnemyDist = nil
end

local conditionsHashedFuncs = {
    PlyMin = function(conditions, data)
        return data.NumPlysA >= (conditions.PlyMin or 0)
    end,
    PlyMax = function(conditions, data)
        return data.NumPlysA <= (conditions.PlyMax or math.huge)
    end,
    MinTraitors = function(conditions, data)
        return data.NumTraitorsA >= (conditions.MinTraitors or 0)
    end,
    MaxTraitors = function(conditions, data)
        return data.NumTraitorsA <= (conditions.MaxTraitors or math.huge)
    end,
    MinHumanTraitors = function(conditions, data)
        return data.NumHumanTraitorsA >= (conditions.MinHumanTraitors or 0)
    end,
    MaxHumanTraitors = function(conditions, data)
        return data.NumHumanTraitorsA <= (conditions.MaxHumanTraitors or math.huge)
    end,
    Chance = function(conditions, data)
        return math.random(1, 100) <= (conditions.Chance or 100)
    end,
    --- Require at least one living police-type player (detective, sheriff, etc.)
    RequiresPolice = function(conditions, data)
        if not conditions.RequiresPolice then return true end
        return data.HasPolice
    end,
    --- Require the coordinating team to be outnumbered (fewer coordinators than enemies).
    --- Value is a ratio threshold, e.g. 0.5 means coordinators are at most half of enemies.
    TeamOutnumberedRatio = function(conditions, data)
        if not conditions.TeamOutnumberedRatio then return true end
        if data.NumEnemiesA <= 0 then return false end
        return (data.NumCoordinatorsA / data.NumEnemiesA) <= conditions.TeamOutnumberedRatio
    end,
    --- Require at least one coordinator to have a revival weapon (role defib, mesmerist defib, etc.)
    RequiresReviveCapability = function(conditions, data)
        if not conditions.RequiresReviveCapability then return true end
        return data.HasReviveCapability
    end,
    --- Require at least one coordinator to have a conversion weapon (sidekick deagle, medic deagle, etc.)
    RequiresConvertCapability = function(conditions, data)
        if not conditions.RequiresConvertCapability then return true end
        return data.HasConvertCapability
    end,
    --- Require at least N revivable corpses on the map
    MinCorpses = function(conditions, data)
        return data.NumCorpses >= (conditions.MinCorpses or 0)
    end,
    --- Require that revive OR convert capability exists
    RequiresReviveOrConvert = function(conditions, data)
        if not conditions.RequiresReviveOrConvert then return true end
        return data.HasReviveCapability or data.HasConvertCapability
    end,
    --- Require the 200-damage knife mod to be installed
    KnifeModInstalled = function(conditions, data)
        if not conditions.KnifeModInstalled then return true end
        return data.KnifeModInstalled
    end,
    --- Require team to have heavy firepower weapons (minigun, arson thrower, etc.)
    RequiresHeavyFirepower = function(conditions, data)
        if not conditions.RequiresHeavyFirepower then return true end
        return data.Loadout and data.Loadout.HasHeavyFirepower
    end,
    --- Require team to have stealth weapons (poison dart, dead ringer, etc.)
    RequiresStealthWeapons = function(conditions, data)
        if not conditions.RequiresStealthWeapons then return true end
        return data.Loadout and data.Loadout.HasStealthWeapons
    end,
    --- Require team to have smart weapons (smart pistol, smart bullets)
    RequiresSmartWeapons = function(conditions, data)
        if not conditions.RequiresSmartWeapons then return true end
        return data.Loadout and data.Loadout.HasSmartWeapons
    end,
    --- Require team to have explosive weapons (C4, jihad, grenades, etc.)
    RequiresExplosives = function(conditions, data)
        if not conditions.RequiresExplosives then return true end
        return data.Loadout and data.Loadout.HasExplosives
    end,
    --- Require team to have area denial capabilities (turret, mines, C4, etc.)
    RequiresAreaDenial = function(conditions, data)
        if not conditions.RequiresAreaDenial then return true end
        return data.Loadout and data.Loadout.HasAreaDenial
    end,
    --- Require team to have disruption weapons (EMP, timestop, dance gun, etc.)
    RequiresDisruption = function(conditions, data)
        if not conditions.RequiresDisruption then return true end
        return data.Loadout and data.Loadout.HasDisruption
    end,
    --- Require a minimum number of coordinators with heavy firepower
    MinHeavyFirepower = function(conditions, data)
        if not conditions.MinHeavyFirepower then return true end
        return data.Loadout and (data.Loadout.HeavyFirepowerCount or 0) >= conditions.MinHeavyFirepower
    end,
    --- Require a minimum team firepower score (0-100)
    MinFirepowerScore = function(conditions, data)
        if not conditions.MinFirepowerScore then return true end
        return data.Loadout and (data.Loadout.TeamFirepowerScore or 0) >= conditions.MinFirepowerScore
    end,
    --- Require a minimum team stealth score (0-100)
    MinStealthScore = function(conditions, data)
        if not conditions.MinStealthScore then return true end
        return data.Loadout and (data.Loadout.TeamStealthScore or 0) >= conditions.MinStealthScore
    end,
    --- Require there to be isolated enemies available
    MinIsolatedEnemies = function(conditions, data)
        if not conditions.MinIsolatedEnemies then return true end
        return data.EnemyDist and (data.EnemyDist.IsolatedEnemies or 0) >= conditions.MinIsolatedEnemies
    end,
    --- Require enemies to be clustered (for AoE/area-denial plans)
    MinClusteredEnemies = function(conditions, data)
        if not conditions.MinClusteredEnemies then return true end
        return data.EnemyDist and (data.EnemyDist.ClusteredEnemies or 0) >= conditions.MinClusteredEnemies
    end,
    --- Require the team to still have unspent credits (for deferred-buy plans)
    MinTeamCredits = function(conditions, data)
        if not conditions.MinTeamCredits then return true end
        return data.Loadout and (data.Loadout.TotalCreditsRemaining or 0) >= conditions.MinTeamCredits
    end,
}
function TTTBots.Plans.AreConditionsValid(conditions, filterTeam)
    -- Coordinators: any role with GetCanCoordinate (traitors, necromancer, etc.)
    -- When filterTeam is specified, only count coordinators on that team.
    local aliveCoordinators = TTTBots.Lib.FilterTable(TTTBots.Match.AlivePlayers,
        function(ply)
            if not TTTBots.Roles.GetRoleFor(ply):GetCanCoordinate() then return false end
            if filterTeam then
                local team = ply.GetTeam and ply:GetTeam()
                return team == filterTeam
            end
            return true
        end)
    -- Actual traitor-team players only (for MinTraitors/MaxTraitors conditions)
    -- When filterTeam is specified, count members of THAT team instead.
    local countTeam = filterTeam or TEAM_TRAITOR
    local aliveTraitors = TTTBots.Lib.FilterTable(TTTBots.Match.AlivePlayers,
        function(ply)
            local team = ply.GetTeam and ply:GetTeam()
            return team == countTeam
        end)
    -- Check if any police-type player exists
    local hasPolice = #TTTBots.Lib.FilterTable(TTTBots.Match.AlivePlayers, function(ply)
        if not TTTBots.Lib.IsPlayerAlive(ply) then return false end
        if ply:GetRoleStringRaw() == "detective" then return true end
        if ply.GetSubRoleData then
            local rd = ply:GetSubRoleData()
            if rd and rd.isPolicingRole then return true end
        end
        return false
    end) > 0
    -- Count enemies: alive players who are NOT coordinators and NOT allied to any coordinator
    local aliveEnemies = TTTBots.Lib.FilterTable(TTTBots.Match.AlivePlayers, function(ply)
        for _, coord in ipairs(aliveCoordinators) do
            if TTTBots.Roles.IsAllies(coord, ply) then return false end
        end
        return true
    end)

    -- Check if any coordinator has revival capability (defib weapons)
    local reviveWeaponClasses = {
        "weapon_ttt_defib_traitor", "weapon_ttt_mesdefi", "weapon_ttt2_markerdefi",
        "weapon_ttth_necrodefi", "weapon_ttt_defibrillator", "weapon_ttt2_medic_defibrillator",
    }
    local convertWeaponClasses = {
        "weapon_ttt2_sidekick_deagle", "weapon_ttt2_medic_deagle", "weapon_ttt2_doctor_deagle",
        "weapon_ttt2_cursed_deagle", "weapon_ttt_defector_jihad",
    }
    -- Buyable defib classes and their credit costs — used to check if a
    -- coordinator who doesn't HAVE a defib yet could BUY one mid-round.
    local buyableReviveWeapons = {
        { Class = "weapon_ttt_defibrillator", Price = 1 },   -- standard defib (deferred price)
        { Class = "weapon_ttt_defib_traitor",  Price = 1 },   -- role defib
    }
    local hasReviveCapability = false
    local hasConvertCapability = false
    for _, coord in ipairs(aliveCoordinators) do
        if not IsValid(coord) then continue end
        -- Already carrying a revive weapon?
        for _, cls in ipairs(reviveWeaponClasses) do
            if coord:HasWeapon(cls) then hasReviveCapability = true break end
        end
        -- Not carrying one — could they BUY one? (has credits + weapon exists on server)
        if not hasReviveCapability then
            local credits = coord.GetCredits and coord:GetCredits() or 0
            for _, info in ipairs(buyableReviveWeapons) do
                if credits >= info.Price and TTTBots.Lib.WepClassExists(info.Class) then
                    hasReviveCapability = true
                    break
                end
            end
        end
        for _, cls in ipairs(convertWeaponClasses) do
            if coord:HasWeapon(cls) then hasConvertCapability = true break end
        end
        if hasReviveCapability and hasConvertCapability then break end
    end

    -- Count revivable corpses
    local numCorpses = 0
    local corpses = TTTBots.Lib.GetRevivableCorpses and TTTBots.Lib.GetRevivableCorpses() or {}
    numCorpses = #corpses

    -- Check if the 200-damage knife mod is installed
    local knifeModInstalled = false
    if TTTBots.Behaviors and TTTBots.Behaviors.KnifeStalk and TTTBots.Behaviors.KnifeStalk.IsKnifeModInstalled then
        knifeModInstalled = TTTBots.Behaviors.KnifeStalk.IsKnifeModInstalled()
    end

    -- Fetch loadout and enemy-distribution analysis (cached per plan-selection cycle)
    local loadout, enemyDist = TTTBots.Plans.GetAnalysisData()

    local Data = {
        NumPlysA = #TTTBots.Match.AlivePlayers,
        NumTraitorsA = #aliveTraitors,
        NumCoordinatorsA = #aliveCoordinators,
        NumHumanTraitorsA = #TTTBots.Lib.FilterTable(aliveTraitors, function(ply) return not ply:IsBot() end),
        HasPolice = hasPolice,
        NumEnemiesA = #aliveEnemies,
        HasReviveCapability = hasReviveCapability,
        HasConvertCapability = hasConvertCapability,
        NumCorpses = numCorpses,
        KnifeModInstalled = knifeModInstalled,
        -- Loadout and enemy distribution data for dynamic plan conditions
        Loadout = loadout,
        EnemyDist = enemyDist,
    }
    for key, value in pairs(conditions) do
        if key == nil or value == nil then continue end
        local func = conditionsHashedFuncs[key]
        if func then
            local result = func(conditions, Data)
            if not result then
                return false, key
            end
        end
    end

    return true
end

function TTTBots.Plans.GetCurrentPlan()
    return TTTBots.Plans.SelectedPlan
end

function TTTBots.Plans.GetName()
    local plan = TTTBots.Plans.SelectedPlan
    if not plan then return "Not selected" end
    return plan.Name
end

--- Priority order for plan selection.
--- Revival/recovery presets are checked FIRST so that outnumbered teams
--- with revival/conversion capability don't default to pure-combat plans.
--- Within each tier the iteration is deterministic (ipairs).
TTTBots.Plans.PresetPriority = {
    -- Tier 1: Revival / conversion recovery (most restrictive conditions)
    "CorpseHarvest",
    "LowPlayer_RevivalRecovery",
    "MediumPlayer_RevivalRecovery",
    "LargePlayer_RevivalRecovery",
    "ConversionRecovery",
    -- Tier 1.5: Knife-stalk plans (200dmg knife mod — silent elimination)
    "KnifeHunter_LowPlayer",
    "KnifeHunter_MediumPlayer",
    "KnifeHunter_LargePlayer",
    -- Tier 2: Loadout-aware dynamic plans (weapon synergy)
    "Loadout_FirepowerBlitz",
    "Loadout_StealthAssassination",
    "Loadout_SmartWeaponsStrike",
    "Loadout_AreaDenialLockdown",
    "Loadout_ExplosiveChaos",
    "Loadout_DisruptAndStrike",
    "Loadout_RevivalSnowball",
    "Loadout_MixedAdaptive",
    "Loadout_CreditReserveAdaptive",
    "Loadout_IsolationHunters",
    -- Tier 3: Coordinated group attacks
    "MediumPlayerCount_DetectiveHunt",
    "AveragePlayerCount_CoordinatedBlitz",
    "MediumPlayerCount_HitSquad",
    "LowPlayerCount_WolfPack",
    -- Tier 4: Standard plans (broadest conditions, catch-all)
    "LowPlayerCount_Standard",
    "MediumPlayerCount_Standard",
    "AveragePlayerCount_Standard",
}

---------------------------------------------------------------------------
-- Loadout Synergy Scoring
--
-- Each preset can declare a SynergyScore function that receives the team
-- loadout and enemy distribution data. It returns a bonus (positive) or
-- penalty (negative) that is added to the preset's base Chance to produce
-- a final selection weight.  Presets without SynergyScore use Chance as-is.
---------------------------------------------------------------------------

--- Calculate a synergy score for a preset given the current team state.
--- @param preset table the plan preset
--- @param loadout table result from AnalyzeTeamLoadout
--- @param enemyDist table result from AnalyzeEnemyDistribution
--- @return number synergy bonus (can be negative)
function TTTBots.Plans.CalcSynergyScore(preset, loadout, enemyDist)
    if preset.SynergyScore then
        return preset.SynergyScore(loadout, enemyDist)
    end
    return 0
end

--- Returns the best preset using weighted scoring that factors in both
--- priority ordering and weapon/situational synergy.  Valid presets from
--- higher tiers still get priority, but within each tier the preset with
--- the highest (Chance + SynergyScore) wins via weighted random selection.
--- @param filterTeam string|nil  When provided, only presets tagged with this Team are considered.
function TTTBots.Plans.GetFirstBestPreset(filterTeam)
    local PRESETS = TTTBots.Plans.PRESETS
    local Default = PRESETS.Default

    -- Ensure analysis cache is fresh for this selection cycle
    TTTBots.Plans.InvalidateAnalysisCache()
    local loadout, enemyDist = TTTBots.Plans.GetAnalysisData()

    -- Collect all valid presets with their effective weights
    local candidates = {}
    local totalWeight = 0

    -- Walk the explicit priority list first
    for priority, name in ipairs(TTTBots.Plans.PresetPriority) do
        local preset = PRESETS[name]
        if not preset then continue end

        -- Team filter: skip presets not matching the requested team
        if filterTeam and preset.Team and preset.Team ~= filterTeam then continue end
        -- If no filterTeam, default to only TEAM_TRAITOR presets (backward compat)
        if not filterTeam and preset.Team and preset.Team ~= TEAM_TRAITOR then continue end

        -- Test conditions WITHOUT the random Chance roll — we handle Chance as weight
        local baseChance = preset.Conditions.Chance or 100
        local condCopy = {}
        for k, v in pairs(preset.Conditions) do condCopy[k] = v end
        condCopy.Chance = 100  -- bypass random roll; use Chance as base weight
        local valid = TTTBots.Plans.AreConditionsValid(condCopy, filterTeam)
        if not valid then continue end

        -- Calculate effective weight: base chance + synergy bonus, clamped to [5, 200]
        local synergy = TTTBots.Plans.CalcSynergyScore(preset, loadout, enemyDist)
        -- Higher-tier presets (lower index) get a priority bonus
        local tierBonus = math.max(0, 20 - priority)
        -- Learning modifier: plans that historically win more get a boost
        local learningBonus = 0
        if TTTBots.PlanLearning then
            learningBonus = TTTBots.PlanLearning.GetLearningModifier(name)
        end
        local weight = math.Clamp(baseChance + synergy + tierBonus + learningBonus, 5, 200)

        candidates[#candidates + 1] = { preset = preset, weight = weight }
        totalWeight = totalWeight + weight
    end

    -- Fallback: check any presets NOT in the priority list (custom / add-on presets)
    local prioritySet = {}
    for _, name in ipairs(TTTBots.Plans.PresetPriority) do prioritySet[name] = true end
    for name, preset in pairs(PRESETS) do
        if name ~= "Default" and not prioritySet[name] then
            -- Team filter: skip presets not matching the requested team
            if filterTeam and preset.Team and preset.Team ~= filterTeam then continue end
            if not filterTeam and preset.Team and preset.Team ~= TEAM_TRAITOR then continue end

            local baseChance = preset.Conditions.Chance or 100
            local condCopy = {}
            for k, v in pairs(preset.Conditions) do condCopy[k] = v end
            condCopy.Chance = 100
            local valid = TTTBots.Plans.AreConditionsValid(condCopy, filterTeam)
            if valid then
                local synergy = TTTBots.Plans.CalcSynergyScore(preset, loadout, enemyDist)
                -- Learning modifier for custom/add-on presets too
                local learningBonus = 0
                if TTTBots.PlanLearning then
                    learningBonus = TTTBots.PlanLearning.GetLearningModifier(name)
                end
                local weight = math.Clamp(baseChance + synergy + learningBonus, 5, 200)
                candidates[#candidates + 1] = { preset = preset, weight = weight }
                totalWeight = totalWeight + weight
            end
        end
    end

    -- Weighted random selection from valid candidates
    if #candidates > 0 and totalWeight > 0 then
        local roll = math.Rand(0, totalWeight)
        local running = 0
        for _, entry in ipairs(candidates) do
            running = running + entry.weight
            if roll <= running then
                return entry.preset
            end
        end
        return candidates[#candidates].preset
    end

    return Default
end

TTTBots.Plans.LastReEvalTime = 0
TTTBots.Plans.LastCoordinatorCount = 0
TTTBots.Plans.ReEvalCooldown = 10 -- seconds between re-evaluation checks

---------------------------------------------------------------------------
-- Per-Team Plan Helpers
--
-- Returns all non-innocent teams that currently have alive coordinators.
-- Each team gets its own plan selection and state tracking.
---------------------------------------------------------------------------

--- Get all teams that have at least one alive coordinator bot.
--- @return table teams  list of team name strings (e.g. {"traitors", "jackals"})
function TTTBots.Plans.GetActiveCoordinatorTeams()
    local teamSet = {}
    for _, ply in ipairs(TTTBots.Match.AlivePlayers or {}) do
        if not IsValid(ply) then continue end
        local role = TTTBots.Roles.GetRoleFor(ply)
        if not role or not role:GetCanCoordinate() then continue end
        local team = ply.GetTeam and ply:GetTeam()
        if team and team ~= TEAM_INNOCENT and team ~= TEAM_NONE then
            teamSet[team] = true
        end
    end
    local result = {}
    for team in pairs(teamSet) do
        result[#result + 1] = team
    end
    return result
end

--- Get or create the per-team plan state table.
--- @param team string  team name
--- @return table state  per-team plan state
function TTTBots.Plans.GetTeamPlanState(team)
    if not TTTBots.Plans.TeamPlans[team] then
        TTTBots.Plans.TeamPlans[team] = {
            SelectedPlan = nil,
            CurrentPlanState = TTTBots.Plans.PLANSTATES.WAITING,
            PlanStartTime = 0,
            SharedTargetCache = {},
            LastReEvalTime = 0,
            LastCoordinatorCount = 0,
            BotStatuses = {},
        }
    end
    return TTTBots.Plans.TeamPlans[team]
end

--- Get the active plan for a specific team (used by FollowPlan behavior).
--- Falls back to the legacy SelectedPlan for TEAM_TRAITOR backward compat.
--- @param team string  team name
--- @return table|nil plan  the selected plan or nil
function TTTBots.Plans.GetPlanForTeam(team)
    local state = TTTBots.Plans.TeamPlans[team]
    if state and state.SelectedPlan then
        return state.SelectedPlan
    end
    -- Backward compat: legacy SelectedPlan is always for TEAM_TRAITOR
    if team == TEAM_TRAITOR then
        return TTTBots.Plans.SelectedPlan
    end
    return nil
end

--- Check whether the current plan should be swapped for a better one.
--- Triggers when the coordinator team loses members (ally death) and a
--- revival/recovery plan becomes available.  Throttled so we don't re-evaluate
--- every tick.
function TTTBots.Plans.ShouldReEvaluatePlan()
    local now = CurTime()
    if (now - TTTBots.Plans.LastReEvalTime) < TTTBots.Plans.ReEvalCooldown then return false end
    TTTBots.Plans.LastReEvalTime = now

    -- Count current coordinators
    local aliveCoordinators = TTTBots.Lib.FilterTable(TTTBots.Match.AlivePlayers, function(ply)
        return TTTBots.Roles.GetRoleFor(ply):GetCanCoordinate()
    end)
    local currentCount = #aliveCoordinators

    -- On first call, just record the baseline.
    if TTTBots.Plans.LastCoordinatorCount == 0 then
        TTTBots.Plans.LastCoordinatorCount = currentCount
        return false
    end

    -- If no coordinators died since last check, no need to re-evaluate.
    if currentCount >= TTTBots.Plans.LastCoordinatorCount then
        TTTBots.Plans.LastCoordinatorCount = currentCount
        return false
    end

    TTTBots.Plans.LastCoordinatorCount = currentCount

    -- A coordinator died — check if a different plan would now be better.
    local currentPlan = TTTBots.Plans.SelectedPlan
    if not currentPlan then return false end

    -- Revival/recovery plan names that take priority when conditions shift
    local revivalPlanNames = {
        CorpseHarvest = true,
        LowPlayer_RevivalRecovery = true,
        MediumPlayer_RevivalRecovery = true,
        LargePlayer_RevivalRecovery = true,
        ConversionRecovery = true,
    }

    -- If already on a revival plan, only re-evaluate if we're no longer outnumbered
    -- (team recovered via successful revives) — switch to an attack plan.
    if revivalPlanNames[currentPlan.Name] then
        local aliveCoords = TTTBots.Lib.FilterTable(TTTBots.Match.AlivePlayers, function(ply)
            return TTTBots.Roles.GetRoleFor(ply):GetCanCoordinate()
        end)
        local aliveEnemies = TTTBots.Lib.FilterTable(TTTBots.Match.AlivePlayers, function(ply)
            for _, coord in ipairs(aliveCoords) do
                if TTTBots.Roles.IsAllies(coord, ply) then return false end
            end
            return true
        end)
        -- If we're no longer significantly outnumbered, switch to offense
        if #aliveEnemies > 0 and (#aliveCoords / #aliveEnemies) > 0.8 then
            return true
        end
        return false
    end

    -- Invalidate the analysis cache so we get fresh data
    TTTBots.Plans.InvalidateAnalysisCache()

    -- See if a different plan would now be valid with better synergy
    local bestPreset = TTTBots.Plans.GetFirstBestPreset()
    if bestPreset and bestPreset.Name ~= currentPlan.Name then
        -- Only swap if the new preset is meaningfully different (revival plan,
        -- or a loadout-specific plan that now matches better)
        if revivalPlanNames[bestPreset.Name] then return true end
        if bestPreset.Conditions.RequiresHeavyFirepower
            or bestPreset.Conditions.RequiresStealthWeapons
            or bestPreset.Conditions.RequiresSmartWeapons
            or bestPreset.Conditions.RequiresAreaDenial then
            return true
        end
    end

    return false
end

function TTTBots.Plans.Tick()
    if not TTTBots.Match.RoundActive then
        TTTBots.Plans.Cleanup()
        return
    end

    -- Legacy TEAM_TRAITOR plan selection (backward compatible)
    if not TTTBots.Plans.SelectedPlan then
        TTTBots.Plans.InvalidateAnalysisCache()
        TTTBots.Plans.SelectedPlan = TTTBots.Lib.DeepCopy(TTTBots.Plans.GetFirstBestPreset(TEAM_TRAITOR))
        TTTBots.Plans.CurrentPlanState = TTTBots.Plans.PLANSTATES.START
        TTTBots.Plans.PlanStartTime = CurTime()
        TTTBots.Plans.LastCoordinatorCount = 0  -- reset for re-eval tracking
        -- Notify plan learning system of the selected plan
        if TTTBots.PlanLearning and TTTBots.Plans.SelectedPlan then
            TTTBots.PlanLearning.OnPlanSelected(TTTBots.Plans.SelectedPlan.Name)
        end
        -- Mirror into per-team state
        local tState = TTTBots.Plans.GetTeamPlanState(TEAM_TRAITOR)
        tState.SelectedPlan = TTTBots.Plans.SelectedPlan
        tState.CurrentPlanState = TTTBots.Plans.CurrentPlanState
        tState.PlanStartTime = TTTBots.Plans.PlanStartTime
    end

    -- Mid-round re-evaluation for traitor team
    if TTTBots.Plans.CurrentPlanState == TTTBots.Plans.PLANSTATES.RUNNING then
        if TTTBots.Plans.ShouldReEvaluatePlan() then
            TTTBots.Plans.BotStatuses = {}
            TTTBots.Plans.SharedTargetCache = {}
            TTTBots.Plans.InvalidateAnalysisCache()
            TTTBots.Plans.SelectedPlan = TTTBots.Lib.DeepCopy(TTTBots.Plans.GetFirstBestPreset(TEAM_TRAITOR))
            TTTBots.Plans.CurrentPlanState = TTTBots.Plans.PLANSTATES.START
            TTTBots.Plans.PlanStartTime = CurTime()
            if TTTBots.PlanLearning and TTTBots.Plans.SelectedPlan then
                TTTBots.PlanLearning.OnPlanSelected(TTTBots.Plans.SelectedPlan.Name)
            end
            -- Mirror into per-team state
            local tState = TTTBots.Plans.GetTeamPlanState(TEAM_TRAITOR)
            tState.SelectedPlan = TTTBots.Plans.SelectedPlan
            tState.CurrentPlanState = TTTBots.Plans.CurrentPlanState
            tState.PlanStartTime = TTTBots.Plans.PlanStartTime
            return
        end
    end

    -- Transition out of START for traitor plan
    if TTTBots.Plans.CurrentPlanState == TTTBots.Plans.PLANSTATES.START then
        local startedAt = TTTBots.Plans.PlanStartTime or CurTime()
        if (CurTime() - startedAt) >= 1 then
            TTTBots.Plans.CurrentPlanState = TTTBots.Plans.PLANSTATES.RUNNING
            local tState = TTTBots.Plans.GetTeamPlanState(TEAM_TRAITOR)
            tState.CurrentPlanState = TTTBots.Plans.PLANSTATES.RUNNING
        end
    end

    -- Per-team plan selection for non-traitor coordinator teams
    local activeTeams = TTTBots.Plans.GetActiveCoordinatorTeams()
    for _, team in ipairs(activeTeams) do
        if team == TEAM_TRAITOR then continue end -- already handled above
        local state = TTTBots.Plans.GetTeamPlanState(team)

        if not state.SelectedPlan then
            TTTBots.Plans.InvalidateAnalysisCache()
            local preset = TTTBots.Plans.GetFirstBestPreset(team)
            if preset then
                state.SelectedPlan = TTTBots.Lib.DeepCopy(preset)
                state.CurrentPlanState = TTTBots.Plans.PLANSTATES.START
                state.PlanStartTime = CurTime()
                state.LastCoordinatorCount = 0
            end
        end

        -- Transition out of START
        if state.CurrentPlanState == TTTBots.Plans.PLANSTATES.START then
            local startedAt = state.PlanStartTime or CurTime()
            if (CurTime() - startedAt) >= 1 then
                state.CurrentPlanState = TTTBots.Plans.PLANSTATES.RUNNING
            end
        end
    end
end
