
--- This module is specific to the TTT2 Cursed role.
if not (TTT2 and ROLE_CURSED) then return end

--- This file defines the behavior for walking up to a player and swapping roles with them.

---@class BSwapRole : BBase
TTTBots.Behaviors.SwapRole = {}

local lib = TTTBots.Lib

---@class BSwapRole
local SwapRole = TTTBots.Behaviors.SwapRole
SwapRole.Name = "SwapRole"
SwapRole.Description = "Swaps a role with the nearest non-allied player using the addon's API."
SwapRole.Interruptible = true

---@class Bot
---@field SwapRoleTarget Player?

local STATUS = TTTBots.STATUS

--- Compute an urgency value [0.1, 1.0] based on elapsed round time and living player count.
--- Higher urgency = the Cursed bot is more eager to swap.
---@param bot Bot
---@return number
local function GetCursedUrgency(bot)
    local alivePlayers = #TTTBots.Match.AlivePlayers
    local totalPlayers = #player.GetAll()
    local aliveRatio = 1 - (alivePlayers / math.max(totalPlayers, 1))

    local roundTime = TTTBots.Match.Time()
    local roundMinutesConVar = GetConVar("ttt_roundtime_minutes")
    local maxTime = (roundMinutesConVar and roundMinutesConVar:GetFloat() or 5) * 60
    local timeRatio = math.Clamp(roundTime / math.max(maxTime, 1), 0, 1)

    return math.Clamp(0.1 + (timeRatio * 0.5) + (aliveRatio * 0.4), 0.1, 1.0)
end

--- Should we start swapping this tick? Urgency scales the probability from ~5% (round start) up to ~50% (near end).
---@param bot Bot
---@return boolean
function SwapRole.ShouldStartSwapping(bot)
    local urgency = GetCursedUrgency(bot)
    local threshold = math.floor(urgency * 50)
    return TTTBots.Match.IsRoundActive() and (math.random(1, 100) <= threshold)
end

--- Validate the behavior before we can start it (or continue running).
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function SwapRole.Validate(bot)
    if not IsValid(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not lib.IsPlayerAlive(bot) then return false end
    if bot:GetSubRole() ~= ROLE_CURSED then return false end
    local target = SwapRole.GetTarget(bot)
    return target ~= nil or SwapRole.ShouldStartSwapping(bot)
end

--- Called when the behavior is started. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function SwapRole.OnStart(bot)
    local target = bot.SwapRoleTarget
    if target and IsValid(target) then
        local chatter = bot:BotChatter()
        if chatter then chatter:On("CursedChasing", {player = target:Nick()}) end
    end
    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function SwapRole.OnRunning(bot)
    local target = bot.SwapRoleTarget
    if not (target and IsValid(target) and lib.IsPlayerAlive(target)) then
        -- Attempt to find a fresh target before giving up.
        SwapRole.GetTarget(bot)
        target = bot.SwapRoleTarget
        if not (target and IsValid(target) and lib.IsPlayerAlive(target)) then
            return STATUS.FAILURE
        end
    end

    local targetPos = target:GetPos()
    local botPos = bot:GetPos()
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    local dist = botPos:Distance(targetPos)
    if dist <= 150 then
        local bodyPos = TTTBots.Behaviors.AttackTarget.GetTargetBodyPos(target)
        loco:LookAt(bodyPos)
        local eyeTrace = bot:GetEyeTrace()
        if eyeTrace and eyeTrace.Entity == target then
            SwapRole.DoSwap(bot, target)
            return STATUS.SUCCESS
        end
    else
        loco:SetGoal(targetPos)
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state.
---@param bot Bot
function SwapRole.OnSuccess(bot)
    local chatter = bot:BotChatter()
    if chatter then chatter:On("CursedSwapSuccess") end
end

--- Called when the behavior returns a failure state.
---@param bot Bot
function SwapRole.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup.
---@param bot Bot
function SwapRole.OnEnd(bot)
    bot.SwapRoleTarget = nil
    local loco = bot:BotLocomotor()
    if loco then loco:SetGoal(nil) end
end

--- Find and return the nearest valid swap target, respecting the addon's no-backsies and detective-protection rules.
--- Stores the result in bot.SwapRoleTarget and returns it.
---@param bot Bot
---@return Player?
function SwapRole.GetTarget(bot)
    local players = player.GetAll()
    local botPos = bot:GetPos()
    local nearestPlayer = nil
    local nearestDistance = math.huge

    -- Read the addon convar that controls whether Detectives can be tagged.
    local affectDetConVar = GetConVar("ttt2_cursed_affect_det")
    local affectDet = affectDetConVar == nil or affectDetConVar:GetBool()

    for _, ply in ipairs(players) do
        if ply == bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then continue end

        -- Respect the addon's native no-backsies flag.
        if ply.curs_last_tagged ~= nil then continue end

        -- Respect countercurse equipment item.
        if ply:HasEquipmentItem("item_ttt_countercurse_mantra") then continue end

        -- Defectors cannot be swapped into.
        if ROLE_DEFECTOR and ply:GetSubRole() == ROLE_DEFECTOR then continue end

        -- Respect detective-protection convar.
        if not affectDet then
            if ROLE_DETECTIVE and ply:GetBaseRole() == ROLE_DETECTIVE then continue end
        end

        local distance = botPos:Distance(ply:GetPos())
        if distance < nearestDistance then
            nearestDistance = distance
            nearestPlayer = ply
        end
    end

    bot.SwapRoleTarget = nearestPlayer
    return nearestPlayer
end

--- Perform the role swap using the addon's AttemptSwap API when available.
--- Falls back to a direct swap if the API is not present.
---@param bot Bot
---@param target Player
function SwapRole.DoSwap(bot, target)
    -- Use the addon's API (passing 0 for distance since proximity was already verified).
    if CURS_DATA and CURS_DATA.AttemptSwap then
        CURS_DATA.AttemptSwap(bot, target, 0)
        return
    end

    -- Fallback: perform a minimal manual swap when the addon API is unavailable.
    local botRole = bot:GetSubRole()
    local botTeam = bot:GetTeam()
    local targetRole = target:GetSubRole()
    local targetTeam = target:GetTeam()
    bot:UpdateTeam(targetTeam)
    bot:SetRole(targetRole)
    target:SetRole(botRole)
    target:UpdateTeam(botTeam)
    SendFullStateUpdate()
end