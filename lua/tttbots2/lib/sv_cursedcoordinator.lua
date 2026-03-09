--- sv_cursedcoordinator.lua
--- Detects mid-round Cursed role transitions via TTT2UpdateSubrole, publishes
--- events, triggers chatter/evidence for witnesses, handles respawn awareness,
--- urgency scaling, damage immunity awareness, and swap observation.
--- Modeled after sv_infectedcoordinator.lua.
--- This file is auto-included by IncludeDirectory("tttbots2/lib").

if not (TTT2 and ROLE_CURSED) then return end

local lib = TTTBots.Lib

TTTBots.CursedCoordinator = TTTBots.CursedCoordinator or {}
local Coord = TTTBots.CursedCoordinator

--- Track known Cursed players so we can detect swap events
Coord._knownCursed = Coord._knownCursed or {}

--- Track the previous role of bots that just became Cursed (for "got cursed" reaction)
Coord._previousRoles = Coord._previousRoles or {}

-- ---------------------------------------------------------------------------
-- Role-change detection via TTT2UpdateSubrole
-- ---------------------------------------------------------------------------

hook.Add("TTT2UpdateSubrole", "TTTBots.CursedCoordinator.DetectCurseChange", function(ply, oldSubrole, newSubrole)
    if not ROLE_CURSED then return end

    -- ── Player BECAME Cursed ──────────────────────────────────────────────
    if newSubrole == ROLE_CURSED and oldSubrole ~= ROLE_CURSED then
        timer.Simple(0.1, function()
            if not IsValid(ply) then return end

            -- Track this player as cursed
            Coord._knownCursed[ply] = true
            Coord._previousRoles[ply] = oldSubrole

            -- If this is a bot, fire the "got cursed" reaction
            if ply:IsBot() and ply.BotChatter then
                local chatter = ply:BotChatter()
                if chatter and chatter.On then
                    chatter:On("CursedRoleReceived", {})
                end

                -- Reset suspicion/evidence for the bot (stale data from old role)
                local morality = ply.components and ply.components.morality
                if morality and morality.ResetSuspicions then
                    morality:ResetSuspicions()
                elseif morality then
                    -- Fallback: clear the suspicion table manually
                    if morality.suspicions then
                        table.Empty(morality.suspicions)
                    end
                end

                -- Clear stale evidence
                local evidence = ply.components and ply.components.evidence
                if evidence and evidence.ClearAllEvidence then
                    evidence:ClearAllEvidence()
                elseif evidence and evidence.evidenceEntries then
                    table.Empty(evidence.evidenceEntries)
                end
            end

            -- Notify witnessing bots
            if TTTBots.Bots then
                for _, bot in ipairs(TTTBots.Bots) do
                    if not IsValid(bot) then continue end
                    if not lib.IsPlayerAlive(bot) then continue end
                    if bot == ply then continue end

                    if bot:Visible(ply) then
                        -- Fire "CursedSpotted" chatter for the witness
                        local _c = bot:BotChatter()
                        if _c and _c.On then
                            _c:On("CursedSpotted", { player = ply:Nick() })
                        end

                        -- Add evidence that this player is Cursed
                        local evidence = bot.components and bot.components.evidence
                        if evidence and evidence.AddEvidence then
                            evidence:AddEvidence({
                                type = "CURSE_WITNESSED",
                                subject = ply,
                                detail = "was just cursed and became the new Cursed player",
                            })
                        end
                    end
                end
            end

            -- Publish event on the event bus if available
            if TTTBots.Events and TTTBots.Events.Publish then
                TTTBots.Events.Publish("PLAYER_CURSED", {
                    victim = ply,
                    oldRole = oldSubrole,
                })
            end
        end)
    end

    -- ── Player LEFT Cursed (swapped out) ──────────────────────────────────
    if oldSubrole == ROLE_CURSED and newSubrole ~= ROLE_CURSED then
        timer.Simple(0.1, function()
            if not IsValid(ply) then return end

            Coord._knownCursed[ply] = nil

            -- If this is a bot, re-enable suspicion system for the new role
            if ply:IsBot() then
                -- The behavior tree automatically switches via GetTreeFor() live lookup
                -- But we should fire a chatter event about the successful swap
                local chatter = ply:BotChatter and ply:BotChatter()
                if chatter and chatter.On then
                    -- This bot just escaped the curse
                    -- CursedSwapSuccess is already fired by the SwapRole behavior,
                    -- so we don't double-fire here
                end
            end

            -- Notify witnessing bots about the swap
            if TTTBots.Bots then
                for _, bot in ipairs(TTTBots.Bots) do
                    if not IsValid(bot) then continue end
                    if not lib.IsPlayerAlive(bot) then continue end
                    if bot == ply then continue end

                    if bot:Visible(ply) then
                        local _c = bot:BotChatter()
                        if _c and _c.On then
                            -- Find who the NEW cursed is (the player who just got newSubrole == ROLE_CURSED)
                            local newCursed = nil
                            for p, _ in pairs(Coord._knownCursed) do
                                if IsValid(p) and p ~= ply and lib.IsPlayerAlive(p) then
                                    newCursed = p
                                    break
                                end
                            end

                            if newCursed then
                                _c:On("CursedSwappedWithSomeone", {
                                    player1 = ply:Nick(),
                                    player2 = newCursed:Nick(),
                                })
                            end
                        end

                        -- Update evidence
                        local evidence = bot.components and bot.components.evidence
                        if evidence and evidence.AddEvidence then
                            evidence:AddEvidence({
                                type = "CURSE_SWAP_WITNESSED",
                                subject = ply,
                                detail = "just swapped roles with someone (was Cursed, now has a new role)",
                            })
                        end
                    end
                end
            end

            -- Publish event
            if TTTBots.Events and TTTBots.Events.Publish then
                TTTBots.Events.Publish("PLAYER_UNCURSED", {
                    player = ply,
                    newRole = newSubrole,
                })
            end
        end)
    end
end)

-- ---------------------------------------------------------------------------
-- Respawn awareness (GAP-2)
-- ---------------------------------------------------------------------------

hook.Add("PlayerSpawn", "TTTBots.CursedCoordinator.RespawnAwareness", function(ply)
    if not IsValid(ply) then return end
    if not ply:IsBot() then return end
    if not ROLE_CURSED then return end

    -- Slight delay to ensure role data is set
    timer.Simple(0.5, function()
        if not IsValid(ply) then return end
        if ply:GetSubRole() ~= ROLE_CURSED then return end

        -- Fire respawn chatter
        local chatter = ply:BotChatter and ply:BotChatter()
        if chatter and chatter.On then
            chatter:On("CursedRespawned", {})
        end

        -- Clear any stale behavior state so the bot re-evaluates targets
        if ply.lastBehavior then
            ply.lastBehavior = nil
        end
    end)
end)

-- ---------------------------------------------------------------------------
-- Urgency scaling (GAP-4): Late-round desperation chatter
-- ---------------------------------------------------------------------------

timer.Create("TTTBots.CursedCoordinator.UrgencyTick", 5, 0, function()
    if not TTTBots.Match.IsRoundActive() then return end
    if not TTTBots.Bots then return end

    local alivePlayers = lib.GetAlivePlayers()
    local aliveCount = #alivePlayers
    local totalPlayers = player.GetCount()

    -- Trigger urgency when fewer than 40% of players remain
    local urgencyThreshold = math.ceil(totalPlayers * 0.4)
    if aliveCount > urgencyThreshold then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not IsValid(bot) then continue end
        if not lib.IsPlayerAlive(bot) then continue end
        if bot:GetSubRole() ~= ROLE_CURSED then continue end

        -- The bot is Cursed and time is running out
        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            -- Only fire once every ~30 seconds per bot
            bot._cursedLastUrgency = bot._cursedLastUrgency or 0
            if CurTime() - bot._cursedLastUrgency > 30 then
                chatter:On("CursedDesperateLate", {})
                bot._cursedLastUrgency = CurTime()
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Damage immunity awareness (GAP-8): Detect when bots waste ammo on Cursed
-- ---------------------------------------------------------------------------

hook.Add("EntityTakeDamage", "TTTBots.CursedCoordinator.DamageImmunity", function(target, dmgInfo)
    if not IsValid(target) or not target:IsPlayer() then return end
    if target:GetSubRole() ~= ROLE_CURSED then return end

    -- Check if damage immunity is active
    local damageImmune = GetConVar("ttt2_cursed_damage_immunity")
        and GetConVar("ttt2_cursed_damage_immunity"):GetBool() or false
    if not damageImmune then return end

    local attacker = dmgInfo:GetAttacker()
    if not IsValid(attacker) or not attacker:IsPlayer() then return end

    -- If the attacker is a bot, fire "can't damage" chatter
    if attacker:IsBot() and attacker.BotChatter then
        -- Rate-limit this chatter
        attacker._cursedCantDamageTime = attacker._cursedCantDamageTime or 0
        if CurTime() - attacker._cursedCantDamageTime > 10 then
            local chatter = attacker:BotChatter()
            if chatter and chatter.On then
                chatter:On("CursedCantDamage", { player = target:Nick() })
            end
            attacker._cursedCantDamageTime = CurTime()

            -- Clear the attack target so the bot stops wasting ammo
            if attacker.attackTarget == target then
                attacker.attackTarget = nil
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Cursed approaching awareness (GAP-6): Warn bots when Cursed is near
-- ---------------------------------------------------------------------------

timer.Create("TTTBots.CursedCoordinator.ApproachWarning", 2, 0, function()
    if not TTTBots.Match.IsRoundActive() then return end
    if not TTTBots.Bots then return end

    -- Find all living cursed players
    local cursedPlayers = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and lib.IsPlayerAlive(ply) and ply:GetSubRole() == ROLE_CURSED then
            table.insert(cursedPlayers, ply)
        end
    end

    if #cursedPlayers == 0 then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not IsValid(bot) then continue end
        if not lib.IsPlayerAlive(bot) then continue end
        if bot:GetSubRole() == ROLE_CURSED then continue end -- Cursed don't warn about themselves

        for _, cursed in ipairs(cursedPlayers) do
            local dist = bot:GetPos():Distance(cursed:GetPos())

            -- Warn when Cursed is approaching within 300 units
            if dist < 300 and bot:Visible(cursed) then
                -- Rate-limit per bot per cursed player
                bot._cursedApproachWarning = bot._cursedApproachWarning or {}
                local lastWarn = bot._cursedApproachWarning[cursed] or 0
                if CurTime() - lastWarn > 15 then
                    local chatter = bot:BotChatter()
                    if chatter and chatter.On then
                        chatter:On("CursedApproachingMe", { player = cursed:Nick() })
                    end
                    bot._cursedApproachWarning[cursed] = CurTime()
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Chatter command extension: "curse {player}" targets for Cursed bots
-- ---------------------------------------------------------------------------

-- The existing "curse" command in sv_chatter_commands.lua routes to CreateCursed.HandleRequest
-- which is for traitors using the Cursed Deagle. We add a secondary handler:
-- When a human tells a Cursed bot "curse {player}", suggest that target for SwapRole.
hook.Add("TTTBots.ChatterCommand.Curse", "TTTBots.CursedCoordinator.CurseCommand", function(bot, target)
    if not IsValid(bot) or not IsValid(target) then return end
    if bot:GetSubRole() ~= ROLE_CURSED then return end

    -- Set the target in the SwapRole behavior state
    local state = TTTBots.Behaviors.GetState(bot, "SwapRole")
    state.target = target
end)

-- ---------------------------------------------------------------------------
-- Round cleanup
-- ---------------------------------------------------------------------------

hook.Add("TTTEndRound", "TTTBots.CursedCoordinator.Cleanup", function()
    Coord._knownCursed = {}
    Coord._previousRoles = {}

    -- Clean up per-bot state
    if TTTBots.Bots then
        for _, bot in ipairs(TTTBots.Bots) do
            if IsValid(bot) then
                bot._cursedLastUrgency = nil
                bot._cursedCantDamageTime = nil
                bot._cursedApproachWarning = nil
            end
        end
    end
end)
