--- zombieattack.lua
--- Ranged combat behavior for Necromancer Zombies using the zombie deagle
--- (weapon_ttth_zombpistol). Tracks remaining ammo, conserves shots, and
--- becomes more aggressive as ammo depletes. When ammo hits 0, the weapon
--- auto-kills the zombie — the bot is aware of this self-destruct mechanic.

---@class BZombieAttack
TTTBots.Behaviors.ZombieAttack = {}

local lib = TTTBots.Lib

---@class BZombieAttack
local ZAttack = TTTBots.Behaviors.ZombieAttack
ZAttack.Name = "ZombieAttack"
ZAttack.Description = "Hunt non-allies with the zombie deagle (ammo-aware combat)."
ZAttack.Interruptible = true

local STATUS = TTTBots.STATUS

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

--- Maximum engagement range (zombie deagle is accurate: 0.02 cone).
local ENGAGE_RANGE = 1200
--- Range at which the bot enters desperate rush mode (low ammo).
local DESPERATE_RUSH_RANGE = 2000
--- Below this ammo threshold, become desperate (rush and spray).
local DESPERATE_AMMO_THRESHOLD = 2
--- How often (in ticks) to re-evaluate the best target.
local RETARGET_INTERVAL = 5
--- Close enough to start firing.
local FIRE_RANGE = 800
--- When desperate, fire from further away.
local DESPERATE_FIRE_RANGE = 1000

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Check if the bot is a necromancer zombie.
---@param bot Bot
---@return boolean
local function isNecroZombie(bot)
    if not IsValid(bot) then return false end
    if TTTBots.Roles.IsNecroZombie then
        return TTTBots.Roles.IsNecroZombie(bot)
    end
    -- Fallback
    return ROLE_ZOMBIE and bot:GetSubRole() == ROLE_ZOMBIE
end

--- Get the zombie deagle weapon.
---@param bot Bot
---@return Weapon?
local function getZombieDeagle(bot)
    local wep = bot:GetWeapon("weapon_ttth_zombpistol")
    if IsValid(wep) then return wep end
    return nil
end

--- Get current ammo in the zombie deagle clip.
---@param bot Bot
---@return number
local function getAmmo(bot)
    local wep = getZombieDeagle(bot)
    if not wep then return 0 end
    return wep:Clip1()
end

--- Find the closest visible non-allied player.
---@param bot Bot
---@param maxRange number?
---@return Player? target
---@return number distance
local function findTarget(bot, maxRange)
    maxRange = maxRange or ENGAGE_RANGE
    local nonAllies = TTTBots.Roles.GetNonAllies(bot)
    local bestTarget = nil
    local bestDist = math.huge

    for _, ply in ipairs(nonAllies) do
        if not IsValid(ply) then continue end
        if not lib.IsPlayerAlive(ply) then continue end

        local dist = bot:GetPos():Distance(ply:GetPos())
        if dist > maxRange then continue end
        if dist < bestDist then
            bestDist = dist
            bestTarget = ply
        end
    end

    return bestTarget, bestDist
end

-- ---------------------------------------------------------------------------
-- Behavior interface
-- ---------------------------------------------------------------------------

function ZAttack.Validate(bot)
    if not IsValid(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not isNecroZombie(bot) then return false end

    -- Don't activate if already fighting via AttackTarget
    if bot.attackTarget ~= nil then return false end

    -- Must have the zombie deagle with ammo
    local ammo = getAmmo(bot)
    if ammo <= 0 then return false end

    -- Check if there's a target in range
    local range = ammo <= DESPERATE_AMMO_THRESHOLD and DESPERATE_RUSH_RANGE or ENGAGE_RANGE
    local target = findTarget(bot, range)
    return target ~= nil
end

function ZAttack.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ZombieAttack")
    state.target = nil
    state.retargetTick = 0
    state.lastAmmoWarning = 0

    -- Make sure we're holding the zombie deagle
    local wep = getZombieDeagle(bot)
    if IsValid(wep) then
        bot:SelectWeapon("weapon_ttth_zombpistol")
    end

    return STATUS.RUNNING
end

function ZAttack.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ZombieAttack")
    state.retargetTick = (state.retargetTick or 0) + 1

    local ammo = getAmmo(bot)
    local isDesperate = ammo <= DESPERATE_AMMO_THRESHOLD

    -- Self-destruct awareness: if ammo is 0, we're about to die
    if ammo <= 0 then
        -- Fire last words chatter
        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("ZombieSelfDestruct", {}, false, 0)
        end
        return STATUS.FAILURE
    end

    -- Ammo warning chatter
    if isDesperate and state.lastAmmoWarning == 0 then
        state.lastAmmoWarning = CurTime()
        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("ZombieAmmoLow", { ammo = tostring(ammo) }, false, 0)
        end
    end

    -- Periodically re-evaluate target
    local maxRange = isDesperate and DESPERATE_RUSH_RANGE or ENGAGE_RANGE
    if not IsValid(state.target) or not lib.IsPlayerAlive(state.target) or (state.retargetTick % RETARGET_INTERVAL == 0) then
        local newTarget, dist = findTarget(bot, maxRange)
        if not newTarget then return STATUS.FAILURE end
        state.target = newTarget
    end

    local target = state.target
    local targetPos = target:GetPos()
    local dist = bot:GetPos():Distance(targetPos)

    local loco = bot:BotLocomotor()
    local inv = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    -- Ensure we're holding the zombie deagle
    local wep = getZombieDeagle(bot)
    if IsValid(wep) then
        inv:PauseAutoSwitch()
        bot:SetActiveWeapon(wep)
    end

    -- Always look at and move toward the target
    loco:SetGoal(targetPos)
    loco:LookAt(target:EyePos())

    -- Determine firing range based on desperation
    local fireRange = isDesperate and DESPERATE_FIRE_RANGE or FIRE_RANGE

    -- When close enough and visible, engage via the morality/attack system
    if dist <= fireRange and bot:Visible(target) then
        -- Use SetAttackTarget to engage — this handles the actual combat
        bot:SetAttackTarget(target, "ZOMBIE_ATTACK", 4)
        return STATUS.SUCCESS
    end

    return STATUS.RUNNING
end

function ZAttack.OnSuccess(bot)
end

function ZAttack.OnFailure(bot)
end

function ZAttack.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "ZombieAttack")
    local inv = bot:BotInventory()
    if inv then
        inv:ResumeAutoSwitch()
    end
end
