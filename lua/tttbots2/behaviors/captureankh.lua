TTTBots.Behaviors.CaptureAnkh = {}

local lib = TTTBots.Lib

local CaptureAnkh = TTTBots.Behaviors.CaptureAnkh
CaptureAnkh.Name = "Capture Ankh"
CaptureAnkh.Description = "Look for and use an ankh"
CaptureAnkh.Interruptible = true
CaptureAnkh.UseRange = 50 --- The range at which we can use an ankh

CaptureAnkh.TargetClass = "ttt_ankh"

local STATUS = TTTBots.STATUS

--- Validate that an ankh entity is a real placed ankh on the map
function CaptureAnkh.ValidateAnkh(ankh)
    return IsValid(ankh) and ankh:GetClass() == CaptureAnkh.TargetClass
end

function CaptureAnkh.GetNearestAnkh(bot)
    local ankhs = ents.FindByClass(CaptureAnkh.TargetClass)
    local validAnkhs = {}
    for i, v in pairs(ankhs) do
        if not CaptureAnkh.ValidateAnkh(v) then
            continue
        end
        table.insert(validAnkhs, v)
    end

    local nearestAnkh = lib.GetClosest(validAnkhs, bot:GetPos())
    if nearestAnkh then
        bot.targetAnkh = nearestAnkh
        bot.lastSeenAnkhPos = nearestAnkh:GetPos() -- Remember the position of the ankh
    elseif bot.lastSeenAnkhPos then
        -- If no valid ankh is found, use the last seen position
        bot.targetAnkh = bot.lastSeenAnkhPos
    end
    return nearestAnkh
end

--- Begin converting an ankh, respecting the ttt_ankh_conversion_time ConVar.
--- Uses the ankh entity's built-in Use() logic by simulating continuous USE input.
function CaptureAnkh.UseAnkh(bot, ankh)
    if bot._ankhConvertingEnt == ankh then return STATUS.RUNNING end -- Already converting

    bot._ankhConvertingEnt = ankh
    bot._ankhConvertStart = CurTime()

    local conversionTime = GetConVar("ttt_ankh_conversion_time"):GetInt()

    -- NOTE: We do NOT set ankh.last_activator because the entity's ENT:Think()
    -- checks KeyDown(IN_USE) and trace-hit on the ankh — both will fail for bots
    -- and would immediately cancel the conversion. Instead we:
    --   (a) Set ankh._tttbots_converter for the suspicion timer to identify who's converting
    --   (b) Manually update the conversion_progress NWInt so DefendAnkh can detect it
    ankh._tttbots_converter = bot

    -- Simulate the continuous USE input that the ankh entity expects
    PHARAOH_HANDLER:StartConversion(ankh, bot)

    -- Set up a repeating timer to simulate continuous USE ticks and complete after full conversion time
    local timerName = "TTTBots.CaptureAnkh.Convert." .. bot:EntIndex()
    timer.Create(timerName, 0.5, conversionTime * 2, function()
        if not IsValid(bot) or not lib.IsPlayerAlive(bot) then
            if IsValid(ankh) then
                ankh._tttbots_converter = nil
                ankh:SetNWInt("conversion_progress", 0)
            end
            timer.Remove(timerName)
            return
        end
        if not IsValid(ankh) then
            bot._ankhConvertingEnt = nil
            bot._ankhConvertStart = nil
            timer.Remove(timerName)
            return
        end

        -- Manually update conversion_progress NWInt so DefendAnkh.IsAnkhUnderThreat detects it
        local elapsed = CurTime() - bot._ankhConvertStart
        local progress = math.Round(elapsed / conversionTime * 100, 0)
        ankh:SetNWInt("conversion_progress", math.Clamp(progress, 0, 100))

        -- Check distance — if the bot moved too far away, cancel
        if bot:GetPos():Distance(ankh:GetPos()) > CaptureAnkh.UseRange * 1.5 then
            PHARAOH_HANDLER:CancelConversion(ankh, bot)
            ankh._tttbots_converter = nil
            ankh:SetNWInt("conversion_progress", 0)
            bot._ankhConvertingEnt = nil
            bot._ankhConvertStart = nil
            timer.Remove(timerName)
            return
        end
        -- Check if conversion time has elapsed
        if CurTime() - bot._ankhConvertStart >= conversionTime then
            PHARAOH_HANDLER:TransferAnkhOwnership(ankh, bot)
            ankh._tttbots_converter = nil
            ankh:SetNWInt("conversion_progress", 0)
            bot._ankhConvertingEnt = nil
            bot._ankhConvertStart = nil
            timer.Remove(timerName)

            -- Fire chatter events
            local chatter = bot:BotChatter()
            if chatter and chatter.On then
                if bot:GetSubRole() == ROLE_GRAVEROBBER then
                    chatter:On("GraverobberStoleAnkh", {}, true)
                elseif bot:GetSubRole() == ROLE_PHARAOH then
                    chatter:On("AnkhRecovered", {})
                end
            end
        end
    end)

    return STATUS.RUNNING
end

--- Validate the behavior
function CaptureAnkh.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.attackTarget ~= nil then return false end --- We are preoccupied with an attacker.

    -- BUG-2 FIX: Only Pharaohs and Graverobbers should attempt to capture ankhs
    if bot:GetSubRole() ~= ROLE_GRAVEROBBER and bot:GetSubRole() ~= ROLE_PHARAOH then
        return false
    end

    local isAnkhNearby = (bot.targetAnkh or CaptureAnkh.GetNearestAnkh(bot) ~= nil)
    -- Players can only control one Ankh, and may not convert another until they use the one they control
    if PHARAOH_HANDLER:PlayerControlsAnAnkh(bot) then
        return false
    end

    if not IsValid(bot.targetAnkh) then
        return false
    end

    if bot.targetAnkh and bot:Visible(bot.targetAnkh) then
        bot.lastSeenAnkhPos = bot.targetAnkh:GetPos()
    end

    --- if not in line of sight, don't bother
    if bot.targetAnkh and not bot:Visible(bot.targetAnkh) then
        --- if we don't remember the last seen position, don't bother
        if not bot.lastSeenAnkhPos then
            return false
        end
    end

    --Pharaohs may only convert ankhs that have been stolen from them.
    if bot:GetSubRole() == ROLE_PHARAOH and not PHARAOH_HANDLER:PlayerIsOriginalOwnerOfThisAnkh(bot, bot.targetAnkh) then
        return false
    end

    if bot.targetAnkh:GetNWBool("isReviving", false) then
        return false
    end

    return isAnkhNearby
end

--- Called when the behavior is started
function CaptureAnkh.OnStart(bot)
    local ankh = CaptureAnkh.GetNearestAnkh(bot)
    bot.targetAnkh = ankh
    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function CaptureAnkh.OnRunning(bot)
    if not CaptureAnkh.ValidateAnkh(bot.targetAnkh) then
        return STATUS.FAILURE
    end
    if bot.attackTarget ~= nil then
        return STATUS.FAILURE
    end

    local ankh = bot.targetAnkh
    local locomotor = bot:BotLocomotor()
    locomotor:SetGoal(ankh:GetPos())
    locomotor:PauseRepel()
    local distToAnkh = bot:GetPos():Distance(ankh:GetPos())

    if distToAnkh < 65 then
        locomotor:LookAt(ankh:GetPos())
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state
function CaptureAnkh.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function CaptureAnkh.OnFailure(bot)
end

--- Called when the behavior ends
function CaptureAnkh.OnEnd(bot)
    --- clear the target ankh
    if bot._ankhConvertingEnt and IsValid(bot._ankhConvertingEnt) then
        PHARAOH_HANDLER:CancelConversion(bot._ankhConvertingEnt, bot)
    end
    bot._ankhConvertingEnt = nil
    bot._ankhConvertStart = nil
    bot.targetAnkh = nil
    local timerName = "TTTBots.CaptureAnkh.Convert." .. bot:EntIndex()
    timer.Remove(timerName)
    local locomotor = bot:BotLocomotor()
    locomotor:ResumeRepel()
end

timer.Create("TTTBots.Behaviors.CaptureAnkh.UseNearbyAnkhs", 5, 0, function()
    local Arb = TTTBots.Morality
    local PRI = Arb.PRIORITY

    for i, bot in pairs(TTTBots.Bots) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
        -- Don't interfere while the bot is actively attacking a target
        if bot.attackTarget ~= nil then continue end
        -- Only Pharaohs and Graverobbers should interact with ankhs
        if bot:GetSubRole() ~= ROLE_GRAVEROBBER and bot:GetSubRole() ~= ROLE_PHARAOH then continue end
        local ankh = bot.targetAnkh
        if not (ankh and CaptureAnkh.ValidateAnkh(ankh)) then continue end
        local distToAnkh = bot:GetPos():Distance(ankh:GetPos())
        if distToAnkh < CaptureAnkh.UseRange then
            -- M-4: Graverobber concealment — wait for isolation before converting
            if bot:GetSubRole() == ROLE_GRAVEROBBER then
                local witnesses = TTTBots.Lib.GetAllWitnesses(bot:GetPos(), true)
                local innocentWitnesses = 0
                for _, v in pairs(witnesses) do
                    if v == bot then continue end
                    if v:GetTeam() == TEAM_INNOCENT or v:GetTeam() == TEAM_NONE then
                        innocentWitnesses = innocentWitnesses + 1
                    end
                end
                -- If there are innocent witnesses, delay conversion (unless round phase is late)
                if innocentWitnesses > 0 then
                    local ra = bot.BotRoundAwareness and bot:BotRoundAwareness()
                    local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
                    local isLate = ra and PHASE and (ra:GetPhase() == PHASE.LATE or ra:GetPhase() == PHASE.OVERTIME)
                    if not isLate then
                        continue -- Wait for witnesses to leave
                    end
                end
            end

            CaptureAnkh.UseAnkh(bot, ankh)

            -- Witness reactions using arbitration system
            local witnesses = TTTBots.Lib.GetAllWitnesses(bot:GetPos(), true)
            for _, v in pairs(witnesses) do
                if not (IsValid(v) and v:IsBot() and lib.IsPlayerAlive(v)) then continue end
                if v == bot then continue end

                if v:GetSubRole() == ROLE_GRAVEROBBER and bot:GetSubRole() == ROLE_PHARAOH then
                    -- Graverobber witnesses Pharaoh reclaiming — attack them
                    Arb.RequestAttackTarget(v, bot, "CAPTURE_ANKH", PRI.PLAYER_REQUEST)
                elseif bot:GetSubRole() == ROLE_GRAVEROBBER and v:GetTeam() == TEAM_INNOCENT then
                    -- Innocent witnesses Graverobber stealing — attack them
                    Arb.RequestAttackTarget(v, bot, "ANKH_CONVERSION_WITNESS", PRI.PLAYER_REQUEST)
                end
            end
        end
    end
end)