--- BreakConsignment — Behavior for bots to break open consignment crates
--- dropped by the Gun Dealer to loot weapons and ammo from them.
---
--- Bots will:
---   1. Detect nearby consignment crates (ent_ttt2_consignment)
---   2. Navigate to the closest crate
---   3. Switch to crowbar (or shoot if no crowbar) to break it open
---   4. Pick up the dropped weapons/ammo
---
--- This applies to ALL non-Gun-Dealer bots — everyone wants free loot.

---@class BBreakConsignment
TTTBots.Behaviors.BreakConsignment = {}

local lib = TTTBots.Lib

---@class BBreakConsignment
local BreakConsignment = TTTBots.Behaviors.BreakConsignment
BreakConsignment.Name = "BreakConsignment"
BreakConsignment.Description = "Break open a Gun Dealer consignment crate to loot its contents"
BreakConsignment.Interruptible = true

local STATUS = TTTBots.STATUS

-- Search radius for consignment crates
local CRATE_SEARCH_RADIUS = 800
-- Distance at which we switch from pathfinding to direct approach
local DIRECT_WALK_DIST = 200
-- Distance at which we start attacking with melee
local MELEE_ATTACK_DIST = 72
-- Distance at which we can shoot instead of melee (if no crowbar)
local SHOOT_ATTACK_DIST = 300
-- Timeout for the entire behavior
local CRATE_TIMEOUT = 20
-- Cooldown between crate-breaking attempts
local CRATE_COOLDOWN = 5

--- Find the nearest consignment crate, prioritizing crates intended for this bot
---@param bot Bot
---@return Entity|nil
local function FindNearestCrate(bot)
    local crates = ents.FindByClass("ent_ttt2_consignment")
    if #crates == 0 then return nil end

    local bestCrate = nil
    local bestDist = math.huge
    local bestIsPersonal = false

    for _, crate in ipairs(crates) do
        if not IsValid(crate) then continue end
        if crate:Health() <= 0 then continue end

        local dist = bot:GetPos():Distance(crate:GetPos())
        if dist > CRATE_SEARCH_RADIUS then continue end

        -- Check if this crate is specifically intended for this bot
        local isPersonal = false
        if crate.GetIntendedTarget then
            local intended = crate:GetIntendedTarget()
            if IsValid(intended) and intended == bot then
                isPersonal = true
            end
        end

        -- Personal crates always beat non-personal crates; otherwise pick closest
        if isPersonal and not bestIsPersonal then
            bestDist = dist
            bestCrate = crate
            bestIsPersonal = true
        elseif isPersonal == bestIsPersonal and dist < bestDist then
            bestDist = dist
            bestCrate = crate
        end
    end

    return bestCrate
end

--- Check if the bot has a crowbar / melee weapon
---@param bot Bot
---@return boolean
local function HasMelee(bot)
    -- Check for infected fists first
    local fists = bot:GetWeapon("weapon_ttt_inf_fists")
    if IsValid(fists) then return true end

    -- Check for standard TTT crowbar
    local crowbar = bot:GetWeapon("weapon_zm_improvised")
    if IsValid(crowbar) then return true end

    return false
end

--- Check if the bot has a ranged weapon with ammo
---@param bot Bot
---@return boolean
local function HasRangedWeapon(bot)
    local weapons = bot:GetWeapons()
    for _, wep in pairs(weapons) do
        if not IsValid(wep) then continue end
        -- Skip melee and special weapons
        local kind = wep.Kind
        if kind and (kind == WEAPON_HEAVY or kind == WEAPON_PISTOL) then
            -- Check clip ammo
            local clip = wep:Clip1()
            if clip > 0 then return true end
            -- Check reserve ammo
            local ammoType = wep:GetPrimaryAmmoType()
            if ammoType >= 0 and bot:GetAmmoCount(ammoType) > 0 then return true end
        end
    end
    return false
end

function BreakConsignment.Validate(bot)
    if not lib.IsPlayerAlive(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Gun Dealers don't break their own crates (unless self_break is enabled)
    if bot:GetSubRole() == ROLE_GUNDEALER then
        if not GetConVar("ttt2_gundealer_self_break"):GetBool() then
            return false
        end
    end

    -- Don't break crates during combat
    if IsValid(bot.attackTarget) then return false end

    -- Cooldown
    if (bot._breakConsignmentCooldown or 0) > CurTime() then return false end

    -- If we already have a target crate and it's still valid, keep going
    local state = TTTBots.Behaviors.GetState(bot, "BreakConsignment")
    if IsValid(state.targetCrate) and state.targetCrate:Health() > 0 then
        return true
    end

    -- Find a new crate
    local crate = FindNearestCrate(bot)
    if not crate then return false end

    state.targetCrate = crate
    return true
end

function BreakConsignment.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "BreakConsignment")
    state.startTime = CurTime()
    state.useMelee = HasMelee(bot)

    -- Announce intention to break the crate
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("GunDealerCrateSpotted", {}, false, 0)
    end

    return STATUS.RUNNING
end

function BreakConsignment.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "BreakConsignment")
    local crate = state.targetCrate

    -- Crate became invalid or was destroyed
    if not IsValid(crate) or crate:Health() <= 0 then
        return STATUS.SUCCESS -- Crate broken, loot should be on ground
    end

    -- Timeout
    if (CurTime() - (state.startTime or 0)) > CRATE_TIMEOUT then
        return STATUS.FAILURE
    end

    -- Abort if combat starts
    if IsValid(bot.attackTarget) then return STATUS.FAILURE end

    local loco = bot:BotLocomotor()
    local inv = bot.components.inventory
    -- Aim at center of the crate model, not the floor origin
    local cratePos = crate.WorldSpaceCenter and crate:WorldSpaceCenter() or (crate:GetPos() + Vector(0, 0, 16))
    local dist = bot:GetPos():Distance(crate:GetPos())

    local useMelee = state.useMelee

    if useMelee then
        -- MELEE PATH: get close and swing crowbar
        if dist <= MELEE_ATTACK_DIST then
            -- We're in range — look at crate, equip crowbar, and attack
            loco:LookAt(cratePos, 0.5)
            inv:EquipMelee()
            inv:PauseAutoSwitch()
            loco:StartAttack()
            -- Keep pushing toward the crate — use a very small threshold
            -- so we don't stop short. PriorityGoal auto-completes when within range,
            -- so use a tiny value to ensure we stay on top of it.
            loco:SetPriorityGoal(crate:GetPos(), 16)
            return STATUS.RUNNING
        end

        -- Not close enough yet — navigate toward the crate
        loco:StopAttack()
        loco:LookAt(cratePos)

        if dist <= DIRECT_WALK_DIST then
            -- Close enough for direct walk — skip pathfinding, beeline to it
            loco:SetGoal(nil)
            loco:SetPriorityGoal(crate:GetPos(), MELEE_ATTACK_DIST * 0.5)
        else
            loco:SetGoal(crate:GetPos())
        end
    else
        -- RANGED PATH: no crowbar, shoot the crate
        if not HasRangedWeapon(bot) then
            -- No melee AND no ranged weapon — can't break it
            return STATUS.FAILURE
        end

        if dist <= SHOOT_ATTACK_DIST then
            -- Close enough to shoot — look at crate and fire
            loco:LookAt(cratePos, 0.5)
            -- Equip best ranged weapon
            if inv.EquipBestWeapon then
                inv:EquipBestWeapon()
            elseif inv.EquipPrimary then
                if not inv:EquipPrimary() then
                    inv:EquipSecondary()
                end
            end
            inv:PauseAutoSwitch()
            loco:StartAttack()
            -- Stand still while shooting so we're accurate
            return STATUS.RUNNING
        end

        -- Not close enough to shoot — navigate closer
        loco:StopAttack()
        loco:LookAt(cratePos)
        loco:SetGoal(crate:GetPos())
    end

    return STATUS.RUNNING
end

function BreakConsignment.OnSuccess(bot)
    bot._breakConsignmentCooldown = CurTime() + CRATE_COOLDOWN

    -- Announce loot
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("GunDealerCrateBroken", {}, false, 0)
    end
end

function BreakConsignment.OnFailure(bot)
    bot._breakConsignmentCooldown = CurTime() + CRATE_COOLDOWN
end

function BreakConsignment.OnEnd(bot)
    local loco = bot:BotLocomotor()
    if loco then
        loco:StopAttack()
    end

    if bot.components and bot.components.inventory then
        bot.components.inventory:ResumeAutoSwitch()
    end

    TTTBots.Behaviors.ClearState(bot, "BreakConsignment")
end
