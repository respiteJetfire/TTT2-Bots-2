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
    return (
        GetWeapons.NeedsWeapon(bot)
        and (
            GetWeapons.AssignTargetWeapon(bot)
            or bot.botTargetWeapon ~= nil
        )
    )
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
    return STATUS.RUNNING
end

-- Distance at which the bot walks directly toward the weapon instead of full
-- pathfinding. Must be larger than PathManager.completeRange (~28) so the bot
-- does not oscillate when the locomotor thinks the goal is already reached.
local DIRECT_WALK_DIST = 120
-- Distance at which the server-side Give() pickup is attempted.
local PICKUP_DIST_GW = 60

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

    -- Close enough — pick up directly server-side.
    if dist <= PICKUP_DIST_GW then
        loco:StopMoving()
        loco:SetUse(true)
        loco:LookAt(targetPos)
        local class = target:GetClass()
        if class ~= "" then
            local given = bot:Give(class)
            if IsValid(given) then
                target:Remove()
            end
        end
        bot.botTargetWeapon = nil
        return STATUS.SUCCESS
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
