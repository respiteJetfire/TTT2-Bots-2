
TTTBots.Behaviors.UseRoleChecker = {}

local lib = TTTBots.Lib

local UseRoleChecker = TTTBots.Behaviors.UseRoleChecker
UseRoleChecker.Name = "Use Role Tester / Checker"
UseRoleChecker.Description = "Use or place a Role Checker to determine the role of a player."
UseRoleChecker.Interruptible = false
UseRoleChecker.UseRange = 100 --- The range at which we can use a health checker

UseRoleChecker.TargetClass = "ttt_traitorchecker"

--- Maximum time (seconds) the detective will spend trying to place before giving up.
UseRoleChecker.PlaceTimeout = 25

--- After this many seconds of failed placement, recalculate the look-at target.
UseRoleChecker.PlaceRetryInterval = 6

local STATUS = TTTBots.STATUS


function UseRoleChecker.HasRoleChecker(bot)
    return bot:HasWeapon("weapon_ttt_traitorchecker")
end

function UseRoleChecker.ValidateChecker(hs)
    local isvalid = (
        IsValid(hs)
        and hs:GetClass() == UseRoleChecker.TargetClass
    )
    return isvalid
end

function UseRoleChecker.GetNearestChecker(bot)
    local checkers = ents.FindByClass(UseRoleChecker.TargetClass)
    local validCheckers = {}
    for i, v in pairs(checkers) do
        if not UseRoleChecker.ValidateChecker(v) then
            continue
        end
        table.insert(validCheckers, v)
    end

    local nearestChecker = lib.GetClosest(validCheckers, bot:GetPos())
    return nearestChecker
end

function UseRoleChecker.UseChecker(bot, checker)
    -- Force the bot to look directly at the checker entity first.
    -- The checker's ENT:Use checks ply:GetEyeTrace().Entity != self and
    -- rejects the use if the player isn't looking at it.
    local loco = bot:BotLocomotor()
    if loco then loco:LookAt(checker:GetPos()) end
    -- Use the 4-arg form so the entity receives proper activator/caller/useType
    checker:Use(bot, bot, USE_ON, 0)
end

--- Validate the behavior
function UseRoleChecker.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.attackTarget ~= nil then return false end             --- We are preoccupied with an attacker (self-defense, KOS, etc.)

    local role = bot:GetSubRole()

    if TTTBots.Match.CheckedPlayers[bot] and TTTBots.Match.CheckedPlayers[bot][role] then
        -- print("UseRoleChecker.Validate: Already checked player")
        return false
    end

    local hasRoleChecker = UseRoleChecker.HasRoleChecker(bot)
    local isCheckerNearby = (bot.targetChecker or UseRoleChecker.GetNearestChecker(bot) ~= nil)

    if not (hasRoleChecker or isCheckerNearby) then return false end

    -- Detective bots should almost always use/place the role checker when they have one —
    -- don't gate them behind the stochastic roll.
    -- Skip if the detective already deployed this round (tracked by InnocentCoordinator).
    if hasRoleChecker and bot:GetBaseRole() == ROLE_DETECTIVE then
        local IC = TTTBots.InnocentCoordinator
        if IC and IC.DetectiveDeployedChecker then return false end
        return true
    end

    -- Innocent / None bots have a chance to walk to a nearby checker.
    -- Increased from the original ~2.5% per tick to ~10% so the behavior actually triggers
    -- within a reasonable time frame during a round.
    if not bot.isGoingToChecker then
        local chance = (bot:GetTeam() == TEAM_NONE or bot:GetTeam() == TEAM_INNOCENT) and 20 or 3
        if math.random(0, 200) > chance then
            return false
        end
    end

    return true
end

--- Called when the behavior is started
function UseRoleChecker.OnStart(bot)
    if UseRoleChecker.HasRoleChecker(bot) then
        local inventory = bot:BotInventory()
        inventory:PauseAutoSwitch()
        bot._checkerPlaceStartedAt = CurTime()
        return STATUS.RUNNING
    end

    bot.isGoingToChecker = true

    local checker = UseRoleChecker.GetNearestChecker(bot)
    bot.targetChecker = checker
    local chatter = bot:BotChatter()
    if chatter and chatter.On then chatter:On("UsingRoleChecker") end
    return STATUS.RUNNING
end

--- Compute a placement position on the ground a short distance in front of the bot.
---@param bot Player
---@return Vector
function UseRoleChecker.GetPlacementLookPos(bot)
    local fwd = bot:GetForward()
    -- Point ~80 units ahead and 40 units below eye level so the trace hits the floor.
    local eyePos = bot:EyePos()
    return eyePos + fwd * 80 - Vector(0, 0, 40)
end

function UseRoleChecker.PlaceRoleChecker(bot)
    local locomotor = bot:BotLocomotor()

    -- Compute and cache a stable look-at position so we don't keep chasing a
    -- moving target as the bot's forward vector changes each frame.
    -- 🟡 8: Retry with a new target if the current one hasn't worked after PlaceRetryInterval
    if not bot._checkerPlaceTarget or
       (bot._checkerPlaceRetryAt and CurTime() > bot._checkerPlaceRetryAt) then
        bot._checkerPlaceTarget = UseRoleChecker.GetPlacementLookPos(bot)
        bot._checkerPlaceRetryAt = CurTime() + UseRoleChecker.PlaceRetryInterval
        bot._checkerPlaceAttempts = (bot._checkerPlaceAttempts or 0) + 1

        -- On retry attempts, vary the look position to find a valid placement surface:
        -- try looking more steeply downward, or slightly to the side
        if bot._checkerPlaceAttempts > 1 then
            local fwd = bot:GetForward()
            local eyePos = bot:EyePos()
            local attemptIdx = bot._checkerPlaceAttempts
            if attemptIdx == 2 then
                -- Look more steeply down
                bot._checkerPlaceTarget = eyePos + fwd * 60 - Vector(0, 0, 55)
            elseif attemptIdx == 3 then
                -- Look slightly to the right
                local right = bot:GetRight()
                bot._checkerPlaceTarget = eyePos + fwd * 70 + right * 30 - Vector(0, 0, 45)
            else
                -- Look directly at feet
                bot._checkerPlaceTarget = bot:GetPos() + Vector(0, 0, 5)
            end
        end
    end
    locomotor:LookAt(bot._checkerPlaceTarget, 2)

    -- IMPORTANT: Only call SelectWeapon if the bot isn't already holding the
    -- role checker. Calling SelectWeapon every tick resets the weapon's deploy
    -- animation, preventing PrimaryAttack from ever firing.
    local activeWep = bot:GetActiveWeapon()
    if not IsValid(activeWep) or activeWep:GetClass() ~= "weapon_ttt_traitorchecker" then
        bot:SelectWeapon("weapon_ttt_traitorchecker")
        bot._checkerEquipTime = CurTime()
        return -- Give one tick for the weapon to deploy before attacking.
    end

    -- 🟡 8: Wait a brief stabilization period after equipping before firing,
    -- so the aim direction has time to settle on the target
    if bot._checkerEquipTime and (CurTime() - bot._checkerEquipTime) < 0.3 then
        return
    end

    -- Pause the attack-compatibility rate limiter so the fire isn't suppressed
    -- on the one-out-of-N-ticks compat-skip frame.
    locomotor:PauseAttackCompat()
    locomotor:StartAttack()
end

--- Called when the behavior's last state is running
function UseRoleChecker.OnRunning(bot)

    -- Abort using role checker if the bot has an active attack target (self-defense)
    if bot.attackTarget ~= nil then
        return STATUS.FAILURE
    end

    if UseRoleChecker.HasRoleChecker(bot) then
        -- Safety: give up after PlaceTimeout seconds so we don't loop forever.
        if bot._checkerPlaceStartedAt and (CurTime() - bot._checkerPlaceStartedAt) > UseRoleChecker.PlaceTimeout then
            return STATUS.FAILURE
        end

        -- Detective (or whoever carries the weapon) places the checker on the ground.
        UseRoleChecker.PlaceRoleChecker(bot)
        -- Keep attacking until the weapon is consumed (placed successfully).
        -- The weapon entity is removed from inventory once placement succeeds,
        -- so we just keep running until HasRoleChecker becomes false.
        return STATUS.RUNNING
    end

    -- If the bot *had* the checker but no longer does, it was successfully placed.
    if bot._checkerPlaceStartedAt then
        -- Mark as deployed so we don't re-enter this behavior.
        local IC = TTTBots.InnocentCoordinator
        if IC then
            IC.DetectiveDeployedChecker = true
            -- Invalidate the tester position cache so the coordinator can
            -- immediately discover the newly placed entity and assign queue jobs.
            IC._cachedTesterPos = nil
            IC._testerCacheTime = 0
            -- Force strategy re-evaluation on next tick so TesterQueue activates
            IC.SelectedStrategy = nil
        end

        local locomotor = bot:BotLocomotor()
        locomotor:StopAttack()

        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("DeployedRoleChecker", {})
        end
        return STATUS.SUCCESS
    end

    if bot:GetBaseRole() == ROLE_DETECTIVE then
        return STATUS.FAILURE
    end

    if not UseRoleChecker.ValidateChecker(bot.targetChecker) then
        return STATUS.FAILURE
    end

    -- print("Walking to role checker")

    local checker = bot.targetChecker
    local locomotor = bot:BotLocomotor()
    locomotor:SetGoal(checker:GetPos())
    locomotor:PauseRepel()
    local distToChecker = bot:GetPos():Distance(checker:GetPos())

    if distToChecker < 200 then
        locomotor:LookAt(checker:GetPos())
    end
    if distToChecker < UseRoleChecker.UseRange then
        -- print("Using role checker")
        UseRoleChecker.UseChecker(bot, checker)
        TTTBots.Match.CheckedPlayers[bot] = TTTBots.Match.CheckedPlayers[bot] or {}
        local role = bot:GetSubRole()
        TTTBots.Match.CheckedPlayers[bot][role] = true

        -- Determine the tester result based on the bot's actual team
        local isInnocent = (bot:GetTeam() == TEAM_INNOCENT)
        local resultStr = isInnocent and "innocent" or "traitor"

        -- Fire the hook so the morality/suspicion system picks up the result
        hook.Run("TTTBots.UseRoleChecker.Result", bot, bot, resultStr)

        -- If innocent: update own suspicion, evidence, memory and dequeue from coordinator
        if isInnocent then
            -- Mark self as tested clean in own morality
            local morality = bot:BotMorality()
            if morality then
                morality:SetTestedClean(bot)
            end

            -- Confirm innocent in own evidence / trust network
            local evidence = bot:BotEvidence()
            if evidence then
                evidence:ConfirmInnocent(bot, "passed_role_tester_self")
            end

            -- Record a witness event in memory for LLM context
            local mem = bot:BotMemory()
            if mem then
                mem:AddWitnessEvent("tester", bot:Nick() .. " passed the role tester and is confirmed innocent")
            end

            -- Dequeue from the InnocentCoordinator tester queue
            local IC = TTTBots.InnocentCoordinator
            if IC then
                IC.DequeueBot(bot)
                -- Clear the bot's current IC job so it transitions to wander/groupup
                IC.ClearJobFor(bot)
            end

            -- Announce the result
            local chatter = bot:BotChatter()
            if chatter and chatter.On then
                chatter:On("DeclareInnocent", { player = bot:Nick() })
            end
        end

        return STATUS.SUCCESS
        end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state
function UseRoleChecker.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function UseRoleChecker.OnFailure(bot)
end

--- Called when the behavior ends
function UseRoleChecker.OnEnd(bot)
    bot.isGoingToChecker = nil
    bot.targetChecker = nil
    bot._checkerPlacedAt = nil
    bot._checkerPlaceStartedAt = nil
    bot._checkerPlaceTarget = nil
    bot._checkerPlaceRetryAt = nil
    bot._checkerPlaceAttempts = nil
    bot._checkerEquipTime = nil
    local locomotor = bot:BotLocomotor()
    local inventory = bot:BotInventory()
    inventory:ResumeAutoSwitch()
    locomotor:StopAttack()
    locomotor:ResumeAttackCompat()
    locomotor:ResumeRepel()
end
