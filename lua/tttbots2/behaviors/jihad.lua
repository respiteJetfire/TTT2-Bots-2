

---@class BJihad
TTTBots.Behaviors.Jihad = {}

local lib = TTTBots.Lib

---@class BJihad
local BehaviorJihad = TTTBots.Behaviors.Jihad
BehaviorJihad.Name = "Jihad"
BehaviorJihad.Description = "Equip and use a 'weapon_ttt_jihad_bomb' when 2+ players not on the same team are within a configurable radius."
BehaviorJihad.Interruptible = true

local STATUS = TTTBots.STATUS

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function BehaviorJihad.Validate(bot)
    -- Check if the bot has the 'ttt_item' in its inventory
    -- print("Jihad Validate")
    local differentTeams = 0
    local sameTeams = 0

    if not TTTBots.Lib.IsTTT2() then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not IsValid(bot) then return false end
    if not bot:Alive() then return false end

    local role = bot:GetSubRole()

    if not BehaviorJihad.HasJihadBomb(bot) then
        -- print("Jihad Validate, no weapon")
        return false
    end

    -- print("Jihad Validate, checking for players")

    -- Check if there are 2+ players not on the same team within the radius
    local radius = 500 -- Configurable radius
    local players = lib.FindCloseTargets(bot, radius, true)
    for _, player in ipairs(players) do
        if player:GetTeam() ~= bot:GetTeam() then
            differentTeams = differentTeams + 1
            if player:GetTeam() == TEAM_JESTER then
                return false
            end
        end
    end

    --- if there are 2+ players not on the same team within the radius
    if differentTeams < 4 and role ~= ROLE_DEFECTOR then
        return false
    elseif differentTeams < 1 and role == ROLE_DEFECTOR then
        return false
    end

    --chance to use jihad bomb, proportional to the number of different teams
    
    local chance = differentTeams * 2
    local negativeChance = sameTeams * 2
    for _, player in ipairs(players) do
        if player:GetTeam() == bot:GetTeam() then
            sameTeams = sameTeams + 1
        end
    end
    if role == ROLE_DEFECTOR then
        chance = chance * 3
    end
    local value = math.random(1, 100)
    -- print(value, chance, negativeChance)
    if value > (chance - negativeChance) then
        return STATUS.FAILURE
    end

    -- print("Jihad: Validated")

    return true
end

--- Start the behavior
---@param bot Bot
function BehaviorJihad.OnStart(bot)
    -- Equip the 'ttt_item'
    -- print("Jihad OnStart")
    local chatter = bot:BotChatter()
    chatter:On("JihadBombWarn", {}, true)
    return STATUS.RUNNING
end

--- Run the behavior
---@param bot Bot
---@return STATUS
function BehaviorJihad.OnRunning(bot)
    -- print("Jihad OnRunning")
    local inventory, loco = bot:BotInventory(), bot:BotLocomotor()
    local jihad = BehaviorJihad.GetJihadBomb(bot)
    local role = bot:GetSubRole()
    if not (inventory and loco) then return STATUS.FAILURE end
    
    inventory:PauseAutoSwitch()
    bot:SetActiveWeapon(jihad)
    loco:SetGoal() -- reset goal to stop moving
    loco:PauseAttackCompat()

    -- Calculate the midpoint between the players
    local midpoint = Vector(0, 0, 0)
    local count = 0

    for _, player in ipairs(players) do
        if player:GetTeam() ~= bot:GetTeam() then
            midpoint = midpoint + player:GetPos()
            count = count + 1
        end
    end

    midpoint = midpoint / count

    -- Move towards the midpoint
    local loco = bot:BotLocomotor()
    loco:SetGoal(midpoint)
    
    if not BehaviorJihad.HasJihadBomb(bot) then return STATUS.FAILURE end

    -- Trigger the attack
    loco:StartAttack()
    -- print("Jihad OnRunning, chance and value", chance, value)
    
    chatter:On("JihadBombUse", {})

    return STATUS.RUNNING
end

--- End the behavior
---@param bot Bot
function BehaviorJihad.OnEnd(bot)
    -- print("Jihad OnEnd")
    local inventory, loco = bot:BotInventory(), bot:BotLocomotor()
    if not (inventory and loco) then return end
    -- Reset any state if necessary
    inventory:ResumeAutoSwitch()
    loco:StopAttack()
    bot:SetAttackTarget(nil)
    loco:ResumeAttackCompat()
end

function BehaviorJihad.OnSuccess(bot)
    -- print("Jihad OnSuccess")
end

function BehaviorJihad.OnFailure(bot)
    -- print("Jihad OnFailure")
end

-- Function that checks if the bot has the 'ttt_item' in its inventory
---@param bot Bot
---@return boolean
function BehaviorJihad.HasJihadBomb(bot)
    return bot:HasWeapon('weapon_ttt_jihad_bomb')
end

---Function that gets the 'ttt_item' from the bot's inventory
---@param bot Bot
---@return Weapon?
function BehaviorJihad.GetJihadBomb(bot)
    return bot:GetWeapon('weapon_ttt_jihad_bomb')
end