# Clown / Killer Clown Role — TTT2 Bot Integration Design & Code Analysis

> **Author:** AI Analysis  
> **Date:** 2026-03-10  
> **Target Codebase:** TTT2-Bots-2 (branch: `development`)  
> **Role Addon:** `ttt2_clown_role_2605758514`  
> **Status:** Partial implementation exists — functional but behaviorally shallow; major enhancement opportunities identified

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Role Mechanics Deep Dive](#2-role-mechanics-deep-dive)
3. [Current Bot Implementation Audit](#3-current-bot-implementation-audit)
4. [Gap Analysis](#4-gap-analysis)
5. [Recommended Architecture](#5-recommended-architecture)
6. [File-by-File Implementation Plan](#6-file-by-file-implementation-plan)
7. [Behavior Tree Design](#7-behavior-tree-design)
8. [Dynamic Tree Switching (Clown → Killer Clown)](#8-dynamic-tree-switching-clown--killer-clown)
9. [ClownCoordinator — Mid-Round Transformation Detection](#9-clowncoordinator--mid-round-transformation-detection)
10. [Perception Layer Integration](#10-perception-layer-integration)
11. [Morality & Combat Integration](#11-morality--combat-integration)
12. [Personality & Trait Integration](#12-personality--trait-integration)
13. [Chatter & Locale Additions](#13-chatter--locale-additions)
14. [Buyable Equipment Design](#14-buyable-equipment-design)
15. [Round Awareness & Phase-Gated Behavior](#15-round-awareness--phase-gated-behavior)
16. [Other Bot Reactions to the Clown](#16-other-bot-reactions-to-the-clown)
17. [Edge Cases & Failure Modes](#17-edge-cases--failure-modes)
18. [Testing Strategy](#18-testing-strategy)
19. [Implementation Priority & Phasing](#19-implementation-priority--phasing)
20. [Implementation Checklist](#20-implementation-checklist)

---

## 1. Executive Summary

### What Is the Clown?

The Clown is a **two-phase deception/survival role** unique in TTT2. It operates across two distinct sub-roles:

| Phase | Role | Team | Can Deal Damage? | Win Condition |
|-------|------|------|-----------------|---------------|
| **Phase 1** | Clown (`ROLE_CLOWN`) | `TEAM_CLOWN` | ❌ No player damage | Survive until only one team remains |
| **Phase 2** | Killer Clown (`ROLE_KILLERCLOWN`) | `TEAM_CLOWN` (inherits the last surviving team visually) | ✅ Yes, with bonus damage | Kill all remaining players |

**The transformation is automatic and server-driven.** When the last death causes only one team to remain alive (excluding clowns and `preventWin` roles), every living Clown is converted to Killer Clown with a confetti/sound effect broadcast. The Clown then has the traitor shop, optional bonus damage, optional health restoration, and optional starting credits.

### Why This Role Is Interesting for Bots

The Clown is one of the most strategically deep jester-like roles because:

1. **It has a pre-transformation survival phase** where the bot must act harmless and jester-like
2. **It has a post-transformation combat phase** where the bot must become an aggressive solo killer
3. **The transformation is externally triggered** — the bot doesn't control when it happens
4. **Traitors see the Clown as a Jester** via `TTT2SpecialRoleSyncing` — bots on the traitor team should behave accordingly
5. **The Clown is immune to player damage pre-transformation** — creating unique tactical dynamics where bots should not waste ammo
6. **Post-transformation, the Killer Clown is a public threat** — all other bots should react aggressively

This creates a bot behavior profile that requires **two completely different playstyles in the same round**, connected by a mid-round transformation event. This is analogous to the Amnesiac pattern but with combat instead of corpse-seeking.

### Current State in TTT2-Bots-2

The bot mod already has:
- **`roles/clown.lua`** — Basic role registration with a passive Jester-like behavior tree
- **`roles/killerclown.lua`** — Basic role registration with a FightBack-only tree
- **No ClownCoordinator** — No mid-round transformation detection
- **No dynamic tree switching** — No `GetTreeFor` override to swap trees on conversion
- **No chatter** — No Clown-specific locale entries
- **No perception layer integration** — No handling for traitors seeing Clown as Jester
- **No buyable equipment** — Killer Clown has an empty buyable list despite having traitor shop access
- **No personality/trait integration** — No Clown-specific personality modifiers
- **No suspicion hooks** — No `TTTBotsModifySuspicion` to prevent bots from suspecting the Clown

### Critical Finding

**The current implementation is functional but behaviorally flat.** A bot assigned the Clown role will wander passively, and if transformed into a Killer Clown, will only react when attacked. It lacks:
- Proactive survival behaviors (blending with groups, acting suspicious-but-harmless)
- Transformation awareness (clearing stale behavior state, immediate aggression shift)
- Post-transformation hunting behaviors (stalking, aggressive target selection)
- Social deception (acting like a real Jester to confuse traitors)
- Equipment usage (buying weapons from the traitor shop post-transformation)

**The bot does NOT know it transformed.** Without a `TTT2UpdateSubrole` hook or `GetTreeFor` chain override, the behavior tree does not dynamically switch when the Clown becomes a Killer Clown.

---

## 2. Role Mechanics Deep Dive

### 2.1 Clown Role Definition (`clown/shared.lua`)

```lua
-- Key properties:
self.color = Color(245, 48, 155, 255)       -- Hot pink
self.abbr = "clo"
self.surviveBonus = 2                         -- Bonus for surviving while others die
self.scoreKillsMultiplier = 0                 -- No kill scoring
self.scoreTeamKillsMultiplier = 0             -- No teamkill scoring
self.preventWin = false                       -- Does NOT prevent the round from ending
self.defaultTeam = TEAM_CLOWN                 -- Custom team
self.defaultEquipment = SPECIAL_EQUIPMENT

-- ConVars:
pct = 0.15          -- 15% chance per player
maximum = 1          -- Max 1 clown per round
minPlayers = 5       -- Requires 5+ players
credits = 1          -- Starts with 1 credit (but has SHOP_DISABLED)
```

**Key observations:**
- `preventWin = false` — This is critical. The Clown does NOT prevent the round from ending. The `KillerClownChecks` function manually detects when only one non-clown team remains and triggers transformation before the round actually ends.
- `shopFallback = SHOP_DISABLED` — The Clown has NO shop access pre-transformation.
- `credits = 1` — Has 1 credit but can't spend it. This credit carries over to Killer Clown form.

### 2.2 Killer Clown Role Definition (`killerclown/shared.lua`)

```lua
self.color = Color(245, 48, 155, 255)
self.abbr = "kcl"
self.surviveBonus = 0
self.scoreKillsMultiplier = 2                 -- Double kill scoring
self.scoreTeamKillsMultiplier = -8            -- Heavy teamkill penalty (shouldn't happen as solo)
self.preventWin = false
self.defaultTeam = TEAM_CLOWN
self.notSelectable = true                      -- Cannot be assigned at round start
self.shopFallback = SHOP_TRAITOR               -- Has full traitor shop access

-- Role inheritance:
roles.SetBaseRole(self, ROLE_CLOWN)            -- Inherits from Clown base
```

**Key observations:**
- `notSelectable = true` — Killer Clown only appears via transformation
- `SHOP_TRAITOR` — Full traitor shop access, meaning the bot can buy weapons
- `ScalePlayerDamage` hook applies `ttt2_clown_damage_bonus` multiplier

### 2.3 Damage Blocking System (`shared_function.lua`)

The Clown uses a shared damage framework with Swapper and Beggar:

```lua
-- PlayerTakeDamage hook: "ClownNoDamage"
-- Blocks ALL player-to-player damage involving a Clown:
--   TakeNoDamage(): Clown cannot be hurt by other players
--   DealNoDamage(): Clown cannot hurt other players

-- EntityTakeDamage hook: "ClownEntityNoDamage"  
-- Blocks entity damage and environmental damage based on ConVars:
--   ttt2_clown_entity_damage (default: 1 = allowed)
--   ttt2_clown_environmental_damage (default: 1 = allowed)
```

**Critical implication for bots:**
- Pre-transformation, the Clown bot should NEVER attempt to attack other players (damage is always 0)
- Pre-transformation, other bots should NOT waste ammo shooting a Clown (damage is always 0)
- The Clown CAN take environmental damage (fall, fire, explosions, drowning) unless the ConVar is disabled
- This means a Clown bot should avoid environmental hazards as a survival priority

### 2.4 Transformation Trigger (`KillerClownChecks`)

The transformation logic runs inside a `DoPlayerDeath` hook:

```lua
-- 1. On any player death, check if a living Clown exists
-- 2. Count all alive teams, EXCLUDING:
--    - The Clown's own team
--    - Roles with preventWin = true
-- 3. If only ONE team remains alive → Transform ALL living Clowns
-- 4. Transformation:
--    a. SetRole(ROLE_KILLERCLOWN, team)  -- Inherits the last surviving team
--    b. SendFullStateUpdate()
--    c. UpdateTeam(team)                 -- Visually joins the remaining team
--    d. Optional health restoration
--    e. Net broadcast: confetti + sound effect
--    f. HUD message: "Kill them all!"
```

**Critical findings:**
- The Clown **joins the team of the last surviving faction** — this is for visual/deceptive purposes
- `SendFullStateUpdate()` is called TWICE (likely a bug in the addon, but harmless)
- The transformation fires via `DoPlayerDeath`, not `TTT2UpdateSubrole` directly — but `SetRole()` internally triggers `TTT2UpdateSubrole`
- Health restoration is controlled by `ttt2_clown_health_on_transform` (default 0 = no change)
- Activation credits controlled by `ttt2_clown_activation_credits` (default 1)

### 2.5 Traitor Perception System

```lua
-- TTT2SpecialRoleSyncing hook: "TTT2RoleClown"
-- For traitor-team players looking at the Clown:
--   - If observer is NOT on TEAM_JESTER: Clown appears as ROLE_JESTER
--   - If observer IS on TEAM_JESTER: Clown appears as ROLE_CLOWN (with TEAM_JESTER)

-- TTT2ModifyRadarRole hook: "TTT2ModifyRadarRoleClown"
-- Traitors using radar see the Clown as ROLE_JESTER
```

**Implication for bot perception:** Traitor bots should perceive the Clown as a Jester. Since bots already avoid attacking Jesters (via `NeutralOverride`), this should work passively — BUT the perception layer needs to be explicitly aware of this masquerading.

### 2.6 Killer Clown Damage Bonus

```lua
-- ScalePlayerDamage hook: "KillerClownDamageScale"
-- If attacker is ROLE_KILLERCLOWN: damage *= (1 + ttt2_clown_damage_bonus)
-- Default bonus: 0 (no extra damage)
```

This means the Killer Clown can potentially deal 2x–6x damage depending on server config. Bots should be aware of this when deciding whether to retreat or push.

---

## 3. Current Bot Implementation Audit

### 3.1 `roles/clown.lua` — Current State

```lua
-- Allied teams: TEAM_JESTER
-- Behavior tree: Chatter → Requests → Interact → Investigate → Minge → Decrowd → Patrol
-- Role data:
--   DefusesC4:       false
--   StartsFights:    false
--   CanCoordinate:   false
--   UsesSuspicion:   false
--   Team:            TEAM_CLOWN
--   KnowsLifeStates: true
--   NeutralOverride: true    ← Prevents other bots from attacking
--   LovesTeammates:  false
```

**Assessment:**
- ✅ `NeutralOverride = true` — Other bots won't target the Clown (correct)
- ✅ `StartsFights = false` — Clown won't try to attack (correct — damage blocked anyway)
- ✅ `UsesSuspicion = false` — Clown doesn't track suspicion (correct)
- ✅ `KnowsLifeStates = true` — Clown knows who's alive/dead (useful for transformation awareness)
- ❌ No `FightBack` in behavior tree — Even a jester-type should be able to flee from attacks
- ❌ No deception behaviors — Clown should act jester-like to maintain cover
- ❌ No survival-oriented behaviors — No `GroupUp` or `Follow` to stay near crowds (safety)
- ❌ No transformation-preparation behaviors — Could stockpile weapons for post-transformation
- ❌ Allied with `TEAM_JESTER` but NOT with `TEAM_CLOWN` — The KillerClown is `TEAM_CLOWN`, so other clowns aren't considered allies (minor — max 1 clown per round)
- ❌ No `RoleDescription` — Missing AI description for LLM/chatter context

### 3.2 `roles/killerclown.lua` — Current State

```lua
-- Allied teams: TEAM_JESTER, TEAM_CLOWN
-- Behavior tree: Chatter → FightBack → Requests → Interact → Investigate → Minge → Decrowd → Patrol
-- Role data:
--   DefusesC4:       false
--   StartsFights:    true
--   CanCoordinate:   true      ← Questionable — who does the solo killer coordinate with?
--   UsesSuspicion:   false
--   Team:            TEAM_CLOWN
--   KOSAll:          true      ← Attacks everyone
--   KOSedByAll:      false     ← Others DON'T automatically target the Killer Clown
--   NeutralOverride: false
--   KnowsLifeStates: true
--   LovesTeammates:  false
```

**Assessment:**
- ✅ `KOSAll = true` — Killer Clown attacks all non-allies (correct)
- ✅ `StartsFights = true` — Will proactively engage targets (correct)
- ❌ `KOSedByAll = false` — **This is WRONG.** The Killer Clown is a PUBLIC THREAT — everyone knows they transformed (confetti + sound + "Kill them all!" message). All bots should immediately KOS the Killer Clown.
- ❌ `CanCoordinate = true` — **Questionable.** The Killer Clown is a solo role with no teammates to coordinate with. Should be `false`.
- ❌ No `Stalk` behavior — The Killer Clown should actively hunt players, not just wander and fight back
- ❌ No `DoomguyHunt`-style dedicated hunting behavior — Should have aggressive target seeking
- ❌ No `BuyableWeapons` — Empty list despite having traitor shop access
- ❌ No `RoleDescription` — Missing AI description
- ❌ No dynamic damage awareness — Bot doesn't know it has bonus damage
- ❌ FightBack is the only proactive combat entry — Bot won't initiate attacks unless provoked

### 3.3 Missing Infrastructure

| Component | Status | Impact |
|-----------|--------|--------|
| `ClownCoordinator` (lib) | ❌ Missing | No transformation detection, no state cleanup, no chatter on transform |
| `GetTreeFor` chain override | ❌ Missing | Behavior tree doesn't switch when Clown → Killer Clown |
| `TTT2UpdateSubrole` hook | ❌ Missing | Bot doesn't know it transformed; stale behavior state persists |
| Perception layer entry | ❌ Missing | Traitor bots don't see Clown as Jester in the perception system |
| Chatter locale entries | ❌ Missing | No Clown-specific dialog lines |
| Personality trait | ❌ Missing | No `clown` trait in `sh_traits.lua` |
| Buyable equipment data | ❌ Missing | Killer Clown can't buy weapons from traitor shop |
| Suspicion hook | ❌ Missing | No `TTTBotsModifySuspicion` for Clown recognition |

---

## 4. Gap Analysis

### 4.1 Critical Gaps (Must Fix)

| # | Gap | Description | Impact |
|---|-----|-------------|--------|
| G-1 | **No tree switching on transform** | Bot continues using passive Clown tree after becoming Killer Clown | Killer Clown bot is completely passive — doesn't attack anyone |
| G-2 | **`KOSedByAll = false`** | Other bots don't automatically target the Killer Clown | Killer Clown walks around unbothered by other bots |
| G-3 | **No ClownCoordinator** | No detection of Clown→KillerClown transformation | No state cleanup, no chatter trigger, no evidence for witnesses |
| G-4 | **No behavior state reset** | Stale `lastBehavior`, `attackTarget`, evidence, suspicion after transform | Bot may get stuck in pre-transform behavior loops |

### 4.2 High-Impact Gaps

| # | Gap | Description | Impact |
|---|-----|-------------|--------|
| G-5 | **No proactive hunting** | Killer Clown tree has no `Stalk` or hunting behavior | Bot wanders aimlessly instead of actively seeking kills |
| G-6 | **No buyable equipment** | Empty buyable list for Killer Clown | Bot doesn't buy weapons despite having shop + credits |
| G-7 | **No pre-transform survival strategy** | Clown tree is generic patrol/investigate | Bot doesn't try to survive strategically |
| G-8 | **No chatter** | Zero Clown-specific dialog lines | Bot is silent during critical moments (transformation, kills, etc.) |

### 4.3 Enhancement Gaps

| # | Gap | Description | Impact |
|---|-----|-------------|--------|
| G-9 | **No perception integration** | Traitor bots use raw role data, not perception-aware check | Inconsistency with how traitors actually see the Clown in-game |
| G-10 | **No personality traits** | No Clown-specific personality modifiers | All Clown bots behave identically |
| G-11 | **No round awareness integration** | No phase-gated behavior changes | Clown doesn't adapt strategy based on round progress |
| G-12 | **No suspicion hook** | Bots that "cheat_know_jester" should avoid suspecting the Clown | Inconsistency with Jester suspicion behavior |
| G-13 | **No environmental damage awareness** | Clown bot doesn't avoid fall/fire/explosion hazards | Unnecessary deaths from avoidable environmental damage |

---

## 5. Recommended Architecture

### 5.1 Design Philosophy

The Clown bot should embody the **"Ticking Time Bomb"** archetype:

**Phase 1 (Clown): The Survivor**
- Act harmless, blend with crowds, mimic Jester behavior
- Avoid environmental hazards (the one thing that CAN kill you)
- Monitor round state — know when transformation is imminent
- Optionally: be subtly annoying (minge, crowbar) to make players hesitate to kill
- NEVER attempt to deal damage (it's blocked anyway)

**Phase 2 (Killer Clown): The Berserker**
- Immediate aggression — transformation is PUBLIC, there's no deception phase
- Buy equipment immediately if credits available
- Hunt the nearest/weakest target first
- Use damage bonus to overwhelm opponents
- No need for deception — everyone knows you're hostile

### 5.2 Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                  roles/clown.lua                         │
│  - Pre-transform tree (passive survival)                │
│  - Post-transform tree (aggressive hunting)             │
│  - GetTreeFor chain override for dynamic switching      │
│  - TTTBotsModifySuspicion hook                          │
│  - RoleDescription for LLM context                      │
│  - Personality-aware behavior selection                  │
├─────────────────────────────────────────────────────────┤
│                  roles/killerclown.lua                   │
│  - Corrected role data (KOSedByAll = true)              │
│  - RoleDescription for LLM context                      │
│  - BuyableWeapons for traitor shop                      │
├─────────────────────────────────────────────────────────┤
│                  lib/sv_clowncoordinator.lua             │
│  - TTT2UpdateSubrole hook for transform detection       │
│  - State cleanup (behavior, evidence, suspicion)        │
│  - Chatter triggers (transform, witness, reaction)      │
│  - Evidence injection for all bots                      │
│  - Transformation announcement for all alive bots       │
│  - Round cleanup                                        │
├─────────────────────────────────────────────────────────┤
│                  locale/en/sh_chats.lua (additions)     │
│  - ClownSurviving, ClownTransformed, ClownHunting       │
│  - KillerClownKill, KillerClownPanic                    │
│  - Witness: ClownTransformWitnessed                     │
│  - Traitor: TraitorSeesClown                            │
├─────────────────────────────────────────────────────────┤
│                  data/sv_default_buyables.lua            │
│  - KillerClown equipment entries                        │
├─────────────────────────────────────────────────────────┤
│                  lib/sv_perception.lua (minor addition)  │
│  - Clown → Jester perception for traitor bots           │
└─────────────────────────────────────────────────────────┘
```

---

## 6. File-by-File Implementation Plan

### 6.1 `roles/clown.lua` — Complete Rewrite

**Changes required:**
1. Add two behavior trees: `preTransformTree` and (reference to) `postTransformTree`
2. Implement `GetTreeFor` chain override for dynamic tree switching
3. Add `TTTBotsModifySuspicion` hook
4. Add `RoleDescription`
5. Improve pre-transform tree with survival behaviors
6. Add allied teams properly (`TEAM_CLOWN`)

### 6.2 `roles/killerclown.lua` — Major Corrections

**Changes required:**
1. Fix `KOSedByAll = true` (currently `false`)
2. Fix `CanCoordinate = false` (currently `true`)
3. Add aggressive hunting behavior tree
4. Add `BuyableWeapons` for traitor shop access
5. Add `RoleDescription`
6. Add `Stalk` and hunting behaviors to tree

### 6.3 `lib/sv_clowncoordinator.lua` — New File

**Responsibilities:**
1. Detect Clown → Killer Clown transformation via `TTT2UpdateSubrole`
2. Clear stale bot state (behavior, evidence, suspicion, attack targets)
3. Trigger transformation chatter on the transforming bot
4. Trigger witness chatter on all other alive bots
5. Inject evidence for all bots ("Clown has transformed!")
6. Set transition grace period for morality evaluation
7. Publish event on the event bus
8. Round cleanup

### 6.4 `locale/en/sh_chats.lua` — Additions

New chatter categories for Clown-specific situations.

### 6.5 `data/sv_default_buyables.lua` — Additions

Equipment buyable entries for Killer Clown using `SHOP_TRAITOR` fallback.

### 6.6 `lib/sv_perception.lua` — Minor Addition

Optional: Add Clown → Jester perception so traitor bots explicitly perceive the Clown as a Jester through the perception layer, consistent with the game's `TTT2SpecialRoleSyncing`.

---

## 7. Behavior Tree Design

### 7.1 Pre-Transformation Tree (Clown Phase)

The Clown's pre-transformation tree should prioritize **survival above all else**. Since the Clown cannot deal or receive player damage, the primary threats are:
- Environmental damage (fall, fire, explosion, drowning) if ConVar allows
- Getting stuck in dangerous positions
- Round ending before transformation triggers

```lua
local preTransformTree = {
    _prior.Chatter,          -- Social presence (maintain cover as "harmless")
    _prior.Requests,         -- Respond to requests (appear cooperative)
    _bh.Interact,            -- Interact with props (jester-like behavior)
    _prior.Restore,          -- Pick up weapons (stockpile for post-transform!)
    _prior.Investigate,      -- Investigate corpses/noises (appear innocent)
    _prior.Minge,            -- Crowbar minge (classic jester behavior)
    _bh.Decrowd,             -- Avoid crowded areas (survival — fewer enemies)
    _bh.Follow,              -- Follow players (blend in, stay near groups)
    _bh.GroupUp,             -- Group up with others (safety in numbers)
    _bh.Wander               -- Default fallback
}
```

**Design rationale:**
- `_prior.Restore` (GetWeapons, LootNearby, UseHealthStation) is included because weapons picked up pre-transform carry over to Killer Clown form. A smart Clown should arm itself while harmless.
- `_prior.Minge` is included for the "annoying but harmless" jester archetype.
- `Follow` and `GroupUp` encourage social blending — a Clown near other players is less likely to die from environmental hazards and more likely to witness deaths (transformation trigger).
- No `FightBack` — the Clown literally cannot fight. Including it would waste cycles trying to attack blocked targets.
- No `Stalk` — stalking implies intent to kill, which the Clown cannot do.

### 7.2 Post-Transformation Tree (Killer Clown Phase)

The Killer Clown tree should be **maximally aggressive** — similar to Doomguy or a late-game Serial Killer.

```lua
local postTransformTree = {
    _prior.Chatter,          -- Callouts and taunts
    _prior.FightBack,        -- React to immediate combat (AttackTarget, SeekCover)
    _bh.Stalk,               -- Actively hunt isolated targets
    _prior.Requests,         -- Handle requests (mostly ignore — killing time)
    _prior.Restore,          -- Grab weapons/health/ammo
    _bh.Interact,            -- Interact with environment
    _bh.Wander               -- Fallback when no targets found
}
```

**Design rationale:**
- `Stalk` is HIGH priority — the Killer Clown must actively hunt targets
- `FightBack` above `Stalk` — respond to immediate threats first, then hunt
- No `Investigate` — the Killer Clown doesn't care about evidence
- No `Minge` — no time for games, must kill
- No `Deception` — transformation is PUBLIC, everyone knows
- No `Patrol` priority group (just `Wander`) — we want the bot moving aggressively, not casually patrolling
- `Restore` kept for weapon/health management between kills

### 7.3 Tree Comparison Matrix

| Behavior | Pre-Transform (Clown) | Post-Transform (Killer Clown) | Rationale |
|----------|----------------------|-------------------------------|-----------|
| Chatter | ✅ | ✅ | Social presence in both phases |
| FightBack | ❌ | ✅ | Can't fight pre-transform; must fight post-transform |
| Stalk | ❌ | ✅ | No kill intent pre-transform; core mechanic post-transform |
| Requests | ✅ | ✅ (lower priority) | Cooperative pre-transform; mostly ignored post-transform |
| Investigate | ✅ | ❌ | Appear innocent pre-transform; irrelevant post-transform |
| Minge | ✅ | ❌ | Jester cover pre-transform; no time post-transform |
| Restore | ✅ | ✅ | Stockpile pre-transform; maintain loadout post-transform |
| Follow/GroupUp | ✅ | ❌ | Safety pre-transform; hunting solo post-transform |
| Interact | ✅ | ✅ | Environmental interaction in both phases |
| Wander | ✅ | ✅ (fallback) | Default movement in both phases |
| Deception | ❌ | ❌ | Not deceptive in either phase (jester-like, then public threat) |

---

## 8. Dynamic Tree Switching (Clown → Killer Clown)

### 8.1 Pattern: `GetTreeFor` Chain Override

Following the established pattern from `infected.lua`, `serialkiller.lua`, `necromancer.lua`, and `amnesiac.lua`:

```lua
-- In roles/clown.lua:
local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor

function TTTBots.Behaviors.GetTreeFor(bot)
    if not IsValid(bot) then return nil end

    -- Intercept for both Clown and Killer Clown roles
    local roleString = bot:GetRoleStringRaw()

    if roleString == "clown" then
        return preTransformTree
    end

    if roleString == "killerclown" then
        return postTransformTree
    end

    return _origGetTreeFor(bot)
end
```

**Why this works:**
- `GetTreeFor()` is called every tick by `RunTreeOnBots()`
- When `TTT2UpdateSubrole` fires and changes the role from Clown to Killer Clown, `GetRoleStringRaw()` immediately returns `"killerclown"`
- The next tick, the tree switches to `postTransformTree`
- No explicit "transformation event" needed in the tree code — it's reactive to game state

### 8.2 Chain Ordering Consideration

Multiple roles use the `GetTreeFor` chain pattern. The chain is built by each role file storing `_origGetTreeFor` at load time. Since role files are loaded via `IncludeDirectory("tttbots2/roles")` in alphabetical order:

```
amnesiac.lua → ... → clown.lua → ... → infected.lua → ... → 
killerclown.lua → ... → necromancer.lua → ... → serialkiller.lua
```

The chain resolves correctly because each file:
1. Stores the current `GetTreeFor` as `_origGetTreeFor`
2. Defines a new `GetTreeFor` that only intercepts its own role
3. Falls through to `_origGetTreeFor` for all other roles

**Important:** The `GetTreeFor` override should be in `clown.lua` only (handling both `"clown"` and `"killerclown"` strings), NOT in `killerclown.lua`. This avoids double-chaining and keeps transformation logic co-located.

---

## 9. ClownCoordinator — Mid-Round Transformation Detection

### 9.1 Purpose

The ClownCoordinator detects the Clown → Killer Clown transformation event and handles all bot-side consequences:

1. **State cleanup** for the transforming bot
2. **Chatter triggers** for the transformed bot and all witnesses
3. **Evidence injection** for all alive bots
4. **Event bus publication** for other systems to react

### 9.2 Implementation Design

```lua
-- lib/sv_clowncoordinator.lua

-- Hook: TTT2UpdateSubrole
-- Trigger: oldSubrole == ROLE_CLOWN and newSubrole == ROLE_KILLERCLOWN

-- On transformation:
-- 1. Set transition grace period (2 seconds)
-- 2. Clear stale state:
--    a. bot.lastBehavior = nil
--    b. bot.attackTarget = nil
--    c. Reset suspicion (morality component)
--    d. Clear evidence entries
--    e. Clear behaviorState for "Stalk", "Follow", "GroupUp", etc.
-- 3. Fire chatter: "ClownTransformed" on the bot
-- 4. For all other alive bots:
--    a. Fire chatter: "ClownTransformWitnessed" with {player = clown:Nick()}
--    b. Inject evidence: "CLOWN_TRANSFORMED" pointing to the Killer Clown
--    c. Request attack target if the bot is aggressive (traitor, detective, etc.)
-- 5. Publish event: "CLOWN_TRANSFORMED"
```

### 9.3 Key Design Decisions

**Q: Should other bots immediately KOS the Killer Clown?**
A: Yes. The transformation is broadcast to ALL players (confetti + sound + HUD message). Every player in the game knows. Setting `KOSedByAll = true` handles this globally — the morality system will naturally target the Killer Clown.

**Q: Should traitor bots react differently?**
A: Yes. Traitors previously saw the Clown as a Jester (harmless). The transformation reveals the truth. Traitor bots should update their perception and potentially re-evaluate their strategy if the Killer Clown is now a threat to their remaining enemies AND to them.

**Q: Should the ClownCoordinator handle equipment buying?**
A: No. Equipment buying should be handled by the standard `sv_buyables.lua` system. The Killer Clown's `BuyableWeapons` list + credits system handles this automatically.

---

## 10. Perception Layer Integration

### 10.1 Current State

The perception layer (`sv_perception.lua`) currently only handles Spy ↔ Traitor asymmetric perception. The Clown's disguise as Jester to traitors is handled by the game's `TTT2SpecialRoleSyncing` hook, which the perception layer is unaware of.

### 10.2 Recommended Approach

**Option A: Extend `sv_perception.lua`** (Recommended)

Add Clown → Jester perception for traitor observers:

```lua
-- In IsPerceivedAlly override or a new clown-specific block:
-- If observer is on TEAM_TRAITOR and target is ROLE_CLOWN:
--   → Perceive as Jester (neutral, don't attack)
-- After transformation (ROLE_KILLERCLOWN):
--   → Perceive as enemy (KOSAll handles this)
```

This ensures that traitor bots using `TTTBots.Perception.IsPerceivedAlly()` will correctly treat the Clown as a non-threat, matching the in-game visual perception.

**Option B: Rely on `NeutralOverride`** (Current — Simpler)

The current `NeutralOverride = true` already prevents bots from attacking the Clown. Since traitors can't damage the Clown anyway (damage is blocked), the perception layer integration is a **polish enhancement** rather than a critical fix.

**Recommendation:** Implement Option B for Phase 1, Option A for Phase 2. The `NeutralOverride` already provides correct behavior. The perception integration adds realism but isn't functionally necessary.

---

## 11. Morality & Combat Integration

### 11.1 Pre-Transformation: Hostility Prevention

The `preventAttack` function in `sv_morality_hostility.lua` already handles `NeutralOverride`:

```lua
local function preventAttack(bot)
    local attackTarget = bot.attackTarget
    if not IsValid(attackTarget) then return end
    local role = TTTBots.Roles.GetRoleFor(attackTarget)
    if not role then return end
    local isNeutral = role:GetNeutralOverride()
    if isNeutral then
        Arb.RequestClearTarget(bot, "PREVENT_NEUTRAL", PRI.ROLE_HOSTILITY)
    end
end
```

Since the Clown has `NeutralOverride = true`, this already works. ✅

### 11.2 Post-Transformation: Immediate Hostility

Setting `KOSedByAll = true` on the Killer Clown role data triggers the hostility system:

- All bots will see the Killer Clown as a valid target
- The morality system will request attack on sight
- No suspicion buildup needed — immediate KOS

### 11.3 Suspicion Hook

Add a `TTTBotsModifySuspicion` hook to suppress suspicion accumulation on the Clown (pre-transformation), consistent with the Jester/Swapper pattern:

```lua
hook.Add("TTTBotsModifySuspicion", "TTTBots.clown.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    local role = target:GetRoleStringRaw()
    if role == "clown" then
        -- If the bot "cheats" to know jesters, reduce suspicion
        if TTTBots.Lib.GetConVarBool("cheat_know_jester") then
            return mult * 0.1  -- Nearly zero suspicion
        end
    end
end)
```

---

## 12. Personality & Trait Integration

### 12.1 Clown Personality Traits

Add to `data/sh_traits.lua`:

```lua
-- Clown-specific traits:
-- "theatrical"  — More likely to minge, use voice commands, be social
-- "calculated"  — More likely to group up, stockpile weapons, play safe
```

These traits would influence the pre-transformation behavior:
- **Theatrical** Clowns: More minging, more chatting, more jester-like behavior
- **Calculated** Clowns: More weapon stockpiling, more strategic positioning, more group-following

### 12.2 Archetype Influence on Post-Transformation

After transformation, personality should influence hunting style:

| Archetype | Post-Transform Behavior |
|-----------|------------------------|
| Hothead | Rush nearest target immediately, no caution |
| Tryhard | Methodically hunt weakest target first, use cover |
| Cautious | Buy equipment first, then hunt from advantageous positions |
| Default | Standard stalk-and-attack pattern |

---

## 13. Chatter & Locale Additions

### 13.1 New Chatter Categories

The following chatter categories should be added to `locale/en/sh_chats.lua`:

#### Pre-Transformation (Clown Phase)

| Category | Priority | When | Description |
|----------|----------|------|-------------|
| `ClownRoundStart` | NORMAL | Round begins | Clown acknowledges their role |
| `ClownSurviving` | LOW | Periodic (every ~60s) | Clown comments on surviving |
| `ClownWitnessedDeath` | NORMAL | When a player dies | Clown reacts to death (transformation getting closer) |
| `ClownNearTransform` | IMPORTANT | When 2 teams left → 1 death away | Anticipation of transformation |
| `ClownEnvironmentalDanger` | NORMAL | Near fire/heights | Comments about environmental threats |

#### Transformation Event

| Category | Priority | When | Description |
|----------|----------|------|-------------|
| `ClownTransformed` | CRITICAL | Bot transforms into Killer Clown | "Kill them all!" type callout |
| `ClownTransformWitnessed` | IMPORTANT | Other bots witness transformation | Reaction to seeing confetti/hearing sound |
| `TraitorSeesClownTransform` | IMPORTANT | Traitor bot witnesses transformation | Traitor-specific reaction (they thought it was a Jester) |

#### Post-Transformation (Killer Clown Phase)

| Category | Priority | When | Description |
|----------|----------|------|-------------|
| `KillerClownHunting` | NORMAL | Stalk behavior active | Taunting while hunting |
| `KillerClownKill` | IMPORTANT | Killer Clown kills someone | Post-kill taunt |
| `KillerClownTakingDamage` | NORMAL | Damaged by enemy | Reaction to being hurt |
| `KillerClownBuyingEquipment` | LOW | Buying from shop | Comments while shopping |
| `KillerClownLastTarget` | CRITICAL | Only one enemy remains | Final target callout |

### 13.2 Example Lines

```lua
-- ClownRoundStart
"Time to survive..."
"Let's see how long I can last"
"I just need to wait them out"
"The show must go on!"

-- ClownTransformed
"IT'S SHOWTIME!"
"Surprise! Miss me?"
"The clown has arrived! Run."
"HONK HONK! Time to die!"
"Kill them all!"

-- ClownTransformWitnessed
"Oh no... the clown transformed!"
"THE CLOWN! Everyone focus the clown!"
"That's a Killer Clown now, watch out!"
"KOS the clown! They've transformed!"

-- TraitorSeesClownTransform
"Wait, that wasn't a Jester?!"
"The Jester was a CLOWN all along!"
"That's not good... the clown is loose"

-- KillerClownHunting
"Here I come..."
"You can't hide from me"
"One by one..."
"The show's not over yet"

-- KillerClownKill
"Another one down!"
"That's what you get!"
"The audience is shrinking!"
"HONK!"
```

---

## 14. Buyable Equipment Design

### 14.1 Killer Clown Equipment Strategy

The Killer Clown has `SHOP_TRAITOR` fallback, giving access to the full traitor shop. Recommended buyable priorities:

```lua
-- Add to data/sv_default_buyables.lua:
-- Condition: bot:GetRoleStringRaw() == "killerclown"

-- Priority 1: Weapons (most impactful)
"weapon_ttt_ak47"         -- Reliable assault rifle
"weapon_ttt_m16"          -- Good at range
"weapon_ttt_shotgun"      -- Devastating with damage bonus

-- Priority 2: Utility
"weapon_ttt_health_station" -- If health was set low on transform
"weapon_ttt_knife"        -- Silent kills

-- Priority 3: Tactical
"weapon_ttt_c4"           -- Area denial
"weapon_ttt_flaregun"     -- Fire damage
```

### 14.2 Credit Management

- The Clown starts with 1 credit (from Clown `conVarData.credits`)
- Killer Clown gets `ttt2_clown_activation_credits` additional credits (default: 1)
- Total: 2 credits typically available at transformation
- The buyable system should prioritize weapon purchases first

---

## 15. Round Awareness & Phase-Gated Behavior

### 15.1 Pre-Transformation Phase Awareness

The Clown doesn't need traditional phase awareness (EARLY/MID/LATE/OVERTIME) because its behavior doesn't change based on round time — it changes based on **team count**. However, the Clown's awareness of impending transformation is valuable:

**Transformation Proximity Detection:**
```lua
-- Count alive teams (excluding clowns and preventWin roles)
-- If teams == 2: Transformation is close — heighten alertness
-- If teams == 1: Transformation SHOULD have happened already
```

This can be used to:
1. Fire anticipation chatter ("It's almost time...")
2. Move toward weapon-dense areas (prepare for combat)
3. Position near the surviving team (to be close when hunting begins)

### 15.2 Post-Transformation Phase Awareness

After transformation, the Killer Clown benefits from standard round awareness:
- **Few enemies remaining:** More aggressive, less cautious
- **Many enemies remaining:** More tactical, use cover
- **Low health:** Prioritize health station or retreat

---

## 16. Other Bot Reactions to the Clown

### 16.1 Innocent Bots

**Pre-transformation:**
- Should NOT attack the Clown (damage blocked anyway + NeutralOverride)
- May investigate the Clown's identity via role checker (if available)
- Should treat Clown as neutral/harmless

**Post-transformation:**
- IMMEDIATELY KOS the Killer Clown (KOSedByAll = true)
- Prioritize the Killer Clown as a target (it's a solo threat to everyone)
- Call out the Killer Clown's position
- Group up against the threat

### 16.2 Traitor Bots

**Pre-transformation:**
- See the Clown as a Jester (via `TTT2SpecialRoleSyncing`)
- Should NOT attack (waste of time + NeutralOverride)
- May use the Clown as bait (position near clown to draw innocents)

**Post-transformation:**
- The Killer Clown is now hostile to everyone, including traitors
- Traitors should KOS the Killer Clown
- Traitors should re-evaluate strategy (a new enemy just appeared)
- Possible temporary alliance with innocents against the Killer Clown (not mechanically supported but interesting for chatter)

### 16.3 Detective/Police Bots

**Pre-transformation:**
- Use role checker on the Clown to confirm identity
- May call out the Clown's role to the group
- Should NOT attack (NeutralOverride)

**Post-transformation:**
- IMMEDIATELY KOS the Killer Clown
- Use DNA scanner on Killer Clown's victims
- Rally other players against the threat

---

## 17. Edge Cases & Failure Modes

### 17.1 Multiple Clowns

The addon limits to `maximum = 1` Clown per round. However, if the server overrides this:
- All Clowns transform simultaneously
- The `KillerClownChecks` function iterates all players and transforms ALL living Clowns
- The bot system handles this correctly because each bot independently gets its tree switched

### 17.2 Clown Dies Before Transformation

- The Clown can die from environmental damage (fall, fire, etc.)
- If the Clown dies, `KillerClownChecks` won't find a living Clown and no transformation occurs
- This is correct behavior — no special handling needed
- The ClownCoordinator should handle this gracefully (no transformation event = no action)

### 17.3 Round Ends Before Transformation

- If the round ends naturally (timer, last non-clown team wins), the Clown simply loses
- No transformation occurs
- The Clown's `preventWin = false` means it doesn't extend the round

### 17.4 Transformation During Active Combat

- If another bot is in combat when the Clown transforms, the bot needs to handle the new threat
- `KOSedByAll = true` ensures that the morality system will eventually target the Killer Clown
- The existing `RequestAttackTarget` system handles priority-based target switching

### 17.5 Environmental Damage Death as Clown

- The Clown takes environmental damage unless `ttt2_clown_environmental_damage = 0`
- Bots don't have explicit environmental awareness (avoiding fire, heights, etc.)
- This is a known limitation — the standard locomotor avoidance handles some cases
- Future enhancement: Add an environmental avoidance behavior to the pre-transform tree

### 17.6 `SetRole` Team Parameter Edge Case

The transformation code does:
```lua
ply:SetRole(ROLE_KILLERCLOWN, team)
```
Where `team` is the LAST surviving team. This means the Killer Clown's `GetTeam()` will return that team (e.g., `TEAM_TRAITOR` or `TEAM_INNOCENT`), NOT `TEAM_CLOWN`.

**Impact on bots:** The `GetRoleStringRaw()` still returns `"killerclown"`, so the tree switch works. However, `GetTeam()` returning a non-clown team could confuse alliance checks. The `AlliedTeams` in the role data should include `TEAM_CLOWN` (already present) to maintain self-alliance. The `KOSAll = true` and `KOSedByAll = true` flags override team-based alliance checks.

**Mitigation:** The ClownCoordinator should explicitly track transformed Killer Clowns and ensure the perception/morality system treats them as hostile regardless of their displayed team.

### 17.7 Stale `GetTreeFor` Chain After Lua Refresh

If a Lua refresh occurs mid-round (e.g., `lua_openscript`), the `GetTreeFor` chain may break because `_origGetTreeFor` references are recreated. This is a known issue shared with all roles using the chain pattern. No special handling needed for Clown.

---

## 18. Testing Strategy

### 18.1 Unit Tests (Manual Verification)

| Test ID | Scenario | Expected Outcome | Priority |
|---------|----------|-------------------|----------|
| T-1 | Bot assigned Clown role | Uses pre-transform tree, wanders/groups/minges | Critical |
| T-2 | Clown bot cannot damage players | No damage dealt, no attack attempts | Critical |
| T-3 | Other bots don't attack Clown | NeutralOverride prevents targeting | Critical |
| T-4 | Clown transforms to Killer Clown | Tree switches to aggressive, bot starts hunting | Critical |
| T-5 | Killer Clown KOS'd by all bots | All non-ally bots target Killer Clown on sight | Critical |
| T-6 | Killer Clown uses Stalk behavior | Actively hunts isolated targets | High |
| T-7 | Killer Clown buys equipment | Purchases weapons from traitor shop | High |
| T-8 | Transformation chatter fires | Bot says transformation line, witnesses react | Medium |
| T-9 | Clown survives environmental hazards | Doesn't die to avoidable hazards | Medium |
| T-10 | Clown picks up weapons pre-transform | Weapons available post-transform | Medium |
| T-11 | Multiple rounds — no stale state | State cleans up properly between rounds | High |
| T-12 | Clown dies before transformation | No transformation event, no errors | Medium |
| T-13 | Traitor bot sees Clown as Jester | Suspicion reduced, no attack attempts | Low |
| T-14 | Killer Clown damage bonus applied | Higher damage than normal weapons | Low |

### 18.2 Integration Tests

| Test | Method | Duration |
|------|--------|----------|
| 10-round soak test with 1 Clown guaranteed | Force clown via `ttt2_clown_pct 1` | ~30 min |
| Stress test with 20 bots | Verify no performance issues from transform detection | ~15 min |
| Multi-role interaction | Clown + Jester + Swapper in same round | ~10 min |
| Environmental death test | Force Clown near hazards, verify graceful handling | ~10 min |

### 18.3 Debug Commands

```
tttbots_debug_brain 1     -- Show active behavior in 3D
tttbots_debug_misc 1      -- Show role-related debug prints
tttbots_perception_debug  -- Show perception matrix (verify Clown handling)
```

---

## 19. Implementation Priority & Phasing

### Phase 1: Critical Fixes (Estimated: 2–3 hours)

**Goal:** Make the Clown/Killer Clown bot actually functional.

| Task | File | Effort |
|------|------|--------|
| Fix `KOSedByAll = true` on Killer Clown | `roles/killerclown.lua` | 5 min |
| Fix `CanCoordinate = false` on Killer Clown | `roles/killerclown.lua` | 5 min |
| Add `GetTreeFor` chain override | `roles/clown.lua` | 30 min |
| Add post-transform tree with `Stalk` | `roles/clown.lua` | 15 min |
| Create `sv_clowncoordinator.lua` | `lib/sv_clowncoordinator.lua` | 1 hour |
| Add `RoleDescription` to both roles | `roles/clown.lua`, `roles/killerclown.lua` | 10 min |

### Phase 2: Enhanced Behaviors (Estimated: 2–3 hours)

**Goal:** Make the Clown bot intelligent and interesting.

| Task | File | Effort |
|------|------|--------|
| Improve pre-transform tree (survival focus) | `roles/clown.lua` | 30 min |
| Add `BuyableWeapons` for Killer Clown | `roles/killerclown.lua` + `data/sv_default_buyables.lua` | 30 min |
| Add `TTTBotsModifySuspicion` hook | `roles/clown.lua` | 15 min |
| Add basic chatter categories | `locale/en/sh_chats.lua` | 1 hour |
| Add allied teams properly | `roles/clown.lua` | 10 min |

### Phase 3: Polish & Personality (Estimated: 2–3 hours)

**Goal:** Make the Clown bot feel unique and personality-driven.

| Task | File | Effort |
|------|------|--------|
| Add Clown personality traits | `data/sh_traits.lua` | 30 min |
| Add full chatter catalog | `locale/en/sh_chats.lua` | 1 hour |
| Add perception layer integration | `lib/sv_perception.lua` | 30 min |
| Add round awareness integration | `roles/clown.lua` | 30 min |
| Add transformation proximity chatter | `lib/sv_clowncoordinator.lua` | 30 min |

---

## 20. Implementation Checklist

### Phase 1: Critical Fixes
- [ ] **P1-1.** Fix `killerclown.lua`: Set `KOSedByAll = true`
- [ ] **P1-2.** Fix `killerclown.lua`: Set `CanCoordinate = false`
- [ ] **P1-3.** Create `postTransformTree` in `clown.lua` with Stalk, FightBack, Restore, Wander
- [ ] **P1-4.** Implement `GetTreeFor` chain override in `clown.lua` for both `"clown"` and `"killerclown"`
- [ ] **P1-5.** Create `lib/sv_clowncoordinator.lua` with `TTT2UpdateSubrole` hook
- [ ] **P1-6.** In coordinator: Clear `lastBehavior`, `attackTarget`, behavior state on transform
- [ ] **P1-7.** In coordinator: Fire `ClownTransformed` chatter on the transforming bot
- [ ] **P1-8.** In coordinator: Fire `ClownTransformWitnessed` chatter on all other alive bots
- [ ] **P1-9.** In coordinator: Inject evidence for all bots about the transformation
- [ ] **P1-10.** In coordinator: Set transition grace period (2 seconds)
- [ ] **P1-11.** In coordinator: Publish `CLOWN_TRANSFORMED` event
- [ ] **P1-12.** In coordinator: Round cleanup hook
- [ ] **P1-13.** Add `RoleDescription` to Clown role data
- [ ] **P1-14.** Add `RoleDescription` to Killer Clown role data

### Phase 2: Enhanced Behaviors
- [ ] **P2-1.** Redesign pre-transform tree with survival behaviors (Follow, GroupUp, Restore, Minge)
- [ ] **P2-2.** Add `BuyableWeapons` to Killer Clown role data
- [ ] **P2-3.** Add buyable equipment entries in `sv_default_buyables.lua`
- [ ] **P2-4.** Add `TTTBotsModifySuspicion` hook for Clown (reduce suspicion if cheat_know_jester)
- [ ] **P2-5.** Add basic chatter categories to `sh_chats.lua`: ClownTransformed, ClownTransformWitnessed, TraitorSeesClownTransform, KillerClownHunting, KillerClownKill
- [ ] **P2-6.** Fix allied teams: Add `TEAM_CLOWN` to Clown's allied teams
- [ ] **P2-7.** Add Killer Clown damage bonus awareness (use aggressive weapons, close range preferred)

### Phase 3: Polish & Personality
- [ ] **P3-1.** Add Clown personality traits to `sh_traits.lua`
- [ ] **P3-2.** Add full chatter catalog: ClownRoundStart, ClownSurviving, ClownNearTransform, etc.
- [ ] **P3-3.** Add perception layer integration for Clown → Jester masquerading
- [ ] **P3-4.** Add round awareness: transformation proximity detection chatter
- [ ] **P3-5.** Add urgency scaling: late-round survival anxiety chatter for Clown
- [ ] **P3-6.** Add archetype-driven post-transform hunting style
- [ ] **P3-7.** Test with 10-round soak test
- [ ] **P3-8.** Test with multi-role interaction (Clown + Jester + Swapper)
- [ ] **P3-9.** Verify no stale state between rounds
- [ ] **P3-10.** Performance profile with 20 bots and Clown active

---

## Appendix A: Role Addon File Reference

| File | Purpose |
|------|---------|
| `entities/roles/clown/shared.lua` | Clown role definition, damage hooks, transformation logic |
| `entities/roles/killerclown/shared.lua` | Killer Clown role definition, damage bonus hook |
| `autorun/shared/shared_function.lua` | Shared damage utilities (TakeNoDamage, DealNoDamage, etc.) |
| `autorun/client/cl_killerclown_effects.lua` | Client-side confetti/sound effects on transformation |
| `lang/en/clown.lua` | Language strings for both roles |

## Appendix B: Existing Bot Mod File Reference

| File | Current State | Changes Needed |
|------|---------------|----------------|
| `roles/clown.lua` | Basic passive tree | Complete rewrite (trees, GetTreeFor, suspicion hook, description) |
| `roles/killerclown.lua` | Basic FightBack tree | Major corrections (KOSedByAll, CanCoordinate, buyables, tree, description) |
| `lib/sv_clowncoordinator.lua` | Does not exist | New file (transformation detection, state cleanup, chatter, events) |
| `lib/sv_perception.lua` | Spy-only | Optional: Add Clown perception entry |
| `locale/en/sh_chats.lua` | No Clown entries | Add 10+ chatter categories |
| `data/sv_default_buyables.lua` | No Clown entries | Add Killer Clown equipment buyables |
| `data/sh_traits.lua` | No Clown traits | Add Clown personality traits |

## Appendix C: ConVar Reference

| ConVar | Default | Purpose | Bot Relevance |
|--------|---------|---------|---------------|
| `ttt2_clown_damage_bonus` | 0 | Extra damage multiplier for Killer Clown | Affects DPS calculation |
| `ttt2_clown_activation_credits` | 1 | Credits given on transformation | Determines equipment budget |
| `ttt2_clown_health_on_transform` | 0 | Health set on transformation (0 = no change) | Affects post-transform survivability |
| `ttt2_clown_entity_damage` | 1 | Can Clown damage entities? | Minimal bot impact |
| `ttt2_clown_environmental_damage` | 1 | Can Clown take environmental damage? | Critical: determines if bot needs to avoid hazards |
