--- DefectorApproach: Navigate toward the best enemy cluster before
--- the Jihad behavior takes over to detonate. The defector bot seeks out
--- groups of non-allied players while avoiding getting too close to allies.
---
--- Validates only for ROLE_DEFECTOR bots that have a jihad bomb and are
--- in MID phase or later (early phase is too risky — maintain cover).
--- Returns SUCCESS once the bot is within detonation range of the cluster,
--- letting the Jihad behavior's Validate pick up from there.

TTTBots.Behaviors.DefectorApproach = {}

local lib = TTTBots.Lib

---@class BDefectorApproach
local BehaviorDefectorApproach = TTTBots.Behaviors.DefectorApproach
BehaviorDefectorApproach.Name = "DefectorApproach"
BehaviorDefectorApproach.Description = "Navigate toward the best enemy cluster for jihad detonation."
BehaviorDefectorApproach.Interruptible = true

local STATUS = TTTBots.STATUS

--- Detonation radius used by the jihad bomb (should match weapon_ttt_jihad_bomb)
local DETONATION_RADIUS = 500
--- How close we need to be to the cluster midpoint before handing off to Jihad
local APPROACH_SUCCESS_DIST = DETONATION_RADIUS * 0.85
--- Minimum number of enemies in the cluster before approaching is worthwhile
local MIN_CLUSTER_SIZE = 2

--- Check if the bot has a jihad bomb
---@param bot Bot
---@return boolean
local function HasJihadBomb(bot)
    return bot:HasWeapon("weapon_ttt_jihad_bomb")
end

--- Score and find the best enemy cluster to approach.
--- Returns the midpoint of the best cluster and the count of enemies near it.
---@param bot Bot
---@return Vector? midpoint
---@return number enemyCount
---@return number allyCount
local function FindBestCluster(bot)
    local alivePlayers = TTTBots.Match.AlivePlayers or player.GetAll()
    local botPos = bot:GetPos()

    -- Gather enemies and allies
    local enemies = {}
    local allies = {}
    for _, ply in pairs(alivePlayers) do
        if not IsValid(ply) then continue end
        if ply == bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end
        -- Skip jesters — we never want to detonate near them
        if TEAM_JESTER and ply:GetTeam() == TEAM_JESTER then continue end

        local isAlly = TTTBots.Roles.IsAllies(bot, ply)
        if isAlly then
            table.insert(allies, ply)
        else
            table.insert(enemies, ply)
        end
    end

    if #enemies < MIN_CLUSTER_SIZE then return nil, 0, 0 end

    -- Use each enemy as a cluster seed and score the surrounding area
    local bestMidpoint = nil
    local bestScore = -math.huge
    local bestEnemyCount = 0
    local bestAllyCount = 0

    for _, seed in ipairs(enemies) do
        local seedPos = seed:GetPos()
        local clusterEnemies = 0
        local clusterAllies = 0
        local midpoint = Vector(0, 0, 0)

        -- Count enemies within detonation radius of this seed
        for _, enemy in ipairs(enemies) do
            if seedPos:Distance(enemy:GetPos()) <= DETONATION_RADIUS then
                clusterEnemies = clusterEnemies + 1
                midpoint = midpoint + enemy:GetPos()
            end
        end

        -- Count allies within detonation radius (penalty)
        for _, ally in ipairs(allies) do
            if seedPos:Distance(ally:GetPos()) <= DETONATION_RADIUS then
                clusterAllies = clusterAllies + 1
            end
        end

        if clusterEnemies < MIN_CLUSTER_SIZE then continue end

        midpoint = midpoint / clusterEnemies

        -- Score: more enemies is better, allies in blast radius is very bad
        -- Net kills = enemies - allies; penalize heavily if allies >= enemies
        local score = clusterEnemies * 10 - clusterAllies * 15

        -- Prefer clusters closer to the bot (less travel time = less suspicion)
        local dist = botPos:Distance(midpoint)
        score = score - (dist / 500) -- Small distance penalty

        if score > bestScore then
            bestScore = score
            bestMidpoint = midpoint
            bestEnemyCount = clusterEnemies
            bestAllyCount = clusterAllies
        end
    end

    return bestMidpoint, bestEnemyCount, bestAllyCount
end

--- Validate the behavior
---@param bot Bot
---@return boolean
function BehaviorDefectorApproach.Validate(bot)
    if not IsValid(bot) then return false end
    if not bot:Alive() then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not ROLE_DEFECTOR then return false end
    if bot:GetSubRole() ~= ROLE_DEFECTOR then return false end
    if not HasJihadBomb(bot) then return false end

    -- Phase check: prefer MID phase or later for approach
    -- In EARLY phase, only approach with reduced chance (blend in, but don't wait forever)
    local ra = bot.BotRoundAwareness and bot:BotRoundAwareness()
    local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
    if ra and PHASE then
        local phase = ra:GetPhase()
        if phase == PHASE.EARLY then
            -- 25% chance to start positioning early; otherwise blend in
            if math.random(1, 100) > 25 then return false end
        end
    end

    -- Check if there's actually a worthwhile cluster to approach
    local midpoint, enemyCount, allyCount = FindBestCluster(bot)
    if not midpoint or enemyCount < MIN_CLUSTER_SIZE then return false end

    -- Don't approach if allies would die (net kills must be positive)
    if allyCount >= enemyCount then return false end

    return true
end

--- Start the behavior
---@param bot Bot
function BehaviorDefectorApproach.OnStart(bot)
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("DefectorApproaching", {}, true) -- team-only
    end
    return STATUS.RUNNING
end

--- Run the behavior — navigate toward the best cluster
---@param bot Bot
---@return STATUS
function BehaviorDefectorApproach.OnRunning(bot)
    if not HasJihadBomb(bot) then return STATUS.FAILURE end

    local midpoint, enemyCount, allyCount = FindBestCluster(bot)
    if not midpoint or enemyCount < MIN_CLUSTER_SIZE then return STATUS.FAILURE end

    -- Abort if allies would be caught in the blast
    if allyCount >= enemyCount then return STATUS.FAILURE end

    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    local dist = bot:GetPos():Distance(midpoint)

    -- If we're close enough to the cluster, hand off to the Jihad behavior
    if dist <= APPROACH_SUCCESS_DIST then
        return STATUS.SUCCESS
    end

    -- Navigate toward the cluster midpoint
    loco:SetGoal(midpoint)

    return STATUS.RUNNING
end

--- End the behavior
---@param bot Bot
function BehaviorDefectorApproach.OnEnd(bot)
    local loco = bot:BotLocomotor()
    if loco then
        loco:SetGoal() -- clear navigation goal
    end
end

function BehaviorDefectorApproach.OnSuccess(bot)
end

function BehaviorDefectorApproach.OnFailure(bot)
end
