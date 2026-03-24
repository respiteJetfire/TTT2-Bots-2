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
end

TTTBots.Plans.Cleanup() -- Call when this script is first executed

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
}
function TTTBots.Plans.AreConditionsValid(conditions)
    -- Coordinators: any role with GetCanCoordinate (traitors, necromancer, etc.)
    local aliveCoordinators = TTTBots.Lib.FilterTable(TTTBots.Match.AlivePlayers,
        function(ply) return TTTBots.Roles.GetRoleFor(ply):GetCanCoordinate() end)
    -- Actual traitor-team players only (for MinTraitors/MaxTraitors conditions)
    local aliveTraitors = TTTBots.Lib.FilterTable(TTTBots.Match.AlivePlayers,
        function(ply)
            local team = ply.GetTeam and ply:GetTeam()
            return team == TEAM_TRAITOR
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
    -- Tier 2: Coordinated group attacks
    "MediumPlayerCount_DetectiveHunt",
    "AveragePlayerCount_CoordinatedBlitz",
    "MediumPlayerCount_HitSquad",
    "LowPlayerCount_WolfPack",
    -- Tier 3: Standard plans (broadest conditions, catch-all)
    "LowPlayerCount_Standard",
    "MediumPlayerCount_Standard",
    "AveragePlayerCount_Standard",
}

--- Returns the first best preset in TTTBots.Plans.PRESETS, according to the conditions.
--- Uses the deterministic priority order defined in PresetPriority, then falls back
--- to any remaining presets not in the list, and finally the Default preset.
function TTTBots.Plans.GetFirstBestPreset()
    local PRESETS = TTTBots.Plans.PRESETS
    local Default = PRESETS.Default

    -- Walk the explicit priority list first (deterministic order)
    for _, name in ipairs(TTTBots.Plans.PresetPriority) do
        local preset = PRESETS[name]
        if preset then
            local valid, reason = TTTBots.Plans.AreConditionsValid(preset.Conditions)
            if valid then return preset end
        end
    end

    -- Fallback: iterate any presets NOT in the priority list (custom / add-on presets)
    local prioritySet = {}
    for _, name in ipairs(TTTBots.Plans.PresetPriority) do prioritySet[name] = true end
    for name, preset in pairs(PRESETS) do
        if name ~= "Default" and not prioritySet[name] then
            local valid, reason = TTTBots.Plans.AreConditionsValid(preset.Conditions)
            if valid then return preset end
        end
    end

    return Default
end

TTTBots.Plans.LastReEvalTime = 0
TTTBots.Plans.LastCoordinatorCount = 0
TTTBots.Plans.ReEvalCooldown = 10 -- seconds between re-evaluation checks

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

    -- A coordinator died — check if a revival/recovery plan is now available
    -- that wasn't selected initially.
    local currentPlan = TTTBots.Plans.SelectedPlan
    if not currentPlan then return false end

    -- Only re-evaluate if the current plan is NOT already a revival/recovery plan.
    local revivalPlanNames = {
        CorpseHarvest = true,
        LowPlayer_RevivalRecovery = true,
        MediumPlayer_RevivalRecovery = true,
        LargePlayer_RevivalRecovery = true,
        ConversionRecovery = true,
    }
    if revivalPlanNames[currentPlan.Name] then return false end

    -- See if a revival plan would now be valid
    local bestPreset = TTTBots.Plans.GetFirstBestPreset()
    if bestPreset and revivalPlanNames[bestPreset.Name] then
        return true
    end

    return false
end

function TTTBots.Plans.Tick()
    if not TTTBots.Match.RoundActive then
        TTTBots.Plans.Cleanup()
        return
    end
    if not TTTBots.Plans.SelectedPlan then
        TTTBots.Plans.SelectedPlan = TTTBots.Lib.DeepCopy(TTTBots.Plans.GetFirstBestPreset())
        TTTBots.Plans.CurrentPlanState = TTTBots.Plans.PLANSTATES.START
        TTTBots.Plans.PlanStartTime = CurTime()
        TTTBots.Plans.LastCoordinatorCount = 0  -- reset for re-eval tracking
        return
    end

    -- Mid-round re-evaluation: if the team lost members and a revival plan
    -- is now available, swap to it so bots start reviving instead of fighting.
    if TTTBots.Plans.CurrentPlanState == TTTBots.Plans.PLANSTATES.RUNNING then
        if TTTBots.Plans.ShouldReEvaluatePlan() then
            -- Swap to the new best preset, clearing all bot job assignments.
            TTTBots.Plans.BotStatuses = {}
            TTTBots.Plans.SharedTargetCache = {}
            TTTBots.Plans.SelectedPlan = TTTBots.Lib.DeepCopy(TTTBots.Plans.GetFirstBestPreset())
            TTTBots.Plans.CurrentPlanState = TTTBots.Plans.PLANSTATES.START
            TTTBots.Plans.PlanStartTime = CurTime()
            return
        end
    end

    -- Transition out of START once the round has had a short warmup window.
    -- This prevents the plan FSM from appearing permanently stuck in "Starting".
    if TTTBots.Plans.CurrentPlanState == TTTBots.Plans.PLANSTATES.START then
        local startedAt = TTTBots.Plans.PlanStartTime or CurTime()
        if (CurTime() - startedAt) >= 1 then
            TTTBots.Plans.CurrentPlanState = TTTBots.Plans.PLANSTATES.RUNNING
        end
    end
end
