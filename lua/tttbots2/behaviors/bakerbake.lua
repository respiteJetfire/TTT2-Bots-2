--- bakerbake.lua
--- Dedicated baking behavior for Baker bots.
--- The Baker distributes bread by using weapon_ttt2_baker_baking's PrimaryAttack
--- (which throws a bread entity that players can pick up and eat).
---
--- Key mechanics:
---   • PrimaryAttack creates a "baker_bread" entity thrown in front of the baker.
---   • Clip size is 10 (10 breads max). Each throw consumes 1 ammo.
---   • SecondaryAttack forces the Famine transformation immediately.
---   • Players who eat bread get healed and become immune to Famine's starvation.
---   • Once enough bread is eaten (default 5), Baker auto-transforms into Famine.
---
--- Bot strategy:
---   1. Equip the baking weapon
---   2. Find a player to give bread to (prefer isolated non-allies)
---   3. Walk close to them and throw bread (PrimaryAttack)
---   4. When ammo is depleted or transformation threshold is near,
---      consider using SecondaryAttack to force-start Famine early.

if not (TTT2 and ROLE_BAKER) then return end

---@class BakerBake
TTTBots.Behaviors.BakerBake = {}

local lib = TTTBots.Lib

---@class BakerBake
local BakerBake = TTTBots.Behaviors.BakerBake
BakerBake.Name = "BakerBake"
BakerBake.Description = "Distribute bread to players as the Baker"
BakerBake.Interruptible = true

local STATUS = TTTBots.STATUS

--- Optimal bread-throwing distance. Not too close (bread lands on self),
--- not too far (harder to aim). The bread is a thrown physics entity.
local THROW_DIST = 200

--- Maximum distance to consider a player as a bread candidate.
local SEEK_MAXDIST = 4000

--- How many breads we need to have distributed before considering force-famine.
--- (Only force if we've thrown most of our bread and round is progressing.)
local FORCE_FAMINE_AMMO_THRESHOLD = 3

-- ---------------------------------------------------------------------------
-- Target selection
-- ---------------------------------------------------------------------------

--- Returns whether a player is a valid bread recipient.
---@param bot Player
---@param ply Player
---@return boolean
local function isValidBreadTarget(bot, ply)
    if not IsValid(ply) then return false end
    if ply == bot then return false end
    if not lib.IsPlayerAlive(ply) then return false end

    -- Don't throw bread at Horsemen (they can't eat it — Use() rejects TEAM_HORSEMEN)
    if ply.GetTeam and TEAM_HORSEMEN and ply:GetTeam() == TEAM_HORSEMEN then
        return false
    end

    -- Skip players who already have the "well-fed" status (already ate bread)
    if ply.HasStatus and ply:HasStatus("ttt2_ate_bread") then
        return false
    end

    return true
end

--- Find the best player to throw bread at.
--- Prefer players who are nearby, visible, and not already fed.
---@param bot Player
---@return Player|nil bestTarget
local function findBestBreadTarget(bot)
    local botPos = bot:GetPos()
    local alivePlayers = TTTBots.Match.AlivePlayers or {}
    local bestTarget = nil
    local bestScore = -math.huge

    for _, ply in ipairs(alivePlayers) do
        if not isValidBreadTarget(bot, ply) then continue end

        local plyPos = ply:GetPos()
        local dist = botPos:Distance(plyPos)
        if dist > SEEK_MAXDIST then continue end

        -- Base score: prefer closer players
        local score = 10000 - dist

        -- Visibility bonus
        if bot:Visible(ply) then
            score = score + 3000
        end

        -- Prefer players who are already looking at us (more likely to notice bread)
        local toBot = (botPos - plyPos):GetNormalized()
        local plyForward = ply:GetAimVector()
        local dot = plyForward:Dot(toBot)
        if dot > 0.5 then
            score = score + 1000
        end

        if score > bestScore then
            bestScore = score
            bestTarget = ply
        end
    end

    return bestTarget
end

-- ---------------------------------------------------------------------------
-- Ammo & state helpers
-- ---------------------------------------------------------------------------

--- Get remaining bread ammo from the baking weapon.
---@param bot Player
---@return number ammo  Remaining bread count, or 0 if weapon not found
local function getRemainingBread(bot)
    local wep = bot:GetWeapon("weapon_ttt2_baker_baking")
    if not IsValid(wep) then return 0 end
    return wep:Clip1() or 0
end

--- Check if the Baker should force-start Famine (SecondaryAttack).
--- Conditions: low ammo, enough bread distributed, mid-to-late round.
---@param bot Player
---@return boolean
local function shouldForceFamine(bot)
    local remaining = getRemainingBread(bot)

    -- Don't force if we still have plenty of bread
    if remaining > FORCE_FAMINE_AMMO_THRESHOLD then return false end

    -- Check BREAD_DATA for how many have been eaten
    if BREAD_DATA then
        local eaten = BREAD_DATA.amount_eaten or 0
        local threshold = BREAD_DATA.amount_to_famine or 5

        -- If we're close to auto-threshold, just wait for it
        if eaten >= threshold - 1 then return false end

        -- If we've thrown all our bread but not enough was eaten,
        -- and we're running low — force it rather than being helpless.
        if remaining <= 1 and eaten >= 2 then
            return true
        end
    end

    -- If we have 0 ammo, we have no choice but to force or wait
    if remaining <= 0 then
        return true
    end

    return false
end

-- ---------------------------------------------------------------------------
-- Behavior lifecycle
-- ---------------------------------------------------------------------------

--- Validate: only runs while the bot is the Baker and has bread to throw.
---@param bot Player
---@return boolean
function BakerBake.Validate(bot)
    if not IsValid(bot) then return false end
    if not ROLE_BAKER then return false end
    if bot:GetSubRole() ~= ROLE_BAKER then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Must have the baking weapon
    if not bot:HasWeapon("weapon_ttt2_baker_baking") then return false end

    -- If we have no ammo and shouldn't force-famine, nothing to do
    local remaining = getRemainingBread(bot)
    if remaining <= 0 and not shouldForceFamine(bot) then return false end

    -- If we already have a valid target, keep going
    local state = TTTBots.Behaviors.GetState(bot, "BakerBake")
    if state.target and isValidBreadTarget(bot, state.target) then
        return true
    end

    -- Find a new target
    local target = findBestBreadTarget(bot)
    if not target then
        -- No target but should force famine? Still validate.
        if shouldForceFamine(bot) then
            state.forceTransform = true
            return true
        end
        return false
    end

    state.target = target
    state.forceTransform = false
    return true
end

--- Called when the behavior starts.
---@param bot Player
---@return BStatus
function BakerBake.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "BakerBake")

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        if state.forceTransform then
            chatter:On("BakerForceTransform", {})
        elseif state.target then
            chatter:On("BakerBaking", { player = state.target:Nick() })
        end
    end

    return STATUS.RUNNING
end

--- Called each tick while running.
---@param bot Player
---@return BStatus
function BakerBake.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "BakerBake")

    -- Check if bot is still Baker (may have transformed into Famine)
    if bot:GetSubRole() ~= ROLE_BAKER then
        return STATUS.SUCCESS
    end

    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    -- Force-transform mode: equip weapon and use SecondaryAttack
    if state.forceTransform or shouldForceFamine(bot) then
        local inv = bot:BotInventory()
        if inv then inv:PauseAutoSwitch() end

        local wep = bot:GetWeapon("weapon_ttt2_baker_baking")
        if IsValid(wep) then
            bot:SetActiveWeapon(wep)
            -- Fire SecondaryAttack to trigger famine transformation
            loco:StartAttack2()
            timer.Simple(0.5, function()
                if IsValid(bot) then
                    local l = bot:BotLocomotor()
                    if l then l:StopAttack() end
                end
            end)
        end
        return STATUS.SUCCESS
    end

    -- Normal baking mode: approach target and throw bread
    local target = state.target
    if not isValidBreadTarget(bot, target) then
        return STATUS.FAILURE
    end

    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()
    local dist = bot:GetPos():Distance(targetPos)

    -- Navigate towards target
    loco:SetGoal(targetPos)

    -- In throwing range: equip weapon and throw bread
    if dist < THROW_DIST and bot:Visible(target) then
        loco:LookAt(targetEyes)

        -- Equip the baking weapon
        local inv = bot:BotInventory()
        if inv then inv:PauseAutoSwitch() end

        local wep = bot:GetWeapon("weapon_ttt2_baker_baking")
        if IsValid(wep) then
            bot:SetActiveWeapon(wep)

            -- Check we have ammo
            if wep:Clip1() <= 0 then
                -- Out of bread — consider force famine
                if shouldForceFamine(bot) then
                    state.forceTransform = true
                end
                return STATUS.FAILURE
            end

            -- Throw bread (PrimaryAttack)
            loco:StartAttack()

            -- After throwing, pause briefly then look for next target
            timer.Simple(1.2, function()
                if not IsValid(bot) then return end
                local l = bot:BotLocomotor()
                if l then l:StopAttack() end
                local currentState = TTTBots.Behaviors.GetState(bot, "BakerBake")
                if currentState then
                    currentState.target = nil -- Force retarget
                end
            end)

            return STATUS.SUCCESS
        end
    end

    return STATUS.RUNNING
end

--- Called on success.
---@param bot Player
function BakerBake.OnSuccess(bot)
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end
end

--- Called on failure.
---@param bot Player
function BakerBake.OnFailure(bot)
end

--- Called when the behavior ends.
---@param bot Player
function BakerBake.OnEnd(bot)
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end

    -- Resume auto-switch
    local inv = bot:BotInventory()
    if inv and inv.ResumeAutoSwitch then
        inv:ResumeAutoSwitch()
    end

    TTTBots.Behaviors.ClearState(bot, "BakerBake")
end
