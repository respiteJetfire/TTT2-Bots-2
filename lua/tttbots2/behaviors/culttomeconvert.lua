--- culttomeconvert.lua
--- Dedicated behavior for the Cult Leader role.
--- The Cult Leader uses weapon_ttt_culttome to melee-attack non-cultists,
--- converting them to ROLE_CULTIST on hit. The tome also heals existing cultists.
---
--- Bot strategy:
---   1. Equip the cult tome weapon
---   2. Find a non-cultist, non-cult-leader target (prefer isolated)
---   3. Approach to melee range and use PrimaryAttack
---   4. After converting, find next target or heal existing cultists
---   5. Respect the max conversions limit

if not (TTT2 and ROLE_CULTLEADER) then return end

---@class CultTomeConvert
TTTBots.Behaviors.CultTomeConvert = {}

local lib = TTTBots.Lib

---@class CultTomeConvert
local CultTomeConvert = TTTBots.Behaviors.CultTomeConvert
CultTomeConvert.Name = "CultTomeConvert"
CultTomeConvert.Description = "Use cult tome to convert players or heal cultists"
CultTomeConvert.Interruptible = true

local STATUS = TTTBots.STATUS

--- Melee engagement range for the tome
local MELEE_RANGE = 80

--- Maximum distance to seek a conversion target
local SEEK_MAXDIST = 3000

--- Minimum distance before we start swinging
local SWING_DIST = 65

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Count current alive cultists
local function countCultists()
    local count = 0
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and ROLE_CULTIST and ply:GetSubRole() == ROLE_CULTIST then
            count = count + 1
        end
    end
    return count
end

--- Check if we can still convert (max conversions not reached)
local function canConvert()
    local maxConversions = 2
    if GetConVar("ttt2_cultleader_maxconversions") then
        maxConversions = GetConVar("ttt2_cultleader_maxconversions"):GetInt()
    end
    return countCultists() < maxConversions
end

--- Is target a valid conversion candidate?
---@param bot Player
---@param ply Player
---@return boolean
local function isValidConvertTarget(bot, ply)
    if not IsValid(ply) then return false end
    if ply == bot then return false end
    if not lib.IsPlayerAlive(ply) then return false end
    if ROLE_CULTLEADER and ply:GetSubRole() == ROLE_CULTLEADER then return false end
    if ROLE_CULTIST and ply:GetSubRole() == ROLE_CULTIST then return false end
    return true
end

--- Is target a valid heal candidate (existing cultist)?
---@param bot Player
---@param ply Player
---@return boolean
local function isValidHealTarget(bot, ply)
    if not IsValid(ply) then return false end
    if ply == bot then return false end
    if not lib.IsPlayerAlive(ply) then return false end
    if not ROLE_CULTIST then return false end
    if ply:GetSubRole() ~= ROLE_CULTIST then return false end
    return ply:Health() < ply:GetMaxHealth()
end

--- Find the best target to convert (prefer isolated players).
---@param bot Player
---@return Player|nil
local function findConvertTarget(bot)
    local botPos = bot:GetPos()
    local bestTarget = nil
    local bestScore = -math.huge

    local alivePlayers = TTTBots.Match.AlivePlayers or {}
    for _, ply in ipairs(alivePlayers) do
        if not isValidConvertTarget(bot, ply) then continue end

        local dist = botPos:Distance(ply:GetPos())
        if dist > SEEK_MAXDIST then continue end

        -- Base score: prefer closer players
        local score = 10000 - dist

        -- Prefer visible targets
        if bot:Visible(ply) then
            score = score + 3000
        end

        -- Prefer isolated targets (fewer witnesses)
        local isolation = lib.RateIsolation(bot, ply)
        score = score + isolation * 500

        if score > bestScore then
            bestScore = score
            bestTarget = ply
        end
    end

    return bestTarget
end

--- Find an injured cultist to heal.
---@param bot Player
---@return Player|nil
local function findHealTarget(bot)
    local botPos = bot:GetPos()
    local bestTarget = nil
    local bestScore = -math.huge

    local alivePlayers = TTTBots.Match.AlivePlayers or {}
    for _, ply in ipairs(alivePlayers) do
        if not isValidHealTarget(bot, ply) then continue end

        local dist = botPos:Distance(ply:GetPos())
        if dist > SEEK_MAXDIST then continue end

        -- Prefer closer cultists who need healing more
        local healthRatio = ply:Health() / ply:GetMaxHealth()
        local score = (1 - healthRatio) * 5000 + (10000 - dist)

        if score > bestScore then
            bestScore = score
            bestTarget = ply
        end
    end

    return bestTarget
end

-- ---------------------------------------------------------------------------
-- Behavior lifecycle
-- ---------------------------------------------------------------------------

function CultTomeConvert.Validate(bot)
    if not IsValid(bot) then return false end
    if not ROLE_CULTLEADER then return false end
    if bot:GetSubRole() ~= ROLE_CULTLEADER then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Must have the cult tome weapon
    if not bot:HasWeapon("weapon_ttt_culttome") then return false end

    -- If we can still convert, check for targets
    if canConvert() then
        local target = findConvertTarget(bot)
        if target then return true end
    end

    -- Otherwise check for injured cultists to heal
    local healTarget = findHealTarget(bot)
    if healTarget then return true end

    return false
end

function CultTomeConvert.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "CultTomeConvert")

    -- Pick mode: convert or heal
    if canConvert() then
        state.target = findConvertTarget(bot)
        state.mode = "convert"
    end

    if not state.target then
        state.target = findHealTarget(bot)
        state.mode = "heal"
    end

    if not state.target then
        return STATUS.FAILURE
    end

    local chatter = bot:BotChatter()
    if chatter and chatter.On and state.mode == "convert" then
        chatter:On("CultConvert", { player = state.target:Nick() }, true)
    end

    return STATUS.RUNNING
end

function CultTomeConvert.OnRunning(bot)
    if bot:GetSubRole() ~= ROLE_CULTLEADER then
        return STATUS.SUCCESS
    end

    local state = TTTBots.Behaviors.GetState(bot, "CultTomeConvert")
    local target = state.target

    -- Validate target still valid
    if not IsValid(target) or not lib.IsPlayerAlive(target) then
        return STATUS.FAILURE
    end

    -- In convert mode, check if target is still convertible
    if state.mode == "convert" and not isValidConvertTarget(bot, target) then
        return STATUS.SUCCESS -- Target was converted!
    end

    -- In heal mode, check if target still needs healing
    if state.mode == "heal" and not isValidHealTarget(bot, target) then
        return STATUS.SUCCESS -- Target is healed
    end

    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    local targetPos = target:GetPos()
    local dist = bot:GetPos():Distance(targetPos)

    -- Navigate towards target
    loco:SetGoal(targetPos)

    -- When in melee range, equip tome and swing
    if dist < MELEE_RANGE and bot:Visible(target) then
        loco:LookAt(target:EyePos())

        -- Equip the cult tome
        local inv = bot:BotInventory()
        if inv then inv:PauseAutoSwitch() end

        local wep = bot:GetWeapon("weapon_ttt_culttome")
        if IsValid(wep) then
            bot:SetActiveWeapon(wep)

            -- PrimaryAttack to swing the tome
            loco:StartAttack()
            timer.Simple(0.5, function()
                if IsValid(bot) then
                    local l = bot:BotLocomotor()
                    if l then l:StopAttack() end
                end
            end)
        end

        return STATUS.RUNNING
    end

    return STATUS.RUNNING
end

function CultTomeConvert.OnSuccess(bot)
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end
end

function CultTomeConvert.OnFailure(bot)
end

function CultTomeConvert.OnEnd(bot)
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end

    -- Resume auto-switch
    local inv = bot:BotInventory()
    if inv and inv.ResumeAutoSwitch then
        inv:ResumeAutoSwitch()
    end

    TTTBots.Behaviors.ClearState(bot, "CultTomeConvert")
end
