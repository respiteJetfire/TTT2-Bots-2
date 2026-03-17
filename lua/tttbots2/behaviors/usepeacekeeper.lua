--- behaviors/usepeacekeeper.lua
--- Uses the Peacekeeper / "High Noon" weapon (weapon_ttt_peacekeeper).
--- This is a McCree-style ultimate: the bot equips it, charges up targets in FOV,
--- then fires lethal homing shots. It's a one-use weapon that slows the user.
--- The bot should only use it when multiple enemies are visible at once.

local lib = TTTBots.Lib
local STATUS = TTTBots.STATUS

---@class BUsePeacekeeper
TTTBots.Behaviors.UsePeacekeeper = {}

local UsePeacekeeper = TTTBots.Behaviors.UsePeacekeeper
UsePeacekeeper.Name = "UsePeacekeeper"
UsePeacekeeper.Description = "Use the Peacekeeper (High Noon) weapon on multiple visible enemies."
UsePeacekeeper.Interruptible = false  -- Once committed, don't abort

--- Minimum visible enemies to justify using this powerful one-shot weapon.
local MIN_VISIBLE_ENEMIES = 2
--- Max time we'll hold before firing (the weapon charges automatically).
local CHARGE_TIME = 4.0
--- Max total behavior duration before we force-fire or fail.
local MAX_DURATION = 8.0

function UsePeacekeeper.HasPeacekeeper(bot)
    return bot:HasWeapon("weapon_ttt_peacekeeper")
end

function UsePeacekeeper.GetPeacekeeper(bot)
    local wep = bot:GetWeapon("weapon_ttt_peacekeeper")
    return IsValid(wep) and wep or nil
end

--- Count enemies visible to the bot within a reasonable FOV/range.
---@param bot Bot
---@return number visibleEnemies
local function CountVisibleEnemies(bot)
    local count = 0
    for _, ply in pairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() or ply == bot then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then continue end
        -- Check if the bot can see them within weapon range
        if bot:GetPos():Distance(ply:GetPos()) > 2000 then continue end
        if bot:Visible(ply) then
            count = count + 1
        end
    end
    return count
end

function UsePeacekeeper.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if not UsePeacekeeper.HasPeacekeeper(bot) then return false end

    local visibleEnemies = CountVisibleEnemies(bot)
    if visibleEnemies < MIN_VISIBLE_ENEMIES then return false end

    -- Small chance gate per tick
    if math.random(1, 40) > 1 then return false end

    return true
end

function UsePeacekeeper.OnStart(bot)
    bot._peacekeeperStart = CurTime()
    bot._peacekeeperChargeStart = nil

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("HighNoon", {}, false)
    end

    return STATUS.RUNNING
end

function UsePeacekeeper.OnRunning(bot)
    if not UsePeacekeeper.HasPeacekeeper(bot) then
        -- Weapon consumed — we successfully fired
        return STATUS.SUCCESS
    end

    -- Hard timeout
    if bot._peacekeeperStart and (CurTime() - bot._peacekeeperStart) > MAX_DURATION then
        return STATUS.FAILURE
    end

    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    local wep = UsePeacekeeper.GetPeacekeeper(bot)
    if not wep then return STATUS.FAILURE end

    -- Equip the peacekeeper
    inv:PauseAutoSwitch()
    bot:SetActiveWeapon(wep)
    loco:PauseAttackCompat()

    -- Find the centroid of visible enemies to look at
    local enemyPositions = {}
    for _, ply in pairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() or ply == bot then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then continue end
        if bot:GetPos():Distance(ply:GetPos()) > 2000 then continue end
        if bot:Visible(ply) then
            table.insert(enemyPositions, ply:EyePos())
        end
    end

    if #enemyPositions == 0 then
        -- Lost sight of everyone
        return STATUS.FAILURE
    end

    -- Look at centroid of enemy eyes
    local center = Vector(0, 0, 0)
    for _, pos in ipairs(enemyPositions) do
        center = center + pos
    end
    center = center / #enemyPositions
    loco:LookAt(center)
    loco:SetHalt(true)

    -- Phase 1: Primary fire starts the charge sequence
    if not bot._peacekeeperChargeStart then
        loco:StartAttack()
        bot._peacekeeperChargeStart = CurTime()
        return STATUS.RUNNING
    end

    -- Phase 2: Hold attack while charging — the weapon locks targets in FOV automatically.
    -- After CHARGE_TIME, release to fire the lethal shots.
    if (CurTime() - bot._peacekeeperChargeStart) >= CHARGE_TIME then
        loco:StopAttack()
        -- The weapon fires on release / secondary fire
        -- Give a brief moment then secondary fire
        timer.Simple(0.3, function()
            if IsValid(bot) then
                local l = bot:BotLocomotor()
                if l then l:StartAttack2() end
                timer.Simple(0.2, function()
                    if IsValid(bot) then
                        local l2 = bot:BotLocomotor()
                        if l2 then l2:StopAttack2() end
                    end
                end)
            end
        end)
        return STATUS.RUNNING
    end

    return STATUS.RUNNING
end

function UsePeacekeeper.OnSuccess(bot)
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("PeacekeeperFired", {}, false)
    end
end

function UsePeacekeeper.OnFailure(bot) end

function UsePeacekeeper.OnEnd(bot)
    bot._peacekeeperStart = nil
    bot._peacekeeperChargeStart = nil
    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if loco then
        loco:StopAttack()
        loco:StopAttack2()
        loco:ResumeAttackCompat()
        loco:SetHalt(false)
    end
    if inv then
        inv:ResumeAutoSwitch()
    end
end
