--- sv_clowncoordinator.lua
--- Detects mid-round Clown → Killer Clown transformation via TTT2UpdateSubrole,
--- publishes events, triggers chatter/evidence for witnesses, handles state reset,
--- transition grace period, and round cleanup.
--- Modeled after sv_amnesiaccoordinator.lua and sv_infectedcoordinator.lua.
--- This file is auto-included by IncludeDirectory("tttbots2/lib").

if not (TTT2 and ROLE_CLOWN) then return end

local lib = TTTBots.Lib

TTTBots.ClownCoordinator = TTTBots.ClownCoordinator or {}
local Coord = TTTBots.ClownCoordinator

--- Track known Clown players so we can detect transformation events.
Coord._knownClowns = Coord._knownClowns or {}

--- Track transformed Killer Clowns for post-transform logging.
Coord._transformLog = Coord._transformLog or {}

-- ---------------------------------------------------------------------------
-- Role-change detection via TTT2UpdateSubrole
-- ---------------------------------------------------------------------------

hook.Add("TTT2UpdateSubrole", "TTTBots.ClownCoordinator.DetectTransformation", function(ply, oldSubrole, newSubrole)
    if not ROLE_CLOWN then return end

    -- ── Player BECAME Clown (round start assignment) ─────────────────────
    if newSubrole == ROLE_CLOWN and oldSubrole ~= ROLE_CLOWN then
        timer.Simple(0.1, function()
            if not IsValid(ply) then return end

            Coord._knownClowns[ply] = true

            -- If this is a bot, fire initial role-received chatter
            if ply:IsBot() and ply.BotChatter then
                local chatter = ply:BotChatter()
                if chatter and chatter.On then
                    chatter:On("ClownRoundStart", {})
                end
            end
        end)
    end

    -- ── Player TRANSFORMED: Clown → Killer Clown ─────────────────────────
    if oldSubrole == ROLE_CLOWN and ROLE_KILLERCLOWN and newSubrole == ROLE_KILLERCLOWN then
        timer.Simple(0.1, function()
            if not IsValid(ply) then return end

            Coord._knownClowns[ply] = nil

            -- Log the transformation
            Coord._transformLog[ply] = {
                time = CurTime(),
            }

            if ply:IsBot() then
                -- ── Set transition grace period ───────────────────────────
                -- Prevents stale morality/hostility evaluation during the
                -- brief window between role change and cleanup completion.
                ply._clownTransitionGrace = CurTime() + 2

                -- ── Reset suspicion ───────────────────────────────────────
                local morality = ply.components and ply.components.morality
                if morality and morality.ResetSuspicions then
                    morality:ResetSuspicions()
                elseif morality then
                    if morality.suspicions then
                        table.Empty(morality.suspicions)
                    end
                end

                -- ── Clear stale evidence ──────────────────────────────────
                local evidence = ply.components and ply.components.evidence
                if evidence and evidence.ClearRoundEvidence then
                    evidence:ClearRoundEvidence()
                elseif evidence and evidence.evidenceEntries then
                    table.Empty(evidence.evidenceEntries)
                end

                -- ── Clear stale behavior state ────────────────────────────
                -- Force the behavior tree to re-evaluate from scratch
                ply.lastBehavior = nil
                ply.attackTarget = nil

                -- Clear any stale behavior states from the pre-transform tree
                if ply.behaviorState then
                    ply.behaviorState["Follow"] = nil
                    ply.behaviorState["GroupUp"] = nil
                    ply.behaviorState["Minge"] = nil
                    ply.behaviorState["Wander"] = nil
                    ply.behaviorState["Interact"] = nil
                    ply.behaviorState["Decrowd"] = nil
                end

                -- ── Fire transformation chatter on the bot ────────────────
                local chatter = ply.BotChatter and ply:BotChatter()
                if chatter and chatter.On then
                    chatter:On("ClownTransformed", {})
                end
            end

            -- ── Notify all other alive bots about the transformation ──────
            -- The transformation is PUBLIC: confetti + sound + HUD message.
            -- Every alive player sees it, so every bot should react.
            if TTTBots.Bots then
                for _, bot in ipairs(TTTBots.Bots) do
                    if not IsValid(bot) then continue end
                    if not lib.IsPlayerAlive(bot) then continue end
                    if bot == ply then continue end

                    -- Determine appropriate chatter based on bot's team
                    local _c = bot:BotChatter()
                    if _c and _c.On then
                        local botTeam = bot:GetTeam()
                        if botTeam == TEAM_TRAITOR then
                            -- Traitors previously saw the Clown as a Jester
                            _c:On("TraitorSeesClownTransform", {
                                player = ply:Nick(),
                            })
                        else
                            -- Everyone else reacts to the transformation
                            _c:On("ClownTransformWitnessed", {
                                player = ply:Nick(),
                            })
                        end
                    end

                    -- Add evidence that the Clown has transformed
                    local botEvidence = bot.components and bot.components.evidence
                    if botEvidence and botEvidence.AddEvidence then
                        botEvidence:AddEvidence({
                            type = "CLOWN_TRANSFORMED",
                            subject = ply,
                            detail = ply:Nick() .. " has transformed into a Killer Clown! Kill them!",
                        })
                    end
                end
            end

            -- ── Invalidate perception cache ───────────────────────────────
            -- The Clown was previously perceived as Jester by traitor bots.
            -- Now as Killer Clown, perception must update.
            if TTTBots.Perception and TTTBots.Perception.InvalidateCache then
                TTTBots.Perception.InvalidateCache()
            end

            -- ── Publish event on the event bus ────────────────────────────
            if TTTBots.Events and TTTBots.Events.Publish then
                TTTBots.Events.Publish("CLOWN_TRANSFORMED", {
                    player = ply,
                    oldRole = oldSubrole,
                    newRole = newSubrole,
                })
            end
        end)
    end
end)

-- ---------------------------------------------------------------------------
-- Urgency/survival chatter: periodic check for living Clowns
-- Fires survival chatter and near-transformation anticipation lines
-- ---------------------------------------------------------------------------

timer.Create("TTTBots.ClownCoordinator.SurvivalTick", 10, 0, function()
    if not TTTBots.Match.IsRoundActive() then return end
    if not TTTBots.Bots then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not IsValid(bot) then continue end
        if not lib.IsPlayerAlive(bot) then continue end
        if bot:GetSubRole() ~= ROLE_CLOWN then continue end

        local chatter = bot:BotChatter()
        if not (chatter and chatter.On) then continue end

        -- Rate limit: once every ~45 seconds per bot
        bot._clownLastSurvival = bot._clownLastSurvival or 0
        if CurTime() - bot._clownLastSurvival < 45 then continue end

        -- Count alive teams (excluding clowns and preventWin roles)
        -- to determine proximity to transformation
        local alivePlayers = lib.GetAlivePlayers()
        local teams = {}
        for _, ply in ipairs(alivePlayers) do
            if not IsValid(ply) then continue end
            local roleData = ply:GetSubRoleData()
            if roleData then
                local team = ply:GetTeam()
                -- Exclude clown team and preventWin roles
                if team ~= TEAM_CLOWN and not roleData.preventWin then
                    teams[team] = true
                end
            end
        end

        local teamCount = table.Count(teams)

        if teamCount <= 2 then
            -- Very close to transformation — 1 death away potentially
            chatter:On("ClownNearTransform", {})
            bot._clownLastSurvival = CurTime()
        elseif math.random(1, 3) == 1 then
            -- General survival chatter (periodic)
            chatter:On("ClownSurviving", {})
            bot._clownLastSurvival = CurTime()
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Post-transformation hunting chatter for Killer Clowns
-- ---------------------------------------------------------------------------

timer.Create("TTTBots.ClownCoordinator.HuntingTick", 15, 0, function()
    if not TTTBots.Match.IsRoundActive() then return end
    if not TTTBots.Bots then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not IsValid(bot) then continue end
        if not lib.IsPlayerAlive(bot) then continue end
        if not ROLE_KILLERCLOWN then continue end
        if bot:GetSubRole() ~= ROLE_KILLERCLOWN then continue end

        local chatter = bot:BotChatter()
        if not (chatter and chatter.On) then continue end

        -- Rate limit: once every ~30 seconds per bot
        bot._clownLastHunting = bot._clownLastHunting or 0
        if CurTime() - bot._clownLastHunting < 30 then continue end

        -- Count remaining enemies
        local alivePlayers = lib.GetAlivePlayers()
        local enemyCount = 0
        for _, ply in ipairs(alivePlayers) do
            if IsValid(ply) and ply ~= bot then
                enemyCount = enemyCount + 1
            end
        end

        if enemyCount == 1 then
            chatter:On("KillerClownLastTarget", {})
        elseif math.random(1, 2) == 1 then
            chatter:On("KillerClownHunting", {})
        end

        bot._clownLastHunting = CurTime()
    end
end)

-- ---------------------------------------------------------------------------
-- Round cleanup
-- ---------------------------------------------------------------------------

hook.Add("TTTEndRound", "TTTBots.ClownCoordinator.Cleanup", function()
    Coord._knownClowns = {}
    Coord._transformLog = {}

    -- Clean up per-bot state
    if TTTBots.Bots then
        for _, bot in ipairs(TTTBots.Bots) do
            if IsValid(bot) then
                bot._clownTransitionGrace = nil
                bot._clownLastSurvival = nil
                bot._clownLastHunting = nil
            end
        end
    end
end)

print("[TTT Bots 2] ClownCoordinator loaded — Clown/Killer Clown transformation detection enabled.")
