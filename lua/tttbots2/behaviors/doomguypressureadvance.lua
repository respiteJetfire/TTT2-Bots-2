--- doomguypressureadvance.lua
--- Doomguy "pressure advance" behavior.
--- When Doomguy is in active combat (attackTarget is set) and is healthy enough
--- to benefit from life steal, this behavior overrides normal backpedal logic
--- and forces the bot to keep closing distance instead of retreating.
--- It also suppresses the cover-seeking cooldown so Doomguy stays in the fight.
---
--- Design intent:
---   - Life steal means Doomguy is rewarded for staying close and dealing damage.
---   - This behavior removes the cowardly backpedal that hurts shotgun bots.
---   - It also ensures Doomguy does NOT enter SeekCover unless truly overwhelmed.
---
--- This is injected into the Doomguy behavior tree at low priority so it only
--- triggers when AttackTarget is already active.

---@class BDoomguyPressureAdvance
TTTBots.Behaviors.DoomguyPressureAdvance = {}

local lib = TTTBots.Lib
---@class BDoomguyPressureAdvance
local Advance = TTTBots.Behaviors.DoomguyPressureAdvance
Advance.Name = "DoomguyPressureAdvance"
Advance.Description = "Maintain forward pressure while dealing damage as Doomguy."
Advance.Interruptible = true

local STATUS = TTTBots.STATUS

--- Returns true if this bot is playing the Doomguy role.
---@param bot Bot
---@return boolean
local function isDoomguy(bot)
    if not bot then return false end
    local roleStr = bot.GetRoleStringRaw and bot:GetRoleStringRaw() or ""
    return (roleStr == "doomguy" or roleStr == "doomguy_blue" or roleStr == "doomguy_red")
end

--- How healthy Doomguy needs to be to keep pressing.
--- If below this threshold and outnumbered, allow disengaging.
local DISENGAGE_HP_THRESHOLD = 30

--- Max number of visible enemies before Doomguy considers backing off.
local OVERWHELM_ENEMY_COUNT = 3

--- Count how many living non-allies Doomguy can currently see within a radius.
---@param bot Bot
---@param radius number
---@return integer
local function countVisibleEnemies(bot, radius)
    local count = 0
    local botPos = bot:GetPos()
    for _, ply in ipairs(player.GetAll()) do
        if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end
        if ply == bot then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then continue end
        if botPos:Distance(ply:GetPos()) <= radius and bot:Visible(ply) then
            count = count + 1
        end
    end
    return count
end

--- Validate: only for Doomguy, only during active combat.
---@param bot Bot
---@return boolean
function Advance.Validate(bot)
    if not isDoomguy(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not IsValid(bot.attackTarget) then return false end
    return true
end

--- Called when behavior starts.
---@param bot Bot
---@return BStatus
function Advance.OnStart(bot)
    return STATUS.RUNNING
end

--- Main pressure logic runs each tick.
---@param bot Bot
---@return BStatus
function Advance.OnRunning(bot)
    if not isDoomguy(bot) then return STATUS.FAILURE end
    if not IsValid(bot.attackTarget) then return STATUS.FAILURE end

    local hp        = bot:Health()
    local loco      = bot:BotLocomotor() ---@type CLocomotor
    if not loco then return STATUS.FAILURE end

    local visibleEnemies = countVisibleEnemies(bot, 1500)
    local overwhelmed    = visibleEnemies >= OVERWHELM_ENEMY_COUNT and hp < DISENGAGE_HP_THRESHOLD

    if overwhelmed then
        -- Too many enemies and critically low — allow normal disengage / cover.
        -- Clear our cover suppression so SeekCover can take over if needed.
        bot.doomguyPressuring = false
        return STATUS.FAILURE
    end

    -- Mark that we are actively pressuring so other code can react.
    bot.doomguyPressuring = true

    -- Prevent cover-seeking while pressing: clear any cover target assigned by CheckCoverConditions,
    -- unless health is critically low (below 30).
    if hp >= DISENGAGE_HP_THRESHOLD and IsValid(bot.coverTarget) then
        bot.coverTarget = nil
        -- Small cooldown reset so it doesn't immediately re-trigger.
        bot.seekCoverCooldownUntil = CurTime() + 4
    end

    -- Force the locomotor to press forward toward the attack target.
    local target    = bot.attackTarget
    local targetPos = target:GetPos()
    local dist      = bot:GetPos():Distance(targetPos)

    -- Only intervene if we're far enough that backing off would be wasted.
    if dist > 100 then
        loco:SetForceBackward(false)
        -- Don't override goal — AttackTarget.Engage manages exact movement.
        -- Just make sure we're not being pushed backwards by AttackTarget logic.
    end

    -- If the super shotgun is held, ensure we don't snipe — stay in SSG range.
    local inv = bot:BotInventory() ---@type CInventory
    if inv then
        local wep = inv:GetHeldWeaponInfo()
        if wep and wep.class == "weapon_dredux_de_supershotgun" then
            -- SSG ideal engagement range: 80-350 units.
            -- Approach if too far, hold position if in range, stop if too close.
            if dist > 350 then
                loco:SetForceForward(true)
            elseif dist < 80 then
                -- Very close — stop force-forward so we don't run into the target.
                loco:SetForceForward(false)
            else
                -- In ideal SSG range — clear force forward so locomotor manages spacing.
                loco:SetForceForward(false)
            end
        end
    end

    return STATUS.RUNNING
end

--- Called on success.
---@param bot Bot
function Advance.OnSuccess(bot)
    bot.doomguyPressuring = false
end

--- Called on failure.
---@param bot Bot
function Advance.OnFailure(bot)
    bot.doomguyPressuring = false
end

--- Called when behavior ends.
---@param bot Bot
function Advance.OnEnd(bot)
    bot.doomguyPressuring = false
    TTTBots.Behaviors.ClearState(bot, "DoomguyPressureAdvance")
end
