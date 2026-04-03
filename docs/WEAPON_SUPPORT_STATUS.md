# TTT2 Bots — Weapon Support Status

> Last updated: April 2, 2026

---

## ✅ Fully Supported

These weapons have their own dedicated behavior file(s) in `lua/tttbots2/behaviors/` with full tactical usage logic, equip/fire handling, situational validation, target selection, chatter integration, and cleanup.

### 🔫 Standard Combat / Utility Weapons

| Weapon | Behavior(s) | Notes |
|--------|------------|-------|
| **Defibrillator** (`weapon_ttt_defibrillator`, `weapon_ttt2_medic_defibrillator`) | `defib.lua`, `defibplayer.lua` | Full corpse-seeking, navigation, hold-attack revive pipeline with `BeginRevival`/`FinishRevival` fallback; role-aware (Doctor, Medic, generic); marked-for-defib coordination |
| **Medigun / Healgun** (generic) | `healgun.lua` | `RegisterRoleWeapon` factory; finds low-HP targets; heals to max HP; handles heal requests from chatter |
| **Medigun (Doctor)** (`inv:GetStandardMedigun()`) | `healgundoctor.lua` | `RegisterRoleWeapon` factory; same-team healing only; heals to 100 HP |
| **Medigun (Medic)** (`inv:GetMedicMedigun()`) | `healgunmedic.lua` | `RegisterRoleWeapon` factory; heals ANY team (neutral healer); heals to max HP |
| **Jihad Bomb** (`weapon_ttt_jihad_bomb`) | `jihad.lua` | Phase-aware detonation thresholds; ally/jester blast protection; personality-driven chance calculation; used by Traitors and Defectors |
| **C4 Bomb** (`weapon_ttt_c4`) | `plantbomb.lua` | Full bomb-site selection with weighted scoring (witnesses, distance to enemies, existing bombs); navigate-to-site, plant, arm sequence; anti-loop protection |
| **DNA Scanner** (`weapon_ttt_wtester`) | `usednascanner.lua` | Corpse prioritization (unidentified > fresh > close); multi-slot scanner room checking; TTTFoundDNA hook integration; background radar-reaction hook for marker tracking; evidence sharing with allies |
| **Health Station** (`weapon_ttt_health_station`) | `usehealthstation.lua` | Places health stations; navigates to existing stations when hurt; validates station stored health |
| **Role Checker / Tester** (`weapon_ttt_traitorchecker`) | `userolechecker.lua`, `requestuserolechecker.lua` | Detectives place the checker; innocents walk to and use it; result hooks fire morality/evidence/memory updates; InnocentCoordinator tester queue integration; multi-attempt placement with aim retry logic |
| **Grenades** (incendiary, smoke, discombob, EMP, generic) | `usegrenade.lua` | Type-aware throw logic: cluster-targeting incendiary, retreating/cover smoke, ledge-push discombob, equipment-disabling EMP; hold-to-throw pin mechanic; cooldown and timeout protection |
| **Smart Bullets** (`weapon_ttt2_smart_bullets`) | `activatesmartbullets.lua` | Full equip → activate → switch-back pipeline; direct `PrimaryAttack()` call bypassing locomotor delays; tactical gate (only activates with target or aggressive personality); retry counter |
| **Time Stop** (`weapon_ttt_timestop`) | `usetimestop.lua` | Two-phase behavior: activation (equip, fire, wait for activation animation) → hunting (switch to combat weapon, navigate to frozen enemies, execute them); phase-aware thresholds; personality-driven chance; kill tracking and chatter |
| **Gravity Mine** (`weapon_ttt2_gravity_mine`) | `usegravitymine.lua`, `evadegravitymine.lua` | **Deploy:** finds enemy cluster centroid, equips, aims, fires via `PrimaryAttack()`; **Evade:** detects armed/pulling mines, calculates flee position away from mine, shoots mine from safe distance |
| **Hologram Decoy** (`weapon_ttt2_hologram_decoy`) | `usehologramdecoy.lua` | Deploys when not in active combat; direct `PrimaryAttack()` call; retry counter; opportunistic random chance gate |
| **Poison Dart** (`weapon_ttt2_poison_dart`) | `usepoisondart.lua` | `RegisterRoleWeapon` factory; targets isolated enemies; witness threshold check; clip-empty failure handling |
| **Reveal Grenade** (`weapon_ttt_reveal_nade`) | `userevealgrenade.lua` | Navigate to corpse → throw grenade onto it; scores corpses by proximity to enemies, attack target distance, visibility; non-interruptible once committed |
| **Traitor Turret** (`weapon_ttt_turret`) | `useturret.lua` | Finds tactical deploy spot; navigates to position; aims at ground for valid placement trace; verifies world-hit before firing; deploy timeout protection |
| **Peacekeeper / High Noon** (`weapon_ttt_peacekeeper`) | `usepeacekeeper.lua` | Full multi-phase state machine: equip → start → charge (sweep aim across enemies for FOV lock-on) → fire; tracks charged targets via `highnoontargets` and NWBools; handles all SWEP states (`none`/`starting`/`charging`/`firing`) |
| **Traitor Turret** (`weapon_ttt_turret`) | `useturret.lua` | Navigate, aim at floor, deploy; combat interruption protection |

### 🔪 Role-Specific Melee Weapons

| Weapon | Behavior(s) | Notes |
|--------|------------|-------|
| **Serial Killer Knife** (`weapon_ttt_sk_knife`) | `skknifeattack.lua` | Full isolation-seeking target selection; score-based rating (HP, witnesses, velocity, visibility); back-stab detection; witness-aware engagement; hands off to `AttackTarget` for melee combat |
| **TTT Knife (200dmg mod)** (`weapon_ttt_knife`) | `knifestalk.lua` | Only activates when 200dmg knife mod is detected; multi-phase stalk → close → attack → post-kill (roledefib or body-hide); back-facing detection; realistic witness counting; personality-driven chance (cautious > hothead) |
| **Hidden Knife** (`weapon_ttt_hd_knife`) | `hiddenknifeattack.lua`, `hiddenknifethrow.lua` | Full melee attack behavior + projectile throw (M2 secondary fire); stun-check awareness; Hidden invisibility integration |
| **Hidden Stun Grenade** (`weapon_ttt_hd_nade`) | `hiddenstunnade.lua` | Area denial / escape / pre-kill distraction; respawn delay awareness (`ttt2_hdn_nade_delay`); auto-switch back to knife after throw |

### 🎯 Role-Specific Deagles / Conversion Weapons

| Weapon | Behavior(s) | Notes |
|--------|------------|-------|
| **Jackal Deagle** (`inv:GetJackalGun()`) | `createsidekick.lua` | `RegisterRoleWeapon` factory; isolated target selection; witness threshold; phase-aware conversion boost |
| **Brainwasher Deagle** (`inv:GetBrainwashGun()`) | `createslave.lua` | `RegisterRoleWeapon` factory; conversion behavior with `isConversion = true` |
| **Sheriff Deputy Deagle** (`inv:GetDeputyGun()`) | `createdeputy.lua` | `RegisterRoleWeapon` factory; bot-side deagle refill handling for server-side bots; targets innocents with low suspicion |
| **Doctor Creation Deagle** | `createdoctor.lua` | `RegisterRoleWeapon` factory; creates Doctor role on target |
| **Medic Creation Deagle** | `createmedic.lua` | `RegisterRoleWeapon` factory; `hasWeaponFn`/`equipDirectFn` pattern |
| **Cursed Deagle** (`weapon_ttt2_role_swap_deagle`) | `swapdeagle.lua` | `RegisterRoleWeapon` factory; server-side deagle refill timer workaround for bots; `EntityFireBullets` miss-detection hook; eager start chance (40%) with `isConversion = true` |
| **Cursed Creation Deagle** | `createcursed.lua` | `RegisterRoleWeapon` factory; cursed role conversion |
| **Role Change Deagle** (`weapon_ttt2_role_change_deagle`) | `rolechangedeagle.lua` | `RegisterRoleWeapon` factory; detective-only; suspicion-weighted target selection; clip-empty failure |
| **Cupid's Lovers Gun** | `createlovers.lua` | Custom two-phase stateful behavior (replaced old `RegisterRoleWeapon`); server-side pairing logic |
| **Marker Deagle** | `createmarker.lua` | `RegisterRoleWeapon` factory; jester-team Marker role |
| **Priest Holy Deagle** | `priestconvert.lua` | `RegisterRoleWeapon` factory; safe target selection with suspicion filtering; `isConversion = true`; `clipEmptyFails = true` |
| **Defector Approach / Jihad** | `createdefector.lua`, `defectorapproach.lua` | Custom stateful behavior (not RegisterRoleWeapon); deception → jihad bomb detonation |

### 🎭 Spy-Specific Weapons

| Weapon | Behavior(s) | Notes |
|--------|------------|-------|
| **Dead Ringer** (`weapon_ttt_deadringer`) | `spydeadringer.lua` | Activates under threat (low HP, blown cover, nearby threats); fake-death → flee to safe location; per-round use limit; chatter deflection |

### 🏥 Doomguy-Specific Weapons

| Weapon | Behavior(s) | Notes |
|--------|------------|-------|
| **Doom Super Shotgun Meathook** (`weapon_dredux_de_supershotgun` M2) | `usemeathook.lua` | Secondary fire grapple hook; range/LOS/geometry safety checks; commit window with movement suppression; cooldown between attempts; post-hook primary fire follow-up |

---

## ⚠️ Partially Supported

These weapons are recognized by the bot system or used indirectly, but lack dedicated tactical behaviors. The bot can equip and fire them as generic weapons through the inventory auto-management system, but won't use their special mechanics intelligently.

| Weapon | How It's Handled | Missing Mechanics |
|--------|-----------------|-------------------|
| **Role Defibrillators** (`weapon_ttt_defib_traitor`, `weapon_ttt_mesdefi`, `weapon_ttt2_markerdefi`) | `roledefib.lua` handles all three classes generically | No role-specific revival logic per weapon type; treats all role defibs identically |
| **Necromancer Defibrillator** (`weapon_ttth_necrodefi`) | `necrodefib.lua` — full behavior exists | Witness checking and corpse prioritization exist but zombie management after revival relies on separate zombie sub-tree |
| **Mesmerist Defibrillator** (`weapon_ttt_mesdefi`) | `mesmeristdefib.lua` — full behavior exists | Dedicated behavior exists with witness safety and kill-corpse priority; partially overlaps with generic `roledefib.lua` |
| **Counter-Strike Weapons** (CS:S weapons pack) | Auto-managed as standard guns by inventory system | No special firing mode logic (burst fire, scoped weapons); bots just point and shoot |
| **M9K Minigun** (`m9k_minigun`) | Equippable as a primary weapon through inventory | No spin-up/spin-down awareness; no movement speed penalty consideration; no sustained-fire tactics |
| **Beenade** (`weapon_ttt_beenade`) | May be picked up as grenade slot by inventory | UseGrenade reports -1/-1 clip grenades as bogus and skips them; beenade may not throw properly |
| **Holy Hand Grenade** (`weapon_holyhand_grenade`) | May be picked up as grenade slot by inventory | UseGrenade explicitly skips grenades with -1 clip / -1 maxammo / 0 reserve (matches this weapon's ammo pattern) |
| **Infini-Shoot** (item, not SWEP) | Item is auto-bought if available in shop | No tactical awareness of infinite ammo buff; doesn't change bot combat behavior |
| **TTT Knife (standard 50dmg)** (`weapon_ttt_knife`) | Generic melee weapon in inventory | `knifestalk.lua` only activates with the 200dmg mod installed; standard knife gets no stalk/ambush AI |

---

## ❌ No Support

These weapons exist in the installed TTT2 Weapons collection but have **no corresponding behavior file** in `lua/tttbots2/behaviors/`. Bots assigned these weapons (through shop purchases or loadouts) will either ignore them, equip them as generic guns with no special usage, or fail to use them entirely.

### Workshop Weapons (No Bot AI)

| Weapon | Addon Folder | Notes |
|--------|-------------|-------|
| **Maxwell's Gun** | `maxwell_gun_ttt_2918174143/` | No bot usage logic |
| **Prop Rain** | `ttt2_prop_rain_2321730454/` | Prop-spawning weapon; no area denial / prop rain tactics |
| **Smart Pistol** | `ttt2_smart_pistol_buffed_3336119131/` | Auto-aim weapon; bots don't need the auto-aim but lack lock-on / burst-fire awareness |
| **Snail** | `snail_732985332/` | Model/prop addon; no weapon behavior needed |
| **EMP Grenade** | `ttt2_emp_grenade/` | The `usegrenade.lua` behavior has EMP type detection and targets equipment entities — **may partially work** if classified as a grenade by the inventory system |

### Standard TTT2 Base Weapons (Generic Handling Only)

These are core TTT2/TTT weapons that bots handle through the generic combat system (inventory auto-management, `AttackTarget` behavior) but lack weapon-specific tactical behaviors:

| Weapon Type | How Bots Handle It | What's Missing |
|-------------|-------------------|----------------|
| **Shotguns** (e.g. M3 Super 90) | Equip and fire through `AttackTarget` | No range-awareness for spread; no close-quarters preference logic |
| **Sniper Rifles** (e.g. Scout) | Equip and fire through `AttackTarget` | No scope usage; no long-range positioning preference; no headshot targeting |
| **SMGs** (e.g. MAC-10, UMP) | Equip and fire through `AttackTarget` | No burst-fire or spray control |
| **Pistols** (e.g. Glock, Five-SeveN) | Equip and fire through `AttackTarget` | No tap-fire or accuracy management |
| **Crowbar** (`weapon_zm_improvised`) | Used as last-resort melee | No door-breaking priority; no prop-pushing tactics |
| **Magneto Stick** (`weapon_zm_carry`) | Used for basic prop interactions | No body-carrying strategy (except in `knifestalk.lua` post-kill) |

---

## 📋 Summary

| Category | Count | Description |
|----------|-------|-------------|
| ✅ **Fully Supported** | ~30 weapons/behaviors | Dedicated behavior files with full tactical AI, equip/fire pipelines, and situational awareness |
| ⚠️ **Partially Supported** | ~10 weapons | Recognized by inventory system but lacking special mechanic usage |
| ❌ **No Support** | ~15 custom weapons | No behavior file; bots will ignore or use as generic weapons |

### Key Behavior Files Reference

| File | Weapons Covered |
|------|----------------|
| `activatesmartbullets.lua` | Smart Bullets SWEP |
| `defib.lua` / `defibplayer.lua` | Standard defibrillators |
| `evadegravitymine.lua` | Gravity Mine (defensive) |
| `healgun.lua` / `healgundoctor.lua` / `healgunmedic.lua` | Medigun variants |
| `hiddenknifeattack.lua` / `hiddenknifethrow.lua` / `hiddenstunnade.lua` | Hidden role weapons |
| `jihad.lua` | Jihad Bomb |
| `knifestalk.lua` | TTT Knife (200dmg mod) |
| `mesmeristdefib.lua` | Mesmerist Defibrillator |
| `meta_roleweapon.lua` | Factory for all deagle/conversion weapons |
| `necrodefib.lua` | Necromancer Defibrillator |
| `plantbomb.lua` | C4 Bomb |
| `rolechangedeagle.lua` | Role Change Deagle |
| `roledefib.lua` | Traitor role defibrillators |
| `skknifeattack.lua` | Serial Killer Knife |
| `spydeadringer.lua` | Dead Ringer |
| `swapdeagle.lua` | Cursed Role Swap Deagle |
| `usednascanner.lua` | DNA Scanner |
| `usegrenade.lua` | All grenade types |
| `usegravitymine.lua` | Gravity Mine (offensive) |
| `usehealthstation.lua` | Health Station |
| `usehologramdecoy.lua` | Hologram Decoy |
| `usemeathook.lua` | Doom SSG Meathook |
| `usepeacekeeper.lua` | Peacekeeper / High Noon |
| `usepoisondart.lua` | Poison Dart Gun |
| `userevealgrenade.lua` | Reveal Grenade |
| `userolechecker.lua` / `requestuserolechecker.lua` | Role Checker / Tester |
| `usetimestop.lua` | Time Stop weapon |
| `useturret.lua` | Traitor Turret |
| `create*.lua` (7 files) | Various role conversion deagles |
| `priestconvert.lua` | Priest Holy Deagle |
