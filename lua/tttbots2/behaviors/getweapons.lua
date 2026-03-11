TTTBots.Behaviors.GetWeapons = {}

local lib = TTTBots.Lib

local GetWeapons = TTTBots.Behaviors.GetWeapons
GetWeapons.Name = "GetWeapons"
GetWeapons.Description = "Acquire a weapon to use"
GetWeapons.Interruptible = true

local STATUS = TTTBots.STATUS

local globalWeapons = {}
local globalPrimaries = {}
local globalSecondaries = {}
local globalSpecials = {}

---@class Bot
---@field botTargetWeapon Weapon?

---Get the needed weapon type for the bot, else "none"
---@param bot Bot
---@return string type
function GetWeapons.GetNeededWeapon(bot)
    local inventory = bot:BotInventory()

    local hasPrimary = inventory:HasPrimary()
    local hasSecondary = inventory:HasSecondary()
    local hasSpecial = inventory:HasSpecialWeapon()

    return (
        not hasPrimary and "primary" or
        not hasSecondary and "secondary" or
        not hasSpecial and "special" or
        "none"
    )
end

---@param bot Bot
function GetWeapons.NeedsWeapon(bot)
    return GetWeapons.GetNeededWeapon(bot) ~= "none"
end

---@param bot Bot
function GetWeapons.Validate(bot)
    -- When fleeing (out-of-ammo), also seek weapons even if we technically
    -- have a primary/secondary — we need one with actual ammo.
    local isFleeing = IsValid(bot.fleeFromTarget) and (bot.fleeFromTargetUntil or 0) > CurTime()
    local inv = bot:BotInventory()
    local desperateForWeapon = isFleeing and inv and inv:HasNoWeaponAvailable(false)

    if not (GetWeapons.NeedsWeapon(bot) or desperateForWeapon) then return false end

    return (
        GetWeapons.AssignTargetWeapon(bot)
        or bot.botTargetWeapon ~= nil
    )
end

--- Drop the weapon occupying the given slot kind so we can pick up a new one.
---@param bot Bot
---@param slotKind number The weapon Kind (2=secondary, 3=primary, 7=special)
function GetWeapons.DropBlockingWeapon(bot, slotKind)
    local weapons = bot:GetWeapons()
    for _, wep in pairs(weapons) do
        if IsValid(wep) and wep.Kind == slotKind and wep.AllowDrop then
            -- Use TTT2's SafeDropWeapon if available, otherwise manual drop.
            if bot.SafeDropWeapon then
                bot:SafeDropWeapon(wep, true)
            else
                bot:DropWeapon(wep)
            end
            return true
        end
    end
    return false
end

---Sets the bot.botTargetWeapon field to the nearest weapon, else nil. Returns true if it found one.
---@param bot Bot
---@return boolean success
function GetWeapons.AssignTargetWeapon(bot)
    local neededWeapon = GetWeapons.GetNeededWeapon(bot)
    local weapons = (neededWeapon == "primary") and globalPrimaries or 
                    (neededWeapon == "secondary") and globalSecondaries or 
                    globalSpecials

    local closestWeapon = nil
    local closestDistance = math.huge

    for k, v in pairs(weapons) do
        if not GetWeapons.IsAvailable(v) then continue end
        local distance = bot:GetPos():DistToSqr(v:GetPos())
        if distance < closestDistance then
            closestWeapon = v
            closestDistance = distance
        end
    end

    bot.botTargetWeapon = closestWeapon
    return closestWeapon ~= nil
end

---@param bot Bot
---@return BStatus
function GetWeapons.OnStart(bot)
    bot.getWeaponsStartTime = CurTime()
    return STATUS.RUNNING
end

-- Distance at which the bot walks directly toward the weapon instead of full
-- pathfinding. Must be larger than PathManager.completeRange (~28) so the bot
-- does not oscillate when the locomotor thinks the goal is already reached.
local DIRECT_WALK_DIST = 120
-- Distance at which the server-side Give() pickup is attempted.
local PICKUP_DIST_GW = 60

-- How long (seconds) before the bot drops its current weapon to make room.
local DROP_BLOCKING_TIMEOUT = 3

---@param bot Bot
---@return BStatus
function GetWeapons.OnRunning(bot)
    local target = bot.botTargetWeapon

    if not (target and GetWeapons.IsAvailable(target)) then
        bot.botTargetWeapon = nil
        return STATUS.FAILURE
    end

    local loco = bot:BotLocomotor()
    local targetPos = target:GetPos()
    local dist = bot:GetPos():Distance(targetPos)

    -- Close enough — pick up using TTT2's SafePickupWeapon for proper slot handling.
    if dist <= PICKUP_DIST_GW then
        loco:StopMoving()
        loco:SetUse(true)
        loco:LookAt(targetPos)

        -- If we've been trying for too long, drop the blocking weapon first.
        local elapsed = CurTime() - (bot.getWeaponsStartTime or CurTime())
        if elapsed >= DROP_BLOCKING_TIMEOUT and target.Kind then
            GetWeapons.DropBlockingWeapon(bot, target.Kind)
        end

        -- Try TTT2's SafePickupWeapon (handles slot conflicts, drops blocking wep).
        if bot.SafePickupWeapon then
            local result = bot:SafePickupWeapon(target, false, true, true, nil)
            if IsValid(result) then
                bot.botTargetWeapon = nil
                return STATUS.SUCCESS
            end
        end

        -- Fallback: raw Give() + Remove() for non-TTT2 environments.
        local class = target:GetClass()
        if class ~= "" then
            local given = bot:Give(class)
            if IsValid(given) then
                target:Remove()
                bot.botTargetWeapon = nil
                return STATUS.SUCCESS
            end
        end

        -- Pickup failed but we're in range — keep trying.
        return STATUS.RUNNING
    end

    -- Inside the direct-walk zone: bypass pathfinding (which would clear the
    -- goal at ~28 units) and walk straight toward the weapon.
    if dist <= DIRECT_WALK_DIST then
        loco:SetGoal(nil) -- clear any stale pathfinding goal
        loco:SetPriorityGoal(targetPos, PICKUP_DIST_GW)
        loco:LookAt(targetPos)
        return STATUS.RUNNING
    end

    loco:SetUse(false)
    loco:SetGoal(targetPos)

    return STATUS.RUNNING
end

---@param bot Bot
function GetWeapons.OnEnd(bot)
    bot:BotLocomotor():StopMoving()
    bot.getWeaponsStartTime = nil
end

---@param bot Bot
function GetWeapons.OnSuccess(bot) end

---@param bot Bot
function GetWeapons.OnFailure(bot) end

---Tests for validity and returns if a weapon can be currently picked up
---@param ent Entity?
---@return boolean
function GetWeapons.IsAvailable(ent)
    if not (ent and IsValid(ent)) then return false end
    if not ent:IsWeapon() then return false end

    ---@cast ent Weapon

    -- Skip unavailable weapons
    if ent:GetOwner() ~= nil then return false end

    -- If it ain't droppable then it aint' pickable.
    if not ent.AllowDrop then return false end
    if not ent.Kind then return false end

    return true
end

function GetWeapons.UpdateCache()
    globalWeapons = {}
    globalPrimaries = {}
    globalSecondaries = {}
    globalSpecials = {}
    for k, v in pairs(ents.GetAll()) do
        if not GetWeapons.IsAvailable(v) then continue end

        table.insert(globalWeapons, v)

        local kindTable = {
            [2] = globalSecondaries,
            [3] = globalPrimaries,
            [7] = globalSpecials,
        }

        if kindTable[v.Kind] then
            table.insert(kindTable[v.Kind], v)
        end
    end
end

timer.Create("TTTBots.Weapons.UpdateCache", 3, 0, GetWeapons.UpdateCache)
hook.Add("TTTBeginRound", "TTTBots.Weapons.UpdateCacheRound", GetWeapons.UpdateCache)
