--- sv_debuglog.lua
--- Comprehensive server-console debug logging suite for TTT Bots 2.
--- Controlled by ttt_bot_debug_log_* cvars — enable any combination to get
--- a full picture of the round directly from the server console output.
---
--- All output is gated behind the corresponding cvar so there is ZERO overhead
--- when the cvar is off.  Lines are prefixed with [BOTDBG:<CATEGORY>] for easy
--- grep/filtering.

if not SERVER then return end

TTTBots.DebugLog = TTTBots.DebugLog or {}
local DL = TTTBots.DebugLog
local lib = TTTBots.Lib
local f = string.format

-- ═══════════════════════════════════════════════════════════════════════════
-- Helper: gated print
-- ═══════════════════════════════════════════════════════════════════════════

--- Prints a debug message if the given cvar is enabled.
---@param cvar string  Short cvar suffix after "debug_log_"
---@param tag  string  Tag for the log line (e.g. "ROUND", "ROLES")
---@param msg  string  Formatted message
function DL.Log(cvar, tag, msg)
    local cv = GetConVar("ttt_bot_debug_log_" .. cvar)
    if not cv or not cv:GetBool() then return end
    print(f("[BOTDBG:%s] %s", tag, msg))
end

--- Convenience: log with string.format args
function DL.Logf(cvar, tag, fmt, ...)
    DL.Log(cvar, tag, f(fmt, ...))
end

-- Helper to get a safe player name
local function pname(ply)
    if not IsValid(ply) then return "<invalid>" end
    return ply:Nick()
end

-- Helper to get role name safely
local function rolename(ply)
    if not IsValid(ply) then return "?" end
    if TTTBots.Roles and TTTBots.Roles.GetRoleFor then
        local rd = TTTBots.Roles.GetRoleFor(ply)
        if rd then return rd:GetName() or "?" end
    end
    if ply.GetRoleStringRaw then return ply:GetRoleStringRaw() or "?" end
    return "?"
end

-- Helper to get team name
local function teamname(ply)
    if not IsValid(ply) then return "?" end
    local t = ply:GetTeam()
    if t == TEAM_TRAITOR then return "TRAITOR" end
    if t == TEAM_INNOCENT then return "INNOCENT" end
    if t == TEAM_NONE then return "NONE" end
    return tostring(t)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. ROUND LIFECYCLE
-- ═══════════════════════════════════════════════════════════════════════════

hook.Add("TTTPrepareRound", "TTTBots.DebugLog.PrepareRound", function()
    DL.Log("round", "ROUND", "========== PREPARE ROUND ==========")
    DL.Logf("round", "ROUND", "Players on server: %d / %d  |  Bots: %d",
        #player.GetAll(), game.MaxPlayers(), #TTTBots.Bots)
end)

hook.Add("TTTBeginRound", "TTTBots.DebugLog.BeginRound", function()
    DL.Log("round", "ROUND", "========== ROUND START ==========")
    DL.Logf("round", "ROUND", "Map: %s  |  Time: %s", game.GetMap(), os.date("%H:%M:%S"))

    -- Defer role printout slightly so roles are assigned
    timer.Simple(1.5, function()
        if not TTTBots.Match.RoundActive then return end
        local cv = GetConVar("ttt_bot_debug_log_round")
        if not cv or not cv:GetBool() then return end

        DL.Log("round", "ROUND", "--- Player roster ---")
        for _, ply in pairs(player.GetAll()) do
            if not IsValid(ply) then continue end
            local alive = TTTBots.Lib.IsPlayerAlive(ply) and "ALIVE" or "DEAD"
            local isBot = ply:IsBot() and "[BOT]" or "[HUMAN]"
            DL.Logf("round", "ROUND", "  %s %s  |  Role: %-16s  Team: %-10s  HP: %d  %s",
                isBot, pname(ply), rolename(ply), teamname(ply), ply:Health(), alive)
        end
        DL.Logf("round", "ROUND", "Initial traitor count: %d", TTTBots.Match.InitialTraitorCount or 0)
        DL.Log("round", "ROUND", "--------------------")
    end)
end)

hook.Add("TTTEndRound", "TTTBots.DebugLog.EndRound", function(result)
    DL.Log("round", "ROUND", "========== ROUND END ==========")
    DL.Logf("round", "ROUND", "Result: %s  |  Duration: %.1fs", tostring(result), TTTBots.Match.SecondsPassed or 0)

    -- Final scoreboard
    local cv = GetConVar("ttt_bot_debug_log_round")
    if not cv or not cv:GetBool() then return end

    DL.Log("round", "ROUND", "--- Final state ---")
    for _, ply in pairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        local alive = TTTBots.Lib.IsPlayerAlive(ply) and "ALIVE" or "DEAD"
        local isBot = ply:IsBot() and "[BOT]" or "[HUMAN]"
        DL.Logf("round", "ROUND", "  %s %s  |  Role: %-16s  Team: %-10s  HP: %d  %s",
            isBot, pname(ply), rolename(ply), teamname(ply), ply:Health(), alive)
    end
    DL.Log("round", "ROUND", "================================")
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- 2. KILLS / DEATHS
-- ═══════════════════════════════════════════════════════════════════════════

hook.Add("PlayerDeath", "TTTBots.DebugLog.PlayerDeath", function(victim, inflictor, attacker)
    if not TTTBots.Match.RoundActive then return end
    local attackerName = "world"
    local attackerRole = "N/A"
    if IsValid(attacker) and attacker:IsPlayer() then
        attackerName = pname(attacker)
        attackerRole = rolename(attacker)
    end
    local wep = "unknown"
    if IsValid(inflictor) then
        wep = inflictor:GetClass()
        if inflictor:IsWeapon() and inflictor.GetPrintName then
            wep = inflictor:GetPrintName() .. " (" .. inflictor:GetClass() .. ")"
        end
    end

    DL.Logf("kills", "KILL", "%s [%s] killed %s [%s] with %s  (round +%.1fs)",
        attackerName, attackerRole, pname(victim), rolename(victim), wep,
        TTTBots.Match.SecondsPassed or 0)

    -- Remaining alive summary
    local alive = TTTBots.Lib.GetAlivePlayers()
    DL.Logf("kills", "KILL", "  Alive remaining: %d", #alive)
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- 3. DAMAGE
-- ═══════════════════════════════════════════════════════════════════════════

hook.Add("PlayerHurt", "TTTBots.DebugLog.PlayerHurt", function(victim, attacker, healthRemaining, damageTaken)
    if not TTTBots.Match.RoundActive then return end
    if not (IsValid(victim) and victim:IsPlayer()) then return end
    local attackerStr = "world"
    if IsValid(attacker) and attacker:IsPlayer() then
        attackerStr = f("%s [%s]", pname(attacker), rolename(attacker))
    end
    DL.Logf("damage", "DMG", "%s dealt %d dmg to %s [%s]  (HP now: %d)",
        attackerStr, damageTaken, pname(victim), rolename(victim), healthRemaining)
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- 4. KOS CALLS
-- ═══════════════════════════════════════════════════════════════════════════

hook.Add("TTTBots.KOSCalled", "TTTBots.DebugLog.KOS", function(caller, target)
    DL.Logf("kos", "KOS", "%s [%s] called KOS on %s [%s]  (round +%.1fs)",
        pname(caller), rolename(caller), pname(target), rolename(target),
        TTTBots.Match.SecondsPassed or 0)
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- 5. BODY FOUND / CONFIRMED
-- ═══════════════════════════════════════════════════════════════════════════

hook.Add("TTTBodyFound", "TTTBots.DebugLog.BodyFound", function(discoverer, deceased, ragdoll)
    if not TTTBots.Match.RoundActive then return end
    DL.Logf("bodies", "BODY", "%s [%s] found body of %s [%s]  (round +%.1fs)",
        pname(discoverer), rolename(discoverer), pname(deceased), rolename(deceased),
        TTTBots.Match.SecondsPassed or 0)
    DL.Logf("bodies", "BODY", "  Confirmed dead count: %d", table.Count(TTTBots.Match.ConfirmedDead))
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- 6. BOT BEHAVIOR TREE (periodic ticker)
-- ═══════════════════════════════════════════════════════════════════════════

timer.Create("TTTBots.DebugLog.Behaviors", 3, 0, function()
    local cv = GetConVar("ttt_bot_debug_log_behaviors")
    if not cv or not cv:GetBool() then return end
    if not TTTBots.Match.RoundActive then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot.components and TTTBots.Lib.IsPlayerAlive(bot)) then continue end

        local bhName = bot.lastBehavior and bot.lastBehavior.Name or "None"
        local targetStr = "none"
        if IsValid(bot.attackTarget) then
            if bot.attackTarget:IsPlayer() then
                targetStr = pname(bot.attackTarget) .. " [" .. rolename(bot.attackTarget) .. "]"
            else
                targetStr = bot.attackTarget:GetClass()
            end
        end

        DL.Logf("behaviors", "BEHAV", "%-20s | Behavior: %-24s | Target: %s",
            pname(bot), bhName, targetStr)
    end
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- 7. TRAITOR PLANS / EVIL COORDINATOR
-- ═══════════════════════════════════════════════════════════════════════════

-- Hook into the event bus for plan assignments
hook.Add("TTTBotsInitialized", "TTTBots.DebugLog.SubscribePlans", function()
    if not TTTBots.Events then return end

    TTTBots.Events.Subscribe("PLAN_ASSIGNED", function(payload)
        if not payload then return end
        local bot = payload.bot
        local job = payload.job
        if not (IsValid(bot) and job) then return end
        DL.Logf("plans", "PLAN", "%s [%s] assigned plan job: Action=%s  Target=%s",
            pname(bot), rolename(bot),
            tostring(job.Action or "?"), tostring(job.Target or "N/A"))
    end, 90)
end)

-- Periodic plan state dump
timer.Create("TTTBots.DebugLog.PlanState", 5, 0, function()
    local cv = GetConVar("ttt_bot_debug_log_plans")
    if not cv or not cv:GetBool() then return end
    if not TTTBots.Match.RoundActive then return end
    if not TTTBots.Plans then return end

    local plan = TTTBots.Plans.SelectedPlan
    if plan then
        DL.Logf("plans", "PLAN", "Active plan: %s  |  State: %s",
            plan.Name or "unnamed", TTTBots.Plans.CurrentPlanState or "?")
    end
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- 8. INNOCENT COORDINATOR
-- ═══════════════════════════════════════════════════════════════════════════

timer.Create("TTTBots.DebugLog.InnocentCoord", 5, 0, function()
    local cv = GetConVar("ttt_bot_debug_log_innocentcoord")
    if not cv or not cv:GetBool() then return end
    if not TTTBots.Match.RoundActive then return end
    if not TTTBots.InnocentCoordinator then return end

    local IC = TTTBots.InnocentCoordinator
    local strat = IC.SelectedStrategy or "none"
    DL.Logf("innocentcoord", "IC", "Current innocent strategy: %s", strat)

    -- Print buddy pairs if available
    if IC.BuddyPairs and next(IC.BuddyPairs) then
        for bot, buddy in pairs(IC.BuddyPairs) do
            if IsValid(bot) and IsValid(buddy) then
                DL.Logf("innocentcoord", "IC", "  Buddy pair: %s <-> %s", pname(bot), pname(buddy))
            end
        end
    end
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- 9. EVIDENCE / SUSPICION
-- ═══════════════════════════════════════════════════════════════════════════

timer.Create("TTTBots.DebugLog.Evidence", 5, 0, function()
    local cv = GetConVar("ttt_bot_debug_log_evidence")
    if not cv or not cv:GetBool() then return end
    if not TTTBots.Match.RoundActive then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot.components and TTTBots.Lib.IsPlayerAlive(bot)) then continue end
        local evidence = bot.components.evidence
        if not evidence then continue end

        -- Get top suspects
        local suspects = {}
        if evidence.GetAllSuspects then
            suspects = evidence:GetAllSuspects()
        elseif evidence.evidenceLog then
            -- Manually aggregate from the evidence log
            local weights = {}
            for _, entry in pairs(evidence.evidenceLog or {}) do
                if IsValid(entry.suspect) then
                    weights[entry.suspect] = (weights[entry.suspect] or 0) + (entry.weight or 0)
                end
            end
            for suspect, weight in pairs(weights) do
                table.insert(suspects, { suspect = suspect, weight = weight })
            end
            table.sort(suspects, function(a, b) return a.weight > b.weight end)
        end

        if #suspects > 0 then
            local topN = math.min(3, #suspects)
            local parts = {}
            for i = 1, topN do
                local s = suspects[i]
                local name = IsValid(s.suspect) and pname(s.suspect) or "?"
                table.insert(parts, f("%s(%.1f)", name, s.weight or 0))
            end
            DL.Logf("evidence", "EVID", "%-20s top suspects: %s", pname(bot), table.concat(parts, ", "))
        end
    end
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- 10. ROUND AWARENESS / PHASE
-- ═══════════════════════════════════════════════════════════════════════════

timer.Create("TTTBots.DebugLog.RoundAwareness", 8, 0, function()
    local cv = GetConVar("ttt_bot_debug_log_awareness")
    if not cv or not cv:GetBool() then return end
    if not TTTBots.Match.RoundActive then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot.components and TTTBots.Lib.IsPlayerAlive(bot)) then continue end
        local ra = bot.components.roundawareness
        if not ra then continue end

        DL.Logf("awareness", "PHASE", "%-20s Phase: %-8s  Progress: %.0f%%  Aggression: %.2f  GroupUrg: %.2f  SusPres: %.2f  Overtake: %s",
            pname(bot),
            ra.phase or "?",
            (ra.phaseProgress or 0) * 100,
            ra.aggressionMult or 1,
            ra.groupUrgency or 0,
            ra.suspicionPressure or 1,
            tostring(ra.overtake or false))
    end
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- 11. PERSONALITY / TRAITS
-- ═══════════════════════════════════════════════════════════════════════════

timer.Create("TTTBots.DebugLog.Personality", 10, 0, function()
    local cv = GetConVar("ttt_bot_debug_log_personality")
    if not cv or not cv:GetBool() then return end
    if not TTTBots.Match.RoundActive then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot.components) then continue end
        local p = bot.components.personality
        if not p then continue end

        local traits = (p.GetTraits and p:GetTraits()) or {}
        local traitStr = #traits > 0 and table.concat(traits, ", ") or "none"
        local diff = (p.GetDifficulty and p:GetDifficulty()) or 0

        DL.Logf("personality", "PERS", "%-20s Arch: %-12s  Diff: %+.1f  R/B/P: %.1f / %.1f / %.1f  Traits: %s",
            pname(bot),
            p.archetype or "?",
            diff,
            p.rage or 0,
            p.boredom or 0,
            p.pressure or 0,
            traitStr)
    end
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- 12. INVENTORY / WEAPONS
-- ═══════════════════════════════════════════════════════════════════════════

timer.Create("TTTBots.DebugLog.Inventory", 8, 0, function()
    local cv = GetConVar("ttt_bot_debug_log_inventory")
    if not cv or not cv:GetBool() then return end
    if not TTTBots.Match.RoundActive then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot.components and TTTBots.Lib.IsPlayerAlive(bot)) then continue end
        local inv = bot.components.inventory
        if not inv then continue end

        local held = inv:GetHeldWeaponInfo()
        local heldStr = inv:GetWepInfoText(held)
        local _, priInfo = inv:GetPrimary()
        local priStr = inv:GetWepInfoText(priInfo)
        local _, secInfo = inv:GetSecondary()
        local secStr = inv:GetWepInfoText(secInfo)

        DL.Logf("inventory", "INV", "%-20s Held: %-24s  Primary: %-24s  Secondary: %s",
            pname(bot), heldStr or "none", priStr or "none", secStr or "none")
    end
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- 13. MEMORY / SIGHTINGS
-- ═══════════════════════════════════════════════════════════════════════════

timer.Create("TTTBots.DebugLog.Memory", 8, 0, function()
    local cv = GetConVar("ttt_bot_debug_log_memory")
    if not cv or not cv:GetBool() then return end
    if not TTTBots.Match.RoundActive then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot.components and TTTBots.Lib.IsPlayerAlive(bot)) then continue end
        local mem = bot.components.memory
        if not mem then continue end

        local recentlySeen = (mem.GetRecentlySeenPlayers and #mem:GetRecentlySeenPlayers()) or 0
        local knownPositions = (mem.GetKnownPlayersPos and table.Count(mem:GetKnownPlayersPos())) or 0
        local knownAlive = (mem.GetKnownAlivePlayers and #mem:GetKnownAlivePlayers()) or 0
        local actualAlive = (mem.GetActualAlivePlayers and #mem:GetActualAlivePlayers()) or 0
        local hearingMult = (mem.GetHearingMultiplier and mem:GetHearingMultiplier()) or 1

        DL.Logf("memory", "MEM", "%-20s CanSee: %d  KnownPos: %d  KnownAlive: %d/%d  Hearing: %.2fx",
            pname(bot), recentlySeen, knownPositions, knownAlive, actualAlive, hearingMult)
    end
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- 14. MORALITY / ATTACK TARGETS
-- ═══════════════════════════════════════════════════════════════════════════

timer.Create("TTTBots.DebugLog.Morality", 4, 0, function()
    local cv = GetConVar("ttt_bot_debug_log_morality")
    if not cv or not cv:GetBool() then return end
    if not TTTBots.Match.RoundActive then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot.components and TTTBots.Lib.IsPlayerAlive(bot)) then continue end
        local mor = bot.components.morality
        if not mor then continue end

        local target = "none"
        local reason = bot.attackTargetReason or "?"
        local priority = bot.attackTargetPriority or 0
        if IsValid(bot.attackTarget) then
            if bot.attackTarget:IsPlayer() then
                target = pname(bot.attackTarget) .. " [" .. rolename(bot.attackTarget) .. "]"
            else
                target = bot.attackTarget:GetClass()
            end
        end

        if target ~= "none" then
            DL.Logf("morality", "MORAL", "%-20s => Target: %-24s  Priority: %d  Reason: %s",
                pname(bot), target, priority, reason)
        end
    end
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- 15. CHATTER / CHAT EVENTS
-- ═══════════════════════════════════════════════════════════════════════════

hook.Add("PlayerSay", "TTTBots.DebugLog.Chat", function(ply, text, teamChat)
    if not ply:IsBot() then return end
    DL.Logf("chatter", "CHAT", "%s [%s]: %s%s",
        pname(ply), rolename(ply), teamChat and "(TEAM) " or "", text)
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- 16. C4 EVENTS
-- ═══════════════════════════════════════════════════════════════════════════

timer.Create("TTTBots.DebugLog.C4", 5, 0, function()
    local cv = GetConVar("ttt_bot_debug_log_c4")
    if not cv or not cv:GetBool() then return end
    if not TTTBots.Match.RoundActive then return end

    local armed = table.Count(TTTBots.Match.AllArmedC4s or {})
    local spotted = table.Count(TTTBots.Match.SpottedC4s or {})
    if armed > 0 then
        DL.Logf("c4", "C4", "Armed C4s: %d  |  Spotted by innocents: %d", armed, spotted)
    end
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- 17. LOCOMOTION / PATHFINDING (periodic summary)
-- ═══════════════════════════════════════════════════════════════════════════

timer.Create("TTTBots.DebugLog.Locomotion", 6, 0, function()
    local cv = GetConVar("ttt_bot_debug_log_locomotion")
    if not cv or not cv:GetBool() then return end
    if not TTTBots.Match.RoundActive then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot.components and TTTBots.Lib.IsPlayerAlive(bot)) then continue end
        local loco = bot:BotLocomotor()
        if not loco then continue end

        local hasPath = loco:HasPath() and "yes" or "no"
        local strafe = loco:GetStrafe() or "none"
        local status = loco.status or "idle"
        local goalPos = loco:GetGoal()
        local goalStr = goalPos and f("(%.0f, %.0f, %.0f)", goalPos.x, goalPos.y, goalPos.z) or "none"

        DL.Logf("locomotion", "LOCO", "%-20s Path: %s  Strafe: %-6s  Status: %-10s  Goal: %s",
            pname(bot), hasPath, strafe, status, goalStr)
    end
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- 18. ROUND TIMELINE (periodic snapshot)
-- ═══════════════════════════════════════════════════════════════════════════

timer.Create("TTTBots.DebugLog.Timeline", 15, 0, function()
    local cv = GetConVar("ttt_bot_debug_log_timeline")
    if not cv or not cv:GetBool() then return end
    if not TTTBots.Match.RoundActive then return end

    local alive = TTTBots.Lib.GetAlivePlayers()
    local confirmed = table.Count(TTTBots.Match.ConfirmedDead or {})
    local corpses = #(TTTBots.Match.Corpses or {})
    local kosList = {}
    for target, callers in pairs(TTTBots.Match.KOSList or {}) do
        if IsValid(target) then
            table.insert(kosList, f("%s(%d calls)", pname(target), table.Count(callers)))
        end
    end
    local kosStr = #kosList > 0 and table.concat(kosList, ", ") or "none"

    DL.Log("timeline", "TIME", "---------- ROUND SNAPSHOT ----------")
    DL.Logf("timeline", "TIME", "Round time: %.0fs  |  Alive: %d  |  Corpses: %d  |  Confirmed dead: %d",
        TTTBots.Match.SecondsPassed or 0, #alive, corpses, confirmed)
    DL.Logf("timeline", "TIME", "Active KOS targets: %s", kosStr)

    -- Alive player list with roles
    for _, ply in ipairs(alive) do
        local isBot = ply:IsBot() and "[BOT]" or "[HUM]"
        DL.Logf("timeline", "TIME", "  %s %-20s  Role: %-16s  Team: %-10s  HP: %d",
            isBot, pname(ply), rolename(ply), teamname(ply), ply:Health())
    end
    DL.Log("timeline", "TIME", "------------------------------------")
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- 19. EVENT BUS FIREHOSE
-- ═══════════════════════════════════════════════════════════════════════════

hook.Add("TTTBotsInitialized", "TTTBots.DebugLog.SubscribeEventBus", function()
    if not TTTBots.Events then return end

    -- Subscribe to every well-known event for logging
    for eventKey, eventName in pairs(TTTBots.Events.NAMES or {}) do
        TTTBots.Events.Subscribe(eventName, function(payload)
            local cv = GetConVar("ttt_bot_debug_log_events")
            if not cv or not cv:GetBool() then return end

            -- Build a readable summary of the payload
            local parts = {}
            if payload then
                for k, v in pairs(payload) do
                    local valStr
                    if IsValid(v) and v.Nick then
                        valStr = v:Nick()
                    elseif IsValid(v) then
                        valStr = v:GetClass()
                    else
                        valStr = tostring(v)
                    end
                    table.insert(parts, f("%s=%s", k, valStr))
                end
            end

            DL.Logf("events", "EVENT", "%s  { %s }", eventName, table.concat(parts, ", "))
        end, 99) -- Low priority: run after all real handlers
    end
end)


-- ═══════════════════════════════════════════════════════════════════════════
-- 20. MASTER TOGGLE: enable everything at once
-- ═══════════════════════════════════════════════════════════════════════════

-- Handled by the "ttt_bot_debug_log_all" cvar callback in sh_cvars.lua
-- When set to 1, it toggles all debug_log_* cvars on.
-- When set to 0, it toggles them all off.

local ALL_LOG_CVARS = {
    "round", "kills", "damage", "kos", "bodies", "behaviors",
    "plans", "innocentcoord", "evidence", "awareness", "personality",
    "inventory", "memory", "morality", "chatter", "c4",
    "locomotion", "timeline", "events",
}

concommand.Add("ttt_bot_debug_log_all_on", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    for _, name in ipairs(ALL_LOG_CVARS) do
        RunConsoleCommand("ttt_bot_debug_log_" .. name, "1")
    end
    print("[TTT Bots 2] All debug log cvars ENABLED.")
end)

concommand.Add("ttt_bot_debug_log_all_off", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    for _, name in ipairs(ALL_LOG_CVARS) do
        RunConsoleCommand("ttt_bot_debug_log_" .. name, "0")
    end
    print("[TTT Bots 2] All debug log cvars DISABLED.")
end)

--- Quick status command that prints what debug log cvars are currently active
concommand.Add("ttt_bot_debug_log_status", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    print("[TTT Bots 2] Debug log cvar status:")
    print("----------------------------------")
    for _, name in ipairs(ALL_LOG_CVARS) do
        local cv = GetConVar("ttt_bot_debug_log_" .. name)
        local state = (cv and cv:GetBool()) and "ON" or "OFF"
        print(f("  ttt_bot_debug_log_%-16s %s", name, state))
    end
    print("----------------------------------")
end)

--- One-line round summary command (callable any time)
concommand.Add("ttt_bot_debug_roundinfo", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    if not TTTBots.Match.RoundActive then
        print("[TTT Bots 2] No round is currently active.")
        return
    end

    local alive = TTTBots.Lib.GetAlivePlayers()
    local bots = TTTBots.Bots
    local confirmed = table.Count(TTTBots.Match.ConfirmedDead or {})

    print("============ TTT BOTS ROUND INFO ============")
    print(f("Round time: %.0fs  |  Alive: %d  |  Bots: %d  |  Confirmed dead: %d",
        TTTBots.Match.SecondsPassed or 0, #alive, #bots, confirmed))
    print("----------------------------------------------")

    for _, p in pairs(player.GetAll()) do
        if not IsValid(p) then continue end
        local aliveStr = TTTBots.Lib.IsPlayerAlive(p) and "ALIVE" or "DEAD"
        local botStr = p:IsBot() and "[BOT]" or "[HUM]"
        local bhName = ""
        if p:IsBot() and p.lastBehavior then
            bhName = " | Behavior: " .. (p.lastBehavior.Name or "?")
        end
        print(f("  %s %-20s  Role: %-16s  Team: %-10s  HP: %-4d  %s%s",
            botStr, pname(p), rolename(p), teamname(p), p:Health(), aliveStr, bhName))
    end
    print("==============================================")
end)
