--- sv_amnesiaccoordinator.lua
--- Detects mid-round Amnesiac role transitions via TTT2UpdateSubrole, publishes
--- events, triggers chatter/evidence for witnesses, handles suspicion/evidence
--- reset, popup-awareness, urgency scaling, and transition grace period.
--- Modeled after sv_cursedcoordinator.lua and sv_infectedcoordinator.lua.
--- This file is auto-included by IncludeDirectory("tttbots2/lib").

if not (TTT2 and ROLE_AMNESIAC) then return end

local lib = TTTBots.Lib

TTTBots.AmnesiacCoordinator = TTTBots.AmnesiacCoordinator or {}
local Coord = TTTBots.AmnesiacCoordinator

--- Track known Amnesiac players so we can detect conversion events.
Coord._knownAmnesiacs = Coord._knownAmnesiacs or {}

--- Track the acquired role for post-conversion logging.
Coord._conversionLog = Coord._conversionLog or {}

-- ---------------------------------------------------------------------------
-- Role-change detection via TTT2UpdateSubrole
-- ---------------------------------------------------------------------------

hook.Add("TTT2UpdateSubrole", "TTTBots.AmnesiacCoordinator.DetectConversion", function(ply, oldSubrole, newSubrole)
    if not ROLE_AMNESIAC then return end

    -- ── Player BECAME Amnesiac (round start or mid-round assignment) ──────
    if newSubrole == ROLE_AMNESIAC and oldSubrole ~= ROLE_AMNESIAC then
        timer.Simple(0.1, function()
            if not IsValid(ply) then return end

            Coord._knownAmnesiacs[ply] = true

            -- If this is a bot, fire initial role-received chatter
            if ply:IsBot() and ply.BotChatter then
                local chatter = ply:BotChatter()
                if chatter and chatter.On then
                    chatter:On("AmnesiacRoleReceived", {})
                end
            end
        end)
    end

    -- ── Player LEFT Amnesiac (converted to a new role via corpse search) ──
    if oldSubrole == ROLE_AMNESIAC and newSubrole ~= ROLE_AMNESIAC then
        timer.Simple(0.1, function()
            if not IsValid(ply) then return end

            Coord._knownAmnesiacs[ply] = nil

            -- Log the conversion
            local newRoleObj = roles.GetByIndex(newSubrole)
            local newRoleName = newRoleObj and newRoleObj.name or "unknown"
            Coord._conversionLog[ply] = {
                newRole = newSubrole,
                newRoleName = newRoleName,
                time = CurTime(),
            }

            if ply:IsBot() then
                -- ── Set transition grace period (GAP-12) ──────────────────
                -- Prevents stale morality/hostility evaluation during the
                -- brief window between role change and cleanup completion.
                ply._amnesiacTransitionGrace = CurTime() + 2

                -- ── Reset suspicion (GAP-5) ───────────────────────────────
                local morality = ply.components and ply.components.morality
                if morality and morality.ResetSuspicions then
                    morality:ResetSuspicions()
                elseif morality then
                    if morality.suspicions then
                        table.Empty(morality.suspicions)
                    end
                end

                -- ── Clear stale evidence (GAP-5) ──────────────────────────
                local evidence = ply.components and ply.components.evidence
                if evidence and evidence.ClearRoundEvidence then
                    evidence:ClearRoundEvidence()
                elseif evidence and evidence.evidenceEntries then
                    table.Empty(evidence.evidenceEntries)
                end

                -- ── Clear stale behavior state (GAP-9) ────────────────────
                -- Force the behavior tree to re-evaluate from scratch
                ply.lastBehavior = nil
                ply.corpseTarget = nil
                if ply.attackTarget then
                    ply.attackTarget = nil
                end

                -- Clear AmnesiacSeek state so it doesn't try to seek again
                if ply.behaviorState then
                    ply.behaviorState["AmnesiacSeek"] = nil
                end

                -- ── Fire conversion success chatter ───────────────────────
                local chatter = ply.BotChatter and ply:BotChatter()
                if chatter and chatter.On then
                    chatter:On("AmnesiacConversionSuccess", {
                        newrole = newRoleName,
                    })
                end
            end

            -- ── Popup awareness: notify all bots about the conversion ─────
            local showPopup = GetConVar("ttt2_amnesiac_showpopup")
            if showPopup and showPopup:GetBool() and TTTBots.Bots then
                for _, bot in ipairs(TTTBots.Bots) do
                    if not IsValid(bot) then continue end
                    if not lib.IsPlayerAlive(bot) then continue end
                    if bot == ply then continue end

                    -- All bots see the popup (it's a global broadcast)
                    local _c = bot:BotChatter()
                    if _c and _c.On then
                        _c:On("AmnesiacConversionWitnessed", {
                            newrole = newRoleName,
                        })
                    end

                    -- Add evidence that an Amnesiac just converted
                    local botEvidence = bot.components and bot.components.evidence
                    if botEvidence and botEvidence.AddEvidence then
                        botEvidence:AddEvidence({
                            type = "AMNESIAC_CONVERSION_WITNESSED",
                            subject = ply,
                            detail = "an Amnesiac has remembered they were " .. newRoleName,
                        })
                    end
                end
            end

            -- ── Publish event on the event bus ────────────────────────────
            if TTTBots.Events and TTTBots.Events.Publish then
                TTTBots.Events.Publish("AMNESIAC_CONVERTED", {
                    player = ply,
                    oldRole = oldSubrole,
                    newRole = newSubrole,
                    newRoleName = newRoleName,
                })
            end
        end)
    end
end)

-- ---------------------------------------------------------------------------
-- Urgency scaling: Late-round desperation chatter for unconverted Amnesiacs
-- ---------------------------------------------------------------------------

timer.Create("TTTBots.AmnesiacCoordinator.UrgencyTick", 10, 0, function()
    if not TTTBots.Match.IsRoundActive() then return end
    if not TTTBots.Bots then return end

    local alivePlayers = lib.GetAlivePlayers()
    local aliveCount = #alivePlayers
    local totalPlayers = player.GetCount()

    -- Calculate round time pressure
    local secondsPassed = TTTBots.Match.SecondsPassed or 0

    for _, bot in ipairs(TTTBots.Bots) do
        if not IsValid(bot) then continue end
        if not lib.IsPlayerAlive(bot) then continue end
        if bot:GetSubRole() ~= ROLE_AMNESIAC then continue end

        -- The bot is still Amnesiac — urgency increases over time
        local chatter = bot:BotChatter()
        if not (chatter and chatter.On) then continue end

        -- Rate limit: once every ~30 seconds per bot
        bot._amnesiacLastUrgency = bot._amnesiacLastUrgency or 0
        if CurTime() - bot._amnesiacLastUrgency < 30 then continue end

        -- Check available corpses
        local corpses = TTTBots.Match.Corpses or {}
        local hasValidCorpse = false
        for _, corpse in pairs(corpses) do
            if IsValid(corpse) and lib.IsValidBody(corpse) then
                local found = CORPSE.GetFound(corpse, false)
                local limitConvar = GetConVar("ttt2_amnesiac_limit_to_unconfirmed")
                local limitToUnconfirmed = limitConvar and limitConvar:GetBool() or true
                if not (found and limitToUnconfirmed) then
                    hasValidCorpse = true
                    break
                end
            end
        end

        -- Determine urgency level
        local urgencyThreshold = math.ceil(totalPlayers * 0.4)
        local isLateRound = aliveCount <= urgencyThreshold or secondsPassed > 180

        if not hasValidCorpse then
            chatter:On("AmnesiacNoBodiesAvailable", {})
            bot._amnesiacLastUrgency = CurTime()
        elseif isLateRound then
            chatter:On("AmnesiacDesperateLate", {})
            bot._amnesiacLastUrgency = CurTime()
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Post-conversion discretion: Amnesiac acts carefully after popup broadcast
-- ---------------------------------------------------------------------------

timer.Create("TTTBots.AmnesiacCoordinator.PostConversionDiscretion", 15, 0, function()
    if not TTTBots.Match.IsRoundActive() then return end
    if not TTTBots.Bots then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not IsValid(bot) then continue end
        if not lib.IsPlayerAlive(bot) then continue end

        -- Check if this bot recently converted from Amnesiac
        if not bot._amnesiacTransitionGrace then continue end
        if CurTime() > bot._amnesiacTransitionGrace + 10 then
            -- Grace period + discretion window expired, clean up
            bot._amnesiacTransitionGrace = nil
            continue
        end

        -- The bot just converted — fire discretion chatter occasionally
        bot._amnesiacDiscretionLast = bot._amnesiacDiscretionLast or 0
        if CurTime() - bot._amnesiacDiscretionLast < 20 then continue end

        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("AmnesiacPostConversionDisguise", {})
            bot._amnesiacDiscretionLast = CurTime()
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Round cleanup
-- ---------------------------------------------------------------------------

hook.Add("TTTEndRound", "TTTBots.AmnesiacCoordinator.Cleanup", function()
    Coord._knownAmnesiacs = {}
    Coord._conversionLog = {}

    -- Clean up per-bot state
    if TTTBots.Bots then
        for _, bot in ipairs(TTTBots.Bots) do
            if IsValid(bot) then
                bot._amnesiacLastUrgency = nil
                bot._amnesiacTransitionGrace = nil
                bot._amnesiacDiscretionLast = nil
            end
        end
    end
end)
