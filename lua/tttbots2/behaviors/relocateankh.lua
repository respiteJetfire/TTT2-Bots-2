--- RelocateAnkh: Pharaoh bot picks up their ankh and moves it to a new location
--- when the current spot has been compromised (enemies have found it, or it's
--- taken significant damage). Requires the ttt_ankh_pharaoh_pickup ConVar to be enabled.

TTTBots.Behaviors.RelocateAnkh = {}

local lib = TTTBots.Lib

local RelocateAnkh = TTTBots.Behaviors.RelocateAnkh
RelocateAnkh.Name = "RelocateAnkh"
RelocateAnkh.Description = "Pick up and relocate a compromised ankh to a safer spot"
RelocateAnkh.Interruptible = true

local STATUS = TTTBots.STATUS

--- Minimum time between relocation attempts
RelocateAnkh.COOLDOWN = 60
--- Health percentage threshold — if ankh has taken this much damage, consider relocating
RelocateAnkh.DAMAGE_THRESHOLD = 0.7
--- If this many enemies were spotted near the ankh recently, relocate
RelocateAnkh.THREAT_MEMORY_TIME = 30

--- Get the bot's own placed ankh entity
---@param bot Entity
---@return Entity|nil
function RelocateAnkh.GetOwnAnkh(bot)
    local ankhs = ents.FindByClass("ttt_ankh")
    for _, ankh in pairs(ankhs) do
        if IsValid(ankh) and ankh:GetOwner() == bot then
            return ankh
        end
    end
    return nil
end

--- Check if the ankh location has been compromised
---@param bot Entity
---@param ankh Entity
---@return boolean
function RelocateAnkh.IsLocationCompromised(bot, ankh)
    if not IsValid(ankh) then return false end

    -- Check if ankh has taken significant damage
    local maxHP = GetConVar("ttt_ankh_health"):GetInt()
    if ankh:Health() < maxHP * RelocateAnkh.DAMAGE_THRESHOLD then
        return true
    end

    -- Check if the ankh was recently under threat (conversion attempted)
    if bot.ankhUnderThreat then
        return true
    end

    -- Check if enemies have been spotted near the ankh recently
    if bot._ankhThreatsNearby and (CurTime() - (bot._ankhThreatsNearbyTime or 0)) < RelocateAnkh.THREAT_MEMORY_TIME then
        return true
    end

    return false
end

--- Validate the behavior
function RelocateAnkh.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.attackTarget ~= nil then return false end

    -- Only Pharaohs (and Graverobbers if their ConVar allows)
    local role = bot:GetSubRole()
    if role == ROLE_PHARAOH then
        if not GetConVar("ttt_ankh_pharaoh_pickup"):GetBool() then return false end
    elseif role == ROLE_GRAVEROBBER then
        if not GetConVar("ttt_ankh_graverobber_pickup"):GetBool() then return false end
    else
        return false
    end

    -- Must control an ankh
    if not PHARAOH_HANDLER:PlayerControlsAnAnkh(bot) then return false end

    local ankh = RelocateAnkh.GetOwnAnkh(bot)
    if not IsValid(ankh) then return false end

    -- Cooldown
    if (bot._lastRelocateAnkhEnd or 0) + RelocateAnkh.COOLDOWN > CurTime() then
        return false
    end

    -- Only relocate if location is compromised
    return RelocateAnkh.IsLocationCompromised(bot, ankh)
end

--- Called when the behavior is started
function RelocateAnkh.OnStart(bot)
    bot._relocatePhase = "pickup" -- phases: pickup, navigate, place
    bot._relocateNewSpot = nil
    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function RelocateAnkh.OnRunning(bot)
    if bot.attackTarget ~= nil then return STATUS.FAILURE end

    local locomotor = bot:BotLocomotor()

    if bot._relocatePhase == "pickup" then
        local ankh = RelocateAnkh.GetOwnAnkh(bot)
        if not IsValid(ankh) then return STATUS.FAILURE end

        local dist = bot:GetPos():Distance(ankh:GetPos())
        if dist > 80 then
            locomotor:SetGoal(ankh:GetPos())
            return STATUS.RUNNING
        end

        -- We're close enough — simulate USE to pick up the ankh
        -- The ankh entity's USE handler checks CanPickUpAnkh and handles pickup
        if PHARAOH_HANDLER:CanPickUpAnkh(ankh, bot) then
            -- Simulate the pickup by using the ankh entity
            ankh:Use(bot, bot, USE_ON, 0)

            -- Check if we now have the weapon (ankh was picked up)
            if bot:HasWeapon("weapon_ttt_ankh") then
                bot._relocatePhase = "navigate"
                -- Find a new strategic spot using PlantAnkh's logic if available
                if TTTBots.Behaviors.PlantAnkh and TTTBots.Behaviors.PlantAnkh.FindStrategicSpot then
                    bot._relocateNewSpot = TTTBots.Behaviors.PlantAnkh.FindStrategicSpot(bot)
                end
                if not bot._relocateNewSpot then
                    -- Fallback: just move away from current location
                    local angle = math.random(0, 360)
                    local offset = Vector(math.cos(math.rad(angle)) * 500, math.sin(math.rad(angle)) * 500, 0)
                    bot._relocateNewSpot = bot:GetPos() + offset
                end
            else
                -- Pickup failed — might need more USE time
                return STATUS.RUNNING
            end
        else
            return STATUS.FAILURE -- Can't pick up
        end
    end

    if bot._relocatePhase == "navigate" then
        if not bot._relocateNewSpot then return STATUS.FAILURE end

        local dist = bot:GetPos():Distance(bot._relocateNewSpot)
        if dist > 80 then
            locomotor:SetGoal(bot._relocateNewSpot)
            return STATUS.RUNNING
        end

        -- Arrived at new spot — place the ankh
        bot._relocatePhase = "place"
    end

    if bot._relocatePhase == "place" then
        -- PlantAnkh behavior will handle actual placement next tick
        -- Just switch weapon and trigger placement
        local ankhWep = bot:GetWeapon("weapon_ttt_ankh")
        if IsValid(ankhWep) then
            bot:SelectWeapon("weapon_ttt_ankh")
            locomotor:LookAt(bot:GetPos() + bot:GetForward() * 100 + Vector(0, 0, -50))
            timer.Simple(0.5, function()
                if not IsValid(bot) then return end
                bot:ConCommand("+attack")
                timer.Simple(0.1, function()
                    if not IsValid(bot) then return end
                    bot:ConCommand("-attack")
                end)
            end)
            return STATUS.SUCCESS
        else
            return STATUS.FAILURE
        end
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state
function RelocateAnkh.OnSuccess(bot)
    bot._lastRelocateAnkhEnd = CurTime()
end

--- Called when the behavior returns a failure state
function RelocateAnkh.OnFailure(bot)
    bot._lastRelocateAnkhEnd = CurTime()
end

--- Called when the behavior ends
function RelocateAnkh.OnEnd(bot)
    bot._relocatePhase = nil
    bot._relocateNewSpot = nil
end
