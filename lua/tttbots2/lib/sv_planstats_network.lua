---------------------------------------------------------------------------
-- Plan Stats Networking
--
-- Server-side module that responds to client requests for plan learning
-- statistics and current plan state.  Sends compressed JSON to the
-- requesting client so the Plan Stats UI can display it.
--
-- Note: Network strings are registered in sh_tttbots2.lua.
---------------------------------------------------------------------------

--- Build a snapshot of all plan stats for the client.
---@return table planStatsPayload
local function BuildPlanStatsPayload()
    local payload = {
        --- Current plan info
        CurrentPlan = {
            Name = "None",
            Description = "No plan selected",
            State = TTTBots.Plans.CurrentPlanState or "Waiting",
            StartTime = TTTBots.Plans.PlanStartTime or 0,
            RoundTime = TTTBots.Match.Time() or 0,
        },
        --- Learning history
        History = {
            TotalRounds = 0,
            Plans = {},
        },
        --- Snapshot of the analysis data (if available)
        Analysis = {
            Loadout = {},
            EnemyDist = {},
        },
        --- List of all known presets and their conditions
        Presets = {},
        --- Bot job assignments
        BotJobs = {},
    }

    -- Current plan details
    local plan = TTTBots.Plans.SelectedPlan
    if plan then
        payload.CurrentPlan.Name = plan.Name or "Unknown"
        payload.CurrentPlan.Description = plan.Description or ""
        payload.CurrentPlan.State = TTTBots.Plans.CurrentPlanState or "Running"
        payload.CurrentPlan.StartTime = TTTBots.Plans.PlanStartTime or 0
        payload.CurrentPlan.JobCount = plan.Jobs and #plan.Jobs or 0

        -- Job details (action, target type, assigned count)
        if plan.Jobs then
            payload.CurrentPlan.Jobs = {}
            for i, job in ipairs(plan.Jobs) do
                table.insert(payload.CurrentPlan.Jobs, {
                    Action = job.Action or "?",
                    Target = job.Target or "?",
                    Chance = job.Chance or 0,
                    MaxAssigned = job.MaxAssigned or 0,
                    NumAssigned = job.NumAssigned or 0,
                    Repeat = job.Repeat or false,
                    Skip = job.Skip or false,
                })
            end
        end
    end

    -- Plan learning history
    if TTTBots.PlanLearning then
        TTTBots.PlanLearning.EnsureLoaded()
        local history = TTTBots.PlanLearning.History
        if history then
            payload.History.TotalRounds = history.TotalRounds or 0
            payload.History.LastDecayTime = history.LastDecayTime or 0

            for name, entry in pairs(history.Plans or {}) do
                local total = entry.Wins + entry.Losses
                local winRate = total > 0 and (entry.Wins / total) or 0
                local contexts = {}

                for ctxKey, ctx in pairs(entry.Contexts or {}) do
                    local ctxTotal = ctx.Wins + ctx.Losses
                    local ctxWinRate = ctxTotal > 0 and (ctx.Wins / ctxTotal) or 0
                    table.insert(contexts, {
                        Key = ctxKey,
                        Wins = math.Round(ctx.Wins, 1),
                        Losses = math.Round(ctx.Losses, 1),
                        WinRate = math.Round(ctxWinRate * 100, 1),
                    })
                end

                -- Learning modifier for current context
                local learningMod = TTTBots.PlanLearning.GetLearningModifier(name) or 0

                payload.History.Plans[name] = {
                    Wins = math.Round(entry.Wins, 1),
                    Losses = math.Round(entry.Losses, 1),
                    Total = math.Round(total, 1),
                    WinRate = math.Round(winRate * 100, 1),
                    LearningModifier = math.Round(learningMod, 1),
                    Contexts = contexts,
                }
            end
        end
    end

    -- Analysis snapshot
    local loadout, enemyDist = TTTBots.Plans.GetAnalysisData()
    if loadout then
        payload.Analysis.Loadout = {
            TotalCoordinators = loadout.TotalCoordinators or 0,
            TotalCreditsRemaining = loadout.TotalCreditsRemaining or 0,
            CoordinatorsWithCredits = loadout.CoordinatorsWithCredits or 0,
            TeamFirepowerScore = math.Round(loadout.TeamFirepowerScore or 0, 1),
            TeamStealthScore = math.Round(loadout.TeamStealthScore or 0, 1),
            TeamUtilityScore = math.Round(loadout.TeamUtilityScore or 0, 1),
            HasHeavyFirepower = loadout.HasHeavyFirepower or false,
            HasStealthWeapons = loadout.HasStealthWeapons or false,
            HasSmartWeapons = loadout.HasSmartWeapons or false,
            HasExplosives = loadout.HasExplosives or false,
            HasAreaDenial = loadout.HasAreaDenial or false,
            HasRevivalWeapons = loadout.HasRevivalWeapons or false,
            HasConversionWeapons = loadout.HasConversionWeapons or false,
            HasGrenades = loadout.HasGrenades or false,
            HasDisruption = loadout.HasDisruption or false,
        }
    end
    if enemyDist then
        payload.Analysis.EnemyDist = {
            TotalEnemies = enemyDist.TotalEnemies or 0,
            IsolatedEnemies = enemyDist.IsolatedEnemies or 0,
            ClusteredEnemies = enemyDist.ClusteredEnemies or 0,
            AvgEnemyGroupSize = math.Round(enemyDist.AvgEnemyGroupSize or 1, 2),
            HasPoliceCluster = enemyDist.HasPoliceCluster or false,
        }
    end

    -- Known presets summary
    local PRESETS = TTTBots.Plans.PRESETS
    if PRESETS then
        for name, preset in pairs(PRESETS) do
            if name == "Default" then continue end
            local presetInfo = {
                Name = preset.Name or name,
                Description = preset.Description or "",
                Chance = preset.Conditions and preset.Conditions.Chance or 0,
            }
            -- Calculate synergy score if analysis data is available
            if loadout and enemyDist and preset.SynergyScore then
                local ok, synergy = pcall(preset.SynergyScore, loadout, enemyDist)
                if ok then
                    presetInfo.SynergyScore = math.Round(synergy, 1)
                end
            end
            -- Check if conditions are currently valid (without chance roll)
            if preset.Conditions then
                local condCopy = {}
                for k, v in pairs(preset.Conditions) do condCopy[k] = v end
                condCopy.Chance = 100
                local valid = TTTBots.Plans.AreConditionsValid(condCopy)
                presetInfo.IsValid = valid
            end

            payload.Presets[name] = presetInfo
        end
    end

    -- Bot job assignments
    for bot, statusTbl in pairs(TTTBots.Plans.BotStatuses or {}) do
        if not IsValid(bot) then continue end
        table.insert(payload.BotJobs, {
            Name = bot:Nick(),
            Status = statusTbl.status or "Unknown",
        })
    end

    return payload
end

--- Handle client request for plan stats
net.Receive("TTTBots_RequestPlanStats", function(len, ply)
    if not IsValid(ply) then return end
    -- Allow any admin to view plan stats (superadmin or admin)
    if not ply:IsAdmin() then return end

    local payload = BuildPlanStatsPayload()
    local json = util.TableToJSON(payload)
    local compressed = util.Compress(json)

    net.Start("TTTBots_PlanStatsData")
    net.WriteUInt(#compressed, 32)
    net.WriteData(compressed, #compressed)
    net.Send(ply)
end)

print("[TTT Bots 2] Plan stats networking module loaded.")
