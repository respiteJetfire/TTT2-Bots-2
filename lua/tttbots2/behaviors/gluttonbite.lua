--- gluttonbite.lua
--- Behavior for Glutton bots: manage hunger through combat and corpse eating.
---
--- The Glutton's hunger ticks down 1/sec. When hungry, the bite weapon deals
--- more damage and the bot moves faster. At 0 hunger, the bot transforms.
---
--- Priority order:
---   1. If hunger is CRITICAL (≤20), immediately find and attack the nearest enemy.
---   2. If hunger is LOW (≤60) and there's a nearby corpse, eat it (secondary fire).
---   3. If hunger is LOW (≤60) and no corpse, attack the nearest enemy.
---   4. Otherwise, let normal traitor behavior handle combat (fallback to FAILURE).

if not (TTT2 and ROLE_GLUTTON) then return end

---@class BGluttonBite
TTTBots.Behaviors.GluttonBite = {}

local lib = TTTBots.Lib

---@class BGluttonBite
local GBite = TTTBots.Behaviors.GluttonBite
GBite.Name = "GluttonBite"
GBite.Description = "Manage hunger: bite enemies and eat corpses"
GBite.Interruptible = true

local STATUS = TTTBots.STATUS

--- Hunger level at which we must act immediately.
local HUNGER_CRITICAL = 20
--- Hunger level at which we start actively seeking food.
local HUNGER_LOW = 60
--- Maximum hunger (assume 180 — top of default range).
local HUNGER_MAX = 180

--- Corpse eat range (secondary fire melee trace range from addon).
local EAT_RANGE = 150
--- Attack range for bite weapon.
local BITE_RANGE = 80

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

---@param bot Player
---@return number
local function getHunger(bot)
    return bot:GetNWInt("Hunger_Level", HUNGER_MAX)
end

--- Find the nearest corpse (ragdoll) that can be eaten.
---@param bot Player
---@return Entity|nil
local function findNearestCorpse(bot)
    local botPos = bot:GetPos()
    local best, bestDist = nil, EAT_RANGE

    for _, ent in ipairs(ents.FindInSphere(botPos, EAT_RANGE)) do
        if not IsValid(ent) then continue end
        -- Ragdolls are class prop_ragdoll; TTT2 corpses use PlayerCorpse or similar
        local class = ent:GetClass()
        if class ~= "prop_ragdoll" and class ~= "ttt_c4" then
            if not (ent.PlayerCorpse or ent.CPPIGetOwner) then continue end
        end
        if class ~= "prop_ragdoll" then continue end

        local dist = botPos:Distance(ent:GetPos())
        if dist < bestDist then
            bestDist = dist
            best = ent
        end
    end

    return best
end

--- Find the nearest enemy to bite.
---@param bot Player
---@return Player|nil
local function findNearestEnemy(bot)
    local botPos = bot:GetPos()
    local best, bestDist = nil, math.huge

    for _, ply in ipairs(TTTBots.Match.AlivePlayers or {}) do
        if not IsValid(ply) then continue end
        if ply == bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then continue end

        local dist = botPos:Distance(ply:GetPos())
        if dist < bestDist then
            bestDist = dist
            best = ply
        end
    end

    return best
end

-- ---------------------------------------------------------------------------
-- Behavior interface
-- ---------------------------------------------------------------------------

function GBite.Validate(bot)
    if not IsValid(bot) then return false end
    if not ROLE_GLUTTON then return false end
    if bot:GetSubRole() ~= ROLE_GLUTTON then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    local hunger = getHunger(bot)
    return hunger <= HUNGER_LOW
end

function GBite.OnStart(bot)
    -- Hunger-driven chatter
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        local hunger = getHunger(bot)
        if hunger <= HUNGER_CRITICAL then
            chatter:On("GluttonBiting", {}, true)
        elseif math.random(1, 3) == 1 then
            chatter:On("GluttonBiting", {}, true)
        end
    end
    return STATUS.RUNNING
end

function GBite.OnRunning(bot)
    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    local hunger = getHunger(bot)

    -- Hunger restored; stop urgency hunting
    if hunger > HUNGER_LOW then
        return STATUS.FAILURE
    end

    -- Equip bite weapon
    local biteWep = bot:GetWeapon("weapon_ttt_glut_bite")
    if IsValid(biteWep) then
        bot:SetActiveWeapon(biteWep)
        inv:PauseAutoSwitch()
    end

    local botPos = bot:GetPos()

    -- ── Try to eat a nearby corpse ─────────────────────────────────────────
    local corpse = findNearestCorpse(bot)
    if corpse and IsValid(corpse) then
        local dist = botPos:Distance(corpse:GetPos())
        loco:SetGoal(corpse:GetPos())
        loco:LookAt(corpse:GetPos() + Vector(0, 0, 20))

        if dist <= EAT_RANGE and bot:VisibleVec(corpse:GetPos()) then
            -- Secondary fire = eat
            loco:StartSecondaryAttack()
            timer.Simple(0.2, function()
                if IsValid(bot) then loco:StopAttack() end
            end)
            return STATUS.RUNNING
        end
    end

    -- ── Find enemy to bite ─────────────────────────────────────────────────
    local enemy = findNearestEnemy(bot)
    if enemy then
        local memory = bot.components and bot.components.memory
        if memory then
            memory:UpdateKnownPositionFor(enemy, enemy:GetPos())
        end
        local PRI = TTTBots.Morality and TTTBots.Morality.PRIORITY
        -- Critical hunger: use self-defense priority (5)
        -- Low hunger: use role hostility priority (3)
        local pri = (hunger <= HUNGER_CRITICAL)
            and (PRI and PRI.SELF_DEFENSE or 5)
            or  (PRI and PRI.ROLE_HOSTILITY or 3)
        bot:SetAttackTarget(enemy, "GLUTTON_HUNGRY", pri)
    end

    return STATUS.RUNNING
end

function GBite.OnSuccess(bot)
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end
end

function GBite.OnFailure(bot)
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
end

function GBite.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "GluttonBite")
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end
end
