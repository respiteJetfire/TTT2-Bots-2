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

local function includeServer()
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
    include("tttbots2/lib/sv_innocentcoordinator.lua")
    include("tttbots2/lib/sv_infectedcoordinator.lua")
    include("tttbots2/lib/sv_necrocoordinator.lua")
    include("tttbots2/lib/sv_cursedcoordinator.lua")
    include("tttbots2/lib/sv_doomguycoordinator.lua")
    include("tttbots2/lib/sv_amnesiaccoordinator.lua")
    include("tttbots2/lib/sv_pharaohcoordinator.lua")
    include("tttbots2/commands/sv_chatcommands.lua")
    include("tttbots2/lib/sv_dialog.lua")
    include("tttbots2/lib/sv_tree.lua")
    include("tttbots2/lib/sv_buyables.lua")
    include("tttbots2/lib/sv_roles.lua")
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
    includeClientFile("tttbots2/client/cl_TTS.lua")
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
util.AddNetworkString("SayTTSEL")
util.AddNetworkString("SayTTSBad")
-- Cupid role compatibility: bot-side lover linking sends these messages directly.
util.AddNetworkString("inLove")
util.AddNetworkString("betrayedTraitor")

local hasNavmesh = function() return navmesh.GetNavAreaCount() > 0 end
local alreadyAddedResources = false

---Load all of the mod's depdenencies and initialize the mod
function TTTBots.Reload()
    -- Pick up the current tickrate cvar value before building the timer
    TTTBots.RefreshTickrate()

    includeServer()

    -- Shorthands
    local Lib = TTTBots.Lib
    local PathManager = TTTBots.PathManager

    TTTBots.Spots.CacheAllSpots() -- Cache all navmesh spots (cover, exposed, sniper spots, etc.)
    TTTBots.Lib.GetNavRegions()   -- Caches all nav regions

    -- Bot behavior
    timer.Create("TTTBots_Tick", 1 / TTTBots.Tickrate, 0, function()
        -- Performance sampling: record tick start for auto-adjuster
        if TTTBots.TickRateAuto then TTTBots.TickRateAuto.BeginSample() end

        local call, err = pcall(function()
            -- _testBotAttack()
            TTTBots.Match.Tick()

            -- Dynamic tick scaler: recalculate skip value once per tick
            TTTBots.TickScaler.Recalculate()

            -- Run behavior trees only on bots that the tick scaler allows
            -- this tick. When scaling is disabled every bot passes.
            -- Emergency escalation may additionally skip tree runs for idle bots.
            for _, bot in ipairs(TTTBots.Bots) do
                if not IsValid(bot) then continue end
                if not bot.components then continue end
                if not TTTBots.TickScaler.ShouldBotThink(bot) then continue end
                -- Escalation: skip behavior tree for non-combat bots when under heavy load
                if TTTBots.TickRateAuto and TTTBots.TickRateAuto.ShouldSkipBehaviorTree
                   and TTTBots.TickRateAuto.ShouldSkipBehaviorTree(bot) then
                    continue
                end
                local tree = TTTBots.Behaviors.GetTreeFor(bot)
                if not tree then continue end
                TTTBots.Behaviors.RunTree(bot, tree)
            end

            TTTBots.PlanCoordinator.Tick()
            TTTBots.InnocentCoordinator.Tick()
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

                for i, component in pairs(bot.components) do
                    if component.Think == nil then
                        print("No think")
                        continue
                    end
                    -- Dynamic tick scaler gate: if this bot is throttled, skip
                    -- component thinking entirely (locomotor still runs via
                    -- StartCommand so movement doesn't freeze).
                    if not botShouldThink then continue end
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

local initChecks = {}

local function addInitCheck(data)
    initChecks[data.name] = data
    initChecks[data.name].notifiedPlayers = {}
    initChecks[data.name].dontChat = data.dontChat or false
end

addInitCheck({
    name = "hasNavmesh",
    callback = hasNavmesh,
    adminsOnly = true,
    msg = TTTBots.Locale.GetLocalizedString("no.navmesh")
})

local function chatCheck(check)
    local msg = check.msg
    for i, v in pairs(player.GetHumans()) do
        if (check.adminsOnly and not v:IsSuperAdmin()) then continue end
        if check.notifiedPlayers[v] then continue end
        if not check.dontChat then
            v:ChatPrint("TTT Bots: " .. msg)
        else
            print("TTT Bots: " .. check.msg)
        end
        check.notifiedPlayers[v] = true
    end
end

-- Initialization
local function initializeIfChecksPassed()
    for i, check in pairs(initChecks) do
        local passed = check.callback()
        if (not passed) then
            chatCheck(check)
            timer.Simple(1, initializeIfChecksPassed)
            return
        end
    end

    print("[TTT Bots 2] Initializing TTT Bots...")
    TTTBots.Reload()
    hook.Run("TTTBotsInitialized", TTTBots)
end

initializeIfChecksPassed()