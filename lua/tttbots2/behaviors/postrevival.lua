--- PostRevival: After reviving from an ankh, the bot plays cautiously —
--- retreating from the ankh position, seeking cover, and prioritizing healing
--- due to only having 50 HP after revival.

TTTBots.Behaviors.PostRevival = {}

local lib = TTTBots.Lib

local PostRevival = TTTBots.Behaviors.PostRevival
PostRevival.Name = "PostRevival"
PostRevival.Description = "Play cautiously after ankh revival with low HP"
PostRevival.Interruptible = true

local STATUS = TTTBots.STATUS

--- How long after revival the cautious behavior stays active (seconds)
PostRevival.CAUTION_DURATION = 20
--- HP threshold — once above this, we can stop being cautious
PostRevival.HP_SAFE_THRESHOLD = 75
--- How far to retreat from the ankh position
PostRevival.RETREAT_DIST = 500

--- Validate the behavior
function PostRevival.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Check if the bot just revived via ankh
    if not bot._tttbots_ankhRevivalTime then return false end

    -- Still within the caution window?
    local elapsed = CurTime() - bot._tttbots_ankhRevivalTime
    if elapsed > PostRevival.CAUTION_DURATION then
        bot._tttbots_ankhRevivalTime = nil
        return false
    end

    -- Already healed enough?
    if bot:Health() >= PostRevival.HP_SAFE_THRESHOLD then
        return false
    end

    return true
end

--- Called when the behavior is started
function PostRevival.OnStart(bot)
    bot._postRevivalPhase = "retreat" -- phases: retreat, seek_health
    bot._postRevivalStart = CurTime()

    -- Fire revival chatter
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("AnkhRevival", {})
    end

    return STATUS.RUNNING
end

--- Find the nearest health station or health pack
---@param bot Entity
---@return Vector|nil
function PostRevival.FindHealthSource(bot)
    -- Try health stations
    local healthStations = ents.FindByClass("ttt_health_station")
    local closest = nil
    local closestDist = math.huge

    for _, hs in pairs(healthStations) do
        if not IsValid(hs) then continue end
        local dist = bot:GetPos():Distance(hs:GetPos())
        if dist < closestDist then
            closestDist = dist
            closest = hs:GetPos()
        end
    end

    return closest
end

--- Find a safe position away from the ankh and other players
---@param bot Entity
---@return Vector|nil
function PostRevival.FindSafeSpot(bot)
    -- Try using hiding spots
    if TTTBots.Spots and TTTBots.Spots.GetSpotsInCategory then
        local hidingSpots = TTTBots.Spots.GetSpotsInCategory("hiding")
        if hidingSpots and #hidingSpots > 0 then
            local bestSpot = nil
            local bestScore = -math.huge

            for _, spot in pairs(hidingSpots) do
                local pos = spot.pos or spot
                if not isvector(pos) then continue end

                local score = 0
                -- Prefer spots away from other players
                for _, ply in pairs(TTTBots.Match.AlivePlayers or {}) do
                    if not IsValid(ply) or ply == bot then continue end
                    local dist = pos:Distance(ply:GetPos())
                    score = score + math.min(dist / 100, 10)
                end

                -- Prefer spots not too far from current position (don't wander into danger)
                local distFromBot = pos:Distance(bot:GetPos())
                if distFromBot < 1500 then
                    score = score + 5
                end

                if score > bestScore then
                    bestScore = score
                    bestSpot = pos
                end
            end

            return bestSpot
        end
    end

    -- Fallback: just move away from the ankh spawn position
    local ankhs = ents.FindByClass("ttt_ankh")
    for _, ankh in pairs(ankhs) do
        if IsValid(ankh) and ankh:GetOwner() == bot then
            local awayDir = (bot:GetPos() - ankh:GetPos()):GetNormalized()
            return bot:GetPos() + awayDir * PostRevival.RETREAT_DIST
        end
    end

    return nil
end

--- Called when the behavior's last state is running
function PostRevival.OnRunning(bot)
    if bot.attackTarget ~= nil then return STATUS.FAILURE end

    local elapsed = CurTime() - (bot._postRevivalStart or 0)
    if elapsed > PostRevival.CAUTION_DURATION then return STATUS.SUCCESS end
    if bot:Health() >= PostRevival.HP_SAFE_THRESHOLD then return STATUS.SUCCESS end

    local locomotor = bot:BotLocomotor()

    if bot._postRevivalPhase == "retreat" then
        -- Phase 1: Move to a safe position
        if not bot._postRevivalRetreatPos then
            bot._postRevivalRetreatPos = PostRevival.FindSafeSpot(bot)
        end

        if bot._postRevivalRetreatPos then
            local dist = bot:GetPos():Distance(bot._postRevivalRetreatPos)
            if dist > 80 then
                locomotor:SetGoal(bot._postRevivalRetreatPos)
                return STATUS.RUNNING
            end
        end

        -- Retreat complete, switch to seeking health
        bot._postRevivalPhase = "seek_health"
    end

    if bot._postRevivalPhase == "seek_health" then
        -- Phase 2: Find and go to a health source
        local healthPos = PostRevival.FindHealthSource(bot)
        if healthPos then
            local dist = bot:GetPos():Distance(healthPos)
            if dist > 80 then
                locomotor:SetGoal(healthPos)
                return STATUS.RUNNING
            end
            -- At health station, UseHealthStation behavior will handle the rest
            return STATUS.SUCCESS
        end

        -- No health source found — stay in cover
        return STATUS.RUNNING
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state
function PostRevival.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function PostRevival.OnFailure(bot)
end

--- Called when the behavior ends
function PostRevival.OnEnd(bot)
    bot._postRevivalPhase = nil
    bot._postRevivalStart = nil
    bot._postRevivalRetreatPos = nil
end

-- ===========================================================================
-- Hook: detect ankh revivals and mark bots for cautious post-revival behavior
-- ===========================================================================

--- Primary detection: TTT2AnkhRevive fires from PharaohCoordinator when ankh
--- revival completes. This is the most reliable detection method.
hook.Add("TTT2AnkhRevive", "TTTBots.PostRevival.DetectAnkhRevival", function(ply)
    if not (IsValid(ply) and ply:IsBot()) then return end

    ply._tttbots_ankhRevivalTime = CurTime()
end)

--- Fallback detection: PlayerSpawn catches mid-round spawns for Pharaoh/Graverobber
--- bots. This covers edge cases where TTT2AnkhRevive might not fire (e.g., if the
--- PharaohCoordinator timer hasn't polled yet).
hook.Add("PlayerSpawn", "TTTBots.PostRevival.DetectAnkhRevivalFallback", function(ply)
    if not (IsValid(ply) and ply:IsBot()) then return end
    if not TTTBots.Match.RoundActive then return end

    -- Short delay to let the revival system finish initializing the player
    timer.Simple(0.1, function()
        if not IsValid(ply) then return end
        -- Already tagged by the primary hook? Skip.
        if ply._tttbots_ankhRevivalTime and (CurTime() - ply._tttbots_ankhRevivalTime) < 2 then return end

        -- If the bot is alive mid-round (not round start), it was revived
        -- Check if they are a Pharaoh or Graverobber who had an ankh
        local role = ply:GetSubRole()
        if role ~= ROLE_PHARAOH and role ~= ROLE_GRAVEROBBER then return end

        ply._tttbots_ankhRevivalTime = CurTime()
    end)
end)
