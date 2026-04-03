--- beggarseek.lua
--- Dedicated behavior for the Beggar and Collusionist roles.
--- These jester-team roles need to approach other players and get close to them
--- in the hopes that a player will drop a shop-bought weapon for them to pick up.
--- Picking up a bought weapon triggers a team change (role addon handles this).
---
--- Bot strategy:
---   1. Find an alive player to follow / "beg" from
---   2. Walk close to them, stay nearby and look at them
---   3. Use crowbar minge-style to get attention
---   4. If a dropped weapon is nearby on the ground, try to pick it up
---   5. Once the role changes (team is no longer jester), behavior ends

if not (TTT2) then return end

---@class BeggarSeek
TTTBots.Behaviors.BeggarSeek = {}

local lib = TTTBots.Lib

---@class BeggarSeek
local BeggarSeek = TTTBots.Behaviors.BeggarSeek
BeggarSeek.Name = "BeggarSeek"
BeggarSeek.Description = "Follow players and seek dropped shop weapons as Beggar/Collusionist"
BeggarSeek.Interruptible = true

local STATUS = TTTBots.STATUS

--- How close to get to our beg target
local BEG_DIST = 150

--- Maximum distance to consider a player as a beg target
local SEEK_MAXDIST = 3000

--- Distance to detect dropped shop weapons
local PICKUP_DIST = 300

--- Roles that qualify for this behavior
local BEGGAR_ROLES = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function isBeggarRole(bot)
    if not IsValid(bot) then return false end
    local role = bot:GetSubRole()
    return (ROLE_BEGGAR and role == ROLE_BEGGAR) or (ROLE_COLLUSIONIST and role == ROLE_COLLUSIONIST)
end

--- Find a player to follow and "beg" from.
--- Prefer visible, alive, non-jester-team players.
---@param bot Player
---@return Player|nil
local function findBegTarget(bot)
    local botPos = bot:GetPos()
    local bestTarget = nil
    local bestScore = -math.huge

    local alivePlayers = TTTBots.Match.AlivePlayers or {}
    for _, ply in ipairs(alivePlayers) do
        if not IsValid(ply) then continue end
        if ply == bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end

        local dist = botPos:Distance(ply:GetPos())
        if dist > SEEK_MAXDIST then continue end

        -- Prefer closer players
        local score = 10000 - dist

        -- Prefer visible players
        if bot:Visible(ply) then
            score = score + 3000
        end

        -- Prefer players who look like they might have shop items (detectives etc)
        if ply.GetSubRoleData and ply:GetSubRoleData() then
            local roleData = ply:GetSubRoleData()
            if roleData.isPolicingRole then
                score = score + 2000 -- Detectives are more likely to give items
            end
        end

        if score > bestScore then
            bestScore = score
            bestTarget = ply
        end
    end

    return bestTarget
end

--- Find a dropped weapon on the ground that is shop-bought.
--- The Beggar's team-change triggers when picking up a weapon that has BoughtBy set.
---@param bot Player
---@return Entity|nil
local function findDroppedShopWeapon(bot)
    local botPos = bot:GetPos()
    local bestWep = nil
    local bestDist = PICKUP_DIST

    for _, ent in ipairs(ents.FindInSphere(botPos, PICKUP_DIST)) do
        if not IsValid(ent) then continue end
        if not ent:IsWeapon() then continue end
        if IsValid(ent:GetOwner()) then continue end -- Still held by someone

        -- Check if it's a shop weapon (CanBuy set and not auto-spawnable)
        if ent.CanBuy and not ent.AutoSpawnable and ent.BoughtBy then
            local dist = botPos:Distance(ent:GetPos())
            if dist < bestDist then
                bestDist = dist
                bestWep = ent
            end
        end
    end

    return bestWep
end

-- ---------------------------------------------------------------------------
-- Behavior lifecycle
-- ---------------------------------------------------------------------------

function BeggarSeek.Validate(bot)
    if not IsValid(bot) then return false end
    if not isBeggarRole(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    return true
end

function BeggarSeek.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "BeggarSeek")
    state.target = findBegTarget(bot)
    state.retargetTime = CurTime() + math.random(8, 15)
    return STATUS.RUNNING
end

function BeggarSeek.OnRunning(bot)
    if not isBeggarRole(bot) then
        -- Role changed! The beggar picked up an item and switched teams.
        return STATUS.SUCCESS
    end

    local state = TTTBots.Behaviors.GetState(bot, "BeggarSeek")
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    -- First priority: pick up any dropped shop weapon nearby
    local droppedWep = findDroppedShopWeapon(bot)
    if droppedWep then
        local wepPos = droppedWep:GetPos()
        loco:SetGoal(wepPos)
        loco:LookAt(wepPos)

        local dist = bot:GetPos():Distance(wepPos)
        if dist < 80 then
            -- Try to use/pickup the weapon
            bot:ConCommand("+use")
            timer.Simple(0.2, function()
                if IsValid(bot) then
                    bot:ConCommand("-use")
                end
            end)
        end
        return STATUS.RUNNING
    end

    -- Periodically retarget
    if not state.target or not IsValid(state.target)
        or not lib.IsPlayerAlive(state.target)
        or CurTime() > (state.retargetTime or 0) then
        state.target = findBegTarget(bot)
        state.retargetTime = CurTime() + math.random(8, 15)
    end

    local target = state.target
    if not target then
        -- No one to beg from, just wander
        return STATUS.FAILURE
    end

    local targetPos = target:GetPos()
    local dist = bot:GetPos():Distance(targetPos)

    -- Navigate towards the target
    loco:SetGoal(targetPos)

    -- When close, look at them
    if dist < BEG_DIST and bot:Visible(target) then
        loco:LookAt(target:EyePos())
    end

    return STATUS.RUNNING
end

function BeggarSeek.OnSuccess(bot)
end

function BeggarSeek.OnFailure(bot)
end

function BeggarSeek.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "BeggarSeek")
end
