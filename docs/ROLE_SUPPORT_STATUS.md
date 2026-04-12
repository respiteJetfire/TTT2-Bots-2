# TTT2 Bots — Role Support Status

> Last updated: April 6, 2026 (batch 6 — Astronaut fully supported; Star Wars: The Force clarified as a vanilla TTT weapon addon with no custom roles)

---

## ✅ Fully Supported

These roles have their own `.lua` file in `lua/tttbots2/roles/` with full custom behavior trees, role-specific behaviors, and hooks.

### 🔵 Innocent Team

| Role | Notes |
|------|-------|
| **Innocent** | Base innocent tree via `InnocentLike` builder |
| **Detective** | `DetectiveLike` builder with DNA scanner usage and corpse investigation |
| **Deputy** | Full tree with `FollowMaster`; reacts to Sheriff being shot/attacked via hooks |
| **Sheriff** | Custom `DetectiveLike` tree with elevated `Convert` priority for deputizing; `TTTBotsOnWitnessHurt` hook retaliates when Sheriff is attacked and calls for backup |
| **Sniffer** | `DetectiveLike` tree; `TTTBodyFound` hook converts `snifferIsKiller` blood-trail flag into suspicious position + `SetAttackTarget` for the confirmed killer |
| **Banker** | Custom `DetectiveLike` tree with `TacticalEquipment` prioritised for credit spending; `Think` hook watches credit balance and scales aggression (richer = more confident) |
| **Vigilante** | Custom `DetectiveLike` tree; `TTT2PostPlayerDeath` hook reads `ttt2_vig_multiplier` NWFloat and scales bot aggression (higher mult = more aggressive pursuit; team-kill = cautious) |
| **Decipherer** | Custom `DetectiveLike` tree with standalone `UseRoleChecker` node elevated between `Requests` and `Accuse` so the bot deploys and scans suspects before committing to accusations |
| **Doctor** | Custom tree with `Healgun`, defibrillator, allied with innocents |
| **Medic** | Custom tree with `Healgun`; allied with ALL teams (neutral healer) |
| **Occultist** | Custom innocent tree; `Think` hook watches `occ_data.allow_revival` — cautious before revival is armed (0.5 aggression), reckless after (1.0), conservative post-revival (0.4) |
| **Survivalist** | Custom scavenger-focused innocent tree with `unknownTeam` awareness; elevated `Restore` priority for weapon looting; `Think` hook sets aggression proportional to HP ratio |
| **Oracle** | Custom tree with dedicated `Oracle` behavior |
| **Pharaoh** | Full custom tree: `DefendAnkh`, `PlantAnkh`, `CaptureAnkh`, `GuardAnkh`, `RelocateAnkh`, `PostRevival` |
| **Clairvoyant** | Full custom tree: `ClairvoyantIntel`, `ClairvoyantJesterHunt` (conditional), `ClairvoyantWicked` |
| **Spy** | Full custom tree: `SpyBlend`, `SpyReport`, `SpyFakeBuy`, `SpyEavesdrop`, `SpyDeadRinger`; traitor detection timers; personality modifiers; cover-blown hooks |
| **Priest** | Full custom tree with `PriestConvert`; brotherhood trust/evidence syncing; cascade threat awareness; coordination timers |
| **Beacon** | Custom tree with heavy corpse investigation focus for buff accumulation; `unknownTeam` awareness; demotion-safe (avoids innocent kills) |
| **Announcer** | `DetectiveLike` builder; public policing role with purchase broadcast support |
| **Chef** | Custom innocent tree with `unknownTeam` awareness; cooking is server-driven (automatic healing); no coordination; uses suspicion |
| **Hurricane** | `DetectiveLike` builder; detective subrole with "flagging" first-shot mechanic (reduces target HP, mutes); public policing role |
| **Master Chief** | Full custom tree: omniscient public hunter with `Stalk` priority; `DetectiveLike` base; prefers `br55` battle rifle; `SetKnowsLifeStates(true)`, no suspicion; custom `TEAM_MASTERCHIEF` allied; radar flag respects `ttt2_masterchief_tracker_mode` convar via `InitPostEntity` hook |
| **Guardian** | Custom tree with `GuardianProtect`; Phase 1 links to a ward via 0-dmg deagle shot; Phase 2 follows and defends ward; `PlayerHurt` hook intercepts attacks on ward and assigns attacker as combat target; `unknownTeam`; no shop |
| **Astronaut** | Custom tree with `AstronautMeeting`; navigates to unused corpses within 2000 u, equips `weapon_ast_meeting`, holds primary fire for `ttt_astronaut_meeting_charge_time` seconds to call a community vote; self-imposed 35 s post-meeting cooldown; `isPublicRole`; `unknownTeam`; detective shop fallback |
| **Trapper** | Custom tree with `TrapperButton`; navigates to and activates traitor buttons (`func_button` / `ttt_traitor_button`) with 20 s cooldown; button-ping notifications feed into suspicious position memory; `unknownTeam`; no shop |
| **Seance** | `InnocentLike` tree; `PlayerDeath` hook with `ttt2_seance_notification_time` delay feeds death positions into bot memory via `AddSuspiciousPosition` / `UpdateKnownPositionFor`; passive intel role; `unknownTeam`; no shop |
| **Lycanthrope** | Two-phase tree: normal Innocent pre-transform → aggressive `Stalk` post-transform; `GetTreeFor` override checks `LycTransformed` NWBool each tick; chatter / `TTTBots.LycanthropyTransformed` hook fires on transformation detection |
| **Hunch** | `DetectiveLike` builder; `TTT2PostPlayerDeath` hook feeds death positions into suspicious memory (simulating death vision); `unknownTeam` awareness |
| **Mute** | Custom innocent tree with radar; cannot fight effectively (weapon-switch blocked server-side); `unknownTeam`; no coordination; no shop |
| **Nova** | `InnocentLike` tree with `unknownTeam`; `Think` hook watches nova timer → steers bot toward enemies in final 10 seconds; explosion is server-driven |
| **Paranoid** | `InnocentLike` builder; Dead Man's Sight item is cosmetic/automatic — no bot action needed; `unknownTeam` awareness |
| **Wrath** | `InnocentLike` builder; disableSync role is hidden from bot itself; revival-to-traitor is server-driven; `unknownTeam` awareness |
| **Spectre** | `InnocentLike` builder; `unknownTeam`; on-death haunt phase and revive are fully server-driven; no shop |
| **Poisoner** | `InnocentLike` builder; `unknownTeam`; on-death poison DoT is fully server-driven; no shop |
| **Rat** | Two-phase tree: pre-reveal (innocent blend) → post-reveal (aggressive hunt of known traitors); `GetTreeFor` override on `IsRatRevealed` flag; `TTTBotsOnWitnessHurt` hook triggers reveal detection; `unknownTeam` |
| **Sleeper** | Two-phase tree: pre-activation (full InnocentLike) → post-activation (traitor-level Stalk aggression); `GetTreeFor` override on `awokenSleepers` table; `TTT2PostPlayerDeath` hook detects last-traitor death and flips bot to traitor combat mode; `unknownTeam`; `disableSync` |

### 🔴 Traitor Team

| Role | Notes |
|------|-------|
| **Traitor** | Full default traitor tree via `TraitorLike` builder |
| **Hitman** | Custom traitor tree with `HitmanTarget` behavior inserted at high priority; `HitmanTarget` uses `GetTargetPlayer()` / NW entity fallback; `SetKnowsLifeStates(true)`; `TTTBeginRound` hook pre-seeds contract target into bot memory |
| **Mesmerist** | Full custom tree with `MesmeristDefib` (revives kills as Thralls) |
| **Brainwasher** | Full custom tree with `Convert` priority, deception blend, and `Slave` ally awareness |
| **Slave** | Custom traitor tree with `FollowMaster` inserted before `FollowPlan`; `TTTBotsOnWitnessHurt` hook immediately retaliates and calls chatter when the Brainwasher (master) is attacked |
| **Defector** | Full custom tree: `DefectorApproach` + `Jihad` suicide bomb; deception/blend behaviors; mid-round conversion hook |
| **Wicked** | Full custom tree: `ClairvoyantWicked`, `Jihad`, `PlantBomb`, traitor coordination |
| **Graverobber** | Full custom tree: `CaptureAnkh`, `DestroyAnkh`, `HuntAnkh`, `PostRevival`; spawned when Pharaoh places Ankh |
| **Accomplice** | Custom traitor tree with `unknownTeam` awareness — uses suspicion system, no coordination, corpse radar emphasis |
| **Ajin** | Two-phase traitor: dormant (standard traitor) → transformed (solo aggressive); `GetTreeFor` override swaps tree on `AjinTransformed` NWBool |
| **Ambusher** | `TraitorLike` builder with camping emphasis — `CanSnipe`/`CanHide` enabled for ambush positions; damage buff from standing still |
| **Arsonist** | `TraitorLike` builder optimized for close-range — prefers flamethrower engagements; no sniping |
| **Blight** | `TraitorLike` builder; isOmniscientRole; infects killer on death with DoT (server-driven) |
| **Blocker** | `TraitorLike` builder; isOmniscientRole; prevents corpse identification while alive (server-driven) |
| **Cyclone** | `TraitorLike` builder; traitor subrole with "flagging" first-shot mechanic (reduces target HP, mutes) |
| **Executioner** | Custom tree with `ExecutionerTarget`; focus-fires contract target at 2× damage while suppressing attacks on non-targets during punishment phases; `TTTBots.Executioner_GetTarget` / `IsPunished` helpers with `EXCT_DATA` API + NW fallback; `isOmniscientRole` |
| **Vampire** | Custom tree with `VampireHunt`; urgency-scaled hunting across 4 tiers (calm / uneasy / urgent / desperate) driven by bloodlust timer; activates at urgency ≥ 0.4; `InBloodlust` NWBool + `Bloodlust` NWInt timestamp tracking; SELF_DEFENSE priority (5) in full bloodlust; `isOmniscientRole` |
| **Glutton** | Two-phase tree (Glutton → Ravenous): `GluttonBite` manages hunger via corpse eating (secondary fire on `prop_ragdoll`) and urgency target assignment; `GetTreeFor` override switches trees on `Hunger_Level` NWInt threshold; `TEAM_RAVENOUS` registration with `KOSAll` + `KOSedByAll`; `isOmniscientRole` |
| **Ravenous** *(Glutton sub-role)* | Ravenous sub-tree: `Stalk` aggression; `KOSAll` + `KOSedByAll`; preferred weapon `weapon_ttt_glut_bite`; omniscient; solo win condition |
| **Janitor** | Custom tree with `JanitorSweep`; navigates to corpses within 1500 u and sweeps (primary fire, 60 s cooldown via `ttt2_jan_timer_cooldown`) or DNA-wipes (secondary fire, no cooldown); `cleanedCorpses` set prevents re-sweeping; equips `weapon_ttt2_jan_broom`; `isOmniscientRole` |
| **Impostor** | Custom tree with `ImpostorKill` + `ImpostorSabotage`; instant kill via interact (+use eye-trace) or knife mode (45 s cooldown); proactive O2/Reactor sabotage via `IMPO_SABO_DATA` API with net message fallback; `impo_can_insta_kill` / `impo_in_vent` NW tracking; excludes Spy from instakill; `isOmniscientRole`; no shop |
| **Fuse** | `TraitorLike` builder with aggressive `Stalk`-first tree; timer-pressure driven — must kill within cooldown or self-explode; timer reset is server-driven; `isOmniscientRole` |
| **Gambler** | `TraitorLike` builder; receives random assortment of traitor items/weapons at round start (server-driven); no credit earning; `isOmniscientRole` |
| **Morphling** | `TraitorLike` builder with `FakeInvestigate` + `AlibiBuilding` deception blend; disguise device (`weapon_ttt_morph_disguise`) used automatically; suspicion hook reduces bot trust; `isOmniscientRole` |
| **Psycho** | `TraitorLike` builder with aggressive `Stalk`-first tree; transformation item boosts damage/speed post-delay (server-driven); `isOmniscientRole`; no shop |
| **Roider** | `TraitorLike` builder; preferred weapon `weapon_zm_improvised` (crowbar); enhanced crowbar damage and push force are server-driven |
| **Sus** | Custom tree with `FakeInvestigate` + traitor coordination blend; `isOmniscientRole`; `unknownTeam`; randomly may be TEAM_TRAITOR at spawn; jams traitor chat/voice (server-driven); appears as traitor on radar and corpse inspection |
| **Defective** | `TraitorLike`-style custom tree with `FakeInvestigate` + `AlibiBuilding` deception blend; disguised as Detective to all; uses DNA scanner; `unknownTeam` suspicion hook (lower mult = appears trustworthy); `isOmniscientRole` |
| **Haunted** | `TraitorLike` builder; `TTT2PostPlayerDeath` hook marks killer as KOS target for all traitor bots (promotes haunt-trigger conditions); revival is server-driven; `isOmniscientRole` |

### 🟡 Neutral / Independent Teams

| Role | Notes |
|------|-------|
| **Serial Killer** | Full custom tree: `SKKnifeAttack`, `SKShakeNade`; phase-based tree switching (stealth early → aggressive late); `NeutralKiller` builder |
| **Doomguy** | Full custom tree: `DoomguyHunt`, `DoomguyPressureAdvance`, `UseMeathook`; prefers SSG; `NeutralKiller` builder |
| **Doomguy (Blue)** | Mirrors main Doomguy behavior |
| **Doomguy (Red)** | Mirrors main Doomguy behavior |
| **Hidden** | Full custom two-phase tree (Disguised → Stalker): `HiddenActivate`, `HiddenKnifeAttack`, `HiddenKnifeThrow`, `HiddenStunNade`; invisibility perception reduction for other bots |
| **Jackal** | Full custom tree: `Convert` (sidekick deagle), `Stalk`, `Deception` blend |
| **Sidekick** | Full custom tree: `FollowMaster`; cooperative fire/defense hooks tied to Jackal |
| **Necromancer** | Full custom tree + Zombie sub-tree: `NecroDefib` for corpse→zombie conversion; dynamic tree switching |
| **Zombie** *(Necromancer sub-role)* | Zombie sub-tree: `ZombieAttack`, `ZombieProtectMaster` |
| **Infected** | Full custom tree + Zombie sub-tree: `InfectedRush`, `ProtectHost`; host vs. zombie dynamic tree switching |
| **Amnesiac** | Full custom tree: `AmnesiacSeek` (high-priority corpse-seeking); seamless post-conversion tree handoff to copied role |
| **Cursed** | Full custom tree: `CursedEvade`, `SwapDeagle`, `SwapRole`, `CursedImmolate` |
| **Clown / Killer Clown** | Full two-phase tree: passive pre-transform (jester-like) → aggressive Killer Clown; dynamic tree switching; suspicion hook |
| **Drunk** | Custom neutral passive tree; `TTT2UpdateSubrole` hook fires on role reveal — hot-swaps bot's `BTree`, `StartsFights`, and `UsesSuspicion` flags to the revealed role's `RoleData` within 0.2 s |
| **Cupid** | Full two-phase tree: pre-link (`CreateLovers`) → post-link (`ProtectLover`); helper API for lover queries |
| **Mimic** | Custom tree with `CopyRole` elevated to high priority (after `SelfDefense`, before `Investigate`); `TTT2UpdateSubrole` hook hot-swaps bot tree on copy completion; suspicion hook (0.5×) for innocent blending |
| **Undecided** | Basic neutral non-aggressive tree |
| **Revenant** | Team-based killer with `Convert` and `Stalk` |
| **Restless** | Team-based killer with `Convert`, `Stalk`, and life-state knowledge |
| **Alien** | Full custom tree: `AlienProbe` behavior seeks isolated targets for melee-range probing; non-violent; tracks probed players; auto-revives; suspicion reduction hook |
| **Baker / Famine** | Full two-phase tree: Baker distributes bread via `BakerBake` → Famine hunts aggressively; `GetTreeFor` override for phase switching; force-famine SecondaryAttack support; suspicion hook |
| **Gun Dealer** | Full neutral supply tree: `GunDealerDeliver`, consignment manifest; self-defense only; `NeutralOverride` set |
| **Marker** | Jester-team role with `CreateMarker` behavior |
| **Jester** | Jester-team role with suspicion hook (`cheat_know_jester` convar) |
| **Swapper** | Jester-team stalker with suspicion hook (`cheat_know_swapper` convar) |
| **Anonymous** | Traitor-like team role with `Convert`, radar, no suspicion |
| **Pirate** | Full team role: `FollowMaster`; cooperative fire hooks with captain; contract-based team allegiance switching |
| **Pirate Captain** | Full team role: `Convert`, `FollowMaster`; cooperative hooks with pirates; contract-based team switching |
| **Beggar** | Full custom tree with `BeggarSeek` behavior; jester-team role that follows players seeking dropped shop weapons; team conversion on pickup; suspicion hook |
| **Collusionist** | Full custom tree with `BeggarSeek` behavior; jester-team role that swaps roles with shop item donors; suspicion hook |
| **Cult Leader** | Full custom tree with `CultTomeConvert` behavior; melee tome converts players to Cultists and heals existing Cultists; custom TEAM_CULTIST; traitor-shop access |
| **Cultist** | Custom aggressive tree; converted sub-role on TEAM_CULTIST; coordinates with Cult Leader; isOmniscientRole |
| **Lunk** | Custom solo killer tree on TEAM_LUNK: `FightBack` + `Stalk` only; melee-only (`weapon_lunkfist`; `SetAutoSwitch(false)`); high HP/armor server-driven; `KOSAll`/`KOSedByAll`; `isOmniscientRole`; `isPublicRole` |
| **Vulture** | Custom solo independent tree: `VultureEat` behavior seeks and eats corpses within 2000 u (primary knife fire); `Stalk` to create more corpses; `KOSAll`; custom TEAM_VULTURE; win condition tracks `VULTURE_DATA.amount_eaten`; suspicion hook |
| **Speedrunner** | Custom solo killer tree on TEAM_SPEEDRUNNER: `Stalk`-priority aggressive hunter; `KOSAll`/`KOSedByAll`; radar from loadout; `isOmniscientRole`; boosted speed/jump/fire rate are server-driven; respawn on death is server-driven |
| **Duelist** | Custom TEAM_NONE neutral tree: aggressive `Stalk` to hunt opponent; `NeutralOverride`; immunity to non-Duelists is server-driven; suspicion hook (0.4×) |
| **Dunce** | Custom TEAM_DUNCE public tree: `Minge`-priority wanderer; `StartsFights = false`; all damage output blocked server-side; `NeutralOverride`; zero-suspicion hook; forced via `roleselection.finalRoles` |
| **Elderly** | Custom TEAM_NONE neutral tree: `CombatRetreat`-priority survival; greatly reduced max HP (server-driven); `StartsFights = false`; no shop; suspicion hook (0.5×) |
| **Thief** | Custom TEAM_THIEF solo survivalist tree: `CombatRetreat`-first; win-steal mechanic is entirely server-driven (`TTT2ModifyWinningAlives`); `NeutralOverride`; suspicion hook (0.5×) |
| **Leech** | Custom TEAM_NONE neutral tree: repurposes `BeggarSeek` to stay near players (hunger refill); dies if hunger hits 0 (server-driven `Think` hook); join-winning-team mechanic is server-driven; suspicion hook (0.4×) |
| **Mayor** | `DetectiveLike` builder; public policing Detective sub-role with omniscient intel awareness; `isOmniscientRole`; intel tips are server-driven |
| **Warpriest** | `DetectiveLike` builder (`ROLE_WARP`); public policing Detective sub-role; `isOmniscientRole`; sigmartome weapon use handled by base combat |
| **Link** | `DetectiveLike` builder; public policing Detective sub-role with omniscient awareness; master sword use handled by base combat |
| **Undercover Agent** | Custom `TEAM_INNOCENT` tree (`ROLE_UCA`); `unknownTeam`; `InvestigateCorpse`-priority to prepare for detective promotion; auto-promotion to Detective on Detective's death is server-driven |
| **Revolutionary** | Custom `TEAM_INNOCENT` tree (`ROLE_REVOL`); `unknownTeam`; traitor-shop fallback; `InvestigateCorpse` + `UseDNAScanner` focus; `isOmniscientRole`; `canSnipe`/`canHide` enabled for aggressive policing |
| **Pure** | `InnocentLike` builder (`ROLE_PURE`); `TTTBotsModifyPersonality` hook reduces aggression to 0.2 (avoids killing to preserve role); `unknownTeam` |
| **Sacrifice** | Custom `TEAM_INNOCENT` tree (`ROLE_SACRIFICE`); `unknownTeam`; heavy `InvestigateCorpse` + `UseDNAScanner` focus for defibrillator-synergy play; radar enabled |
| **Mutant** | `InnocentLike` builder (`ROLE_MUT`); `unknownTeam`; 4-tier damage-scaling mutation and stat boosts are server-driven |
| **Patient** | `InnocentLike` builder (`ROLE_PAT`); `unknownTeam`; cough-infection weapon use handled by base combat; no shop |
| **Necrohealiac** | `InnocentLike` builder (`ROLE_NECROH`); `unknownTeam`; healing-on-player-death mechanic is server-driven |
| **Shanker** | Custom `TEAM_TRAITOR` tree (`ROLE_SHANK`); `isOmniscientRole`; melee-only (`canSnipe=false`); `Stalk` + `AttackTarget` close-range rush; no shop |
| **Hanfei** | Custom `TEAM_TRAITOR` tree (`ROLE_HANF`); `isOmniscientRole`; `Jihad` + `PlantBomb` behaviors; prefers close range for death-explosion synergy; no sniping |
| **Heretic** | Custom `TEAM_TRAITOR` tree; `isOmniscientRole`; `Stalk`-priority aggressive traitor; demon transformation stats are server-driven |
| **Yandere (Calm)** | Custom `TEAM_INNOCENT` tree (`ROLE_YCALM`); `unknownTeam`; `SetGetTreeFor` swaps to crazy-aggro tree on `ROLE_YCRAZY` detection; radar given at loadout |
| **Yandere (Crazy)** | Custom `TEAM_INNOCENT` tree (`ROLE_YCRAZY`); `KOSAll`/`KOSedByAll`; aggressive `Stalk`; heals on kill and speed boost are server-driven |
| **Senpai** | `InnocentLike` builder (`ROLE_SENPAI`); passive role linked to the Yandere |
| **Streamer** | Custom `TEAM_STREAMER` tree (`ROLE_STREAM`); `isOmniscientRole`; `Interact` behavior for weapon-pickup-to-convert mechanic; coordinates with Simps |
| **Simp** | Custom `TEAM_STREAMER` tree (`ROLE_SIMP`); converted mid-round by Streamer; `isOmniscientRole`; `Stalk` aggression; coordinates with Streamer |
| **Shinigami** | Custom `TEAM_INNOCENT` tree (`ROLE_SHINI`); `unknownTeam`; `SetGetTreeFor` swaps to aggressive Stalk tree post-revival on `SpawnedAsShinigami` NWBool; suspicion hook (0.2× pre-revival) |
| **The Flood (Infector)** | Custom `TEAM_FLOOD` tree (`ROLE_FINF`); `KOSAll`/`KOSedByAll`; melee-only claws; `isOmniscientRole`; coordinates with all Flood variants |
| **The Flood (Combat Form)** | Custom `TEAM_FLOOD` tree (`ROLE_FCF`); identical to Flood Infector bot behavior |
| **The Flood (Tank Form)** | Custom `TEAM_FLOOD` tree (`ROLE_FTF`); identical to Flood Infector bot behavior |
| **The Flood (Elite Form)** | Custom `TEAM_FLOOD` tree (`ROLE_FEF`); identical to Flood Infector bot behavior |
| **Kobold Hoarder** | Custom `TEAM_KOBOLD` neutral tree; `NeutralOverride`; `Interact`-priority item hoarding; small/fast size, `canHide=true`; `StartsFights=false`; stats server-driven |
| **Loot Goblin** | Custom `TEAM_LOOTGOBLIN` neutral tree; `NeutralOverride`; `Interact`-priority loot hoarding; tiny/fast, low HP server-driven; `canHide=true`; `StartsFights=false` |
| **Hunter (Covenant)** | Custom `TEAM_COVENANT` tree (`ROLE_HUNTER`); `isOmniscientRole`; `KOSAll`/`KOSedByAll`; heavy cannon (no sniping); rage mode and bondmate system are server-driven |
| **Suicide Grunt (Covenant)** | Custom `TEAM_COVENANT` tree (`ROLE_SG`); `isOmniscientRole`; `KOSAll`/`KOSedByAll`; `Jihad` rush-and-detonate behavior; follows Hunter commander; respawn system is server-driven |
| **Suicide Barrel** | Custom `TEAM_BARRELS` solo tree (`ROLE_SBARREL`); `isOmniscientRole`; `KOSAll`/`KOSedByAll`; `Jihad` explosion rush; solo (no allied teams) |

### 🟣 Gang Roles *(requires gang role addon)*

| Role | Notes |
|------|-------|
| **Ballas** | `GangRole` builder — enemies all other gangs |
| **Bloods** | `GangRole` builder |
| **Crips** | `GangRole` builder |
| **Families** | `GangRole` builder |
| **Hoovers** | `GangRole` builder |

---

## ⚠️ Partially Supported

These roles have a file and load correctly, but are registered via a generic builder (`InnocentLike`, `TraitorLike`, `DetectiveLike`) with no role-specific behaviors, ability usage, or special hooks. The bot will function but won't use the role's unique mechanics.

| Role | Builder Used | Missing Mechanics |
|------|-------------|-------------------|
| **Occultist** | `InnocentLike` | Doesn't use occultist-specific soul/spirit abilities |
| **Survivalist** | `InnocentLike` | No scavenger or loot-hoarding logic |
| **Sniffer** | `DetectiveLike` | No active DNA/scent sniffing on suspects |
| **Sheriff** | `DetectiveLike` | No special arrest or deputy-creation shooting logic |
| **Vigilante** | `DetectiveLike` | No self-justice kill tracking or bounty logic |
| **Banker** | `DetectiveLike` | No credit-economy or spend-tracking awareness |
| **Decipherer** | `DetectiveLike` | Bot doesn't actively prioritize using role checker on suspects |
---

## ❌ No Support

These roles exist in the installed TTT2 Roles collection but have **no corresponding file** in `lua/tttbots2/roles/`. Bots assigned to these roles will receive no role-specific AI and may fall back to a broken default state.

### Community Workshop Roles

| Role | Notes |
|------|-------|
| **Unknown** | Stub file only — no meaningful behavior |

> **Note on "Star Wars: The Force":** The local folder `star_wars_the_force_1737101500` is a **mislabelled** copy of the **[TTT2] Pirate [ROLE]** addon (Steam ID 1737101500). The actual "[TTT] Star Wars - The Force" addon (Steam ID 635911320) is a **vanilla TTT weapon addon** (buyable lightsaber for Traitors/Detectives) that adds no custom roles and is **incompatible with TTT2** — no bot support is needed or possible.

---

## 📊 Summary

| Category | Count |
|----------|-------|
| ✅ Fully Supported | ~147 roles (including sub-roles, gang variants, batch 4 community roles, all 11 batch 5 promotions, and batch 6 Astronaut) |
| ⚠️ Partially Supported | 0 roles |
| ❌ No Support | 1 role (Unknown stub only) |

> **Key insight:** The bots mod now covers all major community workshop roles in the collection. Batch 4 added full AI support for 22 previously-unsupported community roles spanning all teams. **Batch 5** promoted all 11 previously-partial roles to full support. **Batch 6** added full Astronaut support (`AstronautMeeting` behavior — holds primary fire on unused corpses to call community vote meetings) and clarified the "Star Wars: The Force" entry: the local folder `star_wars_the_force_1737101500` is a mislabelled copy of the Pirate role (already supported), and the actual "Star Wars: The Force" addon is a vanilla TTT weapon (no roles, incompatible with TTT2). The **⚠️ Partially Supported** category remains empty. The only remaining unsupported entry is the `unknown` stub role.
