TTTBots.Behaviors.CaptureAnkh = {}

local lib = TTTBots.Lib

local CaptureAnkh = TTTBots.Behaviors.CaptureAnkh
CaptureAnkh.Name = "Capture Ankh"
CaptureAnkh.Description = "Look for and use an ankh"
CaptureAnkh.Interruptible = true
CaptureAnkh.UseRange = 50 --- The range at which we can use an ankh

CaptureAnkh.TargetClass = "ttt_ankh"

local STATUS = TTTBots.STATUS

function CaptureAnkh.ValidateAnkh(ankh)
    for i, v in pairs(player.GetAll()) do
        if v:HasWeapon(CaptureAnkh.TargetClass) then
            return false
        end
    end
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

function CaptureAnkh.UseAnkh(bot, ankh)
    --- Wait 1 second before using the ankh
    PHARAOH_HANDLER:StartConversion(ankh, bot)
    timer.Simple(1, function()
        PHARAOH_HANDLER:TransferAnkhOwnership(ankh, bot)
    end)
    return STATUS.SUCCESS
end

--- Validate the behavior
function CaptureAnkh.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.attackTarget ~= nil then return false end --- We are preoccupied with an attacker.

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
    --- if the ROLE_GRAVEROBBER is a witness, they might attack the player
    --- get witnesses
    local witnesses = TTTBots.Lib.GetAllWitnesses(bot:EyePos(), true)
    --- so if the bot is ROLE_PHAROAH and the witneess is ROLE_GRAVEROBBER, the witness will attack the bot
    for i, v in pairs(witnesses) do
        if v:GetSubRole() == ROLE_GRAVEROBBER and bot:GetSubRole() == ROLE_PHARAOH then
            v:SetAttackTarget(bot)
        elseif v:GetSubRole() == ROLE_PHARAOH and bot:GetSubRole() == ROLE_GRAVEROBBER then
            v:SetAttackTarget(bot)
        end
    end
end

--- Called when the behavior returns a failure state
function CaptureAnkh.OnFailure(bot)
end

--- Called when the behavior ends
function CaptureAnkh.OnEnd(bot)
    bot.targetAnkh = nil
    local locomotor = bot:BotLocomotor()
    locomotor:ResumeRepel()
end

timer.Create("TTTBots.Behaviors.CaptureAnkh.UseNearbyAnkhs", 0.5, 0, function()
    for i, bot in pairs(TTTBots.Bots) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
        local ankh = bot.targetAnkh
        if not (ankh and CaptureAnkh.ValidateAnkh(ankh)) then continue end
        local distToAnkh = bot:GetPos():Distance(ankh:GetPos())
        if distToAnkh < CaptureAnkh.UseRange then
            CaptureAnkh.UseAnkh(bot, ankh)
        end
    end
end)