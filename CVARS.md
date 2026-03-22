# TTT Bots 2 Console Commands

## Shared CVARS

- **ttt_bot_language** (default: `en`)
  - Changes the language that the bots speak in text chat, and may modify some GUI strings. Example: `en` or `es`.

- **ttt_bot_pfps** (default: `1`)
  - Bots can have AI-related profile pictures in the scoreboard.

- **ttt_bot_pfps_humanlike** (default: `1`)
  - Bots can have AI-related profile pictures in the scoreboard.

- **ttt_bot_emulate_ping** (default: `0`)
  - Bots will emulate a humanlike ping (does not affect gameplay and is cosmetic).

## Misc CVARS

- **ttt_bot_chat_cmds** (default: `1`)
  - Allows chat commands to be used for administration. This cvar exists for mod compatibility.

- **ttt_bot_names_prefixes** (default: `1`)
  - Bot names are forced prefixed by `[BOT]`.

- **ttt_bot_playermodel** (default: `""`)
  - The path to the playermodel the bots should use. Leave blank to disable this feature.

- **ttt_bot_quota** (default: `0`)
  - The number of bots to ensure are in the level at all times. Set to 0 to disable this feature.

- **ttt_bot_quota_mode** (default: `fill`)
  - The mode of the quota system. Options: `fill`, `exact`, `dynamic`.

- **ttt_bot_quota_cull_difficulty** (default: `1`)
  - Whether or not the quota system should cull bots that are too beyond or below the `ttt_bot_difficulty` setting.

- **ttt_bot_notify_always** (default: `0`)
  - If we should notify players of the number bots at the start of every round.

- **ttt_bot_quota_mode_dynamic_max** (default: `16`)
  - The maximum number of bots that will be dynamically added to the server in `dynamic` mode.

- **ttt_bot_quota_mode_dynamic_min** (default: `4`)
  - The minimum number of bots that will be dynamically added to the server in `dynamic` mode.

## Cheat CVARS

- **ttt_bot_cheat_know_shooter** (default: `1`)
  - Bots will automatically know who in a firefight shot first.

- **ttt_bot_cheat_redhanded_time** (default: `3`)
  - The number of seconds that a player is silently marked KOS by bots after killing a non-evil class.

- **ttt_bot_cheat_traitor_reactionspd** (default: `1`)
  - Traitor bots will have a superior reaction speed.

- **ttt_bot_cheat_traitor_accuracy** (default: `1`)
  - Traitor bots will have double the accuracy of standard bots.

- **ttt_bot_cheat_know_jester** (default: `1`)
  - Bots will automatically know who the jester is.

- **ttt_bot_cheat_know_swapper** (default: `1`)
  - Bots will automatically know who the swapper is.

- **ttt_bot_cheat_bot_zombie** (default: `0`)
  - Bots will not move and will not shoot.

## Chatter CVARS

- **ttt_bot_llm_enabled** (default: `1`)
  - Master toggle to enable or disable all LLM (AI text generation) calls. When set to `0`, bots fall back to pre-written locale responses for all chatter events and will not contact any LLM provider (ChatGPT, Gemini, DeepSeek, or Ollama). Exposed as a checkbox in the **AI Providers** settings menu.

- **ttt_bot_chatter_lvl** (default: `3`)
  - The level of chatter that bots will have. 0 = none, 1 = critical only, 2 = callouts/important only, 3 = everything.

- **ttt_bot_chatter_cps** (default: `30`)
  - Determines the typing speed of bots, in characters per second.

- **ttt_bot_chatter_minrepeat** (default: `15`)
  - The minimum time between a bot can repeat the same chatter event in voice/text chat.

- **ttt_bot_chatter_koschance** (default: `1`)
  - A multiplier value that affects a bot's chance to call KOS.

- **ttt_bot_chatter_silly** (default: `1`)
  - Whether or not bots can say silly stuff randomly in chat.

- **ttt_bot_chatter_dialogue** (default: `1`)
  - Whether or not bots can chitchat with each other in text chat.

- **ttt_bot_chatter_typo_chance** (default: `1`)
  - A percent chance, from 1-100, that each character in a bot's message will have a typo.

- **ttt_bot_chatter_chatgpt_api_key** (default: `""`)
  - The API key for ChatGPT.

- **ttt_bot_chatter_chatgpt_temperature** (default: `0.9`)
  - The temperature for ChatGPT. This determines how random the responses are.

- **ttt_bot_chatter_chance_multi** (default: `1`)
  - A multiplier value that affects a bot's chance to reply to any chat message.

- **ttt_bot_chatter_reply_chance_multi** (default: `1`)
  - A multiplier value that affects a bot's chance to reply to a message.

## Gameplay-effecting CVARS

- **ttt_bot_plans_mindelay** (default: `12`)
  - The delay when a round starts before traitor bots may follow coordinated plans.

- **ttt_bot_plans_maxdelay** (default: `35`)
  - The maximum duration when a round starts before traitor bots may follow coordinated plans.

- **ttt_bot_attack_delay** (default: `15`)
  - The minimum number of seconds until a traitor bot will consider shooting someone around them.

- **ttt_bot_flicking** (default: `1`)
  - Can the bots flick around when they get shot from the rear?

- **ttt_bot_difficulty** (default: `3`)
  - A difficulty integer between 1-5; higher = harder.

- **ttt_bot_kos_limit** (default: `2`)
  - The upper bound of KOS calls an individual, bot or player, can make per round.

- **ttt_bot_reaction_speed** (default: `0.8`)
  - The base time, in seconds, a bot will take before attacking a newly assigned target.

- **ttt_bot_plant_c4** (default: `1`)
  - Whether or not ANY bots are permitted to plant c4.

- **ttt_bot_defuse_c4** (default: `1`)
  - Whether or not ANY bots are permitted to defuse c4.

- **ttt_bot_personalities** (default: `1`)
  - Whether or not each bot should spawn in as its own unique individual.

- **ttt_bot_use_health** (default: `1`)
  - Whether or not bots can use and seek out health stations.

- **ttt_bot_plant_health** (default: `1`)
  - Whether or not bots can plant health stations as a policing role.

## Noise CVARS

- **ttt_bot_noise_investigate_chance** (default: `50`)
  - The % chance that a bot will investigate a noise he hears.

- **ttt_bot_noise_investigate_mtb** (default: `15`)
  - The minimum time between, in seconds, that a bot will investigate a noise he hears.

- **ttt_bot_noise_enable** (default: `1`)
  - Enables bots to hear noises and investigate them.

## Naming CVARS

- **ttt_bot_names_allowcommunity** (default: `1`)
  - Enables community-suggested names, replacing many auto-generated names.

- **ttt_bot_names_communityonly** (default: `0`)
  - Disables auto-generated names, only using community-suggested names.

- **ttt_bot_names_canleetify** (default: `1`)
  - Enables leetifying of ALL names.

- **ttt_bot_names_canusenumbers** (default: `1`)
  - Enables adding numbers to autogenerated names.

- **ttt_bot_names_canusespaces** (default: `1`)
  - Enables using spaces in autogenerated names.

- **ttt_bot_names_allowgeneric** (default: `1`)
  - Enables generic usernames, generated by ChatGPT.

- **ttt_bot_names_custom** (default: `""`)
  - A list of comma-separated names that bots will use as they join.

## Debug CVARS

- **ttt_bot_debug_pathfinding** (default: `0`)
  - Enables debug for pathfinding.

- **ttt_bot_debug_look** (default: `0`)
  - Enables debug for looking at things.

- **ttt_bot_debug_misc** (default: `0`)
  - Enables misc debug.

- **ttt_bot_debug_stuckpositions** (default: `0`)
  - Enables debug for stuck positions.

- **ttt_bot_debug_obstacles** (default: `0`)
  - Enables debug for recognized obstacles.

- **ttt_bot_debug_doors** (default: `0`)
  - Enables debug for doors.

- **ttt_bot_debug_attack** (default: `0`)
  - Enables debug for attacking.

- **ttt_bot_debug_evil** (default: `0`)
  - Enables debug for the Evil Coordinator.

- **ttt_bot_debug_inventory** (default: `0`)
  - Enables debug for inventory management.

- **ttt_bot_debug_strafe** (default: `0`)
  - Enables debug drawing for strafing.

- **ttt_bot_debug_navpopularity** (default: `0`)
  - Enables debug drawing for nav popularity.

- **ttt_bot_debug_brain** (default: `0`)
  - Enables debug for behavior trees.

- **ttt_bot_debug_forceweapon** (default: `""`)
  - Forces bots to use a specific weapon.

## Debug Log CVARS (Server Console Output)

These cvars enable text-based logging to the **server console** so you can get a full picture of the round without needing a client connected. All lines are prefixed with `[BOTDBG:<TAG>]` for easy grep/filtering. Use `ttt_bot_debug_log_all_on` / `ttt_bot_debug_log_all_off` to toggle everything at once, or `ttt_bot_debug_log_status` to check what's enabled.

- **ttt_bot_debug_log_round** (default: `0`)
  - Logs round lifecycle: prepare, start (with full roster/roles), and end (with results). Tag: `[BOTDBG:ROUND]`

- **ttt_bot_debug_log_kills** (default: `0`)
  - Logs every kill: who killed whom, weapon used, alive count after. Tag: `[BOTDBG:KILL]`

- **ttt_bot_debug_log_damage** (default: `0`)
  - Logs every damage event: attacker, victim, damage dealt, remaining HP. Tag: `[BOTDBG:DMG]` ⚠️ Can be spammy.

- **ttt_bot_debug_log_kos** (default: `0`)
  - Logs all KOS calls: caller, target, round timestamp. Tag: `[BOTDBG:KOS]`

- **ttt_bot_debug_log_bodies** (default: `0`)
  - Logs body discovery events: who found whose body, confirmed dead count. Tag: `[BOTDBG:BODY]`

- **ttt_bot_debug_log_behaviors** (default: `0`)
  - Periodically (every 3s) logs each alive bot's current behavior tree node and attack target. Tag: `[BOTDBG:BEHAV]`

- **ttt_bot_debug_log_plans** (default: `0`)
  - Logs traitor plan assignments and periodic plan state dumps. Tag: `[BOTDBG:PLAN]`

- **ttt_bot_debug_log_innocentcoord** (default: `0`)
  - Logs innocent coordinator strategy, buddy pairs (every 5s). Tag: `[BOTDBG:IC]`

- **ttt_bot_debug_log_evidence** (default: `0`)
  - Periodically (every 5s) dumps each bot's top 3 suspects with evidence weights. Tag: `[BOTDBG:EVID]`

- **ttt_bot_debug_log_awareness** (default: `0`)
  - Periodically (every 8s) logs round-awareness phase, aggression multiplier, group urgency, suspicion pressure. Tag: `[BOTDBG:PHASE]`

- **ttt_bot_debug_log_personality** (default: `0`)
  - Periodically (every 10s) logs personality archetype, difficulty, rage/boredom/pressure, and traits. Tag: `[BOTDBG:PERS]`

- **ttt_bot_debug_log_inventory** (default: `0`)
  - Periodically (every 8s) logs held/primary/secondary weapons per bot. Tag: `[BOTDBG:INV]`

- **ttt_bot_debug_log_memory** (default: `0`)
  - Periodically (every 8s) logs memory state: visible players, known positions, hearing multiplier. Tag: `[BOTDBG:MEM]`

- **ttt_bot_debug_log_morality** (default: `0`)
  - Periodically (every 4s) logs active attack targets with priority and reason codes. Tag: `[BOTDBG:MORAL]`

- **ttt_bot_debug_log_chatter** (default: `0`)
  - Logs all bot text chat messages. Tag: `[BOTDBG:CHAT]`

- **ttt_bot_debug_log_c4** (default: `0`)
  - Periodically (every 5s) logs armed/spotted C4 counts. Tag: `[BOTDBG:C4]`

- **ttt_bot_debug_log_locomotion** (default: `0`)
  - Periodically (every 6s) logs pathfinding state: has path, strafe, status, goal position. Tag: `[BOTDBG:LOCO]`

- **ttt_bot_debug_log_timeline** (default: `0`)
  - Periodically (every 15s) prints a full round snapshot: all alive players with roles, KOS targets, counts. Tag: `[BOTDBG:TIME]`

- **ttt_bot_debug_log_events** (default: `0`)
  - Firehose: logs every TTTBots event bus event with full payload. Tag: `[BOTDBG:EVENT]` ⚠️ Very spammy.

### Debug Log Console Commands

- **ttt_bot_debug_log_all_on** — Enables all 19 debug log cvars at once.
- **ttt_bot_debug_log_all_off** — Disables all 19 debug log cvars at once.
- **ttt_bot_debug_log_status** — Prints the ON/OFF state of each debug log cvar.
- **ttt_bot_debug_roundinfo** — Prints a one-shot snapshot of the current round (all players, roles, HP, behaviors).

## Personality CVARS

- **ttt_bot_boredom** (default: `1`)
  - Enables boredom. Bots will leave the server if they get too bored.

- **ttt_bot_boredom_rate** (default: `100`)
  - How quickly bots get bored.

- **ttt_bot_pressure** (default: `1`)
  - Enables pressure. Bots will have worse aim if they are under pressure.

- **ttt_bot_pressure_rate** (default: `100`)
  - How quickly bots accrue pressure.

- **ttt_bot_rage** (default: `1`)
  - Enables rage. Bots will leave, and even be more likely to RDM if RDM is enabled.

- **ttt_bot_rage_rate** (default: `100`)
  - How quickly bots get angry.

- **ttt_bot_allow_leaving** (default: `1`)
  - Enables bots to leave the server if they get too bored or angry.

## Dynamic Tick Rate Scaler CVARS

When many bots are on the server, the tick scaler logarithmically reduces how often each bot's behavior tree and components fire, making bots "dumber" to save CPU. Below the threshold bot count, bots run at full speed with zero overhead. The feature is **opt-in** (disabled by default).

The scaling formula is: `skip = floor(1 + factor × ln(botCount / threshold))` when `botCount > threshold`, clamped to `max_skip`. With default settings (threshold 8, factor 1.4427 ≈ 1/ln2):

| Bots | Skip | Effective Hz (at tickrate 5) | Effect |
|------|------|------------------------------|--------|
| ≤8   | 1    | 5.0 Hz                       | Full speed, no change |
| 16   | 2    | 2.5 Hz                       | Half as responsive    |
| 24   | 2    | 2.5 Hz                       | Half as responsive    |
| 32   | 3    | ~1.7 Hz                      | Noticeably slower     |
| 48   | 3    | ~1.7 Hz                      | Noticeably slower     |
| 64   | 4    | 1.25 Hz                      | Quite sluggish        |

Bots in active combat are exempt from throttling by default (`tickscaler_exempt_combat 1`).

- **ttt_bot_tickscaler_enabled** (default: `0`)
  - Master toggle. Set to `1` to enable dynamic tick scaling. When `0`, all bots think at the full `TTTBots.Tickrate` with zero overhead.

- **ttt_bot_tickscaler_threshold** (default: `8`)
  - Bot count at or below which no scaling is applied. Bots think at full speed until there are more than this many.

- **ttt_bot_tickscaler_factor** (default: `1.4427`)
  - Logarithmic multiplier. Higher = more aggressive throttling. The default `1.4427` (= 1/ln(2)) means every doubling of bots above the threshold adds +1 to the skip value.

- **ttt_bot_tickscaler_max_skip** (default: `6`)
  - Hard cap on the skip value. At tickrate 5, a skip of 6 means a bot only thinks ~0.83 times per second. Prevents bots from becoming completely unresponsive.

- **ttt_bot_tickscaler_exempt_combat** (default: `1`)
  - When `1`, bots that currently have an active attack target bypass throttling and think at full speed. This ensures combat responsiveness even on crowded servers.

- **ttt_bot_tickscaler_stagger** (default: `1`)
  - When `1`, bot think calls are staggered across ticks using each bot's UserID as a phase offset. This spreads CPU load evenly instead of having all bots think on the same tick.

- **ttt_bot_tickscaler_debug** (default: `0`)
  - Periodically (every 10s) prints tick scaler diagnostics to server console: bot count, skip value, and per-bot effective Hz with combat status. Tag: `[BOTDBG:TICKSCALER]`

## Pathfinding CVARS

- **ttt_bot_pathfinding_cpf** (default: `240`)
  - How many pathfinding calculations to do per frame.

- **ttt_bot_pathfinding_cpf_scaling** (default: `0`)
  - Should we dynamically multiply the pathfinding calculations per frame by the number of bots?

- **ttt_bot_pathfinding_max_nodes** (default: `600`)
  - Maximum number of A* nodes the pathfinder will explore before giving up on a path. Higher values allow paths through complex maps at the cost of more CPU time per frame.

- **ttt_bot_rdm** (default: `0`)
  - Enables RDM (random deathmatch).

- **ttt_bot_kos_enemies** (default: `0`)
  - Bots will KOS players in enemy roles or enemy teams.

- **ttt_bot_kos_nonallies** (default: `0`)
  - Bots will KOS players in non-ally roles or non-ally teams.

- **ttt_bot_kos_traitorweapons** (default: `0`)
  - Bots will KOS players that have traitor weapons.

- **ttt_bot_kos_unknown** (default: `0`)
  - Bots will KOS players with unknown roles.

- **ttt_bot_kos_postround** (default: `0`)
  - Bots will KOS players in the post-round.

## Behavior CVARS

- **ttt_bot_radar_chance** (default: `100`)
  - Chance that a traitor bot will simulate having radar as a traitor.

- **ttt_bot_coordinator** (default: `1`)
  - Enables the Evil Coordinator module.

## Voice CVARS

- **ttt_bot_chatter_voice_chance** (default: `50`)
  - The % chance that a bot will use a voice in voice chat.

- **ttt_bot_chatter_voice_good_tts_chance** (default: `0`)
  - The % chance that a bot will use a good TTS voice in voice chat.

- **ttt_bot_chatter_elevenlabs_voice_model** (default: `0`)
  - The Elevenlabs voice model to use for TTS.

- **ttt_bot_chatter_voice_good_tts_custom_name_override** (default: `0`)
  - Bots with the same name as a custom name will be forced to use that corresponding elevenlabs profile.

- **ttt_bot_debug_chatter_voice_team_color** (default: `0`)
  - Bots will use their team color in voice chat.

- **ttt_bot_chatter_voice_elevenlabs_api_key** (default: `""`)
  - The API key for Elevenlabs.

- **ttt_bot_chatter_voice_azure_voice_quality** (default: `3`)
  - The quality of the Azure TTS voice.

- **ttt_bot_chatter_voice_stt** (default: `0`)
  - Audio recorded in voice chat will be sent to a local Speech-to-Text service for transcription.

- **ttt_bot_chatter_voice_force_reply_player** (default: `1`)
  - Bots will always reply to players in voice chat.

- **ttt_bot_chatter_voice_azure_subscription_key** (default: `""`)
  - The API key for Azure Speech-to-Text.

- **ttt_bot_chatter_voice_azure_region** (default: `eastus`)
  - The region for Azure Speech-to-Text.

- **ttt_bot_chatter_voice_tts_provider** (default: `0`)
  - The TTS provider to use. 0 = Free TTS, 1 = Elevenlabs, 2 = Azure TTS, 3 = Mixed.

- **ttt_bot_chatter_voice_free_tts_chance** (default: `100`)
  - The % chance that a bot will use a free TTS voice in voice chat.

- **ttt_bot_chatter_voice_microsoft_tts_chance** (default: `0`)
  - The % chance that a bot will use an Azure TTS voice in voice chat.

- **ttt_bot_chatter_voice_elevenlabs_tts_chance** (default: `0`)
  - The % chance that a bot will use an Elevenlabs TTS voice in voice chat.