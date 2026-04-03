--- alienprobe.lua
--- Dedicated probe behavior for Alien bots.
--- The Alien's win condition is to probe a threshold number of unique players
--- using the weapon_ttt2_alien_probe (melee range: 70 hammer units).
---
--- Key mechanics:
---   • The probe weapon heals living players (50 HP by default) and fires
---     EVENT_ALIEN_PROBE hook on hit — the addon handles probe tracking.
---   • Both living players AND corpses can be probed for the win condition.
---   • The Alien deals 0 player damage and auto-revives on death (20s).
---   • Marker vision shows unprobed targets (addon-managed, not bot-side).
---
--- Bot strategy:
---   1. Find the nearest unprobed living player (isolation-weighted scoring)
---   2. Walk into melee range (< 80 units)
---   3. Equip probe weapon and attack
---   4. Track probed players locally to avoid re-probing

if not (TTT2 and ROLE_ALIEN) then return end

---@class AlienProbe
TTTBots.Behaviors.AlienProbe = {}

local lib = TTTBots.Lib

---@class AlienProbe
local AlienProbe = TTTBots.Behaviors.AlienProbe
AlienProbe.Name = "AlienProbe"
AlienProbe.Description = "Seek and probe players to win as the Alien"
AlienProbe.Interruptible = true

local STATUS = TTTBots.STATUS

--- Interaction distance: probe weapon trace range is 70u, give a small buffer.
local PROBE_RANGE = 80

--- Maximum distance to consider a player as a probe candidate.
local SEEK_MAXDIST = 8000

--- Cooldown between re-targeting attempts (seconds).
local RETARGET_COOLDOWN = 3

-- ---------------------------------------------------------------------------
-- Local probe tracking
-- ---------------------------------------------------------------------------

--- Track which players this bot has already probed this round.
--- The addon tracks this in ALIEN_DATA.probedTable, but we maintain our own
--- lightweight mirror per-bot so the behavior can skip already-probed targets.
---@param bot Player
---@return table probedSet  Set of Player entities that have been probed
local function getProbedPlayers(bot)
    if not bot._alienProbedSet then
        bot._alienProbedSet = {}
    end

    -- Sync from addon data if available
    if ALIEN_DATA and ALIEN_DATA.probedTable then
        for _, ply in ipairs(ALIEN_DATA.probedTable) do
            if IsValid(ply) then
                bot._alienProbedSet[ply] = true
            end
        end
    end

    return bot._alienProbedSet
end

--- Mark a player as probed in the local tracking set.
---@param bot Player
---@param target Player
local function markProbed(bot, target)
    local probed = getProbedPlayers(bot)
    probed[target] = true
end

--- Clear probe tracking (called at behavior end / round reset).
---@param bot Player
local function clearProbedTracking(bot)
    bot._alienProbedSet = nil
end

-- ---------------------------------------------------------------------------
-- Target selection
-- ---------------------------------------------------------------------------

--- Returns whether a player is a valid probe target.
---@param bot Player
---@param ply Player
---@return boolean
local function isValidProbeTarget(bot, ply)
    if not IsValid(ply) then return false end
    if ply == bot then return false end
    if not lib.IsPlayerAlive(ply) then return false end

    -- Skip already-probed players
    local probed = getProbedPlayers(bot)
    if probed[ply] then return false end

    -- Don't probe other aliens (same team)
    if ply.GetSubRole and ROLE_ALIEN and ply:GetSubRole() == ROLE_ALIEN then
        return false
    end

    return true
end

--- Find the best probe target: nearest unprobed player with isolation weighting.
---@param bot Player
---@return Player|nil bestTarget
local function findBestTarget(bot)
    local botPos = bot:GetPos()
    local alivePlayers = TTTBots.Match.AlivePlayers or {}
    local bestTarget = nil
    local bestScore = -math.huge

    for _, ply in ipairs(alivePlayers) do
        if not isValidProbeTarget(bot, ply) then continue end

        local plyPos = ply:GetPos()
        local dist = botPos:Distance(plyPos)
        if dist > SEEK_MAXDIST then continue end

        -- Base score: inversely proportional to distance (closer = better)
        local score = 10000 - dist

        -- Visibility bonus: can see target → much better
        if bot:Visible(ply) then
            score = score + 3000
        end

        -- Isolation bonus: fewer nearby players = easier to approach
        local nearbyCount = 0
        for _, other in ipairs(alivePlayers) do
            if IsValid(other) and other ~= bot and other ~= ply
               and other:GetPos():Distance(plyPos) < 500 then
                nearbyCount = nearbyCount + 1
            end
        end
        score = score - (nearbyCount * 500)

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

--- Validate: only runs while the bot is the Alien and has unprobed targets.
---@param bot Player
---@return boolean
function AlienProbe.Validate(bot)
    if not IsValid(bot) then return false end
    if not ROLE_ALIEN then return false end
    if bot:GetSubRole() ~= ROLE_ALIEN then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- If we already have a valid target in progress, keep going
    local state = TTTBots.Behaviors.GetState(bot, "AlienProbe")
    if state.target and isValidProbeTarget(bot, state.target) then
        return true
    end

    -- Find a new target
    local target = findBestTarget(bot)
    if not target then return false end

    state.target = target
    return true
end

--- Called when the behavior starts.
---@param bot Player
---@return BStatus
function AlienProbe.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "AlienProbe")

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        local name = state.target and state.target:Nick() or "someone"
        chatter:On("AlienSeeking", { player = name })
    end

    return STATUS.RUNNING
end

--- Called each tick while running.
---@param bot Player
---@return BStatus
function AlienProbe.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "AlienProbe")
    local target = state.target

    -- Verify target is still valid
    if not isValidProbeTarget(bot, target) then
        -- Target was probed or died — mark success and find new one next tick
        return STATUS.FAILURE
    end

    -- Check if bot is still Alien
    if bot:GetSubRole() ~= ROLE_ALIEN then
        return STATUS.SUCCESS
    end

    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()
    local dist = bot:GetPos():Distance(targetPos)

    -- Navigate towards target
    loco:SetGoal(targetPos)

    -- Periodically check for better targets (closer / more isolated)
    if not state.lastRetarget then state.lastRetarget = 0 end
    if CurTime() - state.lastRetarget > RETARGET_COOLDOWN then
        state.lastRetarget = CurTime()
        local better = findBestTarget(bot)
        if better and better ~= target then
            -- Only switch if significantly closer
            local currentDist = dist
            local betterDist = bot:GetPos():Distance(better:GetPos())
            if betterDist < currentDist * 0.6 then
                state.target = better
                target = better
                targetPos = target:GetPos()
                targetEyes = target:EyePos()
                dist = bot:GetPos():Distance(targetPos)
            end
        end
    end

    -- In range: equip probe and attack
    if dist < PROBE_RANGE and bot:Visible(target) then
        loco:LookAt(targetEyes)
        loco:SetGoal() -- Stop moving, we're in range

        -- Equip the probe weapon
        local inv = bot:BotInventory()
        if inv then
            inv:PauseAutoSwitch()
        end

        local probeWep = bot:GetWeapon("weapon_ttt2_alien_probe")
        if IsValid(probeWep) then
            bot:SetActiveWeapon(probeWep)
        end

        -- Check eye trace to see if we're aimed at the target
        local eyeTrace = bot:GetEyeTrace()
        local tracedEnt = eyeTrace and eyeTrace.Entity

        if tracedEnt == target then
            loco:StartAttack()

            -- Mark as probed after a short delay (give the weapon time to fire)
            -- The addon handles the actual probe tracking via EVENT_ALIEN_PROBE
            markProbed(bot, target)

            timer.Simple(0.5, function()
                if not IsValid(bot) then return end
                local currentState = TTTBots.Behaviors.GetState(bot, "AlienProbe")
                if currentState and currentState.target == target then
                    currentState.target = nil -- Force retarget next tick
                end
            end)

            return STATUS.SUCCESS
        end

        return STATUS.RUNNING
    end

    return STATUS.RUNNING
end

--- Called on success.
---@param bot Player
function AlienProbe.OnSuccess(bot)
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end
end

--- Called on failure.
---@param bot Player
function AlienProbe.OnFailure(bot)
end

--- Called when the behavior ends (success, failure, or interruption).
---@param bot Player
function AlienProbe.OnEnd(bot)
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end

    -- Resume auto-switch
    local inv = bot:BotInventory()
    if inv and inv.ResumeAutoSwitch then
        inv:ResumeAutoSwitch()
    end

    TTTBots.Behaviors.ClearState(bot, "AlienProbe")
end

--- Round reset: clear probe tracking for all bots.
hook.Add("TTTBeginRound", "TTTBots.AlienProbe.Reset", function()
    for _, bot in ipairs(TTTBots.Bots or {}) do
        if IsValid(bot) then
            clearProbedTracking(bot)
        end
    end
end)
