--- This file is a shared resource called by both cl_tttbots2.lua and sv_tttbots2.lua in their respective autorun realms.
--- It is used to initialize the mod and load all of the necessary files.

AddCSLuaFile() -- Add this file to the client's download list

--- Checks if the current engine.ActiveGamemode is compatible with TTT Bots
---@return boolean
local gamemodeCompatible = function()
    local compatible = { ["terrortown"] = true }
    return compatible[engine.ActiveGamemode()] or false
end

if not gamemodeCompatible() then return end

-- Declare TTTBots table
TTTBots = {
    Version = "v1.3",
    Tickrate = 5, -- Ticks per second. Overridden by the ttt_bot_tickrate cvar at runtime.
    Lib = {},
    Chat = {}
}

--- Read the base tick rate from the cvar (or fall back to the default 5).
--- Called during Reload() to pick up cvar changes and auto-adjust results.
function TTTBots.RefreshTickrate()
    local cv = GetConVar("ttt_bot_tickrate")
    local rate = cv and cv:GetInt() or 5
    TTTBots.Tickrate = math.Clamp(rate, 1, 20)
end

function TTTBots.Chat.MessagePlayer(ply, message)
    ply:ChatPrint("[TTT Bots 2] " .. message)
end

--- P2 Perf: Adaptive ThinkRate scaling.
--- Returns a multiplier (1..max) based on current bot count.
--- Below the threshold: returns 1 (no scaling). Above: logarithmic ramp.
---@return number multiplier
function TTTBots.GetAdaptiveThinkRateMultiplier()
    local cv = GetConVar("ttt_bot_adaptive_thinkrate")
    if not (cv and cv:GetBool()) then return 1 end

    local botCount = #(TTTBots.Bots or {})
    local threshold = GetConVar("ttt_bot_adaptive_thinkrate_threshold")
    threshold = threshold and threshold:GetInt() or 12
    if botCount <= threshold then return 1 end

    local maxMulti = GetConVar("ttt_bot_adaptive_thinkrate_max_multi")
    maxMulti = maxMulti and maxMulti:GetInt() or 3

    -- Logarithmic ramp: multi = 1 + log2(botCount / threshold)
    local ratio = botCount / threshold
    local multi = 1 + math.log(ratio) / math.log(2)
    return math.Clamp(math.floor(multi), 1, maxMulti)
end

local function includeServer()
    include("tttbots2/lib/sv_proximity.lua")
    include("tttbots2/lib/sv_pathmanager.lua")
    include("tttbots2/lib/sv_debug.lua")
    include("tttbots2/lib/sv_miscnetwork.lua")
    include("tttbots2/lib/sv_debug.lua")
    include("tttbots2/lib/sv_debuglog.lua")
    include("tttbots2/lib/sv_popularnavs.lua")
    include("tttbots2/lib/sv_providers.lua")
    include("tttbots2/lib/sv_TTS.lua")
    include("tttbots2/lib/sv_TTS_url.lua")
    include("tttbots2/lib/sv_chatGPT.lua")
    include("tttbots2/lib/sv_gemini.lua")
    include("tttbots2/lib/sv_deepSeek.lua")
    include("tttbots2/lib/sv_ollama.lua")
    include("tttbots2/lib/sv_openrouter.lua")
    include("tttbots2/lib/sv_spots.lua")
    include("tttbots2/lib/sv_tickscaler.lua")
    include("tttbots2/lib/sv_plancoordinator.lua")
    include("tttbots2/lib/sv_planlearning.lua")
    include("tttbots2/lib/sv_innocentcoordinator.lua")
    include("tttbots2/lib/sv_infectedcoordinator.lua")
    include("tttbots2/lib/sv_necrocoordinator.lua")
    include("tttbots2/lib/sv_cursedcoordinator.lua")
    include("tttbots2/lib/sv_doomguycoordinator.lua")
    include("tttbots2/lib/sv_amnesiaccoordinator.lua")
    include("tttbots2/lib/sv_pharaohcoordinator.lua")
    include("tttbots2/commands/sv_chatcommands.lua")
    include("tttbots2/lib/sv_headless.lua")
    include("tttbots2/lib/sv_planstats_network.lua")
    include("tttbots2/lib/sv_customplans.lua")
    include("tttbots2/lib/sv_dialog.lua")
    include("tttbots2/lib/sv_tree.lua")
    include("tttbots2/lib/sv_buyables.lua")
    include("tttbots2/lib/sv_adaptive_difficulty.lua")
    include("tttbots2/lib/sv_roles.lua")
    include("tttbots2/lib/sv_errortracker.lua")
    include("tttbots2/lib/sv_swep_threat_response.lua")
    include("tttbots2/lib/sv_suspicion_net.lua")
end

--- Similar to includeSharedFile, will include the file if we're a client, otherwise will AddCSLuaFile it if we're a server.
local function includeClientFile(path)
    if SERVER then AddCSLuaFile(path) end
    if CLIENT then include(path) end
end

local function includeClient()
    includeClientFile("tttbots2/client/cl_debug3d.lua")
    includeClientFile("tttbots2/client/cl_debugui.lua")
    includeClientFile("tttbots2/client/cl_scoreboard.lua")
    includeClientFile("tttbots2/client/cl_botmenu.lua")
    includeClientFile("tttbots2/client/cl_planstats.lua")
    includeClientFile("tttbots2/client/cl_customplans.lua")
    includeClientFile("tttbots2/client/cl_TTS.lua")
    includeClientFile("tttbots2/lib/cl_ratelimiter.lua")
    includeClientFile("tttbots2/client/cl_errortracker.lua")
    includeClientFile("tttbots2/client/cl_suspicion_monitor.lua")
end

--- Places the file in the AddCSLuaFile if server, otherwise loads it if we're a client. Includes the file either way.
---@param path string
---@param isReload? boolean = false
local function includeSharedFile(path, isReload)
    if not isReload and SERVER then AddCSLuaFile(path) end
    include(path)
end

---Include the shared files
---@param isReload? boolean = false
local function includeShared(isReload)
    includeSharedFile("tttbots2/lib/sh_errortracker.lua", isReload) -- Error tracker — loaded first for early capture
    includeSharedFile("tttbots2/lib/sh_events.lua", isReload)   -- Event bus — loaded first so all other modules can subscribe
    includeSharedFile("tttbots2/lib/sh_botlib.lua", isReload)
    includeSharedFile("tttbots2/commands/sh_cvars.lua", isReload)
    includeSharedFile("tttbots2/commands/sh_concommands.lua", isReload)
    includeSharedFile("tttbots2/lib/sh_match.lua", isReload)
    includeSharedFile("tttbots2/data/sh_traits.lua", isReload)
    includeSharedFile("tttbots2/lib/sh_languages.lua", isReload)
    includeSharedFile("tttbots2/lib/sh_botlib.lua", isReload)
    includeSharedFile("tttbots2/lib/sh_prompt_context.lua", isReload)   -- Tier 8: game-state context + accusation prompts
    includeSharedFile("tttbots2/lib/sh_chatgpt_prompts.lua", isReload)
    includeSharedFile("tttbots2/lib/sh_llama_prompts.lua", isReload)
end

-- These first two need to run on both realms so we can AddCSLuaFile.
includeShared()
includeClient()

if not SERVER then return end
util.AddNetworkString("TTTBots_DrawData")
util.AddNetworkString("TTTBots_ClientData")
util.AddNetworkString("TTTBots_RequestData")
util.AddNetworkString("TTTBots_SyncAvatarNumbers")
util.AddNetworkString("TTTBots_RequestConCommand")
util.AddNetworkString("TTTBots_RequestCvarUpdate")
util.AddNetworkString("TTTBots_RequestPlanStats")
util.AddNetworkString("TTTBots_PlanStatsData")
util.AddNetworkString("TTTBots_CustomPlan_Create")
util.AddNetworkString("TTTBots_CustomPlan_Delete")
util.AddNetworkString("TTTBots_CustomPlan_Update")
util.AddNetworkString("TTTBots_CustomPlan_Sync")
util.AddNetworkString("TTTBots_CustomPlan_RequestSync")
util.AddNetworkString("SayTTSEL")
util.AddNetworkString("SayTTSBad")
util.AddNetworkString("TTTBots_ErrorTracker_Error")
-- Suspicion Monitor: real-time suspicion debugging
util.AddNetworkString("TTTBots_RequestSuspicionData")
util.AddNetworkString("TTTBots_SuspicionData")
-- Bot Menu: bot info + buyable list networking
util.AddNetworkString("TTTBots_RequestBotMenuData")
util.AddNetworkString("TTTBots_BotMenuData")
-- Cupid role compatibility: bot-side lover linking sends these messages directly.
util.AddNetworkString("inLove")
util.AddNetworkString("betrayedTraitor")

local hasNavmesh = function() return navmesh.GetNavAreaCount() > 0 end
local alreadyAddedResources = false
--- Maximum seconds to wait for init checks before forcing init.
local HEADLESS_INIT_TIMEOUT = 30

---------------------------------------------------------------------------
-- HEADLESS / BOT-ONLY SERVER BOOT SYSTEM
--
-- Problem chain (discovered over many iterations):
--   1. sv_hibernate_when_empty does NOT exist as a real engine ConVar on
--      this srcds build.  "Unknown command" in cfg. GetConVar returns nil.
--   2. CreateConVar() creates a Lua-side ConVar but the engine's C++
--      hibernation code ignores it — the server STILL hibernates.
--   3. With 0 human players the engine hibernates, killing ALL Lua:
--      timers (Simple + Create), Think hooks — everything stops.
--   4. player.CreateNextBot() creates a bot but NextBots don't prevent
--      hibernation — only real client connections do.
--   5. RealTime() returns 0.0 at InitPostEntity. CurTime() returns 1.0.
--      Neither advances until the engine enters its main game loop.
--   6. Everything from InitPostEntity through navmesh, cfg exec, Steam
--      init happens in a single non-interactive sequence. No hooks fire.
--
-- Solution (two-part):
--   PART 1 (entrypoint.sh): A background keepalive process monitors
--   console.log for "VAC secure mode" then sends the "bot" command to
--   srcds via a named pipe (FIFO). The engine's "bot" command creates a
--   real fake-client connection (unlike CreateNextBot), which the engine
--   counts as a connected player, preventing re-hibernation.
--
--   PART 2 (this file): A Think hook registered at autorun time waits
--   for the server to wake up. Once the FIFO-injected bot connects and
--   the engine starts ticking, Think fires and we begin the init loop.
--   After HEADLESS_INIT_TIMEOUT seconds, init is forced regardless of
--   navmesh status.
---------------------------------------------------------------------------

local _initStarted = false
local _initDone = false
local _lastAttemptTime = -999
local _attemptCount = 0

--- Core initialization function. Called repeatedly from Think hook.
local function tryInitialize()
    if _initDone then return end

    _attemptCount = _attemptCount + 1

    -- Read headless cvar (should have cfg value by now since server is awake)
    local headlessCvar = GetConVar("ttt_bot_headless")
    local isHeadless = headlessCvar and headlessCvar:GetBool() or false
    local navAreas = navmesh.GetNavAreaCount()

    print(string.format("[TTT Bots 2] Init attempt #%d (headless=%s, navmesh_areas=%d, players=%d, CurTime=%.1f, RealTime=%.1f)",
        _attemptCount, tostring(isHeadless), navAreas, #player.GetAll(), CurTime(), RealTime()))

    -- Check if navmesh is available
    local navOk = navAreas > 0

    -- Force init after timeout
    local forceInit = _attemptCount >= HEADLESS_INIT_TIMEOUT

    if navOk then
        print("[TTT Bots 2] Init check 'hasNavmesh' PASSED.")
    elseif forceInit then
        print(string.format("[TTT Bots 2] WARNING: hasNavmesh still FAILED after %d attempts — forcing init.", _attemptCount))
    else
        print(string.format("[TTT Bots 2] Init check 'hasNavmesh' FAILED — will retry (attempt %d/%d)...",
            _attemptCount, HEADLESS_INIT_TIMEOUT))
        return
    end

    -- SUCCESS: Initialize the bot system
    _initDone = true
    hook.Remove("Think", "TTTBots_InitRetryThink")
    hook.Remove("PlayerInitialSpawn", "TTTBots_WakeUpTrigger")
    print("[TTT Bots 2] ========================================")
    print("[TTT Bots 2] All init checks passed — Initializing TTT Bots...")
    print(string.format("[TTT Bots 2] headless=%s, navmesh_areas=%d, forced=%s",
        tostring(isHeadless), navAreas, tostring(forceInit)))

    local ok, err = pcall(TTTBots.Reload)
    if ok then
        print("[TTT Bots 2] TTTBots.Reload() completed successfully.")
        hook.Run("TTTBotsInitialized", TTTBots)
        print("[TTT Bots 2] TTTBotsInitialized hook fired. Bot system is LIVE.")
    else
        print("[TTT Bots 2] ERROR: TTTBots.Reload() failed: " .. tostring(err))
        ErrorNoHaltWithStack(err)
    end
end

-- THINK HOOK: fires every frame once the server is awake.
-- While hibernating this never runs. The moment a human connects
-- (or the engine otherwise wakes), this starts firing immediately.
hook.Add("Think", "TTTBots_InitRetryThink", function()
    if _initDone then return end

    -- First Think frame ever: log wake-up
    if not _initStarted then
        _initStarted = true
        _lastAttemptTime = RealTime()
        print("[TTT Bots 2] ========================================")
        print(string.format("[TTT Bots 2] Think hook ALIVE! Server is awake. (CurTime=%.1f, RealTime=%.1f, players=%d)",
            CurTime(), RealTime(), #player.GetAll()))
        print("[TTT Bots 2] Starting init retry loop (1 attempt/second)...")
        print("[TTT Bots 2] ========================================")
        -- Run first attempt immediately
        tryInitialize()
        return
    end

    -- Throttle: one attempt per second using RealTime
    local now = RealTime()
    if now - _lastAttemptTime < 1.0 then return end
    _lastAttemptTime = now

    tryInitialize()
end)

-- BELT-AND-SUSPENDERS: PlayerInitialSpawn fires when any player
-- (human or bot) first joins. If Think somehow hasn't started yet,
-- this gives us another chance.
hook.Add("PlayerInitialSpawn", "TTTBots_WakeUpTrigger", function(ply)
    if _initDone then return end
    if _initStarted then return end -- Think is already handling it

    print(string.format("[TTT Bots 2] PlayerInitialSpawn trigger: %s (bot=%s). Starting init...",
        tostring(ply), tostring(ply:IsBot())))

    _initStarted = true
    _lastAttemptTime = RealTime()
    tryInitialize()
end)

print("[TTT Bots 2] Autorun: Think + PlayerInitialSpawn hooks registered for deferred init.")
print("[TTT Bots 2] Server will initialize bots when first player connects (or when Think starts).")

---Load all of the mod's depdenencies and initialize the mod
function TTTBots.Reload()
    -- Pick up the current tickrate cvar value before building the timer
    TTTBots.RefreshTickrate()

    includeServer()

    -- Shorthands
    local Lib = TTTBots.Lib
    local PathManager = TTTBots.PathManager

    -- Cache navmesh data (safe even if no navmesh exists — will just be empty)
    local ok, err = pcall(function()
        TTTBots.Spots.CacheAllSpots()
        TTTBots.Lib.GetNavRegions()
    end)
    if not ok then
        print("[TTT Bots 2] WARNING: Failed to cache navmesh spots: " .. tostring(err))
        print("[TTT Bots 2] Bots will have limited navigation capabilities.")
    end

    -- Bot behavior
    timer.Create("TTTBots_Tick", 1 / TTTBots.Tickrate, 0, function()
        -- Performance sampling: record tick start for auto-adjuster
        if TTTBots.TickRateAuto then TTTBots.TickRateAuto.BeginSample() end

        -- P1 Perf: Cache player.GetAll() once per tick so all components
        -- and sub-systems use the same snapshot without re-querying the engine.
        TTTBots._tickPlayers = player.GetAll()

        local call, err = pcall(function()
            -- _testBotAttack()
            TTTBots.Match.Tick()

            -- Dynamic tick scaler: recalculate skip value once per tick
            TTTBots.TickScaler.Recalculate()

            -- Run behavior trees for ALL bots every tick.
            -- The behavior tree assigns goals (walk targets, attack targets, etc.)
            -- that the locomotor needs to execute movement. Skipping the tree causes
            -- bots to stand still because the locomotor has no goals to follow.
            -- Component ThinkRate throttling (below) already reduces per-component
            -- CPU cost — the tree itself is cheap and must always run.
            for _, bot in ipairs(TTTBots.Bots) do
                if not IsValid(bot) then continue end
                if not bot.components then continue end
                local tree = TTTBots.Behaviors.GetTreeFor(bot)
                if not tree then continue end
                TTTBots.Behaviors.RunTree(bot, tree)
            end

            TTTBots.PlanCoordinator.Tick()
            if TTTBots.InnocentCoordinator then TTTBots.InnocentCoordinator.Tick() end
            local bots = TTTBots.Bots
            for i, bot in pairs(bots) do
                -- TTTBots.DebugServer.RenderDebugFor(bot, { "all" })
                if not (IsValid(bot) and bot and bot.components) then continue end -- Sometimes a weird bug or edge case occurs, just ignore it

                -- Keep bot.tick in sync BEFORE components run so ThinkRate arithmetic never sees nil
                local loco = bot:BotLocomotor()
                bot.tick = loco and loco.tick or 0

                -- Dynamic tick scaler: skip component Think for throttled bots this tick.
                -- timeInGame always advances so round-time tracking stays accurate.
                local botShouldThink = TTTBots.TickScaler.ShouldBotThink(bot)

                -- Emergency escalation: skip behavior trees for non-combat bots
                -- when performance is still bad at minimum tick rate.
                local escalationTreeSkip = false
                if TTTBots.TickRateAuto and TTTBots.TickRateAuto.ShouldSkipBehaviorTree then
                    escalationTreeSkip = TTTBots.TickRateAuto.ShouldSkipBehaviorTree(bot)
                end

                -- Emergency escalation: multiply component ThinkRates when
                -- the auto-adjuster has escalated beyond tick rate reduction.
                local thinkRateMulti = 1
                if TTTBots.TickRateAuto and TTTBots.TickRateAuto.GetThinkRateMultiplier then
                    thinkRateMulti = TTTBots.TickRateAuto.GetThinkRateMultiplier()
                end

                -- P2 Perf: Adaptive ThinkRate scaling by bot count.
                -- When many bots are active, automatically slow non-critical
                -- components so total CPU cost grows sub-linearly.
                local adaptiveMulti = TTTBots.GetAdaptiveThinkRateMultiplier
                    and TTTBots.GetAdaptiveThinkRateMultiplier() or 1
                thinkRateMulti = thinkRateMulti * adaptiveMulti

                for i, component in pairs(bot.components) do
                    if component.Think == nil then
                        print("No think")
                        continue
                    end
                    -- Dynamic tick scaler gate: if this bot is throttled, skip
                    -- component thinking — but ALWAYS let locomotor run.
                    -- StartCommand only reads movement state that Think() computes;
                    -- without Think(), movementVec goes stale and the bot freezes.
                    if not botShouldThink and component ~= bot.components.locomotor then continue end
                    -- Escalation gate: if the behavior tree is being skipped
                    -- for this bot, also skip heavy components (but not locomotor).
                    if escalationTreeSkip and component ~= bot.components.locomotor then continue end
                    -- ThinkRate throttling: ThinkRate=1 runs every tick, 2=every other tick, etc.
                    -- Emergency escalation multiplies the rate to slow components further.
                    local rate = (component.ThinkRate or 1) * thinkRateMulti
                    if rate <= 1 or (bot.tick % rate == 0) then
                        component:Think()
                    end
                end

                bot.timeInGame = (bot.timeInGame or 0) + (1 / TTTBots.Tickrate)
            end
            TTTBots.Lib.UpdateBotModels()
        end, function(err)
            print("ERROR:", err)
        end)
        if err then
            ErrorNoHaltWithStack(err)
        end

        -- Performance sampling: record tick end for auto-adjuster
        if TTTBots.TickRateAuto then TTTBots.TickRateAuto.EndSample() end
    end)

    -- GM:StartCommand
    hook.Add("StartCommand", "TTTBots_StartCommand", function(ply, cmd)
        if ply:IsBot() then
            local bot = ply
            -- Guard: components table may not be populated yet on the first ticks after bot creation.
            if not bot.components then return end
            local locomotor = bot:BotLocomotor()
            if not locomotor then return end

            -- Update locomotor
            locomotor:StartCommand(cmd)
        end
    end)

    -- Function to notify players (when bots are masked from the scoreboard) that there are bots in the server.
    -- This is for ethical purposes and to prevent the mod breaching the Steam Workshop/Garry's Mod guidelines.
    -- The bot masking features should ONLY ever be used on a private server with consenting players, and this is why this notification exists.
    hook.Add("TTTBeginRound", "TTTBots_EthicalNotify", function()
        if table.IsEmpty(TTTBots.Bots) then return end
        local msg = TTTBots.Locale.GetLocalizedString("bot.notice", #TTTBots.Bots)
        local notifyAnyway = Lib.GetConVarBool("notify_always")

        -- If any of these 3 are FALSE, then it is obvious who is a bot, so we don't need to notify.
        local humanlikePfps = (not Lib.GetConVarBool("pfps")) or
            Lib.GetConVarBool("pfps_humanlike")                    -- If pfps are disabled or they are humanlike
        local emulatePing = Lib.GetConVarBool("emulate_ping")      -- If ping is emulated (instead of reading "BOT")
        local noPrefixes = not Lib.GetConVarBool("names_prefixes") -- If their usernames aren't prefixed by [BOT]

        if notifyAnyway or (humanlikePfps and emulatePing and noPrefixes) then
            TTTBots.Chat.BroadcastInChat(msg)
            print(msg)
        end
    end)

    -- Send avatars to clients
    if alreadyAddedResources then return end
    alreadyAddedResources = true

    local f = string.format

    for i = 0, 5 do
        resource.AddFile(f("materials/avatars/%d.png", i))
    end

    for i = 0, 87 do
        resource.AddFile(f("materials/avatars/humanlike/%d.jpg", i))
    end
end

-- Init checks are now handled by the InitPostEntity → Think hook chain above.
-- The old initializeIfChecksPassed() / timer.Simple retry loop has been removed
-- because timer.Simple is killed by engine hibernation.