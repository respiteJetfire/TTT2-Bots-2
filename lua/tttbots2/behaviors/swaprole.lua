
--- This module is specific to the TTT2 Cursed role.
if not (TTT2 and ROLE_CURSED) then return end

--- This file defines the behavior for walking up to a player and copying their role.

---@class BSwapRole : BBase
TTTBots.Behaviors.SwapRole = {}

local lib = TTTBots.Lib
local cursedPlayers = {}

---@class BSwapRole
local SwapRole = TTTBots.Behaviors.SwapRole
SwapRole.Name = "SwapRole"
SwapRole.Description = "Swaps a role with the nearest non-allied player."
SwapRole.Interruptible = true
SwapRole.Target = nil

local STATUS = TTTBots.STATUS

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function SwapRole.Validate(bot)
    local role = bot:GetSubRole()
    if role ~= ROLE_CURSED then
        return false
    end
    local target = SwapRole.GetTarget(bot)
    return target ~= nil or SwapRole.Target ~= nil
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function SwapRole.OnStart(bot)
    local chatter = bot:BotChatter()
    chatter:On("SwappingRole", {player = SwapRole.Target:Nick()})
    timer.Simple(1, function()
        return STATUS.RUNNING
    end)
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function SwapRole.OnRunning(bot)
    if not cursedPlayers[bot] then
        cursedPlayers[bot] = true
    end
    local target = SwapRole.GetTarget(bot)
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
            SwapRole.SwapRole(bot, target)
            cursedPlayers[target] = true
            timer.Simple(10, function()
                cursedPlayers[bot] = nil
            end)
        end
        return STATUS.SUCCESS
    else
        bot:BotLocomotor():SetGoal(targetPos)
        return STATUS.RUNNING
    end
end


--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function SwapRole.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function SwapRole.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function SwapRole.OnEnd(bot)
    SwapRole.Target = nil
    bot:BotLocomotor():SetGoal(nil)
end

--- Get the nearest non-allied player to the bot.
---@param bot Bot
---@return Player
function SwapRole.GetTarget(bot)
    local players = player.GetAll()
    local botPos = bot:GetPos()
    local nearestPlayer = nil
    local nearestDistance = math.huge

    for _, ply in ipairs(players) do
        if ply ~= bot and not TTTBots.Roles.IsAllies(bot, ply) and not cursedPlayers[ply] and TTTBots.Lib.IsPlayerAlive(ply) and not ply:HasEquipmentItem('item_ttt_countercurse_mantra') and ply:GetSubRole() ~= ROLE_DEFECTOR then
            -- print("Found a player with no role preference")
            local distance = botPos:Distance(ply:GetPos())
            if distance < nearestDistance then
                nearestDistance = distance
                nearestPlayer = ply
            end
        end
    end

    SwapRole.Target = nearestPlayer

    return nearestPlayer
end

--- Copy the role of the target player to the bot.
---@param bot Bot
---@param target Player
function SwapRole.SwapRole(bot, target)
    local botRole = bot:GetSubRole()
    local botTeam = bot:GetTeam()
    local targetRole = target:GetSubRole()
    local targetTeam = target:GetTeam()
    local roleString = target:GetRoleStringRaw()
    target:ChatPrint("Your role has been stolen by " .. bot:Nick())
    target:PrintMessage(HUD_PRINTTALK, "Your role has been stolen by " .. bot:Nick())
    bot:UpdateTeam(targetTeam)
    bot:SetRole(targetRole)
    SendFullStateUpdate()
    target:SetRole(botRole)
    target:UpdateTeam(botTeam)
    SendFullStateUpdate()
    print("Stolen role: ", roleString, " from ", target:Nick())
end