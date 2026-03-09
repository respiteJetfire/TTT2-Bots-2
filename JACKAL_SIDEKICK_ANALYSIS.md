# Jackal & Sidekick — TTT2 Bots Integration Analysis

> **Date**: 2026-03-09  
> **Scope**: Full analysis of the Jackal/Sidekick role addon (`ttt2-role_jack-master`, `ttt2-role_siki-master`) and its integration with the TTT2-Bots-2 codebase. Covers bugs, gaps, and a comprehensive improvement roadmap.

---

## Table of Contents

1. [Role Addon Architecture Summary](#1-role-addon-architecture-summary)
2. [Existing Bot Integration Audit](#2-existing-bot-integration-audit)
3. [Critical Bugs](#3-critical-bugs)
4. [Gaps & Missing Features](#4-gaps--missing-features)
5. [Improvement Roadmap & Checklist](#5-improvement-roadmap--checklist)
6. [Implementation Strategies](#6-implementation-strategies)

---

## 1. Role Addon Architecture Summary

### 1.1 Jackal (`ttt2-role_jack-master`)

| Aspect | Detail |
|--------|--------|
| **Team** | `TEAM_JACKAL` (custom team, initialized via `roles.InitCustomTeam`) |
| **Color** | `Color(100, 190, 205, 255)` (teal) |
| **Win Condition** | Kill all non-Jackal/Sidekick players |
| **Equipment** | Traitor shop fallback merged with Jackal-specific items |
| **Loadout** | Sidekick Deagle (if `ttt_jackal_spawn_siki_deagle == 1`), armor (`ttt_jackal_armor_value`, default 30) |
| **ConVars** | `ttt_jackal_armor_value` (0–100), `ttt_jackal_spawn_siki_deagle` (bool) |
| **Key Hook** | `TTTAModifyRolesTable` — moves Jackal player count into innocent pool for role selection |

### 1.2 Sidekick (`ttt2-role_siki-master`)

| Aspect | Detail |
|--------|--------|
| **Team** | Inherits from the Jackal's team at conversion time |
| **Modes** | `ttt2_siki_mode`: 0 = gets targets, can't win alone; 1 = becomes former teammate on mate death; 2 = can win alone + gets targets |
| **Not Selectable** | `notSelectable = true` — never directly assigned by role system |
| **Conversion** | Via `AddSidekick(target, attacker)` — changes role to `ROLE_SIDEKICK`, sets team to attacker's team, heals to full HP |
| **Protection** | `ttt2_siki_protection_time` — new sidekick can't damage their creator for N seconds |
| **Binding** | `NWEntity("binded_sidekick")` — links sidekick to mate; `GetSidekickMate()`, `GetSidekicks()`, `IsSidekick()` Player meta methods |
| **Color** | Darkened version of mate's role color |
| **Mode 0/2 Targets** | Hitman-style target system: random non-ally target, credits for target kills, reassignment on target death |
| **Mode 1 Succession** | On mate death, sidekick becomes the mate's role and leaves the team |

### 1.3 Sidekick Deagle (`weapon_ttt2_sidekickdeagle`)

| Aspect | Detail |
|--------|--------|
| **Ammo** | `Primary.ClipSize = 1`, `Primary.Ammo = ""` (no reserve ammo type — **ammo is entirely in Clip1**) |
| **Behavior** | Fires a 0-damage bullet with a custom callback; on hit, calls `AddSidekick(target, attacker)` |
| **Miss/Refill** | If `ttt2_siki_deagle_refill == 1`, missed shots start a cooldown timer (`ttt2_siki_deagle_refill_cd`, default 120s), reduced by kills (`ttt2_siki_deagle_refill_cd_per_kill`, default 60s) |
| **Restrictions** | Can't shoot same-team players; can't shoot existing Jackals or Sidekicks |
| **Single Use** | Removed from owner after successful hit |
| **Client Refill** | Refill UI status + net messages are entirely **client-side** (timer, STATUS icon) |
| **AllowDrop** | `false` |

---

## 2. Existing Bot Integration Audit

### 2.1 Role Definitions (`roles/jackal.lua`, `roles/sidekick.lua`)

**Jackal** (`roles/jackal.lua`):
- ✅ Role registered with `TEAM_JACKAL`
- ✅ Allied teams: `TEAM_JESTER`, `TEAM_JACKAL`
- ✅ Allied roles: `sidekick`
- ✅ `LovesTeammates=true` — critical for dynamic team detection
- ✅ `CanCoordinate=true` — enables PlanCoordinator participation
- ✅ `StartsFights=true`
- ✅ Good role description for LLM prompts
- ❌ Behavior tree uses `_prior.Convert` — but `CreateSidekick` is **NOT** in the Convert priority node

**Sidekick** (`roles/sidekick.lua`):
- ⚠️ Team set to `TEAM_SIDEKICK` — but the actual addon sets the sidekick to the **Jackal's team** at conversion. If `TEAM_SIDEKICK` doesn't exist as a global, this could be undefined.
- ⚠️ Allied teams only lists `TEAM_JESTER` — missing `TEAM_JACKAL` and own team. Relies on `LovesTeammates=true` as a workaround.
- ✅ Allied roles: `jackal`
- ✅ Has `FollowMaster` in behavior tree
- ✅ Two witness hooks: sidekick defends jackal when attacked, assists jackal when shooting
- ❌ No role description set
- ❌ `CanHaveRadar` not set (defaults to false)

### 2.2 CreateSidekick Behavior (`behaviors/createsidekick.lua`)

- ✅ Uses `RegisterRoleWeapon` factory correctly
- ✅ Targets isolated players (`lib.FindIsolatedTarget`)
- ✅ Witness threshold of 1 (stealthy)
- ✅ Chatter event `CreatingSidekick` wired
- ❌ **NOT in any priority node** — never executes via `_prior.Convert`

### 2.3 Inventory Methods (`components/sv_inventory.lua`)

- ✅ `GetJackalGun()` exists — checks for `weapon_ttt2_sidekickdeagle`
- ✅ `EquipJackalGun()` exists
- 🐛 **Critical Bug**: `GetJackalGun()` uses `wep:Ammo1() > 0` to check ammo — but the sidekick deagle has `Primary.Ammo = ""` (no ammo type), so `Ammo1()` always returns 0. The ammo is in `Clip1()`. **This means GetJackalGun always returns nil, and the bot can never use the sidekick deagle.**

### 2.4 Chatter/Locale (`locale/en/sh_chats.lua`)

- ✅ `CreatingSidekick` category registered with 10 personality-variant lines
- ❌ No chatter events for: sidekick conversion received, mate death/succession, target assignment, jackal victory, jackal team coordination

### 2.5 Buyables (`data/sv_default_buyables.lua`)

- ✅ Health Station and Medigun include `"jackal"` and `"sidekick"` in allowed roles
- ✅ Stungun includes `"sidekick"`

### 2.6 Event Bus (`lib/sh_events.lua`)

- ❌ No Jackal/Sidekick specific events defined

---

## 3. Critical Bugs

### 🐛 BUG-1: `GetJackalGun()` Ammo Check Always Fails

**File**: `lua/tttbots2/components/sv_inventory.lua` L573–L585  
**Impact**: **Bot Jackals can NEVER use the sidekick deagle**  
**Root Cause**: The sidekick deagle weapon has `Primary.Ammo = ""` (no reserve ammo type). All ammo is stored in `Clip1()`. The inventory check uses `wep:Ammo1() > 0`, which always returns 0 for this weapon.  
**Fix**: Change `wep:Ammo1() > 0` to `wep:Clip1() > 0`.

```lua
-- BEFORE (broken):
return wep:Ammo1() > 0 and wep or nil

-- AFTER (fixed):
return wep:Clip1() > 0 and wep or nil
```

### 🐛 BUG-2: `CreateSidekick` Not in Any Priority Node

**File**: `lua/tttbots2/lib/sv_tree.lua` L53–L63  
**Impact**: Even with BUG-1 fixed, the `CreateSidekick` behavior never runs because it's not in the `Convert` priority node, and the Jackal's tree references `_prior.Convert`.  
**Fix**: Add `_bh.CreateSidekick` to the `Convert` priority node in `sv_tree.lua`.

### 🐛 BUG-3: Sidekick Team Mismatch

**File**: `lua/tttbots2/roles/sidekick.lua` L30  
**Impact**: The sidekick role is registered with `TEAM_SIDEKICK`, but the actual addon sets the sidekick to the **Jackal's team** (`TEAM_JACKAL`) at conversion time. If `TEAM_SIDEKICK` is not defined as a global equal to `TEAM_JACKAL`, the bot's role data and actual team will be mismatched, causing alliance checks to fail.  
**Fix**: Register the sidekick role using `TEAM_JACKAL` instead, or add `TEAM_JACKAL` and `TEAM_SIDEKICK` to the allied teams. Also, validate at runtime that these globals exist.

### 🐛 BUG-4: Sidekick Witness Hook — Invalid `eyeTracePos` Check

**File**: `lua/tttbots2/roles/sidekick.lua` L38  
**Impact**: `IsValid(eyeTracePos)` is called on a `Vector`, but `IsValid()` doesn't work on Vectors (it's for entities). This always returns false, so the sidekick never assists the jackal when the jackal shoots.  
**Fix**: Replace with a nil check: `if not eyeTracePos then return end`

### 🐛 BUG-5: FollowMaster Excludes `ROLE_INNOCENT` Base Role

**File**: `lua/tttbots2/behaviors/followmaster.lua` L22  
**Impact**: `FindMaster` filters out players with `baseRole == ROLE_INNOCENT`. The Jackal has a custom base role, so this is fine. But if the sidekick's base role check returns `ROLE_INNOCENT` (which is the default for custom roles), the filter works by accident. However, the `role ~= myRole` check is the real discriminator. Minor edge-case risk.

---

## 4. Gaps & Missing Features

### 4.1 Behavior Gaps

| # | Gap | Impact | Priority |
|---|-----|--------|----------|
| G-1 | No sidekick-specific behavior for target system (Mode 0/2) | Sidekick in Mode 0/2 has a hitman-style target but bot has no behavior to pursue it | **HIGH** |
| G-2 | No handling of deagle refill mechanic | If the jackal misses, the deagle refills on a timer — bot doesn't know to wait and retry | **MEDIUM** |
| G-3 | No post-conversion behavior transition | When a bot is converted to sidekick mid-round, there's no explicit behavior tree swap or state reset | **MEDIUM** |
| G-4 | No `ttt2_siki_mode` awareness | Bot doesn't adapt behavior based on which sidekick mode is active | **MEDIUM** |
| G-5 | Jackal has no coordination specific to sidekick | Jackal treats sidekick like any other ally but should actively coordinate attacks | **MEDIUM** |
| G-6 | No "protect the mate" priority for sidekick | Sidekick has FollowMaster but no explicit bodyguard/protect behavior for its jackal | **LOW** |
| G-7 | No strategic target selection for sidekick deagle | Currently uses `FindIsolatedTarget` — should prefer converting a strong player (detective, well-armed) | **LOW** |

### 4.2 Communication/Chatter Gaps

| # | Gap | Impact | Priority |
|---|-----|--------|----------|
| C-1 | No "I'm now a sidekick" chatter event | Converted bot says nothing about role change | **HIGH** |
| C-2 | No jackal team coordination chatter | Jackal has `CanCoordinate=true` but no team-only strategic messages | **HIGH** |
| C-3 | No mate death/succession chatter | Mode 1 sidekick role change is silent | **MEDIUM** |
| C-4 | No target assignment chatter (Mode 0/2) | Sidekick doesn't announce pursuing targets | **LOW** |
| C-5 | No "Jackal team wins" victory chatter | Unlike traitor victory event, no jackal victory event | **LOW** |
| C-6 | No deception chatter for jackal | Jackal needs alibis and misdirection like traitors | **MEDIUM** |
| C-7 | No "don't shoot my sidekick" team coordination | Jackal should tell other (non-existent) allies to protect sidekick | **LOW** |

### 4.3 Event Bus Gaps

| # | Gap | Priority |
|---|-----|----------|
| E-1 | No `SIDEKICK_CONVERTED` event | **HIGH** |
| E-2 | No `JACKAL_MATE_DIED` event | **MEDIUM** |
| E-3 | No `SIDEKICK_TARGET_ASSIGNED` event | **LOW** |
| E-4 | No `SIDEKICK_SUCCEEDED_ROLE` event (Mode 1 succession) | **MEDIUM** |

### 4.4 Morality/Hostility Gaps

| # | Gap | Priority |
|---|-----|----------|
| M-1 | No special handling when a witnessed conversion occurs — other bots should KOS the jackal | **HIGH** |
| M-2 | No suspicion bump for players seen holding the sidekick deagle | **MEDIUM** |
| M-3 | Sidekick body found doesn't reveal jackal team information to investigating bots | **LOW** |

### 4.5 Plan Coordinator Gaps

| # | Gap | Priority |
|---|-----|----------|
| P-1 | PlanCoordinator only supports `TEAM_TRAITOR` — Jackal team (`TEAM_JACKAL`) has no plan support | **HIGH** |
| P-2 | No jackal-specific plans (e.g., "convert then ambush", "isolate target for deagle") | **MEDIUM** |

---

## 5. Improvement Roadmap & Checklist

### Phase 1: Critical Bug Fixes (Unblocks all other work)

- [ ] **FIX BUG-1**: Change `GetJackalGun()` ammo check from `Ammo1()` to `Clip1()`
  - File: `components/sv_inventory.lua` L584
  - One-line change

- [ ] **FIX BUG-2**: Add `_bh.CreateSidekick` to the `Convert` priority node
  - File: `lib/sv_tree.lua` L53–63
  - Add to the Convert table

- [ ] **FIX BUG-3**: Fix sidekick team registration and allied teams
  - File: `roles/sidekick.lua`
  - Use `TEAM_JACKAL` for registration OR add both `TEAM_JACKAL` and `TEAM_SIDEKICK` to `allyTeams`
  - Add nil-guard for `TEAM_SIDEKICK`

- [ ] **FIX BUG-4**: Fix sidekick witness hook Vector validation
  - File: `roles/sidekick.lua` L38
  - Change `IsValid(eyeTracePos)` to `if not eyeTracePos then return end`

### Phase 2: Core Behavior Integration

- [ ] **IMPL G-2**: Handle sidekick deagle refill
  - In `CreateSidekick` behavior or a new wrapper, add `clipEmptyFails = true` so behavior fails when clip is 0
  - Add deagle refill awareness: if clip is 0 and refill is enabled, don't permanently give up on the behavior
  - Consider a "wait for deagle refill" sub-state

- [ ] **IMPL G-3**: Post-conversion behavior tree swap
  - Hook into `TTT2UpdateSubrole` or the `AddSidekick` function
  - When a bot becomes a sidekick, force a behavior tree reset so it immediately picks up the sidekick tree
  - Clear any active stalk/attack targets that are now allies

- [ ] **IMPL G-5**: Jackal-Sidekick tactical coordination
  - When jackal has a sidekick, signal via team chat to coordinate attack timing
  - Sidekick should assist jackal's current target, not independently stalk
  - Add a `JackalCoordinator` (lightweight, modeled on `PlanCoordinator`) or extend `PlanCoordinator` to support `TEAM_JACKAL`

- [ ] **IMPL G-7**: Strategic deagle target selection
  - Enhance `CreateSidekick`'s `findTargetFn` to prefer:
    1. Isolated detectives (highest value conversion)
    2. Well-armed players
    3. Players not near groups
  - Weight by isolation score + role value

### Phase 3: Sidekick Mode Awareness

- [ ] **IMPL G-1**: Mode 0/2 target pursuit behavior
  - Create a new behavior `PursueTarget` for sidekick hitman-style targets
  - Hook into `SelectNewTarget` or use a think hook to detect when `ply:GetTargetPlayer()` changes
  - Bot should stalk and kill its assigned target with priority

- [ ] **IMPL G-4**: Mode-aware behavior tree selection
  - Mode 0: Standard sidekick tree + `PursueTarget`
  - Mode 1: Standard sidekick tree + `FollowMaster` (current)
  - Mode 2: Independent killer tree + `PursueTarget`
  - On mate death in Mode 1: dynamically swap to the inherited role's tree

### Phase 4: Communication & Chatter Integration

- [ ] **IMPL C-1**: Add `SidekickConverted` chatter event
  - Register locale category with personality variants
  - Fire when bot is converted: "I'm on {{player}}'s side now", "Guess I'm a sidekick now..."
  - Team-only message

- [ ] **IMPL C-2**: Add jackal team coordination chatter
  - Events: `JackalPlanAttack`, `JackalRequestAssist`, `JackalRegroup`
  - Examples: "Let's take out {{player}} together", "Cover me while I use the deagle", "Group up on me"
  - Team-only messages using `chatter:On()` with `teamOnly=true`

- [ ] **IMPL C-3**: Add mate death/succession chatter
  - `SidekickMateDied`: "My partner is dead... I'm on my own now"
  - `SidekickSucceeded`: "Taking over as {{role}} now" (Mode 1)
  - Both fire in the public channel

- [ ] **IMPL C-6**: Add jackal deception chatter
  - Reuse existing deception behavior patterns (`AlibiBuilding`, `FalseKOS`, `PlausibleIgnorance`)
  - Add jackal-specific alibi lines
  - Add to the Jackal behavior tree: `_prior.Deception`

- [ ] **IMPL C-5**: Add jackal victory chatter
  - Hook into `TTTEndRound` for `TEAM_JACKAL` win
  - Team-only gloating messages

### Phase 5: Event Bus & Morality Integration

- [ ] **IMPL E-1**: Add `SIDEKICK_CONVERTED` event
  - Payload: `{ jackal, newSidekick, previousRole }`
  - Subscribe in morality: witnesses should KOS the jackal
  - Subscribe in chatter: converted bot announces role change
  - Subscribe in evidence: record conversion as strong evidence

- [ ] **IMPL E-2**: Add `JACKAL_MATE_DIED` event
  - Payload: `{ deadMate, survivingSidekick, mode }`
  - Subscribe in behavior: trigger tree swap for Mode 1
  - Subscribe in chatter: announce succession

- [ ] **IMPL M-1**: Witness conversion KOS
  - When a bot witnesses the sidekick deagle being fired and someone's role changing:
    - Immediately KOS the shooter
    - Mark both as `TEAM_JACKAL` threats
  - Hook into `TTT2UpdateSubrole` and check for `ROLE_SIDEKICK` transitions

- [ ] **IMPL M-2**: Suspicious deagle detection
  - If a non-police player is seen holding `weapon_ttt2_sidekickdeagle`, add suspicion
  - Already partially handled by `noticeTraitorWeapons` in `sv_morality_hostility.lua`, but the deagle may not be classified as a traitor weapon

### Phase 6: Plan Coordinator Extension

- [ ] **IMPL P-1**: Extend PlanCoordinator for TEAM_JACKAL
  - Add Jackal-specific plans:
    - `ISOLATE_AND_CONVERT`: Follow an isolated target, use deagle when alone
    - `AMBUSH_PAIR`: Jackal + sidekick ambush a lone player
    - `SPLIT_AND_HUNT`: Jackal and sidekick cover different map areas
    - `PROTECT_SIDEKICK`: Jackal escorts sidekick until sidekick is armed
  - Activate after conversion (pre-conversion, jackal operates solo)

- [ ] **IMPL P-2**: Dynamic plan switching post-conversion
  - Before sidekick: Use traitor-like stalking plans
  - After sidekick: Switch to coordinated 2-person plans
  - If sidekick dies: Revert to solo desperate mode

---

## 6. Implementation Strategies

### 6.1 Bug Fix Strategy (Phase 1)

All four bug fixes are independent single-file changes. They should be implemented and tested atomically:

1. **BUG-1** is a one-liner in `sv_inventory.lua` — safest to fix first as it unblocks `CreateSidekick`
2. **BUG-2** is a one-liner in `sv_tree.lua` — adding `_bh.CreateSidekick` to the Convert table
3. **BUG-3** requires careful consideration of the runtime team values. Best approach: add `TEAM_JACKAL` to the sidekick's `allyTeams` table and add a nil-guard
4. **BUG-4** is a one-liner fix in the sidekick witness hook

### 6.2 Behavior Integration Strategy (Phase 2–3)

**Post-conversion tree swap** is the highest-impact improvement. Implementation approach:

```
Hook: TTT2UpdateSubrole  (fires when any player's subrole changes)
  → If new role == ROLE_SIDEKICK and player is a bot:
    1. Clear attackTarget if target is now an ally
    2. Force behavior tree reset (set lastBehavior = nil)
    3. Update the bot's cached RoleData reference
    4. Fire SIDEKICK_CONVERTED event
```

**Mode-aware trees**: Use a wrapper function in `roles/sidekick.lua` that returns different trees based on `ttt2_siki_mode`:

```lua
local function getSidekickTree()
    local mode = GetConVar("ttt2_siki_mode"):GetInt()
    if mode == 1 then
        return followMasterTree  -- current tree
    else
        return targetHunterTree  -- includes PursueTarget
    end
end
```

**Deagle refill handling**: The `CreateSidekick` behavior already uses `clipEmptyFails` as false by default. The fix is to:
1. Change to not permanently fail when clip is empty
2. Add a deagle refill awareness timer that re-enables the behavior after the refill cooldown

### 6.3 Communication Strategy (Phase 4)

Follow the established patterns:

1. **Register locale categories** in `locale/en/sh_chats.lua` with personality variants (10 lines per event)
2. **Add chatter chance entries** in `sv_chatter_events.lua`'s `chancesOf100` table
3. **Fire events** from hooks or behaviors using `bot:BotChatter():On(eventName, args, teamOnly)`
4. **For LLM-backed chatter**: The role description in `jackal.lua` already provides good context. Sidekick needs a description added.

### 6.4 Event Bus Strategy (Phase 5)

1. Add new event names to `TTTBots.Events.NAMES` in `sh_events.lua`
2. Publish from game hooks (`TTT2UpdateSubrole`, `PostPlayerDeath`, `EntityTakeDamage`)
3. Subscribe in relevant systems (morality, chatter, evidence)

### 6.5 Plan Coordinator Strategy (Phase 6)

The PlanCoordinator was designed for `TEAM_TRAITOR` but its architecture is team-agnostic. Strategy:

1. Add a `JackalCoordinator` module (separate file) that uses the same job/plan structure
2. Activate it only when `TEAM_JACKAL` has 2+ members (post-conversion)
3. Keep plans simple (2-person team max) — no need for complex multi-role coordination
4. Wire into the existing `FollowPlan` behavior or create a `FollowJackalPlan` behavior

### 6.6 Testing Strategy

| Test | Verification |
|------|-------------|
| Jackal bot uses sidekick deagle | Bot equips deagle, approaches isolated target, fires |
| Sidekick deagle converts target | Target becomes sidekick, heals, joins team |
| Sidekick follows jackal | FollowMaster activates, sidekick trails jackal |
| Sidekick defends jackal | When jackal is attacked, sidekick targets the attacker |
| Sidekick assists jackal | When jackal shoots, sidekick attacks same target |
| Mode 1 succession | When jackal dies, sidekick becomes jackal's role |
| Witness KOS | Innocent bot witnessing conversion calls KOS on jackal |
| Team chatter | Jackal/sidekick use team-only chat for coordination |
| Deagle refill | After miss, bot waits for refill and retries |
| Alliance checks | Jackal and sidekick never attack each other |

### 6.7 Priority Order

```
Phase 1 (Critical Bugs)     → Immediate: 4 bug fixes
Phase 2 (Core Behaviors)    → High: conversion handling, coordination
Phase 4 (Chatter)           → High: comms give life to the role
Phase 5 (Events/Morality)   → Medium: witness reactions, evidence
Phase 3 (Mode Awareness)    → Medium: Mode 0/2 target system
Phase 6 (Plan Coordinator)  → Low: advanced tactical coordination
```

---

## Appendix A: File Reference Map

| File | Relevance |
|------|-----------|
| `roles/jackal.lua` | Jackal bot role definition |
| `roles/sidekick.lua` | Sidekick bot role definition + witness hooks |
| `behaviors/createsidekick.lua` | Sidekick deagle usage behavior |
| `behaviors/followmaster.lua` | Sidekick follow-the-jackal behavior |
| `behaviors/stalk.lua` | Stalking behavior used by jackal |
| `behaviors/meta_roleweapon.lua` | Factory for role-weapon behaviors |
| `components/sv_inventory.lua` | `GetJackalGun()`, `EquipJackalGun()` |
| `components/sv_morality.lua` | Attack target selection |
| `components/morality/sv_morality_hostility.lua` | Role-based hostility policy |
| `components/chatter/sv_chatter_events.lua` | Chatter event probabilities & hooks |
| `lib/sv_tree.lua` | Behavior tree engine + priority nodes |
| `lib/sv_roles.lua` | Role registry + alliance checks |
| `lib/sv_roledata.lua` | RoleData class |
| `lib/sv_rolebuilder.lua` | Factory presets |
| `lib/sh_events.lua` | Event bus |
| `lib/sv_plancoordinator.lua` | Traitor plan coordination |
| `lib/sv_innocentcoordinator.lua` | Innocent plan coordination |
| `locale/en/sh_chats.lua` | Chatter locale lines |
| `data/sv_default_buyables.lua` | Shop items for jackal/sidekick |

## Appendix B: TTT2 Jackal/Sidekick Addon File Map

| File | Purpose |
|------|---------|
| `ttt2-role_jack-master/lua/terrortown/entities/roles/jackal/shared.lua` | Jackal role definition, loadout, shop |
| `ttt2-role_jack-master/lua/terrortown/autorun/shared/sh_jackal_convars.lua` | Jackal ConVars |
| `ttt2-role_siki-master/lua/terrortown/entities/roles/sidekick/shared.lua` | Sidekick role, conversion logic, mode system |
| `ttt2-role_siki-master/lua/terrortown/entities/roles/sidekick/target.lua` | Mode 0/2 hitman target system |
| `ttt2-role_siki-master/gamemodes/terrortown/entities/weapons/weapon_ttt2_sidekickdeagle.lua` | Sidekick deagle weapon |
