--- behaviors/cursedevade.lua
--- Cursed evasion behavior.
--- When the Cursed bot is being attacked or chased, uses its speed advantage
--- to evade rather than fight (since the Cursed can't deal damage).
--- Also exploits damage immunity awareness when applicable.

if not (TTT2 and ROLE_CURSED) then return end

---@class BCursedEvade : BBase
TTTBots.Behaviors.CursedEvade = {}

local lib = TTTBots.Lib

---@class BCursedEvade
local CursedEvade = TTTBots.Behaviors.CursedEvade
CursedEvade.Name = "CursedEvade"
CursedEvade.Description = "Evades attackers using the Cursed's speed advantage."
CursedEvade.Interruptible = true

local STATUS = TTTBots.STATUS

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Find the nearest threatening player (someone aiming at or chasing the bot)
---@param bot Player
---@return Player? threat, number distance
local function FindThreat(bot)
    local botPos = bot:GetPos()
    local nearestThreat = nil
    local nearestDist = math.huge

    for _, ply in ipairs(player.GetAll()) do
        if ply == bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end

        local dist = botPos:Distance(ply:GetPos())
        if dist > 800 then continue end -- Only care about nearby threats

        -- Check if this player is targeting us
        local isTargetingUs = false

        -- Check if they're shooting at us
        if ply.attackTarget == bot then
            isTargetingUs = true
        end

        -- Check if they're looking at us and close
        if not isTargetingUs and dist < 400 then
            local eyeTrace = ply:GetEyeTrace()
            if eyeTrace and eyeTrace.Entity == bot then
                isTargetingUs = true
            end
        end

        if isTargetingUs and dist < nearestDist then
            nearestDist = dist
            nearestThreat = ply
        end
    end

    return nearestThreat, nearestDist
end

--- Get a flee position away from the threat
---@param bot Player
---@param threat Player
---@return Vector?
local function GetFleePosition(bot, threat)
    local botPos = bot:GetPos()
    local threatPos = threat:GetPos()

    -- Calculate direction away from threat
    local awayDir = (botPos - threatPos):GetNormalized()

    -- Try to find a valid position ~600 units away from the threat
    local fleePos = botPos + awayDir * 600

    -- Try a few angles if the direct path is blocked
    local angles = { 0, 45, -45, 90, -90 }
    for _, ang in ipairs(angles) do
        local rotated = awayDir
        rotated:Rotate(Angle(0, ang, 0))
        local testPos = botPos + rotated * 600

        -- Simple ground check
        local tr = util.TraceLine({
            start = testPos + Vector(0, 0, 50),
            endpos = testPos - Vector(0, 0, 100),
            mask = MASK_PLAYERSOLID,
        })

        if tr.Hit and not tr.HitSky then
            return tr.HitPos + Vector(0, 0, 10)
        end
    end

    return fleePos
end

-- ---------------------------------------------------------------------------
-- Behavior Lifecycle
-- ---------------------------------------------------------------------------

function CursedEvade.Validate(bot)
    if bot:GetSubRole() ~= ROLE_CURSED then return false end
    if not lib.IsPlayerAlive(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- If damage immunity is ON, we don't need to evade (we're invincible)
    local damageImmunity = GetConVar("ttt2_cursed_damage_immunity")
        and GetConVar("ttt2_cursed_damage_immunity"):GetBool() or false
    if damageImmunity then return false end

    -- Check if someone is threatening us
    local threat, dist = FindThreat(bot)
    if not threat then return false end

    -- Store threat in state
    local state = TTTBots.Behaviors.GetState(bot, "CursedEvade")
    state.threat = threat
    state.fleePos = GetFleePosition(bot, threat)

    return true
end

function CursedEvade.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "CursedEvade")
    local threat = state.threat

    -- Fire evasion chatter
    if threat and IsValid(threat) then
        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("CursedApproachingMe", { player = threat:Nick() })
        end
    end

    return STATUS.RUNNING
end

function CursedEvade.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "CursedEvade")
    local threat = state.threat
    local fleePos = state.fleePos

    -- Re-check threat validity
    if not threat or not IsValid(threat) or not lib.IsPlayerAlive(threat) then
        return STATUS.SUCCESS -- Threat gone
    end

    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    -- Check distance to threat
    local dist = bot:GetPos():Distance(threat:GetPos())

    -- If we've gotten far enough away, success
    if dist > 700 then
        return STATUS.SUCCESS
    end

    -- Update flee position if threat moved
    if math.random(1, 5) == 1 then
        state.fleePos = GetFleePosition(bot, threat)
        fleePos = state.fleePos
    end

    -- Run away!
    if fleePos then
        loco:SetGoal(fleePos)
    end

    -- Make sure we're not attacking (Cursed can't deal damage anyway)
    loco:StopAttack()

    return STATUS.RUNNING
end

function CursedEvade.OnSuccess(bot)
end

function CursedEvade.OnFailure(bot)
end

function CursedEvade.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "CursedEvade")
    local loco = bot:BotLocomotor()
    if loco then
        loco:SetGoal(nil)
    end
end
