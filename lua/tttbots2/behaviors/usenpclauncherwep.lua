--- behaviors/usenpclauncherwep.lua
--- Shared behavior factory for NPC-spawning canister launchers:
---   weapon_ttt_combinelauncher   — drops a Combine soldier squad from orbit
---   weapon_ttt_fastzombielauncher — drops fast zombies from orbit
---   weapon_ttt_headlauncher       — fires a headcrab canister (headcrabs auto-spawn)
---
--- All three weapons share the same attack mechanic:
---   1. The SWEP scans from the eye-trace hit point for sky-visible directions.
---   2. If any sky hits are found, it fires an env_headcrabcanister toward the sky.
---   3. NPCs (or headcrabs) spawn at the impact point ~2.6 s later.
---
--- Because the weapon handles all targeting internally, the bot only needs to:
---   • Equip the weapon.
---   • Confirm at least one sky-visible direction exists (quick sanity check).
---   • Call PrimaryAttack() directly on the weapon entity.
---
--- Cooldown is tracked per-weapon-class on the bot to prevent looping after
--- all charges have been spent.

TTTBots = TTTBots or {}
TTTBots.Behaviors = TTTBots.Behaviors or {}

local lib = TTTBots.Lib
local STATUS = TTTBots.STATUS

--- How long between uses of the same launcher (seconds).
--- Each weapon only has 2-3 shots total, so this mainly prevents
--- rapid re-fires within a single round.
local USE_COOLDOWN = 30

--- Minimum live enemies in the game before the bot considers firing.
local MIN_ENEMIES = 2

--- Timeout (seconds) to abort if the weapon never fires.
local FIRE_TIMEOUT = 4

--- Quick sky-visibility check from around the bot's position.
--- Fires a handful of upward traces from the bot's eye position with slight
--- horizontal offsets to mimic the weapon's own scanning behaviour.
--- Returns true if at least one trace hits the sky (is outdoors).
---@param bot Bot
---@return boolean
local function HasSkyAccess(bot)
    local eyePos = bot:EyePos()
    -- Sample cardinal + up directions; any sky hit means the weapon can fire.
    local dirs = {
        Vector(0, 0, 1),
        Vector(0.3, 0, 0.95),
        Vector(-0.3, 0, 0.95),
        Vector(0, 0.3, 0.95),
        Vector(0, -0.3, 0.95),
    }
    for _, dir in ipairs(dirs) do
        local tr = util.TraceLine({
            start  = eyePos,
            endpos = eyePos + dir * 40000,
            mask   = MASK_SOLID,
        })
        if tr.HitSky then return true end
    end
    return false
end

--- Count living non-ally players visible to the bot (rough threat count).
---@param bot Bot
---@return number
local function CountLiveEnemies(bot)
    local count = 0
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if not ply:Alive() then continue end
        if ply == bot then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then continue end
        count = count + 1
    end
    return count
end

--- Cooldown key for a specific weapon class on a bot table.
---@param weaponClass string
---@return string
local function CooldownKey(weaponClass)
    return "_npcLauncherCooldown_" .. weaponClass
end

--- Build and register a launcher behavior for the given weapon class and display name.
---@param weaponClass string   e.g. "weapon_ttt_combinelauncher"
---@param displayName string   e.g. "CombineLauncher"
---@param chatterTag  string?  optional chatter event name
local function RegisterLauncherBehavior(weaponClass, displayName, chatterTag)
    local BehaviorName = "Use" .. displayName
    local cdKey = CooldownKey(weaponClass)

    ---@class BNPCLauncher
    local Behavior = {}
    TTTBots.Behaviors[BehaviorName] = Behavior

    Behavior.Name         = BehaviorName
    Behavior.Description  = "Deploy " .. displayName .. " to spawn NPCs"
    Behavior.Interruptible = true

    --- Validate: bot must have the weapon, round active, enemies present,
    --- sky access available, and the cooldown expired.
    ---@param bot Bot
    ---@return boolean
    function Behavior.Validate(bot)
        if not IsValid(bot) then return false end
        if not bot:Alive() then return false end
        if not TTTBots.Match.IsRoundActive() then return false end
        if not bot:HasWeapon(weaponClass) then return false end

        -- Cooldown gate
        local lastUse = bot[cdKey] or 0
        if (CurTime() - lastUse) < USE_COOLDOWN then return false end

        -- Require enough live enemies to be worth calling in a strike
        if CountLiveEnemies(bot) < MIN_ENEMIES then return false end

        -- Require sky access — these weapons need outdoor/sky-visible positions
        if not HasSkyAccess(bot) then return false end

        -- Random chance gate so bots don't always fire immediately on equip
        -- (~5 % chance per validate tick at 5 TPS = fires within ~4 s of being valid)
        if math.random(1, 20) ~= 1 then return false end

        return true
    end

    ---@param bot Bot
    ---@return BStatus
    function Behavior.OnStart(bot)
        local state = TTTBots.Behaviors.GetState(bot, BehaviorName)
        state.startTime = CurTime()
        state.fired     = false

        local inv = bot:BotInventory()
        if inv then inv:PauseAutoSwitch() end

        if chatterTag then
            local chatter = bot:BotChatter()
            if chatter and chatter.On then
                chatter:On(chatterTag, {}, true)
            end
        end

        return STATUS.RUNNING
    end

    ---@param bot Bot
    ---@return BStatus
    function Behavior.OnRunning(bot)
        local state = TTTBots.Behaviors.GetState(bot, BehaviorName)

        -- Abort if weapon was consumed (all shots spent) or lost
        if not bot:HasWeapon(weaponClass) then
            return STATUS.SUCCESS
        end

        -- Timeout safety
        local elapsed = CurTime() - (state.startTime or CurTime())
        if elapsed > FIRE_TIMEOUT then
            return STATUS.FAILURE
        end

        local loco = bot:BotLocomotor()
        if not loco then return STATUS.FAILURE end

        -- Step 0: equip the weapon
        if not state.equipped then
            local wep = bot:GetWeapon(weaponClass)
            if not IsValid(wep) then return STATUS.FAILURE end
            bot:SelectWeapon(weaponClass)
            state.equipped   = true
            state.equipTime  = CurTime()
            return STATUS.RUNNING
        end

        -- Wait a tick for the weapon switch to settle
        if (CurTime() - (state.equipTime or 0)) < 0.15 then
            return STATUS.RUNNING
        end

        local activeWep = bot:GetActiveWeapon()
        if not (IsValid(activeWep) and activeWep:GetClass() == weaponClass) then
            -- Weapon switch hasn't completed — retry select
            bot:SelectWeapon(weaponClass)
            return STATUS.RUNNING
        end

        -- Confirm sky access is still valid now that we're equipped
        if not HasSkyAccess(bot) then
            return STATUS.FAILURE
        end

        -- Stand still so the eye-trace hit point is stable for the weapon scan
        loco:StopMoving()
        loco:StopAttack()

        -- Step 1: call PrimaryAttack() directly — the weapon's own scanning
        -- loop picks sky-visible targets from the owner's current view.
        -- This mirrors the approach used by ActivateSmartBullets and avoids
        -- the locomotor's reaction-delay and semi-auto click pipeline.
        if not state.fired then
            activeWep:PrimaryAttack()
            state.fired    = true
            state.firedTime = CurTime()
            bot[cdKey]     = CurTime()
            return STATUS.RUNNING
        end

        -- Step 2: brief wait then check the weapon was consumed (clip dropped)
        -- or still has charges. Either way consider this a success.
        if (CurTime() - (state.firedTime or 0)) >= 0.3 then
            return STATUS.SUCCESS
        end

        return STATUS.RUNNING
    end

    ---@param bot Bot
    function Behavior.OnSuccess(bot)
    end

    ---@param bot Bot
    function Behavior.OnFailure(bot)
        -- Reset cooldown on failure so it can retry sooner
        -- (but still impose a short back-off to prevent tight loops)
        local cdVal = bot[cdKey] or 0
        if (CurTime() - cdVal) < 5 then
            bot[cdKey] = CurTime() - (USE_COOLDOWN - 10)
        end
    end

    ---@param bot Bot
    function Behavior.OnEnd(bot)
        TTTBots.Behaviors.ClearState(bot, BehaviorName)
        local loco = bot:BotLocomotor()
        if loco then loco:StopAttack() end
        local inv = bot:BotInventory()
        if inv then inv:ResumeAutoSwitch() end
    end
end

-- ── Register the three launcher behaviors ────────────────────────────────

RegisterLauncherBehavior(
    "weapon_ttt_combinelauncher",
    "CombineLauncher",
    "DeployingCombineLauncher"
)

RegisterLauncherBehavior(
    "weapon_ttt_fastzombielauncher",
    "FastZombieLauncher",
    "DeployingFastZombieLauncher"
)

RegisterLauncherBehavior(
    "weapon_ttt_headlauncher",
    "HeadcrabLauncher",
    "DeployingHeadcrabLauncher"
)
