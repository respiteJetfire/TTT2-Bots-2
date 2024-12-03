
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
    if bot.attackTarget then
        bot:SetAttackTarget(nil)
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
    local chance = 0.5
    if playerIsPolice and bot:GetTeam() == TEAM_INNOCENT then
        chance = 1
    elseif not roleDisablesSuspicion then
        local sus = math.Clamp(playerSus, -10, 10)
        chance = math.Clamp((10 - sus) / 20, 0, 1)
    end
    if teamOnly and not bot:GetTeam() == player:GetTeam() then
        print(bot:Nick() .. " refused to cease fire for " .. player:Nick())
        return
    end
    if math.random() > chance * 100 then
        print(bot:Nick() .. " refused to cease fire for " .. player:Nick())
        chatter:On("CeaseFireRefuse", { player = player:Nick() }, teamOnly, math.random(1, 4))
        return
    end
    bot.ceaseFire = true
    bot.ceaseFireRequester = player
    print(bot:Nick() .. " is now ceasing fire as requested by " .. player:Nick())
end
