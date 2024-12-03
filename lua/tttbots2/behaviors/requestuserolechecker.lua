
TTTBots.Behaviors.RequestUseRoleChecker = {}

local lib = TTTBots.Lib

local RequestUseRoleChecker = TTTBots.Behaviors.RequestUseRoleChecker
RequestUseRoleChecker.Name = "Request Use Role Tester / Checker"
RequestUseRoleChecker.Description = "a Bot is requested to use the RoleChecker, this behaviour handles this case."
RequestUseRoleChecker.Interruptible = true
RequestUseRoleChecker.UseRange = 100 --- The range at which we can use a health checker

RequestUseRoleChecker.TargetClass = "ttt_traitorchecker"

local STATUS = TTTBots.STATUS


function RequestUseRoleChecker.ValidateChecker(hs)
    local isvalid = (
        IsValid(hs)
        and hs:GetClass() == RequestUseRoleChecker.TargetClass
    )
    return isvalid
end

function RequestUseRoleChecker.GetNearestChecker(bot)
    local checkers = ents.FindByClass(RequestUseRoleChecker.TargetClass)
    local validCheckers = {}
    for i, v in pairs(checkers) do
        if not RequestUseRoleChecker.ValidateChecker(v) then
            continue
        end
        table.insert(validCheckers, v)
    end

    local nearestChecker = lib.GetClosest(validCheckers, bot:GetPos())
    return nearestChecker
end

function RequestUseRoleChecker.UseChecker(bot, checker)
    -- print("bot is using checker")
    checker:Use(bot)
end

--- Validate the behavior
function RequestUseRoleChecker.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.attackTarget ~= nil then return false end

    local isCheckerNearby = (bot.targetChecker or RequestUseRoleChecker.GetNearestChecker(bot) ~= nil)
    -- print("Bot: " .. bot:Nick() .. " validate: " .. tostring(isCheckerNearby) .. " " .. tostring(bot.RequestRoleCheckAccepted))

    if TTTBots.Match.CheckedPlayers[bot] and TTTBots.Match.CheckedPlayers[bot][role] then
        -- print("Bot: " .. bot:Nick() .. " has already been checked")
        -- print("RequestUseRoleChecker.Validate: Already checked player")
        return false
    end
    -- print("RequestUseRoleChecker.Validate: " .. tostring(isCheckerNearby), tostring(bot.RequestRoleCheckAccepted))
    return isCheckerNearby and bot.RequestRoleCheckAccepted
end

--- Called when the behavior is started
function RequestUseRoleChecker.OnStart(bot)
    -- if TTTBots.Match.CheckedPlayers[bot] then
    --     return STATUS.SUCCESS
    -- end
    local checker = RequestUseRoleChecker.GetNearestChecker(bot)
    bot.targetChecker = checker
    local chatter = bot:BotChatter()
    chatter:On("UsingRoleChecker")
    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function RequestUseRoleChecker.OnRunning(bot)

    if bot:GetBaseRole() == ROLE_DETECTIVE then
        return STATUS.FAILURE
    end

    if not RequestUseRoleChecker.ValidateChecker(bot.targetChecker) then
        return STATUS.FAILURE
    end

    print("Walking to role checker")

    local checker = bot.targetChecker
    local locomotor = bot:BotLocomotor()
    locomotor:SetGoal(checker:GetPos())
    locomotor:PauseRepel()
    local distToChecker = bot:GetPos():Distance(checker:GetPos())

    if distToChecker < 200 then
        locomotor:LookAt(checker:GetPos())
    end
    if distToChecker < RequestUseRoleChecker.UseRange then
        -- print("Using role checker")
        RequestUseRoleChecker.UseChecker(bot, checker)
        TTTBots.Match.CheckedPlayers[bot] = TTTBots.Match.CheckedPlayers[bot] or {}
        local role = bot:GetSubRole()
        TTTBots.Match.CheckedPlayers[bot][role] = true
        -- print("Checked player " .. bot:Nick() .. " as " .. role)
        return STATUS.SUCCESS
        end

    return STATUS.RUNNING
end

function RequestUseRoleChecker.HandleRequest(bot, player)
    --- function to handle the request to use the role checker, the bot will use the role checker under the following circumstances:
    --- 1. The player asking them to use the role checker is a detective and the bot is on the Innocent or None Team
    --- 2. The player asking them to use the role checker is not a detective has a suspicion rating of 5 or more and the bot is on the Innocent or None Team
    --- 3. There are only spies and traitors left in the game

    local playerRole = player:GetBaseRole()
    local botRole = bot:GetBaseRole()
    local botTeam = bot:GetTeam()
    local chatter = bot:BotChatter()
    local Morality = bot:BotMorality()
    local playerSus = Morality:GetSuspicion(player) or 0
    local botSus = Morality:GetSuspicion(bot) or 0

    local playerIsDetective = playerRole == ROLE_DETECTIVE
    local botIsInnocent = botTeam == TEAM_INNOCENT
    local botIsNone = botTeam == TEAM_NONE

    if playerIsDetective and (botIsInnocent or botIsNone) then
        bot.RequestRoleCheckAccepted = true
        print(bot:Nick() .. " is now using the role checker as requested by " .. player:Nick())
        chatter:On("RoleCheckerRequestAccepted", { target = player:Nick() })
        return
    elseif not playerIsDetective and (botIsInnocent or botIsNone) then
        bot.RequestRoleCheckAccepted = true
        print(bot:Nick() .. " is now using the role checker as requested by " .. player:Nick())
        chatter:On("RoleCheckerRequestAccepted", { target = player:Nick() })
        return
    elseif not (botIsInnocent or botIsNone) then
        --- 3 things will happen here:
        --- 1. If the bot has a sus rating below -5, they will attack the player who requested them
        --- 2. If the bot has a sus rating between -5 and 5, they will ignore the request
        --- 3. If the bot has a sus rating above 5, there is a 50% chance they will use the role checker

        if botSus < 5 then
            bot.RequestRoleCheckAccepted = false
            bot.attackTarget = player
            print(bot:Nick() .. " is now attacking " .. player:Nick() .. " as requested by " .. player:Nick())
            return
        elseif botSus >= -5 and botSus <= 5 then
            bot.RequestRoleCheckAccepted = false
            print(bot:Nick() .. " refused to use the role checker as requested by " .. player:Nick())
            return
        elseif botSus > 5 then
            local chance = 0.5
            if math.random(0, 100) > chance * 100 then
                bot.RequestRoleCheckAccepted = true
                chatter:On("RoleCheckerRequestAccepted", { player = player:Nick() })
                return
            end
        end
    end
end
        
--- Called when the behavior returns a success state
function RequestUseRoleChecker.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function RequestUseRoleChecker.OnFailure(bot)
    TTTBots.Match.CheckedPlayers[bot] = nil
end

--- Called when the behavior ends
function RequestUseRoleChecker.OnEnd(bot)
    bot.RequestRoleCheckAccepted = false
    bot.targetChecker = nil
    local locomotor = bot:BotLocomotor()
    local inventory = bot:BotInventory()
    inventory:ResumeAutoSwitch()
    locomotor:StopAttack()
    locomotor:ResumeRepel()
end
