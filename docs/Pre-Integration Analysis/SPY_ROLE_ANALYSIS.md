# Spy Role — Complete Integration Analysis & Implementation Plan

> **Date:** 2026-03-09  
> **Scope:** TTT2-Bots-2 × ttt2-role_spy-master  
> **Status:** Planning

---

## Table of Contents

1. [Spy Role Mechanics Summary](#1-spy-role-mechanics-summary)
2. [Current Bot Implementation (spy.lua)](#2-current-bot-implementation)
3. [Critical Bugs & Problems](#3-critical-bugs--problems)
4. [Gap Analysis — Systems Missing Spy Awareness](#4-gap-analysis)
5. [Implementation Strategy](#5-implementation-strategy)
6. [Detailed Task Checklist](#6-detailed-task-checklist)
7. [New Behaviors & Chatter Events](#7-new-behaviors--chatter-events)
8. [Locale & Prompt Additions](#8-locale--prompt-additions)
9. [Testing Matrix](#9-testing-matrix)

---

## 1. Spy Role Mechanics Summary

The Spy (`ttt2-role_spy-master`) is an **INNOCENT-team** role that **appears as a traitor** to all traitor-side players. It is one of the most deceptive roles in TTT2.

### Core Mechanics

| Mechanic | Detail |
|----------|--------|
| **Actual Team** | `TEAM_INNOCENT` |
| **Base Role** | `ROLE_INNOCENT` |
| **Visible As** | `ROLE_TRAITOR` / `TEAM_TRAITOR` to all traitors (via `TTT2SpecialRoleSyncing`) |
| **On Radar** | Appears as traitor to traitor radar (`TTT2ModifyRadarRole4Spy`) |
| **In Traitor List** | Spy name added to the "fellow traitors" announcement (`TTT2TellTraitors`) |
| **Team Chat** | **Jams traitor team text chat** while any Spy is alive (`TTT2AvoidTeamChat`) |
| **Team Voice** | **Jams traitor team voice chat** while any Spy is alive (`TTT2CanUseVoiceChat`) |
| **Traitor Shop** | Fake-buy only — sends `TEBN_ItemBought` net msg to traitors, no real purchase (`TTTCanOrderEquipment`) |
| **Corpse on Death** | Confirmed as **traitor** (not spy), unless all traitors are dead + `ttt2_spy_reveal_true_role` enabled (`TTTCanSearchCorpse` / `TTT2ConfirmPlayer`) |
| **Role Jamming** | When `ttt2_spy_jam_special_roles` enabled, all special traitors (mesmerist, hitman, etc.) also display as normal traitors |
| **Hitman Target** | Cannot be a hitman target (`TTT2CanBeHitmanTarget`) |
| **Scoring** | Survival bonus (default 3) via `EVENT_SPY_ALIVE` |
| **Equipment** | `SPECIAL_EQUIPMENT`, 1 credit, traitor shop fallback |

### ConVars

| ConVar | Default | Effect |
|--------|---------|--------|
| `ttt2_spy_fake_buy` | `1` | Restrict spy to fake purchases only |
| `ttt2_spy_confirm_as_traitor` | `1` | Dead spy corpse shows as traitor |
| `ttt2_spy_reveal_true_role` | `1` | Reveal true role when all traitors die |
| `ttt2_spy_jam_special_roles` | `1` | All traitor subtypes shown as generic traitor |
| `ttt2_spy_survival_bonus` | `3` | Scoring bonus for surviving a round |

### What Makes the Spy Unique

1. **Information warfare** — Traitors waste time coordinating with someone who's sabotaging them
2. **Communication denial** — Blocks traitor team chat/voice, forcing public communication
3. **Corpse deception** — Even in death, the spy confuses traitors about team composition
4. **Traitor economy disruption** — Fake purchases deceive traitors about equipment distribution

---

## 2. Current Bot Implementation

**File:** `lua/tttbots2/roles/spy.lua` (13 lines)

```lua
local spy = TTTBots.RoleData.New("spy")
spy:SetDefusesC4(false)
spy:SetTeam(TEAM_INNOCENT)
spy:SetBTree(TTTBots.Behaviors.DefaultTrees.innocent)
spy:SetCanHide(true)
spy:SetCanSnipe(true)
spy:SetUsesSuspicion(true)
spy:SetIsFollower(true)
TTTBots.Roles.RegisterRole(spy)
```

### What It Does Right

- ✅ Correct team: `TEAM_INNOCENT`
- ✅ Uses the innocent behavior tree
- ✅ Uses the suspicion system (can accuse/vouch)
- ✅ Can hide and snipe (innocent combat behaviors)
- ✅ Has follower tendency (blends in)

### What's Missing — Everything Below

---

## 3. Critical Bugs & Problems

### BUG-1: Traitor Bots See Through Spy Disguise (CRITICAL)

**The Problem:** All bot alliance checks use server-side actual team/role data (`GetTeam()`, `GetRoleStringRaw()`, `IsAllies()`). Traitor bots immediately know the Spy is NOT their ally because `IsAllies(traitor, spy)` returns `false` — the Spy's team is `TEAM_INNOCENT`, not `TEAM_TRAITOR`.

**Impact:** The entire Spy role is mechanically broken for bot gameplay:
- Traitor bots will **stalk and kill the Spy** (via `GetNonAllies()`)
- Traitor bots will **never coordinate** with the Spy
- Traitor bots will **never share plans** with the Spy
- The Spy gets no benefit from its disguise

**Root cause locations:**
- `sv_roles.lua` → `IsAllies()` — checks actual `GetTeam()`, not perceived role
- `sv_morality_hostility.lua` → `attackNonAllies()`, `attackEnemies()` — use `GetNonAllies()`
- `behaviors/stalk.lua` → witness check via `GetNonAllies()`
- `sv_plancoordinator.lua` → plan assignment via `IsAllies()`

### BUG-2: Spy Bot Has No Deception Capability

The Spy bot runs the standard innocent behavior tree, making it mechanically indistinguishable from a regular innocent. It has **zero** spy-specific behaviors:
- No jamming awareness (doesn't know it's blocking traitor comms)
- No fake-buy behavior
- No intelligence gathering from traitor coordination attempts
- No proactive disruption of traitor plans

### BUG-3: Missing Chatter Integration

- **0 locale strings** for spy-specific events
- **0 LLM prompt templates** for spy-specific scenarios
- No chatter events for: spy discovering traitors, spy using fake buy, spy realizing it's jammed comms, spy reacting to being "welcomed" by traitors

### BUG-4: Evidence System Doesn't Account for Spy Perception

- Traitor bots gathering evidence on the Spy won't flag it as "ally acting suspicious" — they treat it like any other innocent
- The Spy doesn't get intel from observing traitor coordination (whispers, grouping, plan execution)
- No evidence type for "claimed traitor but acting innocent" (perception mismatch)

### BUG-5: No Dead Ringer Integration

`sv_default_buyables.lua` registers `weapon_ttt_deadringer` for the spy role, but there is **no behavior** for:
- Deciding when to buy/equip the Dead Ringer
- Using it to fake death
- Post-fake-death behavior (hide, relocate, re-engage)

### BUG-6: RoleDescription for LLM Missing

The RoleData's `SetRoleDescription()` is never called. When LLM prompts reference the spy's role, they get a generic placeholder instead of a description like: *"You are a Spy — you appear as a traitor to traitors but you are actually innocent. Jam their communications and gather intelligence."*

---

## 4. Gap Analysis — Systems Missing Spy Awareness

### 4.1 Alliance & Perception Layer (CRITICAL)

| System | Current State | Required State |
|--------|---------------|----------------|
| `IsAllies(traitor, spy)` | Returns `false` (correct by actual team) | Should return `true` **from the traitor's perspective** (perceived ally) |
| `IsAllies(spy, traitor)` | Returns `false` | Should remain `false` (Spy knows the truth) |
| Hostility policy | Traitors target Spy as enemy | Traitors should **not** target Spy (they think it's an ally) |
| Plan Coordinator | Excludes Spy from traitor plans | Should **include** Spy in traitor plans (unwittingly) |
| Stalk behavior | Spy is a valid stalk target for traitors | Should be **excluded** from traitor stalking |

**Key design decision:** The alliance system needs **asymmetric perception**. Traitor→Spy should be perceived-ally. Spy→Traitor should be actual-enemy (but the Spy can choose to act friendly).

### 4.2 Communication Layer

| System | Current State | Required State |
|--------|---------------|----------------|
| Traitor team chat (bots) | No awareness of jamming | Bots should notice team chat is jammed and react |
| Spy eavesdropping | Not implemented | Spy could "overhear" traitor coordination (public chat by frustrated traitors) |
| Spy-specific chatter events | None exist | Need 10+ events (see §7) |
| False-buy announcement | Not implemented | Spy should fake-purchase and traitors should notice |
| Post-round spy reveal chatter | Not implemented | Traitors should react to discovering a spy was among them |

### 4.3 Behavior Layer

| Behavior | Status | Notes |
|----------|--------|-------|
| Innocent tree basics | ✅ Working | Investigate, accuse, vouch, group up, follow |
| Spy-specific deception | ❌ Missing | Intelligence gathering from traitor plans |
| Fake equipment purchase | ❌ Missing | Dead Ringer / traitor items |
| Traitor confidence play | ❌ Missing | Act like you "belong" near traitors |
| KOS deflection | ❌ Missing | When traitors realize you're not attacking innocents |
| Chat-jamming awareness | ❌ Missing | React to/leverage the team chat jam |
| Post-reveal survival | ❌ Missing | When traitors figure out you're a spy |

### 4.4 Evidence & Suspicion Layer

| System | Current State | Required State |
|--------|---------------|----------------|
| Spy building evidence on traitors | ✅ Works (innocent tree) | Could be enhanced — spy has unique intel opportunity |
| Traitor bots tracking spy | ❌ Broken (treats as innocent) | Should have delayed suspicion (they think spy is ally) |
| Spy's perception advantage | ❌ Not implemented | Spy knows who traitors are (via team list announcement) |
| Evidence sharing near traitors | ❌ Dangerous | Spy shouldn't share evidence with traitors it's near |

### 4.5 Coordination Layer

| System | Current State | Required State |
|--------|---------------|----------------|
| Traitor plan includes spy | ❌ Excluded | Should include (traitors think spy is ally) |
| Spy sabotages plans | ❌ Not implemented | Spy could leak plans, warn targets, or simply not follow through |
| Traitor discovers spy non-compliance | ❌ Not implemented | Traitors should get suspicious of spy if orders aren't followed |

---

## 5. Implementation Strategy

### Architecture Overview

The spy integration requires changes across **4 layers**, ordered by priority:

```
Layer 1 — Perception (CRITICAL)
  └─ Asymmetric alliance: traitor bots believe spy is ally
  └─ Spy knows who traitors are (perception advantage)

Layer 2 — Behavior (HIGH)
  └─ New spy-specific behaviors
  └─ Modified existing behaviors for spy context

Layer 3 — Communication (HIGH)
  └─ Chatter events for spy scenarios
  └─ Locale strings and LLM prompts
  └─ Team chat jamming awareness

Layer 4 — Advanced Integration (MEDIUM)
  └─ Plan coordinator spy inclusion/sabotage
  └─ Evidence system enhancements
  └─ Dead Ringer behavior
  └─ Post-reveal dynamics
```

### Approach: Perception Hook System

Rather than modifying `IsAllies()` globally (which would break actual team logic), introduce a **perception overlay** that traitor bots consult:

```
TTTBots.Perception.IsPerceivedAlly(observer, target) → bool
  - If observer is traitor-team AND target is spy → true
  - Otherwise → TTTBots.Roles.IsAllies(observer, target)

TTTBots.Perception.GetPerceivedRole(observer, target) → string
  - If observer is traitor-team AND target is spy → "traitor"
  - Otherwise → target:GetRoleStringRaw()
```

Systems that should use **perceived** alliance (traitor-facing):
- Hostility policy (`attackNonAllies`, `attackEnemies`)
- Stalk target selection
- Plan coordinator job assignment
- Follow teammate filter
- Witness threshold (traitors shouldn't avoid witnesses who they think are allies)

Systems that should use **actual** alliance (truth-based):
- Spy's own behavior tree and decisions
- Evidence system (spy correctly builds evidence on traitors)
- Scoring
- Round-end evaluation

---

## 6. Detailed Task Checklist

### Phase 1 — Perception Layer (CRITICAL)

- [ ] **P1-1:** Create `lib/sv_perception.lua` with `TTTBots.Perception` namespace
  - [ ] `IsPerceivedAlly(observer, target)` — asymmetric alliance check
  - [ ] `GetPerceivedRole(observer, target)` — what role does observer think target has
  - [ ] `GetPerceivedTeam(observer, target)` — what team does observer think target is on
  - [ ] `IsSpyDisguiseActive(target)` — checks if target is alive spy (disguise breaks on death)
  - [ ] Cache invalidation on round start and spy death

- [ ] **P1-2:** Patch hostility policy to use perception
  - [ ] `sv_morality_hostility.lua` → `attackNonAllies()` — filter out perceived allies
  - [ ] `sv_morality_hostility.lua` → `attackEnemies()` — skip perceived allies
  - [ ] `sv_morality_hostility.lua` → `attackKOSedByAll()` — respect perceived role
  - [ ] `sv_morality_hostility.lua` → `noticeTraitorWeapons()` — traitors should ignore spy's "traitor" weapons

- [ ] **P1-3:** Patch stalk behavior for perception
  - [ ] `behaviors/stalk.lua` → target selection should exclude perceived allies
  - [ ] Witness check should count perceived allies as "safe" witnesses

- [ ] **P1-4:** Give spy knowledge of traitor identities
  - [ ] On role assignment, populate spy's evidence component with traitor identity info
  - [ ] Spy should know who the traitors are (mirrors the `TTT2TellTraitors` hook)
  - [ ] This knowledge should inform the spy's behavior (avoid, observe, report)

- [ ] **P1-5:** Update the spy RoleData registration
  - [ ] Add `RoleDescription` for LLM context
  - [ ] Add `AlliedRoles` for self-awareness (spy allied with innocents)
  - [ ] Add `AlliedTeams` explicitly: `{[TEAM_INNOCENT] = true}`
  - [ ] Consider `SetKnowsLifeStates(false)` (spy shouldn't have omniscience)
  - [ ] Set `SetCanCoordinateInnocent(true)` (spy can share intel with innocents)

### Phase 2 — Core Behaviors (HIGH)

- [ ] **P2-1:** Create `behaviors/spyblend.lua` — Blend In With Traitors
  - [ ] Spy occasionally approaches traitors to appear as if coordinating
  - [ ] Maintains a safe distance (not too close = suspicious, not too far = absent)
  - [ ] Triggers when spy knows nearby traitor is alone or in small group
  - [ ] Phase-gated: primarily EARLY/MID phase
  - [ ] Chatter event: `"SpyBlendIn"` — generic traitor-like small talk

- [ ] **P2-2:** Create `behaviors/spyreport.lua` — Report Traitor Intel
  - [ ] When spy has observed traitor behavior (kills, C4 plant, suspicious movement)
  - [ ] Find an isolated innocent and share evidence via chatter
  - [ ] Use `AccuseKOS` / `AccuseSoft` events targeting traitors
  - [ ] Phase-gated: MID/LATE (too early is suspicious, spy needs to gather intel first)
  - [ ] Cooldown: 60s between reports

- [ ] **P2-3:** Create `behaviors/spyfakebuy.lua` — Fake Equipment Purchase
  - [ ] If `ttt2_spy_fake_buy` is enabled
  - [ ] Spy approaches a buy zone / opens buy menu
  - [ ] Triggers the fake-buy mechanic (traitors see notification)
  - [ ] Chatter event: `"SpyFakeBuy"` (team-only to traitors: "just bought something")
  - [ ] Chance-based: 30% per round, once per round max

- [ ] **P2-4:** Create `behaviors/spyeavesdrop.lua` — Eavesdrop on Traitor Plans
  - [ ] When traitor bots execute plan-related behaviors near the spy
  - [ ] Spy observes and records plan details (gather point, attack target, bomb location)
  - [ ] This intel feeds into the spy's evidence component
  - [ ] Enables `spyreport` behavior with richer detail
  - [ ] No explicit chatter (silent observation)

- [ ] **P2-5:** Modify `behaviors/follow.lua` for spy context
  - [ ] When spy is the follower and target is a known traitor → use "blend in" follow distance
  - [ ] Don't share evidence while following a traitor
  - [ ] Occasionally "check in" via chatter (generic messages, not role-revealing)

- [ ] **P2-6:** Modify `behaviors/accuseplayer.lua` for spy context
  - [ ] Spy should have slightly higher accusation threshold for traitors initially (to maintain cover)
  - [ ] After MID phase, spy becomes more aggressive with accusations
  - [ ] Spy accusations of traitors should carry extra evidence weight (unique `SPY_INTEL` evidence type)

### Phase 3 — Communication & Chatter (HIGH)

- [ ] **P3-1:** Register spy-specific chatter events in `chancesOf100`
  - [ ] `SpyBlendIn` — 40% — Generic small talk while near traitors
  - [ ] `SpyFakeBuy` — 80% — Announce fake purchase (team-only to traitors)
  - [ ] `SpyReportIntel` — 75% — Share traitor intel with innocents
  - [ ] `SpyReactJam` — 35% — React to team chat being jammed (for traitor bots)
  - [ ] `SpyCoverBlow` — 90% — React when spy suspects their cover is blown
  - [ ] `SpyPostReveal` — 85% — Post-round or discovery chatter
  - [ ] `SpyDeflection` — 60% — When traitors ask spy why they haven't attacked anyone
  - [ ] `SpySurvival` — 70% — End-of-round survival comment
  - [ ] `TraitorSuspectsSpy` — 50% — Traitor bot voices suspicion about the spy's inaction
  - [ ] `TraitorDiscoversSpy` — 90% — Traitor bot realizes spy is fake

- [ ] **P3-2:** Create locale strings (`locale/en/sh_chats.lua` additions)
  - [ ] 5-8 archetype variants per event
  - [ ] Cover all 10 archetypes (Default, Casual, Hothead, Stoic, Dumb, Nice, Bad, Sus, Teamer, Tryhard)
  - [ ] Template parameters: `{{player}}`, `{{target}}`, `{{item}}`

- [ ] **P3-3:** Add LLM prompt context for spy role
  - [ ] Role description in prompt: "You're a Spy — an innocent who appears as a traitor to the traitor team. Your goal is to confuse traitors and gather intelligence while maintaining your cover."
  - [ ] Spy-specific instruction set for each event
  - [ ] Context injection: which traitors the spy knows about, whether cover seems intact

- [ ] **P3-4:** Team chat jamming awareness
  - [ ] Traitor bots should react when `TTT2AvoidTeamChat` fires
  - [ ] Fire `SpyReactJam` chatter event on affected traitor bots
  - [ ] Traitors should become suspicious that there's a spy (increase general paranoia)
  - [ ] Hook into `TTT2AvoidTeamChat` / `TTT2CanUseVoiceChat` to detect jammed state

- [ ] **P3-5:** Post-round spy reveal chatter
  - [ ] On `TTTEndRound`, if spy survived: `SpySurvival` event
  - [ ] On `TTTEndRound`, traitor bots discover spy was fake: `SpyPostReveal` event
  - [ ] If spy was killed but confirmed as traitor: traitors don't know (no chatter)
  - [ ] If spy's true role revealed (all traitors dead): `SpyTrueRoleRevealed` event

### Phase 4 — Advanced Integration (MEDIUM)

- [ ] **P4-1:** Plan coordinator spy inclusion
  - [ ] `sv_plancoordinator.lua` → Include spy in traitor plan distribution (traitors believe spy is ally)
  - [ ] Spy receives plan jobs but doesn't execute them (or deliberately sabotages)
  - [ ] When spy receives "ATTACK" job → warn the target instead or simply don't comply
  - [ ] When spy receives "GATHER" job → show up but don't participate in coordinated attacks
  - [ ] Track spy non-compliance as a "suspicion trigger" for traitor bots

- [ ] **P4-2:** Traitor spy-detection mechanics
  - [ ] Timer: Every 30-60s, traitor bots evaluate spy's behavior
  - [ ] Red flags that increase traitor suspicion of spy:
    - Spy hasn't attacked any innocents after X seconds
    - Spy was seen near an innocent group without attacking
    - Spy didn't follow a plan/job
    - Spy called KOS on a traitor
    - Spy was seen vouching for an innocent
  - [ ] When suspicion threshold reached → traitor calls KOS on spy
  - [ ] `TraitorSuspectsSpy` and `TraitorDiscoversSpy` chatter events fire

- [ ] **P4-3:** Evidence system enhancements
  - [ ] New evidence type: `SPY_INTEL` (weight 8) — spy-gathered intelligence
  - [ ] New evidence type: `TRAITOR_COORDINATION_WITNESSED` (weight 6) — spy saw traitors coordinating
  - [ ] New evidence type: `SUSPECTED_SPY` (weight 4) — traitor suspects someone is a spy
  - [ ] Evidence sharing filter: spy should NOT share evidence when traitors are in earshot
  - [ ] Spy evidence is more reliable (multiplier 1.5× for spy-sourced intel)

- [ ] **P4-4:** Dead Ringer behavior
  - [ ] Create `behaviors/spydeadringer.lua`
  - [ ] Buy check: does spy have credits, is Dead Ringer available?
  - [ ] Equip logic: equip when health is low or when being chased
  - [ ] Post-fake-death: spy "dies" but reappears — need behavior for relocation
  - [ ] Chatter integration: spy goes silent after "death" to maintain illusion
  - [ ] Limited to 1 use per round (weapon constraint)

- [ ] **P4-5:** Event system integration
  - [ ] Publish `SPY_COVER_BLOWN` event when traitors discover spy
  - [ ] Publish `SPY_INTEL_SHARED` event when spy reports to innocents
  - [ ] Publish `SPY_FAKE_BUY` event when spy makes a fake purchase
  - [ ] Subscribe to `ATTACK_START` — if attacker is traitor and target is spy, spy switches to survival mode
  - [ ] Subscribe to `KOS_CALLED` — if spy is KOS'd by a traitor, spy's cover is blown

- [ ] **P4-6:** Personality trait interactions
  - [ ] `aggressive` trait spy → shorter cover period, quicker to accuse traitors
  - [ ] `cautious` trait spy → longer cover maintenance, more careful intel gathering
  - [ ] `talkative` trait spy → more chatter while blending, higher risk of slip-ups
  - [ ] `silent` trait spy → excellent cover but less useful intel sharing
  - [ ] `bold` trait spy → may approach traitors directly, higher risk/reward
  - [ ] `loner` trait spy → avoids groups, harder for traitors to monitor but less effective cover

### Phase 5 — Polish & Edge Cases (LOW)

- [ ] **P5-1:** Handle spy + other role interactions
  - [ ] Spy + Detective: spy shares intel with detective preferentially
  - [ ] Spy + Jackal: spy treats jackal as hostile (not traitor-allied)
  - [ ] Spy + Jester: spy doesn't waste effort on jester
  - [ ] Spy + Infected: spy treats infected as hostile
  - [ ] Spy + Bodyguard: bodyguard protecting spy should be extra effective

- [ ] **P5-2:** Handle multi-spy scenarios
  - [ ] Multiple spies should coordinate evidence sharing
  - [ ] Spies should recognize each other (they're both on TEAM_INNOCENT)
  - [ ] Don't double-jam traitor comms awareness (avoid redundant chatter)

- [ ] **P5-3:** Handle spy death edge cases
  - [ ] When spy dies and is confirmed as "traitor" → traitor bots shouldn't mourn an ally death
  - [ ] When `ttt2_spy_reveal_true_role` fires → all bots should update their evidence
  - [ ] Corpse investigation should reflect the modified role data from the spy addon

- [ ] **P5-4:** ConVar respect
  - [ ] All spy behaviors should check `ttt2_spy_fake_buy`, `ttt2_spy_confirm_as_traitor`, etc.
  - [ ] Add bot-specific ConVar: `tttbots_spy_intel_sharing_chance` (default 60%)
  - [ ] Add bot-specific ConVar: `tttbots_spy_cover_duration_min` (default 30s before first accusation)
  - [ ] Add bot-specific ConVar: `tttbots_spy_traitor_detection_rate` (how fast traitors catch on)

- [ ] **P5-5:** Debug & developer tooling
  - [ ] Debug overlay showing spy perception state (who sees spy as ally)
  - [ ] Debug command to force spy cover blown
  - [ ] Log spy intel gathering events for debugging
  - [ ] Add spy to bot menu role selection

---

## 7. New Behaviors & Chatter Events

### Behavior Tree Modification

**Current:** Standard innocent tree  
**Proposed:** Enhanced innocent tree with spy-specific insertions

```
SpyBTree = {
    -- Priority 1: Survival (same as innocent)
    Requests,
    Chatter,
    FightBack,
    SelfDefense,
    Grenades,
    
    -- Priority 2: Spy Intelligence (NEW)
    SpyEavesdrop,        -- Silent observation of traitor plans
    SpyReport,           -- Share intel with innocents
    SpyFakeBuy,          -- Fake equipment purchase
    
    -- Priority 3: Cover Maintenance (NEW)
    SpyBlendIn,          -- Blend in near traitors
    
    -- Priority 4: Standard Innocent (same as innocent)
    Accuse,
    FollowInnocentPlan,
    Support,
    Defuse,
    Restore,
    Interact,
    Investigate,
    Minge,
    Decrowd,
    Patrol,
}
```

### Chatter Event Specifications

| Event | When Fired | Who Speaks | Team-Only | Example Line |
|-------|-----------|------------|-----------|--------------|
| `SpyBlendIn` | Near a traitor, maintaining cover | Spy | No (public) | "Alright, what's the plan?" / "Anything going on over here?" |
| `SpyFakeBuy` | After executing fake purchase | Spy | No (public to look natural) | "Just picked something up from the shop." |
| `SpyReportIntel` | Sharing evidence with innocent | Spy | No (public, framed as normal suspicion) | "I think {{player}} is up to something, I saw them near a body." |
| `SpyReactJam` | Team chat jammed (fired on traitor bot) | Traitor | No (forced public) | "Why can't I use team chat??" / "Something's wrong with comms..." |
| `SpyCoverBlow` | Spy realizes traitors are onto them | Spy | No | "I think they're onto me..." |
| `SpyDeflection` | Traitor asks why spy hasn't killed | Spy | No (careful wording) | "I'm working on it, trust me." / "I've been setting up a play." |
| `SpySurvival` | End of round, spy survived | Spy | No | "And THAT'S how you spy. GG." |
| `TraitorSuspectsSpy` | Traitor notices spy inaction | Traitor | No (public, can't use team chat) | "Has anyone noticed {{player}} hasn't done anything?" |
| `TraitorDiscoversSpy` | Traitor confirms spy is fake | Traitor | No (public) | "{{player}} is the spy! They've been playing us!" |
| `SpyPostReveal` | End of round, roles revealed | Any | No | "Wait, {{player}} was a SPY?!" |

---

## 8. Locale & Prompt Additions

### Locale Structure (for `sh_chats.lua`)

```
-- SPY BLEND-IN
RegisterCategory("SpyBlendIn", NORMAL, "Spy makes small talk near traitors to maintain cover.")
  Line("So, uh, what's the plan?", Default)
  Line("anything happening? just checking in", Casual)
  Line("Let's get this done. Who are we going for?", Hothead)
  Line("Standing by.", Stoic)
  Line("wait are we supposed to be doing something?", Dumb)
  ... (all 10 archetypes)

-- SPY REPORT INTEL
RegisterCategory("SpyReportIntel", IMPORTANT, "Spy shares traitor intelligence with innocents.")
  Line("I've been watching {{player}} — they're definitely suspicious.", Default)
  ...

-- (10 categories × 10 archetypes = ~100 new locale lines)
```

### LLM Prompt Additions

Add to `sh_chatgpt_prompts.lua` or role description:

```
spy_role_description = [[
You are a Spy in TTT2. You appear as a traitor to the traitor team, but you are 
actually on the innocent team. Your goals:
1. Maintain your cover as long as possible — act like you belong with the traitors
2. Gather intelligence on traitor plans and identities
3. Subtly share your intel with innocent players through natural conversation
4. Avoid directly attacking innocent players (your actual allies)
5. When confronted by suspicious traitors, deflect with excuses

You know who the traitors are: {{known_traitors}}
Your cover status: {{cover_status}}
]]
```

---

## 9. Testing Matrix

### Unit Tests

| Test | Expected Result |
|------|-----------------|
| `IsPerceivedAlly(traitor, spy)` | `true` |
| `IsPerceivedAlly(spy, traitor)` | `false` |
| `IsPerceivedAlly(innocent, spy)` | `true` (actual ally) |
| `GetPerceivedRole(traitor, spy)` | `"traitor"` |
| `GetPerceivedRole(innocent, spy)` | `"spy"` |
| Traitor bot stalk target list excludes spy | Spy not in target list |
| Spy behavior tree includes spy-specific behaviors | SpyBlendIn, SpyReport present |
| Spy evidence component has traitor identities | Known traitors populated on round start |

### Integration Tests

| Scenario | Expected Bot Behavior |
|----------|----------------------|
| Round start with 1 spy, 2 traitors | Traitors announce spy as fellow traitor, spy knows traitor identities |
| Spy approaches traitor group | Spy uses SpyBlendIn behavior, traitors don't attack |
| Spy observes traitor kill | Spy records evidence, later reports to innocent |
| Traitor tries team chat | Chat jammed, traitor fires SpyReactJam chatter |
| Spy calls KOS on traitor (mid-round) | KOS processed normally, traitors may realize spy is fake |
| Traitor notices spy hasn't attacked after 90s | TraitorSuspectsSpy event fires |
| Spy dies, corpse found | Corpse shows as traitor (per addon hook) |
| All traitors die, spy alive | Spy true role revealed, SpyTrueRoleRevealed chatter |
| Spy fake-buys equipment | Traitor bots see purchase notification |
| Spy with Dead Ringer at low health | SpyDeadRinger behavior activates |

### Stress Tests

| Scenario | Concern |
|----------|---------|
| 4+ spies in one round | Chatter spam, redundant intel sharing |
| Spy + Jester + Swapper together | Perception system handling multiple deceptive roles |
| All traitors are bots, spy is bot | Full bot-on-bot spy gameplay loop |
| Spy is the only innocent-side player | Edge case: no one to share intel with |
| Spy killed immediately on round start | Dead spy perception cleanup |

---

## Priority Summary

| Priority | Task Group | Effort | Impact |
|----------|-----------|--------|--------|
| 🔴 **P1** | Perception Layer | Medium | Fixes fundamentally broken spy gameplay |
| 🟠 **P2** | Core Behaviors | Medium-High | Gives spy actual spy gameplay |
| 🟡 **P3** | Communication | Medium | Makes spy feel alive in chatter |
| 🟢 **P4** | Advanced Integration | High | Rich spy metagame (plans, detection, Dead Ringer) |
| 🔵 **P5** | Polish & Edge Cases | Low-Medium | Completeness and robustness |

**Recommended implementation order:** P1 → P2 → P3 → P4 → P5  
**Minimum viable spy:** P1 + P2-1 + P2-2 + P3-2 (partial)

---

## Appendix A: Files to Create

| File | Purpose |
|------|---------|
| `lib/sv_perception.lua` | Perception overlay system |
| `behaviors/spyblend.lua` | Blend in with traitors |
| `behaviors/spyreport.lua` | Report intel to innocents |
| `behaviors/spyfakebuy.lua` | Fake equipment purchase |
| `behaviors/spyeavesdrop.lua` | Eavesdrop on traitor plans |
| `behaviors/spydeadringer.lua` | Dead Ringer usage |

## Appendix B: Files to Modify

| File | Change |
|------|--------|
| `roles/spy.lua` | Enhanced RoleData, custom behavior tree, role description, hooks |
| `sv_morality_hostility.lua` | Perception-aware alliance checks |
| `behaviors/stalk.lua` | Perception-aware target filtering |
| `behaviors/follow.lua` | Spy-specific follow logic |
| `behaviors/accuseplayer.lua` | Spy timing/threshold adjustments |
| `sv_plancoordinator.lua` | Include spy in traitor plans |
| `sv_chatter_events.lua` | New spy chatter events + team jam hook |
| `locale/en/sh_chats.lua` | Spy locale strings |
| `data/sh_chatgpt_prompts.lua` | Spy LLM prompt templates |
| `lib/sh_events.lua` | New spy event name constants |
| `sv_morality_suspicion.lua` | Spy-specific evidence handling |
| `components/sv_evidence.lua` | New evidence types for spy intel |
