# Cupid Role — Bot Integration Analysis

> **Date:** March 9, 2026
> **Scope:** Full analysis of the ttt2-role-cupid addon, its interaction with TTT2-Bots-2, all bugs, gaps, and a comprehensive implementation plan for deep bot integration.

---

## Table of Contents

1. [Cupid Role Overview](#1-cupid-role-overview)
2. [Current Bot Implementation Status](#2-current-bot-implementation-status)
3. [Critical Bugs](#3-critical-bugs)
4. [Gaps & Missing Features](#4-gaps--missing-features)
5. [Implementation Strategy](#5-implementation-strategy)
6. [Checklist](#6-checklist)

---

## 1. Cupid Role Overview

### Role Mechanics

The Cupid is a special role that defaults to `TEAM_INNOCENT` but possesses a unique weapon (crossbow or legacy bow) to **link two players as "Lovers"**. Once linked:

| Mechanic | Description |
|----------|-------------|
| **Team Switch** | Both lovers (and optionally Cupid) move to `TEAM_LOVER` |
| **Shared Death** | If one lover dies, the other dies 5 seconds later |
| **Damage Split** | (cvar) Damage taken by either lover is split 50/50 between both |
| **Health Sync** | (cvar) Lovers' health equalises to the higher value each tick |
| **Win Condition** | Lovers win when all non-lovers are dead |
| **Time Limit** | Cupid's weapon is stripped after `ttt_cupid_timelimit_magic` seconds (default 60) |

### ConVars

| ConVar | Default | Effect |
|--------|---------|--------|
| `ttt_cupid_damage_split_enabled` | 1 | Enable shared damage between lovers |
| `ttt_cupid_old_weapon` | 0 | Use legacy bow (GUI-based) instead of crossbow |
| `ttt_cupid_forced_selflove` | 0 | First crossbow shot auto-pairs Cupid with the target |
| `ttt_cupid_lovers_force_own_team` | 0 | Lovers always join `TEAM_LOVER` even if same team |
| `ttt_cupid_joins_team_lovers` | 0 | Cupid also joins `TEAM_LOVER` |
| `ttt_cupid_timelimit_magic` | 60 | Seconds before weapon is stripped |

### Weapons

- **Crossbow** (`weapon_ttt2_cupidscrossbow`) — Two-shot point-and-click: first shot marks lover #1, second shot marks lover #2. Secondary fire pairs Cupid with lover #1.
- **Bow** (`weapon_ttt2_cupidsbow`) — Opens a VGUI dropdown menu to select two players by name. Entirely client-side GUI.

### Key Addon Files

| File | Purpose |
|------|---------|
| `lua/terrortown/entities/roles/cupid/shared.lua` | Role definition, loadout, team creation (`TEAM_LOVER`) |
| `lua/autorun/sh_cupid_convars.lua` | ConVar definitions |
| `lua/autorun/sh_cupid_love_handler.lua` | Core game logic: lover pairing, death hooks, damage split, health sync, team switching, net message handlers, round reset |
| `gamemodes/.../weapon_ttt2_cupidscrossbow/shared.lua` | Crossbow weapon SWEP |
| `gamemodes/.../weapon_ttt2_cupidsbow/shared.lua` | Bow weapon SWEP (legacy, uses VGUI) |

---

## 2. Current Bot Implementation Status

### What Exists

**Role File** (`roles/cupid.lua`):
- Registers Cupid with `TEAM_LOVER`, allied teams `TEAM_JESTER` + `TEAM_LOVER`
- Sets `LovesTeammates = true` for dynamic alliance via team matching
- Sets `StartsFights = true`, `UsesSuspicion = false`, `CanCoordinate = true`
- Behavior tree: `Chatter → FightBack → Requests → CreateLovers → Restore → Minge → Stalk → Investigate → Patrol`

**Behavior** (`behaviors/createlovers.lua`):
- Uses `RegisterRoleWeapon` factory with `GetLoversGun()`/`EquipLoversGun()` from inventory
- Finds closest alive player not already targeted
- Engage distance: 150 units, start chance: 2%
- Tracks targets in module-level `targets` table

**Inventory** (`components/sv_inventory.lua`):
- `GetLoversGun()` — checks for both `weapon_ttt2_cupidscrossbow` and `weapon_ttt2_cupidsbow`
- `EquipLoversGun()` — equips the found weapon

### What's Completely Missing

| Category | Status |
|----------|--------|
| Chatter events | ❌ Zero events in `chancesOf100` |
| Locale lines | ❌ Zero `RegisterCategory` entries in `sh_chats.lua` |
| Hook integrations | ❌ No game hooks for lover lifecycle events |
| Morality/suspicion awareness | ❌ No Cupid-specific evidence types |
| Dynamic behavior tree | ❌ No pre-link vs post-link tree switching |
| Helper functions | ❌ No `IsCupidLinked()`, `GetLover()`, etc. |
| Partner coordination | ❌ No lover-to-lover tactical behavior |
| Non-Cupid bot awareness | ❌ Other bots don't know about or react to Cupid/Lovers |
| Phase awareness | ❌ No urgency escalation near time limit |

---

## 3. Critical Bugs

### Bug 1: 🔴 Bot Can Never Complete Lover Pairing (Crossbow)

**Root cause:** The crossbow's `PrimaryAttack` is a **two-stage state machine** — first shot sets `self.lover1`, second shot sends the `Lovedones` net message. However, `createlovers.lua`'s `onFireFn` returns `STATUS.SUCCESS` after the **first shot**, immediately terminating the behavior before a second target can be found and shot.

**Code path:**
1. Bot fires → crossbow's `PrimaryAttack` runs → `self.lover1 = trace` (shot 1 logged)
2. `onFireFn` returns `STATUS.SUCCESS` → meta_roleweapon framework exits → `OnEnd` cleanup
3. Bot never fires again → `Lovedones` net message never sent → lovers never created

### Bug 2: 🔴 Net Message Architecture Incompatible with Bots

**Root cause:** The crossbow's critical `net.Start("Lovedones")` / `net.SendToServer()` call is wrapped in `if CLIENT && LocalPlayer()==tempOwner then`. Bots have **no client realm** — `CLIENT` is always `false` on the server where bot weapon code executes. Even if Bug 1 were fixed, the net message that actually triggers lover creation **can never be sent by a bot**.

**The entire lover-creation pathway depends on a client→server net message that bots cannot send.**

### Bug 3: 🔴 Bow Weapon 100% Non-Functional for Bots

**Root cause:** The legacy bow (`weapon_ttt2_cupidsbow`) uses `vgui.Create("DFrame")` with `DComboBox` dropdowns and a "Finish" button — entirely client-side VGUI. Bots cannot interact with VGUI panels, click buttons, or select from dropdowns. If `ttt_cupid_old_weapon = 1`, Cupid bots are completely inert.

### Bug 4: 🟡 `targets` Table Never Resets Between Rounds

**Root cause:** `createlovers.lua` uses a module-level `local targets = {}` to track already-targeted players. This table is **never cleared** — not on round start, not on round end, not on map change. After the first round, previously-targeted players remain permanently marked, reducing the pool of valid targets.

### Bug 5: 🟡 Global `lovedones` Table Supports Only One Pair

**Root cause (addon-side):** `sh_cupid_love_handler.lua` uses a single global `lovedones = {}` table. If multiple Cupids exist (unlikely with `maximum = 1` but possible via admin), they overwrite each other's pairings. Not a bot bug per se, but affects bot behavior if multiple pairings are attempted.

### Bug 6: 🟠 No Secondary Attack Handling

**Root cause:** The crossbow's `SecondaryAttack()` implements "self-love" — Cupid pairs themselves with lover #1. The bot behavior has no concept of secondary fire or the `ttt_cupid_forced_selflove` ConVar, meaning this entire feature path is inaccessible to bots.

---

## 4. Gaps & Missing Features

### 4.1 Behavior System Gaps

#### No Dynamic Tree Switching (Pre-Link vs Post-Link)

The Cupid bot uses a single static behavior tree for the entire round. Comparable roles (Infected, Necromancer, Serial Killer) all implement dynamic tree switching via the `GetTreeFor` chain pattern. Cupid needs:

| Phase | Tree Focus |
|-------|-----------|
| **Pre-Link** (weapon equipped) | Urgently find and "shoot" two targets, aware of time limit |
| **Post-Link** (lovers created) | Aggressive combat with partner coordination, like Infected host |

#### No Time Pressure Awareness

Cupid's weapon is stripped after `ttt_cupid_timelimit_magic` seconds. The bot has no urgency escalation — it should increase `startChance` and seek targets more aggressively as the deadline approaches.

#### No Partner Following/Coordination (Post-Link)

After lovers are created, the bot has no behavior to:
- Stay near their lover (shared damage = shared death)
- Coordinate attacks with their lover
- Prioritize targets threatening their lover
- React to their lover being attacked (similar to Bodyguard's `PlayerHurt` hook)

#### No Self-Love Decision Logic

When `ttt_cupid_forced_selflove` is enabled or when the bot strategically wants to pair with itself, there's no decision-making around `SecondaryAttack`.

### 4.2 Chatter/Communication Gaps

No chatter events exist for the Cupid lifecycle. Needed events (following established patterns):

| Event | Probability | Visibility | Trigger |
|-------|------------|------------|---------|
| `CupidCreatingLovers` | 80 | Public (disguised) | When starting to use the crossbow |
| `CupidLoversFormed` | 90 | Team Only | Lovers successfully linked |
| `CupidLoverDied` | 95 | Public | Partner died — panic before own death |
| `CupidLoverPanic` | 70 | Public | Lover is being attacked |
| `CupidTeamCoordinate` | 50 | Team Only | Periodic lover team coordination |
| `CupidVictory` | 85 | Public | Lovers team won the round |
| `CupidTimePressure` | 75 | Public | Time running out to use crossbow |
| `CupidBetrayedTraitor` | 70 | Team Only (traitors) | Reaction to traitor being pulled to lovers |
| `CupidSpotted` | 85 | Public | Non-cupid bot witnesses cupid using crossbow |
| `CupidLoverSpotted` | 70 | Public | Non-cupid bot identifies a lover-team player |

### 4.3 Morality/Suspicion Gaps

| Gap | Description |
|-----|-------------|
| **No Cupid evidence type** | Bots cannot raise suspicion when witnessing Cupid fire the crossbow |
| **No shared-death awareness** | Bots don't understand that killing one lover kills both — should be a tactical priority |
| **No lover team detection** | Bots don't react to seeing players switch to `TEAM_LOVER` mid-round |
| **No damage-split awareness** | Bots don't understand that lovers share damage (targeting strategy implications) |

### 4.4 Non-Cupid Bot Awareness Gaps

Other bots currently have **zero awareness** of the Cupid/Lover system:

| Situation | Expected Bot Reaction | Current Behavior |
|-----------|-----------------------|-----------------|
| Witness Cupid fire crossbow | Raise suspicion, possibly call out | Nothing |
| See player switch to `TEAM_LOVER` | Recognise new enemy team | Nothing (alliance works via team system, but no callouts) |
| Identify lover pair | Prioritize killing one to kill both | No tactical awareness |
| Traitor gets pulled to `TEAM_LOVER` | React to betrayal, adjust targets | Nothing |
| Lover partner dies | Bots near remaining lover should know they'll die soon | No reaction |

---

## 5. Implementation Strategy

### Phase 1: Fix Core Weapon Interaction (Critical)

The fundamental problem is that the Cupid addon's lover-creation pathway is **client-to-server net messaging**, which bots cannot use. There are two approaches:

#### Option A: Server-Side Bypass (Recommended) ✅

Create a server-side helper function that directly executes the lover-creation logic, bypassing the weapon entirely. This is how the bot should work:

1. **Extract** the logic from `net.Receive("Lovedones")` in `sh_cupid_love_handler.lua` into a callable server function
2. **Bot behavior** finds two targets, then calls this function directly with `{target1, target2, cupid_bot}` instead of firing the weapon
3. **Strip the weapon** after successful pairing (matching the addon's timer behavior)

```
-- Pseudocode for server-side lover creation
function TTTBots.Cupid.CreateLovers(cupidBot, lover1, lover2)
    local lovedones = {lover1, lover2, cupidBot}
    -- Replicate the logic from net.Receive("Lovedones"):
    -- 1. Team switching
    -- 2. Damage split hooks
    -- 3. Health sync hooks
    -- 4. Weapon stripping
    -- 5. Set .inLove flags
    -- 6. Send "inLove" net message to affected players (for client-side effects)
end
```

**Pros:** Clean, reliable, no dependency on weapon firing mechanics. Follows how the addon actually processes lovers server-side.
**Cons:** Duplicates some addon logic — could break if addon updates. Needs careful testing.

#### Option B: Addon Patch (Alternative)

Modify the Cupid addon to expose a server-side API:

1. Add `CUPID_CreateLovers(lover1, lover2, cupid)` as a global function in `sh_cupid_love_handler.lua`
2. Move the `net.Receive("Lovedones")` logic into this function
3. Have the net handler call this function
4. Bot behavior calls this function directly

**Pros:** Single source of truth, addon maintains the logic.
**Cons:** Requires modifying the addon (may not be desired), addon author dependency.

### Phase 2: Rewrite CreateLovers Behavior

The current `RegisterRoleWeapon`-based behavior is fundamentally wrong for a two-stage weapon. Replace with a custom behavior:

```
CreateLovers Behavior (Rewritten):
├── State: FINDING_FIRST
│   ├── Find isolated/close target
│   ├── Navigate to within range
│   ├── If selfLove mode → pair self + target → goto LINKING
│   └── Mark as lover1 → goto FINDING_SECOND
├── State: FINDING_SECOND
│   ├── Find second target (different from first)
│   ├── Navigate to within range
│   └── Mark as lover2 → goto LINKING
├── State: LINKING
│   ├── Call server-side CreateLovers()
│   ├── Strip weapon
│   └── Return SUCCESS
└── Urgency: Escalates as ttt_cupid_timelimit_magic approaches
```

**Target Selection Strategy:**
- Prefer isolated players (fewer witnesses)
- Prefer players on the same team (strategic: won't need team switching)
- Avoid detectives/public roles (crossbow addon blocks these)
- Consider self-pairing when `ttt_cupid_forced_selflove` is enabled or strategically advantageous
- Time pressure: as deadline nears, accept any valid target

### Phase 3: Dynamic Behavior Tree

Implement `GetTreeFor` chain override following the Infected/Necromancer/SK pattern:

```lua
-- Pre-link tree (Cupid still has weapon)
local preLinkTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _bh.CreateLovers,      -- Priority: complete the pairing
    _prior.Restore,
    _prior.Investigate,
    _prior.Patrol
}

-- Post-link tree (Lovers created, fight to win)
local postLinkTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _bh.ProtectLover,      -- New: stay near + defend lover
    _prior.Restore,
    _prior.Minge,
    _bh.Stalk,             -- Hunt isolated enemies
    _prior.Investigate,
    _prior.Patrol
}
```

**Detection:** Check `bot.inLove == true` or `lovedones` table contains the bot.

### Phase 4: New Behaviors

#### ProtectLover Behavior (New)

Similar to the existing Bodyguard behavior, but for the Cupid/Lover dynamic:

- **Follow** the lover, staying within ~200 units
- **React to attacks** on the lover via `PlayerHurt` hook (like Bodyguard)
- **Priority:** HIGH — shared death means protecting the lover is self-preservation
- **Coordination:** When attacking, prefer targeting enemies near the lover

#### CupidTimePressure Behavior (New or Enhancement)

- Track remaining time before weapon strip
- At 50% time: increase engagement distance, reduce witness caution
- At 75% time: accept any valid target, sprint toward closest
- At 90% time: desperate mode, fire at the first player seen
- Fire chatter events expressing urgency

### Phase 5: Chatter Integration

#### 5a. Register Events in `sv_chatter_events.lua`

Add to `chancesOf100`:
```lua
CupidCreatingLovers = 80,
CupidLoversFormed = 90,
CupidLoverDied = 95,
CupidLoverPanic = 70,
CupidTeamCoordinate = 50,
CupidVictory = 85,
CupidTimePressure = 75,
CupidBetrayedTraitor = 70,
CupidSpotted = 85,
CupidLoverSpotted = 70,
```

#### 5b. Add Event Triggers

| Trigger Location | Event | Mechanism |
|-----------------|-------|-----------|
| CreateLovers behavior `OnStart` | `CupidCreatingLovers` | `chatter:On(...)` |
| Server-side CreateLovers function | `CupidLoversFormed` | Direct call after successful pairing |
| `PlayerDeath` hook | `CupidLoverDied` | Check if dead player `.inLove`, fire on surviving lover |
| ProtectLover behavior periodic | `CupidTeamCoordinate` | Timer-based team chat |
| `TTTEndRound` hook | `CupidVictory` | Check if `TEAM_LOVER` won |
| CreateLovers time pressure check | `CupidTimePressure` | Timer approaching deadline |
| Traitor `PlayerDeath` callback | `CupidBetrayedTraitor` | Traitor pulled to lovers → team reacts |
| Suspicion witness event | `CupidSpotted` | Non-cupid bot sees crossbow fire |
| Team change detection | `CupidLoverSpotted` | Bot notices player on `TEAM_LOVER` |

#### 5c. Locale Lines in `sh_chats.lua`

Add `RegisterCategory` blocks with archetype-specific lines for each event. Example:

```
-- CupidCreatingLovers (disguised as innocent chatter — cupid doesn't want to reveal themselves)
"Time to play matchmaker... nobody look"
"I've got something special for you two"
"Just need to get a little closer..."

-- CupidLoversFormed (team only)
"We're linked now. If one of us goes down, we both do. Stick together."
"Alright, we're in this together. Watch each other's backs."
"Love connection established. Don't get us killed."

-- CupidLoverDied
"NO! They killed them... I don't have long..."
"My partner's gone... this is it for me too..."
"Wait... I'm dying too?! WHAT"

-- CupidTimePressure
"I need to hurry up with this..."
"Running out of time to find my targets..."
"Tick tock, gotta make this love connection happen"
```

### Phase 6: Morality/Suspicion Integration

#### New Evidence Types in `sv_morality_suspicion.lua`

| Type | Value | Description |
|------|-------|-------------|
| `CupidCrossbow` | 5 | Witnessed Cupid firing the crossbow |
| `LoverTeamSwitch` | 4 | Player observed switching to `TEAM_LOVER` |

#### Tactical Awareness in `sv_morality_hostility.lua`

Add a new hostility function:

```lua
-- When bot identifies a lover pair, prioritize killing one (kills both)
local function prioritizeLoverTarget(bot)
    -- If bot can see a player with .inLove == true
    -- AND that player's partner is also alive
    -- → This is a high-value target (2-for-1 kill)
    -- → Request attack with elevated priority
end
```

### Phase 7: Non-Cupid Bot Awareness

Bots that are NOT cupid or lovers need to react to the Cupid system:

1. **Witness Detection:** When a bot sees a player fire a crossbow at another player without killing them → raise `CupidCrossbow` suspicion evidence
2. **Team Change Alert:** When a player's team changes to `TEAM_LOVER` mid-round → fire `CupidLoverSpotted` chatter
3. **Tactical Deduction:** If bot knows two players are lovers → understand killing one kills both → slightly prioritize lover targets
4. **Traitor Awareness:** If bot is a traitor and a teammate gets pulled to `TEAM_LOVER` → react with `CupidBetrayedTraitor` chatter, remove from ally list

---

## 6. Checklist

### Phase 1 — Fix Core Weapon Interaction
- [ ] **1.1** Create server-side `TTTBots.Cupid.CreateLovers(cupidBot, lover1, lover2)` helper function
  - Replicate team switching logic from `net.Receive("Lovedones")`
  - Handle `ttt_cupid_lovers_force_own_team` ConVar
  - Handle `ttt_cupid_joins_team_lovers` ConVar
  - Set `.inLove` flags on both lovers
  - Populate `lovedones` global table
  - Register damage split hook (if ConVar enabled)
  - Register health sync hook (if ConVar enabled)
  - Send `"inLove"` net message to affected players (for client-side visuals)
  - Send `"betrayedTraitor"` net message if applicable
  - Strip Cupid's weapon after pairing
  - Call `SendFullStateUpdate()`
- [ ] **1.2** Add round-reset cleanup for bot-created lovers
  - Hook into `TTTPrepareRound` to reset bot-side lover tracking
  - Ensure `targets` table in `createlovers.lua` is cleared each round
- [ ] **1.3** Test that human players still see correct UI (EPOP popups, halos, team colors) when bot Cupid creates lovers

### Phase 2 — Rewrite CreateLovers Behavior
- [ ] **2.1** Replace `RegisterRoleWeapon` usage with custom stateful behavior
  - Implement `FINDING_FIRST` → `FINDING_SECOND` → `LINKING` state machine
  - Handle both `ttt_cupid_forced_selflove` (self-pair) and normal two-target mode
  - Validate targets: alive, not public role, not already paired
- [ ] **2.2** Implement intelligent target selection
  - Score targets by: isolation, distance, same-team preference, witness count
  - Exclude players with `GetSubRoleData().isPublicRole` (matching addon logic)
  - Prefer targets the bot can reach before the time limit
- [ ] **2.3** Implement time pressure escalation
  - Track `ttt_cupid_timelimit_magic` countdown
  - Increase `startChance` and `engageDistance` as deadline approaches
  - At 75%+ elapsed: accept any valid target, ignore witness checks
  - At 90%+ elapsed: fire at first visible valid player
- [ ] **2.4** Clear `targets` tracking table on `TTTPrepareRound`

### Phase 3 — Dynamic Behavior Tree
- [ ] **3.1** Define pre-link behavior tree (weapon phase)
  - Focus: CreateLovers as high priority, minimal combat (stay alive)
  - Include: Chatter, FightBack, Requests, CreateLovers, Restore, Investigate, Patrol
- [ ] **3.2** Define post-link behavior tree (combat phase)
  - Focus: Aggressive combat coordinated with lover
  - Include: Chatter, FightBack, Requests, ProtectLover, Restore, Minge, Stalk, Investigate, Patrol
- [ ] **3.3** Implement `GetTreeFor` chain override
  - Follow the Infected/Necromancer/SK pattern
  - Check `bot.inLove` or membership in `lovedones` table to determine phase
- [ ] **3.4** Add helper functions to `roles/cupid.lua`
  - `TTTBots.Cupid.IsCupidLinked(bot)` — has the bot completed lover pairing?
  - `TTTBots.Cupid.GetLover(bot)` — return the bot's lover partner
  - `TTTBots.Cupid.AreBothLoversAlive()` — are both lovers still alive?
  - `TTTBots.Cupid.GetTimeRemaining(bot)` — seconds until weapon is stripped
  - `TTTBots.Cupid.IsLover(ply)` — is this player a lover (`.inLove` check)?

### Phase 4 — New Behaviors
- [ ] **4.1** Create `behaviors/protectlover.lua`
  - Follow lover within ~200 units (like Bodyguard)
  - Disable avoidance when near lover (allow close proximity)
  - When lover is attacked → `SetAttackTarget(attacker, "LOVER_DEFEND", 4)`
  - When lover is low health → increase follow priority, prefer defensive positioning
- [ ] **4.2** Add `PlayerHurt` hook for lover defence
  - When a lover is hurt → find the other lover bot → assign attack target against the attacker
  - Priority: `PLAYER_REQUEST` (4) — same as Bodyguard defend
- [ ] **4.3** Enhance Stalk behavior for post-link phase
  - Override phase gate for Cupid lovers: allow stalking in all phases (like SK/Infected exemptions)
  - Prefer targets near both lovers (coordinate attack positioning)
- [ ] **4.4** Consider self-pairing decision logic
  - When `ttt_cupid_forced_selflove` is off, bot should still consider self-pairing as a strategic option
  - Factors: time remaining, number of visible targets, personality aggressiveness

### Phase 5 — Chatter Integration
- [ ] **5.1** Add 10 events to `chancesOf100` in `sv_chatter_events.lua`
  - `CupidCreatingLovers` (80), `CupidLoversFormed` (90), `CupidLoverDied` (95), `CupidLoverPanic` (70), `CupidTeamCoordinate` (50), `CupidVictory` (85), `CupidTimePressure` (75), `CupidBetrayedTraitor` (70), `CupidSpotted` (85), `CupidLoverSpotted` (70)
- [ ] **5.2** Add event triggers
  - `CupidCreatingLovers` — fired in CreateLovers behavior `OnStart`
  - `CupidLoversFormed` — fired after successful server-side `CreateLovers()` call
  - `CupidLoverDied` — `PlayerDeath` hook, check `.inLove` on victim
  - `CupidLoverPanic` — `PlayerHurt` hook, check if hurt player is bot's lover
  - `CupidTeamCoordinate` — periodic timer (every 30s) for lover team chat
  - `CupidVictory` — `TTTEndRound` hook, check if `TEAM_LOVER` won
  - `CupidTimePressure` — timer check in CreateLovers behavior
  - `CupidBetrayedTraitor` — `PlayerDeath` hook or team-change detection for traitors
  - `CupidSpotted` — witness event when non-cupid sees crossbow fire
  - `CupidLoverSpotted` — team-change detection by non-lovers
- [ ] **5.3** Create locale lines in `sh_chats.lua`
  - ~8-12 archetype-specific lines per event category
  - Cover all 10 archetypes: Default, Tryhard, Hothead, Stoic, Dumb, Nice, Bad, Teamer, Sus/Quirky, Casual
  - Cupid's pre-link chatter should be disguised (doesn't want to reveal role)
  - Post-link chatter should be coordinated and urgent
  - Non-cupid reactions should express confusion/concern about team switches
- [ ] **5.4** Add Cupid-specific LLM prompt context
  - Include Cupid role description in LLM system prompt when bot is Cupid
  - Include lover status, partner name, team composition
  - Enable natural language responses about the love mechanic

### Phase 6 — Morality/Suspicion Integration
- [ ] **6.1** Add evidence types to `SUSPICIONVALUES`
  - `CupidCrossbow` (5) — witnessed Cupid weapon fire at a player
  - `LoverTeamSwitch` (4) — observed player joining `TEAM_LOVER`
- [ ] **6.2** Add witness detection for Cupid crossbow usage
  - When a bot sees a player fire the cupid crossbow at someone → apply `CupidCrossbow` evidence
  - Hook into `EntityFireBullets` or `PlayerHurt` (crossbow fires invisible bullets)
- [ ] **6.3** Add lover-pair tactical awareness
  - `prioritizeLoverTarget()` in hostility policy: if bot identifies a lover, elevate targeting priority (2-for-1 value)
  - Bots with `KnowsLifeStates` should recognize the shared-death mechanic
- [ ] **6.4** Add traitor betrayal reaction
  - When a traitor teammate is moved to `TEAM_LOVER` → remove from ally perception, react with chatter

### Phase 7 — Non-Cupid Bot Awareness
- [ ] **7.1** Witness crossbow fire detection
  - Use `EntityFireBullets` hook to detect when Cupid crossbow is fired
  - Nearby bots (within line of sight) should observe and react
  - Generate suspicion evidence + potential callout
- [ ] **7.2** Team change detection
  - Monitor `Player:GetTeam()` changes during round
  - When a player switches from any team to `TEAM_LOVER` → bots notice
  - Trigger appropriate chatter and suspicion updates
- [ ] **7.3** Tactical intelligence for lover-pair handling
  - Bots should understand that lovers share fate
  - Prioritize attacking the weaker/more exposed lover
  - If damage split is active: focus fire on one lover (damage is shared anyway)
  - If one lover is dead: remaining lover dies in 5s — no need to attack, focus elsewhere
- [ ] **7.4** Post-death awareness
  - When a lover dies → bots near the surviving lover should know they'll die soon
  - Don't waste ammo/risk on the surviving lover (they have 5 seconds to live)
  - React with appropriate chatter ("they're already dead, the love curse got them")

### Phase 8 — Testing & Polish
- [ ] **8.1** Test bot Cupid can successfully create lover pair (both weapons if supported)
- [ ] **8.2** Test post-link behavior: lovers fight together, defend each other
- [ ] **8.3** Test time pressure: bot escalates urgency near weapon deadline
- [ ] **8.4** Test self-love mode (`ttt_cupid_forced_selflove`)
- [ ] **8.5** Test non-cupid bot reactions to witnessing crossbow fire
- [ ] **8.6** Test traitor bot reaction to teammate being pulled to `TEAM_LOVER`
- [ ] **8.7** Test shared death: surviving lover bot knows they're doomed
- [ ] **8.8** Test all chatter events fire correctly with appropriate timing
- [ ] **8.9** Test LLM integration produces contextually appropriate responses
- [ ] **8.10** Test round reset: all cupid state properly cleaned up between rounds
- [ ] **8.11** Test with `ttt_cupid_joins_team_lovers = 1` (Cupid joins team)
- [ ] **8.12** Test with `ttt_cupid_damage_split_enabled = 0` (no damage split)
- [ ] **8.13** Test multiple concurrent lover pairs (if server allows multiple Cupids)
- [ ] **8.14** Performance test: ensure no tick-rate impact from new hooks/timers

---

## Appendix A: File Change Map

| File | Action | Description |
|------|--------|-------------|
| `roles/cupid.lua` | **Major rewrite** | Add helper functions, `GetTreeFor` override, two behavior trees, lifecycle hooks |
| `behaviors/createlovers.lua` | **Major rewrite** | Replace `RegisterRoleWeapon` with custom stateful behavior, server-side pairing |
| `behaviors/protectlover.lua` | **New file** | Lover defense/follow behavior |
| `components/sv_inventory.lua` | Minor update | Verify `GetLoversGun()` still needed or can be removed |
| `components/chatter/sv_chatter_events.lua` | Addition | 10 new events in `chancesOf100`, hook triggers |
| `locale/en/sh_chats.lua` | Addition | ~100-120 new locale lines for 10 Cupid events |
| `components/morality/sv_morality_suspicion.lua` | Addition | 2 new evidence types |
| `components/morality/sv_morality_hostility.lua` | Addition | Lover-pair tactical targeting function |
| `components/morality/sv_morality.lua` | Minor | Wire in new lover-pair hooks |

## Appendix B: Reference Implementation Patterns

| Feature | Reference Role | File |
|---------|---------------|------|
| Dynamic `GetTreeFor` | Infected, Necromancer, SK | `roles/infected.lua`, `roles/necromancer.lua`, `roles/serialkiller.lua` |
| Partner follow/defend | Bodyguard | `behaviors/bodyguard.lua`, `roles/bodyguard.lua` |
| Melee-range engagement | Infected Rush | `behaviors/infectedrush.lua` |
| Chatter events for roles | Spy, Necromancer, SK | `components/chatter/sv_chatter_events.lua` |
| Locale archetype lines | All roles | `locale/en/sh_chats.lua` |
| Suspicion evidence types | Cursed, Infected | `components/morality/sv_morality_suspicion.lua` |
| Round cleanup hooks | All roles | `TTTPrepareRound` handlers throughout codebase |
| Helper utility functions | Necromancer | `roles/necromancer.lua` (`IsNecroZombie`, `GetNecroMaster`) |

## Appendix C: Cupid Addon Bugs / Concerns (Addon-Side)

These are issues in the Cupid addon itself (not the bot integration) worth noting:

| Issue | Location | Description |
|-------|----------|-------------|
| `self` reference in `TakeDamage` | `sh_cupid_love_handler.lua:9` | `lovedones[2]:TakeDamage(999,killer,self)` — `self` is undefined in a hook callback, will error |
| Global `lovedones` table | `sh_cupid_love_handler.lua:3` | Single global table limits to one lover pair |
| `!` negation operator | Throughout | Uses `!` instead of `not` — works in GLua but non-standard |
| `CurTime()%1 == 0` check | `sh_cupid_love_handler.lua:144` | Float modulo check will virtually never equal exactly 0 |
| Missing `AddCSLuaFile` for shared file | `sh_cupid_love_handler.lua` | May not be sent to clients properly depending on load order |
| `tempOwner` local scope | `weapon_ttt2_cupidscrossbow/shared.lua` | `tempOwner` defined in `PrimaryAttack` scope but used across calls — may be nil on second call if function re-enters |
| Network string duplication | Both weapon files | Both `weapon_ttt2_cupidsbow` and `weapon_ttt2_cupidscrossbow` call `util.AddNetworkString` for the same strings |
| `m_bApplyingDamage` global | `sh_cupid_love_handler.lua` | Used as a re-entrancy guard but is a global variable — could conflict with other addons |
