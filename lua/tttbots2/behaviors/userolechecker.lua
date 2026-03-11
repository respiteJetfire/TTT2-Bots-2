
TTTBots.Behaviors.UseRoleChecker = {}

local lib = TTTBots.Lib

local UseRoleChecker = TTTBots.Behaviors.UseRoleChecker
UseRoleChecker.Name = "Use Role Tester / Checker"
UseRoleChecker.Description = "Use or place a Role Checker to determine the role of a player."
UseRoleChecker.Interruptible = false
UseRoleChecker.UseRange = 100 --- The range at which we can use a health checker

UseRoleChecker.TargetClass = "ttt_traitorchecker"

--- Maximum time (seconds) the detective will spend trying to place before giving up.
UseRoleChecker.PlaceTimeout = 8

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
    -- print("bot is using checker")
    checker:Use(bot)
end

--- Validate the behavior
function UseRoleChecker.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.attackTarget ~= nil then return false end             --- We are preoccupied with an attacker.

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

    -- Innocent / None bots have a small random chance to walk to a nearby checker
    if not bot.isGoingToChecker then
        local chance = (bot:GetTeam() == TEAM_NONE or bot:GetTeam() == TEAM_INNOCENT) and 5 or 1
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
    -- Aim at a point on the ground ahead of the bot so the weapon's placement trace succeeds.
    local placePos = UseRoleChecker.GetPlacementLookPos(bot)
    locomotor:LookAt(placePos, 2)
    bot:SelectWeapon("weapon_ttt_traitorchecker")
    locomotor:StartAttack()
end

--- Called when the behavior's last state is running
function UseRoleChecker.OnRunning(bot)

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
        if IC then IC.DetectiveDeployedChecker = true end

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
        -- print("Checked player " .. bot:Nick() .. " as " .. role)
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
    local locomotor = bot:BotLocomotor()
    local inventory = bot:BotInventory()
    inventory:ResumeAutoSwitch()
    locomotor:StopAttack()
    locomotor:ResumeRepel()
end
