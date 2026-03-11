--- GuardAnkh: Pharaoh bot periodically returns to and stays near their placed ankh
--- to benefit from the healing aura and protect it from enemies.

TTTBots.Behaviors.GuardAnkh = {}

local lib = TTTBots.Lib

local GuardAnkh = TTTBots.Behaviors.GuardAnkh
GuardAnkh.Name = "GuardAnkh"
GuardAnkh.Description = "Stay near own ankh for healing and protection"
GuardAnkh.Interruptible = true

GuardAnkh.GUARD_RANGE = 200 --- Distance to stay within the ankh for healing aura
GuardAnkh.HEAL_RANGE = 100 --- The ankh's healing aura range
GuardAnkh.PATROL_RADIUS = 250 --- How far to patrol around the ankh

local STATUS = TTTBots.STATUS

--- Get the bot's own placed ankh entity
---@param bot Entity
---@return Entity|nil
function GuardAnkh.GetOwnAnkh(bot)
    local ankhs = ents.FindByClass("ttt_ankh")
    for _, ankh in pairs(ankhs) do
        if IsValid(ankh) and ankh:GetOwner() == bot then
            return ankh
        end
    end
    return nil
end

--- Check if the bot is hurt and should prioritize staying near ankh for healing
---@param bot Entity
---@return boolean
function GuardAnkh.NeedsHealing(bot)
    return bot:Health() < bot:GetMaxHealth() * 0.8
end

--- Validate the behavior
function GuardAnkh.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.attackTarget ~= nil then return false end

    -- Only Pharaohs and Graverobbers who control an ankh should guard it
    if bot:GetSubRole() ~= ROLE_PHARAOH and bot:GetSubRole() ~= ROLE_GRAVEROBBER then
        return false
    end

    -- Must actually control an ankh
    if not PHARAOH_HANDLER:PlayerControlsAnAnkh(bot) then
        return false
    end

    local ankh = GuardAnkh.GetOwnAnkh(bot)
    if not IsValid(ankh) then return false end

    -- More likely to guard when hurt (healing aura benefit)
    if GuardAnkh.NeedsHealing(bot) then
        return true
    end

    -- Periodically return to guard the ankh (every ~45 seconds, spend time near it)
    if not bot._lastAnkhGuardTime then
        bot._lastAnkhGuardTime = CurTime()
    end

    -- Guard for 15 seconds every 45 seconds
    local timeSinceGuard = CurTime() - (bot._lastAnkhGuardEnd or 0)
    if timeSinceGuard > 45 then
        return true
    end

    return false
end

--- Called when the behavior is started
function GuardAnkh.OnStart(bot)
    bot._ankhGuardStart = CurTime()
    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function GuardAnkh.OnRunning(bot)
    local ankh = GuardAnkh.GetOwnAnkh(bot)
    if not IsValid(ankh) then return STATUS.FAILURE end
    if bot.attackTarget ~= nil then return STATUS.FAILURE end

    local locomotor = bot:BotLocomotor()
    local distToAnkh = bot:GetPos():Distance(ankh:GetPos())

    -- Navigate toward the ankh
    if distToAnkh > GuardAnkh.GUARD_RANGE then
        locomotor:SetGoal(ankh:GetPos())
        return STATUS.RUNNING
    end

    -- If we're close enough, patrol around the ankh
    if distToAnkh <= GuardAnkh.GUARD_RANGE then
        -- If healing is needed, stay within heal range
        if GuardAnkh.NeedsHealing(bot) and distToAnkh > GuardAnkh.HEAL_RANGE then
            locomotor:SetGoal(ankh:GetPos())
            return STATUS.RUNNING
        end

        -- If fully healed and guarded long enough, end behavior
        local guardDuration = CurTime() - (bot._ankhGuardStart or CurTime())
        if guardDuration > 15 and not GuardAnkh.NeedsHealing(bot) then
            return STATUS.SUCCESS
        end

        -- Patrol: pick a random point near the ankh
        if not bot._ankhPatrolTarget or bot:GetPos():Distance(bot._ankhPatrolTarget) < 50 then
            local angle = math.random(0, 360)
            local rad = math.rad(angle)
            local offset = Vector(math.cos(rad) * GuardAnkh.PATROL_RADIUS, math.sin(rad) * GuardAnkh.PATROL_RADIUS, 0)
            bot._ankhPatrolTarget = ankh:GetPos() + offset
        end

        locomotor:SetGoal(bot._ankhPatrolTarget)

        -- Watch for enemies near the ankh
        local nearbyPlayers = lib.GetAllVisible(ankh:GetPos(), false, bot)
        for _, ply in pairs(nearbyPlayers) do
            if not IsValid(ply) then continue end
            if ply == bot then continue end
            -- Be suspicious of unknown players lurking near our ankh
            if bot:GetSubRole() == ROLE_PHARAOH then
                local chatter = bot:BotChatter()
                if chatter and chatter.On and (CurTime() - (bot._lastAnkhProximityWarn or 0)) > 15 then
                    bot._lastAnkhProximityWarn = CurTime()
                    chatter:On("DeclareSuspicious", { player = ply:Nick(), playerEnt = ply })
                end
            end
        end
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state
function GuardAnkh.OnSuccess(bot)
    bot._lastAnkhGuardEnd = CurTime()
end

--- Called when the behavior returns a failure state
function GuardAnkh.OnFailure(bot)
    bot._lastAnkhGuardEnd = CurTime()
end

--- Called when the behavior ends
function GuardAnkh.OnEnd(bot)
    bot._ankhGuardStart = nil
    bot._ankhPatrolTarget = nil
end
