--- behaviors/evadegravitymine.lua
--- Bot behavior: flee from armed/triggered gravity mines to avoid being
--- pulled in and killed by the explosion.

---@class BEvadeGravityMine
TTTBots.Behaviors.EvadeGravityMine = {}

local lib = TTTBots.Lib
local STATUS = TTTBots.STATUS

local EvadeGravityMine = TTTBots.Behaviors.EvadeGravityMine
EvadeGravityMine.Name = "EvadeGravityMine"
EvadeGravityMine.Description = "Flee from nearby gravity mines"
EvadeGravityMine.Interruptible = true

--- How close a mine must be to trigger evasion (slightly larger than pull radius)
local EVASION_RADIUS = 500
--- A mine that is both pulling and within this range is critical — always evade
local CRITICAL_RADIUS = 300

--- Find the nearest dangerous gravity mine
---@param bot Bot
---@return Entity|nil mine
---@return number distance
local function FindNearestDangerousMine(bot)
    local mines = ents.FindByClass("ent_ttt2_gravity_mine")
    local botPos = bot:GetPos()
    local nearestMine = nil
    local nearestDist = math.huge

    for _, mine in ipairs(mines) do
        if not IsValid(mine) then continue end

        -- Only care about armed mines
        if mine.GetArmed and not mine:GetArmed() then continue end

        -- Skip mines owned by allies
        local mineOwner = mine.GetMineOwner and mine:GetMineOwner()
        if IsValid(mineOwner) then
            if mineOwner == bot then continue end
            if mineOwner.GetTeam and bot.GetTeam then
                if mineOwner:GetTeam() == bot:GetTeam() and mineOwner:GetTeam() ~= TEAM_NONE then
                    continue
                end
            end
        end

        local dist = botPos:Distance(mine:GetPos())
        if dist < nearestDist then
            nearestDist = dist
            nearestMine = mine
        end
    end

    return nearestMine, nearestDist
end

--- Get a flee position away from the mine
---@param bot Bot
---@param minePos Vector
---@return Vector
local function GetFleePosition(bot, minePos)
    local botPos = bot:GetPos()
    local awayDir = (botPos - minePos):GetNormalized()

    -- Try several angles to find valid ground
    local angles = { 0, 30, -30, 60, -60, 90, -90 }
    for _, ang in ipairs(angles) do
        local rotated = Vector(awayDir.x, awayDir.y, 0)
        rotated:Rotate(Angle(0, ang, 0))
        local testPos = botPos + rotated * 600

        local tr = util.TraceLine({
            start = testPos + Vector(0, 0, 50),
            endpos = testPos - Vector(0, 0, 100),
            mask = MASK_PLAYERSOLID,
        })

        if tr.Hit and not tr.HitSky then
            return tr.HitPos + Vector(0, 0, 10)
        end
    end

    -- Fallback: just run directly away
    return botPos + awayDir * 600
end

function EvadeGravityMine.Validate(bot)
    if not IsValid(bot) or not bot:Alive() then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    local mine, dist = FindNearestDangerousMine(bot)
    if not mine then return false end

    -- Always evade if the mine is pulling and we're in range
    local isPulling = mine.GetPulling and mine:GetPulling()
    if isPulling and dist <= EVASION_RADIUS then
        return true
    end

    -- Evade armed but not-yet-triggered mines only if very close
    if dist <= CRITICAL_RADIUS then
        return true
    end

    return false
end

function EvadeGravityMine.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "EvadeGravityMine")
    state.startTime = CurTime()

    local mine = FindNearestDangerousMine(bot)
    if mine then
        state.minePos = mine:GetPos()
        state.fleePos = GetFleePosition(bot, state.minePos)
    end

    -- Chatter: warn about the mine
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("SpottedGravityMine", {}, true)
    end

    return STATUS.RUNNING
end

function EvadeGravityMine.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "EvadeGravityMine")
    local elapsed = CurTime() - (state.startTime or CurTime())

    -- Timeout after 6 seconds (mine should have detonated by then)
    if elapsed > 6.0 then return STATUS.SUCCESS end

    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    -- Re-check: is there still a dangerous mine?
    local mine, dist = FindNearestDangerousMine(bot)
    if not mine then return STATUS.SUCCESS end

    -- Update mine position and flee target periodically
    if math.random(1, 5) == 1 or not state.fleePos then
        state.minePos = mine:GetPos()
        state.fleePos = GetFleePosition(bot, state.minePos)
    end

    -- If we're far enough away, success
    if dist > EVASION_RADIUS + 100 then
        return STATUS.SUCCESS
    end

    -- Run away from the mine
    loco:SetGoal(state.fleePos)
    loco:StopAttack() -- Focus on running, not fighting

    -- If the mine is pulling and we can see it, try to shoot it to trigger early detonation
    -- (only if we're already outside the explosion radius)
    local isPulling = mine.GetPulling and mine:GetPulling()
    if isPulling and dist > 350 and bot:Visible(mine) then
        loco:LookAt(mine:GetPos())
        loco:StartAttack()
    end

    return STATUS.RUNNING
end

function EvadeGravityMine.OnSuccess(bot) end
function EvadeGravityMine.OnFailure(bot) end

function EvadeGravityMine.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "EvadeGravityMine")

    local loco = bot:BotLocomotor()
    if loco then
        loco:StopAttack()
    end
end
