--- necrodefib.lua
--- Dedicated defib behavior for the Necromancer's `weapon_ttth_necrodefi`.
--- Unlike the generic Defib behavior, this uses the weapon's actual attack
--- mechanics so that the base defibrillator's OnRevive → AddZombie() callback
--- fires correctly, converting the dead player into a zombie.
--- Includes witness checking, corpse prioritization, and round-phase awareness.

---@class BNecroDefib
TTTBots.Behaviors.NecroDefib = {}

local lib = TTTBots.Lib

---@class BNecroDefib
local NecroDefib = TTTBots.Behaviors.NecroDefib
NecroDefib.Name = "NecroDefib"
NecroDefib.Description = "Use the Necro Defibrillator to revive a corpse as a zombie."
NecroDefib.Interruptible = true
NecroDefib.WeaponClasses = { "weapon_ttth_necrodefi" }

local STATUS = TTTBots.STATUS

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

--- Maximum range to search for corpses.
local SEARCH_RANGE = 3000
--- How close the bot needs to be to the corpse spine to begin defibbing.
local CLOSE_THRESHOLD = 80
--- How far the bot can drift before we cancel a started revive.
local CANCEL_THRESHOLD = 200
--- Behavior timeout in seconds.
local BEHAVIOR_TIMEOUT = 45
--- Maximum witnesses allowed before the bot aborts (early game).
local MAX_WITNESSES_EARLY = 1
--- Maximum witnesses allowed in late/overtime phases (more aggressive).
local MAX_WITNESSES_LATE = 3
--- Revive time for the necro defi (default 3s, matches cvar ttt_necro_defibrillator_revive_time).
local REVIVE_HOLD_TIME = 3.5

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Check if the bot has a necro defi.
---@param bot Bot
---@return boolean
function NecroDefib.HasNecroDefi(bot)
    for _, class in ipairs(NecroDefib.WeaponClasses) do
        if bot:HasWeapon(class) then return true end
    end
    return false
end

--- Get the necro defi weapon entity.
---@param bot Bot
---@return Weapon?
function NecroDefib.GetNecroDefi(bot)
    for _, class in ipairs(NecroDefib.WeaponClasses) do
        local wep = bot:GetWeapon(class)
        if IsValid(wep) then return wep end
    end
    return nil
end

--- Check if the bot is a necromancer (not a zombie).
---@param bot Bot
---@return boolean
local function isNecromancer(bot)
    if not IsValid(bot) then return false end
    if TTTBots.Roles.IsNecroMaster then
        return TTTBots.Roles.IsNecroMaster(bot)
    end
    -- Fallback: check subrole directly
    return ROLE_NECROMANCER and bot:GetSubRole() == ROLE_NECROMANCER
end

--- Get the spine position of a ragdoll for positioning.
---@param rag Entity
---@return Vector
function NecroDefib.GetSpinePos(rag)
    local default = rag:GetPos()
    local spineName = "ValveBiped.Bip01_Spine"
    local spine = rag:LookupBone(spineName)
    if spine then
        return rag:GetBonePosition(spine)
    end
    return default
end

--- Count non-allied witnesses near a position.
---@param bot Bot
---@param pos Vector
---@return number
local function countWitnesses(bot, pos)
    local nonAllies = TTTBots.Roles.GetNonAllies(bot)
    local witnesses = lib.GetAllWitnessesBasic(pos, nonAllies, bot)
    return table.Count(witnesses)
end

--- Get the maximum allowed witnesses based on round phase.
---@param bot Bot
---@return number
local function getMaxWitnesses(bot)
    local ra = bot.BotRoundAwareness and bot:BotRoundAwareness()
    if ra then
        local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
        if PHASE then
            local phase = ra:GetPhase()
            if phase == PHASE.LATE or phase == PHASE.OVERTIME then
                return MAX_WITNESSES_LATE
            end
        end
    end
    return MAX_WITNESSES_EARLY
end

--- Find the best corpse to revive. Necromancers revive ANY dead player (not ally-only).
--- Prefers isolated corpses with fewer witnesses.
---@param bot Bot
---@return Player? target
---@return Entity? ragdoll
function NecroDefib.FindBestCorpse(bot)
    -- First try: visible corpses within range
    local closest, rag = lib.GetClosestRevivable(bot, false, true, true, SEARCH_RANGE)
    if closest and rag then
        return closest, rag
    end

    -- Fallback: any corpse, no visibility filter
    closest, rag = lib.GetClosestRevivable(bot, false, false, true, SEARCH_RANGE)
    return closest, rag
end

-- ---------------------------------------------------------------------------
-- Behavior interface
-- ---------------------------------------------------------------------------

function NecroDefib.Validate(bot)
    if not TTTBots.Lib.IsTTT2() then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not isNecromancer(bot) then return false end
    if bot.preventDefib then return false end

    -- Must have the necro defi
    if not NecroDefib.HasNecroDefi(bot) then return false end

    -- Check if weapon still has clip
    local defi = NecroDefib.GetNecroDefi(bot)
    if defi and defi.Clip1 and defi:Clip1() <= 0 then return false end

    -- Re-use existing target if valid
    if bot.necroDefibTarget and bot.necroDefibRag then
        if lib.IsValidBody(bot.necroDefibRag) then
            return true
        end
    end

    -- Find a new target
    local target, rag = NecroDefib.FindBestCorpse(bot)
    if not (target and rag) then return false end

    -- Check if already claimed by another bot
    if TTTBots.Match.MarkedForDefib[target] and TTTBots.Match.MarkedForDefib[target] ~= bot then
        return false
    end

    bot.necroDefibTarget = target
    bot.necroDefibRag = rag

    return true
end

function NecroDefib.OnStart(bot)
    bot.necroDefibBehaviorStart = CurTime()

    if not bot.necroDefibTarget or not bot.necroDefibRag then
        bot.necroDefibTarget, bot.necroDefibRag = NecroDefib.FindBestCorpse(bot)
    end

    if not (bot.necroDefibTarget and bot.necroDefibRag) then
        return STATUS.FAILURE
    end

    -- Mark the target so other bots don't also try to defib it
    if not TTTBots.Match.MarkedForDefib[bot.necroDefibTarget] then
        TTTBots.Match.MarkedForDefib[bot.necroDefibTarget] = bot
    end

    -- Fire chatter event
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("NecroRevivingZombie", { player = bot.necroDefibTarget:Nick() }, true)
    end

    return STATUS.RUNNING
end

---@param bot Bot
function NecroDefib.OnRunning(bot)
    local inventory, loco = bot:BotInventory(), bot:BotLocomotor()
    if not (inventory and loco) then return STATUS.FAILURE end

    local defi = NecroDefib.GetNecroDefi(bot)
    if not NecroDefib.HasNecroDefi(bot) then return STATUS.FAILURE end
    if defi and defi.Clip1 and defi:Clip1() <= 0 then return STATUS.FAILURE end

    local target = bot.necroDefibTarget
    local rag = bot.necroDefibRag

    -- Timeout check
    if bot.necroDefibBehaviorStart and (CurTime() - bot.necroDefibBehaviorStart) > BEHAVIOR_TIMEOUT then
        return STATUS.FAILURE
    end

    if not (target and rag) then return STATUS.FAILURE end
    if not (IsValid(target) and IsValid(rag)) then return STATUS.FAILURE end
    if not lib.IsValidBody(rag) then return STATUS.FAILURE end

    local ragPos = NecroDefib.GetSpinePos(rag)
    -- Use a ground-level position for navigation so the navmesh lookup resolves
    -- to the correct area.  The spine bone sits ~10-20 units above the floor,
    -- which can map to a neighbouring nav area and stall the path follower.
    local ragGroundPos = Vector(ragPos.x, ragPos.y, rag:GetPos().z)

    -- Navigate to the corpse (ground-level for pathing)
    loco:SetGoal(ragGroundPos)
    loco:LookAt(ragPos)

    -- Use XY distance so the spine's vertical offset doesn't shrink the
    -- effective threshold and prevent the bot from starting the defib.
    local dist = ragGroundPos:Distance(Vector(bot:GetPos().x, bot:GetPos().y, ragGroundPos.z))
    local alreadyStarted = bot.necroDefibStartTime ~= nil

    if dist < CLOSE_THRESHOLD or (alreadyStarted and dist < CANCEL_THRESHOLD) then
        -- Witness check before committing
        if not alreadyStarted then
            local witnessCount = countWitnesses(bot, ragPos)
            local maxWitnesses = getMaxWitnesses(bot)
            if witnessCount > maxWitnesses then
                -- Too many witnesses, wait
                return STATUS.RUNNING
            end
        end

        -- Close enough — equip the necro defi and hold attack
        inventory:PauseAutoSwitch()
        bot:SetActiveWeapon(defi)
        loco:SetGoal()  -- stop moving
        loco:SetHalt(true)
        loco:PauseAttackCompat()
        loco.persistCrouch = true
        loco:Crouch(true)
        loco:PauseRepel()
        -- Look at ground level of corpse, not elevated spine
        local lookTarget = ragGroundPos + Vector(0, 0, 5)
        loco:LookAt(lookTarget, 2)

        -- Start the defib hold timer
        if bot.necroDefibStartTime == nil then
            bot.necroDefibStartTime = CurTime()
            -- Use the locomotor attack system to hold +attack on the weapon
            -- The weapon_ttt_defibrillator base class detects the corpse and begins reviving
            loco:StartAttack()
        end

        -- Wait for the revive time (weapon handles the actual revive via its Think/Attack)
        if bot.necroDefibStartTime + REVIVE_HOLD_TIME < CurTime() then
            -- The weapon should have handled the revive by now via OnRevive → AddZombie
            loco:StopAttack()
            return STATUS.SUCCESS
        end
    else
        -- Not close enough yet — reset if we haven't started
        if not alreadyStarted then
            inventory:ResumeAutoSwitch()
            loco:ResumeAttackCompat()
            loco:SetHalt(false)
            loco:ResumeRepel()
            loco:StopAttack()
            loco.persistCrouch = false
        end
        bot.necroDefibStartTime = nil
    end

    return STATUS.RUNNING
end

function NecroDefib.OnSuccess(bot)
    if TTTBots.Match.MarkedForDefib[bot.necroDefibTarget] then
        TTTBots.Match.MarkedForDefib[bot.necroDefibTarget] = nil
    end
end

function NecroDefib.OnFailure(bot)
end

function NecroDefib.OnEnd(bot)
    if bot.necroDefibTarget and TTTBots.Match.MarkedForDefib[bot.necroDefibTarget] then
        TTTBots.Match.MarkedForDefib[bot.necroDefibTarget] = nil
    end
    bot.necroDefibTarget = nil
    bot.necroDefibRag = nil
    bot.necroDefibStartTime = nil
    bot.necroDefibBehaviorStart = nil

    local inventory, loco = bot:BotInventory(), bot:BotLocomotor()
    if not (inventory and loco) then return end

    loco:StopAttack()
    loco:ResumeAttackCompat()
    loco.persistCrouch = false
    loco:Crouch(false)
    loco:SetHalt(false)
    loco:ResumeRepel()
    inventory:ResumeAutoSwitch()
end
