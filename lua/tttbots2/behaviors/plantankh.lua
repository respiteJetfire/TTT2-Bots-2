--- Plants a ankh in a safe location. Does not do anything if the bot does not have C4 in its inventory.


TTTBots.Behaviors.PlantAnkh = {}

local lib = TTTBots.Lib

local PlantAnkh = TTTBots.Behaviors.PlantAnkh
PlantAnkh.Name = "PlantAnkh"
PlantAnkh.Description = "Plant a ankh in a safe location"
PlantAnkh.Interruptible = true

PlantAnkh.PLANT_RANGE = 80 --- Distance to the site to which we can plant the ankh

local STATUS = TTTBots.STATUS

---@class Bot
---@field ankhFailCounter number The number of times the bot has failed to plant a ankh.

function PlantAnkh.HasAnkh(bot)
    return bot:HasWeapon("weapon_ttt_ankh")
end

--- Validate the behavior
function PlantAnkh.Validate(bot)
    local inRound = TTTBots.Match.IsRoundActive()
    local hasAnkh = PlantAnkh.HasAnkh(bot)
    return inRound and hasAnkh
end

--- Called when the behavior is started
function PlantAnkh.OnStart(bot)
    local inventory = bot:BotInventory()
    inventory:PauseAutoSwitch()
    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function PlantAnkh.OnRunning(bot)
    local attempt = bot.ankhFailCounter or 0
    local spot = bot:GetPos()
    bot.ankhPlantSpot = spot
    local locomotor = bot:BotLocomotor()

    if attempt > 5 then
        -- Move to a random nearby position and try again
        local randomOffset = Vector(math.random(-100, 100), math.random(-100, 100), 0)
        locomotor:SetGoal(spot + randomOffset)
        bot.ankhFailCounter = 0
        return STATUS.RUNNING
    end

    -- We are safe to plant.
    local ankh = PlantAnkh.GetAnkh(bot)
    if not IsValid(ankh) then return STATUS.FAILURE end
    bot:SetActiveWeapon(ankh)
    locomotor:LookAt(spot)
    locomotor:StartAttack()
    print("Bot " .. bot:Nick() .. " is planting an ankh at " .. tostring(spot))
    ankh = PlantAnkh.GetAnkh(bot)
    if not ankh then return STATUS.SUCCESS end
    bot.ankhFailCounter = attempt + 1

    return STATUS.RUNNING -- This behavior depends on the validation call ending it.
end

--- Called when the behavior returns a success state
function PlantAnkh.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function PlantAnkh.OnFailure(bot)
end

--- Called when the behavior ends
function PlantAnkh.OnEnd(bot)
    bot.ankhPlantSpot = nil
    local locomotor = bot:BotLocomotor()
    local inventory = bot:BotInventory()
    inventory:ResumeAutoSwitch()
    locomotor:StopAttack()
end

function PlantAnkh.GetAnkh(bot)
    local inventory = bot:BotInventory()
    if not inventory then return end
    inventory:PauseAutoSwitch()
    local wep = bot:GetWeapon("weapon_ttt_ankh")
    if IsValid(wep) then return wep end
    return wep
end

-- This part of the code is referencing preevnting a bot trying to plant indefinitely (and thus failing)
-- Specifically, we decrement the 'ankh fail' counter on each bot once per 20 seconds as to not break the behavior.
timer.Create("TTTBots.Behavior.PlantAnkh.PreventInfinitePlants", 20, 0, function()
    for _, bot in pairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot ~= NULL and bot.components) then continue end
        bot.ankhFailCounter = math.max(bot.ankhFailCounter or 0, 0) - 1
    end
end)
