# Amnesiac Role — Bot Integration Analysis

> **Date:** 2026-03-09
> **Scope:** TTT2 Amnesiac Role Addon × TTT2-Bots-2
> **Status:** Current implementation is **basic/passive** — significant enhancement opportunities identified

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Amnesiac Addon Internals](#2-amnesiac-addon-internals)
3. [Current Bot Integration State](#3-current-bot-integration-state)
4. [Gap Analysis](#4-gap-analysis)
5. [Integration Strategy — Phase Plan](#5-integration-strategy--phase-plan)
6. [New Behavior: `AmnesiacSeekCorpse`](#6-new-behavior-amnesiacseekporse)
7. [Dynamic Tree Switching (Pre/Post-Copy)](#7-dynamic-tree-switching-prepost-copy)
8. [Amnesiac Coordinator (`sv_amnesiaccoordinator.lua`)](#8-amnesiac-coordinator-sv_amnesiaccoordinatorlua)
9. [Morality & Hostility Implications](#9-morality--hostility-implications)
10. [Chatter Events](#10-chatter-events)
11. [Convar Awareness](#11-convar-awareness)
12. [Edge Cases & Race Conditions](#12-edge-cases--race-conditions)
13. [Personality-Driven Behavior Modulation](#13-personality-driven-behavior-modulation)
14. [Implementation Priority & File Manifest](#14-implementation-priority--file-manifest)
15. [Testing Checklist](#15-testing-checklist)
16. [Appendix: Cross-Reference with Other Role Analyses](#16-appendix-cross-reference-with-other-role-analyses)

---

## 1. Executive Summary

The **Amnesiac** is a `TEAM_NONE` neutral role that has no team allegiance and no win condition on its own. Its core mechanic is **corpse searching**: when the Amnesiac searches an unconfirmed body, they **inherit the dead player's role and team**. After conversion, the Amnesiac effectively becomes that role for the remainder of the round.

The current bot integration (`roles/amnesiac.lua`) provides a **basic static registration** with a passive behavior tree. The bot has `InvestigateCorpse` in its tree, which will cause it to walk up to bodies and search them — which *does* trigger the addon's `TTTCanSearchCorpse` hook and converts the role. However, the bot has **zero awareness** that:

- Searching corpses is its **primary objective** (not just evidence gathering)
- It should **prioritize unconfirmed corpses** over all other activities
- After conversion, its behavior tree, alliances, suspicion system, and combat posture should **completely change**
- The convar `ttt2_amnesiac_limit_to_unconfirmed` affects which corpses are valid targets
- A global popup announces the conversion to all players (requiring discretion)
- The built-in **radar** shows corpse locations (bot doesn't leverage this)

This analysis proposes a **5-phase enhancement plan** that adds strategic corpse-seeking, dynamic tree switching, a coordinator module, chatter events, and personality-driven behavior modulation.

---

## 2. Amnesiac Addon Internals

### 2.1 Role Definition (`entities/roles/amnesiac/shared.lua`)

| Property | Value | Impact on Bots |
|---|---|---|
| `defaultTeam` | `TEAM_NONE` | No allies, no enemies — pure neutral |
| `unknownTeam` | `true` | Team is hidden from other players |
| `preventFindCredits` | `true` | Cannot loot credits from bodies |
| `preventKillCredits` | `true` | No credits for kills |
| `preventTraitorAloneCredits` | `true` | No bonus when traitors are alone |
| `preventWin` | `true` | **Cannot win** as Amnesiac — must convert |

### 2.2 Core Mechanic — `TTTCanSearchCorpse` Hook

```lua
hook.Add("TTTCanSearchCorpse", "TTT2AmneIdentifyCorpse", function(ply, rag)
    -- Only triggers if:
    -- 1. ply is alive
    -- 2. ply:GetSubRole() == ROLE_AMNESIAC
    -- 3. Ragdoll is unconfirmed (or convar allows confirmed bodies)
    
    -- On success:
    ply:SetRole(deadply:GetSubRole(), deadply:GetTeam())
    SendFullStateUpdate()
    
    -- Optional popup broadcast
    -- Returns whether the corpse should be "confirmed"
end)
```

**Critical Detail:** The role conversion happens **inside the corpse search hook**. The standard `CORPSE.ShowSearch()` + `CORPSE.SetFound()` flow in `InvestigateCorpse.OnRunning()` calls `CORPSE.ShowSearch(bot, corpse, false, false)` which fires `TTTCanSearchCorpse`. This means **the existing InvestigateCorpse behavior already triggers conversion** — but only incidentally.

### 2.3 Custom Radar

The addon gives the Amnesiac `item_ttt_radar` on spawn via `GiveRoleLoadout`. The radar's `CustomRadar` function returns positions of **all unconfirmed ragdolls** (filtered by the `limit_to_unconfirmed` convar). This radar is purely visual for human players — bots gain no benefit from it.

### 2.4 Convars

| Convar | Default | Purpose |
|---|---|---|
| `ttt2_amnesiac_showpopup` | `1` | Global popup when Amnesiac converts (alerts all players) |
| `ttt2_amnesiac_confirm_player` | `0` | If `0`, searching a body triggers role copy WITHOUT confirming it |
| `ttt2_amnesiac_limit_to_unconfirmed` | `1` | If `1`, can only copy from unconfirmed bodies |

### 2.5 Global Popup Implication

When `ttt2_amnesiac_showpopup` is enabled (default), **every player** sees a popup like: *"An Amnesiac has remembered that they were [Traitor]"*. This reveals:
- That an Amnesiac existed in the round
- What role they acquired
- If only one body was searched recently, it narrows down *who* the Amnesiac is

Bots need to understand this disclosure risk and act accordingly.

---

## 3. Current Bot Integration State

### 3.1 File: `roles/amnesiac.lua`

```lua
local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _bh.InvestigateCorpse,     -- ← This is the only corpse-related behavior
    _prior.Support,
    _bh.Defib,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

local amnesiac = TTTBots.RoleData.New("amnesiac", TEAM_NONE)
amnesiac:SetStartsFights(false)         -- Won't initiate combat
amnesiac:SetCanCoordinate(false)        -- No team coordination
amnesiac:SetUsesSuspicion(false)        -- Won't build suspicion on others
amnesiac:SetKnowsLifeStates(true)      -- Can check scoreboard
amnesiac:SetAlliedTeams(allyTeams)      -- Allied with jesters
amnesiac:SetLovesTeammates(false)       -- No team love
```

### 3.2 What Works (Accidentally)

- `InvestigateCorpse` causes the bot to walk to visible unconfirmed corpses
- `CORPSE.ShowSearch()` inside `InvestigateCorpse.OnRunning()` fires the addon's `TTTCanSearchCorpse` hook
- The hook converts the Amnesiac's role server-side
- `GetRoleFor()` is called fresh each tick, so the behavior tree **does** switch after conversion because `GetRoleStringRaw()` returns the new role

### 3.3 What's Missing

| Gap ID | Description | Severity |
|---|---|---|
| GAP-1 | No priority/urgency for corpse-seeking — treats it same as innocent investigating | **Critical** |
| GAP-2 | No use of radar data to find non-visible corpses | High |
| GAP-3 | No convar awareness (`limit_to_unconfirmed`, `confirm_player`) | High |
| GAP-4 | No coordinator to handle mid-round role transition cleanly | **Critical** |
| GAP-5 | No suspicion/evidence reset after conversion | **Critical** |
| GAP-6 | No chatter events for role-seeking or conversion | Medium |
| GAP-7 | No personality modulation of corpse-seeking urgency | Medium |
| GAP-8 | No awareness of popup disclosure (discretion after conversion) | Medium |
| GAP-9 | No dynamic tree switching (still uses amnesiac tree briefly after conversion) | High |
| GAP-10 | `InvestigateCorpse` has a random dice roll (`GetShouldInvestigateCorpses`) that may cause the bot to *skip* corpses — fatal for Amnesiac | **Critical** |
| GAP-11 | Bot doesn't understand it **cannot win** as Amnesiac — has no urgency | High |
| GAP-12 | After conversion to a traitor role, morality hostility functions see the new role immediately but evidence/suspicion from pre-conversion persists | High |

---

## 4. Gap Analysis

### GAP-1: No Corpse-Seeking Priority

The `InvestigateCorpse` behavior's `Validate()` function calls `GetShouldInvestigateCorpses()` which rolls a personality-weighted dice (base 75%, min 5%). For an Amnesiac, this should be **100%** — every unconfirmed corpse is a potential lifeline.

**Fix:** Create a new `AmnesiacSeekCorpse` behavior that:
- Always validates when the bot is Amnesiac and unconfirmed corpses exist
- Uses the known corpse list from `TTTBots.Match.Corpses` AND the addon's radar data
- Prioritizes the **nearest reachable** unconfirmed corpse
- Runs at higher priority than `InvestigateCorpse`

### GAP-4: No Coordinator

The Cursed and Infected roles both have coordinator modules that hook `TTT2UpdateSubrole` to detect role transitions and perform cleanup. The Amnesiac needs the same pattern.

**Fix:** Create `sv_amnesiaccoordinator.lua` that:
- Hooks `TTT2UpdateSubrole` to detect when a player leaves `ROLE_AMNESIAC`
- Resets suspicion, evidence, attack targets, and behavior state
- Fires chatter events for the converting bot and witnesses
- Publishes events on the event bus

### GAP-10: Random Dice Roll Kills Urgency

`InvestigateCorpse.Validate()` calls `GetShouldInvestigateCorpses()` which may return `false` even when corpses are visible. For the Amnesiac, this is catastrophic — the bot might wander past its only chance at a role.

**Fix:** `AmnesiacSeekCorpse` bypasses the personality dice roll entirely, OR the dice roll is overridden to always return true for Amnesiac bots.

---

## 5. Integration Strategy — Phase Plan

### Phase 1: Amnesiac Coordinator (GAP-4, GAP-5, GAP-12)

**File:** `lua/tttbots2/lib/sv_amnesiaccoordinator.lua`

**Purpose:** Detect and cleanly handle mid-round Amnesiac → NewRole transitions.

**Implementation:**
```lua
hook.Add("TTT2UpdateSubrole", "TTTBots.AmnesiacCoordinator.DetectConversion", function(ply, oldSubrole, newSubrole)
    if not ROLE_AMNESIAC then return end
    if oldSubrole ~= ROLE_AMNESIAC then return end
    if newSubrole == ROLE_AMNESIAC then return end
    
    timer.Simple(0.1, function()
        if not IsValid(ply) then return end
        
        -- 1. Reset suspicion (stale pre-conversion data)
        -- 2. Clear evidence entries
        -- 3. Clear attack targets
        -- 4. Clear behavior state (force tree re-evaluation)
        -- 5. Fire conversion chatter
        -- 6. Notify witnessing bots
        -- 7. Publish event on event bus
    end)
end)
```

**Modeled after:** `sv_cursedcoordinator.lua` (handles bidirectional role swaps with evidence/suspicion cleanup).

### Phase 2: `AmnesiacSeekCorpse` Behavior (GAP-1, GAP-2, GAP-3, GAP-10)

**File:** `lua/tttbots2/behaviors/amnesiacseek.lua`

**Purpose:** Dedicated corpse-seeking behavior that replaces `InvestigateCorpse` in the Amnesiac's pre-conversion tree.

**Behavior Lifecycle:**

| Callback | Logic |
|---|---|
| `Validate` | `bot:GetSubRole() == ROLE_AMNESIAC` AND (visible unconfirmed corpses exist OR radar data indicates corpse positions). Convar `ttt2_amnesiac_limit_to_unconfirmed` is respected. **No dice roll.** |
| `OnStart` | Set target corpse. Fire "AmnesiacSeekingCorpse" chatter. |
| `OnRunning` | Navigate to corpse. When within 80 XY units, look at corpse, call `CORPSE.ShowSearch()`. The addon's hook handles conversion automatically. Return SUCCESS on search completion. |
| `OnEnd` | Clear target. Clear behavior state. |

**Key Differences from `InvestigateCorpse`:**

| Aspect | `InvestigateCorpse` | `AmnesiacSeekCorpse` |
|---|---|---|
| Dice roll | 75% base (personality-weighted) | **100% always** |
| Motivation | Evidence gathering | **Role acquisition (survival)** |
| Corpse source | Visible corpses only | Visible + radar-known positions |
| Convar awareness | None | Respects `limit_to_unconfirmed` |
| Priority in tree | Mid-priority | **High priority** (below FightBack) |
| Target selection | Closest visible | Closest reachable (with navigation check) |

### Phase 3: Dynamic Tree Switching (GAP-9, GAP-11)

**File:** Modified `roles/amnesiac.lua`

**Purpose:** Two distinct behavior trees — pre-conversion (corpse seeker) and post-conversion (adopts new role's tree).

```lua
-- Pre-conversion tree: focused on finding and searching corpses
local preConversionTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _bh.AmnesiacSeek,        -- PRIMARY OBJECTIVE: find & search corpses
    _bh.InvestigateCorpse,   -- Fallback: standard investigate (in case AmnesiacSeek fails)
    _prior.Restore,
    _bh.Interact,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

-- Post-conversion: handled by GetTreeFor returning the new role's tree
-- The coordinator resets bot state, and GetRoleFor() returns the new role
-- which automatically pulls the correct tree.
```

**`GetTreeFor` Override Pattern:**

```lua
local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor
function TTTBots.Behaviors.GetTreeFor(bot)
    if not IsValid(bot) then return nil end
    
    -- If the bot is still ROLE_AMNESIAC, use the pre-conversion tree
    if bot:GetSubRole() == ROLE_AMNESIAC then
        return preConversionTree
    end
    
    -- Post-conversion: the role has already changed, so GetRoleFor
    -- returns the new role's data and its tree. Fall through.
    return _origGetTreeFor(bot)
end
```

**Note:** Because `GetRoleFor()` reads `GetRoleStringRaw()` fresh each call, the tree switching happens automatically once the role changes. The override is primarily to ensure the pre-conversion tree is used *while still Amnesiac*, rather than the registered amnesiac role's default tree (which might not have `AmnesiacSeek` at the right priority).

### Phase 4: Chatter Events (GAP-6, GAP-8)

**Files:**
- `lua/tttbots2/components/chatter/sv_chatter_events.lua` (add event entries)
- `lua/tttbots2/locale/en/amnesiac.lua` (new locale file)

**New Events:**

| Event Name | Trigger | Priority | Example Text |
|---|---|---|---|
| `AmnesiacSeekingCorpse` | Bot spots a body to investigate | 60 | "I need to check that body..." |
| `AmnesiacConversionSuccess` | Bot just converted to a new role | 90 | "I remember now... I remember everything." |
| `AmnesiacConversionWitnessed` | Another bot witnesses the popup | 85 | "Did an Amnesiac just take a role?" |
| `AmnesiacDesperateLate` | Late-round, still no conversion | 75 | "I need to find a body, fast..." |
| `AmnesiacNoBodiesAvailable` | No unconfirmed corpses exist | 50 | "Where are all the bodies?" |
| `AmnesiacPostConversionDisguise` | Bot is acting suspiciously after conversion | 70 | "Act natural, act natural..." |

### Phase 5: Personality Modulation & Polish (GAP-7, GAP-8)

**Purpose:** Differentiate Amnesiac bot behavior based on personality archetypes.

| Archetype | Corpse Seek Radius | Urgency Scaling | Post-Conversion Discretion | Combat Willingness |
|---|---|---|---|---|
| Tryhard | Maximum (whole map) | Aggressive escalation | High — avoids crowds after popup | Calculated |
| Hothead | Standard | Immediate — kills for corpse access | Low — charges into fights | Reckless |
| Stoic | Standard | Gradual | High — patient, waits for safe moment | Defensive only |
| Casual | Reduced | Lazy — may wander first | Medium | Avoids fights |
| Dumb | Random | Erratic | None — ignores popup implications | Random |
| Nice | Standard | Moderate | Medium | Reluctant |
| Sus | Maximum | Strategic | Very high — plays confused | Only if cornered |

---

## 6. New Behavior: `AmnesiacSeekCorpse`

### Complete Behavior Specification

```lua
-- File: lua/tttbots2/behaviors/amnesiacseek.lua

TTTBots.Behaviors.AmnesiacSeek = {}
local AmnesiacSeek = TTTBots.Behaviors.AmnesiacSeek
AmnesiacSeek.Name = "AmnesiacSeek"
AmnesiacSeek.Description = "Seek and search corpses to acquire a role (Amnesiac)"
AmnesiacSeek.Interruptible = true

-- Key design decisions:
-- 1. No dice roll — always validates when corpses available
-- 2. Convar-aware — respects limit_to_unconfirmed
-- 3. Uses corpse list + radar positions for non-visible corpse awareness
-- 4. Urgency increases over time (phase-aware)
-- 5. Interruptible (so FightBack can still fire)
```

### Target Selection Algorithm

```
1. Get all corpses from TTTBots.Match.Corpses
2. Filter by:
   a. IsValid(corpse)
   b. Not CORPSE.GetFound(corpse) (if limit_to_unconfirmed is true)
   c. Is a player_ragdoll with a valid player
3. Sort by:
   a. Distance (closest first)
   b. Visibility bonus (visible corpses preferred over radar-only)
   c. Isolation bonus (corpses far from other players = safer to search)
4. Select the best candidate
5. If no candidates from Match.Corpses, use radar data positions
   (walk to the position; corpse may become visible en route)
```

### Integration with Existing `InvestigateCorpse`

`AmnesiacSeek` and `InvestigateCorpse` use the **same search mechanism** (`CORPSE.ShowSearch`). The key difference is that `AmnesiacSeek`:
- Has no random dice roll
- Is placed at higher priority in the tree
- Doesn't need to extract evidence (the addon hook handles role conversion)
- Has urgency awareness (escalates behavior in later phases)

Once the Amnesiac converts, `AmnesiacSeek.Validate()` returns `false` (bot is no longer `ROLE_AMNESIAC`), and the tree naturally falls through to whatever the new role's tree provides.

---

## 7. Dynamic Tree Switching (Pre/Post-Copy)

### Architecture Decision: Direct vs. `GetTreeFor` Override

**Option A: Direct (no override needed)**
The existing `GetTreeFor()` calls `GetRoleFor(bot):GetBTree()`. After conversion, `GetRoleStringRaw()` returns the new role name, so `GetRoleFor()` returns the new role's `RoleData` and its tree. This means tree switching is **automatic**.

**Option B: Explicit override (recommended)**
Even though Option A works, we should still use the `GetTreeFor` override pattern because:
1. There's a **1-2 tick window** after `TTT2UpdateSubrole` fires but before the next `RunTree` cycle where the old behavior may still be "running" with stale state
2. The coordinator needs to `nil` out `bot.lastBehavior` to force tree re-evaluation
3. Future role-specific post-conversion behaviors (e.g., "act confused" after becoming innocent) need a hook point

### Chain Pattern Compatibility

The `GetTreeFor` override uses the **chain pattern** established by Infected, Necromancer, and Cupid:

```lua
local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor
function TTTBots.Behaviors.GetTreeFor(bot)
    -- Amnesiac-specific logic
    if bot:GetSubRole() == ROLE_AMNESIAC then
        return preConversionTree
    end
    return _origGetTreeFor(bot)  -- Chain to previous override
end
```

**Load Order Consideration:** If `roles/amnesiac.lua` loads before `roles/infected.lua` or `roles/necromancer.lua`, the chain order is Amnesiac → base. If it loads after, the chain is Amnesiac → Infected → Necromancer → ... → base. This is correct behavior as long as the role check is specific (only intercept for `ROLE_AMNESIAC`).

---

## 8. Amnesiac Coordinator (`sv_amnesiaccoordinator.lua`)

### Responsibilities

| Responsibility | Implementation |
|---|---|
| Detect role change | `TTT2UpdateSubrole` hook: `oldSubrole == ROLE_AMNESIAC` |
| Reset suspicion | Clear morality suspicion table |
| Clear evidence | Clear evidence entries (stale pre-conversion data) |
| Clear attack targets | `nil` out `bot.attackTarget` and `bot.lastBehavior` |
| Fire chatter | "AmnesiacConversionSuccess" for bot, "AmnesiacConversionWitnessed" for witnesses |
| Witness notification | Bots who see the popup react (everyone gets it if `showpopup` is true) |
| Urgency ticker | Late-round timer for "AmnesiacDesperateLate" chatter |
| Round cleanup | Clear coordinator state on `TTTEndRound` |

### Suspicion/Evidence Reset Logic

The Cursed coordinator established the pattern:

```lua
-- Reset suspicion
local morality = ply.components and ply.components.morality
if morality and morality.ResetSuspicions then
    morality:ResetSuspicions()
elseif morality and morality.suspicions then
    table.Empty(morality.suspicions)
end

-- Clear evidence
local evidence = ply.components and ply.components.evidence
if evidence and evidence.ClearAllEvidence then
    evidence:ClearAllEvidence()
elseif evidence and evidence.evidenceEntries then
    table.Empty(evidence.evidenceEntries)
end
```

**For Amnesiac, this reset is critical because:**
- Pre-conversion, the bot was `TEAM_NONE` — no allies, no enemies
- Post-conversion, the bot may be `TEAM_TRAITOR` — suddenly has allies and enemies
- Stale suspicion data from the neutral phase would pollute the new role's morality system
- Evidence gathered while neutral is irrelevant to the new role's objectives

### Popup-Awareness System

When `ttt2_amnesiac_showpopup` is `true`, the server broadcasts the conversion to all clients. For bot integration:

```lua
-- On conversion, if showpopup is true, ALL bots should react
if GetConVar("ttt2_amnesiac_showpopup"):GetBool() then
    for _, bot in ipairs(TTTBots.Bots) do
        if not IsValid(bot) or bot == ply then continue end
        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("AmnesiacConversionWitnessed", {
                role = roles.GetByIndex(newSubrole).name or "unknown"
            })
        end
    end
end
```

---

## 9. Morality & Hostility Implications

### Pre-Conversion (Amnesiac)

| System | Behavior |
|---|---|
| `attackEnemies` | No enemies defined → no attacks |
| `attackNonAllies` | `StartsFights=false`, `KOSAll=false` → no attacks |
| `attackKOSedByAll` | Still fires — Amnesiac will attack KOSed-by-all targets (Doomguy etc.) |
| `personalSpace` | `UsesSuspicion=false` → skipped |
| `noticeTraitorWeapons` | `UsesSuspicion=false` → skipped |
| `preventAttackAlly` | Only jesters are allied |
| `preventAttack` | `NeutralOverride=false` → Amnesiac CAN be attacked by others |

**Issue:** The Amnesiac bot won't initiate fights but CAN be attacked. The bot relies solely on `FightBack` (self-defense) in the behavior tree for survival. This is correct — Amnesiac should avoid confrontation.

### Post-Conversion Race Condition

When the Amnesiac converts to (e.g.) Traitor:
1. `TTT2UpdateSubrole` fires → coordinator handles cleanup
2. **But** the morality hostility timer fires every 1 second independently
3. If the timer fires between the role change and the coordinator's `timer.Simple(0.1)` cleanup, the bot might:
   - Attack its new allies (stale evidence says they're suspicious)
   - Not attack its new enemies (no evidence against them yet)

**Mitigation:** The coordinator should set a temporary `bot._amnesiacTransitionGrace` flag that hostility functions check:

```lua
-- In coordinator:
bot._amnesiacTransitionGrace = CurTime() + 2  -- 2-second grace period

-- In hostility functions (proposal):
if bot._amnesiacTransitionGrace and CurTime() < bot._amnesiacTransitionGrace then
    return  -- Skip hostility evaluation during transition
end
```

This pattern is similar to the existing respawn grace gate in `sv_morality_arbitration.lua`.

---

## 10. Chatter Events

### Event Registration (sv_chatter_events.lua additions)

```lua
-- Amnesiac role events
AmnesiacSeekingCorpse          = 60,  -- Bot spots a body to investigate for role acquisition
AmnesiacConversionSuccess      = 90,  -- Bot successfully converted to a new role
AmnesiacConversionWitnessed    = 85,  -- Another bot sees the conversion popup
AmnesiacDesperateLate          = 75,  -- Late-round urgency — still hasn't converted
AmnesiacNoBodiesAvailable      = 50,  -- No unconfirmed corpses exist
AmnesiacPostConvDisguise       = 70,  -- Post-conversion "act natural" behavior
```

### Locale Strings (locale/en/amnesiac.lua — new file)

```lua
TTTBots.Locale["AmnesiacSeekingCorpse"] = {
    "I need to check that body...",
    "There's a body over there, I need to see it.",
    "Let me investigate that corpse.",
    "I have a feeling about that body...",
}

TTTBots.Locale["AmnesiacConversionSuccess"] = {
    "I remember now... I remember everything.",
    "It's all coming back to me.",
    "I know who I am now.",
    "My memory... it's returned.",
}

TTTBots.Locale["AmnesiacConversionWitnessed"] = {
    "Did someone just remember who they are?",
    "An amnesiac found their role...",
    "Uh oh, someone just got a new identity.",
    "That amnesiac popup... interesting.",
}

TTTBots.Locale["AmnesiacDesperateLate"] = {
    "I need to find a body, FAST.",
    "Time is running out and I still don't know who I am!",
    "Come on, there has to be a body somewhere!",
    "I'm running out of time...",
}

TTTBots.Locale["AmnesiacNoBodiesAvailable"] = {
    "Where are all the bodies?",
    "Nobody has died yet... great.",
    "I can't remember if there aren't any clues!",
}

TTTBots.Locale["AmnesiacPostConvDisguise"] = {
    "Act natural, act natural...",
    "Nobody saw that, right?",
    "Just play it cool...",
    "I need to blend in now.",
}
```

---

## 11. Convar Awareness

### Required Convar Reads

| Convar | Where Used | How |
|---|---|---|
| `ttt2_amnesiac_limit_to_unconfirmed` | `AmnesiacSeek.Validate()` | Filter corpses: skip confirmed bodies if `true` |
| `ttt2_amnesiac_confirm_player` | `AmnesiacSeek.OnRunning()` | Affects whether `CORPSE.ShowSearch` also confirms the body |
| `ttt2_amnesiac_showpopup` | `sv_amnesiaccoordinator.lua` | If `true`, all bots react to conversion popup |

### Convar-Driven Target Filtering

```lua
-- In AmnesiacSeek.GetValidCorpses(bot):
local limitToUnconfirmed = GetConVar("ttt2_amnesiac_limit_to_unconfirmed"):GetBool()

for _, corpse in pairs(TTTBots.Match.Corpses) do
    if not IsValid(corpse) then continue end
    
    local isFound = CORPSE.GetFound(corpse, false)
    
    -- If limit_to_unconfirmed is true, skip confirmed bodies
    if limitToUnconfirmed and isFound then continue end
    
    -- If limit_to_unconfirmed is false, all bodies are valid targets
    table.insert(validCorpses, corpse)
end
```

---

## 12. Edge Cases & Race Conditions

### E1: No Bodies Exist (Early Round)

**Scenario:** Amnesiac spawns, no one has died yet.
**Current behavior:** Bot wanders aimlessly.
**Enhanced behavior:** Bot patrols normally, staying near other players to be positioned when a body drops. `AmnesiacSeek.Validate()` returns `false`, tree falls through to Patrol.

### E2: All Bodies Are Confirmed

**Scenario:** All corpses are confirmed and `limit_to_unconfirmed` is `true`.
**Current behavior:** Bot wanders.
**Enhanced behavior:** `AmnesiacSeek.Validate()` returns `false`. Bot falls through to patrol/wander. Fire "AmnesiacNoBodiesAvailable" chatter periodically.

### E3: Amnesiac Kills Someone

**Scenario:** Bot kills a player in self-defense, creating a fresh corpse.
**Enhanced behavior:** The bot should immediately recognize this as a prime opportunity — they created their own unconfirmed corpse! `AmnesiacSeek` should prioritize self-defense kills via `isOwnSelfDefenseKill()` check (already present in `InvestigateCorpse` — reuse that pattern).

### E4: Conversion During Combat

**Scenario:** Bot is in `FightBack` behavior, kills an opponent, and the body search converts them.
**Issue:** Mid-combat conversion changes alliances. The bot might stop fighting its current attacker (who is now an ally).
**Mitigation:** Coordinator clears `bot.attackTarget` and `bot.lastBehavior`. The respawn/transition grace prevents immediate re-targeting.

### E5: Conversion to Traitor While Near Innocents

**Scenario:** Bot converts to Traitor in front of 3 innocent players.
**Issue:** The popup reveals the Amnesiac became a Traitor. Innocent bots should immediately suspect this player.
**Mitigation:** Coordinator fires evidence on witnessing bots:
```lua
evidence:AddEvidence({
    type = "AMNESIAC_CONVERSION",
    subject = ply,
    detail = "became " .. newRoleName .. " (amnesiac popup)",
    weight = 5,  -- Medium weight — suspicion, not auto-KOS
})
```

### E6: Conversion to a Role That Has `GetTreeFor` Override

**Scenario:** Amnesiac converts to Infected or Necromancer or Cupid.
**Issue:** These roles have their own `GetTreeFor` overrides. After conversion, the chain should correctly route to the new role's override.
**Verification:** Because the Amnesiac override only intercepts for `bot:GetSubRole() == ROLE_AMNESIAC`, and after conversion the subrole changes, the chain falls through to the next override which catches the new role.

### E7: Server Convar Change Mid-Round

**Scenario:** Admin changes `ttt2_amnesiac_limit_to_unconfirmed` mid-round.
**Mitigation:** `AmnesiacSeek` reads the convar fresh each `Validate()` call. No caching needed.

### E8: Multiple Amnesiacs in One Round

**Scenario:** `maximum > 1` in role convar settings.
**Issue:** Two Amnesiacs race for the same body.
**Behavior:** First to search gets the role; second finds a confirmed body. `AmnesiacSeek.Validate()` rechecks on next tick and finds no valid targets.

---

## 13. Personality-Driven Behavior Modulation

### Trait Integration Points

```lua
-- In AmnesiacSeek.Validate():
local personality = bot:BotPersonality()
local seekMult = personality:GetTraitMult("investigateCorpse")

-- Tryhard/Sus: always seek (mult doesn't matter, always true)
-- Casual/Dumb: might add a small delay between seek attempts
-- Hothead: might attack someone blocking their path to a corpse
```

### Urgency Escalation Formula

```
urgency = base_urgency × phase_multiplier × personality_multiplier

Where:
  base_urgency = 1.0
  phase_multiplier:
    EARLY  = 0.6 (no rush, no bodies likely)
    MID    = 1.0 (normal urgency)
    LATE   = 1.5 (high urgency, must convert before round ends)
    OVERTIME = 2.0 (desperation)
  personality_multiplier:
    Tryhard = 1.3
    Hothead = 1.5
    Stoic   = 0.8
    Casual  = 0.6
    Dumb    = Random(0.5, 1.5)
```

### Post-Conversion Discretion

After conversion, the bot should exhibit different behavior based on personality:

| Archetype | Post-Conversion Behavior |
|---|---|
| Tryhard | Immediately adopts new role's optimal play style |
| Stoic | Pauses briefly, "processes" the memory restoration |
| Hothead | Immediately attacks enemies if nearby |
| Casual | Continues walking as if nothing happened |
| Sus | Moves away from the body, avoids eye contact |
| Dumb | Might blurt out what they became in chat |

---

## 14. Implementation Priority & File Manifest

### Priority Order

| Priority | Phase | Files | Dependencies |
|---|---|---|---|
| **P1** | Phase 1: Coordinator | `lib/sv_amnesiaccoordinator.lua` | None (auto-included) |
| **P2** | Phase 3: Tree switching | `roles/amnesiac.lua` (modify) | P1 |
| **P3** | Phase 2: SeekCorpse behavior | `behaviors/amnesiacseek.lua` | P2 |
| **P4** | Phase 4: Chatter | `chatter/sv_chatter_events.lua` (modify), `locale/en/amnesiac.lua` (new) | P1, P3 |
| **P5** | Phase 5: Personality | `roles/amnesiac.lua` (modify) | P3, P4 |

### File Manifest

| File | Action | Description |
|---|---|---|
| `lua/tttbots2/lib/sv_amnesiaccoordinator.lua` | **CREATE** | Coordinator: TTT2UpdateSubrole hook, suspicion/evidence reset, popup awareness, urgency ticker, round cleanup |
| `lua/tttbots2/behaviors/amnesiacseek.lua` | **CREATE** | AmnesiacSeek behavior: dedicated corpse-seeking with convar awareness, no dice roll, urgency scaling |
| `lua/tttbots2/roles/amnesiac.lua` | **MODIFY** | Add pre-conversion tree with AmnesiacSeek, add GetTreeFor override chain, update RoleData properties |
| `lua/tttbots2/components/chatter/sv_chatter_events.lua` | **MODIFY** | Add 6 new Amnesiac chatter events |
| `lua/tttbots2/locale/en/amnesiac.lua` | **CREATE** | English locale strings for Amnesiac chatter events |
| `lua/tttbots2/components/morality/sv_morality_hostility.lua` | **MODIFY** (optional) | Add transition grace check for Amnesiac conversion window |

---

## 15. Testing Checklist

### Functional Tests

- [ ] **T1:** Bot as Amnesiac walks to and searches an unconfirmed corpse → role converts correctly
- [ ] **T2:** Bot as Amnesiac ignores confirmed corpses when `limit_to_unconfirmed` is `true`
- [ ] **T3:** Bot as Amnesiac searches confirmed corpses when `limit_to_unconfirmed` is `false`
- [ ] **T4:** After conversion, bot's behavior tree matches the new role (traitor tree for traitor, etc.)
- [ ] **T5:** After conversion, suspicion/evidence is reset (bot doesn't attack new allies)
- [ ] **T6:** After conversion to traitor, bot starts fighting non-allies
- [ ] **T7:** After conversion to innocent, bot participates in InnocentCoordinator
- [ ] **T8:** After conversion to detective, bot uses DNA scanner and accuses
- [ ] **T9:** Popup-aware chatter fires for all bots when `showpopup` is enabled
- [ ] **T10:** Urgency chatter fires in LATE/OVERTIME phases
- [ ] **T11:** Multiple Amnesiacs don't race-condition on the same corpse
- [ ] **T12:** Bot survives self-defense combat and then converts via the created corpse
- [ ] **T13:** Conversion to Infected/Necromancer/Cupid correctly chains GetTreeFor overrides
- [ ] **T14:** Bot doesn't attack anyone during 2-second transition grace window

### Regression Tests

- [ ] **R1:** Non-Amnesiac bots still investigate corpses normally
- [ ] **R2:** InvestigateCorpse behavior unaffected for other roles
- [ ] **R3:** Existing coordinator hooks (Infected, Cursed, Necro) still fire correctly
- [ ] **R4:** Morality hostility system unaffected for non-Amnesiac bots
- [ ] **R5:** Chatter system doesn't break with new event registrations

---

## 16. Appendix: Cross-Reference with Other Role Analyses

### Patterns Borrowed

| Pattern | Source Role | Application to Amnesiac |
|---|---|---|
| `TTT2UpdateSubrole` hook coordinator | Cursed, Infected, Necromancer | Detect conversion, cleanup state |
| Suspicion/evidence reset on role change | Cursed | Wipe stale neutral-phase data |
| `GetTreeFor` chain override | Infected, Necromancer, Cupid | Pre/post-conversion tree switching |
| Urgency ticker | Cursed | Late-round desperation chatter |
| Witness notification loop | Infected, Cursed | All bots react to popup |
| `preventWin = true` urgency | Cursed (cannot deal damage) | Amnesiac cannot win — must convert |
| Phase-aware behavior gating | Morality hostility system | Urgency scaling by round phase |
| Personality modulation table | Spy | Per-archetype behavior multipliers |

### Unique Amnesiac Challenges (Not Seen in Other Roles)

1. **Role is inherently temporary** — the Amnesiac is the only role designed to be replaced mid-round as its *primary mechanic*. Other roles (Cursed, Infected) change *other people's* roles.

2. **The new role is unpredictable** — unlike Cursed (always swaps 1:1) or Infected (always becomes zombie), the Amnesiac can become *any* role. The coordinator must handle all possible destination roles.

3. **Corpse dependency** — the mechanic requires dead players. If no one dies, the Amnesiac is permanently stuck. The bot needs patience behavior and urgency scaling.

4. **Information asymmetry reversal** — pre-conversion, the Amnesiac knows nothing (no team intel). Post-conversion, they might suddenly know everything (if they become a traitor). The evidence system must handle this transition.

5. **The radar is a unique asset** — no other role gets corpse-position radar at spawn. The bot should leverage this for navigation to non-visible bodies.

---

*End of Analysis*
