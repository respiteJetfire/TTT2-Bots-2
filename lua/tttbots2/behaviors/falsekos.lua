--- falsekos.lua
--- FalseKOS behavior — Traitor-only.
--- The traitor calls KOS on a random innocent to sow chaos and confusion.
--- Gated by phase (not EARLY), alive count, and risk assessment.

---@class BFalseKOS
TTTBots.Behaviors.FalseKOS = {}

local lib = TTTBots.Lib
---@class BFalseKOS
local FalseKOS = TTTBots.Behaviors.FalseKOS
FalseKOS.Name         = "FalseKOS"
FalseKOS.Description  = "Call KOS on an innocent player to create chaos."
FalseKOS.Interruptible = true

local STATUS = TTTBots.STATUS

-- Minimum time between false KOS calls (per bot)
local COOLDOWN_SECS    = 90
-- Only trigger if there are at least this many unknowns still alive
local MIN_ALIVE_FOR_KOS = 4

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function isEnabled()
    return TTTBots.Lib.GetConVarBool("deception_enabled")
end

local function isTraitor(bot)
    local role = TTTBots.Roles.GetRoleFor(bot)
    return role and role:GetTeam() == TEAM_TRAITOR
end

--- Returns a suitable innocent target to false-KOS.
--- Avoids allies and players with already-high suspicion weight (it would be too obvious if we pile on).
---@param bot Bot
---@return Player? target
local function pickFalseKOSTarget(bot)
    local nonAllies = TTTBots.Roles.GetNonAllies(bot)
    if not nonAllies or #nonAllies == 0 then return nil end

    -- Prefer players in the "mid suspicion" band — it's more believable
    local evidence = bot:BotEvidence()
    local candidates = {}
    for _, ply in ipairs(nonAllies) do
        if not lib.IsPlayerAlive(ply) then continue end
        local weight = evidence and evidence:EvidenceWeight(ply) or 0
        -- Don't pick someone who already looks highly suspicious (too obvious)
        -- Don't pick someone who is confirmed trustworthy (backfire risk)
        if weight >= 0 and weight < 7 then
            table.insert(candidates, ply)
        end
    end

    if #candidates == 0 then return nil end
    return candidates[math.random(1, #candidates)]
end

---------------------------------------------------------------------------
-- Behavior Interface
---------------------------------------------------------------------------

function FalseKOS.Validate(bot)
    if not isEnabled() then return false end
    if not lib.IsPlayerAlive(bot) then return false end
    if not isTraitor(bot) then return false end
    if bot.attackTarget then return false end

    -- Phase gate: only MID or LATE (not EARLY — too suspicious; not OVERTIME — too obvious)
    local ra = bot:BotRoundAwareness()
    if ra then
        local PHASE = TTTBots.Components.RoundAwareness.PHASE
        local phase = ra:GetPhase()
        if phase == PHASE.EARLY or phase == PHASE.OVERTIME then return false end
    end

    -- Alive count gate
    if #(TTTBots.Match.AlivePlayers or {}) < MIN_ALIVE_FOR_KOS then return false end

    -- Per-bot cooldown
    if (CurTime() - (bot.lastFalseKOSTime or 0)) < COOLDOWN_SECS then return false end

    -- Low probability gate — only trigger occasionally
    if not lib.TestPercent(8) then return false end

    local state  = TTTBots.Behaviors.GetState(bot, "FalseKOS")
    local target = pickFalseKOSTarget(bot)
    if not target then return false end
    state.target = target

    return true
end

function FalseKOS.OnStart(bot)
    local state   = TTTBots.Behaviors.GetState(bot, "FalseKOS")
    local target  = state.target
    local chatter = bot:BotChatter()

    if not (IsValid(target) and lib.IsPlayerAlive(target) and chatter and chatter.On) then
        return STATUS.FAILURE
    end

    -- Stamp cooldown immediately so we don't call it multiple times in quick succession
    bot.lastFalseKOSTime = CurTime()

    -- Fire the false KOS chatter event
    chatter:On("FalseKOS", { player = target:Nick(), playerEnt = target }, false, 0)

    -- Also add a small SUSPICIOUS_MOVEMENT evidence stub against the target in bots'
    -- evidence so that the false accusation has some mechanical backing.
    for _, otherBot in ipairs(TTTBots.Bots) do
        if not (IsValid(otherBot) and lib.IsPlayerAlive(otherBot)) then continue end
        if TTTBots.Roles.IsAllies(bot, otherBot) then continue end
        local ev = otherBot.BotEvidence and otherBot:BotEvidence()
        if ev then
            ev:AddEvidence({
                type    = "KOS_CALLED_BY",
                subject = target,
                detail  = "KOS call by " .. bot:Nick(),
                weight  = 2,  -- modest: innocent bots may still doubt it
            })
        end
    end

    return STATUS.SUCCESS  -- one-shot, no need to run continuously
end

function FalseKOS.OnRunning(bot)  return STATUS.SUCCESS end
function FalseKOS.OnSuccess(bot) end
function FalseKOS.OnFailure(bot) end

function FalseKOS.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "FalseKOS")
end
