--- fakeinvestigate.lua
--- FakeInvestigate behavior — Traitor-only.
--- The traitor visits a corpse they killed and announces fake "findings" to
--- blend in with innocent investigators.

---@class BFakeInvestigate
TTTBots.Behaviors.FakeInvestigate = {}

local lib = TTTBots.Lib
---@class BFakeInvestigate
local FakeInvestigate = TTTBots.Behaviors.FakeInvestigate
FakeInvestigate.Name         = "FakeInvestigate"
FakeInvestigate.Description  = "Visit your own kill's corpse and announce false findings."
FakeInvestigate.Interruptible = true

local STATUS = TTTBots.STATUS

-- Delay (seconds) before a traitor will fake-investigate their own kill
local DELAY_BEFORE_VISIT = 10
-- Only do this occasionally, not every kill
local VISIT_CHANCE_PCT   = 50

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

--- Returns the last kill the bot performed that has an undiscovered corpse.
---@param bot Bot
---@return Entity? corpse
local function getOwnUndiscoveredCorpse(bot)
    local corpses = TTTBots.Match.Corpses
    if not corpses then return nil end
    for _, corpse in pairs(corpses) do
        if not IsValid(corpse) then continue end
        if CORPSE.GetFound(corpse, false) then continue end  -- already discovered
        local killerEnt = CORPSE.GetPlayer(corpse, "killer")
        if IsValid(killerEnt) and killerEnt == bot then
            return corpse
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Behavior Interface
---------------------------------------------------------------------------

function FakeInvestigate.Validate(bot)
    if not isEnabled() then return false end
    if not lib.IsPlayerAlive(bot) then return false end
    if not isTraitor(bot) then return false end
    if bot.attackTarget then return false end

    -- Don't walk to our own kill immediately — wait for a bit so it's less obvious
    local lastKillTime = bot.lastKillTime or 0
    if (CurTime() - lastKillTime) < DELAY_BEFORE_VISIT then return false end

    local state = TTTBots.Behaviors.GetState(bot, "FakeInvestigate")

    -- Already have a valid pending visit target
    if state.corpse and IsValid(state.corpse) and not CORPSE.GetFound(state.corpse, false) then
        return true
    end

    -- Random chance gate (don't do this on every eligible kill)
    if not lib.TestPercent(VISIT_CHANCE_PCT) then return false end

    local corpse = getOwnUndiscoveredCorpse(bot)
    if not corpse then return false end

    state.corpse = corpse
    return true
end

function FakeInvestigate.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "FakeInvestigate")
    state.startTime = CurTime()
    state.chatted   = false

    -- Chatter: fake investigation announcement before even walking there
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        local victimEnt = state.corpse and CORPSE.GetPlayer(state.corpse)
        local victimName = (IsValid(victimEnt) and victimEnt:Nick())
            or (state.corpse and CORPSE.GetPlayerNick(state.corpse))
            or "someone"
        chatter:On("FakeInvestigateApproach", { player = victimName }, false, 1)
    end

    return STATUS.RUNNING
end

function FakeInvestigate.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "FakeInvestigate")

    if not state.corpse or not IsValid(state.corpse) then
        return STATUS.FAILURE
    end
    if CORPSE.GetFound(state.corpse, false) then
        -- Someone else found it before us — that's fine, we can still act surprised
        return STATUS.SUCCESS
    end

    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    loco:SetGoal(state.corpse:GetPos())
    loco:LookAt(state.corpse:GetPos())

    local distToBody = bot:GetPos():Distance(state.corpse:GetPos())
    if distToBody < 80 then
        -- "Discover" the body the same way innocents do
        CORPSE.ShowSearch(bot, state.corpse, false, false)
        CORPSE.SetFound(state.corpse, true)

        if not state.chatted then
            state.chatted = true
            local chatter = bot:BotChatter()
            if chatter and chatter.On then
                local victimEnt  = CORPSE.GetPlayer(state.corpse)
                local victimName = (IsValid(victimEnt) and victimEnt:Nick())
                    or CORPSE.GetPlayerNick(state.corpse)
                    or "someone"
                -- Fire fake report — no DNA, blame unknown/redirect suspicion
                chatter:On("FakeInvestigateReport", { player = victimName }, false, 0)
            end
        end

        return STATUS.SUCCESS
    end

    -- Timeout after 20 s
    if (CurTime() - state.startTime) > 20 then return STATUS.FAILURE end

    return STATUS.RUNNING
end

function FakeInvestigate.OnSuccess(bot) end
function FakeInvestigate.OnFailure(bot) end

function FakeInvestigate.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "FakeInvestigate")
end
