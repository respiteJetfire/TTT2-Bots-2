

---@class BStalk
TTTBots.Behaviors.Stalk = {}

local lib = TTTBots.Lib

---@class Bot
---@field StalkTarget Player? The target to stalk
---@field StalkScore number The isolation score of the target

---@class BStalk
local Stalk = TTTBots.Behaviors.Stalk
Stalk.Name = "Stalk"
Stalk.Description = "Stalk a player (or random player) and ultimately kill them."
Stalk.Interruptible = true


local STATUS = TTTBots.STATUS

---Give a weight to how isolated 'other' is to us. This is used to determine who to stalk.
---A higher isolation means the player is more isolated, and thus a better target for stalking.
---@param bot Bot
---@param other Player
---@return number
function Stalk.RateIsolation(bot, other)
    return lib.RateIsolation(bot, other)
end

---Find the best target to stalk, and return it. This is a pretty expensive function, so don't call it too often.
---@param bot Bot
---@return Player?
---@return number
function Stalk.FindTarget(bot)
    return lib.FindIsolatedTarget(bot)
end

function Stalk.ClearTarget(bot)
    TTTBots.Behaviors.GetState(bot, "Stalk").StalkTarget = nil
end

---Sets the target to target, or if target is nil, then it will find a new target. If you want to clear the target, then see Stalk.ClearTarget.
---@see Stalk.ClearTarget
---@param bot Bot
---@param target Player?
---@param isolationScore number?
function Stalk.SetTarget(bot, target, isolationScore)
    local state = TTTBots.Behaviors.GetState(bot, "Stalk")
    state.StalkTarget = target or Stalk.FindTarget(bot)
    state.StalkScore = isolationScore or Stalk.RateIsolation(bot, state.StalkTarget)
end

function Stalk.GetTarget(bot)
    return TTTBots.Behaviors.GetState(bot, "Stalk").StalkTarget
end

---validate if we can attack the bot's target, or the given target if applicable.
---@param bot Bot
---@param target? Player
---@return boolean
function Stalk.ValidateTarget(bot, target)
    local target = target or Stalk.GetTarget(bot)
    local valid = target and IsValid(target) and lib.IsPlayerAlive(target)
    return valid
end

---Should we start stalking? This is only useful for when we don't already have a target. To make the behavior more varied.
---@param bot Bot
---@return boolean
function Stalk.ShouldStartStalking(bot)
    -- local chance = math.random(0, 100) <= 2
    return TTTBots.Match.IsRoundActive() -- and chance
end

---Since situations change quickly, we want to make sure we pick the best target for the situation when we can.
---@param bot Bot
function Stalk.CheckForBetterTarget(bot)
    local state = TTTBots.Behaviors.GetState(bot, "Stalk")
    local currentScore = state.StalkScore or -math.huge
    local alternative, altScore = Stalk.FindTarget(bot)

    if not alternative then return end
    if not Stalk.ValidateTarget(bot, alternative) then return end

    -- check for a difference of at least +1
    if altScore and altScore - currentScore >= 1 then
        Stalk.SetTarget(bot, alternative, altScore)
    end
end

--- Check if the bot has any conversion weapons that haven't been used yet.
--- Used to suppress stalking (killing) in early game for conversion-capable roles.
---@param bot Bot
---@return boolean
function Stalk.HasConversionWeapon(bot)
    if not IsValid(bot) then return false end
    local registry = TTTBots.Behaviors.RoleWeaponRegistry
    if not registry then return false end

    for behaviorName, config in pairs(registry) do
        if config.isConversion then
            -- Check if the bot actually has this conversion weapon
            local hasIt = false
            if config.getWeaponFn then
                local inv = bot:BotInventory()
                if inv then hasIt = config.getWeaponFn(inv) ~= nil end
            elseif config.hasWeaponFn then
                hasIt = config.hasWeaponFn(bot)
            end
            if hasIt then return true end
        end
    end
    return false
end

--- Validate the behavior before we can start it (or continue running)
--- Returning false when the behavior was just running will still call OnEnd.
---@param bot Bot
---@return boolean
function Stalk.Validate(bot)
    if not IsValid(bot) then return false end
    if bot.attackTarget ~= nil then return false end -- Do not stalk if we're killing someone already.

    -- Phase gate: Stalk is a subtle behavior, only use in EARLY and MID phases.
    -- In LATE/OVERTIME, traitors should move to bolder behaviors.
    -- Exception: Infected hosts ALWAYS stalk — their kill mechanic IS stalking.
    local ra = bot:BotRoundAwareness()
    if ra then
        local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
        if PHASE then
            local phase = ra:GetPhase()

            -- EARLY game suppression: if the bot has a conversion weapon, strongly
            -- discourage stalking (killing) so the tree falls through to Convert behaviors.
            -- Infected hosts are exempt — their "stalk" IS the conversion mechanic.
            if phase == PHASE.EARLY then
                local isInfectedHost = TTTBots.Roles.IsInfectedHost
                    and TTTBots.Roles.IsInfectedHost(bot)
                if not isInfectedHost and Stalk.HasConversionWeapon(bot) then
                    -- 90% chance to skip stalking in early game when conversion is available
                    if math.random(1, 10) <= 9 then
                        return false
                    end
                end
            elseif phase == PHASE.MID then
                -- MID game: moderate suppression for conversion-capable bots
                local isInfectedHost = TTTBots.Roles.IsInfectedHost
                    and TTTBots.Roles.IsInfectedHost(bot)
                if not isInfectedHost and Stalk.HasConversionWeapon(bot) then
                    -- 50% chance to skip stalking in mid game when conversion is available
                    if math.random(1, 10) <= 5 then
                        return false
                    end
                end
            elseif phase == PHASE.LATE or phase == PHASE.OVERTIME then
                -- Infected hosts are exempt from the phase gate — stalking IS their core mechanic
                local isInfectedHost = TTTBots.Roles.IsInfectedHost
                    and TTTBots.Roles.IsInfectedHost(bot)
                -- Serial Killers are exempt — their core mechanic IS stalking + knife kills
                local isSerialKiller = bot.GetRoleStringRaw
                    and bot:GetRoleStringRaw() == "serialkiller"
                if isInfectedHost or isSerialKiller then
                    -- Allow stalking to continue for infected hosts / serial killers at all phases
                elseif not ra:IsOvertake() then
                    -- In overtime with overtake advantage, allow stalking to continue (assassinate stragglers)
                    return false
                end
            end
        end
    end

    return Stalk.ValidateTarget(bot) or Stalk.ShouldStartStalking(bot)
end

--- Called when the behavior is started. Useful for instantiating one-time variables per cycle. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function Stalk.OnStart(bot)
    if not Stalk.ValidateTarget(bot) then
        Stalk.SetTarget(bot)
    end

    return STATUS.RUNNING
end

--- Check if the target is looking towards the bot (within a forward arc).
--- Returns true if the target's aim direction faces the bot within the given arc.
---@param target Player
---@param bot Bot
---@param arc number Degrees of full cone (e.g. 90 = 45° each side)
---@return boolean
local function isTargetLookingAtBot(target, bot, arc)
    if not IsValid(target) or not IsValid(bot) then return false end
    local forward = target:GetAimVector()
    local toBot = (bot:EyePos() - target:EyePos()):GetNormalized()
    local angle = math.deg(math.acos(math.Clamp(forward:Dot(toBot), -1, 1)))
    return angle <= (arc / 2)
end

--- Collect witnesses who are actually looking at the area (FOV-aware) or are
--- dangerously close (earshot). This replaces the old 360° VisibleVec check
--- that counted players as witnesses even when they had their backs turned.
---@param bot Bot
---@param pos Vector The position to check (usually the bot's eye position)
---@param nonAllies table<Player> The non-ally player list
---@return table<Player> witnesses
local function getRealisticWitnesses(bot, pos, nonAllies)
    local witnesses = {}
    local EARSHOT_RANGE = 550  -- players this close would hear gunfire regardless of LOS
    local FOV_ARC = 120        -- generous FOV cone for "actually looking this way"

    for _, ply in pairs(nonAllies) do
        if ply == NULL or not IsValid(ply) then continue end
        if ply == bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end

        local dist = ply:GetPos():Distance(pos)

        -- Earshot check: very close players will hear the fight even through walls
        if dist <= EARSHOT_RANGE then
            table.insert(witnesses, ply)
            continue
        end

        -- Beyond earshot, only count as witness if they can see AND are actually
        -- looking towards the position (FOV-aware check via CanSeeArc)
        if dist <= TTTBots.Lib.BASIC_VIS_RANGE then
            if lib.CanSeeArc and lib.CanSeeArc(ply, pos, FOV_ARC) then
                table.insert(witnesses, ply)
            end
        end
    end
    return witnesses
end

--- Called when OnStart or OnRunning returns STATUS.RUNNING. Return STATUS.RUNNING to continue running.
---@param bot Bot
---@return BStatus
function Stalk.OnRunning(bot)
    -- Stalk.CheckForBetterTarget(bot)
    if not Stalk.ValidateTarget(bot) then return STATUS.FAILURE end
    local target = Stalk.GetTarget(bot)
    local targetPos = target:GetPos()
    local targetEyes = target:EyePos()

    local isClose = bot:Visible(target) and bot:GetPos():Distance(targetPos) <= 150
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end
    loco:SetGoal(targetPos)
    if not isClose then return STATUS.RUNNING end
    loco:LookAt(targetEyes)
    loco:SetGoal()

    -- Abort the attack if the target is already looking at the bot.
    -- Stalking should be an ambush — don't lunge while they're staring at us.
    -- In LATE/OVERTIME phases we're more desperate and accept a wider facing angle.
    local ra = bot:BotRoundAwareness()
    local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
    local phase = (ra and PHASE) and ra:GetPhase() or nil

    local targetFacingArc = 90 -- default: abort if target faces within 45° of bot
    if phase and (phase == PHASE.LATE or phase == PHASE.OVERTIME) then
        targetFacingArc = 50 -- more desperate: only abort if staring almost directly at us
    end
    if isTargetLookingAtBot(target, bot, targetFacingArc) then
        return STATUS.RUNNING -- Wait for them to look away
    end

    -- Build the witness list using FOV-aware + earshot checks at the BOT's position
    -- (we care about who can see/hear the bot attacking, not just who can see the target)
    local nonAllies = TTTBots.Perception and TTTBots.Perception.GetPerceivedNonAllies(bot) or TTTBots.Roles.GetNonAllies(bot)
    local witnessesAtBot = getRealisticWitnesses(bot, bot:EyePos(), nonAllies)
    local witnessesAtTarget = getRealisticWitnesses(bot, targetPos, nonAllies)

    -- Merge both witness lists (union) — if anyone can see/hear either position, it's risky
    local witnessSet = {}
    for _, w in ipairs(witnessesAtBot) do witnessSet[w] = true end
    for _, w in ipairs(witnessesAtTarget) do witnessSet[w] = true end
    -- Remove the target from the witness set (they're the victim, not a bystander witness)
    witnessSet[target] = nil
    local witnessCount = table.Count(witnessSet)

    -- Phase-aware witness threshold: EARLY phase requires zero witnesses,
    -- MID allows 1, LATE/OVERTIME allows 1-2.
    local maxWitnesses = 1
    local attackChance = 3 -- 1-in-N chance per tick (adds randomness)
    if phase then
        if phase == PHASE.EARLY then
            maxWitnesses = 0  -- Must be completely alone
            attackChance = 5  -- Lower chance: 1-in-5
        elseif phase == PHASE.MID then
            maxWitnesses = 1
            attackChance = 3
        else
            maxWitnesses = 2
            attackChance = 2  -- More aggressive in LATE/OVERTIME
        end
    end

    -- Endgame override: ≤15 seconds remaining — abandon witness caution and engage immediately
    local raComp = bot.BotRoundAwareness and bot:BotRoundAwareness()
    if raComp and raComp:IsEndgame() then
        bot:SetAttackTarget(target, "STALK_ENDGAME", 5)
        return STATUS.SUCCESS
    end

    if witnessCount <= maxWitnesses then
        if math.random(1, attackChance) == 1 then
            bot:SetAttackTarget(target, "STALK_ATTACK", 4)
            return STATUS.SUCCESS
        end
    end

    return STATUS.RUNNING
end

--- Called when the behavior returns a success state. Only called on success, however.
---@param bot Bot
function Stalk.OnSuccess(bot)
end

--- Called when the behavior returns a failure state. Only called on failure, however.
---@param bot Bot
function Stalk.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function Stalk.OnEnd(bot)
    Stalk.ClearTarget(bot)
    TTTBots.Behaviors.ClearState(bot, "Stalk")
end
