print("[TTT Bots 2] Loading shared cvars...")

local SH_FCVAR = { FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_LUA_SERVER }

local function bot_sh_cvar(name, def, desc)
    return CreateConVar("ttt_bot_" .. name, def, SH_FCVAR, desc)
end

local function bot_sh_cvar_server_only(name, def, desc)
    return CreateConVar("ttt_bot_" .. name, def, { FCVAR_ARCHIVE, FCVAR_LUA_SERVER }, desc)
end


bot_sh_cvar("language", "en",
    "Changes the language that the bots speak in text chat, and may modify some GUI strings. Example is 'en' or 'es'")
bot_sh_cvar("pfps", "1", "Bots can have AI-related profile pictures in the scoreboard")
bot_sh_cvar("pfps_humanlike", "1", "Bots can have AI-related profile pictures in the scoreboard")
bot_sh_cvar("emulate_ping", "0",
    "Bots will emulate a humanlike ping (does not affect gameplay and is cosmetic.) This is to be used in servers of players that consent to playing with bots. It's a flavor feature for friends.")

-- Misc cvars
bot_sh_cvar("chat_cmds", "1",
    "If you want to allow chat commands to be used for administration. This cvar exists for mod compatibility.")
bot_sh_cvar("names_prefixes", "1", "Bot names are forced prefixed by '[BOT]'")
bot_sh_cvar("playermodel", "", "The path to the playermodel the bots should use. Leave blank to disable this feature.")

bot_sh_cvar("quota", "0",
    "The number of bots to ensure are in the level at all times. Set to 0 to disable this feature. This cvar is affected by ..._mode")
bot_sh_cvar("quota_mode", "fill",
    "The mode of the quota system. Options = 'fill', 'exact', 'dynamic'. Fill will basically set the player count to X (filling in for players as they leave), and exact will always have X bots in the match. Dynamic will fluctuate between a min and max players.")
bot_sh_cvar("quota_cull_difficulty", "1",
    "Whether or not the quota system should cull bots that are too beyond or below the ttt_bot_difficulty setting.")
bot_sh_cvar("notify_always", "0", "If we should notify players of the number bots at the start of *every* round.")
bot_sh_cvar("quota_mode_dynamic_max", "16",
    "The maximum number of bots that will be dynamically added to the server. This is only used in 'dynamic' mode.")
bot_sh_cvar("quota_mode_dynamic_min", "4",
    "The minimum number of bots that will be dynamically added to the server. This is only used in 'dynamic' mode.")

-- "Cheat" cvars
bot_sh_cvar("cheat_know_shooter", "1",
    "If set to 1, bots will automatically know who in a firefight shot first, and will use that to determine who to shoot. While technically a cheat, the bots may feel dumber when this is off.")
bot_sh_cvar("cheat_redhanded_time", "3",
    "This is the number of seconds that a player is silently marked KOS by bots after killing a non-evil class. Set to 0 to disable.")
bot_sh_cvar("cheat_traitor_reactionspd", "1",
    "If set to 1, traitor bots will have a superior reaction speed. TTT2: Does not apply to custom traitor-ish roles.")
bot_sh_cvar("cheat_traitor_accuracy", "1",
    "If set to 1, killer-role bots (any team that is NOT innocent or none) will have significantly improved accuracy. TTT2: Now applies to ALL custom killer roles, not just vanilla traitors.")
bot_sh_cvar("cheat_know_jester", "1",
    "If set to 1, bots will automatically ''know'' who the jester is. They will still shoot at them if they're too annoying, but they inherently know to devalue their sus actions.")
bot_sh_cvar("cheat_know_swapper", "1",
    "If set to 1, bots will automatically ''know'' who the swapper is. They will still shoot at them if they're too annoying, but they inherently know to devalue their sus actions.")
bot_sh_cvar("cheat_bot_zombie", "0",
    "If set to 1, bots will not move and will not shoot.")
    
-- Chatter cvars
bot_sh_cvar("llm_enabled", "1",
    "Master toggle to enable or disable all LLM (AI text generation) calls. When set to 0, bots will fall back to locale-string responses for all chatter events and will not contact any LLM provider.")

-- Rate limiter / cost tracker cvars
bot_sh_cvar("llm_max_rpm", "30",
    "Maximum LLM requests per minute across all bots. Requests above this limit are rejected (high-priority events like KOS still get through). Set to 0 for unlimited.")
bot_sh_cvar("llm_max_per_round", "200",
    "Maximum LLM requests per round across all bots. Prevents runaway costs in long rounds. Set to 0 for unlimited.")
bot_sh_cvar("llm_cost_per_1k_tokens", "0.01",
    "Estimated cost in USD per 1,000 tokens for the configured LLM provider. Used for the cost tracker dashboard.")
bot_sh_cvar("llm_budget_per_round", "1.00",
    "Maximum estimated USD spend per round. Once this budget is hit, only high-priority requests (KOS, accusations) are allowed. Set to 0 for unlimited.")
bot_sh_cvar("llm_ratelimit_debug", "0",
    "Print rate limiter decisions and token tracking to server console. Filter: [BOTDBG:RATELIMIT]")

bot_sh_cvar("chatter_lvl", "3",
    "The level of chatter that bots will have. 0 = none (not even KOS), 1 = critical only (like KOS), 2 = >= callouts/important only, 3 = everything.")
bot_sh_cvar("chatter_cps", "30",
    "Determines the typing speed of bots, in characters per second. Higher values = faster typing = more chatting.")
bot_sh_cvar("chatter_minrepeat", "15",
    "The minimum time between a bot can repeat the same chatter event in voice/text chat.")
bot_sh_cvar("chatter_koschance", "1",
    "A multiplier value that affects a bots chance to call KOS. Higher values = more KOS calls. Only does anything if ttt_bot_chatter_lvl is 1 or higher. Set to 0 to disable KOS calls.")
bot_sh_cvar("chatter_silly", "1",
    "Whether or not bots can say silly stuff randomly in chat. This is reserved for one-liners, and does not affect dialog.")
bot_sh_cvar("chatter_dialogue", "1",
    "Whether or not bots can chitchat with each other in text chat.")
bot_sh_cvar("chatter_typo_chance", "1",
    "A percent chance, from 1-100, that each character in a bot's message will have a typo.")
bot_sh_cvar_server_only("chatter_chatgpt_api_key", "",
    "The API key for ChatGPT. This is required for bots to reply. You can get one at https://www.openai.com/")
bot_sh_cvar_server_only("chatter_gemini_api_key", "",
    "The API key for Gemini. This is required for bots to reply. You can get one at https://ai.google.dev/")
bot_sh_cvar_server_only("chatter_deepseek_api_key", "",
    "The API key for Deepseek. This is required for bots to reply.")
bot_sh_cvar_server_only("chatter_openrouter_api_key", "",
    "The API key for OpenRouter. Get one at https://openrouter.ai/keys — required when chatter_api_provider is 5.")
bot_sh_cvar("chatter_openrouter_model", "arcee-ai/trinity-large-preview:free",
    "The OpenRouter model to use when chatter_api_provider is 5. Can be any model slug from https://openrouter.ai/models. Free models end in :free. Examples: nvidia/llama-nemotron-embed-vl-1b-v2:free, openai/gpt-5-nano, anthropic/claude-sonnet-4.6")
bot_sh_cvar("chatter_openrouter_site_url", "",
    "Optional: your site URL sent to OpenRouter as HTTP-Referer for app attribution. Leave blank to omit.")
bot_sh_cvar("chatter_openrouter_site_name", "TTT Bots 2",
    "Optional: your app name sent to OpenRouter as X-Title for attribution. Defaults to 'TTT Bots 2'.")
bot_sh_cvar("chatter_temperature", "0.9",
    "The temperature for ChatGPT. This determines how random the responses are. Lower values = more predictable, higher values = more random.")
bot_sh_cvar("chatter_chance_multi", "1",
    "A multiplier value that affects a bots chance to reply to any chat message (voice if enabled + text). Higher values = more chatting. Set to 0 to disable chatting (Default 1 = 1x Frequency).")
bot_sh_cvar("chatter_reply_chance_multi", "1",
    "A multiplier value that affects a bots chance to reply to a message. Higher values = more replying. Set to 0 to disable replying (Default 1 = 1x Frequency).")
bot_sh_cvar("chatter_gpt_chance", "1",
    "A multiplier value that affects a bots chance to use ChatGPT to generate bot chatter. Higher values = more ChatGPT. Set to 0 to disable ChatGPT Custom Chatter (Default 1 = 1x Frequency).")
bot_sh_cvar("chatter_api_provider", "0",
    "The AI model provider for bot chat. 0 = ChatGPT, 1 = Gemini, 2 = Deepseek, 3 = All, Randomly Assigned to Bots, 4 = Local Ollama (requires GMOD Container or compatible ttsapi), 5 = OpenRouter (any model via https://openrouter.ai)")
bot_sh_cvar("chatter_gpt_model", "gpt-3.5-turbo",
    "The ChatGPT model to use. Options: gpt-3.5-turbo, gpt-4o-mini")
bot_sh_cvar("chatter_gemini_model", "gemini-2.0-flash",
    "The Gemini model to use. Options: gemini-2.0-flash, gemini-1.5-pro-0409")
bot_sh_cvar("chatter_deepseek_model", "deepseek-chat",
    "The Deepseek model to use. Options: deepseek-chat")
bot_sh_cvar("chatter_ollama_model", "tinyllama",
    "The Ollama model to use when chatter_api_provider is 4 (Local Ollama). Examples: tinyllama, llama3, mistral")
bot_sh_cvar_server_only("chatter_ollama_url", "",
    "Override URL for the Ollama /llm proxy endpoint. Leave blank to auto-detect from TTSAPI config (http://ttsapi:80/llm).")
bot_sh_cvar("chatter_local_api_enabled", "0",
    "Master toggle for local ttsapi features (Ollama LLM, Piper TTS). Set to 1 to enable. Auto-enabled when TTSAPI config is detected.")
bot_sh_cvar("chatter_casual_llm", "1",
    "Whether LLM-generated lines are used in casual/idle dialog exchanges (the llm_line template steps). Set to 0 to always use locale templates instead.")
bot_sh_cvar("chatter_casual_llm_chance", "0.4",
    "Probability (0.0-1.0) that a casual dialog llm_line step will call the LLM instead of being skipped. Default 0.4 = 40% of casual dialog closing lines are LLM-generated.")
bot_sh_cvar("chatter_precache_llm", "0",
    "When set to 1, on server boot (first round start) the system scans all known chatter events and uses LLM generation to create fallback locale lines for any event that has no localized strings. Requires ttt_bot_llm_enabled = 1. Generated lines are cached in memory for the session.")

-- Gameplay-effecting cvars
bot_sh_cvar("plans_mindelay", "12",
    "The delay when a round starts before traitor bots may follow coordinated plans.")
bot_sh_cvar("plans_maxdelay", "35",
    "The maximum duration when a round starts before traitor bots may follow coordinated plans.")
bot_sh_cvar("attack_delay", "15",
    "The minimum number of seconds until a traitor bot will consider shooting someone around them.")
bot_sh_cvar("flicking", "1",
    "Can the bots flick around when they get shot from the rear? Effectively makes bots harder and seem smarter.")
bot_sh_cvar("difficulty", "3",
    "A difficulty integer between 1-5; higher = harder. This affects trait selection and aim speed, reaction speed, and KOS callout chances.")
bot_sh_cvar("adaptive_difficulty", "1",
    "Dynamically boosts traitor accuracy and credits when traitors are losing. Tracks a 5-round rolling win-rate; boosts increase below 40% win-rate and decrease above 50%. Set to 0 to disable.")
bot_sh_cvar("kos_limit", "2",
    "The upper bound of KOS calls an individual, bot or player, can make per round. Before the bots ignore them, at least. Used to deter trolls.")
bot_sh_cvar("reaction_speed", "0.8",
    "The base time, in seconds, a bot will take before attacking a newly assigned target. Higher means easier gameplay. THIS INVERSELY SCALES WITH DIFFICULTY AUTOMATICALLY.")
bot_sh_cvar("plant_c4", "1",
    "Whether or not ANY bots are permitted to plant c4. It will not disable the ability to *have* c4, just prevent the use of it.")
bot_sh_cvar("defuse_c4", "1",
    "Whether or not ANY bots are permitted to defuse c4. Does not affect if bots will buy defuse kits or not as detective (they just won't use it).")
bot_sh_cvar("personalities", "1",
    "Whether or not each bot should spawn in as its own unique individual (basically have their own gameplay-effecting traits)")
bot_sh_cvar("use_health", "1", "Whether or not bots can use and seek out health stations")
bot_sh_cvar("plant_health", "1", "Whether or not bots can plant health stations as a policing role")

-- Noise cvars
bot_sh_cvar("noise_investigate_chance", "50",
    "The % chance (therefore 0-100) that a bot will investigate a noise he hears.")
bot_sh_cvar("noise_investigate_mtb", "15",
    "The minimum time between, in seconds, that a bot will investigate a noise he hears.")
bot_sh_cvar("noise_enable", "1", "Enables bots to hear noises and investigate them.")

-- Naming cvars
bot_sh_cvar("names_allowcommunity", "1",
    "Enables community-suggested names, replacing many auto-generated names. WARNING: Potentially offensive, not family-friendly.")
bot_sh_cvar("names_communityonly", "0",
    "Disables auto-generated names, only using community-suggested names. NOTE: ttt_bot_names_allowcommunity must be enabled.")
bot_sh_cvar("names_canleetify", "1",
    "Enables leetifying of ALL names. (e.g. 'John' -> 'j0hn'). See ttt_bot_names_leetify_chance.")
bot_sh_cvar("names_canusenumbers", "1",
    "Enables adding numbers to autogenerated names. (e.g. 'John' -> 'John69')")
bot_sh_cvar("names_canusespaces", "1",
    "Enables using spaces in autogenerated names. (e.g. 'John Doe' -> 'JohnDoe')")
bot_sh_cvar("names_allowgeneric", "1",
    "Enables generic usernames, generated by ChatGPT. They're less appropriate than random names but more appropriate than community-suggested names.")
bot_sh_cvar("names_custom", "",
    "A list of comma-separated names that bots will use as they join: distributed as first come, first served. Example: 'hello world,bob,billy,steve steve,austin' do not put spaces after commas.")

-- Debug cvars
bot_sh_cvar("debug_pathfinding", "0",
    "[May console spam. Development use only] Enables debug for pathfinding. Requires built-in developer convar to be 1 for drawings.")
bot_sh_cvar("debug_look", "0",
    "[May console spam. Development use only] Enables debug for looking at things. Requires built-in developer convar to be 1 for drawings.")
bot_sh_cvar("debug_misc", "0",
    "[May console spam. Development use only] Enables misc debug. Requires built-in developer convar to be 1 for drawings.")
bot_sh_cvar("debug_stuckpositions", "0",
    "[May console spam. Development use only] Enables debug for stuck positions. Requires built-in developer convar to be 1 for drawings.")
bot_sh_cvar("debug_obstacles", "0",
    "[May console spam. Development use only] Enables debug for recognized obstacles. Requires built-in developer convar to be 1 for drawings.")
bot_sh_cvar("debug_doors", "0",
    "[May console spam. Development use only] Enables debug for doors. Requires built-in developer convar to be 1 for drawings.")
bot_sh_cvar("debug_attack", "0",
    "[May console spam. Development use only] Enables debug for attacking. Requires built-in developer convar to be 1 for drawings.")
bot_sh_cvar("debug_evil", "0",
    "[May console spam. Development use only] Enables debug for the Evil Coordinator.")
bot_sh_cvar("debug_inventory", "0",
    "[May console spam. Development use only] Enables debug for inventory management.")
bot_sh_cvar("debug_strafe", "0",
    "[May console spam. Development use only] Enables debug drawing for strafing. Requires 'developer 1' first.")
bot_sh_cvar('debug_navpopularity', '0',
    '[May console spam. Development use only] Enables debug drawing for nav popularity. Requires "developer 1" first.')
bot_sh_cvar('debug_brain', '0',
    '[May console spam. Development use only] Enables debug for behavior trees. Requires "developer 1" first.')

bot_sh_cvar('debug_forceweapon', '', 'Forces bots to use a specific weapon. Gives it to them if they do not have it.')

-- Debug Log cvars (server-console text output for full round picture)
bot_sh_cvar("debug_log_round", "0",
    "Logs round lifecycle to server console: prepare, start (with full roster/roles), and end (with results). Use [BOTDBG:ROUND] prefix to filter.")
bot_sh_cvar("debug_log_kills", "0",
    "Logs every kill during a round to server console: who killed whom, with what weapon, and the alive count. Filter: [BOTDBG:KILL]")
bot_sh_cvar("debug_log_damage", "0",
    "Logs every PlayerHurt event to server console: attacker, victim, damage, remaining HP. Filter: [BOTDBG:DMG] (can be spammy!)")
bot_sh_cvar("debug_log_kos", "0",
    "Logs all KOS calls to server console: caller, target, and round time. Filter: [BOTDBG:KOS]")
bot_sh_cvar("debug_log_bodies", "0",
    "Logs body discovery events to server console: who found whose body, and the confirmed dead count. Filter: [BOTDBG:BODY]")
bot_sh_cvar("debug_log_behaviors", "0",
    "Periodically logs each alive bot's current behavior tree node and attack target (every 3s). Filter: [BOTDBG:BEHAV]")
bot_sh_cvar("debug_log_plans", "0",
    "Logs traitor plan assignments and periodic plan state to server console. Filter: [BOTDBG:PLAN]")
bot_sh_cvar("debug_log_innocentcoord", "0",
    "Logs innocent coordinator strategy and buddy pairs to server console (every 5s). Filter: [BOTDBG:IC]")
bot_sh_cvar("debug_log_evidence", "0",
    "Periodically dumps each bot's top 3 suspects with evidence weights (every 5s). Filter: [BOTDBG:EVID]")
bot_sh_cvar("debug_log_awareness", "0",
    "Periodically logs round-awareness phase, aggression, group urgency, and suspicion pressure per bot (every 8s). Filter: [BOTDBG:PHASE]")
bot_sh_cvar("debug_log_personality", "0",
    "Periodically logs personality archetype, difficulty, rage/boredom/pressure, and traits per bot (every 10s). Filter: [BOTDBG:PERS]")
bot_sh_cvar("debug_log_inventory", "0",
    "Periodically logs held/primary/secondary weapons per bot (every 8s). Filter: [BOTDBG:INV]")
bot_sh_cvar("debug_log_memory", "0",
    "Periodically logs memory state: visible players, known positions, known alive counts, hearing multiplier (every 8s). Filter: [BOTDBG:MEM]")
bot_sh_cvar("debug_log_morality", "0",
    "Periodically logs active attack targets with priority and reason codes (every 4s). Filter: [BOTDBG:MORAL]")
bot_sh_cvar("debug_log_chatter", "0",
    "Logs all bot chat messages (text chat) to server console. Filter: [BOTDBG:CHAT]")
bot_sh_cvar("debug_log_c4", "0",
    "Periodically logs armed and spotted C4 counts (every 5s). Filter: [BOTDBG:C4]")
bot_sh_cvar("debug_log_locomotion", "0",
    "Periodically logs pathfinding state: has path, strafe direction, status, goal position (every 6s). Filter: [BOTDBG:LOCO]")
bot_sh_cvar("debug_log_timeline", "0",
    "Periodically prints a full round snapshot: all alive players with roles, KOS targets, counts (every 15s). Filter: [BOTDBG:TIME]")
bot_sh_cvar("debug_log_events", "0",
    "Firehose: logs every TTTBots event bus event with payload details. Filter: [BOTDBG:EVENT] (can be very spammy!)")

-- Personality cvars
bot_sh_cvar("boredom", "1",
    "Enables boredom. Bots will leave the server if they get too bored. If RDM is enabled, then some bots will be more likely RDM when (very) bored")
bot_sh_cvar("boredom_rate", "100",
    "How quickly bots get bored. *THIS IS A PERCENTAGE*. Higher values = faster boredom. Only does anything if ttt_bot_boredom is enabled.")
bot_sh_cvar("pressure", "1",
    "Enables pressure. Bots will have worse aim if they are under pressure. Certain traits may make some bots better under pressure, increasing difficulty.")
bot_sh_cvar("pressure_rate", "100",
    "How quickly bots accrue pressure. *THIS IS A PERCENTAGE*. Higher values = faster pressure gain. Only does anything if ttt_bot_pressure is enabled.")
bot_sh_cvar("rage", "1",
    "Enables rage. Like boredom, bots will leave, and even be more likely to RDM if RDM is enabled. This will also build onto pressure, if enabled, and may make bots more aggressive in chat.")
bot_sh_cvar("rage_rate", "100",
    "How quickly bots get angry. *THIS IS A PERCENTAGE*. Higher values = faster anger. Only does anything if ttt_bot_rage is enabled.")
bot_sh_cvar("allow_leaving", "1",
    "Enables bots to leave the server if they get too bored or angry. Bots that leave voluntarily will automatically have a replacement join within 30 seconds.")

-- Pathfinding cvars
bot_sh_cvar("pathfinding_cpf", "240",
    "Don't change this unless you know what you are doing. How many pathfinding calculations to do per frame. Higher values = more CPU usage, but faster pathfinding.")
bot_sh_cvar("pathfinding_cpf_scaling", "0",
    "Don't change this unless you know what you are doing. Should we dynamically multiply the pathfinding calculations per frame by the number of bots? (e.g. 50 cpf * 2 bots = 100 cpf)")
bot_sh_cvar("pathfinding_max_nodes", "600",
    "Maximum number of A* nodes the pathfinder will explore before giving up on a path. Higher values allow finding paths through complex maps at the cost of more CPU time per frame.")
bot_sh_cvar("rdm", "0",
    "Enables RDM (random deathmatch). This isn't advised for most situations, but can offer some extra variety should you want it.")
bot_sh_cvar("kos_enemies", "0",
    "If set to 1, bots will KOS players in enemy roles or enemy teams. If set to 0, bots will not KOS enemies outside of normal gameplay function. This is a global setting.")
bot_sh_cvar("kos_nonallies", "0",
    "If set to 1, bots will KOS players in non-ally roles or non-ally teams. If set to 0, bots will not KOS non-allies outside of normal gameplay function. This is a global setting.")
bot_sh_cvar("kos_traitorweapons", "0",
    "If set to 1, bots will KOS players that have traitor weapons. If set to 0, bots will not KOS players with traitor weapons. This is a global setting.")
bot_sh_cvar("kos_unknown", "0",
    "If set to 1, bots will KOS players with unknown roles. If set to 0, bots will not KOS players with unknown roles. This is a global setting.")
bot_sh_cvar("kos_postround", "0",
    "If set to 1, bots will KOS players in the post-round. If set to 0, bots will not KOS players in the post-round. This is a global setting.")

-- Behavior cvars
bot_sh_cvar("radar_chance", "100",
    "Chance that a traitor bot will simulate having radar as a traitor (internally they must be an 'evil' role).")
bot_sh_cvar("coordinator", "1",
    "Enables the Evil Coordinator module. Evil bots will not coordinate with other traitors with this set to 0. WARNING: This will make traitor bots far less effective & responsive.")
bot_sh_cvar("headless", "0",
    "Enables headless (bots-only) mode. When set to 1, the server will start and continue rounds with only bots connected — no human players required. Useful for dedicated bot servers, testing, or stat collection.")


--- Voice Cvars
bot_sh_cvar("chatter_enable_tts", "1",
    "Globally enable or disable all TTS (Text-to-Speech) voice output for bots. Set to 0 to silence all bot voice chat without changing other voice settings.")
bot_sh_cvar("chatter_proximity", "1",
    "When enabled, bots respect TTT2's proximity/locational voice chat settings (ttt_locational_voice). Bot text and voice chat will only be heard by players within the configured range. Set to 0 to let bots ignore proximity restrictions.")
bot_sh_cvar("chatter_voice_chance", "50",
    "The % chance (therefore 0-100) that a bot will use a voice in voice chat.")
bot_sh_cvar("chatter_voice_good_tts_chance", "0",
    "The % chance (therefore 0-100) that a bot will use a good TTS voice in voice chat (Required Elevenlabs Subscription + API Key). Otherwise will revert to a free TTS voice.")
bot_sh_cvar("chatter_elevenlabs_voice_model", "0",
    "The Elevenlabs voice model to use for TTS. 0 = eleven_turbo_v2_5, 1 = eleven_multilingual_v2, 2 = eleven_monolingual_v1, 3 = eleven_monolingual_v1")
bot_sh_cvar("chatter_voice_good_tts_custom_name_override", "0",
    "If set to 1, bots with the same name as a custom name will be forced to use that corresponding elevenlabs profile.")
bot_sh_cvar("debug_chatter_voice_team_color", "0",
    "If set to 1, bots will use their team color in voice chat. This is a debug feature.")
bot_sh_cvar_server_only("chatter_voice_elevenlabs_api_key", "",
    "The API key for Elevenlabs. This is required for good TTS voices. You can get one at https://www.eleven-labs.com/en/")
bot_sh_cvar("chatter_voice_azure_voice_quality", "3",
    "The quality of the Azure TTS voice. 1 = audio-8khz-8kbitrate-mono-mp3, 2 = audio-16khz-16kbitrate-mono-mp3, 3 = audio-16khz-32kbitrate-mono-mp3, 4 = audio-24khz-48kbitrate-mono-mp3, 5 = audio-24khz-96kbitrate-mono-mp3.")
bot_sh_cvar("chatter_voice_stt", "0",
    "If set to 1, audio recorded in voice chat will be sent to a local Speech-to-Text service for transcription and relayed to bots to reply to. This is an experimental feature.")
bot_sh_cvar("chatter_voice_stt_backend", "whisper",
    "The STT backend to use. 'whisper' = local faster-whisper via ttsapi (no API key needed). 'azure' = Microsoft Azure STT (requires Azure credentials). Only relevant when ttsapi container is running.")
bot_sh_cvar("chatter_voice_force_reply_player", "1",
    "If set to 1, bots will always reply to players in voice chat. If set to 0, bots will not always reply to players in voice chat.")
bot_sh_cvar("chatter_voice_azure_resource_api_key", "",
    "The API key for Azure Speech-to-Text. This is required for bots to reply to voice chat. You can get one at https://azure.microsoft.com/en-us/services/cognitive-services/speech-to-text/")
bot_sh_cvar("chatter_voice_azure_resource_name", "",
    "The subscription name for Azure Speech-to-Text. This is required for bots to reply to voice chat. You can get one at https://azure.microsoft.com/en-us/services/cognitive-services/speech-to-text/")
bot_sh_cvar("chatter_voice_azure_region", "eastus",
    "The region for Azure Speech-to-Text. This is required for bots to reply to voice chat. You can get one at https://azure.microsoft.com/en-us/services/cognitive-services/speech-to-text/")
bot_sh_cvar("chatter_voice_tts_provider", "0",
    "The TTS provider to use. 0 = Free TTS (Microsoft Sam API) Only, 1 = Elevenlabs Only, 2 = Azure TTS Only, 3 = Mixed, 4 = Local Piper TTS (requires ttsapi container)")
bot_sh_cvar("chatter_voice_free_tts_chance", "100",
    "The % chance (therefore 0-100) that a bot will use a free TTS voice in voice chat. This is only used if chatter_voice_tts_provider is set to 3.")
bot_sh_cvar("chatter_voice_microsoft_tts_chance", "0",
    "The % chance (therefore 0-100) that a bot will use a Azure TTS voice in voice chat. This is only used if chatter_voice_tts_provider is set to 3.")
bot_sh_cvar("chatter_voice_elevenlabs_tts_chance", "0",
    "The % chance (therefore 0-100) that a bot will use a Elevenlabs TTS voice in voice chat. This is only used if chatter_voice_tts_provider is set to 3.")
bot_sh_cvar("chatter_voice_local_tts_chance", "0",
    "The % chance (therefore 0-100) that a bot will use Local Piper TTS in voice chat. Only used if chatter_voice_tts_provider is set to 3 (mixed).")
bot_sh_cvar("chatter_voice_local_tts_url", "",
    "Override URL for the local Piper TTS endpoint. Leave blank to use Docker-internal auto-detection (binary mode only). Set to a public-facing address (e.g. http://192.168.1.10:8080/local) to enable URL mode for local TTS so clients can stream audio directly.")
bot_sh_cvar("chatter_voice_url_mode", "0",
    "To enable URL mode set this to 1, this will make the bot voice chat go through URL rather than net.Send which should be quicker, to disable set to 0 (default).")

-- Base Tick Rate cvars
bot_sh_cvar("tickrate", "5",
    "The base tick rate (ticks per second) for bot thinking. Lower values reduce CPU load but make bots less responsive. Range 1-20, default 5. Changes take effect next round or on reload.")
bot_sh_cvar("tickrate_auto", "0",
    "Enable automatic tick rate adjustment based on server performance. When enabled, the tick rate will decrease if tick processing takes too long and recover when performance improves. 0 = off, 1 = on.")
bot_sh_cvar("tickrate_auto_threshold_ms", "30",
    "Maximum allowed average tick duration in milliseconds. If the average bot tick takes longer than this, the tick rate is lowered. Default 30ms. Range 5-200.")
bot_sh_cvar("tickrate_auto_min", "2",
    "Minimum tick rate the auto-adjuster is allowed to set. Bots will never think slower than this many times per second. Default 2.")
bot_sh_cvar("tickrate_auto_recover", "5",
    "Seconds of consistently good tick performance (below threshold) before the auto-adjuster tries increasing the tick rate again. Default 5.")
bot_sh_cvar("tickrate_auto_debug", "0",
    "Periodically prints tick rate auto-adjuster diagnostics to server console. Filter: [BOTDBG:TICKRATE]")
bot_sh_cvar("tickrate_auto_escalate", "1",
    "When enabled and the tick rate is already at its minimum but ticks still exceed the threshold, the system escalates further: level 1 doubles component ThinkRates, level 2 triples them and skips behavior trees for idle bots, level 3 quadruples them and skips trees 75% of the time. 0 = off, 1 = on.")
bot_sh_cvar("tickrate_auto_escalate_max", "3",
    "Maximum escalation level (1-3). Higher levels are more aggressive. Level 1 = slow components, Level 2 = also skip behavior trees for non-combat bots, Level 3 = maximum throttle. Default 3.")

-- Dynamic Tick Rate Scaler cvars
bot_sh_cvar("tickscaler_enabled", "0",
    "Enable dynamic tick rate scaling. When enabled, bots on high-population servers will think less often (logarithmically scaled), making them 'dumber' to reduce CPU load. 0 = off, 1 = on.")
bot_sh_cvar("tickscaler_threshold", "8",
    "Bot count at or below which no tick scaling is applied — bots think at full speed. Above this count the logarithmic slowdown kicks in.")
bot_sh_cvar("tickscaler_factor", "1.4427",
    "Logarithmic multiplier for tick scaling. Higher = more aggressive throttling as bot count grows. Default 1.4427 (= 1/ln2) means doubling bots above threshold adds +1 skip.")
bot_sh_cvar("tickscaler_max_skip", "6",
    "Hard cap on the tick-skip value. A skip of 6 at tickrate 5 means a bot only thinks ~0.83 times per second. Prevents bots from becoming completely unresponsive.")
bot_sh_cvar("tickscaler_exempt_combat", "1",
    "If 1, bots that are currently in combat (have an active attack target) are NOT throttled and think at full speed regardless of population.")
bot_sh_cvar("tickscaler_stagger", "1",
    "If 1, bot think calls are staggered across ticks so not all bots skip the same frames. Distributes CPU load more evenly.")
bot_sh_cvar("tickscaler_debug", "0",
    "Periodically prints tick scaler diagnostics to server console: bot count, skip value, per-bot effective Hz, and combat exemptions. Filter: [BOTDBG:TICKSCALER]")

-- Evidence / Social Deduction cvars
bot_sh_cvar("evidence_kos_threshold", "14",
    "The minimum evidence weight (sum of all evidence entries) required before a bot will call KOS on a player. Higher = less accusatory.")
bot_sh_cvar("evidence_accuse_threshold", "7",
    "The minimum evidence weight before a bot will make a medium accusation (DeclareSuspicious-level).")
bot_sh_cvar("evidence_soft_threshold", "3",
    "The minimum evidence weight before a bot will make a soft accusation hint.")
bot_sh_cvar("evidence_decay_time", "90",
    "Seconds before an evidence entry's weight is halved due to age.")
bot_sh_cvar("evidence_prune_time", "180",
    "Seconds before an old evidence entry is removed entirely from the log.")
bot_sh_cvar("evidence_accuse_cooldown", "60",
    "Seconds a bot must wait before accusing the same player again.")
bot_sh_cvar("evidence_companion_min_time", "20",
    "Seconds a bot must have traveled with another player before they can provide an alibi vouch.")
bot_sh_cvar("evidence_trust_decay_time", "120",
    "Seconds before a player vouch entry expires if not refreshed.")

-- Tier 6 — Personality & Immersion cvars
bot_sh_cvar("deception_enabled", "1",
    "Enables Tier 6 traitor deception behaviors: alibi building, fake investigating, false KOS calls, and plausible ignorance excuses.")
bot_sh_cvar("personality_evolution", "1",
    "Enables dynamic personality evolution: mood shifts from pressure and deaths, social accusation feedback, and confidence modulating aggression.")
bot_sh_cvar("crossround_memory", "0",
    "Enables cross-round traitor memory. Bots will remember who was a traitor in previous rounds, simulating metagame knowledge. Disabled by default.")
bot_sh_cvar("plan_learning", "1",
    "Enables persistent plan learning. Traitor bots track which plans lead to victories and adapt future plan selection to favour historically successful strategies. Data persists across server restarts.")
bot_sh_cvar("semantic_animations", "1",
    "Enables contextual semantic animations during interactions: CrouchPeek near danger, LookAway near kill zones, weapon holstering, and flashlight management.")
bot_sh_cvar("emotional_chatter", "1",
    "Enables emotional reaction chatter events: witness-kill panic, being shot at protests, friend-body grief, round-start comments, overtime haste, last-innocent dread, and traitor-victory gloating.")