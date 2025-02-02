TTTBots.Behaviors.ChatterHelp = {}

local lib = TTTBots.Lib

local ChatterHelp = TTTBots.Behaviors.ChatterHelp
ChatterHelp.Name = "ChatterHelp"
ChatterHelp.Description = "Bots use the Chatter system to ask for help under various circumstances."
ChatterHelp.Interruptible = true
ChatterHelp.AskStatus = nil
ChatterHelp.target = nil

local STATUS = TTTBots.STATUS

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function ChatterHelp.Validate(bot)
    if not bot:Alive() then return false end
    local usesSuspicion = TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion()
    local Morality = bot:BotMorality()
    if ChatterHelp.target == nil or not IsValid(ChatterHelp.target) then return false end
    local aliveBots = TTTBots.Lib.GetAliveBots()
    local humanPlayers = TTTBots.Lib.GetHumanPlayers()
    if not table.HasValue(aliveBots, ChatterHelp.target) and not table.HasValue(humanPlayers, ChatterHelp.target) then
        return false
    end
    local playerSus = Morality:GetSuspicion(ChatterHelp.target) or 0
    -- a) Ask an attacker to stop shooting if they have taken damage
    if ChatterHelp.AskStatus == "AskCeaseFire" then
        local target = ChatterHelp.target
        if target and math.random(1, 50) > 47 then
            return true
        end
    end

    -- b) Ask someone to follow if they think they are trustworthy or want to lure a player to their death
    if usesSuspicion and playerSus < -5 then
        local target = TTTBots.Lib.GetClosestPlayer(bot)
        if target and math.random(1, 100) > 95 then
            ChatterHelp.AskStatus = "AskFollow"
            return true
        end
    end

    -- c) Ask a trusted teammate or a target to come here
    if usesSuspicion and playerSus < -5 then
        local target = TTTBots.Lib.GetClosestPlayer(bot)
        if target and math.random(1, 100) > 95 then
            ChatterHelp.AskStatus = "AskComeHere"
            return true
        end
    end

    -- d) Ask to be healed if on low health
    if bot:Health() < bot:GetMaxHealth() / 2 then
        local target = TTTBots.Lib.GetClosestPlayer(bot)
        if target and math.random(1, 100) > 95 then
            ChatterHelp.AskStatus = "AskHeal"
            return true
        end
    end

    -- e) Ask everyone or a nearby teammate to attack a target if they are very suspicious, or are an attackTarget
    if usesSuspicion and playerSus > 5 then
        local target = TTTBots.Lib.GetClosestPlayer(bot)
        if target and math.random(1, 100) > 95 then
            ChatterHelp.AskStatus = "AskAttack"
            return true
        end
    end
    return false
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function ChatterHelp.OnStart(bot)
    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function ChatterHelp.OnRunning(bot)
    local chatter = bot:BotChatter()
    local Morality = bot:BotMorality()
    local personality = bot:BotPersonality()
    local usesSuspicion = TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion()
    local playerSus = Morality:GetSuspicion(bot) or 0
    local target = ChatterHelp.target
    local teamOnly = bot:GetTeam() ~= TEAM_INNOCENT and target:GetTeam() == bot:GetTeam()

    if ChatterHelp.AskStatus == "AskCeaseFire" then
        chatter:On("AskCeaseFire", { player = target:Nick() }, teamOnly, 0)
    elseif ChatterHelp.AskStatus == "AskFollow" then
        chatter:On("AskFollow", { player = target:Nick() }, teamOnly, 0)
    elseif ChatterHelp.AskStatus == "AskComeHere" then
        chatter:On("AskComeHere", { player = target:Nick() }, teamOnly, 0)
    elseif ChatterHelp.AskStatus == "AskHeal" then
        chatter:On("AskHeal", { player = target:Nick() }, teamOnly, 0)
    elseif ChatterHelp.AskStatus == "AskAttack" then
        chatter:On("AskAttack", { player = target:Nick() }, teamOnly, 0)
    end

    return STATUS.SUCCESS
end

--- Called when the behavior is interrupted. Useful for cleaning up any variables that were set during OnStart.
---@param bot Bot
function ChatterHelp.OnEnd(bot)
    ChatterHelp.AskStatus = nil
    ChatterHelp.target = nil
end

--- Called when the behavior is successfully completed. Useful for any cleanup that needs to be done.
---@param bot Bot
function ChatterHelp.OnSuccess(bot)
end

--- Called when the behavior fails to complete. Useful for any cleanup that needs to be done.
---@param bot Bot
function ChatterHelp.OnFailure(bot)
end

--- Hook PlayerHurt called when a player takes damage, for functions that need to be called when a player is hurt.
hook.Add("PlayerHurt", "TTTBots_PlayerHurt", function(victim, attacker, healthRemaining, damageTaken)
    if not victim:IsBot() then return end

    local bot = victim
    local target = attacker

    if not IsValid(target) or not IsValid(bot) then return end
    ChatterHelp.AskStatus = "AskCeaseFire"
    ChatterHelp.target = target
end)