# Traitor Plans & Weapon Shop Analysis

## Table of Contents
1. [Overview](#overview)
2. [Plan System Architecture](#plan-system-architecture)
3. [Available Traitor Shop Weapons](#available-traitor-shop-weapons)
4. [Plan Presets & How Weapons Fit](#plan-presets--how-weapons-fit)
5. [Buying System Mechanics](#buying-system-mechanics)
6. [Weapon ↔ Plan Synergies](#weapon--plan-synergies)
7. [Gaps & Improvement Opportunities](#gaps--improvement-opportunities)

---

## Overview

The TTT2-Bots-2 traitor gameplay loop has three integrated systems:

| System | File(s) | Purpose |
|--------|---------|---------|
| **Plan Coordinator** | `sv_planpresets.lua`, `followplan.lua` | Assigns strategic jobs (GATHER, ATTACK, COORD_ATTACK, PLANT, FOLLOW, ROAM, DEFEND) to traitor bots |
| **Buyables** | `sv_buyables.lua`, `sv_default_buyables.lua` | Manages credit-based weapon/item purchases at round start and mid-round (deferred) |
| **Inventory/Combat** | `sv_inventory.lua`, `sv_morality.lua` | Weapon scoring, auto-switching, targeting, and phase-aware aggression |

The bot's round lifecycle as a traitor:
1. **Round Start** → Buy equipment from shop (credit-based, personality-gated)
2. **Plan Selection** → Coordinator picks a plan preset based on player count, traitor count, and conditions
3. **Job Execution** → Each bot gets a job (GATHER → ATTACK, PLANT, COORD_ATTACK, etc.)
4. **Opportunistic Combat** → Phase-aware morality system triggers fights when conditions favor the traitor
5. **Deferred Buys** → Mid-round reactive purchases (ally dies → buy defib, low ammo → buy M16/MAC10)

---

## Plan System Architecture

### Plan Actions
| Action | Description | Weapon Relevance |
|--------|-------------|------------------|
| `GATHER` | Traitors converge in an unpopular area before striking | Gathering phase = time to activate buffs (Smart Bullets) |
| `ATTACKANY` | Solo attack on nearest/isolated enemy | All combat weapons used |
| `ATTACK` | Targeted attack on a specific enemy | All combat weapons used |
| `COORD_ATTACK` | Staged group attack — traitors converge, then strike simultaneously | High-value weapons (Minigun, Smart Pistol) shine here |
| `PLANT` | Plant C4 in a strategic location | Requires `weapon_ttt_c4` |
| `FOLLOW` | Shadow a target (police or human traitor) | Stealth weapons (Poison Dart, silenced guns) preferred |
| `ROAM` | Wander toward an area (corpses, unpopular zones) | Revival weapons (Defib, Role Defib) used |
| `DEFEND` | Hold a position | Turret, mines, C4 excel here |

### Plan Target Types
| Target | Used By | Description |
|--------|---------|-------------|
| `NEAREST_ENEMY` | ATTACKANY | Closest non-ally |
| `SHARED_ISOLATED_ENEMY` | COORD_ATTACK, ATTACK | Same isolated target for all traitors |
| `SHARED_ENEMY` | COORD_ATTACK | Same non-isolated target |
| `RAND_POLICE` | FOLLOW, COORD_ATTACK | Random detective/police player |
| `RAND_UNPOPULAR_AREA` | GATHER, ROAM | Low-traffic nav area |
| `ANY_BOMBSPOT` | PLANT | Registered bomb-plantable spot |
| `NEAREST_CORPSE_AREA` | ROAM | Area near player corpses (for revival) |
| `RAND_FRIENDLY_HUMAN` | FOLLOW | Human traitor team member |

---

## Available Traitor Shop Weapons

### Core Combat Weapons (Traitor-Team)

| Weapon | Class | Price | Priority | Trait Gate | Personality Archetype | Bot Behavior Support |
|--------|-------|-------|----------|------------|----------------------|---------------------|
| **C4** | `weapon_ttt_c4` | 1 | 3 | `planter` (1/6) | Bomber/Camper | ✅ Full (`PlantBomb` behavior, arm logic) |
| **Jihad Bomb** | `weapon_ttt_jihad_bomb` | 0 | 4 | `jihad` (1/6) | Bomber | ⚠️ Partial (bought, basic use) |
| **Smart Pistol** | `ttt_smart_pistol` | 1 | 4 | `gimmick`/`aggressive`/CQB | Tryhard/Hothead | ✅ Full (custom scoring: +12 base, +14 ≤900u) |
| **Minigun** | `m9k_minigun` | 1 | 4 | `heavy`/`aggressive`/`hothead` | Heavy | ✅ Full (custom scoring: +10 base, +18 ≤800u) |
| **Poison Dart Gun** | `weapon_ttt2_poison_dart` | 1 | 4 | `disguiser`/`cautious`/`strategic` | Stealth | ✅ Full (stealth scoring: +15 out-of-combat) |
| **Smart Bullets** | `weapon_ttt2_smart_bullets` | 1 | 3 | `aggressive`/`gimmick`/`tryhard` | Aggressive | ✅ Full (`ActivateSmartBullets` behavior) |
| **Hologram Decoy** | `weapon_ttt2_hologram_decoy` | 1 | 3 | `gimmick`/`disguiser`/`strategic` | Tactical | ✅ Partial (score = -999 in combat, bought as utility) |
| **EMP Grenade** | `weapon_ttt2_emp_grenade` | 1 | 3 | `grenades`/`strategic` | Grenades | ✅ Full (`UseGrenade` behavior, EMP targeting) |
| **Gravity Mine** | `weapon_ttt2_gravity_mine` | 1 | 4 | `grenades`/`planter`/`aggressive` | Tactical | ✅ Partial (bought, score = -999 in combat auto-switch) |
| **Reveal Grenade** | `weapon_ttt_reveal_nade` | 1 | 3 | `grenades`/`gimmick`/`strategic` | Tactical/Intel | ✅ Bought (situational score based on enemies + corpses) |

### Traitor Utility / Role Items

| Item | Class | Price | Priority | Trait Gate | Purpose |
|------|-------|-------|----------|------------|---------|
| **Body Armor** | `item_ttt_armor` | 1 | 2 | 33% random | Survivability (passive) |
| **Radar** | `item_ttt_radar` | 1 | 3 | Role flag `CanHaveRadar` | Target tracking (passive) |
| **Disguiser** | `item_ttt_disguiser` | 1 | 2 | `disguiser` (1/4) | Identity concealment (passive) |
| **Infinite Ammo** | `item_ttt_infinishoot` | 1 | 3 | `heavy` (1/4) | Unlimited ammunition (passive) |
| **Defibrillator** | `weapon_ttt_defibrillator` | 2 | 4 | `healer` (1/5) | Revive dead players |
| **Role Defib** | `weapon_ttt_defib_traitor` | 1 | 3 | `healer` (1/3) | Revive + convert to traitor team |
| **Medigun** | `weapon_ttt_medigun` | 1 | 3 | `healer` (1/3) | Heal allies |
| **Defector Jihad** | `weapon_ttt_defector_jihad` | 1 | 3 | `defector` (1/4) | Convert innocent to defector role |
| **Cursed Deagle** | `weapon_ttt2_cursed_deagle` | 1 | 5 | `cursed` (1/6) | Special role-swap deagle |
| **Medic Deagle** | `weapon_ttt2_medic_deagle` | 1 | 5 | `medic` (1/6) | Convert target to medic role |

### Troll / Gimmick Weapons (Personality-Gated)

| Weapon | Class | Price | Trait Gate | Notes |
|--------|-------|-------|------------|-------|
| **Orbital Friendship Beam** | `swep_orbitalfriendshipbeam` | 1 | Always | Area denial |
| **Prop Rain** | `weapon_prop_rain` | 1 | `outdoorSWEPs` (1/6) | Outdoor chaos |
| **Artillery Marker** | `weapon_ttt_artillerymarker` | 2 | `outdoorSWEPs` (1/6) | Outdoor strike |
| **Arson Thrower** | `weapon_ttt2_arsonthrower` | 2 | `heavy` (1/3) | Fire weapon |
| **BeeNade** | `weapon_ttt_beenade` | 2 | `grenades` (1/6) | Grenade |
| **Head Launcher** | `weapon_ttt_headlauncher` | 1 | `outdoorSWEPs` (1/6) | Projectile weapon |
| **Killer Snail** | `weapon_ttt_killersnail` | 1 | `troll` (1/4) | Deployable hazard |
| **Mine Thrower** | `weapon_ttt_ttt2_minethrower` | 1 | `grenades` (1/6) | Explosive trap |
| **Holy Hand Grenade** | `weapon_holyhand_grenade` | 1 | `grenades` (1/6) | Large AoE explosive |
| **Dance Gun** | `weapon_ttt_dancegun` | 1 | `troll` (1/6) | Disabler |
| **Snake Gun** | `weapon_snake_gun` | 1 | `troll` (1/4) | Novelty |
| **Banana** | `weapon_ttt_banana` | 1 | `grenades` (1/6) | Grenade-type |
| **Barrel Gun** | `shared` | 1 | `troll` (1/3) | Novelty |
| **Thomas** | `ttt_thomas_swep` | 1 | `troll` (1/2) | Novelty |
| **Weeping Angel** | `ttt_weeping_angel` | 1 | `troll` (1/6) | Deployable |
| **Sience Show** | `wep_ttt_asdf_sience_show` | 1 | `troll` (1/6) | Novelty |
| **TTTE** | `ttte_swep` | 1 | `gimmick` (1/3) | Gimmick |
| **Melon Launcher** | `melonlauncher` | 1 | `gimmick` (1/3) | Projectile |
| **Turret** | `weapon_ttt_turret` | 1 | `planter` (1/5) | Deployable auto-turret |
| **Timestop** | `weapon_ttt_timestop` | 1 | `gimmick` (1/4) | Freeze enemies |
| **Peacekeeper** | `weapon_ttt_peacekeeper` | 1 | `heavy` (1/4) | High Noon homing |

### Deferred (Mid-Round) Buys

| Weapon | Event Trigger | Price | Purpose |
|--------|---------------|-------|---------|
| **C4 (Deferred)** | `round_mid` | 1 | Mid-round bomb if many players alive |
| **M16 (LowAmmo)** | `LOW_AMMO` | 1 | Emergency primary when ammo depleted |
| **MAC-10 (LowAmmo)** | `LOW_AMMO` | 1 | Emergency backup when ammo depleted |
| **Traitor Defib** | `ally_died` | 1 | Reactive revive when traitor ally dies |

---

## Plan Presets & How Weapons Fit

### Standard Plans

| Preset | Player Count | Traitor Count | Key Phases | Best Weapons |
|--------|-------------|---------------|------------|--------------|
| **LowPlayerCount_Standard** | 1-4 | Any | GATHER → ATTACKANY | Smart Pistol, Minigun (DPS), Poison Dart (stealth) |
| **MediumPlayerCount_Standard** | 5-9 | Any | PLANT → GATHER → ATTACKANY | C4, Smart Bullets + any primary, Minigun |
| **AveragePlayerCount_Standard** | 10-16 | Any | PLANT → FOLLOW → GATHER → ATTACKANY | C4, Disguiser, Radar, Smart Pistol, Minigun |

### Coordinated Attack Plans

| Preset | Player Count | Min Traitors | Strategy | Best Weapons |
|--------|-------------|-------------|----------|--------------|
| **LowPlayerCount_WolfPack** | 1-4 | 2 | GATHER → COORD_ATTACK isolated | Smart Bullets (pre-activate during gather), Minigun (suppression) |
| **MediumPlayerCount_HitSquad** | 5-9 | 2 | GATHER → COORD_ATTACK isolated | Smart Pistol (tracking), Gravity Mine (crowd control) |
| **AveragePlayerCount_CoordinatedBlitz** | 10-16 | 3 | PLANT + GATHER → COORD_ATTACK shared | C4 (distraction), Minigun/Smart Pistol (strike team) |
| **MediumPlayerCount_DetectiveHunt** | 5-16 | 2 | GATHER → COORD_ATTACK police → COORD_ATTACK | EMP Grenade (disable detective equipment), concentrated firepower |

### Revival/Conversion Plans

| Preset | Condition | Strategy | Best Weapons |
|--------|-----------|----------|--------------|
| **LowPlayer_RevivalRecovery** | Outnumbered 0.75x, has revive | ATTACK → ROAM corpses → COORD_ATTACK | Role Defib, Defibrillator, knife (silent kills) |
| **MediumPlayer_RevivalRecovery** | Outnumbered 0.6x, has revive | ATTACK → ROAM corpses → COORD_ATTACK | Role Defib, Defibrillator |
| **LargePlayer_RevivalRecovery** | Outnumbered 0.5x, has revive | PLANT + ATTACK → ROAM corpses → COORD_ATTACK | C4 (distraction), Role Defib |
| **ConversionRecovery** | Outnumbered 0.65x, has convert | FOLLOW isolated → ROAM → ATTACKANY | Medic Deagle, Defector Jihad, Cursed Deagle |
| **CorpseHarvest** | Has corpses + revive | ROAM corpses → COORD_ATTACK | Role Defib, Defibrillator |

### Knife-Stalk Plans (200dmg Knife Mod)

| Preset | Player Count | Strategy | Weapon Synergy |
|--------|-------------|----------|---------------|
| **KnifeHunter_LowPlayer** | 1-6 | ROAM → ATTACK isolated → ROAM corpses → chain | 200dmg Crowbar + Role Defib (kill silently, revive as traitor) |
| **KnifeHunter_MediumPlayer** | 5-10 | PLANT + ROAM → ATTACK → ROAM corpses → COORD_ATTACK | C4 (distraction) + knife + Role Defib |
| **KnifeHunter_LargePlayer** | 10-16 | PLANT + FOLLOW police + ROAM → ATTACK → revive → COORD_ATTACK | C4 + Disguiser + knife + Role Defib |

---

## Buying System Mechanics

### Credit Economy
- Traitors typically start with **2 credits**
- Most weapons cost **1 credit**, some cost **2** (Artillery Marker, Arson Thrower, BeeNade, Defibrillator)
- Deferred buys can spend credits mid-round when triggered by events

### Selection Algorithm
1. Filter buyables by role, affordability, trait gates, and `RandomChance`
2. Compute `SituationalScore` (or fallback to `Priority`) per item
3. Apply weight modifiers:
   - `PrimaryWeapon` → +2 weight, ×1.35 if not a deagle
   - Deagles → ×0.45 weight (heavily penalized)
   - Defector Jihad → ×0.35 weight
   - `TTT2` items → +1 weight
   - Score ≥50 → **forced purchase** (used by RoleChecker: score 100, DNA Scanner: score 60)
4. Weighted random selection from remaining candidates
5. Repeat until credits exhausted or no valid options remain

### Personality → Weapon Pipeline
```
Bot Personality Traits ──┐
                         ├──→ CanBuy() gates ──→ SituationalScore() ──→ Weighted Selection
Round Phase/Context ─────┘
```

Key trait-to-weapon mappings:
- `heavy` → Minigun, Arson Thrower, Peacekeeper, Infinite Ammo
- `aggressive` → Smart Pistol, Smart Bullets, Minigun
- `gimmick` → Smart Pistol, Smart Bullets, Hologram Decoy, TTTE, Melon Launcher, Timestop
- `planter` → C4, Turret, Gravity Mine
- `grenades` → EMP Grenade, Gravity Mine, BeeNade, Mine Thrower, Holy Hand Grenade, Banana, Reveal Grenade
- `troll` → Barrel Gun, Killer Snail, Thomas, Dance Gun, Snake Gun, Weeping Angel, Sience Show
- `disguiser` → Disguiser item, Poison Dart Gun, Hologram Decoy
- `cautious`/`strategic` → Poison Dart Gun, EMP Grenade, Hologram Decoy, Reveal Grenade
- `outdoorSWEPs` → Prop Rain, Artillery Marker, Head Launcher, Osc Sym
- `healer` → Defibrillator, Role Defib, Medigun
- `cursed` → Cursed Deagle
- `jihad` → Jihad Bomb
- `defector` → Defector Jihad

---

## Weapon ↔ Plan Synergies

### High-Synergy Combinations

| Plan | Weapon | Synergy Reason |
|------|--------|----------------|
| **CoordinatedBlitz** | C4 + Smart Bullets | C4 distracts innocents; Smart Bullets activated during GATHER phase gives aimbot during COORD_ATTACK |
| **WolfPack** | Minigun | COORD_ATTACK at close range → Minigun's +18 score ≤800u devastates grouped targets |
| **DetectiveHunt** | EMP Grenade | Disable detective's Health Station / equipment before the coordinated strike |
| **RevivalRecovery** | Role Defib + Poison Dart | Poison Dart for silent kills (creates corpses), Role Defib to convert them |
| **KnifeHunter** | 200dmg Knife + Role Defib | Silent melee kill + revive as traitor = snowball |
| **HitSquad** | Smart Pistol + Gravity Mine | Mine pulls targets into Smart Pistol's effective range (≤900u) |
| **Standard (solo)** | Poison Dart + Disguiser | Stealth DOT + identity concealment = maximum deception |
| **CorpseHarvest** | Defibrillator | Immediately roam to existing corpses and revive allies |
| **ConversionRecovery** | Defector Jihad + Medic Deagle | Drop conversion item for innocents OR shoot to convert |

### Phase-Aware Weapon Value

| Round Phase | Best Weapons | Reason |
|-------------|-------------|--------|
| **EARLY** | Poison Dart, Disguiser, Hologram Decoy | Stealth is paramount; traitors avoid starting fights in front of witnesses |
| **MID** | Smart Bullets, Smart Pistol, C4 (deferred) | Aggression scales up; bots begin committing to fights |
| **LATE** | Minigun, Peacekeeper, Gravity Mine | Maximum aggression; no need for subtlety, raw DPS matters |
| **OVERTIME** | Any combat weapon, EMP Grenade | Desperation; every weapon is viable, disable remaining equipment |

### Inventory Auto-Switch Scoring (Combat)

The `ScoreWeaponForContext()` function ranks weapons dynamically during combat:

| Weapon | Base Score Bonus | Range Bonus | Personality Bonus | Special |
|--------|-----------------|-------------|-------------------|---------|
| Smart Pistol | +12 | +14 (≤900u), +7 (≤1200u), -6 (>1200u) | — | Always preferred at medium range |
| Minigun | +10 | +18 (≤800u), +8 (≤1200u), -10 (>1200u) | +8 (heavy/aggressive/hothead) | Dominant CQB/mid weapon |
| Poison Dart | +15 (stealth out-of-combat) | — | — | -5 in direct combat; stealth-only |
| Smart Bullets | -999 | — | — | Utility only, never auto-equipped |
| Hologram Decoy | -999 | — | — | Utility only, never auto-equipped |
| Gravity Mine | -999 | — | — | Utility only, never auto-equipped |
| Silent weapons | +15 | — | Traitor only, out-of-combat | General stealth bonus |

---

## Gaps & Improvement Opportunities

### 1. **No Explicit Weapon ↔ Plan Coupling**
Plans don't check what weapons traitors bought. A COORD_ATTACK plan would benefit from knowing the team has Smart Bullets activated or a Minigun available. Currently the plan coordinator selects presets purely based on player count, traitor count, and role capabilities — not loadout.

**Potential fix:** Add a `RequiresWeaponClass` or `BonusIfTeamHasWeapon` condition to plan presets.

### 2. **Gravity Mine / Hologram Decoy Have No Dedicated Behavior**
Both weapons are bought and scored -999 in auto-switch, meaning they're never used in combat. There's no behavior node to tactically deploy them (e.g., throw Gravity Mine at a chokepoint before COORD_ATTACK, or deploy Hologram Decoy as a distraction during GATHER phase).

**Potential fix:** Create `DeployGravityMine` and `DeployHologramDecoy` behaviors that activate during appropriate plan phases.

### 3. **Turret Has No Placement Behavior**
The `weapon_ttt_turret` is registered as a buyable but there's no behavior to place it strategically (e.g., defend a bomb site, guard a chokepoint, or protect a revive location).

**Potential fix:** Create a `DeployTurret` behavior linked to DEFEND jobs or pre-COORD_ATTACK staging.

### 4. **Reveal Grenade Lacks Tactical Use**
Bought by traitors but acts as a generic grenade in `UseGrenade`. Its actual utility (revealing roles on nearby corpses) isn't leveraged — traitors don't path to corpse clusters to use it strategically.

**Potential fix:** Add a Reveal Grenade-specific branch in `UseGrenade.GetBestThrowReason()` that paths to corpse areas.

### 5. **Timestop/Peacekeeper Have No Activation Behavior**
Both special weapons are bought but rely entirely on auto-switch scoring. Neither has a dedicated behavior like `ActivateSmartBullets` to use them at the optimal moment (e.g., Timestop before a coordinated strike, Peacekeeper when multiple enemies are visible).

### 6. **Smart Bullets Activation Timing**
The `ActivateSmartBullets` behavior correctly waits for a target, but there's no plan-phase awareness. Activating during the GATHER phase (before the COORD_ATTACK strike) would be more effective than waiting until already in combat.

### 7. **Deferred Buy Coverage**
Only three deferred events exist: `round_mid`, `ally_died`, and `LOW_AMMO`. Missing opportunities:
- `enemy_equipment_spotted` → buy EMP Grenade
- `solo_traitor` → buy Radar/Body Armor
- `many_corpses_available` → buy Defibrillator/Role Defib

### 8. **Troll/Gimmick Weapons Are Fire-and-Forget**
Weapons like Thomas, Weeping Angel, Killer Snail, Dance Gun etc. are bought and marked as `PrimaryWeapon = true`, so auto-switch may equip them in combat. But their actual combat effectiveness varies wildly, and the DPS-based scoring in `ScoreWeaponForContext()` may not accurately represent their utility.

### 9. **No Weapon-Based Plan Variant Selection**
If 3 traitors all bought Smart Pistols vs. 3 traitors with C4 + Defib + Minigun, the plan coordinator would select the same preset. Weapon loadout information could influence plan selection (e.g., team with many revival tools → favor RevivalRecovery even if not strictly "outnumbered").

---

## Summary Statistics

| Category | Count |
|----------|-------|
| Total registered traitor buyables | ~40+ |
| Buyables with dedicated bot behaviors | 6 (C4, Smart Bullets, Grenades, Defib, Role Defib, Poison Dart) |
| Buyables with custom combat scoring | 3 (Smart Pistol, Minigun, Poison Dart) |
| Buyables that are utility-only (score -999) | 3 (Smart Bullets SWEP, Hologram Decoy, Gravity Mine) |
| Plan presets total | 16 (3 standard + 4 coordinated + 5 revival + 3 knife) |
| Deferred buy events | 3 (round_mid, ally_died, LOW_AMMO) |
| Personality traits affecting weapon choice | 15+ (heavy, aggressive, gimmick, planter, grenades, troll, etc.) |
