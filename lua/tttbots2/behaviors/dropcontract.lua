--- This module is specific to the TTT2 Pirate Captain role.
if not (TTT2 and ROLE_PIRATE_CAPTAIN) then return end


--- This file defines the behavior for dropping a ttt_weapon_contract at the nearest non-allied player.

---@class BDropContract : BBase
TTTBots.Behaviors.DropContract = {}

local lib = TTTBots.Lib

---@class BDropContract
local BehaviorDropContract = TTTBots.Behaviors.DropContract
BehaviorDropContract.Name = "DropContract"
BehaviorDropContract.Description = "Drops a ttt_weapon_contract at the nearest non-allied player."
BehaviorDropContract.Interruptible = true

local STATUS = TTTBots.STATUS

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function BehaviorDropContract.Validate(bot)
    local state = TTTBots.Behaviors.GetState(bot, "DropContract")
    local target = state.target or BehaviorDropContract.GetTarget(bot)
    if not target then
        return false
    end
    if not IsValid(target) then
        return false
    end
    if not bot:Alive() then
        return false
    end
    local inventory = bot:BotInventory()
    local getContract = inventory:GetContract()
    local roleCheck = bot:GetSubRole() == ROLE_PIRATE_CAPTAIN
    if not roleCheck then
        return false
    end
    if not getContract and bot:GetTeam() ~= TEAM_PIRATE then
        return false
    end
    return target ~= nil
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function BehaviorDropContract.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "DropContract")
    local target = state.target or BehaviorDropContract.GetTarget(bot)
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("DroppingContract", {player = target:Nick()})
    end
    return STATUS.RUNNING
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function BehaviorDropContract.OnRunning(bot)

    if bot:GetTeam() ~= TEAM_PIRATE then
        -- print("Contract already dropped and picked up.")
        return STATUS.FAILURE
    end

    local target = BehaviorDropContract.GetTarget(bot)

    if not target then
        return STATUS.FAILURE
    end

    -- Check if the bot is still alive
    if not bot:Alive() then
        return STATUS.FAILURE
    end
    
    local targetPos = target:GetPos()
    local botPos = bot:GetPos()
    local loco = bot:BotLocomotor()
    local inv = bot:BotInventory()

    --- stop any allied Pirates from attacking the target, iterate through all living bots. Only do this if the attack target is the same as the contract target.
    for _, other in ipairs(TTTBots.Lib.GetAliveBots()) do
        if other:GetSubRole() == ROLE_PIRATE and other.attackTarget == target then
            other:SetAttackTarget(nil, "PIRATE_CONTRACT_DONE")
        end
    end


    if botPos:Distance(targetPos) <= 150 then
        inv:PauseAutoSwitch()
        local equipped = inv:EquipContract()
        if not equipped then return STATUS.RUNNING end
        local bodyPos = TTTBots.Behaviors.AttackTarget.GetTargetBodyPos(target)
        loco:LookAt(bodyPos)
        local eyeTrace = bot:GetEyeTrace()
        if eyeTrace and eyeTrace.Entity == target then
            loco:StartAttack()
        end
    else
        loco:StopAttack()
        inv:ResumeAutoSwitch()
        bot:BotLocomotor():SetGoal(targetPos)
    end
    if bot:GetTeam() ~= TEAM_PIRATE then
        local chatter = bot:BotChatter()
        if chatter and chatter.On then chatter:On("NewContract", {player = target:Nick()}) end
        return STATUS.SUCCESS
    end
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function BehaviorDropContract.OnSuccess(bot)
    BehaviorDropContract.ClearTarget(bot)
    local loco = bot:BotLocomotor()
    if not loco then return end
    loco:StopAttack()
    bot:SetAttackTarget(nil, "BEHAVIOR_END")
    timer.Simple(1, function()
        if not IsValid(bot) then return end
        local inv = bot:BotInventory()
        if not (inv) then return end
        inv:ResumeAutoSwitch()
    end)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function BehaviorDropContract.OnFailure(bot)
    BehaviorDropContract.ClearTarget(bot)
    local loco = bot:BotLocomotor()
    if not loco then return end
    loco:StopAttack()
    bot:SetAttackTarget(nil, "BEHAVIOR_END")
    timer.Simple(1, function()
        if not IsValid(bot) then return end
        local inv = bot:BotInventory()
        if not (inv) then return end
        inv:ResumeAutoSwitch()
    end)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function BehaviorDropContract.OnEnd(bot)
    BehaviorDropContract.ClearTarget(bot)
end

--- Get the nearest non-allied player to the bot.
---@param bot Bot
---@return Player
function BehaviorDropContract.GetTarget(bot)
    local state = TTTBots.Behaviors.GetState(bot, "DropContract")
    if state.target then
        return state.target
    end
    local players = TTTBots.Lib.GetAlivePlayers()
    local botPos = bot:GetPos()
    local nearestPlayer = nil
    local nearestDistance = math.huge

    local HumanAlive = TTTBots.Lib.GetHumanPlayers()
    local bestDist = math.huge

    
    for _, other in ipairs(HumanAlive) do
        if TTTBots.Roles.IsAllies(bot, other) == false and TTTBots.Lib.IsPlayer(other) and other:Alive() and other:GetTeam() ~= TEAM_PIRATE and other:GetTeam() ~= TEAM_NONE and other:Health() > 0 then
            local dist = botPos:Distance(other:GetPos())
            if dist < bestDist then
                bestDist = dist
                nearestPlayer = other
            end
        else
            nearestPlayer = nil
        end
    end

    -- If no HumanAlive players, find the nearest non-allied bot player
    -- Check if there are any HumanAlive players
    if not nearestPlayer then
        for _, ply in ipairs(players) do
            if ply ~= bot and TTTBots.Roles.IsAllies(bot, ply) == false and ply:Alive() and ply:GetSubRole() ~= ROLE_PIRATE and ply:GetTeam() ~= TEAM_NONE and ply:Health() > 0 then
                local distance = botPos:Distance(ply:GetPos())
                if distance < nearestDistance then
                    nearestDistance = distance
                    nearestPlayer = ply
                end
            end
        end
    end

    if not IsValid(nearestPlayer) then
        nearestPlayer = nil
    end
    state.target = nearestPlayer
    -- print("BehaviorDropContract target: ", nearestPlayer)
    return nearestPlayer
end

function BehaviorDropContract.ClearTarget(bot)
    TTTBots.Behaviors.ClearState(bot, "DropContract")
end

