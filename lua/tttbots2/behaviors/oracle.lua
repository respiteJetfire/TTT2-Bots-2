---@class BOracle
TTTBots.Behaviors.Oracle = {}

local lib = TTTBots.Lib

---@class BOracle
local Oracle = TTTBots.Behaviors.Oracle
Oracle.Name = "Oracle"
Oracle.Description = "Reveals the role of 1 player or the other player."
Oracle.Interruptible = true

local STATUS = TTTBots.STATUS

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function Oracle.Validate(bot)
    -- print("Oracle.Validate")
    if not IsValid(bot) then return false end
    local role = bot:GetSubRole()
    -- print("Oracle.Validate", bot:Nick(), role)
    if role ~= ROLE_ORACLE then
        -- print("Oracle.Validate", bot:Nick(), "is not a oracle")
        return false
    end
    if bot:Health() <= 0 then
        -- print("Oracle.Validate", bot:Nick(), "is dead.")
        return false
    end
    if not bot.roleRevealCooldown then
        bot.roleRevealCooldown = 0
    end
    if CurTime() < bot.roleRevealCooldown then
        -- print("Oracle.Validate", bot:Nick(), "is on cooldown.")
        return false
    end
    bot.roleTarget1, bot.roleTarget2 = Oracle.GetRoleTarget(bot)
    -- print("Oracle.Validate", bot.roleTarget1, bot.roleTarget2)
    return (bot.roleTarget1 ~= nil and bot.roleTarget2 ~= nil)
end

--- Validate the target before we can reveal their role
---@param bot Bot
---@param target Player
---@return boolean
function Oracle.ValidateTarget(bot, target)
    if not IsValid(target) then return false end
    if target == bot then return false end
    if target:IsSpec() then return false end
    return true
end

--- Get the target for the role reveal
---@param bot Bot
---@return Player
function Oracle.GetRoleTarget(bot)
    local players = player.GetAll()
    local eligiblePlayers = {}

    -- Filter players based on their roles
    for _, ply in ipairs(players) do
        if Oracle.ValidateTarget(bot, ply) then
            table.insert(eligiblePlayers, ply)
        end
    end

    -- If no eligible players are found, do nothing
    if #eligiblePlayers < 2 then return nil end

    -- Select 2 random eligible players
    local target = table.Random(eligiblePlayers)
    local target2 = table.Random(eligiblePlayers)
    while target == target2 do
        target2 = table.Random(eligiblePlayers)
    end
    return target, target2
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function Oracle.OnStart(bot)
    -- print(bot:Nick() .. " is revealing a role.")
    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function Oracle.OnRunning(bot)
    local target1 = bot.roleTarget1
    local target2 = bot.roleTarget2
    if not target1 or not target2 then return STATUS.FAILURE end
    -- print("Oracle.OnRunning")
    local team
    if math.random(1, 2) == 1 then
        team = target1:GetTeam()
    else
        team = target2:GetTeam()
    end

    ---sanitise the team name
    local teamString = team.GetName and team:GetName() or tostring(team)
    teamString = teamString:lower():gsub("^team_", "")
    local chatter = bot:BotChatter()
    chatter:On("OracleReveal", {name1 = target1:Nick(), name2 = target2:Nick(), team = teamString})
    -- print("Oracle.OnStart revealed", target1:Nick(), target2:Nick(), "are on team", teamString)
    bot.roleRevealCooldown = CurTime() + math.random(20, 35)
    -- print("Oracle.OnRunning", bot.roleRevealCooldown)
    return STATUS.SUCCESS
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function Oracle.OnSuccess(bot)
    -- print(bot:Nick() .. " has revealed a role.")
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function Oracle.OnFailure(bot)
    bot.roleRevealCooldown = nil
    -- print(bot:Nick() .. " failed to reveal a role.")
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function Oracle.OnEnd(bot)
end