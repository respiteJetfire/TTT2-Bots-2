# Necromancer Role — TTT2 Bots Integration Analysis

> **Date:** 2026-03-09  
> **Scope:** Full analysis of the `ttt2-role_necro` addon, existing TTT2-Bots-2 necromancer support, bugs, gaps, and implementation strategies for deep bot integration.

---

## Table of Contents

1. [Necromancer Role Mechanics Summary](#1-necromancer-role-mechanics-summary)
2. [Current Bot Implementation Status](#2-current-bot-implementation-status)
3. [Bug Report](#3-bug-report)
4. [Gap Analysis](#4-gap-analysis)
5. [Implementation Strategy](#5-implementation-strategy)
6. [Checklist](#6-checklist)
7. [File Map](#7-file-map)

---

## 1. Necromancer Role Mechanics Summary

### 1.1 Necromancer (the master)

| Property | Value |
|---|---|
| **Team** | `TEAM_NECROMANCER` (custom team, initialized via `roles.InitCustomTeam`) |
| **Base Role** | Self (top-level role) |
| **Omniscient** | `true` — knows all allies, can see teammate roles |
| **Marker Vision** | Sees all corpses through walls (via `TTT2RenderMarkerVisionInfo`) |
| **Loadout Weapon** | `weapon_ttth_necrodefi` (Necro Defi — a modified defibrillator) |
| **Shop** | Traitor shop fallback (`SHOP_FALLBACK_TRAITOR`), starts with 2 credits |
| **Win Condition** | Team Necromancer must outlast all other teams |
| **Conflict** | Mutually exclusive with Jackal (random pick via `TTT2ModifySelectableRoles`) |
| **Min Players** | 7 |

### 1.2 Zombie (the minion)

| Property | Value |
|---|---|
| **Team** | `TEAM_NECROMANCER` |
| **Base Role** | `ROLE_NECROMANCER` (set via `roles.SetBaseRole`) |
| **Not Selectable** | `true` — can only be created by necromancer defib |
| **Omniscient** | `true` |
| **Weapon Restriction** | Can ONLY carry `weapon_ttth_zombpistol` (zombie deagle). All other weapons are blocked by `PlayerCanPickupWeapon` hook |
| **Movement** | Walk speed multiplier default `0.5` (configurable `ttt2_zomb_walkspeed`) |
| **Player Model** | Forced to `models/player/corpse1.mdl` or `models/player/skeleton.mdl` |
| **Idle Sounds** | Plays random zombie idle sounds (`npc/zombie/zombie_voice_idle*.wav`) on a 5–25s timer |
| **Death Mechanic** | Zombie deagle has finite ammo (7 rounds, no reserve). When clip is empty, **the zombie kills itself** (`self:GetOwner():TakeDamage(99999)`). Dropping the weapon also kills the zombie |
| **Credits** | Cannot find credits (`preventFindCredits = true`) |

### 1.3 Necro Defibrillator (`weapon_ttth_necrodefi`)

| Property | Value |
|---|---|
| **Base** | `weapon_ttt_defibrillator` (inherits TTT2 defib mechanics) |
| **Clip** | 3 uses (configurable clip) |
| **Not Buyable/Droppable** | Given on role assignment, removed on death/change. Dropping it removes it |
| **Revive Time** | 3.0s (configurable `ttt_necro_defibrillator_revive_time`) |
| **Success Chance** | 100% by default |
| **Revival Health** | 75 HP / 75 max HP |
| **On Revive** | Calls `AddZombie(ply, owner)` — sets victim to `ROLE_ZOMBIE` on necro's team |
| **Restriction** | Cannot revive already-dead zombies (by default, configurable) |

### 1.4 Zombie Deagle (`weapon_ttth_zombpistol`)

| Property | Value |
|---|---|
| **Damage** | 37 per shot, 4x headshot multiplier (148 headshot) |
| **Clip/Ammo** | 7 rounds, ammo type `"none"`, no reserve ammo |
| **Fire Rate** | 0.6s delay, automatic |
| **Self-Destruct** | Empty clip → `TakeDamage(99999)` kills the zombie. Drop → instant death |
| **Cannot be dropped** | `AllowDrop = false`, but OnDrop also kills owner |

---

## 2. Current Bot Implementation Status

### 2.1 What Exists

**File:** `lua/tttbots2/roles/necromancer.lua` (33 lines)

The current implementation is a **bare-minimum RoleData registration**:

```
✅ RoleData registered as "necromancer" on TEAM_NECROMANCER
✅ Allied with TEAM_NECROMANCER and TEAM_JESTER
✅ SetStartsFights(true) — will initiate combat
✅ SetCanHaveRadar(true) — can simulate radar knowledge
✅ SetCanCoordinate(true) — can coordinate with allies
✅ SetUsesSuspicion(false) — omniscient, no need for suspicion
✅ SetKnowsLifeStates(true) — knows who is alive/dead
✅ SetLovesTeammates(true) — won't attack TEAM_NECROMANCER members
```

**Behavior Tree:**
```lua
local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Support,      -- Contains Defib, Healgun, Roledefib
    _prior.Requests,
    _prior.Restore,
    _bh.Stalk,
    _prior.Patrol
}
```

### 2.2 What's Missing

| Component | Status | Impact |
|---|---|---|
| **Zombie RoleData** | ❌ Not registered | Bot zombies fall back to "innocent" behavior tree — they investigate, defuse C4, act innocent |
| **NecroDefib behavior** | ❌ Missing | Necro bot cannot use its `weapon_ttth_necrodefi`. The existing `Defib` behavior only checks for `weapon_ttt_defibrillator` and `weapon_ttt2_medic_defibrillator` |
| **Zombie combat behavior** | ❌ Missing | No weapon-restriction-aware combat for zombie deagle |
| **Zombie self-destruct awareness** | ❌ Missing | Bot doesn't know it dies when ammo runs out |
| **Zombie ammo conservation** | ❌ Missing | No logic to conserve ammo or engage only when needed |
| **NecroCoordinator** | ❌ Missing | No swarm coordination like `sv_infectedcoordinator.lua` |
| **Corpse prioritization** | ❌ Missing | No strategic corpse targeting (isolated corpses, safe revive spots) |
| **Chatter events** | ❌ Missing | No necromancer/zombie-specific chat events |
| **Locale lines** | ❌ Missing | No localized chat strings for necromancer behaviors |
| **LLM role description** | ❌ Missing | `SetRoleDescription()` never called |
| **Dynamic tree switching** | ❌ Missing | No necro→zombie tree switching (like infected's host→zombie pattern) |

---

## 3. Bug Report

### BUG-1: Necro Defi Not Recognized by Any Defib Behavior

**Severity:** 🔴 Critical  
**Location:** `behaviors/defib.lua`, `behaviors/defibplayer.lua`, `behaviors/roledefib.lua`

All three defib behaviors have hardcoded weapon class lists:
- `Defib.WeaponClasses = { "weapon_ttt_defibrillator", "weapon_ttt2_medic_defibrillator" }`
- `Roledefib.WeaponClasses = { "weapon_ttt_defib_traitor", "weapon_ttt_mesdefi", "weapon_ttt2_markerdefi" }`

**`weapon_ttth_necrodefi` is in none of these lists.** Even though the necro's behavior tree includes `_prior.Support` (which contains `_bh.Defib`), the `Defib.HasDefib()` check always returns false for necromancers.

**Result:** Necromancer bots never attempt to revive anyone. Their primary gameplay mechanic is completely non-functional.

### BUG-2: Zombie Bot Has No RoleData — Falls Back to Innocent

**Severity:** 🔴 Critical  
**Location:** `lua/tttbots2/roles/` (no `zombie.lua` exists)

When a player is revived as a zombie, `GetRoleFor()` returns the "innocent" default RoleData because no "zombie" role is registered. This means:
- Zombie bot uses the innocent behavior tree (investigates corpses, defuses C4, groups up)
- Zombie bot uses suspicion system it shouldn't need
- Zombie bot doesn't know who its allies are
- Zombie bot may attack its necromancer master

The auto-registration in `GenerateRegisterForRole()` partially mitigates this:
- It detects `baserole = ROLE_NECROMANCER` and copies the necromancer's RoleData
- But the copied tree still has `Stalk` and `Support` — behaviors the zombie cannot meaningfully use
- It won't have zombie-specific behaviors (melee-only, ammo conservation, protect master)

### BUG-3: Defib.FullDefib Bypasses Necro's Custom Revive Logic

**Severity:** 🟡 Medium  
**Location:** `behaviors/defib.lua:Defib.FullDefib()`

If the necro's defi were somehow recognized, `Defib.FullDefib()` calls `target:Revive(...)` directly — it does NOT call the weapon's `OnRevive` callback. The necro defi's `OnRevive` calls `AddZombie(ply, owner)` which:
1. Sets the role to `ROLE_ZOMBIE`
2. Assigns the necro team
3. Starts zombie idle sounds
4. Sets `zombieMaster` reference
5. Triggers `EVENT_NECRO_REVIVE`

**Result:** Even if we just add `weapon_ttth_necrodefi` to the weapon class list, the revived player would NOT become a zombie — they'd just be revived as their original role.

### BUG-4: Necromancer RoleData Missing `SetRoleDescription()`

**Severity:** 🟢 Low (quality)  
**Location:** `roles/necromancer.lua`

The LLM prompt system reads `GetRoleDescription()` to inform the AI about the bot's role. Without it, necromancer bots get the placeholder text: *"No description available. Say that Callum needs to add a description for this role."*

### BUG-5: Necromancer BTree Has No Corpse-Seeking Behavior

**Severity:** 🟡 Medium  
**Location:** `roles/necromancer.lua` — behavior tree

The necromancer's tree includes `_prior.Support` which contains `_bh.Defib`, `_bh.Healgun`, and `_bh.Roledefib`. Even if defib worked, these are generic support behaviors that:
- Filter corpses by ally status (`allyOnly = true`) — but dead players aren't allies yet
- Don't prioritize isolated corpses for stealthy revives
- Don't account for the strategic value of reviving (e.g., reviving a player with good equipment)

### BUG-6: Zombie Weapon Restriction Not Handled by Bot Inventory

**Severity:** 🟡 Medium  
**Location:** `components/sv_inventory.lua` (auto-switch system)

The zombie can only carry `weapon_ttth_zombpistol`. The bot's inventory auto-switch system doesn't know about this restriction and may try to switch to other weapons or buy items.

---

## 4. Gap Analysis

### 4.1 Behavior Gaps

| Gap | Priority | Comparable Implementation |
|---|---|---|
| **NecroDefib behavior** — Dedicated behavior to use `weapon_ttth_necrodefi` on corpses with proper `AddZombie()` integration | P0 | `behaviors/defib.lua` (structure), but needs custom revive logic |
| **ZombieAttack behavior** — Weapon-aware combat for zombie deagle with ammo tracking | P0 | `behaviors/infectedrush.lua` (pattern), but ranged not melee |
| **ZombieProtectMaster behavior** — Stay near and protect the necromancer | P1 | `behaviors/protecthost.lua` (exact pattern, rename host→master) |
| **ZombieAmmoAwareness** — Track remaining ammo, become more aggressive as ammo depletes | P1 | New concept — integrate into ZombieAttack |
| **NecroCorpseHunt** — Actively seek corpses using marker vision data | P2 | New concept — corpse-seeking beyond defib range |

### 4.2 Coordination Gaps

| Gap | Priority | Comparable Implementation |
|---|---|---|
| **NecroCoordinator** — Swarm coordination, target assignment, zombie rallying | P1 | `lib/sv_infectedcoordinator.lua` (exact pattern) |
| **Master-Zombie communication** — Necro directs zombies to attack specific targets | P2 | Infected swarm target system |
| **Zombie count tracking** — Necro adjusts strategy based on active zombie count | P2 | `InfectedCoordinator._lastZombieCounts` |

### 4.3 Chatter/Comms Gaps

| Gap | Priority |
|---|---|
| **NecroRevivingZombie** — "I'm raising the dead..." / "Rise, my minion!" | P1 |
| **ZombieRisen** — "Braaains..." / "I serve the master" | P1 |
| **NecroVictory** — Team necromancer won gloating | P2 |
| **ZombieSpotted** — Other bots react to seeing zombie player model | P2 |
| **NecroMasterDied** — Zombie reacts to master's death | P2 |
| **ZombieAmmoLow** — "Running out of ammo... getting desperate" | P2 |
| **ZombieSelfDestruct** — Last words before ammo-death | P3 |
| **NecroTeamChat** — Necro team-only strategy talk ("Go get them", "Protect me") | P2 |

### 4.4 Strategic Intelligence Gaps

| Gap | Priority |
|---|---|
| **Corpse memory** — Track known corpse locations from marker vision | P1 |
| **Safe revive assessment** — Check for witnesses before reviving | P1 |
| **Ammo economy** — Zombie deagle has 7 shots. Bot needs to pick fights wisely | P1 |
| **Flee vs fight** — Zombie with 1-2 bullets should try to melee or flee | P2 |
| **Multi-zombie flanking** — Coordinate multiple zombies to attack from different angles | P3 |
| **Phase-aware aggression** — Necro becomes more aggressive about reviving in late game | P2 |

---

## 5. Implementation Strategy

### Phase 1: Core Functionality (P0) — Make It Work

#### 5.1 Register Zombie RoleData (`roles/zombie.lua`)

Create a new file following the infected zombie pattern:

```
- Register "zombie" as RoleData on TEAM_NECROMANCER
- SetStartsFights(true)
- SetUsesSuspicion(false)
- SetKnowsLifeStates(true)
- SetLovesTeammates(true)
- SetAutoSwitch(false) — prevent switching away from zombie deagle
- SetPreferredWeapon("weapon_ttth_zombpistol")
- SetKOSedByAll(true) — zombie model is visible, everyone knows they're hostile
- SetKOSAll(true) — zombies attack all non-allies
- Custom bTree with ZombieAttack, ProtectMaster, FightBack, Patrol
- SetRoleDescription with thematic description
```

**Pattern:** Mirror `roles/infected.lua` for the zombie portion, but adapted for ranged combat.

#### 5.2 Create NecroDefib Behavior (`behaviors/necrodefib.lua`)

A dedicated defib behavior specifically for `weapon_ttth_necrodefi`:

```
- WeaponClasses = { "weapon_ttth_necrodefi" }
- Override target finding: use GetClosestRevivable(bot, false, ...) — revive ANY dead player (not ally-only)
- Override revive logic: Do NOT call target:Revive(). Instead, simulate the weapon's use
  by getting close to the corpse, equipping the necro defi, and holding attack
  (the weapon base class handles the revive timer + AddZombie callback)
- Use ACTUAL weapon interaction: equip weapon → look at corpse → hold +attack
  The weapon_ttt_defibrillator base handles the rest via its think/attack hooks
- Witness check: prefer reviving when no non-allies are watching
- Timeout: fail after 45s like existing defib behaviors
- Chatter: fire "NecroRevivingZombie" event on start
```

**Key insight:** Unlike the standard `Defib` behavior which calls `target:Revive()` directly, we should let the weapon handle revive logic naturally by equipping it and holding +attack near the corpse. This ensures `OnRevive` → `AddZombie()` fires correctly.

Alternatively, replicate the revive call chain:
1. Get close to corpse ragdoll
2. Equip `weapon_ttth_necrodefi`
3. Call `bot:GetActiveWeapon():PrimaryAttack()` or use the loco attack system
4. The base defibrillator handles the rest

#### 5.3 Create ZombieAttack Behavior (`behaviors/zombieattack.lua`)

Ranged combat behavior tailored for the zombie deagle:

```
- Find closest non-allied target
- Track remaining ammo via weapon:Clip1()
- Engage at medium range (zombie deagle is accurate, 37 dmg, 0.02 cone)
- Ammo conservation: don't spray, aim for headshots
- When ammo ≤ 2, become desperate — rush closest target
- When ammo = 0, the weapon auto-kills (handled by weapon code)
- Fire "ZombieAmmoLow" chatter when clip ≤ 2
```

#### 5.4 Update Necromancer RoleData

```
- Add SetRoleDescription() with thematic text
- Restructure bTree to include NecroDefib as highest priority after FightBack
- Remove _prior.Support (contains wrong defib behaviors)
```

#### 5.5 Dynamic Tree Switching

Follow the infected role's pattern — override `GetTreeFor()` to return different trees for necromancer vs zombie:

```
Necromancer tree:
  Chatter → FightBack → NecroDefib → Requests → Restore → Stalk → Patrol

Zombie tree:
  FightBack → ZombieAttack → ProtectMaster → Patrol
```

### Phase 2: Coordination & Intelligence (P1)

#### 5.6 Create NecroCoordinator (`lib/sv_necrocoordinator.lua`)

Mirror `sv_infectedcoordinator.lua`:

```
- Detect mid-round zombie creation via TTT2UpdateSubrole hook
- Track necromancer → zombie relationships (zombieMaster field)
- Assign swarm targets: closest non-ally to necromancer
- Detect necromancer death → fire "NecroMasterDied" event
- Detect zombie death → update zombie count
- Publish events: ZOMBIE_CREATED, NECRO_DIED, ZOMBIE_DIED
```

#### 5.7 Create ZombieProtectMaster Behavior

Adapt `protecthost.lua`:

```
- Check bot.zombieMaster or detect master via team analysis
- Stay within 600 units of master
- Return to master when straying beyond MAX_DISTANCE
- Only activate when no enemies are in immediate range
```

#### 5.8 Safe Revive Assessment

Enhance NecroDefib with witness checking:

```
- Before committing to revive, check for non-allied witnesses
- Prefer corpses in isolated locations
- Factor in current round phase (more aggressive in late game)
- Use lib.GetAllWitnessesBasic() for witness detection
```

### Phase 3: Chatter & Immersion (P2)

#### 5.9 Register Chatter Events

Add to `sv_chatter_events.lua` chancesOf100:

```lua
NecroRevivingZombie = 85,
ZombieRisen = 75,
NecroVictory = 80,
NecroMasterDied = 90,
ZombieAmmoLow = 70,
ZombieSelfDestruct = 95,
NecroTeamRally = 65,
NecroTeamStrategy = 60,
```

#### 5.10 Add Locale Lines (`locale/en/sh_chats.lua`)

```lua
RegisterCategory("NecroRevivingZombie", P.IMPORTANT, "Necromancer is raising a dead player as a zombie")
-- Lines for Default, Casual, Nice, Stoic, Hothead, Bad, Teamer, Tryhard, Sus, Dumb

RegisterCategory("ZombieRisen", P.IMPORTANT, "A bot has just been raised as a zombie")
-- Zombie-themed lines: "Braaains...", "I... serve...", "The dead walk!"

RegisterCategory("ZombieAmmoLow", P.MODERATE, "Zombie bot is running low on ammo")
-- "Only {{ammo}} bullets left...", "Running dry..."

RegisterCategory("NecroMasterDied", P.IMPORTANT, "Zombie's necromancer master has died")
-- "Master? MASTER?!", "I'm on my own now..."

RegisterCategory("NecroTeamRally", P.MODERATE, "Necromancer rallying zombies (team chat)")
-- "Attack {{player}}!", "Go get them, my minions!"

RegisterCategory("NecroVictory", P.IMPORTANT, "Team Necromancer won")
-- "The dead have risen!", "Death comes for all!"
```

#### 5.11 Add LLM Prompt Context

Update prompt builders to include necromancer-specific context:
- Role description for necromancer and zombie
- Knowledge that zombies die when ammo runs out
- Zombie's limited vocabulary / groaning speech patterns
- Necromancer's commanding, dark tone

### Phase 4: Polish & Advanced (P3)

#### 5.12 Multi-Zombie Flanking

When 2+ zombies exist, coordinate approach vectors:
- Assign zombies to approach from different nav mesh directions
- One zombie engages, others flank

#### 5.13 Corpse Memory Integration

Track corpse locations from marker vision events:
- Store corpse positions as they're created
- Remove from list when revived or investigated
- Necro prioritizes closest accessible corpse

#### 5.14 Economy Awareness

Necro can buy from traitor shop — teach bot to buy useful equipment:
- Radar for finding isolated targets
- Body armor for surviving longer
- Additional weapons for self-defense

---

## 6. Checklist

### Phase 1: Core Functionality (P0)

- [ ] **TASK-1:** Create `roles/zombie.lua` — Register zombie RoleData with correct team, flags, weapon restriction, and dedicated behavior tree
- [ ] **TASK-2:** Create `behaviors/necrodefib.lua` — Dedicated behavior for `weapon_ttth_necrodefi` that properly triggers the weapon's revive mechanics and `AddZombie()` callback
- [ ] **TASK-3:** Create `behaviors/zombieattack.lua` — Ranged combat behavior for zombie deagle with ammo tracking and self-destruct awareness
- [ ] **TASK-4:** Update `roles/necromancer.lua` — Add `SetRoleDescription()`, restructure bTree to use NecroDefib instead of generic Support, add dynamic tree switching for necro vs zombie
- [ ] **TASK-5:** Add `weapon_ttth_zombpistol` ammo awareness — Bot tracks `Clip1()` and adjusts aggression level based on remaining ammo
- [ ] **TASK-6:** Test necromancer bot can find corpses, navigate to them, use necro defi, and successfully create zombies
- [ ] **TASK-7:** Test zombie bot uses only zombie deagle, attacks non-allies, and doesn't try to pick up other weapons or investigate corpses

### Phase 2: Coordination & Intelligence (P1)

- [ ] **TASK-8:** Create `lib/sv_necrocoordinator.lua` — Swarm coordination, zombie tracking, target assignment, death detection (mirror `sv_infectedcoordinator.lua`)
- [ ] **TASK-9:** Create `behaviors/zombieprotectmaster.lua` — Zombie stays near necromancer master, returns when strayed too far (adapt `protecthost.lua`)
- [ ] **TASK-10:** Add witness-aware reviving to NecroDefib — Check for non-allied observers before committing to revive, prefer isolated corpses
- [ ] **TASK-11:** Add round-phase awareness — Necro becomes more aggressive about reviving in LATE/OVERTIME phases, less cautious about witnesses
- [ ] **TASK-12:** Handle necromancer death gracefully — Zombies switch to aggressive solo behavior when master dies
- [ ] **TASK-13:** Handle zombie death — Remove from coordinator tracking, update zombie count, necro reacts

### Phase 3: Chatter & Immersion (P2)

- [ ] **TASK-14:** Register necromancer chatter events in `sv_chatter_events.lua` — `NecroRevivingZombie`, `ZombieRisen`, `NecroVictory`, `NecroMasterDied`, `ZombieAmmoLow`, `NecroTeamRally`
- [ ] **TASK-15:** Add locale lines in `locale/en/sh_chats.lua` — Full archetype coverage (Default, Casual, Nice, Stoic, Hothead, Bad, Teamer, Tryhard, Sus, Dumb) for all necro events
- [ ] **TASK-16:** Add `SetRoleDescription()` for zombie RoleData with thematic description
- [ ] **TASK-17:** Add zombie-themed speech patterns — Zombies use broken/groaning speech in LLM prompts, limited vocabulary
- [ ] **TASK-18:** Add team-only necro strategy chat — Necromancer directs zombies in team chat ("Attack {{player}}", "Protect me", "Regroup")
- [ ] **TASK-19:** Add `NecroVictory` hook — Fire chatter event when TEAM_NECROMANCER wins the round
- [ ] **TASK-20:** Wire up `ZombieSpotted` — Other bots react when seeing zombie player model (like `ZombieSpotted` for infected)

### Phase 4: Polish & Advanced (P3)

- [ ] **TASK-21:** Multi-zombie flanking — Coordinate approach vectors when 2+ zombies target the same enemy
- [ ] **TASK-22:** Corpse memory integration — Necro tracks known corpse locations, prioritizes nearest accessible
- [ ] **TASK-23:** Economy awareness — Teach necro bot to buy useful shop items (radar, armor)
- [ ] **TASK-24:** Zombie walk speed handling — Ensure bot locomotor respects the `ttt2_zomb_walkspeed` multiplier for pathfinding timing
- [ ] **TASK-25:** Add necromancer to the `TTTBots.Roles.ValidateAllRoles()` cross-reference report to verify alliance symmetry
- [ ] **TASK-26:** Edge case: Handle re-revive scenario — If `ttt_necro_defibrillator_revive_zombies` is enabled, zombie corpses become valid targets again

---

## 7. File Map

### New Files to Create

| File | Purpose |
|---|---|
| `lua/tttbots2/roles/zombie.lua` | Zombie RoleData + dynamic tree |
| `lua/tttbots2/behaviors/necrodefib.lua` | NecroDefib behavior (corpse → zombie conversion) |
| `lua/tttbots2/behaviors/zombieattack.lua` | Zombie deagle combat with ammo awareness |
| `lua/tttbots2/behaviors/zombieprotectmaster.lua` | Zombie escorts/protects necromancer |
| `lua/tttbots2/lib/sv_necrocoordinator.lua` | Swarm coordination + event publishing |

### Existing Files to Modify

| File | Changes |
|---|---|
| `lua/tttbots2/roles/necromancer.lua` | Add `SetRoleDescription()`, restructure bTree, add dynamic tree switching (GetTreeFor override), add helper functions (`IsNecroZombie`, `IsNecroMaster`, `GetNecroMaster`) |
| `lua/tttbots2/components/chatter/sv_chatter_events.lua` | Add necro/zombie event probabilities + hooks (TTT2UpdateSubrole for zombie creation, PlayerDeath for necro death, TTTEndRound for NecroVictory) |
| `lua/tttbots2/locale/en/sh_chats.lua` | Add locale line categories + archetype lines for all necro events |

### Reference Files (patterns to follow)

| File | Pattern Used For |
|---|---|
| `roles/infected.lua` | Dynamic tree switching, host vs zombie detection, helper functions |
| `lib/sv_infectedcoordinator.lua` | Swarm coordination, death detection, event publishing |
| `behaviors/infectedrush.lua` | Aggressive target-seeking behavior |
| `behaviors/protecthost.lua` | Escort/protect behavior |
| `behaviors/defib.lua` | Corpse finding, revive mechanics, weapon interaction |
| `behaviors/meta_roleweapon.lua` | If we want to use the RegisterRoleWeapon factory for zombie deagle |

---

## Appendix A: Key Architectural Decisions

### A.1: Weapon Interaction Strategy for NecroDefib

**Option A: Simulate weapon use via locomotor attack system**
- Equip weapon, look at corpse, use `loco:StartAttack()` to hold +attack
- The `weapon_ttt_defibrillator` base class handles the revive timer and callbacks
- Pro: Uses actual weapon code path, guaranteed compatibility
- Con: Requires careful positioning (defib has range check), timing is controlled by weapon not behavior

**Option B: Direct revive call with AddZombie**
- Call `AddZombie(ply, owner)` directly after the revive delay
- Pro: Full control over timing and logic
- Con: Bypasses weapon clip count, sound effects, may desync with weapon state

**Recommendation:** Option A (simulate weapon use). This is the most robust approach:
1. Navigate to corpse spine position
2. Equip `weapon_ttth_necrodefi`
3. Use `loco:StartAttack()` — the weapon base class detects the corpse and begins reviving
4. The weapon handles its own timer, clip deduction, success chance, and calls `OnRevive` → `AddZombie()`
5. Behavior waits for success/failure callback or timeout

### A.2: Zombie Tree Architecture

The zombie has extremely constrained gameplay — one weapon, slow movement, finite ammo. The behavior tree should reflect this:

```
ZombieTree = {
    FightBack,           -- Defend if being attacked
    ZombieAttack,        -- Proactively hunt non-allies with deagle
    ZombieProtectMaster, -- Stay near necromancer when idle
    Patrol               -- Wander if nothing else to do
}
```

No investigation, no support, no health stations, no weapon gathering — zombies are pure offensive minions.

### A.3: Necro vs Infected Comparison

| Aspect | Infected | Necromancer |
|---|---|---|
| **Conversion** | Melee kill converts victim | Defib on corpse converts |
| **Zombie weapon** | Fists only (melee) | Zombie deagle (ranged, finite ammo) |
| **Zombie death** | Host dies → all die | Ammo runs out → self-destruct |
| **Speed** | Normal | 0.5x walk speed |
| **Coordination** | Swarm target (closest to host) | Swarm target (closest to necro) |
| **Stealth** | Host is hidden, zombies are overt | Necro is hidden, zombies are overt |

The patterns are similar enough that we can reuse ~70% of the infected architecture.
