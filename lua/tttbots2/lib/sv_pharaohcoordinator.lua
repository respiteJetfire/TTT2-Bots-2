--- sv_pharaohcoordinator.lua
--- Detects mid-round Pharaoh/Graverobber role transitions via TTT2UpdateSubrole,
--- cleans up ankh-related bot state, and fires custom hooks for ankh events.

local lib = TTTBots.Lib

-- ===========================================================================
-- G-8: Role reversion awareness — clean up Graverobber bot state when they
-- revert to their previous role (all ankhs destroyed).
-- Also handles Pharaoh state cleanup if role changes mid-round.
-- ===========================================================================

hook.Add("TTT2UpdateSubrole", "TTTBots.PharaohCoordinator.RoleReversion", function(ply, oldSubrole, newSubrole)
    if not (IsValid(ply) and ply:IsBot()) then return end
    if not TTTBots.Match.RoundActive then return end

    -- Graverobber reverting to another role (all ankhs destroyed)
    if oldSubrole == ROLE_GRAVEROBBER and newSubrole ~= ROLE_GRAVEROBBER then
        -- Clean up all ankh-related state
        ply.targetAnkh = nil
        ply.ankhConvertingEntity = nil
        ply.ankhConvertStartTime = nil
        ply.ankhConvertEndTime = nil
        ply._ankhConvertingEnt = nil
        ply._ankhConvertStart = nil
        ply._huntAnkhStart = nil
        ply._huntAnkhCandidates = nil
        ply._huntAnkhIndex = nil
        ply._huntAnkhScanStart = nil
        ply._huntAnkhChecked = nil
        ply._lastHuntAnkhEnd = nil
        ply._lastAnkhGuardEnd = nil
        ply._ankhGuardStart = nil
        ply._ankhPatrolTarget = nil
        ply.ankhThreatSource = nil
        ply.ankhUnderThreat = nil

        -- Kill any active conversion timer
        timer.Remove("TTTBots.CaptureAnkh.Convert." .. ply:EntIndex())

        if lib.GetConVarBool("debug_misc") then
            print(string.format("[PharaohCoordinator] %s reverted from Graverobber to %s — ankh state cleaned",
                ply:Nick(), ply:GetRoleStringRaw()))
        end
    end

    -- Pharaoh losing their role mid-round (unusual but possible)
    if oldSubrole == ROLE_PHARAOH and newSubrole ~= ROLE_PHARAOH then
        ply._lastAnkhThreatAlert = nil
        ply._lastAnkhGuardEnd = nil
        ply._ankhGuardStart = nil
        ply._ankhPatrolTarget = nil
        ply.ankhThreatSource = nil
        ply.ankhUnderThreat = nil
        ply._lastAnkhProximityWarn = nil

        if lib.GetConVarBool("debug_misc") then
            print(string.format("[PharaohCoordinator] %s lost Pharaoh role — ankh state cleaned",
                ply:Nick()))
        end
    end
end)

-- ===========================================================================
-- Fire custom hooks when ankh events occur, used by chatter triggers.
-- These hooks bridge the PHARAOH_HANDLER events to the bot chatter system.
-- ===========================================================================

--- Monitor for ankh ownership transfers and fire TTT2AnkhOwnershipTransferred hook.
--- PHARAOH_HANDLER:TransferAnkhOwnership modifies ankhs[].current_owner_id and
--- fires sounds/effects but has no hook we can listen to. We detect changes by
--- polling the ankh data table.

local _lastAnkhOwners = {}

timer.Create("TTTBots.PharaohCoordinator.OwnershipMonitor", 1, 0, function()
    if not TTTBots.Match.RoundActive then
        _lastAnkhOwners = {}
        return
    end
    if not PHARAOH_HANDLER or not PHARAOH_HANDLER.ankhs then return end

    for dataId, data in pairs(PHARAOH_HANDLER.ankhs) do
        local currentOwnerSid = data.current_owner_id
        local previousOwnerSid = _lastAnkhOwners[dataId]

        if previousOwnerSid and currentOwnerSid ~= previousOwnerSid then
            -- Ownership changed! Find the players
            local newOwner = nil
            local oldOwner = nil
            for _, ply in pairs(player.GetAll()) do
                if ply:SteamID64() == currentOwnerSid then newOwner = ply end
                if ply:SteamID64() == previousOwnerSid then oldOwner = ply end
            end

            hook.Run("TTT2AnkhOwnershipTransferred", data.ankh, newOwner, oldOwner)
        end

        _lastAnkhOwners[dataId] = currentOwnerSid
    end
end)

--- Monitor for ankh revivals and fire TTT2AnkhRevive hook.
--- The Pharaoh addon sets ankh:SetNWBool("isReviving", true) and ankh.revivingPlayer
--- when a revival starts, then removes the ankh in OnRevive. We detect the revival
--- completing by tracking which ankhs were reviving and checking when the player
--- becomes alive again.
local _revivingAnkhs = {}

timer.Create("TTTBots.PharaohCoordinator.RevivalMonitor", 0.5, 0, function()
    if not TTTBots.Match.RoundActive then
        _revivingAnkhs = {}
        return
    end

    -- Check ankhs currently in a reviving state
    for _, ankh in pairs(ents.FindByClass("ttt_ankh")) do
        if not IsValid(ankh) then continue end

        local idx = ankh:EntIndex()
        local isReviving = ankh:GetNWBool("isReviving", false)
        local revivingPly = ankh.revivingPlayer

        if isReviving and IsValid(revivingPly) and not _revivingAnkhs[idx] then
            -- Track that this ankh is actively reviving someone
            _revivingAnkhs[idx] = revivingPly
        end
    end

    -- Check tracked revivals: if the player is now alive, the revival completed
    -- (The ankh gets removed in OnRevive, so it won't be in FindByClass anymore)
    for idx, ply in pairs(_revivingAnkhs) do
        if not IsValid(ply) then
            _revivingAnkhs[idx] = nil
            continue
        end

        if ply:Alive() and not ply:IsSpec() then
            -- Revival completed! Fire the hook
            hook.Run("TTT2AnkhRevive", ply)
            _revivingAnkhs[idx] = nil

            if lib.GetConVarBool("debug_misc") then
                print(string.format("[PharaohCoordinator] %s revived via ankh — TTT2AnkhRevive fired",
                    ply:Nick()))
            end
        end
    end
end)

--- Monitor for ankh entity destruction and fire TTT2AnkhDestroyed hook.
local _trackedAnkhs = {}

timer.Create("TTTBots.PharaohCoordinator.DestructionMonitor", 0.5, 0, function()
    if not TTTBots.Match.RoundActive then
        _trackedAnkhs = {}
        return
    end

    -- Track current ankhs
    local currentAnkhs = {}
    for _, ankh in pairs(ents.FindByClass("ttt_ankh")) do
        if IsValid(ankh) then
            currentAnkhs[ankh:EntIndex()] = ankh
        end
    end

    -- Check for destroyed ankhs
    for idx, ankh in pairs(_trackedAnkhs) do
        if not currentAnkhs[idx] then
            -- Ankh was destroyed
            hook.Run("TTT2AnkhDestroyed", ankh, nil)
        end
    end

    _trackedAnkhs = currentAnkhs
end)

-- Clean up on round end/start
hook.Add("TTTEndRound", "TTTBots.PharaohCoordinator.RoundEnd", function()
    _lastAnkhOwners = {}
    _trackedAnkhs = {}
    _revivingAnkhs = {}
end)

hook.Add("TTTBeginRound", "TTTBots.PharaohCoordinator.RoundStart", function()
    _lastAnkhOwners = {}
    _trackedAnkhs = {}
    _revivingAnkhs = {}

    -- Clean up ankh state on all bots
    for _, bot in ipairs(TTTBots.Bots) do
        if not IsValid(bot) then continue end
        bot._tttbots_ankhRevivalTime = nil
        bot._lastAnkhThreatAlert = nil
        bot._lastAnkhGuardEnd = nil
        bot._ankhGuardStart = nil
        bot._ankhPatrolTarget = nil
        bot.ankhThreatSource = nil
        bot.ankhUnderThreat = nil
        bot._lastAnkhProximityWarn = nil
        bot.targetAnkh = nil
        bot.ankhConvertingEntity = nil
        bot.ankhConvertStartTime = nil
        bot.ankhConvertEndTime = nil
        bot._ankhConvertingEnt = nil
        bot._ankhConvertStart = nil
        bot._huntAnkhChecked = nil
    end
end)
