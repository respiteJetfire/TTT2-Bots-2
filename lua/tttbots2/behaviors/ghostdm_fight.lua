--[[
    GhostDM Fight Behavior for TTT2 Bots
    When a TTT2 bot is in Ghost Deathmatch mode, this behavior makes it
    seek out and fight other ghost players using basic deathmatch tactics.
]]

TTTBots.Behaviors.GhostDMFight = {}

local lib = TTTBots.Lib

---@class BGhostDMFight
local GhostDMFight = TTTBots.Behaviors.GhostDMFight
GhostDMFight.Name = "GhostDMFight"
GhostDMFight.Description = "Fighting other ghosts in Ghost Deathmatch"
GhostDMFight.Interruptible = true

local STATUS = TTTBots.STATUS

--- Check if the GhostDM addon is loaded and this bot is a ghost
---@param bot Bot
---@return boolean
local function IsGhostBot(bot)
    if not GhostDM then return false end
    if not GhostDM.IsGhost then return false end
    return GhostDM.IsGhost(bot)
end

--- Find the nearest other ghost player that is alive
---@param bot Bot
---@return Player|nil
---@return number distance
local function FindNearestGhost(bot)
    local bestTarget = nil
    local bestDist = math.huge

    for _, other in ipairs(player.GetAll()) do
        if other == bot then continue end
        if not IsValid(other) then continue end
        if not other:Alive() then continue end
        if not GhostDM.IsGhost(other) then continue end

        local dist = bot:GetPos():DistToSqr(other:GetPos())
        if dist < bestDist then
            bestDist = dist
            bestTarget = other
        end
    end

    return bestTarget, math.sqrt(bestDist)
end

--- Validate the behavior - only runs when bot is a ghost
function GhostDMFight.Validate(bot)
    if not IsGhostBot(bot) then return false end
    if not bot:Alive() then return false end
    return true
end

--- Called when the behavior is started
function GhostDMFight.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "GhostDMFight")
    state.lastStrafeChange = 0
    state.strafeDir = "left"
    state.wanderAngle = Angle(0, math.random(0, 360), 0)
    state.wanderNextChange = 0
    return STATUS.RUNNING
end

--- Called when the behavior is running
function GhostDMFight.OnRunning(bot)
    if not IsGhostBot(bot) then return STATUS.FAILURE end
    if not bot:Alive() then return STATUS.FAILURE end

    local state = TTTBots.Behaviors.GetState(bot, "GhostDMFight")
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    local target, dist = FindNearestGhost(bot)

    if not IsValid(target) then
        -- No ghost targets found - wander randomly
        GhostDMFight.Wander(bot, loco, state)
        return STATUS.RUNNING
    end

    -- We have a target ghost - engage
    GhostDMFight.EngageGhost(bot, loco, target, dist, state)

    return STATUS.RUNNING
end

--- Wander around when no ghost targets are available
---@param bot Bot
---@param loco CLocomotor
---@param state table
function GhostDMFight.Wander(bot, loco, state)
    loco:StopAttack()
    loco.stopLookingAround = false

    -- Pick a random nav area to wander to
    local curTime = CurTime()
    if curTime > (state.wanderNextChange or 0) then
        local randomNav = TTTBots.Behaviors.Wander.GetAnyRandomNav(bot)
        if IsValid(randomNav) then
            loco:SetGoal(randomNav:GetCenter())
        end
        state.wanderNextChange = curTime + math.random(3, 8)
    end
end

--- Engage a ghost target in combat
---@param bot Bot
---@param loco CLocomotor
---@param target Player
---@param dist number
---@param state table
function GhostDMFight.EngageGhost(bot, loco, target, dist, state)
    local curTime = CurTime()
    loco.stopLookingAround = true

    -- Aim at the target
    local aimPos
    local targetCenter = target:GetPos() + Vector(0, 0, 40)
    local targetHead = target:EyePos()

    -- Prefer body shots at close range, head shots at long range
    if dist < 400 then
        aimPos = targetCenter
    else
        aimPos = targetHead
    end

    -- Add slight inaccuracy based on bot personality
    local personality = bot:BotPersonality()
    local difficulty = lib.GetConVarInt("difficulty")
    local inaccuracy = math.max(1, 8 - difficulty) -- Less inaccuracy at higher difficulty
    local aimOffset = VectorRand() * inaccuracy
    aimPos = aimPos + aimOffset

    loco:LookAt(aimPos)

    -- Movement logic
    if dist > 600 then
        -- Far away - path toward target
        loco:SetGoal(target:GetPos())
    elseif dist > 200 then
        -- Medium range - approach while strafing
        loco:SetGoal(target:GetPos())

        -- Change strafe direction periodically
        if curTime > (state.lastStrafeChange or 0) then
            state.strafeDir = state.strafeDir == "left" and "right" or "left"
            state.lastStrafeChange = curTime + math.Rand(0.5, 1.5)
        end
        loco:Strafe(state.strafeDir)
    else
        -- Close range - strafe and fight
        if curTime > (state.lastStrafeChange or 0) then
            state.strafeDir = state.strafeDir == "left" and "right" or "left"
            state.lastStrafeChange = curTime + math.Rand(0.3, 1.0)
        end
        loco:Strafe(state.strafeDir)
    end

    -- Check line of sight and shoot
    local canShoot = bot:Visible(target)
    if canShoot then
        -- Check if we're looking close enough to the target
        local degDiff = math.abs(loco:GetEyeAngleDiffTo(target:GetPos()))
        if degDiff < 15 then
            -- Fire in bursts
            if math.random() > 0.25 then
                loco:StartAttack()
            else
                loco:StopAttack()
            end
        else
            loco:StopAttack()
        end
    else
        loco:StopAttack()
    end

    -- Jump occasionally when in close combat
    if dist < 300 and math.random() > 0.97 then
        loco:Jump(true)
    end
end

--- Called when the behavior returns a success state
function GhostDMFight.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function GhostDMFight.OnFailure(bot)
end

--- Called when the behavior ends
function GhostDMFight.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "GhostDMFight")
    local loco = bot:BotLocomotor()
    if loco then
        loco:StopAttack()
        loco.stopLookingAround = false
    end
end

return true
