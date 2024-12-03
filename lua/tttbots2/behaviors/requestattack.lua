--- This file is a base behavior meta file. It is not used in code, and is merely present for Intellisense and prototyping.
---@meta

---@class BRequestAttack : BBase
TTTBots.Behaviors.RequestAttack = {}

local lib = TTTBots.Lib

---@class BRequestAttack : BBase
local BehaviorRequestAttack = TTTBots.Behaviors.RequestAttack
BehaviorRequestAttack.Name = "RequestAttack"
BehaviorRequestAttack.Description = "Request the bot to attack a target if the player has a suspicion of 5 or more, or if the player is on the same team"
BehaviorRequestAttack.Interruptible = true

local STATUS = TTTBots.STATUS

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function BehaviorRequestAttack.Validate(bot)
    return bot.attackTarget ~= nil
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function BehaviorRequestAttack.OnStart(bot)
    print(bot:Nick() .. " is now attacking.")
    local chatter = bot:BotChatter()
    chatter:On("AttackStart", { target = bot.attackTarget:Nick() }, false, math.random(1, 4))
    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function BehaviorRequestAttack.OnRunning(bot)
    if not bot.attackTarget or not bot.attackTarget:IsAlive() then
        print(bot:Nick() .. " has finished attacking.")
        return STATUS.SUCCESS
    end
    local loco = bot:BotLocomotor()
    loco:SetGoal(bot.attackTarget:GetPos()) -- set goal to target's position
    loco:ResumeAttackCompat()
    loco:ResumeRepel()
    return STATUS.RUNNING
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function BehaviorRequestAttack.OnSuccess(bot)
    print(bot:Nick() .. " has finished attacking.")
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function BehaviorRequestAttack.OnFailure(bot)
    print(bot:Nick() .. " failed to attack.")
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function BehaviorRequestAttack.OnEnd(bot)
    bot.attackTarget = nil
    local loco = bot:BotLocomotor()
    loco:PauseAttackCompat()
    loco:SetHalt(false)
    loco:PauseRepel()
    local chatter = bot:BotChatter()
    chatter:On("AttackEnd", { target = bot.attackRequester:Nick() }, false, math.random(1, 4))
    bot.attackRequester = nil
end

--- Request the bot to attack a target if the player has a suspicion of 5 or more, or if the player is on the same team
---@param bot Bot
---@param player Player
---@param target Player
function BehaviorRequestAttack.RequestAttack(bot, player, target, teamOnly)
    local playerIsPolice = TTTBots.Roles.GetRoleFor(player):GetAppearsPolice() or player:GetBaseRole() == ROLE_DETECTIVE
    local roleDisablesSuspicion = not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion()
    local chatter = bot:BotChatter()
    local Morality = bot:BotMorality()
    local playerSus = Morality:GetSuspicion(player) or 0
    local targetSus = Morality:GetSuspicion(target) or 0
    local playerTeam = TTTBots.Roles.GetRoleFor(player):GetTeam()
    local targetTeam = TTTBots.Roles.GetRoleFor(target):GetTeam()
    local botTeam = TTTBots.Roles.GetRoleFor(bot):GetTeam()
    local sameTeam = TTTBots.Roles.GetRoleFor(player):GetTeam() == TTTBots.Roles.GetRoleFor(bot):GetTeam()
    local sameTeamTarget = TTTBots.Roles.GetRoleFor(bot):GetTeam() == TTTBots.Roles.GetRoleFor(target):GetTeam()
    local susCheck = playerSus < -4 and not roleDisablesSuspicion and targetSus > 0
    local policeCheck = playerIsPolice
    local sameTeamCheck = sameTeam and not sameTeamTarget and roleDisablesSuspicion
    local targetAlive = target and target:Alive()

    if not targetAlive then return end
    if teamOnly and not sameTeam then return end
    if susCheck then
        bot:SetAttackTarget(target)
        print(bot:Nick() .. " is now attacking " .. target:Nick() .. " as requested by " .. player:Nick())
        chatter:On("AttackStart", { target = target:Nick() }, teamOnly, math.random(1, 4))
    elseif policeCheck and not sameTeamTarget then
        bot:SetAttackTarget(target)
        print(bot:Nick() .. " is now attacking " .. target:Nick() .. " as requested by " .. player:Nick())
        chatter:On("AttackStart", { target = target:Nick() }, teamOnly, math.random(1, 4))
    elseif (sameTeam and not sameTeamTarget) and roleDisablesSuspicion then
        bot:SetAttackTarget(target)
        print(bot:Nick() .. " is now attacking " .. target:Nick() .. " as requested by " .. player:Nick())
        chatter:On("AttackStart", { target = target:Nick() }, teamOnly, math.random(1, 4))
    elseif policeCheck and sameTeamTarget and bot:GetTeam() == TEAM_INNOCENT then
        bot:SetAttackTarget(target)
        print(bot:Nick() .. " is now attacking " .. target:Nick() .. " as requested by " .. player:Nick())
        chatter:On("AttackStart", { target = target:Nick() }, teamOnly, math.random(1, 4))
    else
        print(bot:Nick() .. " refused to attack " .. target:Nick() .. " as requested by " .. player:Nick())
        chatter:On("AttackRefuse", { target = target:Nick() }, teamOnly, math.random(1, 4))
    end
end
