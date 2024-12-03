
--- This module is specific to the TTT2 Mimic role.
if not (TTT2 and ROLE_MIMIC) then return end

--- This file defines the behavior for walking up to a player and copying their role.

---@class BCopyRole : BBase
TTTBots.Behaviors.CopyRole = {}

local lib = TTTBots.Lib

---@class BCopyRole
local CopyRole = TTTBots.Behaviors.CopyRole
CopyRole.Name = "CopyRole"
CopyRole.Description = "Copies the role of the nearest non-allied player."
CopyRole.Interruptible = true

CopyRole.Target = nil

local STATUS = TTTBots.STATUS

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function CopyRole.Validate(bot)
    local role = bot:GetSubRole()
    if role ~= ROLE_MIMIC then
        return false
    end
    local target = CopyRole.GetTarget(bot)
    return target ~= nil or CopyRole.Target ~= nil
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CopyRole.OnStart(bot)
    local chatter = bot:BotChatter()
    chatter:On("CopyingRole", {player = CopyRole.Target:Nick()})
    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function CopyRole.OnRunning(bot)
    local target = CopyRole.GetTarget(bot)
    if not target then
        return STATUS.FAILURE
    end

    local targetPos = target:GetPos()
    local botPos = bot:GetPos()
    local loco = bot:BotLocomotor()


    if botPos:Distance(targetPos) <= 150 then
        local bodyPos = TTTBots.Behaviors.AttackTarget.GetTargetBodyPos(target)
        loco:LookAt(bodyPos)
        local eyeTrace = bot:GetEyeTrace()
        if eyeTrace and eyeTrace.Entity == target then
            CopyRole.CopyRole(bot, target)
        end
        return STATUS.SUCCESS
    else
        bot:BotLocomotor():SetGoal(targetPos)
        return STATUS.RUNNING
    end
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function CopyRole.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function CopyRole.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function CopyRole.OnEnd(bot)
    CopyRole.Target = nil
    bot:BotLocomotor():SetGoal(nil)
end

--- Get the nearest non-allied player to the bot.
---@param bot Bot
---@return Player
function CopyRole.GetTarget(bot)
    local players = player.GetAll()
    local botPos = bot:GetPos()
    local nearestPlayer = nil
    local nearestDistance = math.huge
    local highestPriority = 4
    local roleCount = {}
    local brokenRoles = {
        [ROLE_SLAVE] = true,
        [ROLE_DEPUTY] = true,
        [ROLE_SIDEKICK] = true,
    }
    --- code below to populate roleCount
    for _, ply in ipairs(players) do
        if ply ~= bot and not TTTBots.Roles.IsAllies(bot, ply) and TTTBots.Lib.IsPlayerAlive(ply) then
            local role = ply:GetRole()
            if not roleCount[role] then
                roleCount[role] = 1
            else
                roleCount[role] = roleCount[role] + 1
            end
        end
    end
    local lowestCount = math.huge
    local closestDistance = math.huge

    for _, ply in ipairs(players) do
        if ply ~= bot and not TTTBots.Roles.IsAllies(bot, ply) and TTTBots.Lib.IsPlayerAlive(ply) then
            local role = ply:GetRole()
            if brokenRoles[role] then continue end
            local roleCount = roleCount[role] or 0
            local distance = botPos:Distance(ply:GetPos())

            if roleCount < lowestCount or (roleCount == lowestCount and distance < closestDistance) then
                lowestCount = roleCount
                closestDistance = distance
                nearestPlayer = ply
            end
        end
    end
    CopyRole.Target = nearestPlayer
    return nearestPlayer
end

--- Copy the role of the target player to the bot.
---@param bot Bot
---@param target Player
function CopyRole.CopyRole(bot, target)
    local targetRole = target:GetSubRole()
    local targetTeam = target:GetTeam()
    local roleString = target:GetRoleStringRaw()
    target:ChatPrint("Your role has been copied by " .. bot:Nick())
    bot:UpdateTeam(targetTeam)
    bot:SetRole(targetRole)
    SendFullStateUpdate()
    print("Copied role: ", roleString, " from ", target:Nick())
end