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

## Pathfinding CVARS

- **ttt_bot_pathfinding_cpf** (default: `240`)
  - How many pathfinding calculations to do per frame.

- **ttt_bot_pathfinding_cpf_scaling** (default: `0`)
  - Should we dynamically multiply the pathfinding calculations per frame by the number of bots?

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