
---@class BCeaseFire : BBase
TTTBots.Behaviors.RequestCeaseFire = {}

local lib = TTTBots.Lib

---@class BCeaseFire : BBase
local BehaviorCeaseFire = TTTBots.Behaviors.RequestCeaseFire
BehaviorCeaseFire.Name = "RequestCeaseFire"
BehaviorCeaseFire.Description = "Cease fire on request"
BehaviorCeaseFire.Interruptible = true

local STATUS = TTTBots.STATUS

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function BehaviorCeaseFire.Validate(bot)
    return bot.ceaseFire
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function BehaviorCeaseFire.OnStart(bot)
    print(bot:Nick() .. " is now ceasing fire.")
    -- Don't drop a high-priority attack target (KOS'd enemy, self-defense, etc.)
    -- just because someone asked for ceasefire.
    local pri = bot.attackTargetPriority or 0
    if pri >= (TTTBots.Morality and TTTBots.Morality.PRIORITY and TTTBots.Morality.PRIORITY.SUSPICION_THRESHOLD or 2) then
        bot.ceaseFire = false
        return STATUS.FAILURE
    end
    if bot.attackTarget then
        bot:SetAttackTarget(nil, "CEASEFIRE")
        bot.attackTarget = nil
    end
    local chatter = bot:BotChatter()
    local teamOnly = (bot:GetTeam() == bot.ceaseFireRequester:GetTeam() and bot:GetTeam() ~= TEAM_INNOCENT) or false
    chatter:On("CeaseFireStart", { player = bot.ceaseFireRequester:Nick() }, teamOnly, math.random(1, 4))
    return STATUS.SUCCESS
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function BehaviorCeaseFire.OnSuccess(bot)
    print(bot:Nick() .. " has ceased fire.")
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function BehaviorCeaseFire.OnFailure(bot)
    print(bot:Nick() .. " failed to cease fire.")
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function BehaviorCeaseFire.OnEnd(bot)
    bot.ceaseFire = false
end

--- Request the bot to cease fire
---@param bot Bot
---@param player Player
function BehaviorCeaseFire.HandleRequest(bot, player, teamOnly)
    local playerIsPolice = TTTBots.Roles.GetRoleFor(player):GetAppearsPolice()
    local roleDisablesSuspicion = not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion()
    local chatter = bot:BotChatter()
    local Morality = bot:BotMorality()
    local playerSus = Morality:GetSuspicion(player) or 0

    -- Reject ceasefire from KOS'd players — a KOS'd traitor should not be able
    -- to tell everyone to stop fighting.
    local kosList = TTTBots.Match.KOSList
    if kosList and kosList[player] and not table.IsEmpty(kosList[player]) then
        print(bot:Nick() .. " refused ceasefire from KOS'd player " .. player:Nick())
        if chatter and chatter.On then chatter:On("CeaseFireRefuse", { player = player:Nick() }, teamOnly, math.random(1, 4)) end
        return
    end

    -- Reject ceasefire from highly suspicious players
    if not roleDisablesSuspicion and playerSus >= (Morality.Thresholds and Morality.Thresholds.KOS or 7) then
        print(bot:Nick() .. " refused ceasefire from suspicious player " .. player:Nick())
        if chatter and chatter.On then chatter:On("CeaseFireRefuse", { player = player:Nick() }, teamOnly, math.random(1, 4)) end
        return
    end

    local chance = 0.5
    if playerIsPolice and bot:GetTeam() == TEAM_INNOCENT then
        chance = 1
    elseif not roleDisablesSuspicion then
        local sus = math.Clamp(playerSus, -10, 10)
        chance = math.Clamp((10 - sus) / 20, 0, 1)
    end
    if teamOnly and bot:GetTeam() ~= player:GetTeam() then
        print(bot:Nick() .. " refused to cease fire for " .. player:Nick())
        return
    end
    -- FIX: math.random() returns 0-1 float, compare directly against chance (also 0-1)
    if math.random() > chance then
        print(bot:Nick() .. " refused to cease fire for " .. player:Nick())
        if chatter and chatter.On then chatter:On("CeaseFireRefuse", { player = player:Nick() }, teamOnly, math.random(1, 4)) end
        return
    end
    bot.ceaseFire = true
    bot.ceaseFireRequester = player
    print(bot:Nick() .. " is now ceasing fire as requested by " .. player:Nick())
end
