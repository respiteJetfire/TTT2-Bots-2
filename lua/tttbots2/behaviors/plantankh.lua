--- Plants an ankh in a strategic location. Does not do anything if the bot does not have an ankh weapon in its inventory.


TTTBots.Behaviors.PlantAnkh = {}

local lib = TTTBots.Lib

local PlantAnkh = TTTBots.Behaviors.PlantAnkh
PlantAnkh.Name = "PlantAnkh"
PlantAnkh.Description = "Plant an ankh in a strategic, hidden location"
PlantAnkh.Interruptible = true

PlantAnkh.PLANT_RANGE = 80 --- Distance to the site to which we can plant the ankh

local STATUS = TTTBots.STATUS

---@class Bot
---@field ankhFailCounter number The number of times the bot has failed to plant an ankh.
---@field ankhPlantSpot Vector|nil The strategic spot chosen for ankh placement.

function PlantAnkh.HasAnkh(bot)
    return bot:HasWeapon("weapon_ttt_ankh")
end

--- Find a strategic, hidden location for the ankh placement.
--- Prioritizes: seclusion, low visibility from common routes, cover from line of sight.
---@param bot Entity The bot placing the ankh
---@return Vector|nil The chosen position, or nil if none found
function PlantAnkh.FindStrategicSpot(bot)
    -- Try to use the hiding spots system first (secluded areas)
    local hidingSpots = TTTBots.Spots and TTTBots.Spots.GetSpotsInCategory and TTTBots.Spots.GetSpotsInCategory("hiding")
    local candidates = hidingSpots or {}

    -- Fallback: use navmesh hidden areas if spot system has no hiding spots
    if #candidates == 0 then
        local navAreas = navmesh.GetAllNavAreas()
        if navAreas then
            for _, area in ipairs(navAreas) do
                if area:IsUnderwater() then continue end
                local center = area:GetCenter()
                -- Prefer areas that are hidden attributes or small areas (corners/alcoves)
                if area:HasAttributes(NAV_MESH_NO_HOSTAGES) or area:GetSizeX() < 200 or area:GetSizeY() < 200 then
                    table.insert(candidates, center)
                end
                if #candidates > 100 then break end -- Limit search space
            end
        end
    end

    -- If still no candidates, use area around the bot with random offsets
    if #candidates == 0 then
        for i = 1, 10 do
            local offset = Vector(math.random(-500, 500), math.random(-500, 500), 0)
            local testPos = bot:GetPos() + offset
            local tr = util.TraceLine({
                start = testPos + Vector(0, 0, 50),
                endpos = testPos - Vector(0, 0, 100),
                mask = MASK_PLAYERSOLID_BRUSHONLY
            })
            if tr.Hit then
                table.insert(candidates, tr.HitPos + Vector(0, 0, 2))
            end
        end
    end

    -- Score each candidate
    local bestSpot = nil
    local bestScore = -math.huge

    for _, spot in pairs(candidates) do
        local score = 0

        -- Check if bot can reach this spot
        local distToBot = bot:GetPos():Distance(spot)
        if distToBot > 2500 then continue end -- Too far away
        if distToBot < 100 then continue end -- Too close to current position (not strategic)

        -- Reward moderate distance (not too close, not too far)
        if distToBot > 400 and distToBot < 1500 then
            score = score + 3
        elseif distToBot <= 400 then
            score = score + 1
        end

        -- Penalize for visible witnesses (other players who can see this spot)
        local witnesses = lib.GetAllVisible(spot, true, bot)
        score = score - (#witnesses * 3)

        -- Reward spots with cover (walls/obstacles nearby reduce line of sight)
        local coverCount = 0
        local directions = {Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0)}
        for _, dir in ipairs(directions) do
            local tr = util.TraceLine({
                start = spot + Vector(0, 0, 20),
                endpos = spot + Vector(0, 0, 20) + dir * 200,
                mask = MASK_SOLID_BRUSHONLY
            })
            if tr.Hit and tr.HitPos:Distance(spot) < 150 then
                coverCount = coverCount + 1
            end
        end
        score = score + coverCount * 1.5

        -- Reward distance from player traffic (avoid common paths)
        for _, ply in pairs(player.GetAll()) do
            if not lib.IsPlayerAlive(ply) then continue end
            if ply == bot then continue end
            local pDist = ply:GetPos():Distance(spot)
            if pDist < 300 then
                score = score - 2
            elseif pDist > 800 then
                score = score + 0.5
            end
        end

        -- Check ground flatness (required by ankh placement logic: dot product ≤ 0.2)
        local groundTr = util.TraceLine({
            start = spot + Vector(0, 0, 50),
            endpos = spot - Vector(0, 0, 100),
            mask = MASK_PLAYERSOLID_BRUSHONLY
        })
        if groundTr.Hit then
            local dot = groundTr.HitNormal:Dot(Vector(0, 0, 1))
            if dot < 0.8 then -- Ground not flat enough
                score = score - 10
            end
        end

        if score > bestScore then
            bestScore = score
            bestSpot = spot
        end
    end

    return bestSpot
end

--- Validate the behavior
function PlantAnkh.Validate(bot)
    local inRound = TTTBots.Match.IsRoundActive()
    local hasAnkh = PlantAnkh.HasAnkh(bot)
    --- check if there are any ttt_ankh entities on the map (if yes AND the bot is not the owner then return true, if no then return true, else return false)
    local ankh = ents.FindByClass("ttt_ankh")
    for _, ent in pairs(ankh) do
        if IsValid(ent) and ent:GetOwner() == bot then
            return false
        end
    end

    return inRound and hasAnkh
end

--- Called when the behavior is started
function PlantAnkh.OnStart(bot)
    local inventory = bot:BotInventory()
    inventory:PauseAutoSwitch()

    -- Find a strategic spot to place the ankh
    local strategicSpot = PlantAnkh.FindStrategicSpot(bot)
    bot.ankhPlantSpot = strategicSpot

    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function PlantAnkh.OnRunning(bot)
    local attempt = bot.ankhFailCounter or 0
    local locomotor = bot:BotLocomotor()

    if attempt > 5 then
        -- Find a new strategic spot
        bot.ankhPlantSpot = PlantAnkh.FindStrategicSpot(bot)
        bot.ankhFailCounter = 0
        return STATUS.RUNNING
    end

    -- Navigate to the chosen strategic spot
    local spot = bot.ankhPlantSpot or bot:GetPos()
    local distToSpot = bot:GetPos():Distance(spot)

    if distToSpot > PlantAnkh.PLANT_RANGE then
        locomotor:SetGoal(spot)
        return STATUS.RUNNING
    end

    -- Check for witnesses before planting
    local witnesses = lib.GetAllVisible(spot, true, bot)
    if #witnesses > 0 then
        -- Wait for witnesses to leave, but don't wait forever
        if not bot._ankhWaitStart then
            bot._ankhWaitStart = CurTime()
        end
        if CurTime() - bot._ankhWaitStart > 10 then
            -- Give up on this spot, find a new one
            bot.ankhPlantSpot = PlantAnkh.FindStrategicSpot(bot)
            bot._ankhWaitStart = nil
            bot.ankhFailCounter = (bot.ankhFailCounter or 0) + 1
        end
        return STATUS.RUNNING
    end

    bot._ankhWaitStart = nil

    -- We are safe to plant - look at the ground in front of us
    local ankh = PlantAnkh.GetAnkh(bot)
    if not IsValid(ankh) then return STATUS.FAILURE end
    bot:SetActiveWeapon(ankh)

    -- Look at a point slightly in front and below to trigger the ankh's trace
    local lookTarget = bot:GetPos() + bot:GetForward() * 50 - Vector(0, 0, 40)
    locomotor:LookAt(lookTarget)
    locomotor:StartAttack()

    ankh = PlantAnkh.GetAnkh(bot)
    if not ankh then return STATUS.SUCCESS end
    bot.ankhFailCounter = attempt + 1

    return STATUS.RUNNING -- This behavior depends on the validation call ending it.
end

--- Called when the behavior returns a success state
function PlantAnkh.OnSuccess(bot)
    local chatter = bot:BotChatter()
    if chatter and chatter.On then chatter:On("PlacedAnkh") end
end

--- Called when the behavior returns a failure state
function PlantAnkh.OnFailure(bot)
end

--- Called when the behavior ends
function PlantAnkh.OnEnd(bot)
    bot.ankhPlantSpot = nil
    bot._ankhWaitStart = nil
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

-- Decrement the 'ankh fail' counter on each bot once per 20 seconds to prevent infinite retry loops.
timer.Create("TTTBots.Behavior.PlantAnkh.PreventInfinitePlants", 20, 0, function()
    for _, bot in pairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot ~= NULL and bot.components) then continue end
        bot.ankhFailCounter = math.max(bot.ankhFailCounter or 0, 0) - 1
    end
end)
