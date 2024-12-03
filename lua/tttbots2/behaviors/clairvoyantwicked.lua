---@class BClairvoyantWicked
TTTBots.Behaviors.ClairvoyantWicked = {}

local lib = TTTBots.Lib

---@class BClairvoyantWicked
local ClairvoyantWicked = TTTBots.Behaviors.ClairvoyantWicked
ClairvoyantWicked.Name = "ClairvoyantWicked"
ClairvoyantWicked.Description = "Reveals the role of a random eligible player."
ClairvoyantWicked.Interruptible = true

local STATUS = TTTBots.STATUS

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function ClairvoyantWicked.Validate(bot)
    -- print("ClairvoyantWicked.Validate")
    if not IsValid(bot) then return false end
    local role = bot:GetSubRole()
    -- print("ClairvoyantWicked.Validate", bot:Nick(), role)
    if not(role == ROLE_WICKED or role == ROLE_CLAIRVOYANT) then
        -- print("ClairvoyantWicked.Validate", bot:Nick(), "is not a clairvoyant or wicked.")
        return false
    end
    if bot:Health() <= 0 then
        -- print("ClairvoyantWicked.Validate", bot:Nick(), "is dead.")
        return false
    end
    if not bot.roleRevealCooldown then
        bot.roleRevealCooldown = 0
    end
    if CurTime() < bot.roleRevealCooldown then
        -- print("Clairvoyant.Validate", bot:Nick(), "is on cooldown.")
        return false
    end
    bot.roleTarget = ClairvoyantWicked.GetRoleTarget(bot)
    -- print("ClairvoyantWicked.Validate", bot.roleTarget)
    return bot.roleTarget ~= nil
end

--- Validate the target before we can reveal their role
---@param bot Bot
---@param target Player
---@return boolean
function ClairvoyantWicked.ValidateTarget(bot, target)
    if not IsValid(target) then return false end
    if target == bot then return false end
    if target:IsSpec() then return false end
    if not target:Alive() then return false end
    if target:GetSubRole() == ROLE_INNOCENT or target:GetBaseRole() == ROLE_DETECTIVE or target:GetSubRole() == ROLE_TRAITOR then return false end
    if bot:GetTeam() == target:GetTeam() and bot:GetSubRole() == ROLE_WICKED then return false end
    return true
end

--- Get the target for the role reveal
---@param bot Bot
---@return Player
function ClairvoyantWicked.GetRoleTarget(bot)
    local players = player.GetAll()
    local eligiblePlayers = {}

    -- Filter players based on their roles
    for _, ply in ipairs(players) do
        if ClairvoyantWicked.ValidateTarget(bot, ply) then
            table.insert(eligiblePlayers, ply)
        end
    end

    -- If no eligible players are found, do nothing
    if #eligiblePlayers == 0 then return nil end

    -- Select a random eligible player
    return eligiblePlayers[math.random(#eligiblePlayers)]
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function ClairvoyantWicked.OnStart(bot)
    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function ClairvoyantWicked.OnRunning(bot)
    local target = bot.roleTarget
    if not target then return STATUS.FAILURE end
    local targetName = target:Nick()
    local chatter = bot:BotChatter()
    chatter:On("ClairvoyantReveal", {name = targetName})
    bot.roleRevealCooldown = CurTime() + math.random(15, 60)
    return STATUS.SUCCESS
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function ClairvoyantWicked.OnSuccess(bot)
    -- print(bot:Nick() .. " has revealed a role.")
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function ClairvoyantWicked.OnFailure(bot)
    bot.roleRevealCooldown = nil
    -- print(bot:Nick() .. " failed to reveal a role.")
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function ClairvoyantWicked.OnEnd(bot)
    bot.roleTarget = nil
end