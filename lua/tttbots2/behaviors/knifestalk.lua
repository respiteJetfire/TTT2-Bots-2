--- knifestalk.lua
--- Knife-Stalk Behavior — Traitor / killer bots exploit the 200-damage knife mod
--- to silently one-hit-kill isolated targets.  After a kill the bot either:
---   (a) uses a role defib on the corpse (if available), or
---   (b) hides/drags the body to conceal the evidence.
---
--- ONLY activates when the 200-damage knife mod is installed (Primary.Damage >= 150
--- on weapon_ttt_knife).  If the mod is not installed the behavior never validates.
---
--- Priority: placed in the traitor tree between TrapPlayer and Support, giving it
--- higher priority than FollowPlan/Deception but lower than combat/self-defense.
---
--- Flow:
---   1. Validate — check mod is installed, bot has knife, round active, no existing target.
---   2. OnStart  — pick the best isolated target.
---   3. OnRunning —
---      a. "stalk"   — path toward target, maintain distance until unobserved.
---      b. "close"   — rush into melee range when target is alone / facing away.
---      c. "attack"  — equip knife, assign attackTarget so AttackTarget takes over.
---      d. "postKill" — after the kill, choose roledefib or body-hide.

---@class BKnifeStalk
TTTBots.Behaviors.KnifeStalk = {}

local lib = TTTBots.Lib
---@class BKnifeStalk
local KnifeStalk = TTTBots.Behaviors.KnifeStalk
KnifeStalk.Name         = "KnifeStalk"
KnifeStalk.Description  = "Stalk an isolated target and knife-kill them silently (200dmg knife mod)."
KnifeStalk.Interruptible = true

local STATUS = TTTBots.STATUS

-- ─────────────────────────────────────────────────────────────────────────────
-- Constants
-- ─────────────────────────────────────────────────────────────────────────────

local KNIFE_CLASS         = "weapon_ttt_knife"
local KNIFE_ENGAGE_DIST   = 130   -- units; close enough to lunge
local APPROACH_HOLD_DIST  = 400   -- units; hold this distance while waiting for opening
local MAX_WITNESSES_STALK = 1     -- witnesses allowed during approach phase
local MAX_WITNESSES_CLOSE = 0     -- witnesses allowed during melee-commit phase
local RETARGET_INTERVAL   = 5.0   -- seconds between target re-evaluations
local POSTKILL_TIMEOUT    = 12    -- seconds to attempt body-hide / roledefib before giving up
local EARSHOT_RANGE       = 550
local FOV_ARC             = 120

-- ─────────────────────────────────────────────────────────────────────────────
-- 200-damage knife detection (cached once per map)
-- ─────────────────────────────────────────────────────────────────────────────

KnifeStalk._knifeModDetected = nil -- nil = not yet checked, true/false after check

--- Returns true if the 200-damage knife mod is installed.
--- Checks weapon_ttt_knife.Primary.Damage >= 150 (normal is 50).
---@return boolean
function KnifeStalk.IsKnifeModInstalled()
    if KnifeStalk._knifeModDetected ~= nil then
        return KnifeStalk._knifeModDetected
    end

    local stored = weapons.GetStored(KNIFE_CLASS)
    if stored and stored.Primary and stored.Primary.Damage and stored.Primary.Damage >= 150 then
        KnifeStalk._knifeModDetected = true
    else
        KnifeStalk._knifeModDetected = false
    end

    return KnifeStalk._knifeModDetected
end

-- Re-check on round start in case the mod was loaded late
hook.Add("TTTBeginRound", "KnifeStalk.RecacheKnifeMod", function()
    KnifeStalk._knifeModDetected = nil
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────

--- Returns true if this bot is on a "killer" team (not TEAM_INNOCENT, not TEAM_NONE).
---@param bot Bot
---@return boolean
local function isKillerRole(bot)
    if not (IsValid(bot) and bot.GetTeam) then return false end
    local team = bot:GetTeam()
    return team ~= TEAM_NONE and team ~= TEAM_INNOCENT
end

--- Returns the TTT knife weapon if the bot has it.
---@param bot Bot
---@return Weapon|nil
local function getKnife(bot)
    if not bot:HasWeapon(KNIFE_CLASS) then return nil end
    local wep = bot:GetWeapon(KNIFE_CLASS)
    return IsValid(wep) and wep or nil
end

--- Check if the target is looking toward the bot (within a forward arc).
---@param target Player
---@param bot Bot
---@param arc number
---@return boolean
local function isTargetFacingBot(target, bot, arc)
    if not (IsValid(target) and IsValid(bot)) then return false end
    local forward = target:GetAimVector()
    local toBot   = (bot:EyePos() - target:EyePos()):GetNormalized()
    local angle   = math.deg(math.acos(math.Clamp(forward:Dot(toBot), -1, 1)))
    return angle <= (arc / 2)
end

--- Collect FOV-aware + earshot witnesses around a position.
--- Returns a count (excluding the target themselves).
---@param bot Bot
---@param pos Vector
---@param target Player  the intended victim (excluded from count)
---@return number witnessCount
local function countRealisticWitnesses(bot, pos, target)
    local nonAllies = TTTBots.Perception and TTTBots.Perception.GetPerceivedNonAllies(bot)
        or TTTBots.Roles.GetNonAllies(bot)
    local count = 0
    for _, ply in pairs(nonAllies) do
        if ply == NULL or not IsValid(ply) then continue end
        if ply == bot or ply == target then continue end
        if not lib.IsPlayerAlive(ply) then continue end
        local d = ply:GetPos():Distance(pos)
        if d <= EARSHOT_RANGE then
            count = count + 1
        elseif d <= lib.BASIC_VIS_RANGE then
            if lib.CanSeeArc and lib.CanSeeArc(ply, pos, FOV_ARC) then
                count = count + 1
            end
        end
    end
    return count
end

--- Rate how desirable a target is for a knife kill.
---@param bot Bot
---@param target Player
---@return number
local function rateKnifeTarget(bot, target)
    if not (IsValid(target) and lib.IsPlayerAlive(target)) then return -math.huge end
    if TTTBots.Roles.IsAllies(bot, target) then return -math.huge end
    -- Don't target perceived allies
    if TTTBots.Perception and TTTBots.Perception.IsPerceivedAlly(bot, target) then return -math.huge end

    local score   = 0
    local botPos  = bot:GetPos()
    local tgtPos  = target:GetPos()
    local dist    = botPos:Distance(tgtPos)

    -- Prefer closer targets (knife is melee)
    score = score + math.max(0, 2500 - dist) / 60

    -- Heavily prefer isolated targets
    local isolation = lib.RateIsolation(bot, target)
    score = score + isolation * 10

    -- Prefer targets we can see
    if bot:Visible(target) then
        score = score + 12
    end

    -- Prefer targets with backs turned
    if not isTargetFacingBot(target, bot, 90) then
        score = score + 8
    end

    -- Prefer stationary targets
    local vel = target:GetVelocity():Length()
    if vel < 50 then
        score = score + 6
    elseif vel < 150 then
        score = score + 2
    end

    -- Slight penalty for detectives (riskier, more investigated)
    local tRole = TTTBots.Roles.GetRoleFor(target)
    if tRole and tRole:GetAppearsPolice() then
        score = score - 5
    end

    return score
end

--- Find the best target for a knife kill.
---@param bot Bot
---@return Player|nil target
---@return number score
local function findBestKnifeTarget(bot)
    local best, bestScore = nil, -math.huge
    for _, ply in ipairs(TTTBots.Match.AlivePlayers or {}) do
        if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end
        if ply == bot then continue end
        local score = rateKnifeTarget(bot, ply)
        if score > bestScore then
            bestScore = score
            best = ply
        end
    end
    return best, bestScore
end

--- Returns true if the bot has any roledefib weapon.
---@param bot Bot
---@return boolean
local function hasRoledefib(bot)
    local classes = { "weapon_ttt_defib_traitor", "weapon_ttt_mesdefi", "weapon_ttt2_markerdefi" }
    for _, cls in ipairs(classes) do
        if bot:HasWeapon(cls) then return true end
    end
    return false
end

--- Find the nearest ragdoll of a recently-killed player near the bot.
---@param bot Bot
---@return Entity|nil ragdoll
local function findNearbyCorpse(bot)
    local bestDist = 600
    local bestRag  = nil
    for _, rag in ipairs(ents.FindByClass("prop_ragdoll")) do
        if not IsValid(rag) then continue end
        if not rag.sid64 then continue end
        local dist = bot:GetPos():Distance(rag:GetPos())
        if dist < bestDist then
            bestDist = dist
            bestRag  = rag
        end
    end
    return bestRag
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Validate
-- ─────────────────────────────────────────────────────────────────────────────

function KnifeStalk.Validate(bot)
    if not KnifeStalk.IsKnifeModInstalled() then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not lib.IsPlayerAlive(bot) then return false end
    if not isKillerRole(bot) then return false end
    if not getKnife(bot) then return false end
    -- Don't interfere with an existing attack target
    if IsValid(bot.attackTarget) then return false end
    -- Respect respawn grace
    if (bot.respawnGraceUntil or 0) > CurTime() then return false end

    -- Check that a viable isolated target exists
    local target, score = findBestKnifeTarget(bot)
    if not IsValid(target) then return false end
    if score < 0 then return false end

    -- Phase gate: in OVERTIME, skip subtlety — other behaviors are more aggressive
    local ra = bot.BotRoundAwareness and bot:BotRoundAwareness()
    local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
    if ra and PHASE then
        local phase = ra:GetPhase()
        if phase == PHASE.OVERTIME then return false end
    end

    -- Chance gate: don't always use knife strategy; mix it up
    -- Higher chance if bot has the "hider" or "cautious" trait
    local personality = bot:BotPersonality()
    local baseChance = 40 -- percent per validate tick
    if personality then
        if personality:GetTraitBool("hider") or personality:GetTraitBool("cautious") then
            baseChance = 70
        elseif personality:GetTraitBool("hothead") then
            baseChance = 15 -- hotheads prefer loud guns
        end
    end
    if math.random(1, 100) > baseChance then return false end

    return true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Lifecycle
-- ─────────────────────────────────────────────────────────────────────────────

function KnifeStalk.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "KnifeStalk")
    state.phase = "stalk"
    state.lastRetarget = 0
    state.startTime = CurTime()
    state.postKillStart = nil
    state.postKillAction = nil -- "roledefib" | "hidebody"

    local target, score = findBestKnifeTarget(bot)
    state.target = target
    state.score  = score

    return STATUS.RUNNING
end

function KnifeStalk.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "KnifeStalk")
    local loco  = bot:BotLocomotor()
    local inv   = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    local now = CurTime()

    -- ── Global timeout: give up after 60 seconds ──────────────────────────
    if (now - (state.startTime or now)) > 60 then return STATUS.FAILURE end

    -- ── Post-kill phase ───────────────────────────────────────────────────
    if state.phase == "postKill" then
        return KnifeStalk.RunPostKill(bot, state, loco, inv)
    end

    -- ── Target validation & re-evaluation ─────────────────────────────────
    local target = state.target
    if not (IsValid(target) and lib.IsPlayerAlive(target)) then
        -- Target died (maybe we killed them) — check for post-kill phase
        if state.lastKillTarget and not lib.IsPlayerAlive(state.lastKillTarget) then
            state.phase = "postKill"
            state.postKillStart = now
            return STATUS.RUNNING
        end
        -- Otherwise try to find a new target
        target = nil
    end

    -- Re-target periodically
    if now - (state.lastRetarget or 0) >= RETARGET_INTERVAL then
        state.lastRetarget = now
        local newTarget, newScore = findBestKnifeTarget(bot)
        if IsValid(newTarget) and newScore > (state.score or -math.huge) + 1 then
            state.target = newTarget
            state.score  = newScore
            target = newTarget
        end
    end

    if not IsValid(target) then return STATUS.FAILURE end

    local botPos   = bot:GetPos()
    local tgtPos   = target:GetPos()
    local dist     = botPos:Distance(tgtPos)
    local canSee   = bot:Visible(target)
    local tgtFacing = isTargetFacingBot(target, bot, 80)

    -- Count witnesses at both positions
    local witnessesAtBot = countRealisticWitnesses(bot, bot:EyePos(), target)
    local witnessesAtTgt = countRealisticWitnesses(bot, tgtPos, target)
    local maxWitnesses   = math.max(witnessesAtBot, witnessesAtTgt)

    -- ── Stalk phase: approach while maintaining distance ──────────────────
    if state.phase == "stalk" then
        loco:SetGoal(tgtPos)

        -- Transition to close phase when:
        -- 1. We can see them
        -- 2. They're not facing us (or we're desperate in late phase)
        -- 3. Witness count is acceptable
        if canSee and dist < APPROACH_HOLD_DIST and not tgtFacing and maxWitnesses <= MAX_WITNESSES_STALK then
            state.phase = "close"
        end

        return STATUS.RUNNING
    end

    -- ── Close phase: rush in for the kill ─────────────────────────────────
    if state.phase == "close" then
        -- Abort back to stalk if target turns to face us or witnesses appear
        if tgtFacing and dist > KNIFE_ENGAGE_DIST + 30 then
            state.phase = "stalk"
            return STATUS.RUNNING
        end
        if maxWitnesses > MAX_WITNESSES_CLOSE and dist > KNIFE_ENGAGE_DIST + 30 then
            state.phase = "stalk"
            return STATUS.RUNNING
        end

        -- Rush toward target
        loco:SetGoal(tgtPos)
        loco:LookAt(target:EyePos())

        -- When in knife range and conditions are right, commit
        if dist <= KNIFE_ENGAGE_DIST and canSee then
            state.phase = "attack"
        end

        return STATUS.RUNNING
    end

    -- ── Attack phase: equip knife & hand off to AttackTarget ──────────────
    if state.phase == "attack" then
        -- Equip knife
        inv:PauseAutoSwitch()
        local knife = getKnife(bot)
        if knife then
            bot:SelectWeapon(KNIFE_CLASS)
        end

        loco:LookAt(target:EyePos())
        loco:SetGoal() -- stop pathing, commit

        -- Remember the target before handing off (for post-kill detection)
        state.lastKillTarget = target

        -- Assign attack target — AttackTarget behavior takes over the melee combat
        bot:SetAttackTarget(target, "KNIFE_STALK_ATTACK", 4)

        -- Fire chatter (rare, to maintain stealth)
        local chatter = bot:BotChatter()
        if chatter and chatter.On and math.random(1, 6) == 1 then
            chatter:On("Plan.Attack", { target = target, player = target:Nick() }, true)
        end

        return STATUS.SUCCESS
    end

    return STATUS.RUNNING
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Post-kill: roledefib or hide body
-- ─────────────────────────────────────────────────────────────────────────────

function KnifeStalk.RunPostKill(bot, state, loco, inv)
    local now = CurTime()

    -- Timeout
    if (now - (state.postKillStart or now)) > POSTKILL_TIMEOUT then
        return STATUS.SUCCESS -- done, regardless
    end

    -- Decide action on first post-kill tick
    if not state.postKillAction then
        if hasRoledefib(bot) then
            state.postKillAction = "roledefib"
        else
            state.postKillAction = "hidebody"
        end
    end

    -- ── Role-defib path: let the existing Roledefib behavior handle it ────
    -- We just mark the bot so Roledefib.Validate will pick up the nearby corpse.
    if state.postKillAction == "roledefib" then
        -- The Roledefib behavior is already in the traitor tree at higher priority
        -- than KnifeStalk. By returning SUCCESS here, we drop KnifeStalk and
        -- the tree will naturally run Roledefib on the next tick (since a corpse
        -- is nearby and the bot has a roledefib).
        -- Record the kill time so TrapPlayer can also try to lock nearby doors.
        bot.lastKillTime = now
        return STATUS.SUCCESS
    end

    -- ── Hide-body path: drag/move the ragdoll to a hidden spot ────────────
    if state.postKillAction == "hidebody" then
        local rag = state.hideRag or findNearbyCorpse(bot)
        if not IsValid(rag) then return STATUS.SUCCESS end
        state.hideRag = rag

        -- Find a hiding spot near the body
        if not state.hidePos then
            local hideSpots = TTTBots.Spots and TTTBots.Spots.GetSpotsInCategory("hiding") or {}
            local ragPos = rag:GetPos()
            local best, bestDist = nil, 800
            for _, spot in ipairs(hideSpots) do
                local d = ragPos:Distance(spot)
                if d < bestDist then
                    bestDist = d
                    best = spot
                end
            end
            -- Fallback: just push body behind nearest wall (navigate away from popular area)
            if not best then
                local unpop = TTTBots.Lib.GetTopNUnpopularNavs and TTTBots.Lib.GetTopNUnpopularNavs(3) or {}
                if unpop[1] then
                    local nav = navmesh.GetNavAreaByID(unpop[1][1])
                    if nav then best = nav:GetCenter() end
                end
            end
            state.hidePos = best
        end

        if not state.hidePos then return STATUS.SUCCESS end -- nowhere to hide it

        -- Walk to the body first
        local ragPos = rag:GetPos()
        local distToRag = bot:GetPos():Distance(ragPos)

        if distToRag > 80 then
            loco:SetGoal(ragPos)
            loco:LookAt(ragPos)
            return STATUS.RUNNING
        end

        -- At the body: try to pick it up / push it
        -- Use the magneto stick if the bot has it, otherwise just shove
        if not state.grabbedBody then
            loco:LookAt(rag:GetPos() + Vector(0, 0, 10))
            loco:Crouch(true)

            -- Try using +use to grab
            if bot:HasWeapon("weapon_ttt_wtester") or true then -- any weapon works for pickup
                -- Look at body and press use
                loco:StartAttack() -- This simulates holding attack on the magneto stick
                timer.Simple(0.3, function()
                    if IsValid(bot) and IsValid(rag) then
                        -- Physically move the ragdoll to the hiding spot
                        -- This is a direct server-side move since bot can't truly grab
                        local phys = rag:GetPhysicsObject()
                        if IsValid(phys) then
                            local hideDir = (state.hidePos - ragPos):GetNormalized()
                            phys:ApplyForceCenter(hideDir * 3000 + Vector(0, 0, 500))
                        end
                        state.grabbedBody = true
                    end
                end)
            end

            return STATUS.RUNNING
        end

        -- Record the kill for TrapPlayer door-locking
        bot.lastKillTime = now
        loco:StopAttack()
        loco:Crouch(false)
        return STATUS.SUCCESS
    end

    return STATUS.SUCCESS
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Callbacks
-- ─────────────────────────────────────────────────────────────────────────────

function KnifeStalk.OnSuccess(bot) end
function KnifeStalk.OnFailure(bot) end

function KnifeStalk.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "KnifeStalk")
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
    local loco = bot:BotLocomotor()
    if loco then
        loco:StopAttack()
        loco:Crouch(false)
    end
end
