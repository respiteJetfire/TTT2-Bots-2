--- DefendAnkh: Pharaoh bot rushes to defend their ankh when it is being
--- converted or attacked by enemies. High-priority reactive behavior.

TTTBots.Behaviors.DefendAnkh = {}

local lib = TTTBots.Lib

local DefendAnkh = TTTBots.Behaviors.DefendAnkh
DefendAnkh.Name = "DefendAnkh"
DefendAnkh.Description = "Rush to defend ankh under attack or conversion"
DefendAnkh.Interruptible = false -- High priority, don't interrupt

local STATUS = TTTBots.STATUS

--- Get the bot's own placed ankh entity
---@param bot Entity
---@return Entity|nil
function DefendAnkh.GetOwnAnkh(bot)
    local ankhs = ents.FindByClass("ttt_ankh")
    for _, ankh in pairs(ankhs) do
        if IsValid(ankh) and ankh:GetOwner() == bot then
            return ankh
        end
    end
    return nil
end

--- Check if the ankh is under threat (being converted or taking damage)
---@param ankh Entity
---@return boolean
function DefendAnkh.IsAnkhUnderThreat(ankh)
    if not IsValid(ankh) then return false end

    -- Check if someone is converting the ankh (conversion progress > 0)
    local convProgress = ankh:GetNWInt("conversion_progress", 0)
    if convProgress > 0 then
        return true
    end

    -- Check if ankh is below max health (has taken damage)
    local maxHP = GetConVar("ttt_ankh_health"):GetInt()
    if ankh:Health() < maxHP * 0.9 then
        return true
    end

    -- Check if a Graverobber is actively converting (but does NOT yet own) the ankh
    local nearbyPlayers = ents.FindInSphere(ankh:GetPos(), 150)
    for _, ent in pairs(nearbyPlayers) do
        if not (IsValid(ent) and ent:IsPlayer() and ent ~= ankh:GetOwner() and lib.IsPlayerAlive(ent)) then continue end
        if ent:GetSubRole() ~= ROLE_GRAVEROBBER then continue end

        -- Only a threat if the Graverobber does NOT already own this ankh
        -- (if they already own it, the ankh:GetOwner() would be them, but let's be explicit)
        local alreadyOwns = PHARAOH_HANDLER and PHARAOH_HANDLER:PlayerControlsAnAnkh(ent)
        if not alreadyOwns then
            return true
        end
    end

    return false
end

--- Validate the behavior
function DefendAnkh.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Must be Pharaoh (defending or reclaiming their own ankh)
    if bot:GetSubRole() ~= ROLE_PHARAOH then
        return false
    end

    -- Case 1: Pharaoh still controls the ankh — defend it from threat
    if PHARAOH_HANDLER:PlayerControlsAnAnkh(bot) then
        local ankh = DefendAnkh.GetOwnAnkh(bot)
        if not IsValid(ankh) then return false end
        return DefendAnkh.IsAnkhUnderThreat(ankh)
    end

    -- Case 2: Pharaoh's ankh was stolen — the Graverobber who stole it is a threat
    -- The ankh still exists in the world (owned by the Graverobber)
    local ply_id = bot:SteamID64()
    local ankhData = PHARAOH_HANDLER and PHARAOH_HANDLER.ankhs and PHARAOH_HANDLER.ankhs[ply_id]
    if ankhData and ankhData.current_owner_id ~= ply_id and IsValid(ankhData.ankh) then
        -- Ankh was stolen and is still placed in the world — go reclaim it
        return true
    end

    return false
end

--- Called when the behavior is started
function DefendAnkh.OnStart(bot)
    -- Fire chatter to alert others
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("DefendAnkh", {})
    end
    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function DefendAnkh.OnRunning(bot)
    local locomotor = bot:BotLocomotor()

    -- Case 2: Ankh was stolen — find the thief and engage them
    local ply_id = bot:SteamID64()
    local ankhData = PHARAOH_HANDLER and PHARAOH_HANDLER.ankhs and PHARAOH_HANDLER.ankhs[ply_id]
    local ankh = DefendAnkh.GetOwnAnkh(bot)

    if not PHARAOH_HANDLER:PlayerControlsAnAnkh(bot) and ankhData and ankhData.current_owner_id ~= ply_id then
        local stolenAnkh = ankhData.ankh
        if not IsValid(stolenAnkh) then return STATUS.FAILURE end

        -- Navigate to the stolen ankh
        locomotor:SetGoal(stolenAnkh:GetPos())

        -- Find and attack the thief
        local plys = player.GetAll()
        for i = 1, #plys do
            local ply = plys[i]
            if ply:SteamID64() == ankhData.current_owner_id and lib.IsPlayerAlive(ply) then
                local Arb = TTTBots.Morality
                local PRI = Arb.PRIORITY
                if bot:Visible(ply) then
                    Arb.RequestAttackTarget(bot, ply, "DEFEND_ANKH", PRI.PLAYER_REQUEST)
                end
                locomotor:LookAt(ply:GetPos())
                break
            end
        end

        -- If ankh is back under control (reclaimed) or the thief is gone, succeed
        if PHARAOH_HANDLER:PlayerControlsAnAnkh(bot) or ankhData.current_owner_id == ply_id then
            return STATUS.SUCCESS
        end
        return STATUS.RUNNING
    end

    -- Case 1: Pharaoh still controls the ankh — defend it from threat
    if not IsValid(ankh) then return STATUS.FAILURE end

    local distToAnkh = bot:GetPos():Distance(ankh:GetPos())

    -- Sprint to the ankh
    locomotor:SetGoal(ankh:GetPos())

    -- If we're close, look for the threat and engage
    if distToAnkh < 200 then
        -- Find nearby enemies, especially Graverobbers
        local nearbyPlayers = ents.FindInSphere(ankh:GetPos(), 250)
        local closestThreat = nil
        local closestDist = math.huge

        for _, ent in pairs(nearbyPlayers) do
            if not (IsValid(ent) and ent:IsPlayer() and ent ~= bot and lib.IsPlayerAlive(ent)) then continue end

            -- Prioritize Graverobbers, then any enemy
            local isThreat = false
            if ent:GetSubRole() == ROLE_GRAVEROBBER then
                isThreat = true
            elseif not TTTBots.Roles.IsAllies(bot, ent) then
                isThreat = true
            end

            if isThreat then
                local dist = bot:GetPos():Distance(ent:GetPos())
                if dist < closestDist then
                    closestDist = dist
                    closestThreat = ent
                end
            end
        end

        if closestThreat then
            local Arb = TTTBots.Morality
            local PRI = Arb.PRIORITY
            Arb.RequestAttackTarget(bot, closestThreat, "DEFEND_ANKH", PRI.PLAYER_REQUEST)
            locomotor:LookAt(closestThreat:GetPos())
        end
    end

    -- If ankh is no longer under threat, we can stop
    if not DefendAnkh.IsAnkhUnderThreat(ankh) and distToAnkh < 100 then
        return STATUS.SUCCESS
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state
function DefendAnkh.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function DefendAnkh.OnFailure(bot)
end

--- Called when the behavior ends
function DefendAnkh.OnEnd(bot)
end

--- Monitor ankhs for threats and notify Pharaoh bots
timer.Create("TTTBots.Behaviors.DefendAnkh.Monitor", 2, 0, function()
    if not TTTBots.Match.RoundActive then return end

    local ankhs = ents.FindByClass("ttt_ankh")
    for _, ankh in pairs(ankhs) do
        if not IsValid(ankh) then continue end
        if not DefendAnkh.IsAnkhUnderThreat(ankh) then continue end

        -- Find the owning bot and alert them
        local owner = ankh:GetOwner()
        if not (IsValid(owner) and owner:IsBot() and lib.IsPlayerAlive(owner)) then continue end
        if owner:GetSubRole() ~= ROLE_PHARAOH then continue end

        -- Fire chatter about ankh being under attack (rate-limited)
        if (CurTime() - (owner._lastAnkhThreatAlert or 0)) > 10 then
            owner._lastAnkhThreatAlert = CurTime()
            local chatter = owner:BotChatter()
            if chatter and chatter.On then
                chatter:On("DefendAnkh", {})
            end
        end
    end
end)
