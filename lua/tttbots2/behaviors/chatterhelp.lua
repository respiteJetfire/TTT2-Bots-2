TTTBots.Behaviors.ChatterHelp = {}

local lib = TTTBots.Lib

local ChatterHelp = TTTBots.Behaviors.ChatterHelp
ChatterHelp.Name = "ChatterHelp"
ChatterHelp.Description = "Bots use the Chatter system to ask for help under various circumstances."
ChatterHelp.Interruptible = true

local STATUS = TTTBots.STATUS

function ChatterHelp.ValidateTarget(bot, target)
    if target == nil or not IsValid(target) then return false end
    local aliveBots = TTTBots.Lib.GetAliveBots()
    local humanPlayers = TTTBots.Lib.GetHumanPlayers()
    if not table.HasValue(aliveBots, target) and not table.HasValue(humanPlayers, target) then
        return false
    end
    return true
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function ChatterHelp.Validate(bot)
    if not bot:Alive() then return false end
    local usesSuspicion = TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion()
    local Morality = bot:BotMorality()
    local state = TTTBots.Behaviors.GetState(bot, "ChatterHelp")

    local playerSus = Morality:GetSuspicion(state.target) or 0

    -- b) Ask someone to follow if they think they are trustworthy or want to lure a player to their death
    if usesSuspicion and playerSus < -5 then
        local target = TTTBots.Lib.GetClosestPlayer(bot)
        if target and math.random(1, 100) > 95 then
            if not ChatterHelp.ValidateTarget(bot, target) then return false end
            state.target = target
            state.askStatus = "AskFollow"
            return true
        end
    end

    -- c) Ask a trusted teammate or a target to come here
    if usesSuspicion and playerSus < -5 then
        local target = TTTBots.Lib.GetClosestPlayer(bot)
        if target and math.random(1, 100) > 96 then
            if not ChatterHelp.ValidateTarget(bot, target) then return false end
            state.target = target
            state.askStatus = "AskComeHere"
            return true
        end
    end

    -- d) Ask to be healed if on low health
    if bot:Health() < bot:GetMaxHealth() / 2 then
        local target = TTTBots.Lib.GetClosestPlayer(bot)
        if target and math.random(1, 100) > 95 then
            if not ChatterHelp.ValidateTarget(bot, target) then return false end
            state.target = target
            state.askStatus = "AskHeal"
            return true
        end
    end

    -- e) Ask everyone or a nearby teammate to attack a target if they are very suspicious, or are an attackTarget
    if usesSuspicion and playerSus > 5 then
        local target = TTTBots.Lib.GetClosestPlayer(bot)
        if target and math.random(1, 100) > 95 then
            if not ChatterHelp.ValidateTarget(bot, target) then return false end
            state.target = target
            state.askStatus = "AskAttack"
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
    if not chatter or not chatter.On then return STATUS.SUCCESS end
    local Morality = bot:BotMorality()
    local personality = bot:BotPersonality()
    local usesSuspicion = TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion()
    local playerSus = Morality:GetSuspicion(bot) or 0
    local state = TTTBots.Behaviors.GetState(bot, "ChatterHelp")
    local target = state.target
    local teamOnly = bot:GetTeam() ~= TEAM_INNOCENT and target:GetTeam() == bot:GetTeam()

    if state.askStatus == "AskFollow" then
        print("Asking " .. target:Nick() .. " to follow.")
        chatter:On("AskFollow", { player = target:Nick() }, teamOnly, 0)
        print("Asked " .. target:Nick() .. " to follow.")
    elseif state.askStatus == "AskComeHere" then
        print("Asking " .. target:Nick() .. " to come here.")
        chatter:On("AskComeHere", { player = target:Nick() }, teamOnly, 0)
    elseif state.askStatus == "AskHeal" then
        print("Asking " .. target:Nick() .. " to heal.")
        chatter:On("AskHeal", { player = target:Nick() }, teamOnly, 0)
    elseif state.askStatus == "AskAttack" then
        print("Asking " .. target:Nick() .. " to attack.")
        chatter:On("AskAttack", { player = target:Nick() }, teamOnly, 0)
    end

    return STATUS.SUCCESS
end

--- Called when the behavior is interrupted. Useful for cleaning up any variables that were set during OnStart.
---@param bot Bot
function ChatterHelp.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "ChatterHelp")
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
    if not target:IsPlayer() then return end

    if healthRemaining <= 75 and IsValid(target) and target:IsPlayer() and math.random(1, 100) > 60 then
        local chatter = bot:BotChatter()
        print("Asking " .. target:Nick() .. " to cease fire.")
        if chatter and chatter.On then chatter:On("AskCeaseFire", { player = target:Nick() }, false, 0) end
    end
end)