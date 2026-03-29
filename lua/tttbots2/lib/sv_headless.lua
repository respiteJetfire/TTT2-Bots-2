---------------------------------------------------------------------------
-- Headless Mode — Bots-Only Server Support
--
-- When ttt_bot_headless is set to 1, the server will allow rounds to
-- start and continue with ONLY bots connected (no human players required).
--
-- This works by:
--   1. Disabling server hibernation so the server stays alive with 0 humans.
--   2. Overriding TTT2's minimum player check to count bots as valid players.
--   3. Automatically spawning bots on server start-up (using quota), without
--      waiting for a human to connect first.
--   4. Ensuring the round loop doesn't stall when the last human leaves.
--
-- Use case: dedicated bot-only servers for testing, spectating via RCON,
-- or running a "headless" TTT server for stat collection / plan learning.
---------------------------------------------------------------------------

print("[TTT Bots 2] sv_headless.lua LOADING (file included by TTTBots.Reload -> includeServer)")

local HEADLESS = {}
TTTBots.Headless = HEADLESS

--- Tracks whether we've already injected the fake player on this map load.
HEADLESS.FakePlayerInjected = false

--- Tracks whether we've already done the initial bot seed on startup.
HEADLESS._initialSeedDone = false

--- Check if headless mode is enabled.
---@return boolean
function HEADLESS.IsEnabled()
    return TTTBots.Lib.GetConVarBool("headless")
end

---------------------------------------------------------------------------
-- CRITICAL: Disable server hibernation when headless mode is enabled.
--
-- By default, Source engine servers set sv_hibernate_when_empty to 1,
-- which suspends the server (stops all Lua execution, timers, Think
-- hooks, etc.) the moment the last human player disconnects.  Bots
-- alone do NOT prevent hibernation — the engine considers them
-- "not real players" for this purpose.
--
-- When the server hibernates it also *kicks* every bot with the
-- message "Punting bot, server is hibernating", which means:
--   • Bots are removed when the last human leaves.
--   • Bots are never added before a human connects (Think never runs).
--   • The quota timer never fires, so the server sits empty forever.
--
-- The fix is simple: force sv_hibernate_when_empty to 0 so the
-- server keeps running with bots only.
---------------------------------------------------------------------------
local function EnsureNoHibernation()
    if not HEADLESS.IsEnabled() then return end

    local cv = GetConVar("sv_hibernate_when_empty")
    if cv and cv:GetInt() ~= 0 then
        RunConsoleCommand("sv_hibernate_when_empty", "0")
        print("[TTT Bots 2] Headless mode: disabled server hibernation (sv_hibernate_when_empty 0)")
    end
end

-- Run immediately on load and also whenever the headless cvar changes.
EnsureNoHibernation()

---------------------------------------------------------------------------
-- Core hook: Override TTT2's HasEnoughPlayers / minimum_players check
--
-- TTT2 uses `ttt_minimum_players` (default 2) and counts only ready,
-- spawnable players.  In headless mode we hook into the round flow to
-- ensure bots are counted toward this minimum.
---------------------------------------------------------------------------

--- When headless mode is on, we override the ttt_minimum_players cvar
--- dynamically so that bots count.  We also ensure at least N bots exist.
local function EnsureBotsForHeadless()
    if not HEADLESS.IsEnabled() then return end

    -- Make sure the quota system will add bots even with 0 humans.
    -- The quota system already handles bot addition, but we need the
    -- round to actually START.  TTT2's HasEnoughPlayers counts ALL
    -- players (including bots) that pass ShouldSpawn + IsReady checks.
    -- Bots always pass IsReady but may not pass ShouldSpawn if they're
    -- set as forced spectators.

    -- Count total ready players (bots + humans)
    local readyCount = 0
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            readyCount = readyCount + 1
        end
    end

    -- Determine how many bots we actually need.
    -- Use the quota target first (ttt_bot_quota), fall back to ttt_minimum_players.
    local quotaCvar = GetConVar("ttt_bot_quota")
    local quotaN = quotaCvar and quotaCvar:GetInt() or 0
    local minPlayers = GetConVar("ttt_minimum_players")
    local minNeeded = minPlayers and minPlayers:GetInt() or 2

    -- The seed target is whichever is greater: the quota or the minimum player count.
    local seedTarget = math.max(quotaN, minNeeded)

    if readyCount < seedTarget then
        -- Only add a few at a time to avoid flooding the engine
        local toAdd = math.min(seedTarget - readyCount, 3)
        for i = 1, toAdd do
            -- Use player.CreateNextBot() to bypass command buffer (Cbuf) issues.
            -- RunConsoleCommand("bot") can be lost during Cbuf overflow at startup.
            local bot = player.CreateNextBot("TTTBot")
            if not IsValid(bot) then
                -- Fallback if CreateNextBot fails for any reason
                RunConsoleCommand("bot")
            end
        end
        print(string.format("[TTT Bots 2] Headless mode: seeding %d bot(s) (have %d, target %d)", toAdd, readyCount, seedTarget))
    end
end

---------------------------------------------------------------------------
-- Startup seed: add bots immediately after initialization so the server
-- doesn't sit empty waiting for a human to connect.
--
-- The quota system (TTTBots.Lib.UpdateQuota) runs every 1 second and
-- handles the long-term bot count, but it needs at least one tick cycle
-- with the server awake to run.  With hibernation disabled above the
-- quota timer will fire on its own within a couple of seconds, but we
-- also give it a direct kick-start here so the first bots appear as
-- soon as possible.
---------------------------------------------------------------------------
local function SeedBotsOnStartup()
    if not HEADLESS.IsEnabled() then return end
    if HEADLESS._initialSeedDone then return end
    HEADLESS._initialSeedDone = true

    -- Give the engine a moment to finish map-load initialisation (nav
    -- mesh, entity spawning, etc.) before we start creating bots.
    timer.Simple(3, function()
        if not HEADLESS.IsEnabled() then return end

        print("[TTT Bots 2] Headless mode: seeding initial bots on startup...")
        EnsureBotsForHeadless()

        -- The quota system will take over from here and add/remove bots
        -- to match the configured ttt_bot_quota.  We just need to get
        -- past the "zero players" chicken-and-egg problem.
    end)
end

-- Fire the seed as soon as this file is loaded (which happens inside
-- TTTBots.Reload(), itself called from initializeIfChecksPassed()).
SeedBotsOnStartup()

--- Hook into the round wait phase to push bots into the game.
--- This runs periodically while the server is waiting for players.
--- Also runs when no game state exists yet (pre-first-round) to handle
--- the case where the server started fresh with no humans.
hook.Add("Think", "TTTBots.Headless.Think", function()
    if not HEADLESS.IsEnabled() then return end

    -- Throttle: only check once every 3 seconds
    HEADLESS._lastCheck = HEADLESS._lastCheck or 0
    if CurTime() - HEADLESS._lastCheck < 3 then return end
    HEADLESS._lastCheck = CurTime()

    -- If the gameloop isn't ready yet (server just started), still try
    -- to ensure bots exist so the quota system and round can kick off.
    if not gameloop or not gameloop.GetRoundState then
        EnsureBotsForHeadless()
        return
    end

    -- During normal operation, only intervene in WAIT state (between rounds).
    -- The quota system handles bot counts during active rounds.
    if gameloop.GetRoundState() ~= ROUND_WAIT then return end

    EnsureBotsForHeadless()
end)

--- When a human player disconnects and headless mode is on, prevent
--- the round from aborting by ensuring enough bots exist.
--- With hibernation disabled the server stays awake, so the timer
--- will actually fire and bots won't be punted.
hook.Add("PlayerDisconnected", "TTTBots.Headless.PlayerDisconnected", function(ply)
    if not HEADLESS.IsEnabled() then return end
    if ply:IsBot() then return end

    -- Re-assert hibernation is disabled (belt-and-suspenders).
    EnsureNoHibernation()

    -- Small delay to let the engine process the disconnect
    timer.Simple(1, function()
        if not HEADLESS.IsEnabled() then return end

        -- Count remaining humans
        local humans = #player.GetHumans()
        if humans == 0 then
            -- No humans left — ensure bots keep the round going
            print("[TTT Bots 2] Headless mode: last human disconnected, keeping bots alive.")
            EnsureBotsForHeadless()
        end
    end)
end)

--- Hook into TTT2's round abort check.  When headless is enabled,
--- we prevent the round from aborting as long as there are enough
--- total players (including bots).
hook.Add("TTT2PreCheckForAbort", "TTTBots.Headless.PreventAbort", function()
    if not HEADLESS.IsEnabled() then return end

    -- Count all alive/ready players including bots
    local ready = 0
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsReady() then
            ready = ready + 1
        end
    end

    local minPlayers = GetConVar("ttt_minimum_players")
    local minNeeded = minPlayers and minPlayers:GetInt() or 2

    if ready >= minNeeded then
        -- Return true to tell TTT2 NOT to abort
        return true
    end
end)

--- Fallback for TTT2 versions that don't have TTT2PreCheckForAbort:
--- Override the HasEnoughPlayers logic by periodically forcing the
--- ttt_minimum_players cvar to 0 when headless is on and we have bots.
--- This is a sledgehammer approach but ensures compatibility.
timer.Create("TTTBots.Headless.ForceMinPlayers", 2, 0, function()
    if not TTTBots or not TTTBots.Headless or not HEADLESS.IsEnabled() then return end

    local botCount = #player.GetBots()
    if botCount == 0 then return end

    -- If headless mode is on and we have bots, ensure minimum_players
    -- is set to 1 so a single bot can trigger round start.
    local cv = GetConVar("ttt_minimum_players")
    if cv and cv:GetInt() > 1 then
        -- Store the original value so we can restore it
        HEADLESS._originalMinPlayers = HEADLESS._originalMinPlayers or cv:GetInt()
        RunConsoleCommand("ttt_minimum_players", "1")
    end
end)

--- Restore ttt_minimum_players and re-enable hibernation when headless mode is disabled.
cvars.AddChangeCallback("ttt_bot_headless", function(cvar, old, new)
    if tonumber(new) == 1 then
        -- Headless just got enabled — disable hibernation and seed bots
        EnsureNoHibernation()
        HEADLESS._initialSeedDone = false
        SeedBotsOnStartup()
    elseif tonumber(new) == 0 then
        if HEADLESS._originalMinPlayers then
            RunConsoleCommand("ttt_minimum_players", tostring(HEADLESS._originalMinPlayers))
            HEADLESS._originalMinPlayers = nil
        end
        -- Optionally re-enable hibernation when headless is turned off
        RunConsoleCommand("sv_hibernate_when_empty", "1")
        print("[TTT Bots 2] Headless mode disabled: re-enabled server hibernation.")
    end
end, "TTTBots.Headless.RestoreMinPlayers")

---------------------------------------------------------------------------
-- Post-initialization round restart
--
-- When booting in headless mode, the entrypoint script injects raw engine
-- bots via the FIFO ("bot" console command) to wake the server from
-- hibernation.  These raw bots lack TTTBot components and cause nil-index
-- errors when they interact with the bot system.  By the time TTTBots
-- fully initializes, a round may already be in progress with these broken
-- bots mixed in.
--
-- The fix: listen for the TTTBotsInitialized hook.  When it fires in
-- headless mode, kick any raw engine bots that lack components, then
-- force a round restart so the bot quota system can create proper bots
-- from scratch.
---------------------------------------------------------------------------
hook.Add("TTTBotsInitialized", "TTTBots.Headless.PostInitRestart", function()
    if not HEADLESS.IsEnabled() then return end

    print("[TTT Bots 2] Headless: TTTBots initialized — scheduling post-init cleanup...")

    -- Give a short delay for the system to stabilize (quota, roles, etc.)
    timer.Simple(5, function()
        if not HEADLESS.IsEnabled() then return end

        -- Kick raw engine bots that don't have TTTBot components.
        -- These were injected by the entrypoint FIFO to wake the server.
        local kicked = 0
        for _, ply in ipairs(player.GetBots()) do
            if IsValid(ply) and not ply.components then
                ply:Kick("Headless cleanup: replacing with TTTBot")
                kicked = kicked + 1
            end
        end
        if kicked > 0 then
            print(string.format("[TTT Bots 2] Headless: kicked %d raw engine bot(s) without components.", kicked))
        end

        -- Force a round restart so TTTBots' quota pipeline creates proper bots.
        timer.Simple(2, function()
            if not HEADLESS.IsEnabled() then return end
            print("[TTT Bots 2] Headless: forcing round restart for clean bot setup...")
            RunConsoleCommand("ttt_roundrestart")
        end)
    end)
end)

print("[TTT Bots 2] Headless mode module loaded.")
