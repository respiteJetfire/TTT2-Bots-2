# Cursed Role — TTT2 Bots Integration Analysis

> **Generated**: 2026-03-09  
> **Scope**: Full analysis of the Cursed role addon (`ttt2-role_curs`) and its integration with the TTT2-Bots-2 codebase, covering bugs, gaps, missing features, and implementation strategies.

---

## Table of Contents

1. [Cursed Role Mechanics Summary](#1-cursed-role-mechanics-summary)
2. [Current Bot Implementation Inventory](#2-current-bot-implementation-inventory)
3. [Critical Bugs](#3-critical-bugs)
4. [Feature Gaps](#4-feature-gaps)
5. [Comms & Chatter Integration](#5-comms--chatter-integration)
6. [Behavior System Integration](#6-behavior-system-integration)
7. [Suspicion & Evidence System](#7-suspicion--evidence-system)
8. [Implementation Checklist](#8-implementation-checklist)

---

## 1. Cursed Role Mechanics Summary

### Core Identity
The Cursed is a **TEAM_NONE** role that **cannot win** (`preventWin = true`), **cannot deal damage**, and must **swap roles** with another player to escape the curse. It is essentially a "hot potato" — the Cursed wants to pass the curse to someone else ASAP and inherit a real, winnable role.

### Key Mechanics

| Mechanic | How It Works | ConVar |
|----------|-------------|--------|
| **Tag Swap (USE key)** | Walk up to a player within `ttt2_cursed_tag_dist` (default 150) and press the tag bind to swap roles | `ttt2_cursed_tag_dist` |
| **RoleSwap Deagle** | Shoot a player to swap roles at range; has cooldown after miss | `ttt2_role_swap_deagle_enable`, `ttt2_role_swap_deagle_refill_time` |
| **No Backsies** | After tagging someone, the tagger gets a `curs_last_tagged` flag preventing the new Cursed from immediately swapping back | `ttt2_cursed_backsies_timer` (0 = permanent) |
| **No Damage Backsies** | Previously-Cursed players can't damage the new Cursed | `ttt2_cursed_no_dmg_backsies` |
| **Damage Immunity** | Cursed takes zero damage from all sources | `ttt2_cursed_damage_immunity` |
| **Zero Outgoing Damage** | Cursed deals zero damage to all players (hardcoded, always active) |  |
| **Auto-Respawn** | Cursed respawns after death (if `preventWin` still true) | `ttt2_cursed_seconds_until_respawn` (default 10) |
| **Self-Immolation** | Cursed can set themselves/corpse on fire to destroy evidence & reposition on respawn | `ttt2_cursed_self_immolate_mode` |
| **Speed Boost** | Cursed runs faster (1.2× default) | `ttt2_cursed_speed_multi` |
| **Stamina Buffs** | Reduced drain (0.35×), boosted regen (1.0×) | `ttt2_cursed_stamina_drain`, `ttt2_cursed_stamina_regen` |
| **Detective Protection** | Optionally blocks swapping with Detectives/Defectives | `ttt2_cursed_affect_det` |
| **Sticky Team Handling** | Doppelganger!Cursed and Copycat!Cursed keep their original team on swap | Hardcoded in `CURS_DATA.SwapRoles` |
| **No Shop/Credits** | Cursed has no shop access and cannot find credits | Hardcoded |

### The Swap Pipeline (Addon Native)
```
Client: net.Start("TTT2CursedSendTagRequest") → Server
Server: ply:GetEyeTrace() → CURS_DATA.AttemptSwap(ply, tgt, dist)
  → CURS_DATA.CanSwapRoles(): round active? ply alive? tgt alive? not SpecDM? tgt not tagged? dist OK? det allowed?
  → CURS_DATA.SwapRoles(): same-role check → sticky team check → SetRole both → SendFullStateUpdate once → clear old taggers → apply backsies timer + status icon
```

---

## 2. Current Bot Implementation Inventory

### Files Involved

| File | Purpose | Status |
|------|---------|--------|
| `roles/cursed.lua` | Role registration — BTree, team, flags | ✅ Exists |
| `behaviors/swaprole.lua` | Proximity tag swap (walk up & USE key simulation) | ⚠️ Broken |
| `behaviors/swapdeagle.lua` | RoleSwap Deagle shooting behavior | ⚠️ Partial |
| `behaviors/createcursed.lua` | Cursed Deagle — curse another player from range | ✅ Works (other roles cursing targets) |
| `components/sv_inventory.lua` | `GetSwapDeagleGun()`, `EquipSwapDeagleGun()`, `GetCursedGun()`, `EquipCursedGun()` | ✅ Exists |
| `data/sv_default_buyables.lua` | `Registry.CursedDeagle` — buyable for killer roles | ✅ Exists |
| `locale/en/sh_chats.lua` | `CreatingCursed` (10 lines), `SwappingRole` (10 lines) | ⚠️ Minimal |
| `components/sv_chatter_commands.lua` | `"curse"` keyword → `handleCursed()` → `CreateCursed.HandleRequest()` | ✅ Works |

### Cursed Bot BTree (from `roles/cursed.lua`)
```lua
local bTree = {
    _prior.Chatter,     -- Social behaviors
    _prior.Convert,     -- CreateDefector, CreateMedic, ..., CreateCursed, SwapDeagle, SwapRole, CopyRole, DropContract
    _prior.Requests,    -- CeaseFire, Wait, ComeHere, FollowMe, etc.
    _bh.Interact,       -- Cosmetic animations
    _prior.Patrol       -- Follow, GroupUp, Wander
}
```

**Key Observation**: The Cursed bot's only offensive/role-related behavior comes from `_prior.Convert`, which includes both `SwapDeagle` and `SwapRole`. The tree has no combat, no investigation, no self-defense — which is correct given the Cursed can't deal damage.

---

## 3. Critical Bugs

### BUG-1: SwapRole Bypasses Addon's Native Swap System (SEVERITY: CRITICAL)

**Location**: `behaviors/swaprole.lua` → `SwapRole.SwapRole()`

The bot's swap function performs a raw manual role swap:
```lua
bot:UpdateTeam(targetTeam)
bot:SetRole(targetRole)
SendFullStateUpdate()
target:SetRole(botRole)
target:UpdateTeam(botTeam)
SendFullStateUpdate()
```

This **completely bypasses** `CURS_DATA.AttemptSwap()` / `CURS_DATA.SwapRoles()`, causing:

| Missed Feature | Consequence |
|----------------|-------------|
| `curs_last_tagged` never set | No-backsies system is dead — immediate counter-swaps possible |
| Backsies timer not created | `ttt2_cursed_backsies_timer` convar ignored |
| `ttt2_curs_no_backsies` status icon never added | HUD feedback broken for the new Cursed target |
| Detective protection not checked | Bot swaps with Detectives even if `ttt2_cursed_affect_det = 0` |
| Sticky team handling absent | Doppelganger/Copycat teams corrupted on swap |
| `SendFullStateUpdate()` called twice | Unnecessary network traffic, potential desync |
| Old taggers not unmarked | Stale `curs_last_tagged` flags persist from human swaps |
| Same-role early exit missing | Bot wastes a swap on someone with the same role |

**Fix**: Replace the manual swap with a direct call to `CURS_DATA.AttemptSwap(bot, target, 0)` (passing `0` for distance since the bot already validated proximity). This is a server-side global function, callable by bots.

---

### BUG-2: SwapRole.GetTarget() Has Incomplete Filtering (SEVERITY: HIGH)

**Location**: `behaviors/swaprole.lua` → `SwapRole.GetTarget()`

Current filtering:
```lua
ply ~= bot
and not TTTBots.Roles.IsAllies(bot, ply)     -- ✅ Good
and not cursedPlayers[ply]                     -- ⚠️ Parallel universe (see below)
and TTTBots.Lib.IsPlayerAlive(ply)             -- ✅ Good
and not ply:HasEquipmentItem('item_ttt_countercurse_mantra')  -- ✅ Good
and ply:GetSubRole() ~= ROLE_DEFECTOR          -- ✅ Good
```

**Missing checks**:
- `ply.curs_last_tagged ~= nil` — addon's native backsies protection
- `tgt:GetBaseRole() == ROLE_DETECTIVE or tgt:GetSubRole() == ROLE_DEFECTIVE` gated by `ttt2_cursed_affect_det`
- Round state check (`GetRoundState() == ROUND_ACTIVE`)
- SpecDM check

**The `cursedPlayers` table** is a bot-internal cooldown that is completely disconnected from the addon's `curs_last_tagged` system. A player can be "cooldown-protected" in the bot's table but not in the addon's, or vice versa.

---

### BUG-3: SwapRole.OnStart() Has Dead Timer (SEVERITY: LOW)

**Location**: `behaviors/swaprole.lua` line ~52

```lua
function SwapRole.OnStart(bot)
    ...
    timer.Simple(1, function()
        return STATUS.RUNNING  -- ← This return goes nowhere; timer callbacks don't feed the behavior system
    end)
end
```

The `timer.Simple` callback's return value is discarded. `OnStart` itself doesn't return `STATUS.RUNNING`, so the behavior tree receives `nil` from `OnStart`, which is likely treated as `FAILURE` by the tree executor. This means the behavior may silently fail on its first tick.

**Fix**: Remove the timer and return `STATUS.RUNNING` directly from `OnStart`.

---

### BUG-4: SwapRole Uses Parallel Cooldown System (SEVERITY: MEDIUM)

**Location**: `behaviors/swaprole.lua` — `cursedPlayers` table

```lua
local cursedPlayers = {}  -- Module-level table, shared across all bots
```

This table is:
- Never synced with `curs_last_tagged`
- Never cleared on round reset (only individual entries expire after 10s timers)
- Shared across all bots (one bot's cooldown affects all bots)

---

### BUG-5: SwapRole.ShouldStartSwapping() 5% Random Gate Too Restrictive (SEVERITY: MEDIUM)

**Location**: `behaviors/swaprole.lua` → `SwapRole.ShouldStartSwapping()`

```lua
function SwapRole.ShouldStartSwapping(bot)
    local chance = math.random(1, 100)
    local shouldStart = chance <= 5
    ...
end
```

This is called inside `Validate()`, which runs **every tick** the behavior tree evaluates. At 5% per tick, this creates highly unpredictable delays. Since the Cursed bot's entire purpose is to swap roles, this artificial gate can cause the bot to wander aimlessly for extended periods even when a valid target is right next to it.

The Cursed should be **eager** to swap, not reluctant.

---

### BUG-6: SwapDeagle Behavior References Non-Existent Weapon State (SEVERITY: MEDIUM)

**Location**: `behaviors/swapdeagle.lua`

The `SwapDeagle` behavior uses `meta_roleweapon.lua` with `clipEmptyFails = true`. When the addon's RoleSwap Deagle misses, the cooldown/refill is handled **client-side** via `ttt_role_swap_deagle_miss` net message and `ttt_role_swap_deagle_refill_timer`. Bots don't have a client realm, so:

- The deagle's clip is never refilled after a miss (the `net.Receive("ttt_role_swap_deagle_refilled")` handler on the server only fires when the client sends the refill signal)
- `clipEmptyFails = true` means after one missed shot, the behavior permanently fails for the rest of the round
- The deagle effectively becomes a one-shot weapon for bots

---

### BUG-7: CreateCursed References Wrong Weapon (SEVERITY: MEDIUM)

**Location**: `behaviors/createcursed.lua` → `HandleRequest()`

```lua
bot:Give("weapon_ttt2_cursed_deagle")
```

This gives the **Cursed Deagle** (a traitor buyable weapon that curses targets). This is NOT the same as the **RoleSwap Deagle** (`weapon_ttt2_role_swap_deagle`). The naming is confusing but the distinction is important:
- `weapon_ttt2_cursed_deagle` — used by traitors to **make** someone cursed
- `weapon_ttt2_role_swap_deagle` — given TO the Cursed player to swap roles at range

This behavior is for traitor-team bots cursing others, so the weapon class is actually correct. However, the `HandleRequest` function in the chatter command system allows ANY bot to receive this command (via the `"curse"` keyword), not just traitors.

---

## 4. Feature Gaps

### GAP-1: No Self-Immolation Behavior
The Cursed can self-immolate (set themselves or their corpse on fire) to destroy evidence and reposition on respawn. Bots have **zero** awareness of this ability.

**Impact**: Bots miss a tactical tool for repositioning and evidence destruction.

### GAP-2: No Respawn Awareness
When the Cursed dies and respawns, the bot has no special handling for the respawn event. It doesn't:
- Re-evaluate targets after respawning
- Change strategy based on death location vs. spawn location
- Account for the respawn delay window

### GAP-3: No "I Got Cursed" Reaction
When a human or bot gets their role swapped to Cursed, there is no chatter event or behavioral shift. The bot should react with surprise/dismay and immediately start seeking a swap target.

### GAP-4: No Urgency Scaling
The Cursed is in a race against the clock — if everyone dies before the Cursed swaps, the round ends and the Cursed loses. There is no urgency mechanic that makes the bot more aggressive about swapping as the round progresses or as players die.

### GAP-5: No Target Prioritization
`SwapRole.GetTarget()` simply finds the **nearest** non-allied alive player. It doesn't consider:
- Which role would be best to inherit (traitor vs. innocent vs. detective)
- Whether the target is isolated (easier to tag without witnesses)
- Whether the target is in combat (distracted, easier to approach)
- Which team is currently winning (swap into the winning team)
- Avoiding targets near groups (less chance of being caught approaching)

### GAP-6: No "Being Cursed" Awareness for Other Bots
When a bot witnesses a Cursed player approaching another player or shooting the RoleSwap Deagle, there is no evidence event or reaction. Other bots should:
- Recognize the Cursed role (if revealed)
- Avoid or evade the Cursed player
- Warn others about the Cursed's location

### GAP-7: No RoleSwap Deagle Refill Handling (Server-Side)
As described in BUG-6, the deagle refill is client-side only. Bots need a server-side mechanism to track and trigger the refill.

### GAP-8: No Damage Immunity Awareness
The Cursed is immune to damage (optionally). Other bots don't know this and will waste ammo shooting at a Cursed player. The Cursed bot itself doesn't leverage this invulnerability for aggressive plays.

### GAP-9: No Speed Boost Exploitation
The Cursed has 1.2× speed and reduced stamina drain. The bot doesn't exploit this for chase-down tactics or evasion.

### GAP-10: Bot's Role Data Missing Key Flags
In `roles/cursed.lua`:
```lua
cursed:SetStartsFights(false)        -- Correct (can't do damage)
cursed:SetCanCoordinate(false)       -- ⚠️ Means no team chat coordination
cursed:SetUsesSuspicion(false)       -- Correct (no team to suspect for)
cursed:SetKOSedByAll(false)          -- ⚠️ Debatable — some servers KOS Cursed on sight
```

Missing considerations:
- No `NeutralOverride` set (should arguably be true so others don't reflexively attack)
- No special handling for the fact that Cursed changes team after swapping
- `SetLovesTeammates(true)` is set but Cursed is TEAM_NONE (no teammates to love)

---

## 5. Comms & Chatter Integration

### Current State

| Event | Exists? | Lines | Quality |
|-------|---------|-------|---------|
| `CreatingCursed` | ✅ | 10 (all archetypes) | Good — covers traitors cursing targets |
| `SwappingRole` | ✅ | 10 (Default only) | Medium — only Default archetype, references "Mimic" (wrong role) |
| `CopyingRole` | ✅ | 10 (Default only) | Medium — for Mimic, not Cursed, but similar |
| Cursed got tagged reaction | ❌ | 0 | Missing |
| Cursed swapped successfully | ❌ | 0 | Missing |
| Cursed spotted / warning | ❌ | 0 | Missing |
| Cursed approaching me | ❌ | 0 | Missing |
| Cursed respawned | ❌ | 0 | Missing |
| Cursed self-immolated | ❌ | 0 | Missing |
| Can't damage Cursed | ❌ | 0 | Missing |
| "No backsies" frustration | ❌ | 0 | Missing |

### Proposed New Chatter Events

#### For the Cursed Bot Itself
| Event Name | Trigger | Team-Only? | Priority | Sample Lines |
|------------|---------|------------|----------|-------------|
| `CursedRoleReceived` | Bot receives Cursed role (round start or mid-round swap) | No | IMPORTANT | "Oh no, I'm cursed!", "Great, I'm cursed... someone come here" |
| `CursedSwapSuccess` | Bot successfully swaps with someone | No | IMPORTANT | "Ha! Have fun being cursed, {player}!", "Sorry {player}, better you than me" |
| `CursedChasing` | Bot is approaching a swap target | No | NORMAL | "Hold still {player}!", "Come here {player}, I just want to talk" |
| `CursedDeagleFired` | Bot fires the RoleSwap Deagle | No | NORMAL | "Don't dodge!", "Tag, you're it!" |
| `CursedRespawned` | Bot respawns after dying | No | LOW | "I'm back!", "You can't get rid of me that easily" |
| `CursedNoBacksies` | Bot tries to tag someone but gets "no backsies" | No | LOW | "Ugh, no backsies...", "I can't tag them back yet" |
| `CursedCantTagDet` | Bot tries to tag a Detective but can't | No | LOW | "I can't curse a Detective!", "They're protected..." |
| `CursedDesperateLate` | Round is in overtime / few players left | No | IMPORTANT | "I need to curse someone NOW!", "Running out of time!" |
| `CursedSelfImmolate` | Bot self-immolates | No | NORMAL | *no text needed — action speaks for itself, or a brief "aaagh"* |

#### For Other Bots Reacting to Cursed
| Event Name | Trigger | Team-Only? | Priority | Sample Lines |
|------------|---------|------------|----------|-------------|
| `CursedSpotted` | Bot sees/identifies a Cursed player | No | IMPORTANT | "Watch out, {player} is Cursed!", "Cursed player spotted!" |
| `CursedApproachingMe` | Cursed player is walking toward this bot | No | CRITICAL | "Stay away from me!", "The Cursed is coming for me!" |
| `CursedCantDamage` | Bot tries to damage Cursed and fails | No | NORMAL | "I can't hurt them!", "The Cursed is immune!" |
| `CursedSwappedWithSomeone` | Bot witnesses a role swap | No | IMPORTANT | "They just swapped roles!", "{player1} cursed {player2}!" |

### Chatter Command Extensions
The `"curse"` keyword command currently only triggers `CreateCursed.HandleRequest()` (traitor cursing targets). It should also support:
- A human telling a Cursed bot "curse {player}" to suggest a swap target
- A human warning "cursed is coming" or "watch out for cursed"

---

## 6. Behavior System Integration

### Recommended BTree Revision

The current Cursed BTree is too passive:

```lua
-- CURRENT (too passive)
local bTree = {
    _prior.Chatter,
    _prior.Convert,     -- Contains SwapDeagle + SwapRole buried among 9 other behaviors
    _prior.Requests,
    _bh.Interact,
    _prior.Patrol
}
```

**Proposed revision**:
```lua
local bTree = {
    _prior.Chatter,
    _prior.Requests,
    _bh.SwapDeagle,      -- HIGH PRIORITY: Fire deagle at range (if has weapon + ammo)
    _bh.SwapRole,         -- HIGH PRIORITY: Walk up and tag (always available)
    _bh.CursedSelfImmolate,  -- NEW: Self-immolate when dead/strategic
    _bh.Interact,
    _bh.CursedStalk,      -- NEW: Stalk a target before approaching
    _prior.Patrol
}
```

Key changes:
- `SwapDeagle` and `SwapRole` promoted to top-level (not buried in `_prior.Convert` with 9 irrelevant behaviors)
- New `CursedSelfImmolate` behavior for when dead
- New `CursedStalk` variant that uses speed advantage to chase targets
- Removed `_prior.Convert` entirely — Cursed shouldn't be trying to use Defector/Medic/Doctor/Deputy deagles

### New Behaviors Needed

#### Behavior: `CursedSwapRole` (replaces `SwapRole`)
A ground-up rewrite that properly interfaces with the addon:

```
Validate:
  - Bot is ROLE_CURSED
  - Round is active
  - Bot is alive
  - Valid target exists (using addon's CURS_DATA.CanSwapRoles for validation)

OnStart:
  - Fire chatter event (CursedChasing)
  - Store target in state

OnRunning:
  - Navigate toward target
  - When within tag distance: look at target, get eye trace
  - If eye trace hits target: call CURS_DATA.AttemptSwap(bot, target, dist)
  - Handle result (success → CursedSwapSuccess chatter; failure → appropriate chatter)

Target Selection:
  - Prefer isolated targets
  - Weight by: distance, isolation (no witnesses), role desirability, line-of-sight
  - Scale urgency with time elapsed / players remaining
  - Respect all addon convars (tag distance, detective protection, backsies)
```

#### Behavior: `CursedSwapDeagle` (replaces `SwapDeagle`)
Enhanced version using `meta_roleweapon.lua` pattern but with:
- Server-side deagle refill tracking (set clip back to 1 after cooldown)
- Proper failure handling (don't permanently fail on empty clip)
- Reduced `startChance` inhibition (Cursed should WANT to use this)

#### Behavior: `CursedSelfImmolate`
New behavior for strategic self-immolation:

```
Validate:
  - Bot is ROLE_CURSED
  - Self-immolate mode convar allows it
  - Bot is dead (corpse mode) OR alive (full mode) AND tactically beneficial

OnRunning:
  - Send net message TTT2CursedSelfImmolateRequest
  - Return SUCCESS

Tactical triggers:
  - Dead with corpse about to be searched
  - Alive and cornered/surrounded with no swap targets nearby
  - Repositioning strategy (die → immolate corpse → respawn elsewhere)
```

#### Behavior: `CursedEvade`
New behavior for when the Cursed is being chased/attacked:

```
Validate:
  - Bot is ROLE_CURSED
  - Bot is being attacked or chased
  - Damage immunity is OFF (otherwise just ignore attackers)

OnRunning:
  - Use speed advantage to evade
  - Sprint toward nearest swap target while evading
  - Prioritize survival to enable future swaps
```

---

## 7. Suspicion & Evidence System

### Current State: No Role-Change Awareness

The evidence and suspicion systems have **zero** handling for mid-round role changes. When a bot gets cursed:

| Component | What Happens | Problem |
|-----------|-------------|---------|
| `sv_evidence.lua` | Evidence log persists from old role | Stale evidence never pruned |
| Trust network | "Confirmed innocent" flags persist | May trust former enemies |
| `sv_morality_suspicion.lua` | Suspicion values freeze (`UsesSuspicion=false`) | Bot acts on outdated grudges after getting a new role |
| `sv_morality_hostility.lua` | Alliance checks update live | ✅ Correct, but race window exists |
| Attack targets | Not cleared on role change | May briefly attack new allies |
| Behavior tree | Switches to Cursed BTree | ✅ Correct via `GetTreeFor()` live lookup |

### Required Hooks
The codebase has **no** `TTT2UpdateSubrole` / `TTT2UpdatedSubrole` hook listener. This is needed for:

1. **Self role change** (bot becomes Cursed):
   - Reset suspicion table
   - Clear evidence log
   - Clear attack targets
   - Switch to Cursed-appropriate behavior
   - Fire `CursedRoleReceived` chatter event

2. **Self role change** (bot swaps OUT of Cursed):
   - Re-enable suspicion system
   - Initialize fresh suspicion based on current game state
   - Adopt new role's BTree and behavior patterns

3. **Observed role change** (bot witnesses someone getting cursed):
   - Update evidence about that player
   - Adjust suspicion accordingly
   - Fire `CursedSwappedWithSomeone` chatter event if witnessed

---

## 8. Implementation Checklist

### Phase 1: Critical Bug Fixes
> Priority: **MUST HAVE** — Current implementation is broken

- [ ] **1.1** Rewrite `SwapRole.SwapRole()` to call `CURS_DATA.AttemptSwap(bot, target, dist)` instead of manual role swap
- [ ] **1.2** Fix `SwapRole.OnStart()` — remove dead `timer.Simple`, return `STATUS.RUNNING` directly
- [ ] **1.3** Replace `SwapRole.GetTarget()` filtering to use `CURS_DATA.CanSwapRoles()` for validation
- [ ] **1.4** Remove the parallel `cursedPlayers` cooldown table — rely on addon's `curs_last_tagged` system
- [ ] **1.5** Fix SwapDeagle refill — add server-side timer to refill the deagle clip after `ttt2_role_swap_deagle_refill_time` seconds on miss
- [ ] **1.6** Add round-state guard to `SwapRole.Validate()` (`GetRoundState() == ROUND_ACTIVE`)

### Phase 2: Behavior Tree Improvements
> Priority: **SHOULD HAVE** — Improves bot competence significantly

- [ ] **2.1** Revise Cursed BTree — promote `SwapDeagle` and `SwapRole` to top-level, remove irrelevant `_prior.Convert` behaviors
- [ ] **2.2** Increase `SwapRole` start chance from 5% to 40-60% (Cursed should be eager to swap)
- [ ] **2.3** Increase `SwapDeagle` start chance from 2% to 20-30%
- [ ] **2.4** Add urgency scaling: as round progresses or player count drops, increase swap eagerness toward 100%
- [ ] **2.5** Implement smart target selection in `SwapRole.GetTarget()`:
  - Weight by isolation (fewer witnesses)
  - Weight by distance (closer = better)
  - Weight by role desirability (prefer non-Cursed, prefer roles with teams that are winning)
  - Deprioritize targets near groups
- [ ] **2.6** Add `SwapRole.Interruptible = false` once target is within tag range (commit to the swap)
- [ ] **2.7** Implement `CursedSelfImmolate` behavior with tactical triggers
- [ ] **2.8** Exploit speed advantage: when chasing a target, use sprint/stamina buffs aggressively

### Phase 3: Chatter & Comms
> Priority: **SHOULD HAVE** — Makes Cursed bots feel alive and communicative

- [ ] **3.1** Register `CursedRoleReceived` chatter event with lines for all 10 archetypes
- [ ] **3.2** Register `CursedSwapSuccess` chatter event with lines for all 10 archetypes
- [ ] **3.3** Register `CursedChasing` chatter event with lines for all 10 archetypes
- [ ] **3.4** Register `CursedDeagleFired` chatter event (Default + key archetypes)
- [ ] **3.5** Register `CursedRespawned` chatter event
- [ ] **3.6** Register `CursedDesperateLate` chatter event for overtime/endgame urgency
- [ ] **3.7** Register `CursedNoBacksies` / `CursedCantTagDet` feedback chatter
- [ ] **3.8** Register `CursedSpotted` event for bots who identify the Cursed player
- [ ] **3.9** Register `CursedApproachingMe` event for bots being approached by Cursed
- [ ] **3.10** Register `CursedCantDamage` event for bots who fail to damage the Cursed
- [ ] **3.11** Fix `SwappingRole` locale lines — currently references "Mimic" instead of "Cursed"
- [ ] **3.12** Add all 10 archetypes to `SwappingRole` (currently Default-only)
- [ ] **3.13** Wire chatter events into behavior lifecycle (`OnStart`, `OnSuccess`, `OnFailure`)
- [ ] **3.14** Extend `"curse"` keyword command to support directing Cursed bots to specific targets

### Phase 4: Suspicion & Evidence System
> Priority: **SHOULD HAVE** — Prevents stale data after role swaps

- [ ] **4.1** Add `TTT2UpdatedSubrole` hook listener in evidence/morality components
- [ ] **4.2** On self role change to Cursed: reset suspicion table, clear evidence log, clear attack targets
- [ ] **4.3** On self role change from Cursed: re-enable suspicion, initialize fresh from current game state
- [ ] **4.4** On observed role change: update evidence about swapped players, fire witness chatter
- [ ] **4.5** Add "CursedImmune" evidence type — when a bot fails to damage a Cursed player, mark them
- [ ] **4.6** Ensure `bot.attackTarget` is cleared immediately on role change (not just on next hostility tick)

### Phase 5: Reactive Behaviors (Other Bots vs. Cursed)
> Priority: **NICE TO HAVE** — Enhances overall TTT gameplay depth

- [ ] **5.1** Add Cursed evasion behavior — bots run away from known Cursed players approaching them
- [ ] **5.2** Add "don't waste ammo" logic — if bot knows target is Cursed (damage immune), don't shoot
- [ ] **5.3** Add Cursed player tracking — bots share Cursed sightings via evidence system
- [ ] **5.4** Add defensive grouping — bots near a known Cursed cluster together for protection
- [ ] **5.5** Add "I got cursed" mid-round role transition — bot seamlessly shifts from its old role behavior to Cursed behavior, including abandoning old objectives

### Phase 6: Polish & Edge Cases
> Priority: **NICE TO HAVE** — Robustness

- [ ] **6.1** Handle Doppelganger!Cursed and Copycat!Cursed sticky team scenarios
- [ ] **6.2** Handle Cursed-on-Cursed swap attempt (same role, different team edge case)
- [ ] **6.3** Validate `item_ttt_countercurse_mantra` check still works (equipment item reference)
- [ ] **6.4** Test with `ttt2_cursed_damage_immunity = 1` — ensure bot leverages invulnerability
- [ ] **6.5** Test with `ttt2_cursed_seconds_until_respawn = 0` — ensure bot handles no-respawn mode
- [ ] **6.6** Test with `ttt2_role_swap_deagle_enable = 0` — ensure bot doesn't try to use nonexistent deagle
- [ ] **6.7** Test with multiple Cursed players (rare but possible with Doppelganger)
- [ ] **6.8** Ensure round-end cleanup: clear all Cursed-specific bot state on `TTTEndRound`

---

## Implementation Strategy Notes

### Approach: Fix First, Enhance Second
1. **Phase 1** should be done first and tested in isolation — it fixes game-breaking bugs
2. **Phase 2** can be done alongside Phase 1 since it's the same files
3. **Phase 3** (chatter) is independent and can be developed in parallel
4. **Phase 4** (suspicion/evidence) is a systemic change that affects all roles, not just Cursed — scope carefully
5. **Phase 5-6** are quality-of-life improvements

### Key Design Decision: Use the Addon's API
The single most impactful change is replacing the bot's custom swap logic with calls to `CURS_DATA.AttemptSwap()` and `CURS_DATA.CanSwapRoles()`. These are global server-side functions that handle all the edge cases. The bot should treat the addon as the source of truth and delegate all swap mechanics to it.

### Server-Side Deagle Refill Pattern
Since bots lack a client realm, the deagle refill must be handled server-side:
```lua
-- In SwapDeagle behavior's OnFailure or when clip empties:
timer.Create("TTTBots_SwapDeagleRefill_" .. bot:EntIndex(), cooldownTime, 1, function()
    local wep = bot:GetWeapon("weapon_ttt2_role_swap_deagle")
    if IsValid(wep) then
        wep:SetClip1(1)
    end
end)
```

### Urgency Formula
```lua
local function GetCursedUrgency(bot)
    local roundTime = CurTime() - TTTBots.Match.RoundStartTime
    local maxTime = GetConVar("ttt_roundtime_minutes"):GetFloat() * 60
    local timeRatio = math.Clamp(roundTime / maxTime, 0, 1)
    
    local alivePlayers = #TTTBots.Match.AlivePlayers
    local totalPlayers = #player.GetAll()
    local aliveRatio = 1 - (alivePlayers / math.max(totalPlayers, 1))
    
    -- Urgency scales from 0.1 (round just started) to 1.0 (overtime/few alive)
    return math.Clamp(0.1 + (timeRatio * 0.5) + (aliveRatio * 0.4), 0.1, 1.0)
end
```

This urgency value can multiply the start chance and influence target selection aggressiveness.

---

## Appendix: File Reference Map

| Source (Addon) | Source (Bot) | Relationship |
|---------------|-------------|--------------|
| `ttt2-role_curs/lua/terrortown/entities/roles/cursed/shared.lua` | `TTT2-Bots-2/lua/tttbots2/roles/cursed.lua` | Role definition ↔ Bot role registration |
| `ttt2-role_curs/lua/terrortown/autorun/shared/sh_curs_handler.lua` | `TTT2-Bots-2/lua/tttbots2/behaviors/swaprole.lua` | Swap logic (addon) ↔ Swap logic (bot, broken) |
| `ttt2-role_curs/lua/terrortown/autorun/shared/sh_curs_convars.lua` | *(none)* | Convars not read by bot |
| `ttt2-role_curs/gamemodes/terrortown/entities/weapons/weapon_ttt2_role_swap_deagle.lua` | `TTT2-Bots-2/lua/tttbots2/behaviors/swapdeagle.lua` | SWEP ↔ Bot weapon behavior |
| *(N/A — self-immolate is client-side)* | *(none)* | No bot implementation |
| `ttt2-role_curs/lua/terrortown/lang/en/cursed.lua` | `TTT2-Bots-2/lua/tttbots2/locale/en/sh_chats.lua` | Addon strings ↔ Bot chatter (minimal) |
