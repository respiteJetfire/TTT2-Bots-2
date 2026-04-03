# TTT2 Bots — Role Support Status

> Last updated: April 2, 2026

---

## ✅ Fully Supported

These roles have their own `.lua` file in `lua/tttbots2/roles/` with full custom behavior trees, role-specific behaviors, and hooks.

### 🔵 Innocent Team

| Role | Notes |
|------|-------|
| **Innocent** | Base innocent tree via `InnocentLike` builder |
| **Detective** | `DetectiveLike` builder with DNA scanner usage and corpse investigation |
| **Deputy** | Full tree with `FollowMaster`; reacts to Sheriff being shot/attacked via hooks |
| **Sheriff** | `DetectiveLike` builder |
| **Sniffer** | `DetectiveLike` builder |
| **Banker** | `DetectiveLike` builder with credit-gain awareness |
| **Vigilante** | `DetectiveLike` builder |
| **Decipherer** | `DetectiveLike` builder with role-checker usage |
| **Doctor** | Custom tree with `Healgun`, defibrillator, allied with innocents |
| **Medic** | Custom tree with `Healgun`; allied with ALL teams (neutral healer) |
| **Occultist** | `InnocentLike` builder |
| **Survivalist** | `InnocentLike` builder |
| **Oracle** | Custom tree with dedicated `Oracle` behavior |
| **Pharaoh** | Full custom tree: `DefendAnkh`, `PlantAnkh`, `CaptureAnkh`, `GuardAnkh`, `RelocateAnkh`, `PostRevival` |
| **Clairvoyant** | Full custom tree: `ClairvoyantIntel`, `ClairvoyantJesterHunt` (conditional), `ClairvoyantWicked` |
| **Spy** | Full custom tree: `SpyBlend`, `SpyReport`, `SpyFakeBuy`, `SpyEavesdrop`, `SpyDeadRinger`; traitor detection timers; personality modifiers; cover-blown hooks |
| **Priest** | Full custom tree with `PriestConvert`; brotherhood trust/evidence syncing; cascade threat awareness; coordination timers |

### 🔴 Traitor Team

| Role | Notes |
|------|-------|
| **Traitor** | Full default traitor tree via `TraitorLike` builder |
| **Hitman** | `TraitorLike` builder |
| **Mesmerist** | Full custom tree with `MesmeristDefib` (revives kills as Thralls) |
| **Brainwasher** | Full custom tree with `Convert` priority, deception blend, and `Slave` ally awareness |
| **Slave** | `TraitorLike` builder |
| **Defector** | Full custom tree: `DefectorApproach` + `Jihad` suicide bomb; deception/blend behaviors; mid-round conversion hook |
| **Wicked** | Full custom tree: `ClairvoyantWicked`, `Jihad`, `PlantBomb`, traitor coordination |
| **Graverobber** | Full custom tree: `CaptureAnkh`, `DestroyAnkh`, `HuntAnkh`, `PostRevival`; spawned when Pharaoh places Ankh |

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
| **Drunk** | Basic neutral tree; registered as `TEAM_DRUNK`; defers to new role after reveal |
| **Cupid** | Full two-phase tree: pre-link (`CreateLovers`) → post-link (`ProtectLover`); helper API for lover queries |
| **Mimic** | Custom tree with `CopyRole` behavior |
| **Undecided** | Basic neutral non-aggressive tree |
| **Revenant** | Team-based killer with `Convert` and `Stalk` |
| **Restless** | Team-based killer with `Convert`, `Stalk`, and life-state knowledge |
| **Gun Dealer** | Full neutral supply tree: `GunDealerDeliver`, consignment manifest; self-defense only; `NeutralOverride` set |
| **Marker** | Jester-team role with `CreateMarker` behavior |
| **Jester** | Jester-team role with suspicion hook (`cheat_know_jester` convar) |
| **Swapper** | Jester-team stalker with suspicion hook (`cheat_know_swapper` convar) |
| **Anonymous** | Traitor-like team role with `Convert`, radar, no suspicion |
| **Pirate** | Full team role: `FollowMaster`; cooperative fire hooks with captain; contract-based team allegiance switching |
| **Pirate Captain** | Full team role: `Convert`, `FollowMaster`; cooperative hooks with pirates; contract-based team switching |

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
| **Hitman** | `TraitorLike` | No contract or priority-target logic; plays as a generic traitor |
| **Slave** | `TraitorLike` | No brainwash-specific obedience; plays as a generic traitor |
| **Drunk** | Custom tree | Generic neutral tree; bot ignores the timed role-reveal mechanic entirely |
| **Mimic** | Custom tree | `CopyRole` behavior exists but mid-round role copy mechanics may be unreliable |

---

## ❌ No Support

These roles exist in the installed TTT2 Roles collection but have **no corresponding file** in `lua/tttbots2/roles/`. Bots assigned to these roles will receive no role-specific AI and may fall back to a broken default state.

### Community Workshop Roles

| Role | Notes |
|------|-------|
| **Accomplice** | No support |
| **Ajin** | No support |
| **Alien** | No support |
| **Ambusher** | No support |
| **Announcer** | No support |
| **Arsonist** | No fire/arson logic |
| **Baker / Famine** | No support |
| **Beacon** | No support |
| **Beggar** | No support |
| **Blight** | No support |
| **Blocker** | No support |
| **Chef** | No support |
| **Collusionist** | No support |
| **Cult Leader / Cultists** | No support |
| **Cyclone / Hurricane** | No support |
| **Defective** | No support |
| **Duelist** | No duel acceptance or challenge logic |
| **Dunce** | No support |
| **Elderly** | No support |
| **Executioner** | No target/bounty logic |
| **Fuse** | No support |
| **Gambler** | No support |
| **Glutton** | No support |
| **Guardian** | No support |
| **Hanfei** | No support |
| **Haunted** | No support |
| **Heretic** | No support |
| **Hunch** | No support |
| **Hunters** | No support |
| **Impostor** | No support |
| **Janitor** | No support |
| **Kobold Hoarder** | No support |
| **Leech** | No support |
| **Link** | No support |
| **Loot Goblin** | No support |
| **Lunk** | No support |
| **Lycanthrope** | No support |
| **Master Chief** | No support |
| **Mayor** | No support |
| **Morphling** | No support |
| **Mutant** | No support |
| **Mute** | No support |
| **Necrohealiac** | No support |
| **Nova** | No support |
| **Paranoid** | No support |
| **Patient** | No support |
| **Poisoner** | No support |
| **Psycho** | No support |
| **Pure** | No support |
| **Rat** | No support |
| **Revolutionary** | No support |
| **Roider** | No support |
| **Sacrifice** | No support |
| **Seance** | No support |
| **Shanker** | No support |
| **Shinigami** | No support |
| **Sleeper** | No support |
| **Spectre** | No support |
| **Speedrunner** | No support |
| **Streamer / Simps** | No support |
| **Suicide Barrel** | No support |
| **Suicide Grunt** | No support |
| **Sus** | No support |
| **The Flood** | No support |
| **Thief** | No support |
| **Trapper** | No support |
| **Undercover Agent** | No support |
| **Unknown** | Stub file only — no meaningful behavior |
| **Vampire** | No support |
| **Vulture** | No support |
| **Warrior Priest** | No support |
| **Wrath** | No support |
| **Yandere / Senpai** | No support |
| **Astronaut** | No support |
| **Star Wars: The Force** | No support |

---

## 📊 Summary

| Category | Count |
|----------|-------|
| ✅ Fully Supported | ~46 roles (including sub-roles and gang variants) |
| ⚠️ Partially Supported | ~11 roles |
| ❌ No Support | ~62 roles |

> **Key insight:** The bots mod has deep integration for the core TTT2 roles, all roles from the major bundled role packs (Jackal, Spy, Infected, Necromancer, Serial Killer, Hidden, Doomguy, Pharaoh/Graverobber, Cupid, Priest), and niche roles the mod developer has added themselves. The vast majority of community workshop roles in the collection have no bot AI whatsoever and are prime candidates for new role integrations.
