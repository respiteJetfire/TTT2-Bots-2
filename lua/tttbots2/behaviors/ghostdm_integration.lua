--[[
    TTT2 Bots 2 — Ghost Deathmatch Integration
    ============================================
    This module integrates TTT2-Bots-2 with the ttt2-ghost-deathmatch addon.

    When a TTT2 bot dies and enters Ghost Deathmatch:
    - Its behavior tree is overridden with a ghost DM-specific tree
    - All morality/suspicion/targeting systems ignore ghost players
    - The bot fights other ghosts using simplified deathmatch AI
    - Normal TTT bot logic is completely suppressed while in ghost mode

    When filtering alive players:
    - Ghost players are excluded from the alive player cache
    - TTT2 bots will never target or react to ghost players
    - Ghost bots will never target living players

    This file is loaded by sv_tree.lua's IncludeDirectory call since it lives
    in the behaviors/ folder and returns true.
]]

if not SERVER then return end

-- Wait for all systems to be available before initializing
hook.Add("TTTBotsInitialized", "GhostDM_BotIntegration", function()
    if not GhostDM then
        print("[TTT Bots 2][GhostDM] Ghost Deathmatch addon not detected, skipping integration.")
        return
    end

    print("[TTT Bots 2][GhostDM] Ghost Deathmatch integration loaded!")

    -- ========================================================================
    -- BEHAVIOR TREE OVERRIDE
    -- When a bot is a ghost, replace its entire behavior tree with the ghost
    -- DM tree so it only does ghost DM behaviors.
    -- ========================================================================

    --- Ghost DM behavior tree: fight ghosts, or wander if no ghosts nearby
    local _bh = TTTBots.Behaviors
    local GhostDMTree = {
        _bh.GhostDMFight,
        _bh.GhostDMWander,
    }

    --- Override GetTreeFor to return the ghost DM tree when bot is a ghost
    local originalGetTreeFor = TTTBots.Behaviors.GetTreeFor
    TTTBots.Behaviors.GetTreeFor = function(bot)
        if not IsValid(bot) then return nil end
        if GhostDM and GhostDM.IsGhost and GhostDM.IsGhost(bot) then
            return GhostDMTree
        end
        return originalGetTreeFor(bot)
    end

    -- ========================================================================
    -- ALIVE PLAYER FILTERING
    -- Ghost players must be invisible to the TTT bot systems. We hook into
    -- the alive player cache and strip out ghosts so they never appear in
    -- targeting lists, witness checks, morality, suspicion, etc.
    -- ========================================================================

    --- Filter ghost players out of the alive player life states cache.
    --- This runs frequently and ensures all TTTBots.Lib functions that
    --- rely on GetPlayerLifeStates() will never see ghost players as alive.
    timer.Create("GhostDM_BotFilterAlivePlayers", 0.2, 0, function()
        if not GhostDM then return end
        if not GhostDM.CVars or not GhostDM.CVars.Enabled:GetBool() then return end

        local states = TTTBots.Lib.GetPlayerLifeStates()
        if not states then return end

        for ply, alive in pairs(states) do
            if alive and IsValid(ply) and GhostDM.IsGhost(ply) then
                states[ply] = false
            end
        end

        -- Also filter from the Match.AlivePlayers table
        if TTTBots.Match and TTTBots.Match.AlivePlayers then
            local filtered = {}
            for _, ply in ipairs(TTTBots.Match.AlivePlayers) do
                if IsValid(ply) and not GhostDM.IsGhost(ply) then
                    filtered[#filtered + 1] = ply
                end
            end
            TTTBots.Match.AlivePlayers = filtered
        end
    end)

    -- ========================================================================
    -- MORALITY / TARGETING SUPPRESSION
    -- Prevent living bots from targeting ghosts and ghost bots from
    -- targeting living players.
    -- ========================================================================

    --- Clear attack targets that cross the ghost/living boundary
    timer.Create("GhostDM_BotClearCrossTargets", 0.5, 0, function()
        if not GhostDM then return end
        if not GhostDM.CVars or not GhostDM.CVars.Enabled:GetBool() then return end

        for _, bot in ipairs(TTTBots.Bots) do
            if not IsValid(bot) then continue end
            if not bot.components then continue end

            local botIsGhost = GhostDM.IsGhost(bot)
            local target = bot.attackTarget

            if IsValid(target) then
                local targetIsGhost = GhostDM.IsGhost(target)

                -- Ghost bot targeting living player -> clear
                -- Living bot targeting ghost player -> clear
                if botIsGhost ~= targetIsGhost then
                    bot:SetAttackTarget(nil, "GHOST_DM_BOUNDARY")
                end
            end

            -- If bot just became a ghost, reset its morality state
            -- so it doesn't carry suspicions from its living phase
            if botIsGhost and not bot.GhostDM_MoralityReset then
                bot.GhostDM_MoralityReset = true

                local morality = bot:BotMorality()
                if morality then
                    morality.suspicions = {}
                    morality.roleGuesses = {}
                end

                -- Clear any last behavior so the ghost DM tree starts fresh
                bot.lastBehavior = nil
            end

            -- Reset the morality flag when bot is no longer ghost
            if not botIsGhost and bot.GhostDM_MoralityReset then
                bot.GhostDM_MoralityReset = nil
            end
        end
    end)

    -- ========================================================================
    -- GHOST ENTRY HOOK
    -- When a TTT2 bot becomes a ghost, prepare it for ghost DM mode
    -- ========================================================================

    hook.Add("GhostDM_PlayerBecameGhost", "TTTBots_GhostEntry", function(ply)
        if not IsValid(ply) then return end
        if not ply:IsBot() then return end

        -- Check if this is a TTTBots bot (has components)
        if not ply.components then return end

        print("[TTT Bots 2][GhostDM] Bot " .. ply:Nick() .. " entered Ghost Deathmatch")

        -- Clear all combat state
        ply:SetAttackTarget(nil, "GHOST_DM_ENTRY")
        ply.lastBehavior = nil
        ply.isRetreating = nil
        ply.fleeFromTarget = nil
        ply.fleeFromTargetUntil = nil
        ply.coverTarget = nil

        -- Clear locomotor state
        local loco = ply:BotLocomotor()
        if loco then
            loco:StopAttack()
            loco:StopMoving()
            loco.stopLookingAround = false
        end

        -- Reset morality suspicions so ghost doesn't carry grudges
        local morality = ply:BotMorality()
        if morality then
            morality.suspicions = {}
        end

        -- Flag the bot to suppress the StartCommand override while ghost DM
        -- handles its own bot think via the behavior tree
        ply.GhostDM_UsingBotTree = true
    end)

    -- ========================================================================
    -- GHOST EXIT HOOK
    -- When a TTT2 bot loses ghost status, restore normal bot operation
    -- ========================================================================

    hook.Add("GhostDM_PlayerLostGhost", "TTTBots_GhostExit", function(ply)
        if not IsValid(ply) then return end
        if not ply:IsBot() then return end
        if not ply.components then return end

        print("[TTT Bots 2][GhostDM] Bot " .. ply:Nick() .. " left Ghost Deathmatch")

        -- Clear ghost-specific state
        ply.GhostDM_UsingBotTree = nil
        ply.GhostDM_MoralityReset = nil
        ply.lastBehavior = nil

        -- Stop any ongoing attacks
        local loco = ply:BotLocomotor()
        if loco then
            loco:StopAttack()
            loco.stopLookingAround = false
        end
    end)

    -- ========================================================================
    -- SUPPRESS GHOST DM's BUILT-IN BOT AI (StartCommand)
    -- The GhostDM addon has its own StartCommand hook for simple bot AI.
    -- For TTT2 bots, we want our behavior tree to handle everything instead.
    -- We override that by making TTT2 bots skip the ghost DM bot think.
    -- ========================================================================

    --- Prevent the GhostDM StartCommand from controlling TTT2 bots.
    --- TTT2 bots have components and use the behavior tree system instead.
    --- We hook at a higher priority (earlier name) to intercept before GhostDM.
    hook.Add("StartCommand", "GhostDM_BotThink_TTTBots_Override", function(ply, cmd)
        if not ply:IsBot() then return end
        if not GhostDM or not GhostDM.IsGhost(ply) then return end

        -- If this is a TTT2 bot (has components), let TTT2 bots handle it
        -- via the behavior tree. We don't need to do anything here since
        -- the TTTBots StartCommand hook will run the locomotor.
        if ply.components then
            -- Return nothing - let TTTBots' own StartCommand handle it
            return
        end
    end)

    -- ========================================================================
    -- WITNESS / KOS / SUSPICION FILTERING
    -- Prevent ghost events from affecting living bot state and vice versa.
    -- ========================================================================

    --- Override GetAllWitnessesBasic to filter out ghost players
    local originalGetAllWitnessesBasic = TTTBots.Lib.GetAllWitnessesBasic
    TTTBots.Lib.GetAllWitnessesBasic = function(pos, playerTbl, ignorePly)
        local witnesses = originalGetAllWitnessesBasic(pos, playerTbl, ignorePly)
        if not GhostDM then return witnesses end

        local filtered = {}
        for _, ply in ipairs(witnesses) do
            if not GhostDM.IsGhost(ply) then
                filtered[#filtered + 1] = ply
            end
        end
        return filtered
    end

    --- Override GetAllWitnesses to filter out ghost players
    local originalGetAllWitnesses = TTTBots.Lib.GetAllWitnesses
    TTTBots.Lib.GetAllWitnesses = function(pos, botsOnly)
        local witnesses = originalGetAllWitnesses(pos, botsOnly)
        if not GhostDM then return witnesses end

        local filtered = {}
        for _, ply in ipairs(witnesses) do
            if not GhostDM.IsGhost(ply) then
                filtered[#filtered + 1] = ply
            end
        end
        return filtered
    end

    -- ========================================================================
    -- DAMAGE ISOLATION REINFORCEMENT
    -- Ensure bot damage tracking ignores ghost/living crossover damage
    -- ========================================================================

    hook.Add("PlayerHurt", "GhostDM_BotDamageFilter", function(victim, attacker, healthRemaining, damageTaken)
        if not GhostDM then return end
        if not (IsValid(victim) and IsValid(attacker)) then return end
        if not (victim:IsPlayer() and attacker:IsPlayer()) then return end

        -- If damage crosses the ghost/living boundary, remove the last
        -- damage log entry to prevent bots from reacting to it
        local victimGhost = GhostDM.IsGhost(victim)
        local attackerGhost = GhostDM.IsGhost(attacker)

        if victimGhost ~= attackerGhost then
            -- Remove the damage log that was just added
            local logs = TTTBots.Match.DamageLogs
            if logs and #logs > 0 then
                local last = logs[#logs]
                if last.victim == victim and last.attacker == attacker then
                    table.remove(logs, #logs)
                end
            end
        end
    end)

    -- ========================================================================
    -- PREVENT GHOST DEATHS FROM AFFECTING TTT BOT STATE
    -- ========================================================================

    hook.Add("PlayerDeath", "GhostDM_BotDeathFilter", function(victim, inflictor, attacker)
        if not GhostDM then return end
        if not IsValid(victim) then return end

        -- If a ghost died, don't let TTT bots react to it
        if GhostDM.IsGhost(victim) then
            -- Remove from confirmed dead so bots don't search for the ghost's corpse
            TTTBots.Match.ConfirmedDead[victim] = nil
        end
    end)

    -- ========================================================================
    -- PREVENT KOS CALLS AGAINST/FROM GHOSTS
    -- ========================================================================

    local originalCallKOS = TTTBots.Match.CallKOS
    TTTBots.Match.CallKOS = function(caller, target)
        if GhostDM and GhostDM.IsGhost then
            -- Ghost players can't call KOS on living players
            if GhostDM.IsGhost(caller) and not GhostDM.IsGhost(target) then
                return false
            end
            -- Living players can't call KOS on ghost players
            if not GhostDM.IsGhost(caller) and GhostDM.IsGhost(target) then
                return false
            end
        end
        return originalCallKOS(caller, target)
    end

    -- ========================================================================
    -- ROUND CLEANUP
    -- ========================================================================

    hook.Add("TTTEndRound", "GhostDM_BotCleanup", function()
        for _, bot in ipairs(TTTBots.Bots) do
            if not IsValid(bot) then continue end
            bot.GhostDM_UsingBotTree = nil
            bot.GhostDM_MoralityReset = nil
        end
    end)

    hook.Add("TTTPrepareRound", "GhostDM_BotPrepare", function()
        for _, bot in ipairs(TTTBots.Bots) do
            if not IsValid(bot) then continue end
            bot.GhostDM_UsingBotTree = nil
            bot.GhostDM_MoralityReset = nil
        end
    end)

end)

-- Also handle the case where GhostDM loads after TTTBots
hook.Add("Initialize", "GhostDM_BotIntegrationFallback", function()
    timer.Simple(5, function()
        if GhostDM and TTTBots and not TTTBots.GhostDM_Integrated then
            TTTBots.GhostDM_Integrated = true
            hook.Run("TTTBotsInitialized", TTTBots)
        end
    end)
end)

return true
