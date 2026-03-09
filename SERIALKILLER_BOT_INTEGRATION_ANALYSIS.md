# Serial Killer Role — Bot Integration Analysis & Implementation Plan

> **Date:** 2026-03-09
> **Scope:** TTT2-Bots-2 integration for `ttt2-role_sk-master` (Serial Killer + weapon_ttt_sk_knife + ttt2_shake_nade)

---

## Table of Contents

1. [Serial Killer Role Summary](#1-serial-killer-role-summary)
2. [Current Bot Implementation Review](#2-current-bot-implementation-review)
3. [Bug & Gap Analysis](#3-bug--gap-analysis)
4. [Improvement Proposals](#4-improvement-proposals)
5. [Implementation Checklist](#5-implementation-checklist)

---

## 1. Serial Killer Role Summary

### 1.1 Role Mechanics (from `ttt2-role_sk-master`)

| Property | Value |
|---|---|
| **Team** | `TEAM_SERIALKILLER` (custom solo team) |
| **Abbreviation** | `sk` |
| **Base Shop** | Traitor shop fallback (`SHOP_FALLBACK_TRAITOR`) |
| **Omniscient** | `true` — sees all players, knows jesters |
| **Starting Credits** | 1 (plus credits on kill and dead-credit awards) |
| **Min Players** | 8 |
| **Maximum** | 1 per round |
| **Jester Awareness** | `networkRoles = {JESTER}` — SK sees who is a Jester |
| **Score** | High kill multiplier (5×), negative team-kill (-16×), survival bonus |

### 1.2 Starting Loadout (ConVar-driven)

| Item | Default | ConVar |
|---|---|---|
| **SK Knife** (`weapon_ttt_sk_knife`) | Always given | — |
| **Armor** | 60 HP | `ttt2_serialkiller_armor` (0–120) |
| **Tracker Mode** | Tracker (constant wallhack) | `ttt2_serialkiller_tracker_mode` (0=none, 1=radar, 2=tracker) |

### 1.3 SK Knife (`weapon_ttt_sk_knife`)

- **Primary Attack (M1):** Melee slash, 40 damage per hit, 1s delay, auto-attack. If target HP < 50, instant kill (2000 dmg) with ragdoll knife-pinning effect. **Silent weapon.**
- **Secondary Attack (M2):** Throws a `ttt2_shake_nade` — a flashbang-like smoke/shake grenade (screen shake + smoke VFX in 512-unit radius). 12-second cooldown; sets clip to 0 and registers a `ttt2_sk_refill_knife` timed status HUD element. Pressing Sprint (Shift) cancels the throw.
- **Slot:** `WEAPON_SPECIAL` (slot 7)
- **Not buyable, not droppable** (removed on drop, stripped on role change)

### 1.4 Shake Nade (`ttt2_shake_nade`)

- 1.72s fuse after throw
- Creates `env_physexplosion` (radius 512, magnitude 64) + `ai_sound` fear zone
- `util.ScreenShake` (radius 1024) + smoke VFX
- **No direct damage** — area denial / disorientation tool

### 1.5 Win Condition

Serial Killer wins by being the **last player alive**. Every other player (innocent, traitor, detective, other evil roles) is an enemy.

---

## 2. Current Bot Implementation Review

### 2.1 Existing Role Registration (`roles/serialkiller.lua`)

```lua
local serialkiller = TTTBots.RoleData.New("serialkiller", TEAM_SERIALKILLER)
serialkiller:SetDefusesC4(true)
serialkiller:SetStartsFights(true)
serialkiller:SetCanCoordinate(true)      -- BUG: SK is solo, shouldn't coordinate
serialkiller:SetTeam(TEAM_SERIALKILLER)
serialkiller:SetBTree(bTree)
serialkiller:SetKnowsLifeStates(true)
serialkiller:SetAlliedTeams(allyTeams)    -- {TEAM_SERIALKILLER, TEAM_JESTER}
serialkiller:SetLovesTeammates(true)
serialkiller:SetIsFollower(true)
TTTBots.Roles.RegisterRole(serialkiller)
```

**Behavior Tree:**
```lua
local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _prior.Convert,
    _prior.Restore,
    _bh.Stalk,
    _prior.Minge,
    _prior.Patrol
}
```

### 2.2 What Works

- ✅ Correctly registers on `TEAM_SERIALKILLER`
- ✅ Allies with Jesters (SK knows and avoids them)
- ✅ `SetStartsFights(true)` — morality system will trigger opportunistic attacks
- ✅ `SetKnowsLifeStates(true)` — omniscient (can see who's dead)
- ✅ `Stalk` behavior is included — SK will follow isolated targets
- ✅ Falls back to general attack logic in `sv_morality_hostility.lua` via `attackNonAllies`

---

## 3. Bug & Gap Analysis

### 3.1 Bugs

| # | Severity | Issue | Details |
|---|---|---|---|
| B1 | 🔴 High | **`SetCanCoordinate(true)` is wrong** | SK is a solo role on its own team — there are no teammates to coordinate with. This flag enables traitor-team coordination logic (e.g. `InnocentCoordinator`) which the SK should never participate in. Should be `false`. |
| B2 | 🔴 High | **No `SetKOSAll(true)`** | SK must kill everyone. Without `KOSAll`, the bot relies solely on `StartsFights` + Stalk, meaning it won't immediately attack visible non-allies the way Doomguy/KillerClown do. The morality hostility system checks `GetKOSAll()` in `attackNonAllies()` — setting this would make SK attack any visible enemy. |
| B3 | 🟡 Medium | **No `SetKOSedByAll(true)`** | When the SK's identity is revealed (body found, witnesses), all bots should aggressively target them. Currently they don't treat SK as inherently hostile on sight. The `attackKOSedByAll()` function in morality checks this flag. |
| B4 | 🟡 Medium | **`SetUsesSuspicion` not set (defaults to `true`)** | SK is omniscient and knows everyone's role. Suspicion tracking is irrelevant and wastes processing. Should be `false`. |
| B5 | 🟡 Medium | **Missing `SetRoleDescription`** | LLM prompts won't have context for this role, leading to generic/confused chatter. |
| B6 | 🟡 Medium | **`_prior.Convert` in BTree is useless** | SK has no conversion weapons (no sidekick deagle, no cursed deagle, etc.). This priority node will just waste evaluation cycles every tick. |
| B7 | 🟡 Medium | **`_prior.Support` in BTree is inappropriate** | The Support node includes `Defib`, `Healgun`, `Roledefib` — SK has no reason to revive or heal other players. |
| B8 | 🟢 Low | **`SetIsFollower(true)` may cause passive behavior** | This increases the chance of following other players instead of actively hunting. While stalking can lead to kills, it can make the SK too passive in late game. |

### 3.2 Gaps — Missing Features

| # | Priority | Gap | Details |
|---|---|---|---|
| G1 | 🔴 High | **Bot doesn't use SK Knife intelligently** | No behavior to prioritize/equip `weapon_ttt_sk_knife`. The knife is silent (no gunshot noise), does 40 dmg per hit (instant-kill under 50 HP), but the bot's `AutoManageInventory` will swap to whatever has the highest DPS score — likely a gun. SK's core identity is knife kills. |
| G2 | 🔴 High | **Bot never throws the Shake Nade** | Secondary attack (`SecondaryAttack`) spawns a `ttt2_shake_nade` — a powerful area-denial tool. No behavior exists to trigger `IN_ATTACK2` on the SK knife. The `UseGrenade` behavior only works with the grenade slot, not secondary-fire abilities. |
| G3 | 🔴 High | **No SK-specific stalking intelligence** | The SK has a tracker/radar (sees all players through walls). The current `Stalk` behavior uses `RateIsolation()` but doesn't account for the SK's omniscient vision. The SK should actively use its tracker info to pick off the most isolated target. |
| G4 | 🟡 Medium | **No shop buying strategy** | SK has traitor shop access with credits, but no `Buyable` entries are registered for `serialkiller`. The bot will never buy any shop items. |
| G5 | 🟡 Medium | **No SK-specific chatter events** | No chatter events for: gloating after kills, reacting to the smoke grenade, taunting survivors, expressing the "hunter" mentality, team-chat solo commentary. |
| G6 | 🟡 Medium | **No locale strings for SK bot chatter** | The `en/` locale directory has no Serial Killer-specific lines for LLM fallback. |
| G7 | 🟡 Medium | **Phase-awareness not tuned for SK** | The `Stalk` behavior has a phase gate that disables stalking in LATE/OVERTIME. This is designed for traitors who should "go loud" in late game, but SK's core mechanic IS stalking + knife kills. The phase gate exception only covers Infected hosts currently. |
| G8 | 🟡 Medium | **No smoke grenade tactical awareness** | When the SK throws a shake nade, nearby bots don't react (flee the smoke area, call out the grenade, increase suspicion). No hook or event fires for the shake nade. |
| G9 | 🟢 Low | **No deception/alibi behaviors** | SK could benefit from some deception behaviors (e.g., fake investigating, building alibis) since they need to survive and pick off players without being immediately KOS'd. Currently the BTree has no `_prior.Deception`. |
| G10 | 🟢 Low | **Armor not leveraged in combat decisions** | SK starts with 60 armor. The bot's combat decision-making doesn't account for having armor (e.g., being more aggressive when armored). |
| G11 | 🟢 Low | **No round-phase escalation strategy** | SK should transition from stealthy knife kills (early/mid) to aggressive hunting (late/overtime). Currently the behavior tree is static. |

---

## 4. Improvement Proposals

### 4.1 Role Registration Fixes

**File:** `lua/tttbots2/roles/serialkiller.lua`

1. Set `SetCanCoordinate(false)` — SK is solo
2. Add `SetKOSAll(true)` — SK needs to kill everyone
3. Add `SetKOSedByAll(true)` — everyone should attack SK on sight
4. Set `SetUsesSuspicion(false)` — SK is omniscient
5. Add `SetRoleDescription(...)` with proper LLM prompt context
6. Consider using `TTTBots.RoleBuilder.NeutralKiller()` as a base and customizing from there

### 4.2 Behavior Tree Overhaul

**Current tree has irrelevant nodes and is missing SK-specific behaviors.**

**Proposed BTree:**
```lua
local bTree = {
    _prior.Chatter,           -- Social deception + chatter
    _prior.FightBack,         -- React to being attacked
    _prior.SelfDefense,       -- Defend from accusations
    _prior.Requests,          -- Handle incoming requests
    _bh.SKKnifeAttack,        -- NEW: Prioritize knife kills on isolated targets
    _bh.SKShakeNade,          -- NEW: Throw shake nade for area denial/escape
    _prior.Deception,         -- Alibi building, fake investigating (early game)
    _prior.Restore,           -- Pick up weapons/health
    _bh.Stalk,                -- Stalk isolated targets
    _prior.Minge,             -- Occasional minge behavior for cover
    _prior.Patrol             -- Default patrol when nothing else to do
}
```

### 4.3 New Behavior: SK Knife Attack (`behaviors/skknifeattack.lua`)

**Purpose:** When near an isolated target, equip the SK knife and go for the kill.

**Logic:**
1. **Validate:** Bot has `weapon_ttt_sk_knife`, round is active, no current attack target
2. **FindTarget:** Use `lib.FindIsolatedTarget()` but with enhanced scoring that accounts for SK's omniscient awareness (lower witness count = better)
3. **OnRunning:**
   - Navigate toward target
   - When within knife range (~70 units) and ≤1 witness:
     - Pause auto-switch
     - Equip SK knife
     - Look at target, primary attack
   - If target HP < 50, commit to instant-kill thrust
4. **OnSuccess:** Resume auto-switch, chatter event "SKKnifeKill"

**Implementation Strategy:** Can use `RegisterRoleWeapon()` factory with:
- `hasWeaponFn` = check `bot:HasWeapon("weapon_ttt_sk_knife")`
- `equipDirectFn` = `bot:GetWeapon("weapon_ttt_sk_knife")`
- `engageDistance` = 100 (knife range)
- `witnessThreshold` = 1
- `findTargetFn` = custom isolation-scoring function

### 4.4 New Behavior: SK Shake Nade (`behaviors/skshakenade.lua`)

**Purpose:** Throw the shake nade tactically via secondary fire on the SK knife.

**Scenarios to throw:**
1. **Escape:** When being chased/shot at with ≤1 escape route → throw at own position
2. **Pre-kill:** Before engaging a group → throw to disorient then rush in
3. **Cover retreat:** After a knife kill with witnesses approaching → throw between self and witnesses

**Logic:**
1. **Validate:** Bot has `weapon_ttt_sk_knife`, knife has clip (Clip1 > 0), cooldown expired (12s between throws)
2. **OnRunning:**
   - Equip knife
   - Aim at throw position
   - Trigger `IN_ATTACK2` (secondary fire)
3. **Cooldown tracking:** Store `bot.lastShakeNadeTime = CurTime()`

**Implementation Strategy:** Custom behavior (not `RegisterRoleWeapon` since this is secondary fire on an existing weapon).

### 4.5 Inventory Integration

**File:** `components/sv_inventory.lua`

Add SK knife awareness methods:
```lua
function BotInventory:GetSKKnife()
    local wep = self.bot:GetWeapon("weapon_ttt_sk_knife")
    return IsValid(wep) and wep or nil
end

function BotInventory:EquipSKKnife()
    local knife = self:GetSKKnife()
    if not knife then return false end
    self.bot:SetActiveWeapon(knife)
    return true
end
```

Also update `ScoreWeaponForContext()` to boost SK knife score when:
- Distance to target < 100 units (knife range)
- Bot is serialkiller role
- Target is isolated (≤1 other visible player)

### 4.6 Chatter & Comms Integration

#### New Chatter Events

| Event Name | When | TeamOnly | Example Lines |
|---|---|---|---|
| `SKHunting` | SK picks a new stalk target | Yes (solo) | "Found my next target..." / "You're next." |
| `SKKnifeKill` | SK kills with knife | No | "Another one falls..." / "Shh... nobody heard that." |
| `SKShakeNade` | SK throws shake nade | No | *silence* (it's supposed to be sneaky) or false innocence |
| `SKGloat` | SK has killed >50% of players | Yes | "They're dropping like flies." |
| `SKLastStand` | SK is last 2-3 alive | No | Unmasked threatening chatter |
| `SKSpotted` | SK is accused/KOS'd | No | "Guess I don't have to hide anymore." |
| `SKVictory` | SK wins the round | No | Gloating, victory line |

#### LLM Prompt Context

Add to `SetRoleDescription`:
```
"The Serial Killer is a solo hostile role that must kill every other player to win.
You have a silent knife (instant kill at low HP), a shake grenade for area denial,
armor, and a tracker that shows all player positions. You start alone — no allies.
You know who the Jesters are (avoid them). Play stealthily early, escalate aggression
as players die. You are cunning, methodical, and ruthless."
```

#### Locale Lines

Add `en/` locale entries for all new chatter events with 3-5 variants each.

### 4.7 Morality & Hostility Tuning

The existing `sv_morality_hostility.lua` already handles the SK correctly once `KOSAll` is set — `attackNonAllies()` checks `GetKOSAll()` and will attack visible non-allies.

**Additional tuning:**
- SK should have higher `aggressionMult` than standard StartsFights roles
- SK should ignore the "personal space" suspicion mechanic (it's omniscient)
- SK that reveals itself (witnessed killing) should escalate to full KOS mode immediately

### 4.8 Round Phase Strategy

| Phase | SK Strategy | BTree Priority |
|---|---|---|
| **EARLY** (0-25%) | Stealth mode. Stalk isolated players, knife kills only. Build alibis. | Deception > Stalk > SKKnifeAttack |
| **MID** (25-60%) | Aggressive stalking. Pick off stragglers. Use shake nade to cover kills. | Stalk > SKKnifeAttack > SKShakeNade |
| **LATE** (60-85%) | Full hunting mode. Switch to guns if needed. | FightBack > SKKnifeAttack > Stalk |
| **OVERTIME** (85%+) | Kill everything in sight. No stealth. | FightBack > direct combat |

**Implementation:** Override the `Stalk.Validate` phase gate to always allow stalking for SK bots (similar to the existing Infected host exception).

### 4.9 Shop Buying Strategy

Register buyable items for the `serialkiller` role:

| Item | Priority | Rationale |
|---|---|---|
| Body Armor (extra) | High | SK is a melee-heavy role, needs survivability |
| Decoy | Medium | Misdirection |
| Radar (if not given) | Medium | Redundant if tracker_mode ≥ 1, useful if 0 |
| Primary weapon (Silenced) | Medium | For when knife isn't viable |

---

## 5. Implementation Checklist

### Phase 1 — Critical Fixes (Bugs)

- [ ] **B1:** Fix `serialkiller.lua` — set `SetCanCoordinate(false)`
- [ ] **B2:** Fix `serialkiller.lua` — add `SetKOSAll(true)`
- [ ] **B3:** Fix `serialkiller.lua` — add `SetKOSedByAll(true)`
- [ ] **B4:** Fix `serialkiller.lua` — add `SetUsesSuspicion(false)`
- [ ] **B5:** Fix `serialkiller.lua` — add `SetRoleDescription("...")` with full LLM-friendly description
- [ ] **B6/B7:** Remove `_prior.Convert` and `_prior.Support` from BTree
- [ ] Add `_prior.SelfDefense` and `_prior.Deception` to BTree

### Phase 2 — Core Behaviors

- [ ] **G1:** Create `behaviors/skknifeattack.lua` — knife-focused kill behavior
  - [ ] Implement target isolation scoring with omniscient awareness
  - [ ] Handle equipping SK knife, approaching within 70 units
  - [ ] Trigger primary attack, handle instant-kill threshold
  - [ ] Add chatter event on successful kill
- [ ] **G2:** Create `behaviors/skshakenade.lua` — secondary fire shake nade behavior
  - [ ] Detect scenarios: escape, pre-kill distraction, cover retreat
  - [ ] Equip knife, aim, trigger `IN_ATTACK2`
  - [ ] Track 12-second cooldown
  - [ ] Add reactive bot behavior: bots near shake nade flee/get suspicious
- [ ] **G7:** Patch `Stalk.Validate` phase gate to exempt SK (like Infected host)

### Phase 3 — Inventory & Buying

- [ ] **G1 (cont.):** Add `GetSKKnife()` and `EquipSKKnife()` to `sv_inventory.lua`
- [ ] Update `ScoreWeaponForContext()` to boost SK knife at close range for SK role
- [ ] **G4:** Register `Buyable` entries for `serialkiller` in `sv_default_buyables.lua`
  - [ ] Body Armor (if not already maxed from loadout)
  - [ ] Silenced weapon for ranged backup
  - [ ] Decoy or radar (situational)

### Phase 4 — Chatter & Communication

- [ ] **G5:** Add chatter events to `sv_chatter_events.lua`:
  - [ ] `SKHunting` — picking a target
  - [ ] `SKKnifeKill` — successful knife kill
  - [ ] `SKShakeNade` — threw a shake nade
  - [ ] `SKGloat` — mid-round gloating
  - [ ] `SKLastStand` — endgame aggression
  - [ ] `SKSpotted` — identity revealed
  - [ ] `SKVictory` — round win
- [ ] **G6:** Add locale lines in `locale/en/` for all new events (3-5 variants each)
- [ ] Add LLM prompt context for SK role in `sh_prompt_context.lua`
- [ ] Add SK-specific prompts in `sh_chatgpt_prompts.lua` and `sh_llama_prompts.lua`

### Phase 5 — Advanced Behaviors & Polish

- [ ] **G8:** Add shake nade reaction hook for non-SK bots:
  - [ ] Detect `ttt2_shake_nade` spawn near bot
  - [ ] Flee behavior / increase suspicion of nearby players
  - [ ] Chatter event "ShakeNadeNearby"
- [ ] **G9:** Add deception layer for early-game SK
  - [ ] Enable `_prior.Deception` in BTree for stealth gameplay
  - [ ] SK-specific alibi building (walk with innocents, fake investigating)
- [ ] **G10:** Factor armor into combat aggression calculations
  - [ ] In `SetRandomNearbyTarget()`, boost aggression if bot has >30 armor
- [ ] **G11:** Implement phase-based BTree selection
  - [ ] EARLY: stealth-focused tree (Deception, Stalk, SKKnifeAttack)
  - [ ] LATE/OVERTIME: combat-focused tree (FightBack, aggressive attack)
- [ ] Smoke grenade awareness: bot reacts to smoke VFX covering kill sites
- [ ] Add SK-specific personality traits (e.g., "methodical", "ruthless")
- [ ] Add SK to the `RoleBuilder` as a preset pattern (`NeutralKiller` variant)

### Phase 6 — Testing & Validation

- [ ] Unit test: SK bot correctly identifies all non-jesters as enemies
- [ ] Unit test: SK bot equips knife when within range, gun when far
- [ ] Integration test: SK bot stalks, kills with knife, throws shake nade
- [ ] Integration test: Other bots react to SK's shake nade
- [ ] Integration test: SK chatter events fire at correct times
- [ ] Integration test: SK buys shop items correctly
- [ ] Balance test: SK bot win rate in 8-16 player lobbies
- [ ] Balance test: SK knife vs gun kill ratio
- [ ] Edge case: SK is the only bot (1v humans)
- [ ] Edge case: SK + Jester interaction (must not kill jester)
- [ ] Edge case: Multiple SKs (if `maximum` cvar is changed from 1)

---

## Appendix A — File Change Map

| File | Action | Description |
|---|---|---|
| `lua/tttbots2/roles/serialkiller.lua` | **Modify** | Fix bugs B1-B8, overhaul BTree, add role description |
| `lua/tttbots2/behaviors/skknifeattack.lua` | **Create** | SK knife kill behavior |
| `lua/tttbots2/behaviors/skshakenade.lua` | **Create** | SK shake nade throw behavior |
| `lua/tttbots2/components/sv_inventory.lua` | **Modify** | Add `GetSKKnife()`, `EquipSKKnife()`, scoring updates |
| `lua/tttbots2/behaviors/stalk.lua` | **Modify** | Add SK phase-gate exemption |
| `lua/tttbots2/components/chatter/sv_chatter_events.lua` | **Modify** | Add SK chatter events + probability entries |
| `lua/tttbots2/locale/en/*.lua` | **Modify** | Add SK locale strings |
| `lua/tttbots2/lib/sh_prompt_context.lua` | **Modify** | Add SK LLM prompt context |
| `lua/tttbots2/lib/sh_chatgpt_prompts.lua` | **Modify** | Add SK-specific prompt templates |
| `lua/tttbots2/data/sv_default_buyables.lua` | **Modify** | Register SK buyable items |

## Appendix B — Comparable Role Implementations

| Role | Similarity | Key Differences |
|---|---|---|
| **Doomguy** | Most similar — solo neutral killer, KOSAll, KOSedByAll | Doomguy has a preferred weapon (supershotgun), no stealth mechanic, no knife. SK should be stealthier. |
| **Killer Clown** | KOSAll, starts fights, no suspicion | Clown has Jester origins, different team. SK is always hostile from round start. |
| **Jackal** | Solo team, stalking, sidekick conversion | Jackal has a sidekick deagle (conversion), SK has no conversion ability. |
| **Infected Host** | Stalking core mechanic, exempt from phase gate | Infected converts targets, SK kills them. Similar stalking pattern. |

## Appendix C — SK Knife Damage Model

```
Primary Attack (M1):
  - 40 dmg/hit, 1.0s delay, auto-fire
  - If target HP < 50: instant kill (2000 dmg)
  - Silent (IsSilent = true)
  - Range: ~70 units (hull trace)

  Time-to-kill (100 HP target):
    Hit 1: 100 → 60 HP
    Hit 2: 60 → 20 HP  (< 50 threshold met)
    Hit 3: instant kill
    Total: ~2.0 seconds (2 hits then finish)

  Time-to-kill (100 HP + 60 armor target):
    Armor absorbs first, then HP
    Effective ~4-5 hits = 4-5 seconds

Secondary Attack (M2):
  - Throws ttt2_shake_nade
  - 12s cooldown (sets Clip1 to 0, refills after timer)
  - No damage, area denial (screen shake, smoke, physics push)
  - Range: thrown projectile (velocity 300 * aim vector)
```

---

*This document should be maintained as a living reference throughout the SK bot integration work.*
