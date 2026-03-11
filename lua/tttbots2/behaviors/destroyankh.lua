--- DestroyAnkh: Graverobber bot shoots/destroys an ankh when they cannot convert it
--- (e.g., they already control one, or it's reviving someone).

TTTBots.Behaviors.DestroyAnkh = {}

local lib = TTTBots.Lib

local DestroyAnkh = TTTBots.Behaviors.DestroyAnkh
DestroyAnkh.Name = "DestroyAnkh"
DestroyAnkh.Description = "Destroy an ankh that cannot be converted"
DestroyAnkh.Interruptible = true
DestroyAnkh.ATTACK_RANGE = 300 --- Range at which we start shooting the ankh

local STATUS = TTTBots.STATUS

--- Find an ankh that should be destroyed (enemy ankh that can't be converted)
---@param bot Entity
---@return Entity|nil
function DestroyAnkh.FindDestroyableAnkh(bot)
    local ankhs = ents.FindByClass("ttt_ankh")
    local bestAnkh = nil
    local bestDist = math.huge

    for _, ankh in pairs(ankhs) do
        if not IsValid(ankh) then continue end

        -- Don't destroy ankhs we own/control
        if ankh:GetOwner() == bot then continue end

        -- Only destroy if we can't convert it (already have one, or it's reviving)
        local shouldDestroy = false

        if PHARAOH_HANDLER:PlayerControlsAnAnkh(bot) then
            -- We already have an ankh, destroy the enemy's
            shouldDestroy = true
        end

        if ankh:GetNWBool("isReviving", false) then
            -- Ankh is reviving someone, destroying it cancels the revival
            shouldDestroy = true
        end

        if shouldDestroy then
            local dist = bot:GetPos():Distance(ankh:GetPos())
            if dist < bestDist then
                bestDist = dist
                bestAnkh = ankh
            end
        end
    end

    return bestAnkh
end

--- Validate the behavior
function DestroyAnkh.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.attackTarget ~= nil then return false end

    -- Only Graverobbers (or traitor-team) should destroy ankhs
    if bot:GetSubRole() ~= ROLE_GRAVEROBBER then
        return false
    end

    local ankh = DestroyAnkh.FindDestroyableAnkh(bot)
    return ankh ~= nil
end

--- Called when the behavior is started
function DestroyAnkh.OnStart(bot)
    bot._destroyAnkhTarget = DestroyAnkh.FindDestroyableAnkh(bot)
    if not IsValid(bot._destroyAnkhTarget) then
        return STATUS.FAILURE
    end
    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function DestroyAnkh.OnRunning(bot)
    local ankh = bot._destroyAnkhTarget
    if not IsValid(ankh) then return STATUS.SUCCESS end -- Ankh was destroyed
    if bot.attackTarget ~= nil then return STATUS.FAILURE end

    local locomotor = bot:BotLocomotor()
    local distToAnkh = bot:GetPos():Distance(ankh:GetPos())

    -- Navigate toward the ankh
    locomotor:SetGoal(ankh:GetPos())

    -- When in range, shoot the ankh
    if distToAnkh < DestroyAnkh.ATTACK_RANGE then
        locomotor:LookAt(ankh:GetPos() + Vector(0, 0, 15)) -- Aim at center of ankh

        -- Check for witnesses (avoid if non-allied players can see)
        local witnesses = lib.GetAllWitnessesBasic and lib.GetAllWitnessesBasic(bot:GetPos(), TTTBots.Roles.GetNonAllies(bot), bot) or {}
        if #witnesses == 0 or distToAnkh < 100 then
            -- Fire at the ankh
            locomotor:StartAttack()

            -- Rate-limited shooting
            if not bot._ankhShootCooldown or CurTime() > bot._ankhShootCooldown then
                bot._ankhShootCooldown = CurTime() + 0.3
            end
        end
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state
function DestroyAnkh.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function DestroyAnkh.OnFailure(bot)
end

--- Called when the behavior ends
function DestroyAnkh.OnEnd(bot)
    bot._destroyAnkhTarget = nil
    bot._ankhShootCooldown = nil
    local locomotor = bot:BotLocomotor()
    locomotor:StopAttack()
end
