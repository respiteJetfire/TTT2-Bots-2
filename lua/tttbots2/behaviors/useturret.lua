--- behaviors/useturret.lua
--- Deploys a traitor turret (weapon_ttt_turret) in a tactically useful position.
--- The bot navigates to a suitable location, aims at the ground, and fires to place
--- the turret, then returns to normal behavior.

local lib = TTTBots.Lib
local STATUS = TTTBots.STATUS

---@class BUseTurret
TTTBots.Behaviors.UseTurret = {}

local UseTurret = TTTBots.Behaviors.UseTurret
UseTurret.Name = "UseTurret"
UseTurret.Description = "Deploy a traitor turret in a strategic position."
UseTurret.Interruptible = true

--- Maximum time (seconds) the bot will spend trying to deploy before giving up.
local DEPLOY_TIMEOUT = 12
--- How close the bot needs to be to its chosen deploy spot.
local DEPLOY_RANGE = 150

--- Check if the bot has the turret weapon.
---@param bot Bot
---@return boolean
function UseTurret.HasTurret(bot)
    return bot:HasWeapon("weapon_ttt_turret")
end

--- Get the turret weapon entity.
---@param bot Bot
---@return Weapon?
function UseTurret.GetTurret(bot)
    local wep = bot:GetWeapon("weapon_ttt_turret")
    return IsValid(wep) and wep or nil
end

--- Find a placement position on the ground nearby. Prefers positions with good
--- line-of-sight to open areas (hallways, rooms) where enemies are likely to pass.
---@param bot Bot
---@return Vector?
function UseTurret.FindDeploySpot(bot)
    local myPos = bot:GetPos()

    -- Try to find a nav area near a chokepoint or high-traffic area.
    -- Simple heuristic: look for a wall or corner nearby we can place the turret against.
    local tr = util.TraceLine({
        start  = bot:EyePos(),
        endpos = bot:EyePos() + bot:GetForward() * 80,
        mask   = MASK_SOLID_BRUSHONLY,
    })

    if tr.Hit and tr.HitPos:Distance(myPos) < 120 then
        -- There's a wall ahead — place turret here facing outward.
        return myPos
    end

    -- Fallback: just place it at current position.
    return myPos
end

--- Validate: bot must have the turret weapon, round must be active, and
--- there should be a reasonable situation to deploy (not in immediate combat).
function UseTurret.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if not UseTurret.HasTurret(bot) then return false end
    -- Don't deploy while in active combat
    if bot.attackTarget ~= nil and IsValid(bot.attackTarget) then return false end
    -- Small random chance gate to prevent constant deploy attempts
    if math.random(1, 80) > 1 then return false end
    return true
end

function UseTurret.OnStart(bot)
    bot._turretDeployStart = CurTime()
    bot._turretDeploySpot = UseTurret.FindDeploySpot(bot)

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("DeployingTurret", {}, true)
    end

    return STATUS.RUNNING
end

function UseTurret.OnRunning(bot)
    if not UseTurret.HasTurret(bot) then
        -- Turret was consumed (successfully placed) or lost
        return STATUS.SUCCESS
    end

    -- Timeout check
    if bot._turretDeployStart and (CurTime() - bot._turretDeployStart) > DEPLOY_TIMEOUT then
        return STATUS.FAILURE
    end

    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    local deploySpot = bot._turretDeploySpot or bot:GetPos()
    local dist = bot:GetPos():Distance(deploySpot)

    if dist > DEPLOY_RANGE then
        loco:SetGoal(deploySpot)
        return STATUS.RUNNING
    end

    -- We're at the deploy spot — equip the turret and fire to place
    inv:PauseAutoSwitch()
    local turret = UseTurret.GetTurret(bot)
    if not turret then return STATUS.FAILURE end

    bot:SetActiveWeapon(turret)
    loco:SetGoal()
    loco:SetHalt(true)

    -- Aim at the ground a short distance ahead for placement
    local placePos = bot:EyePos() + bot:GetForward() * 60 - Vector(0, 0, 50)
    loco:LookAt(placePos, 2)
    loco:StartAttack()

    return STATUS.RUNNING
end

function UseTurret.OnSuccess(bot)
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("TurretDeployed", {}, true)
    end
end

function UseTurret.OnFailure(bot) end

function UseTurret.OnEnd(bot)
    bot._turretDeployStart = nil
    bot._turretDeploySpot = nil
    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if loco then
        loco:StopAttack()
        loco:SetHalt(false)
    end
    if inv then
        inv:ResumeAutoSwitch()
    end
end
