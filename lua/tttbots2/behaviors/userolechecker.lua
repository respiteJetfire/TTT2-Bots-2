
TTTBots.Behaviors.UseRoleChecker = {}

local lib = TTTBots.Lib

local UseRoleChecker = TTTBots.Behaviors.UseRoleChecker
UseRoleChecker.Name = "Use Role Tester / Checker"
UseRoleChecker.Description = "Use or place a Role Checker to determine the role of a player."
UseRoleChecker.Interruptible = false
UseRoleChecker.UseRange = 100 --- The range at which we can use a health checker

UseRoleChecker.TargetClass = "ttt_traitorchecker"

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

    local chance = (bot:GetTeam() == TEAM_NONE or bot:GetTeam() == TEAM_INNOCENT) and 5 or 1
    if not bot.isGoingToChecker then
        if math.random(0, 200) > chance then
            -- print("UseRoleChecker.Validate: Random chance failed")
            return false
        ---else if distance to nearest checker is less than 100
        end
    end

    local hasRoleChecker = UseRoleChecker.HasRoleChecker(bot)
    local isCheckerNearby = (bot.targetChecker or UseRoleChecker.GetNearestChecker(bot) ~= nil)

    if TTTBots.Match.CheckedPlayers[bot] and TTTBots.Match.CheckedPlayers[bot][role] then
        -- print("UseRoleChecker.Validate: Already checked player")
        return false
    end

    return hasRoleChecker or isCheckerNearby
end

--- Called when the behavior is started
function UseRoleChecker.OnStart(bot)
    if UseRoleChecker.HasRoleChecker(bot) then
        local inventory = bot:BotInventory()
        inventory:PauseAutoSwitch()
        return STATUS.RUNNING
    end

    bot.isGoingToChecker = true

    -- if TTTBots.Match.CheckedPlayers[bot] then
    --     return STATUS.SUCCESS
    -- end

    local checker = UseRoleChecker.GetNearestChecker(bot)
    bot.targetChecker = checker
    local chatter = bot:BotChatter()
    chatter:On("UsingRoleChecker")
    return STATUS.RUNNING
end

function UseRoleChecker.PlaceRoleChecker(bot)
    local locomotor = bot:BotLocomotor()
    bot:SelectWeapon("weapon_ttt_traitorchecker")
    locomotor:StartAttack()
end

--- Called when the behavior's last state is running
function UseRoleChecker.OnRunning(bot)

    if UseRoleChecker.HasRoleChecker(bot) then
        UseRoleChecker.PlaceRoleChecker(bot)
        return STATUS.RUNNING
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
    local locomotor = bot:BotLocomotor()
    local inventory = bot:BotInventory()
    inventory:ResumeAutoSwitch()
    locomotor:StopAttack()
    locomotor:ResumeRepel()
end
