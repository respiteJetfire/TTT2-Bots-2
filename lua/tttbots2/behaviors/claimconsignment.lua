--- ClaimConsignment — High-priority behavior for bots to immediately go to
--- a consignment crate that was specifically intended for them.
---
--- When a Gun Dealer sends a crate to a bot, the server tags the bot with
--- `_claimConsignmentCrate`. This behavior fires at higher priority than
--- normal BreakConsignment so the bot bee-lines to "their" crate first.
---
--- Bots will:
---   1. Check if they have a personal crate assigned via _claimConsignmentCrate
---   2. Navigate directly to that crate (ignoring the broader search radius)
---   3. Break it open with melee or ranged weapon
---
--- This does NOT run if the bot is in combat (has an attackTarget).

---@class BClaimConsignment
TTTBots.Behaviors.ClaimConsignment = {}

local lib = TTTBots.Lib

---@class BClaimConsignment
local ClaimConsignment = TTTBots.Behaviors.ClaimConsignment
ClaimConsignment.Name = "ClaimConsignment"
ClaimConsignment.Description = "Go claim a consignment crate that was sent specifically for this bot"
ClaimConsignment.Interruptible = true

local STATUS = TTTBots.STATUS

-- Distance at which we switch from pathfinding to direct approach
local DIRECT_WALK_DIST = 200
-- Distance at which we start attacking with melee
local MELEE_ATTACK_DIST = 72
-- Distance at which we can shoot instead of melee (if no crowbar)
local SHOOT_ATTACK_DIST = 300
-- Timeout for the entire behavior
local CLAIM_TIMEOUT = 30
-- Maximum distance we're willing to travel to claim a crate
local MAX_CLAIM_DIST = 4000

--- Check if the bot has a crowbar / melee weapon
---@param bot Bot
---@return boolean
local function HasMelee(bot)
    local fists = bot:GetWeapon("weapon_ttt_inf_fists")
    if IsValid(fists) then return true end

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
        local kind = wep.Kind
        if kind and (kind == WEAPON_HEAVY or kind == WEAPON_PISTOL) then
            local clip = wep:Clip1()
            if clip > 0 then return true end
            local ammoType = wep:GetPrimaryAmmoType()
            if ammoType >= 0 and bot:GetAmmoCount(ammoType) > 0 then return true end
        end
    end
    return false
end

function ClaimConsignment.Validate(bot)
    if not lib.IsPlayerAlive(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Don't claim crates during combat
    if IsValid(bot.attackTarget) then return false end

    -- Gun Dealers don't break their own crates (unless self_break is enabled)
    if ROLE_GUNDEALER and bot:GetSubRole() == ROLE_GUNDEALER then
        if not GetConVar("ttt2_gundealer_self_break"):GetBool() then
            return false
        end
    end

    -- Check if already tracking a crate via the state
    local state = TTTBots.Behaviors.GetState(bot, "ClaimConsignment")
    if IsValid(state.targetCrate) and state.targetCrate:Health() > 0 then
        return true
    end

    -- Check the server-assigned personal crate
    local crate = bot._claimConsignmentCrate
    if not IsValid(crate) or crate:Health() <= 0 then
        bot._claimConsignmentCrate = nil
        return false
    end

    -- Verify the crate is actually intended for us (sanity check)
    if crate.GetIntendedTarget then
        local intended = crate:GetIntendedTarget()
        if IsValid(intended) and intended ~= bot then
            bot._claimConsignmentCrate = nil
            return false
        end
    end

    -- Check distance — don't cross the entire map for it
    local dist = bot:GetPos():Distance(crate:GetPos())
    if dist > MAX_CLAIM_DIST then return false end

    state.targetCrate = crate
    return true
end

function ClaimConsignment.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ClaimConsignment")
    state.startTime = CurTime()
    state.useMelee = HasMelee(bot)

    -- Announce intention to go get the crate
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("GunDealerCrateSpotted", {}, false, 0)
    end

    return STATUS.RUNNING
end

function ClaimConsignment.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ClaimConsignment")
    local crate = state.targetCrate

    -- Crate became invalid or was destroyed
    if not IsValid(crate) or crate:Health() <= 0 then
        bot._claimConsignmentCrate = nil
        return STATUS.SUCCESS
    end

    -- Timeout
    if (CurTime() - (state.startTime or 0)) > CLAIM_TIMEOUT then
        return STATUS.FAILURE
    end

    -- Abort if combat starts
    if IsValid(bot.attackTarget) then return STATUS.FAILURE end

    local loco = bot:BotLocomotor()
    local inv = bot.components and bot.components.inventory
    local cratePos = crate.WorldSpaceCenter and crate:WorldSpaceCenter() or (crate:GetPos() + Vector(0, 0, 16))
    local dist = bot:GetPos():Distance(crate:GetPos())

    local useMelee = state.useMelee

    if useMelee then
        -- MELEE PATH: get close and swing crowbar
        if dist <= MELEE_ATTACK_DIST then
            loco:LookAt(cratePos, 0.5)
            if inv then
                inv:EquipMelee()
                inv:PauseAutoSwitch()
            end
            loco:StartAttack()
            loco:SetPriorityGoal(crate:GetPos(), 16)
            return STATUS.RUNNING
        end

        -- Navigate toward the crate
        loco:StopAttack()
        loco:LookAt(cratePos)

        if dist <= DIRECT_WALK_DIST then
            loco:SetGoal(nil)
            loco:SetPriorityGoal(crate:GetPos(), MELEE_ATTACK_DIST * 0.5)
        else
            loco:SetGoal(crate:GetPos())
        end
    else
        -- RANGED PATH: no crowbar, shoot the crate
        if not HasRangedWeapon(bot) then
            return STATUS.FAILURE
        end

        if dist <= SHOOT_ATTACK_DIST then
            loco:LookAt(cratePos, 0.5)
            if inv then
                if inv.EquipBestWeapon then
                    inv:EquipBestWeapon()
                elseif inv.EquipPrimary then
                    if not inv:EquipPrimary() then
                        inv:EquipSecondary()
                    end
                end
                inv:PauseAutoSwitch()
            end
            loco:StartAttack()
            return STATUS.RUNNING
        end

        -- Navigate closer
        loco:StopAttack()
        loco:LookAt(cratePos)
        loco:SetGoal(crate:GetPos())
    end

    return STATUS.RUNNING
end

function ClaimConsignment.OnSuccess(bot)
    bot._claimConsignmentCrate = nil

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("GunDealerCrateBroken", {}, false, 0)
    end
end

function ClaimConsignment.OnFailure(bot)
    bot._claimConsignmentCrate = nil
end

function ClaimConsignment.OnEnd(bot)
    local loco = bot:BotLocomotor()
    if loco then
        loco:StopAttack()
    end

    if bot.components and bot.components.inventory then
        bot.components.inventory:ResumeAutoSwitch()
    end

    TTTBots.Behaviors.ClearState(bot, "ClaimConsignment")
end
