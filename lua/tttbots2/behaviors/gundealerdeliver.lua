--- GunDealerDeliver — Behavior for Gun Dealer bots to use their Consignment
--- Manifest to deliver crates to nearby players.
---
--- The Gun Dealer bot will:
---   1. Find a nearby alive player to send a crate to
---   2. Directly invoke the server-side delivery logic (bots run server-side
---      so net.SendToServer is unavailable — we replicate what the
---      net.Receive handler in sv_gundealer_handler does)
---   3. Wait for the delivery timer, then repeat
---
--- Priority: mid-level, after self-defense but before general restoration.

---@class BGunDealerDeliver
TTTBots.Behaviors.GunDealerDeliver = {}

local lib = TTTBots.Lib

---@class BGunDealerDeliver
local GunDealerDeliver = TTTBots.Behaviors.GunDealerDeliver
GunDealerDeliver.Name = "GunDealerDeliver"
GunDealerDeliver.Description = "Gun Dealer bot delivers consignment crates to nearby players"
GunDealerDeliver.Interruptible = true

local STATUS = TTTBots.STATUS

-- Minimum seconds between delivery attempts (includes delivery delay)
local DELIVER_COOLDOWN = 15
-- Maximum distance to consider a target for delivery
local DELIVER_MAX_DIST = 1500

--- Check if the bot has the Consignment Manifest weapon with charges remaining
---@param bot Bot
---@return boolean
local function HasConsignmentCharges(bot)
    local wep = bot:GetWeapon("weapon_ttt2_consignment")
    if not IsValid(wep) then return false end
    return wep:Clip1() > 0
end

--- Check if the weapon is currently delivering
---@param bot Bot
---@return boolean
local function IsDelivering(bot)
    local wep = bot:GetWeapon("weapon_ttt2_consignment")
    if not IsValid(wep) then return false end
    return wep:GetIsDelivering()
end

--- Find the best player to deliver a consignment to.
--- Prefers nearby alive players, avoiding self and other gun dealers.
---@param bot Bot
---@return Player|nil
local function FindDeliveryTarget(bot)
    local alivePlayers = TTTBots.Match.AlivePlayers or {}
    local bestTarget = nil
    local bestDist = math.huge

    for _, ply in ipairs(alivePlayers) do
        if not IsValid(ply) then continue end
        if ply == bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end

        -- Don't send crates to other gun dealers
        if ply:GetSubRole() == ROLE_GUNDEALER then continue end

        local dist = bot:GetPos():Distance(ply:GetPos())
        if dist > DELIVER_MAX_DIST then continue end

        -- Prefer closer players
        if dist < bestDist then
            bestDist = dist
            bestTarget = ply
        end
    end

    return bestTarget
end

--- Server-side delivery: replicate the logic from sv_gundealer_handler's
--- net.Receive("ttt2_gundealer_select_target") since bots cannot use
--- net.SendToServer().
---
--- Spawns a consignment crate after the configured delivery delay, consuming
--- one charge from the Consignment Manifest weapon.
---@param bot Bot
---@param target Player
---@return boolean success Whether the delivery was initiated
local function StartServerDelivery(bot, target)
    if not IsValid(bot) or bot:GetSubRole() ~= ROLE_GUNDEALER then return false end
    if not IsValid(target) or not target:IsPlayer() then return false end
    if not lib.IsPlayerAlive(bot) then return false end
    if not lib.IsPlayerAlive(target) then return false end

    local wep = bot:GetWeapon("weapon_ttt2_consignment")
    if not IsValid(wep) or wep:Clip1() <= 0 then return false end
    if wep:GetIsDelivering() then return false end

    -- Read the delivery delay convar (same as the net handler does)
    local delayCvar = GetConVar("ttt2_gundealer_delivery_delay")
    local delay = delayCvar and delayCvar:GetInt() or 5

    local sid64 = bot:SteamID64()

    -- Cancel any existing delivery timer for this dealer
    timer.Remove("ttt2_gundealer_delivery_" .. sid64)

    -- Mark weapon as delivering
    wep:SetIsDelivering(true)

    timer.Create("ttt2_gundealer_delivery_" .. sid64, delay, 1, function()
        if not IsValid(bot) or not bot:Alive() or bot:GetSubRole() ~= ROLE_GUNDEALER then
            local failWep = IsValid(bot) and bot:GetWeapon("weapon_ttt2_consignment") or nil
            if IsValid(failWep) then
                failWep:SetIsDelivering(false)
            end
            return
        end

        -- Spawn the crate using the Gun Dealer addon's entity
        local crate = ents.Create("ent_ttt2_consignment")
        if IsValid(crate) then
            local spawnPos = bot:GetPos() + Vector(0, 0, 80)
            crate:SetPos(spawnPos)
            crate:SetAngles(Angle(0, math.random(0, 360), 0))

            if crate.SetOriginator then crate:SetOriginator(bot) end
            if crate.SetIntendedTarget then crate:SetIntendedTarget(target) end
            if crate.SetIntendedTeam then
                crate:SetIntendedTeam(IsValid(target) and (target:GetTeam() or "") or "")
            end

            -- Randomly determine contents (weapon vs ammo)
            local weaponChanceCvar = GetConVar("ttt2_gundealer_weapon_chance")
            local weaponChance = weaponChanceCvar and weaponChanceCvar:GetInt() or 50
            if crate.SetContentType then
                crate:SetContentType(math.random(1, 100) <= weaponChance and 0 or 1)
            end

            crate:Spawn()
            crate:Activate()

            local phys = crate:GetPhysicsObject()
            if IsValid(phys) then
                phys:SetVelocity(Vector(0, 0, 50))
            end

            -- Notify bot targets about their personal crate so they can claim it immediately
            if IsValid(target) and target:IsBot() then
                target._claimConsignmentCrate = crate
                target._claimConsignmentTime = CurTime()
            end
        end

        -- Consume ammo
        local curWep = bot:GetWeapon("weapon_ttt2_consignment")
        if IsValid(curWep) then
            curWep:SetIsDelivering(false)
            curWep:SetClip1(curWep:Clip1() - 1)

            if curWep:Clip1() <= 0 then
                bot:StripWeapon("weapon_ttt2_consignment")
            end
        end
    end)

    return true
end

--- Validate: only run if we're a Gun Dealer with charges and not currently delivering
function GunDealerDeliver.Validate(bot)
    if not lib.IsPlayerAlive(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Must be a Gun Dealer
    if bot:GetSubRole() ~= ROLE_GUNDEALER then return false end

    -- Must have the weapon with charges
    if not HasConsignmentCharges(bot) then return false end

    -- If currently delivering, keep running to wait
    if IsDelivering(bot) then return true end

    -- Cooldown between deliveries
    if (bot._gunDealerDeliverCooldown or 0) > CurTime() then return false end

    -- Must have a valid target
    local target = FindDeliveryTarget(bot)
    if not target then return false end

    local state = TTTBots.Behaviors.GetState(bot, "GunDealerDeliver")
    state.target = target

    return true
end

function GunDealerDeliver.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "GunDealerDeliver")
    local target = state.target

    if not IsValid(target) then return STATUS.FAILURE end

    -- If already delivering, just wait
    if IsDelivering(bot) then
        state.waitingForDelivery = true
        return STATUS.RUNNING
    end

    -- Announce the delivery via chatter
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("GunDealerDelivering", {
            player = target:Nick(),
            playerEnt = target,
        }, false, 0)
    end

    -- Directly invoke server-side delivery logic (bots run server-side,
    -- net.SendToServer() does not exist in this context)
    local ok = StartServerDelivery(bot, target)
    if not ok then return STATUS.FAILURE end

    state.waitingForDelivery = true
    state.deliveryStartTime = CurTime()

    return STATUS.RUNNING
end

function GunDealerDeliver.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "GunDealerDeliver")

    -- If we're waiting for a delivery in progress, just wait
    if IsDelivering(bot) then
        -- Look around casually while waiting
        local loco = bot:BotLocomotor()
        if loco then
            loco:SetGoal(nil) -- Stay in place during delivery
        end
        return STATUS.RUNNING
    end

    -- Delivery completed (weapon is no longer in delivering state)
    if state.waitingForDelivery and state.deliveryStartTime then
        -- The delivery finished (the timer in sv_gundealer_handler completed)
        return STATUS.SUCCESS
    end

    -- Timeout after 30 seconds
    if state.deliveryStartTime and (CurTime() - state.deliveryStartTime) > 30 then
        return STATUS.FAILURE
    end

    return STATUS.RUNNING
end

function GunDealerDeliver.OnSuccess(bot)
    -- Set cooldown before next delivery
    bot._gunDealerDeliverCooldown = CurTime() + DELIVER_COOLDOWN

    -- Announce success
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("GunDealerDelivered", {}, false, 0)
    end
end

function GunDealerDeliver.OnFailure(bot)
    bot._gunDealerDeliverCooldown = CurTime() + 5
end

function GunDealerDeliver.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "GunDealerDeliver")
end
