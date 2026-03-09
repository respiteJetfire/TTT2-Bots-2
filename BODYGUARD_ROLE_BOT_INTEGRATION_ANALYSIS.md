# Bodyguard Role — Bot Integration Analysis

> **Date:** 2026-03-09
> **Scope:** ttt2-bodyguard-master addon ↔ TTT2-Bots-2 codebase
> **Goal:** Full audit of the existing implementation, identification of bugs/gaps, and actionable checklist for deeper integration into the comms, behavior, morality, and perception systems.

---

## 1. Bodyguard Role Mechanics (Source Addon)

### 1.1 Core Mechanics

| Mechanic | Detail |
|---|---|
| **Team** | `TEAM_INNOCENT` by default, but dynamically swapped to match the guarded player's team via `guard:UpdateTeam(toGuard:GetTeam())`. |
| **Guard Assignment** | On role assignment, `BODYGRD_DATA:FindNewGuardingPlayer(ply)` picks a random alive non-bodyguard player, preferring one that has no existing guards. |
| **Networked Entity** | `ply:GetNWEntity("guarding_player")` stores who the bodyguard is protecting. |
| **Team Syncing** | When the guarded player's team changes (`TTT2UpdateTeam`), all guards follow suit. |
| **Guard Death** | On bodyguard death, guard is cleared; guarded player receives a "BodyGuard has died!" message. |
| **Target Death** | When guarded player dies: guard takes `ttt_bodygrd_damage_guarded_death` (default 20) damage, `EVENT_BODYGUARD_FAIL` fires, guard is reassigned a new target. |
| **Damage Reflection** | If the bodyguard damages their own target, damage is scaled by `ttt_bodygrd_damage_dealt_multiplier` (0.1x) and reflected at `ttt_bodygrd_damage_reflect_multiplier` (1.5x). |
| **Guard Kills Target** | If `ttt_bodygrd_kill_guard_teamkill` is true and the bodyguard kills their target, the bodyguard dies. |
| **Role Knowledge** | Bodyguard sees the guarded player's role and team. Other teammates are hidden (`unknownTeam = true`). |
| **Radar** | Bodyguard radar spoofs non-guarded allies to appear as ROLE_INNOCENT / TEAM_INNOCENT. |
| **Win Condition** | `preventWin = not ttt_bodygrd_win_alone` — typically cannot win alone. |
| **Hitman Exclusion** | Bodyguards cannot be hitman targets. |

### 1.2 ConVars

| ConVar | Default | Purpose |
|---|---|---|
| `ttt_bodygrd_damage_guarded_death` | 20 | HP damage to bodyguard when target dies |
| `ttt_bodygrd_kill_guard_teamkill` | 1 | Kill bodyguard if they kill their target |
| `ttt_bodygrd_damage_reflect_multiplier` | 1.5 | Damage reflected back to bodyguard attacking their target |
| `ttt_bodygrd_damage_dealt_multiplier` | 0.1 | Damage scale when bodyguard hits their target |
| `ttt_bodygrd_win_alone` | 0 | Whether bodyguard can win solo |

---

## 2. Current Bot Implementation

### 2.1 Role Definition (`roles/bodyguard.lua`)

```lua
local bodyguard = TTTBots.RoleData.New("bodyguard", TEAM_NONE)
bodyguard:SetDefusesC4(false)
bodyguard:SetPlantsC4(false)
bodyguard:SetCanHaveRadar(false)
bodyguard:SetCanCoordinate(true)
bodyguard:SetStartsFights(false)
bodyguard:SetUsesSuspicion(false)
bodyguard:SetBTree(bTree)
bodyguard:SetAlliedTeams({})
bodyguard:SetCanSnipe(false)
bodyguard:SetLovesTeammates(true)
bodyguard:SetRoleDescription(roleDescription)
```

**Behavior Tree:**
```
Chatter → FightBack → Requests → Support → Restore → Interact → Minge → Bodyguard
```

### 2.2 Behavior (`behaviors/bodyguard.lua`)

- **Validate:** Always returns `true` (never gated on target validity or round state).
- **OnRunning:** Gets the guarded player from `BODYGRD_DATA:GetGuardedPlayer(bot)`. Paths to within 250 units, then stops.
- **PlayerHurt Hook:** When the guarded player is hurt, assigns the attacker as the bodyguard bot's attack target via `SetAttackTarget()` at priority `PLAYER_REQUEST (4)`. Also checks the reverse direction (if someone attacks the bodyguard's charge's attacker).

### 2.3 What Works

- Basic follow-and-protect loop functions.
- `LovesTeammates = true` correctly leverages `IsAllies()` to recognize the guarded player as a teammate once the bodyguard's team is dynamically updated by the addon.
- `PlayerHurt` hook correctly uses the arbitration system at `PLAYER_REQUEST` priority.
- Damage reflection is handled entirely by the addon; the bot doesn't need to care about it.

---

## 3. Bugs & Issues

### 3.1 Critical Bugs

| # | Bug | Location | Impact |
|---|---|---|---|
| **B1** | `Bodyguard.Validate()` always returns `true` — even when there is no guarded target, the bot is dead, or the round isn't active. This means the Bodyguard behavior always runs, preventing all lower-priority behaviors (Minge, Follow, Wander, etc.) from ever executing when no target exists. | `behaviors/bodyguard.lua:20` | **High** — bot gets stuck doing nothing when target is nil. |
| **B2** | `OnRunning` returns `STATUS.FAILURE` when target is nil, but `Validate` still returns true next tick, so the behavior immediately restarts and fails again in an infinite start→fail→start loop. This burns CPU and prevents fallthrough to Patrol/Wander. | `behaviors/bodyguard.lua:31-33` | **High** — infinite failure loop. |
| **B3** | `DisableAvoid()` is called every tick when following but `EnableAvoid()` is only called in `OnEnd`. If the behavior fails (target nil) and cycles rapidly, avoidance may be left disabled intermittently. | `behaviors/bodyguard.lua:38-39` | **Medium** — pathfinding anomalies. |
| **B4** | The `defendPossibleFriend` hook checks `defender.attackTarget` but uses the raw field, not `IsValid()`. If attackTarget is a stale/NULL reference, the check passes incorrectly and the bot doesn't get assigned a new defend target. | `behaviors/bodyguard.lua:82` | **Medium** — missed defense opportunities. |
| **B5** | Role definition sets `TEAM_NONE` but the bodyguard addon dynamically sets the team. Between role assignment and `BODYGRD_DATA:FindNewGuardingPlayer()` completing (0.05s delay), the bot is on `TEAM_NONE`. During this window, `IsAllies()` returns `false` for everyone, and the morality system may assign an attack target against the guard's future allies. | `roles/bodyguard.lua:12` | **Medium** — brief hostile window on spawn. |

### 3.2 Non-Critical Issues

| # | Issue | Detail |
|---|---|---|
| **I1** | No `OnStart` meaningful logic — doesn't announce the protection target or initialize state. | Missing chatter and state init. |
| **I2** | No `OnEnd` cleanup of behavior state (uses `bot.` fields but doesn't use `Behaviors.GetState/ClearState`). | State management inconsistency. |
| **I3** | Bodyguard bot never retreats to heal when low HP. The behavior tree has no Retreat or SelfDefense nodes. If the bodyguard is at 5 HP, it still charges at the attacker. | Poor survivability. |
| **I4** | `maxDist = 250` is hardcoded with no consideration for the map size, indoor/outdoor areas, or whether the target is in combat. | Inflexible follow distance. |
| **I5** | No coordination with the guarded player when they are also a bot. E.g., the bodyguard doesn't signal "I'm protecting you" and the guarded bot doesn't know it has a bodyguard. | Missing awareness. |

---

## 4. Gaps & Missing Features

### 4.1 Behavior Gaps

| # | Gap | Priority | Detail |
|---|---|---|---|
| **G1** | **No dynamic tree switching.** Unlike Cupid (pre-link/post-link) and Infected (host/zombie), the bodyguard always uses the same tree regardless of state. When the target dies and reassignment is pending, the bot should fall back to an innocent-like tree. | **High** |
| **G2** | **No SelfDefense node in tree.** The bodyguard behavior tree lacks `_prior.SelfDefense`, meaning bots cannot defend themselves from accusations or KOS calls. | **High** |
| **G3** | **No Accuse node.** The bodyguard cannot accuse players who kill their target. | **Medium** |
| **G4** | **No Investigate node.** The bodyguard doesn't investigate corpses or noises. If their target is killed, they should investigate the body for evidence. | **Medium** |
| **G5** | **No Grenades node.** Cannot use grenades in combat. | **Low** |
| **G6** | **No Patrol fallback.** When the Bodyguard behavior is at the bottom of the tree and validates `true` permanently, the bot never patrols or wanders. Even when correctly fixed, there's no explicit Patrol group after Bodyguard. | **High** |
| **G7** | **No dynamic follow distance.** Should tighten distance when in combat zones or danger zones, and relax when idle. | **Medium** |
| **G8** | **No Retreat behavior.** Bodyguard should retreat to heal, especially since losing the target costs 20 HP. | **Medium** |
| **G9** | **No target reassignment awareness.** When the guarded player dies and a new one is assigned, the bot doesn't announce or react to the change. | **Medium** |
| **G10** | **No "intercept" behavior.** The bodyguard should actively step between the target and a known threat, not just path to the target's position. | **Low** (advanced) |

### 4.2 Chatter & Comms Gaps

| # | Gap | Priority | Detail |
|---|---|---|---|
| **C1** | **Zero chatter events defined.** No bodyguard-specific events in `sv_chatter_events.lua` or locale strings in `sh_chats.lua`. Compare to Cupid (10+ events), SK (8 events), Infected (5 events). | **High** |
| **C2** | **No locale lines.** The locale system has zero bodyguard-specific entries. Other roles have 50-100+ lines per archetype. | **High** |
| **C3** | **No LLM prompt context.** The role description is set but there are no bodyguard-specific prompt builders for casual or event-driven LLM chatter. | **Medium** |
| **C4** | **No team-only coordination chat.** Bodyguard should use team chat to coordinate with their charge (e.g., "Stay close", "I'll cover you", "Moving to you"). | **Medium** |
| **C5** | **No death reaction chatter.** When the guarded player dies, the bodyguard should react emotionally. When the bodyguard dies, nearby bots should comment. | **Medium** |
| **C6** | **No victory/defeat chatter.** No round-end comments for bodyguard success or failure. | **Low** |
| **C7** | **No casual/idle chatter about guarding.** Bodyguard bots near their charge could make comments about their duty. | **Low** |

### 4.3 Morality & Perception Gaps

| # | Gap | Priority | Detail |
|---|---|---|---|
| **M1** | **No perception layer integration.** The bodyguard's dynamic team changes aren't reflected in the perception cache. When a bodyguard switches from `TEAM_NONE` to `TEAM_TRAITOR` (because their charge is a traitor), other bots may still perceive them as neutral/innocent for the cache lifetime. | **Medium** |
| **M2** | **No hostility policy for bodyguard.** The morality hostility module doesn't have bodyguard-specific logic. For example: a bodyguard protecting a traitor should be treated as hostile by innocents once the guard's team is known, but the bot system may not KOS them quickly enough. | **Medium** |
| **M3** | **No suspicion/evidence integration.** When a bodyguard's charge is killed, the bodyguard should generate evidence about the killer. When the bodyguard is seen protecting a known traitor, innocent bots should raise suspicion. | **Medium** |
| **M4** | **No `preventAttack` for guarded player.** The bodyguard could accidentally be assigned its own charge as an attack target through opportunistic or suspicion-based targeting before the team switch completes. | **High** |

### 4.4 Role Data Configuration Gaps

| # | Gap | Priority | Detail |
|---|---|---|---|
| **R1** | `AlliedTeams = {}` is empty. This means no team is inherently allied. `LovesTeammates = true` compensates via `IsAllies()`, but it relies on the team being set correctly before any morality tick fires. | **Medium** |
| **R2** | `CanCoordinate = true` is set but there's nothing to coordinate about. Bodyguard is a solo role that doesn't work with other traitors or innocents in the coordinator systems. | **Low** |
| **R3** | `CanCoordinateInnocent` is not set (defaults false). If the bodyguard is protecting an innocent, they should participate in innocent-side coordination (BuddySystem, PatrolRoutes, etc.). | **Medium** |
| **R4** | `CanSnipe = false` — reasonable for a protector role, but when the charge is far away and in danger, a sniper position covering them could be valuable. | **Low** |
| **R5** | No `EnemyTeams` or `EnemyRoles` are defined. The bodyguard relies entirely on `LovesTeammates` + dynamic team to determine enemies. | **Low** |

---

## 5. Comparison with Well-Implemented Roles

| Feature | Cupid/Lover | Infected | Serial Killer | **Bodyguard** |
|---|---|---|---|---|
| Dynamic tree switching | ✅ pre/post-link | ✅ host/zombie | ✅ stealth/exposed | ❌ Static tree |
| Chatter events (count) | 10+ | 5+ | 8+ | **0** |
| Locale lines | ~80 | ~60 | ~60 | **0** |
| PlayerHurt defense hook | ✅ | ✅ | N/A | ✅ (basic) |
| Perception integration | ✅ Lover team | ✅ Zombie model | N/A | ❌ |
| Evidence/suspicion | N/A | N/A | ✅ knife evidence | ❌ |
| Team coordination chat | ✅ CupidTeamCoordinate | ✅ InfectedTeamRush | N/A | ❌ |
| Victory/defeat chatter | ✅ | ✅ | ✅ | ❌ |
| Retreat/survivability | Via ProtectLover | N/A (swarm) | ✅ armor-aware | ❌ |
| Round-end hooks | ✅ CupidVictory | ✅ InfectedVictory | ✅ SKVictory | ❌ |
| Behavior state mgmt | ✅ GetState/ClearState | ✅ | ✅ | ❌ raw fields |

---

## 6. Implementation Strategy

### Phase 1: Bug Fixes & Core Behavior (Priority: Critical)

**Goal:** Fix all critical bugs and make the basic protect loop robust.

#### 6.1 Fix `Validate()` (B1, B2)
- Gate on: round active, bot alive, has valid guarded player.
- When no target exists, return `false` to allow fallthrough to lower behaviors.

#### 6.2 Fix Avoidance Management (B3)
- Track avoidance state in `Behaviors.GetState(bot, "Bodyguard")`.
- Always re-enable in `OnEnd`.

#### 6.3 Fix `defendPossibleFriend` Stale Reference (B4)
- Check `IsValid(defender.attackTarget)` not just truthiness.

#### 6.4 Prevent Self-Attack During Team Transition (B5, M4)
- In the `PlayerHurt` hook, skip if the attacker is the bodyguard's own charge.
- Add a brief grace period (0.1s) after role assignment before morality ticks fire.

### Phase 2: Behavior Tree Overhaul (Priority: High)

**Goal:** Bring the bodyguard tree up to par with Cupid/Infected.

#### 6.5 Dynamic Tree Switching (G1)
- **Guarding Tree** (has valid target):
  ```
  Chatter → FightBack → SelfDefense → Grenades → Accuse →
  Requests → Support → Restore → Interact → Bodyguard → Investigate → Patrol
  ```
- **Unassigned Tree** (no target, waiting for reassignment):
  ```
  Chatter → FightBack → SelfDefense → Requests → Support →
  Restore → Interact → Investigate → Minge → Patrol
  ```
- Override `TTTBots.Behaviors.GetTreeFor()` following the Cupid chain pattern.

#### 6.6 Enhanced Follow Behavior (G7, G10)
- **Dynamic follow distance:** 150 units when target is in combat or danger zone, 300 units normally, 500 units in open/safe areas.
- **Intercept positioning:** When an attacker is known, position between the attacker and the charge rather than behind the charge.
- **Look direction:** Face threats, not the charge's back.
- Use `Behaviors.GetState()` and `ClearState()` for proper state management (I2).

#### 6.7 Add SelfDefense, Accuse, Retreat (G2, G3, G8)
- Include `_prior.SelfDefense` in the guarding tree above Accuse.
- Include `_prior.Accuse` so bodyguard can KOS killers.
- Add Retreat node so the bodyguard can heal when critically wounded.

#### 6.8 Target Reassignment Awareness (G9)
- Hook `BODYGRD_DATA:SetNewGuard()` or `PlayerDeath` to detect when the guarded player dies and a new one is assigned.
- Fire chatter event on reassignment.

### Phase 3: Chatter & Communication System (Priority: High)

**Goal:** Implement a full set of bodyguard-specific chatter events and locale lines.

#### 6.9 Define Chatter Events

Add to `sv_chatter_events.lua` `chancesOf100` table:

| Event Name | Chance | Trigger | Team-Only |
|---|---|---|---|
| `BodyguardAssigned` | 90 | Round start / reassignment — "I'm guarding {{player}}" | No |
| `BodyguardTargetDied` | 95 | Guarded player dies — panic/grief | No |
| `BodyguardReassigned` | 85 | New target assigned — "New objective: protecting {{player}}" | No |
| `BodyguardDefending` | 80 | PlayerHurt hook fires — "Get away from {{player}}!" | No |
| `BodyguardCoordinate` | 50 | Periodic (every 45s) — "Stay close, {{player}}" | Team-only |
| `BodyguardTargetFar` | 40 | Target is >500 units away — "{{player}}, wait up!" | No |
| `BodyguardLowHP` | 70 | Bot HP < 30 — "I'm hurt bad, can't protect much longer" | No |
| `BodyguardKilledThreat` | 75 | Killed an attacker of the charge — relief/pride | No |
| `BodyguardVictory` | 80 | Round end, bodyguard's team won | No |
| `BodyguardFailed` | 90 | Guard took damage from target death | No |
| `BodyguardSpotted` | 70 | Other bots see the bodyguard following someone suspiciously | No |
| `BodyguardProtectingTraitor` | 85 | Innocent sees bodyguard on traitor team — alarm | No |

#### 6.10 Add Locale Lines

Create entries in `locale/en/sh_chats.lua` for each event above, with lines for all archetypes:
- Default, Casual, Hothead, Dumb, Stoic, Nice, Tryhard, Teamer, Strategic (minimum 3-5 lines per archetype per event).

Example structure:
```lua
RegisterCategory("BodyguardAssigned", P.IMPORTANT,
    "Bot has been assigned as a bodyguard protecting {{player}}.")
    Line("I'm on bodyguard duty. Watching over {{player}}.", A.Default)
    Line("got assigned to guard {{player}}, wish me luck", A.Casual)
    Line("{{player}}, I've GOT you. Nobody touches you!", A.Hothead)
    -- ... etc
```

#### 6.11 Add Chatter Hooks

Add to `sv_chatter_events.lua`:
- **`TTT2BodyGrdNewGuardingMessage` net hook equivalent:** Fire `BodyguardAssigned` when bot receives assignment.
- **`PlayerDeath` hook:** Fire `BodyguardTargetDied` when the guarded player dies.
- **Round-end hook:** Fire `BodyguardVictory` on win.
- **Periodic timer (30s):** Fire `BodyguardCoordinate` if bot has a target and is alive.
- **`PostPlayerDeath` hook:** Fire `BodyguardFailed` when bot takes death damage.

### Phase 4: Morality, Evidence & Perception (Priority: Medium)

**Goal:** Integrate bodyguard into the social deduction systems.

#### 6.12 Evidence Generation
- When the guarded player is killed, the bodyguard should generate `WITNESSED_KILL` evidence against the killer (if visible).
- When the bodyguard sees someone attacking their charge, generate `SUSPICIOUS_MOVEMENT` evidence.
- Bodyguard should share evidence with their charge if both are alive.

#### 6.13 Perception Cache Invalidation
- On `TTT2UpdateTeam` for a bodyguard, call `TTTBots.Perception.InvalidateCache()` so other bots re-evaluate the bodyguard's alliance status immediately.

#### 6.14 Suspicion for Other Bots
- When an innocent-side bot sees a bodyguard following a known traitor, raise suspicion on the bodyguard.
- When a bodyguard is on `TEAM_TRAITOR`, innocent bots should eventually KOS them through the normal hostility pipeline.

#### 6.15 Prevent Friendly Fire on Charge
- In the morality arbitration, add a `preventAttackCharge` function that clears the attack target if it's the bodyguard's own charge.
- Priority: `PLAYER_REQUEST (4)` to override opportunistic and suspicion-based targeting.

### Phase 5: Advanced Behaviors (Priority: Low)

**Goal:** Add depth and emergent gameplay.

#### 6.16 Intercept Positioning
- When a known threat exists, calculate a midpoint between the threat and the charge.
- Path to that midpoint rather than directly to the charge.
- Requires awareness of the threat's last known position (from memory component).

#### 6.17 Coordinated Retreat
- If the bodyguard is low HP and the charge is being overwhelmed, the bodyguard should signal retreat and path both of them toward a health station or safe area.

#### 6.18 Innocent Coordinator Integration (R3)
- When the bodyguard is on `TEAM_INNOCENT`:
  - Set `CanCoordinateInnocent = true` dynamically.
  - The bodyguard's charge becomes their implicit "buddy" in the BuddySystem strategy.
  - Override BuddySystem pairing so the bodyguard is always paired with their charge.

#### 6.19 Dialogue Templates
- Add bodyguard-specific dialog templates:
  - "The Escort" — bodyguard and charge chat while walking together.
  - "The Sacrifice" — bodyguard's last words after charge dies.
  - "The Reveal" — bodyguard reveals they were guarding someone at round end.

#### 6.20 Cross-Role Interactions
- **Bodyguard + Spy:** If the bodyguard's charge is a spy on `TEAM_TRAITOR`, the bodyguard appears allied to traitors. Unique chatter about maintaining cover.
- **Bodyguard + Infected:** If the charge becomes infected, the bodyguard follows them into the infected team. Potential for zombie-guard behavior.
- **Bodyguard + Cupid:** If a lover is also the bodyguard's charge, the bodyguard has double incentive to protect them.

---

## 7. Implementation Checklist

### Phase 1: Bug Fixes ⚡
- [ ] **B1/B2** — Fix `Bodyguard.Validate()` to check round state, bot alive, valid target
- [ ] **B3** — Track avoidance state properly with `GetState/ClearState`
- [ ] **B4** — Fix stale reference check in `defendPossibleFriend`
- [ ] **B5/M4** — Add grace period and prevent self-attack on charge during team transition

### Phase 2: Behavior Tree 🌳
- [ ] **G1** — Implement dynamic tree switching (guarding vs unassigned)
- [ ] **G2** — Add `_prior.SelfDefense` to bodyguard tree
- [ ] **G3** — Add `_prior.Accuse` to bodyguard tree
- [ ] **G4** — Add `_prior.Investigate` to bodyguard tree
- [ ] **G5** — Add `_prior.Grenades` to bodyguard tree
- [ ] **G6** — Add `_prior.Patrol` fallback to bodyguard tree
- [ ] **G7** — Implement dynamic follow distance based on context
- [ ] **G8** — Add Retreat behavior support to bodyguard tree
- [ ] **G9** — Implement target reassignment detection and reaction
- [ ] **I1** — Add meaningful `OnStart` with chatter and state initialization
- [ ] **I2** — Migrate to `Behaviors.GetState/ClearState` pattern

### Phase 3: Chatter & Communication 💬
- [ ] **C1** — Define 12+ chatter events in `sv_chatter_events.lua`
- [ ] **C2** — Write locale lines for all events across all archetypes (~100+ lines)
- [ ] **C3** — Add bodyguard-specific LLM prompt context
- [ ] **C4** — Implement team-only coordination chatter (periodic timer)
- [ ] **C5** — Add death/failure reaction chatter hooks
- [ ] **C6** — Add round-end victory/defeat chatter hooks
- [ ] **C7** — Add idle/casual chatter about guarding duty
- [ ] Wire up `PlayerDeath`, `PostPlayerDeath`, `TTTBeginRound`, `TTTEndRound` hooks for chatter
- [ ] Add `BodyguardSpotted` / `BodyguardProtectingTraitor` detection timer for non-bodyguard bots

### Phase 4: Morality, Evidence & Perception 🧠
- [ ] **M1** — Invalidate perception cache on bodyguard team change
- [ ] **M2** — Add bodyguard-specific hostility policy considerations
- [ ] **M3** — Generate evidence when charge is attacked/killed
- [ ] **M4** — Add `preventAttackCharge` to morality hostility module
- [ ] Share evidence between bodyguard and charge
- [ ] Raise suspicion on bodyguard when seen protecting known traitor

### Phase 5: Advanced Behaviors 🎯
- [ ] **G10** — Implement intercept positioning (midpoint between threat and charge)
- [ ] **R3** — Dynamic `CanCoordinateInnocent` based on current team
- [ ] Integrate with InnocentCoordinator BuddySystem
- [ ] Add "The Escort" and "The Sacrifice" dialogue templates
- [ ] Cross-role interactions (Spy, Infected, Cupid)
- [ ] Coordinated retreat with charge

### Testing & Validation 🧪
- [ ] Verify `Validate()` correctly returns false when no target, bot dead, or round inactive
- [ ] Verify dynamic tree switching works (round start → guarding, target dies → unassigned → reassigned)
- [ ] Verify no infinite failure loops in behavior iteration
- [ ] Verify bodyguard doesn't attack own charge through any targeting pathway
- [ ] Verify chatter events fire at appropriate times and rates
- [ ] Verify perception cache is invalidated on team changes
- [ ] Verify bodyguard correctly follows a traitor charge without being KOS'd immediately
- [ ] Verify `OnEnd` properly cleans up locomotor state (avoidance, movement)
- [ ] Test with human guarded player and bot bodyguard
- [ ] Test with bot guarded player and bot bodyguard
- [ ] Test reassignment when guarded player disconnects
- [ ] Test bodyguard survives target death → takes damage → gets new target → continues

---

## 8. File Change Map

| File | Changes |
|---|---|
| `behaviors/bodyguard.lua` | **Major rewrite**: Fix Validate, dynamic distance, intercept positioning, state management, chatter integration, evidence generation |
| `roles/bodyguard.lua` | **Major rewrite**: Dynamic tree switching, tree overhaul, `GetTreeFor` override, role data tweaks |
| `components/chatter/sv_chatter_events.lua` | Add 12+ bodyguard event entries to `chancesOf100`, add PlayerDeath/PostPlayerDeath/round-end hooks, add periodic coordination timer |
| `locale/en/sh_chats.lua` | Add ~100+ locale lines for all bodyguard chatter events |
| `components/morality/sv_morality_hostility.lua` | Add `preventAttackCharge()` to prevent pipeline |
| `lib/sv_perception.lua` | Add perception cache invalidation hook for bodyguard team changes |
| `data/sv_dialogtemplates.lua` | Add "The Escort" and "The Sacrifice" dialog templates |

---

## 9. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Dynamic team changes confuse morality/perception for 1-2 ticks | Medium | Low | Grace period + cache invalidation |
| Bodyguard following traitor charge creates "outed traitor" cascade | Medium | Medium | Bodyguard's `unknownTeam` means other bots shouldn't know unless they observe |
| PlayerHurt hook fires too aggressively, causing bodyguard to attack wrong targets | Low | Medium | Validate attacker is not the charge; validate attacker is visible |
| Chatter spam from coordination timer | Medium | Low | Rate-limit via existing `CanSayEvent` system |
| `GetTreeFor` chain override conflicts with other role overrides (Cupid, Infected, etc.) | Low | High | Follow established chain pattern: save `_orig`, call it for non-bodyguard roles |

---

## 10. Notes

- The Bodyguard role is structurally very similar to the Cupid/Lover system: a role that dynamically changes teams and has a "protect this player" core loop. The ProtectLover behavior should be used as the primary reference implementation.
- The `BODYGRD_DATA` global is provided by the addon and is always available server-side when `ROLE_BODYGUARD` is defined. All bot code gates on `ROLE_BODYGUARD` existence.
- The damage reflection mechanic (`ReflectGuardedDamage` hook) means the bot should **never** intentionally damage its charge. The `preventAttackCharge` addition is critical.
- The `unknownTeam = true` flag on the role means the bodyguard doesn't inherently know who their teammates are (except their charge). This should inform the suspicion/evidence system — the bodyguard operates with limited information.
