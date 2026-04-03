--- sv_chatter_precache.lua
--- On server boot (or first round), iterates all registered chatter events and
--- uses LLM generation to cache fallback lines for any event × archetype
--- combination that has no locale strings.  The generated lines are injected
--- into TTTBots.Locale via AddLine() so they serve as first-class locale
--- entries going forward — eliminating the "No localized strings for event X"
--- warnings entirely.
---
--- Gated behind the cvar ttt_bot_chatter_precache_llm (default 0).
--- Requires ttt_bot_llm_enabled = 1.

local lib = TTTBots.Lib
local BotChatter = TTTBots.Components.Chatter

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

TTTBots.ChatterPrecache = TTTBots.ChatterPrecache or {
    --- Events that have already been precached (set of event names → true)
    completed       = {},
    --- Pending queue: array of {event, archetype, description} tables
    queue           = {},
    --- Is the queue currently being drained?
    running         = false,
    --- Total generated this session
    generated       = 0,
    --- Total failed this session
    failed          = 0,
    --- Has the initial scan been done?
    scanned         = false,
}

local PC = TTTBots.ChatterPrecache

-- ---------------------------------------------------------------------------
-- Archetype list (all archetypes that bots can have)
-- ---------------------------------------------------------------------------

local ALL_ARCHETYPES = {
    "default",
    "Tryhard/nerd",
    "Hothead",
    "Stoic",
    "Dumb",
    "Nice",
    "Bad",
    "Teamer",
    "Sus/Quirky",
    "Casual",
}

--- Reverse-map archetype values back to keys for GetArchetypeDescription().
--- (Locale lines store the value, e.g. "Tryhard/nerd", but ARCHETYPE_DESC
---  in sh_chatgpt_prompts.lua is keyed by the short name, e.g. "Tryhard".)
local ARCHETYPE_VALUE_TO_KEY = {}
for k, v in pairs(TTTBots.Archetypes or {}) do
    ARCHETYPE_VALUE_TO_KEY[v] = k
end

-- ---------------------------------------------------------------------------
-- Master event registry — collects ALL possible chatter events.
-- Populated from: chancesOf100 (exported), RegisterCategory calls (Locale.Priorities),
-- and a hardcoded supplementary list for events fired via chatter:On() that may
-- not appear in either of the above.
-- ---------------------------------------------------------------------------

--- Supplementary events that are fired by behaviors but may not appear in
--- chancesOf100 or RegisterCategory. This list is a safety-net to catch any
--- events that would otherwise produce the "No localized strings" warning.
local SUPPLEMENTARY_EVENTS = {
    -- NPC launcher weapons
    "DeployingCombineLauncher",
    "DeployingFastZombieLauncher",
    "DeployingHeadcrabLauncher",
    -- Equipment / weapon usage
    "DeployingGravityMine",
    "DeployingTurret",
    "TurretDeployed",
    "DeployingDecoy",
    "PlacingHealthStation",
    "UseTraitorButton",
    "UsingTimestop",
    "TimestopUsed",
    "TimestopHunting",
    "TimestopKill",
    "TimestopMassacre",
    "ThrowGrenade",
    "DeployedRoleChecker",
    "HighNoon",
    "PeacekeeperFired",
    "RoleDefibStart",
    "SpottedMurderWeapon",
    -- Spy events
    "SpyBlendIn",
    "SpyFakeBuy",
    "SpyReportIntel",
    "SpyReactJam",
    "SpyCoverBlow",
    "SpyDeflection",
    "SpySurvival",
    "TraitorSuspectsSpy",
    "TraitorDiscoversSpy",
    "SpyPostReveal",
    "SpyEavesdrop",
    -- Copycat events
    "CopycatSeekingCorpse",
    "CopycatTranscribed",
    "CopycatSwitching",
    "CopycatSwitchSuccess",
    "CopycatRoleReceived",
    "CopycatPostSwitch",
    "CopyingRole",
    -- Hidden events
    "HiddenSpotted",
    -- Defector events
    "DefectorConverted",
    "DefectorApproaching",
    "DefectorDropping",
    -- Priest events
    "PriestConverting",
    "PriestConvertSuccess",
    "PriestBrotherDied",
    "PriestDetectiveShot",
    "PriestEvilKill",
    "PriestBrotherhoodStrong",
    "CreatingPriestBrother",
    -- Zombie / Necro events
    "NecroRevivingZombie",
    "ZombieRisen",
    "NecroZombieSpotted",
    "NecroMasterKilled",
    "NecroMasterDied",
    "NecroVictory",
    "ZombieAmmoLow",
    "ZombieSelfDestruct",
    "NecroTeamRally",
    "NecroTeamStrategy",
    -- SK events
    "SKHunting",
    "SKKnifeKill",
    "SKShakeNade",
    "SKGloat",
    "SKLastStand",
    "SKSpotted",
    "SKVictory",
    "SKSpottedByOthers",
    -- Ankh / Pharaoh events
    "PlacedAnkh",
    "AnkhStolen",
    "AnkhRecovered",
    "AnkhDestroyed",
    "AnkhRevival",
    "GraverobberStoleAnkh",
    "AnkhSpotted",
    "DefendAnkh",
    "HuntingAnkh",
    -- Contract events
    "NewContract",
    "ContractAccepted",
    -- Buy events (common ones)
    "BuyRadar",
    "BuyDisguise",
    "BuyBodyArmor",
    -- Help / Call events
    "CallHelp",
    "CallKOS",
    "AskAttack",
    -- Smart Bullets events
    "SmartBulletsActivated",
    "SmartBulletsKill",
    "SmartBulletsExpired",
    "SmartBulletsDetected",
    "SmartBulletsKOS",
    "SmartBulletsWarning",
    "SmartBulletsSurvived",
    -- Clown events
    "ClownRoundStart",
    "ClownSurviving",
    "ClownNearTransform",
    "ClownTransformed",
    "ClownTransformWitnessed",
    "TraitorSeesClownTransform",
    "KillerClownHunting",
    "KillerClownKill",
    "KillerClownLastTarget",
    "KillerClownTakingDamage",
    -- Evidence / Miscellaneous
    "EvidenceShare",
    "ProximityCallout",
    -- Revive / Role events
    "RevivingPlayer",
    "RoleDefibPlayer",
    -- Oracle / Clairvoyant
    "OracleReveal",
    "ClairvoyantReveal",
    "ClairvoyantJesterHunt",
    "ClairvoyantSidekickSuccess",
    "ClairvoyantIntelComplete",
}

--- Build a deduplicated set of all known event names.
---@return table<string, boolean>  eventName → true
local function collectAllEvents()
    local events = {}

    -- 1. From the exported chancesOf100 table (populated by sv_chatter_events.lua)
    if TTTBots.ChatterEventChances then
        for eventName, _ in pairs(TTTBots.ChatterEventChances) do
            events[eventName] = true
        end
    end

    -- 2. From registered locale categories (Priorities table)
    if TTTBots.Locale and TTTBots.Locale.Priorities then
        for eventName, _ in pairs(TTTBots.Locale.Priorities) do
            events[eventName] = true
        end
    end

    -- 3. Supplementary events hardcoded above
    for _, eventName in ipairs(SUPPLEMENTARY_EVENTS) do
        events[eventName] = true
    end

    return events
end

--- Check whether an event has at least one locale line in the current language.
---@param eventName string
---@return boolean
local function eventHasLocaleLines(eventName)
    local lang = lib.GetConVarString("language") or "en"
    local tbl = TTTBots.Locale[lang] and TTTBots.Locale[lang][eventName]
    return tbl and #tbl > 0
end

--- Check whether a specific event + archetype pair has at least one line.
---@param eventName string
---@param archetype string
---@return boolean
local function eventHasArchetypeLine(eventName, archetype)
    local lang = lib.GetConVarString("language") or "en"
    local tbl = TTTBots.Locale[lang] and TTTBots.Locale[lang][eventName]
    if not tbl or #tbl == 0 then return false end
    for _, entry in ipairs(tbl) do
        if entry.archetype == archetype or entry.archetype == "default" then
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- LLM prompt for generating fallback lines
-- ---------------------------------------------------------------------------

--- Build the LLM prompt to generate a fallback chat line for a given event.
---@param eventName string
---@param archetype string
---@param description string|nil
---@return table  { system = string, prompt = string }
local function buildPrecachePrompt(eventName, archetype, description)
    -- Map locale archetype value to ARCHETYPE_DESC key
    local descKey = ARCHETYPE_VALUE_TO_KEY[archetype] or archetype
    local archetypeDesc = TTTBots.ChatGPTPrompts
        and TTTBots.ChatGPTPrompts.GetArchetypeDescription(descKey)
        or ("Personality: " .. archetype)

    local system = string.format(
        "You are a chat line generator for Trouble in Terrorist Town bots in Garry's Mod. "
        .. "Generate a single short in-game chat message (max 12 words) that a bot would say "
        .. "for the given game event. The bot's personality archetype is: %s. "
        .. "RULES: Write ONLY the chat message. No quotes, no asterisks, no narration, no name prefix. "
        .. "Keep parameters like {{player}}, {{victim}}, {{attacker}} etc. as-is — do NOT replace them. "
        .. "Do NOT include any explanation.",
        archetypeDesc
    )

    local promptParts = {
        string.format("Generate a chat line for the event '%s'.", eventName),
    }

    if description and description ~= "" then
        table.insert(promptParts, "Event description: " .. description)
    end

    -- Provide a style example from existing locale if any lines exist for a different archetype
    local lang = lib.GetConVarString("language") or "en"
    local existingLines = TTTBots.Locale[lang] and TTTBots.Locale[lang][eventName]
    if existingLines and #existingLines > 0 then
        local example = existingLines[math.random(1, #existingLines)]
        if example and example.line then
            table.insert(promptParts, "Style example (different archetype): " .. example.line)
        end
    end

    table.insert(promptParts, string.format("Write a line matching the '%s' archetype:", archetype))

    return { system = system, prompt = table.concat(promptParts, " ") }
end

-- ---------------------------------------------------------------------------
-- Queue processing
-- ---------------------------------------------------------------------------

--- How many LLM requests to make per batch before yielding (timer tick).
local BATCH_SIZE = 2
--- Delay in seconds between batches.
local BATCH_DELAY = 1.5
--- Maximum concurrent in-flight requests.
local MAX_INFLIGHT = 3

local inflight = 0

--- Process the next batch of items from the precache queue.
local function processNextBatch()
    if #PC.queue == 0 then
        PC.running = false
        print(string.format(
            "[TTTBots:Precache] Precache complete. Generated: %d, Failed: %d, Total events scanned: %d",
            PC.generated, PC.failed, table.Count(PC.completed)
        ))
        return
    end

    local processed = 0
    while processed < BATCH_SIZE and #PC.queue > 0 and inflight < MAX_INFLIGHT do
        local item = table.remove(PC.queue, 1)
        if not item then break end

        local eventName = item.event
        local archetype = item.archetype
        local description = item.description

        -- Double-check: maybe another request already filled this slot
        if eventHasArchetypeLine(eventName, archetype) then
            processed = processed + 1
            continue
        end

        local promptData = buildPrecachePrompt(eventName, archetype, description)

        inflight = inflight + 1
        processed = processed + 1

        TTTBots.Providers.SendText(promptData.prompt, nil, {
            teamOnly = false,
            wasVoice = false,
            systemPrompt = promptData.system,
            eventName = "Precache_" .. eventName,
        }, function(envelope)
            inflight = inflight - 1

            if envelope and envelope.ok and envelope.text then
                local line = TTTBots.Providers.SanitizeText(envelope.text)
                line = TTTBots.Providers.StripQuotes(line)

                -- Strip any accidental name prefixes the LLM might add
                line = line:gsub("^%S+:%s*", "")

                if line and line ~= "" and #line < 200 then
                    local lang = lib.GetConVarString("language") or "en"

                    -- Ensure the event has a registered category so CategoryIsEnabled works
                    if not TTTBots.Locale.Priorities[eventName] then
                        TTTBots.Locale.RegisterCategory(eventName, lang, 3,
                            description or ("Auto-generated event: " .. eventName))
                    end

                    TTTBots.Locale.AddLine(eventName, line, lang, archetype)
                    PC.generated = PC.generated + 1

                    if lib.GetConVarBool("debug_misc") then
                        print(string.format("[TTTBots:Precache] Generated '%s' [%s]: %s",
                            eventName, archetype, line))
                    end
                else
                    PC.failed = PC.failed + 1
                end
            else
                PC.failed = PC.failed + 1
                if lib.GetConVarBool("debug_misc") then
                    local errMsg = envelope and envelope.message or "unknown error"
                    print(string.format("[TTTBots:Precache] Failed '%s' [%s]: %s",
                        eventName, archetype, errMsg))
                end
            end
        end)
    end

    -- Schedule the next batch
    timer.Simple(BATCH_DELAY, processNextBatch)
end

-- ---------------------------------------------------------------------------
-- Scan & enqueue missing event lines
-- ---------------------------------------------------------------------------

--- Scan all known events and enqueue LLM generation for any missing locale lines.
--- Safe to call multiple times; already-precached events are skipped.
function PC.ScanAndEnqueue()
    if PC.scanned then return end
    PC.scanned = true

    if not lib.GetConVarBool("llm_enabled") then
        print("[TTTBots:Precache] LLM is disabled (ttt_bot_llm_enabled = 0). Skipping precache.")
        return
    end

    if not lib.GetConVarBool("chatter_precache_llm") then
        print("[TTTBots:Precache] Precache is disabled (ttt_bot_chatter_precache_llm = 0). Skipping.")
        return
    end

    local allEvents = collectAllEvents()
    local lang = lib.GetConVarString("language") or "en"
    local totalMissing = 0
    local totalEvents = 0

    for eventName, _ in pairs(allEvents) do
        totalEvents = totalEvents + 1

        -- Skip if this event already has lines for ALL archetypes (or at least default)
        if PC.completed[eventName] then continue end

        local description = TTTBots.Locale.Description[eventName] or nil

        -- Check if the event has NO lines at all (complete miss)
        local hasAnyLines = eventHasLocaleLines(eventName)

        if not hasAnyLines then
            -- No lines at all: generate for "default" archetype as a universal fallback
            table.insert(PC.queue, {
                event = eventName,
                archetype = "default",
                description = description,
            })
            totalMissing = totalMissing + 1
            PC.completed[eventName] = true
        else
            -- Has some lines, but check for missing archetype-specific entries
            for _, archetype in ipairs(ALL_ARCHETYPES) do
                if not eventHasArchetypeLine(eventName, archetype) and archetype ~= "default" then
                    -- Only generate for archetypes that truly have no coverage
                    -- (the "default" archetype lines serve as fallback for all)
                    -- So only enqueue if there's no default AND no archetype line
                    -- Actually, skip this for now — the getArchetypalLines() function
                    -- already falls back to default. We only need to fill total misses.
                end
            end
            PC.completed[eventName] = true
        end
    end

    print(string.format(
        "[TTTBots:Precache] Scanned %d events, found %d with no locale lines. Queue size: %d",
        totalEvents, totalMissing, #PC.queue
    ))

    if #PC.queue > 0 then
        PC.running = true
        -- Start processing after a short delay to let the server finish initializing
        timer.Simple(3, processNextBatch)
    end
end

-- ---------------------------------------------------------------------------
-- Boot triggers
-- ---------------------------------------------------------------------------

--- Hook into the first round start to trigger the precache scan.
--- Using TTTBeginRound ensures all locale files and providers are loaded.
hook.Add("TTTBeginRound", "TTTBots.ChatterPrecache.FirstRound", function()
    -- Only run once per server session
    if PC.scanned then return end

    -- Delay slightly so all systems are ready
    timer.Simple(5, function()
        PC.ScanAndEnqueue()
    end)
end)

--- Also provide a console command for manual triggering.
concommand.Add("ttt_bot_precache_chatter", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:PrintMessage(HUD_PRINTCONSOLE, "You must be a superadmin to run this command.")
        return
    end

    -- Reset scan state so it can run again
    PC.scanned = false
    PC.queue = {}
    PC.completed = {}
    PC.generated = 0
    PC.failed = 0

    print("[TTTBots:Precache] Manual precache triggered.")
    PC.ScanAndEnqueue()
end)

--- Fallback: if no round has started after 60 seconds (e.g. headless mode),
--- trigger the scan anyway.
timer.Simple(60, function()
    if not PC.scanned then
        print("[TTTBots:Precache] No round detected after 60s, running precache scan.")
        PC.ScanAndEnqueue()
    end
end)
