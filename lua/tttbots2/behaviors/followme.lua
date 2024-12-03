
TTTBots.Behaviors.FollowMe = {}

local lib = TTTBots.Lib

local FollowMe = TTTBots.Behaviors.FollowMe
FollowMe.Name = "FollowMe"
FollowMe.Description = "FollowMe a player non-descreetly."
FollowMe.Interruptible = false

local STATUS = TTTBots.STATUS

--- Return if whether or not the bot is a follower per their personality. That is, if they are a traitor or have a following trait.
---@param bot Bot
---@return boolean
function FollowMe.IsFollowerPersonality(bot)
    local personality = bot:BotPersonality()
    if not personality then return false end

    local hasTrait = personality:GetTraitBool("follower") or personality:GetTraitBool("followerAlways")

    return hasTrait
end

--- Return if the bot is a follower role, like a traitor.
---@param bot any
function FollowMe.IsFollowerRole(bot)
    local role = TTTBots.Roles.GetRoleFor(bot) ---@type RoleData
    if not role then return false end

    return role:GetIsFollower()
end

--- Similar to IsFollower, but returns mathematical chance of deciding to follow a new person this tick.
function FollowMe.GetFollowChance(bot)
    local BASE_CHANCE = 0.8 -- X % chance per tick
    local debugging = false
    local chance = BASE_CHANCE * (FollowMe.IsFollowerPersonality(bot) and 2 or 1) * (FollowMe.IsFollowerRole(bot) and 2 or 1)

    local personality = bot:BotPersonality()
    if not personality then return chance end
    local alwaysFollows = personality:GetTraitBool("followerAlways")

    return (
        ((debugging or alwaysFollows) and 100) or -- if debugging return 100% always.
        chance                                    -- otherwise return the actual chance.
    )
end

function FollowMe.InitiateFollow(bot, player, teamOnly)
    local playerIsPolice = TTTBots.Roles.GetRoleFor(player):GetAppearsPolice()
    local roleDisablesSuspicion = not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion()
    local chatter = bot:BotChatter()
    local Morality = bot:BotMorality()
    local playerSus = Morality:GetSuspicion(player) or 0
    --- calculate chance of acceptance and time based on player's suspicion level (0% and 5 seconds at -10, 100% and 20 seconds at 10 but player can exceed both), or a base 50% if not using suspicion 
    --- if the player is a public role, the bot will always accept local targetIsPolice = TTTBots.Roles.GetRoleFor(target):GetAppearsPolice()
    local chance = 0.5
    local time = 5
    if playerIsPolice then
        chance = 1
        time = 15
    elseif roleDisablesSuspicion and bot:GetTeam() == player:GetTeam() then
        chance = 1
        time = 60
    elseif not roleDisablesSuspicion then
        local sus = math.Clamp(playerSus, -10, 10)
        chance = math.Clamp((10 - sus) / 20, 0, 1)
        time = math.Clamp((10 - sus) / 20 * 15 + 5, 5, 15)
    end
    if teamOnly and bot:GetTeam() ~= player:GetTeam() then
        print(bot:Nick() .. " ignores the team only request from " .. player:Nick())
        return
    end
    if math.random(0, 100) > chance * 100 then
        print(bot:Nick() .. " refused to follow " .. player:Nick())
        chatter:On("FollowMeRefuse", { target = player:Nick() }, teamOnly, math.random(1, 4))
        return
    end
    bot.followMeTarget = player
    print("Initiating follow for " .. bot:Nick() .. " to " .. player:Nick())
    bot.followEndTime = CurTime() + time
end

--- Get a random point in the list of CNavAreas
---@param navList table<CNavArea>
---@return Vector
function FollowMe.GetRandomPointInList(navList)
    local nav = table.Random(navList)
    local pos = nav:GetRandomPoint()
    return pos
end

--- Validate the behavior
function FollowMe.Validate(bot)
    if bot.followMeTarget and not IsValid(bot.followMeTarget) then
        -- print("FollowMe.Validate: bot.followMeTarget is invalid for " .. bot:Nick())
        bot.followMeTarget = nil
    end
    if not TTTBots.Match.IsRoundActive() then return false end
    -- if bot.followMeTarget then print("FollowMe.Validate: " .. bot:Nick() ..  "decided to follow.") return true end -- already following someone
    return bot.followMeTarget ~= nil and CurTime() < (bot.followEndTime or 0)
end

--- Called when the behavior is started
function FollowMe.OnStart(bot)
    if not bot.followMeTarget then
        ErrorNoHaltWithStack("FollowMe.OnStart: bot.followMeTarget is nil for " .. bot:Nick() .. "\n")
        return STATUS.FAILURE
    end -- IDK how this happens but it just does.
    local teamOnly
    if bot:GetTeam() == bot.followMeTarget:GetTeam() and bot:GetTeam() ~= TEAM_INNOCENT then
        teamOnly = true
    else
        teamOnly = false
    end
    bot.followEndTime = CurTime() + math.random(12, 24)
    print("FollowMe.OnStart: " .. bot:Nick() .. " following " .. bot.followMeTarget:Nick())

    local chatter = bot:BotChatter()
    chatter:On("FollowMe", { target = bot.followMeTarget:Nick() }, teamOnly, math.random(1, 4))

    return STATUS.RUNNING
end

function FollowMe.GetFollowPoint(target)
    return target:GetPos()
end

--- Called when the behavior's last state is running
function FollowMe.OnRunning(bot)
    local target = bot.followMeTarget

    if not IsValid(target) or not lib.IsPlayerAlive(target) then
        return STATUS.FAILURE
    end

    if CurTime() > (bot.followEndTime or 0) then
        return STATUS.FAILURE
    end

    -- if bot.botFollowPoint ~= nil and bot:GetPos():Distance(bot.botFollowPoint) < 100 then
    --     return STATUS.SUCCESS
    -- end

    local loco = bot:BotLocomotor()
    bot.botFollowPoint = FollowMe.GetFollowPoint(target)

    if bot.botFollowPoint == false then return STATUS.FAILURE end

    local distToPoint = bot:GetPos():Distance(bot.botFollowPoint)
    local finalTarget = (distToPoint < 250 and bot:GetPos()) or bot.botFollowPoint

    loco:SetGoal(finalTarget)
end

--- Called when the behavior returns a success state
function FollowMe.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function FollowMe.OnFailure(bot)
end

--- Called when the behavior ends
function FollowMe.OnEnd(bot)
    local chatter = bot:BotChatter()
    timer.Remove("TTTBots.FollowMe." .. bot:Nick())
    if bot:GetTeam() == bot.followMeTarget:GetTeam() and bot:GetTeam() ~= TEAM_INNOCENT then
        local teamOnly = true
    else
        local teamOnly = false
    end
    chatter:On("FollowMeEnd", { target = bot.followMeTarget:Nick() }, teamOnly, math.random(1, 4))
    bot.followMeTarget = nil
    bot.botFollowPoint = nil
    bot.followEndTime = nil
    bot:BotLocomotor():StopMoving()
end
