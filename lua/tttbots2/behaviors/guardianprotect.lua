--- guardianprotect.lua
--- Dedicated behavior for Guardian bots.
---
--- Phase 1 (Unlinked): Find the nearest valid ward candidate (non-Detective,
---   alive Innocent-team ally) and shoot them with weapon_ttt_guardian_deagle
---   to establish the protection link.
---
--- Phase 2 (Linked): Stay close to the ward. When someone attacks the ward,
---   immediately target the attacker. The deagle auto-recharges (1 shot clip),
---   but since the link persists until the bonus health is exhausted, a second
---   shot is not needed unless the first link expires.

if not (TTT2 and ROLE_GUARDIAN) then return end

---@class BGuardianProtect
TTTBots.Behaviors.GuardianProtect = {}

local lib = TTTBots.Lib

---@class BGuardianProtect
local Protect = TTTBots.Behaviors.GuardianProtect
Protect.Name = "GuardianProtect"
Protect.Description = "Link to an ally with the guardian deagle and follow / defend them"
Protect.Interruptible = true

local STATUS = TTTBots.STATUS

--- Maximum distance to search for ward candidates.
local SEEK_MAXDIST = 4000
--- Target follow distance threshold — stay within this many units of the ward.
local FOLLOW_DIST = 280
--- Distance at which we actually aim and fire the deagle.
local LINK_RANGE  = 600

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Returns true if this bot already has a valid protection link.
---@param bot Player
---@return boolean
local function isLinked(bot)
    -- The addon sets ttt2_guardian_protector on the ward and tracks
    -- the Guardian via guardian_players table in GUARDIAN_DATA.
    if GUARDIAN_DATA and GUARDIAN_DATA.GetGuardedPlayer then
        local ward = GUARDIAN_DATA.GetGuardedPlayer(bot)
        return IsValid(ward) and lib.IsPlayerAlive(ward)
    end
    -- Fallback: check our local state
    local state = TTTBots.Behaviors.GetState(bot, "GuardianProtect")
    return state.ward ~= nil and IsValid(state.ward) and lib.IsPlayerAlive(state.ward)
end

--- Returns the currently linked ward (if any).
---@param bot Player
---@return Player|nil
local function getWard(bot)
    if GUARDIAN_DATA and GUARDIAN_DATA.GetGuardedPlayer then
        local ward = GUARDIAN_DATA.GetGuardedPlayer(bot)
        if IsValid(ward) then return ward end
    end
    local state = TTTBots.Behaviors.GetState(bot, "GuardianProtect")
    if state.ward and IsValid(state.ward) then return state.ward end
    return nil
end

--- Returns true if the target player is a Detective (cannot be protected).
---@param target Player
---@return boolean
local function isDetective(target)
    if not IsValid(target) then return false end
    if not target.GetSubRoleData then return false end
    local data = target:GetSubRoleData()
    return data and data.isPolicingRole and data.defaultTeam == TEAM_INNOCENT
end

--- Score a potential ward candidate.
--- Prefer: visible, close, non-Detective Innocent-team players.
---@param bot Player
---@param ply Player
---@return number score
local function scoreCandidate(bot, ply)
    if not IsValid(ply) then return -math.huge end
    if ply == bot then return -math.huge end
    if not lib.IsPlayerAlive(ply) then return -math.huge end
    if isDetective(ply) then return -math.huge end
    if ply:GetTeam() ~= TEAM_INNOCENT then return -math.huge end

    -- Skip players already protected by another Guardian
    if ply:GetNWEntity("ttt2_guardian_protector", nil) ~= NULL then
        if IsValid(ply:GetNWEntity("ttt2_guardian_protector", nil)) then
            return -math.huge
        end
    end

    local dist = bot:GetPos():Distance(ply:GetPos())
    if dist > SEEK_MAXDIST then return -math.huge end

    local score = 10000 - dist
    if bot:Visible(ply) then score = score + 2000 end
    return score
end

--- Find the best candidate to protect.
---@param bot Player
---@return Player|nil
local function findBestCandidate(bot)
    local best, bestScore = nil, -math.huge
    for _, ply in ipairs(TTTBots.Match.AlivePlayers or {}) do
        local s = scoreCandidate(bot, ply)
        if s > bestScore then
            bestScore = s
            best = ply
        end
    end
    return best
end

-- ---------------------------------------------------------------------------
-- Behavior interface
-- ---------------------------------------------------------------------------

function Protect.Validate(bot)
    if not IsValid(bot) then return false end
    if not ROLE_GUARDIAN then return false end
    if bot:GetSubRole() ~= ROLE_GUARDIAN then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    return true
end

function Protect.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "GuardianProtect")
    state.ward = nil
    state.phase = "SEEKING"
    state.lastRetarget = 0

    -- Announce guardian role
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("GuardianSeeking", {}, false, 0)
    end

    return STATUS.RUNNING
end

function Protect.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "GuardianProtect")
    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    -- ── Phase: SEEKING ─────────────────────────────────────────────────────
    -- Not yet linked. Find and approach a candidate to shoot.
    if not isLinked(bot) then
        state.phase = "SEEKING"

        -- Re-find candidate periodically
        if CurTime() - (state.lastRetarget or 0) > 5 then
            state.lastRetarget = CurTime()
            state.ward = findBestCandidate(bot)
        end

        local ward = state.ward
        if not ward or not IsValid(ward) or not lib.IsPlayerAlive(ward) then
            state.ward = findBestCandidate(bot)
            ward = state.ward
        end

        if not ward then
            return STATUS.FAILURE  -- no valid target, let other behaviors run
        end

        local wardPos = ward:GetPos()
        local dist = bot:GetPos():Distance(wardPos)

        loco:SetGoal(wardPos)

        -- In link range and can see ward — equip deagle and shoot
        if dist <= LINK_RANGE and bot:Visible(ward) then
            loco:LookAt(ward:EyePos())

            -- Equip guardian deagle
            local deagle = bot:GetWeapon("weapon_ttt_guardian_deagle")
            if IsValid(deagle) then
                bot:SetActiveWeapon(deagle)
                inv:PauseAutoSwitch()
            end

            -- Check aim
            local eyeTrace = bot:GetEyeTrace()
            if eyeTrace and eyeTrace.Entity == ward then
                loco:StartAttack()
                -- Mark link attempt locally — the addon fires the actual link
                state.linkAttemptTime = CurTime()
                state.phase = "LINKING"
            end
        end

        return STATUS.RUNNING
    end

    -- ── Phase: FOLLOWING ───────────────────────────────────────────────────
    -- Linked — follow and defend the ward.
    state.phase = "FOLLOWING"
    inv:ResumeAutoSwitch()

    local ward = getWard(bot)
    if not ward or not IsValid(ward) or not lib.IsPlayerAlive(ward) then
        -- Ward died — reset and seek a new one
        state.ward = nil
        state.phase = "SEEKING"
        state.lastRetarget = 0
        return STATUS.RUNNING
    end

    local wardPos = ward:GetPos()
    local dist = bot:GetPos():Distance(wardPos)

    -- If too far, move toward ward
    if dist > FOLLOW_DIST then
        loco:SetGoal(wardPos)
    else
        loco:LookAt(ward:EyePos())
    end

    -- If the ward is being attacked, help fight back
    -- (PlayerHurt hook below also does this, but keep it here as backup)
    if not bot.attackTarget then
        local attacker = ward._guardianAttacker
        if IsValid(attacker) and lib.IsPlayerAlive(attacker) then
            bot:SetAttackTarget(attacker, "GUARDIAN_WARD_DEFENSE", 4)
            ward._guardianAttacker = nil
        end
    end

    return STATUS.RUNNING
end

function Protect.OnSuccess(bot)
end

function Protect.OnFailure(bot)
end

function Protect.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "GuardianProtect")
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end
end

-- ---------------------------------------------------------------------------
-- PlayerHurt hook: when the ward is attacked, Guardian bots respond.
-- ---------------------------------------------------------------------------
hook.Add("PlayerHurt", "TTTBots.GuardianProtect.WardHurt", function(victim, attacker)
    if not TTTBots.Match.IsRoundActive() then return end
    if not (IsValid(victim) and IsValid(attacker)) then return end
    if not attacker:IsPlayer() then return end

    -- Find any Guardian bot guarding this victim
    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and bot:IsBot()) then continue end
        if not ROLE_GUARDIAN then continue end
        if bot:GetSubRole() ~= ROLE_GUARDIAN then continue end

        local ward = getWard(bot)
        if ward == victim then
            -- Tag the attacker for the next OnRunning tick
            victim._guardianAttacker = attacker
            -- Assign immediately if not already in combat
            if not bot.attackTarget then
                bot:SetAttackTarget(attacker, "GUARDIAN_WARD_DEFENSE", 4)
                if bot.components and bot.components.memory then
                    bot.components.memory:UpdateKnownPositionFor(attacker, attacker:GetPos())
                end
            end
        end
    end
end)
