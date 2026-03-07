# TTT2-Bots-2 Overhaul Suggestions

## Full-Codebase Analysis & Feature Roadmap

> **Generated**: 2026-03-07 | **Codebase Version**: v1.3 (development branch)
> **Scope**: Complete bot experience overhaul — transforming bots from mechanical combatants into believable social deduction participants.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Tier 1 — Social Deduction Core (Critical)](#2-tier-1--social-deduction-core-critical)
3. [Tier 2 — Strategic Intelligence (High Impact)](#3-tier-2--strategic-intelligence-high-impact)
4. [Tier 3 — Combat & Movement Overhaul (Medium Impact)](#4-tier-3--combat--movement-overhaul-medium-impact)
5. [Tier 4 — Systems & Mechanics Integration (Medium Impact)](#5-tier-4--systems--mechanics-integration-medium-impact)
6. [Tier 5 — Traitor Coordination Overhaul (High Impact)](#6-tier-5--traitor-coordination-overhaul-high-impact)
7. [Tier 6 — Personality & Immersion (Polish)](#7-tier-6--personality--immersion-polish)
8. [Tier 7 — Technical Debt & Architecture (Foundation)](#8-tier-7--technical-debt--architecture-foundation)
9. [Tier 8 — LLM & Voice Integration Enhancements](#9-tier-8--llm--voice-integration-enhancements)
10. [Implementation Priority Matrix](#10-implementation-priority-matrix)
11. [Appendix: Current System Scorecard](#11-appendix-current-system-scorecard)

---

## 1. Executive Summary

### The Core Problem

TTT2-Bots-2 has **excellent mechanical foundations** — combat aiming, navmesh pathfinding, 57 role definitions, 50+ personality traits, and an impressive LLM/TTS pipeline. However, TTT is fundamentally a **social deduction game**, and the bots currently lack the cognitive layer that makes TTT what it is.

**Bots can**: Shoot, stalk, defuse C4, heal allies, wander, and chat flavor text.
**Bots cannot**: Accuse, argue, defend themselves, build alibis, reason about evidence, coordinate investigations, lie strategically, or participate in the information warfare that defines the gamemode.

### The Vision

Transform bots from "FPS bots that happen to be in TTT" into **believable social deduction participants** who:
- Build mental models of other players through evidence gathering
- Make accusations and defend themselves when accused
- Exhibit deceptive behavior as traitors (alibis, framing, strategic self-reports)
- Coordinate investigations as innocents/detectives
- React meaningfully to game events with appropriate urgency
- Use the full breadth of TTT2's mechanics (shop, equipment, karma, sprint, traitor buttons)

### Suggested Approach

The overhaul is organized into **8 tiers** from most critical to polish-level improvements. Each tier is self-contained and can be implemented incrementally without breaking existing functionality.

---

## 2. Tier 1 — Social Deduction Core (Critical)

*These features are the heart of the overhaul. Without them, bots will never feel like TTT players.*

### 2.1 Evidence Reasoning Engine

**Problem**: Bots have a `suspicion` integer per player but no understanding of *why* someone is suspicious. The morality system tracks "witnessed kill = +15 suspicion" but cannot chain evidence or communicate reasoning.

**Proposed System — `CEvidence` Component**:

```
New component: CEvidence (attached to bot.components.evidence)

Responsibilities:
├── EvidenceLog: Timestamped array of evidence entries
│   ├── { type: "WITNESSED_KILL", subject: Player, victim: Player, time: T, location: NavArea }
│   ├── { type: "NEAR_BODY", subject: Player, corpse: Entity, duration: seconds }
│   ├── { type: "TRAITOR_WEAPON", subject: Player, weapon: string }
│   ├── { type: "FAILED_TEST", subject: Player }
│   ├── { type: "REFUSED_TEST", subject: Player }
│   ├── { type: "ABSENT_FROM_GROUP", subject: Player, duration: seconds }
│   ├── { type: "DNA_MATCH", subject: Player, victim: Player }
│   ├── { type: "ALIBI_CONFIRMED", subject: Player, voucher: Player }
│   ├── { type: "ALIBI_BROKEN", subject: Player, reason: string }
│   ├── { type: "KOS_CALLED_BY", subject: Player, caller: Player }
│   ├── { type: "BODY_FOUND_NEAR", subject: Player, corpse: Entity }
│   └── { type: "SUSPICIOUS_MOVEMENT", subject: Player, detail: string }
│
├── EvidenceWeight(): Calculates cumulative evidence score per player
│   → Replaces raw suspicion integer with evidence-backed reasoning
│
├── GetStrongestEvidence(player): Returns the most damning evidence entry
│   → Used for accusation chat messages: "I saw X kill Y near the lighthouse"
│
├── CanExplainSuspicion(player): Bool — has articulable evidence
│   → Prevents baseless accusations (personality-gated: "Sus" archetype ignores this)
│
└── ShareEvidence(otherBot): Transfers evidence entries between bots
    → Enables cooperative investigation
```

**Integration Points**:
- Feed into `CMorality` suspicion scores (replacing some hardcoded +/- values)
- Feed into `CChatter` for evidence-based callouts
- Feed into accusation/defense behaviors (see 2.2)
- Personality traits modulate evidence weight: `suspicious` = lower threshold, `gullible` = trusts everything

### 2.2 Accusation & Defense Behaviors

**Problem**: Bots never independently call KOS based on evidence chains. When accused, bots have zero response — they don't defend themselves, offer to test, or flee.

**New Behaviors**:

#### `AccusePlayer` Behavior
```
Priority Group: "Accuse" (between Chatter and FightBack)

Validate:
  - Has strong evidence against a player (EvidenceWeight > threshold)
  - Not already in combat
  - Hasn't accused this player recently (60s cooldown)
  - Personality gate: aggressive/suspicious = lower threshold, passive/gullible = higher

OnStart:
  - Look at the suspect
  - Choose communication based on evidence strength:
    · Strong (witnessed kill): CallKOS + share evidence in chat
    · Medium (multiple circumstantial): DeclareSuspicious + explain why
    · Weak (single clue): Soft accusation ("X is acting weird")

OnRunning:
  - If suspect is nearby and no one else is acting:
    · Request the suspect to test (RequestUseRoleChecker)
    · Follow the suspect to watch them
  - If other players support the accusation:
    · Escalate to KOS
  - If suspect proves innocence (tests clean, alibi confirmed):
    · Retract accusation, lower suspicion

Personality Modulation:
  - Tryhard: Precise evidence citation, requests testing
  - Hothead: Immediate KOS, no discussion
  - Nice: Soft accusations, gives benefit of doubt
  - Dumb: Accuses wrong person sometimes, confused reasoning
  - Sus: Accuses with minimal evidence
  - Teamer: Rallies group consensus before accusing
```

#### `DefendSelf` Behavior
```
Priority Group: "SelfDefense" (high priority, below FightBack)

Validate:
  - Bot has been KOS'd or accused (tracked via KOS list / chatter memory)
  - Bot is not actually guilty (innocent-side) OR is guilty but wants to deflect (traitor)

Innocent Response Tree:
  ├── Offer to test: "I'll use the tester, I'm clean"
  ├── Provide alibi: "I was with {{player}} the whole time"
  ├── Counter-accuse: "{{accuser}} is the real traitor, I saw them near {{body}}"
  ├── Appeal to group: "Does anyone else think I'm sus? I've been helping"
  └── Flee if situation escalates and no one believes them

Traitor Response Tree:
  ├── Feign innocence: "What? I was nowhere near there"
  ├── Offer to test (then avoid/delay): Move toward tester slowly, get "distracted"
  ├── Counter-accuse the accuser: "Actually {{accuser}} has been following people into dark corners"
  ├── Frame someone else: Redirect suspicion with false evidence
  ├── Assassinate the accuser if isolated: Escalate to eliminate the witness
  └── Accept the accusation if cornered: Last-stand fight

Personality Modulation:
  - Tryhard traitor: Sophisticated deflection with fake evidence
  - Dumb traitor: Panic, say something incriminating accidentally
  - Stoic: Calm denial, simple counter-evidence
  - Hothead: Rage at accuser, potentially attack prematurely
```

### 2.3 Proactive KOS & Callout System

**Problem**: The `Match.KOSList` exists but bots only add to it reactively via suspicion thresholds. Real players proactively call out suspicious behavior in real-time.

**Enhancements to `CChatter`**:

- **Witness Callouts**: When `OnWitnessKill` fires, immediately generate a contextual callout:
  - "I just saw {{killer}} shoot {{victim}} near {{location}}!"
  - Include weapon type: "{{killer}} is using a traitor weapon!"
  - Personality-driven urgency: Hothead screams in caps; Stoic states facts calmly

- **Proximity Callouts**: When `personalSpace` timer triggers suspicion:
  - "{{player}} has been following me for a while, stay away"
  - "Why is {{player}} just standing behind me?"

- **Death Callouts (Last Words)**: On `PlayerDeath` hook, if the bot saw their killer:
  - Final message: "It was {{killer}}!" (emulating the TTT2 "last words" mechanic)
  - Personality-gated accuracy: `Dumb` might name the wrong person

- **Life Check System**: Periodic behavior to call out names:
  - "Who's still alive? Sound off"
  - Track who responds vs. who's suspiciously silent

### 2.4 Vouching & Alliance Building

**Problem**: Bots never vouch for other players. In real TTT, confirmed innocents forming groups and vouching for each other is a core survival strategy.

**New System — Trust Network**:

```
Extension to CEvidence / CMorality:

TrustNetwork:
├── confirmedInnocent[player] = { evidence: "tested clean", time: T }
├── travelCompanions[player] = { since: T, continuous: bool }
│   → "I was with X for the last 30 seconds, they're clean"
├── vouchedBy[player] = { voucher: Player, time: T }
│   → Transitive trust: if a confirmed detective vouches for X, trust X
└── trustDecay: Trust weakens over time if players separate

Behaviors:
├── VouchForPlayer: "{{player}} is with me, they're clean"
├── GroupUp: Seek confirmed innocents to travel with
├── RequestVouch: "Can anyone confirm where I was?"
└── BreakTrust: If a vouched player does something suspicious, revoke trust
```

---

## 3. Tier 2 — Strategic Intelligence (High Impact)

*These features give bots temporal awareness and the ability to reason about the state of the round.*

### 3.1 Round Phase Awareness

**Problem**: Bots behave identically at round start, mid-round, and endgame. Real players dramatically shift strategy based on round phase.

**Proposed System — `CRoundAwareness` (extension to `Match`)**:

```
Round Phases:
├── EARLY (0-25% of round time)
│   Innocent: Explore, pick up weapons, group up, use testers
│   Traitor: Blend in, build alibi, identify isolated targets
│   Detective: Set up health station, distribute equipment, start investigations
│
├── MID (25-60% of round time)
│   Innocent: Investigate deaths, call out suspects, buddy system
│   Traitor: Execute kills on isolated targets, frame innocents
│   Detective: Follow DNA trails, test suspects, coordinate group
│
├── LATE (60-85% of round time)
│   Innocent: Stick together tightly, force testing, KOS anyone alone
│   Traitor: Execute bold plays, coordinate team attacks, use C4/jihad
│   Detective: Final tests, protect confirmed innocents, last stand defense
│
└── OVERTIME / HASTE (85%+ or haste active)
    Innocent: Turtle, KOS anyone approaching, test everyone
    Traitor: All-out assault, no more stealth
    Detective: Rally point, last-ditch investigations

Integration:
- Behavior tree selection modulated by phase (e.g., "Stalk" only available in EARLY/MID)
- Aggression multipliers scale with phase (traitors become bolder over time)
- Group-up urgency increases with player deaths
- Chatter reflects phase awareness: "We're running out of time, everyone group up!"
```

### 3.2 Player Count & Alive Tracking Reasoning

**Problem**: Bots don't reason about the game state. "3 players left, 2 confirmed innocents → the third MUST be traitor" is obvious to humans but invisible to bots.

**Enhancements**:

- **Deduction by elimination**: If N innocents confirmed and M players alive, remaining unknowns are increasingly suspicious
- **Traitor count awareness**: TTT announces traitor count; bots should track confirmed traitor deaths against expected count
- **"Too quiet" detection**: If no one has died in a long time, increase alertness
- **Majority awareness**: Traitors should know when they have numbers advantage
- **Last-alive escalation**: Already exists (`TickIfLastAlive`) but should trigger earlier with appropriate chatter

### 3.3 Suspicion Decay & Revision

**Problem**: `CMorality.suspicion` values never decay mid-round. A player who was briefly suspicious 2 minutes ago remains permanently flagged.

**Fix**:
- Implement per-tick suspicion decay: `suspicion[ply] = suspicion[ply] * 0.998` (slow decay)
- Evidence-based suspicion is "pinned" and decays slower than circumstantial suspicion
- Trait modulation: `suspicious` personality decays slower, `gullible` decays faster
- Positive actions (testing clean, being vouched for) actively reduce suspicion
- Clearing a player via role tester should set suspicion floor (can't go below -5 for tested players)

### 3.4 Location-Based Reasoning

**Problem**: Memory tracks player positions but never correlates them with events.

**New Capabilities for `CMemory` / `CEvidence`**:

- **"Near the body" reasoning**: When a body is found, check which players were last known near that location around the estimated time of death → generate `NEAR_BODY` evidence
- **"Came from the crime scene"**: If a player appears from the direction of recent gunshots → generate `SUSPICIOUS_MOVEMENT` evidence
- **Map callouts**: Name nav areas or landmarks for chat references:
  - "I found a body near the lighthouse"
  - "X was heading toward the traitor room"
- **Patrol coverage tracking**: Remember which areas have been checked; prefer unexplored areas when wandering
- **Danger zone avoidance**: Areas where recent kills occurred should be avoided by cautious innocents, targeted by investigators

---

## 4. Tier 3 — Combat & Movement Overhaul (Medium Impact)

### 4.1 Sprint System Integration

**Problem**: TTT2 has a full sprint/stamina system (`sh_sprint.lua`). Bots never press `IN_SPEED`, making them ~33% slower than sprinting humans.

**Implementation**:
- Add `IN_SPEED` to `CLocomotor:StartCommand` when:
  - Traveling long distances (path length > 500 units)
  - Fleeing from combat
  - Chasing a target
  - Responding to nearby gunshots/screams
- Stamina management: Don't sprint when stamina < 20% (leaves reserve for emergencies)
- Personality modulation: `cautious` sprints less, `aggressive`/`risktaker` sprint more freely
- Never sprint while "sneaking" (traitor stalking behavior)

### 4.2 Cover-Based Combat

**Problem**: Bots stand in the open during firefights. No peeking, no cover-seeking, no retreat.

**New Behavior — `SeekCover`**:

```
Trigger: Taking damage while in combat AND health < 60% OR outgunned

Logic:
1. Cast rays in 8 directions to find nearby cover (walls, props, corners)
2. Score cover positions by:
   - Blocks LOS to attacker: +10
   - Has escape route: +5
   - Near allies: +3
   - Not a dead end: +2
3. Path to best cover position
4. Peek from cover to return fire (alternate between exposed/hidden)
5. Retreat further if health drops below 25%

Integration with AttackTarget:
- When engaging, prefer positions with partial cover
- Strafe between cover points rather than standing still
- Backpedal toward cover when reloading

Personality Modulation:
- Tryhard/cautious: Aggressive cover usage
- Hothead: Ignores cover, charges in
- Dumb: Picks bad cover positions
```

### 4.3 Retreat & Flee Behavior

**Problem**: Bots fight to the death. No flight response even when severely wounded.

**New Behavior — `Retreat`**:

```
Priority: Above Patrol, below FightBack (or integrated into FightBack)

Validate:
  - Health < 30% AND in combat
  - OR outnumbered (2+ attackers)
  - OR out of ammo
  - Personality gate: Hothead/rager never retreats, cautious retreats earlier

OnRunning:
  - Path away from attacker (opposite direction vector)
  - Prefer paths toward allies or health stations
  - Call for help via chatter: "Help! {{attacker}} is trying to kill me near {{location}}!"
  - Drop smoke grenade if available (see equipment usage)
  - Sprint while fleeing

Success: Reached safe distance (>1000 units) or found allies
Failure: Cornered or killed
```

### 4.4 Weapon Intelligence Overhaul

**Problem**: `CInventory` auto-selects the first weapon with ammo. No range-based switching, no preference for stealth weapons, no looting dead players.

**Enhancements**:

- **Range-based weapon selection**: Within 200u → shotgun/melee; 200-800u → SMG/rifle; 800u+ → sniper/scoped
- **Stealth weapon preference for traitors**: Knife and silenced pistol when stalking; loud weapons only when cover is blown
- **Weapon looting**: New behavior to approach recently-killed players and pick up their weapons if superior to current loadout
- **Ammo awareness**: Seek ammo crates when reserve is low; switch weapons preemptively when clip is about to empty
- **Grenade queuing**: Before engaging, throw a tactical grenade (see 5.3)

---

## 5. Tier 4 — Systems & Mechanics Integration (Medium Impact)

### 5.1 Shop & Equipment Buying Overhaul

**Problem**: The `sv_buyables.lua` system exists but is rudimentary — bots buy 2 items at round start based on static priority. No situational or map-aware purchasing.

**Enhancements**:

- **Situational buying**: Consider round state, player count, and map type:
  - Large maps: Buy radar (traitor) or body armor (detective)
  - Small maps: Buy close-range weapons, incendiary grenades
  - Many players alive: Buy C4 (traitor); few alive: buy knife (traitor)
  - Detective with bodies to investigate: Buy DNA scanner first

- **Deferred buying**: Don't buy everything at round start. Save credits for mid-round needs:
  - Traitor saves 1 credit for emergency disguiser/dead ringer
  - Detective saves credit for defib if an ally dies

- **Credit coordination**: Traitor bots communicate about purchases:
  - "I'll buy the C4, you get the jihad bomb"
  - Avoid duplicate purchases of unique items

- **Equipment usage behaviors**: Each purchased item needs a corresponding behavior:
  - Radar: Check periodically, share intel with team
  - Disguiser: Activate before engaging, deactivate when safe
  - Body Armor: Auto-equip (passive, no behavior needed)
  - Health Station: Place in defensible location, announce to allies
  - Decoy: Place to create false radar blip
  - Radio: Place near common areas, trigger at strategic moments

### 5.2 Karma Awareness

**Problem**: Bots have zero karma awareness. They RDM freely and risk auto-kick/ban from karma penalties.

**Implementation**:

- **Track own karma**: Read `GetLiveKarma()` and factor into attack decisions
- **Hesitation at low karma**: Below a threshold (e.g., 700), bots require stronger evidence before attacking
- **Karma recovery mode**: If karma is dangerously low, avoid all combat except self-defense
- **Pre-attack karma check**: Estimate karma penalty of attacking the target; abort if it would trigger auto-kick
- **Personality override**: `rdmer` and `Hothead` have higher tolerance for karma risk; `cautious`/`Nice` avoid karma-risky plays

### 5.3 Grenade & Utility Usage

**Problem**: Bots never use smoke grenades, incendiaries, discombobs, or other utility items.

**New Behaviors**:

- **Smoke Grenade**: Throw when retreating, when a body is found (to cover the area), or as traitor to obscure a kill
- **Incendiary Grenade**: Throw into groups of enemies, or to deny area access (block a doorway)
- **Discombobulator**: Throw near ledges for fall-damage kills (requires map geometry awareness)
- **Flash/Stun**: Throw before engaging a group to disorient
- **Traitor-specific**: Radio placement for distraction, decoy placement for misdirection

### 5.4 DNA Scanner Usage (Detective)

**Problem**: Detectives never use the DNA scanner — the primary investigation tool in TTT.

**New Behavior — `UseDNAScanner`**:

```
Priority: High for Detective tree (between Support and Investigate)

Validate:
  - Bot is detective
  - Has DNA scanner (bought or spawned with)
  - Unscanned corpse exists

OnRunning:
  1. Navigate to corpse
  2. Equip DNA scanner
  3. Scan corpse
  4. If DNA found:
     a. Add DNA_MATCH evidence against the identified player
     b. Announce in chat: "DNA matches {{suspect}}! They killed {{victim}}!"
     c. Escalate to KOS if multiple DNA matches
  5. Follow the DNA trail (scanner points toward the killer)
  6. If no DNA found: Note the corpse as scanned, move to next body
```

### 5.5 Traitor Button & Map Trap Awareness

**Problem**: Traitor bots never activate traitor buttons (`ttt_traitor_button`), ignoring powerful map-specific tools.

**New Behavior — `UseTraitorButton`**:

```
Priority: Medium in Traitor tree (between PlantBomb and FollowPlan)

Validate:
  - Bot is traitor team
  - Traitor button entities exist on the map
  - Button hasn't been used recently (cooldown)

OnRunning:
  1. Scan for ttt_traitor_button entities
  2. Score each button by:
     - Proximity to enemies
     - Number of potential victims in the trap zone
     - Witness risk (can the bot reach the button unseen?)
  3. Navigate to the best button
  4. Wait for optimal moment (enemies in kill zone, no witnesses at button)
  5. Activate the button
  6. React accordingly: move away from trap zone, act surprised

Limitation: Can't know what each button does without map-specific data.
Workaround: Activate buttons opportunistically; learn from outcomes over multiple rounds.
```

### 5.6 Door Locking & Manipulation

**Problem**: Bots can open doors but never lock them (to trap players) or use them tactically.

**Enhancements**:
- **Lock doors behind victims** (traitor): After luring someone into a room, lock the door
- **Lock traitor room doors**: Prevent innocents from accessing traitor-only areas
- **Door camping awareness**: If a door keeps opening/closing, someone may be lurking
- **Break down locked doors**: When pursuing or investigating, break through locked doors

---

## 6. Tier 5 — Traitor Coordination Overhaul (High Impact)

### 6.1 Expanded Plan Presets

**Problem**: Only 3 plan presets exist, all variations of "maybe plant C4, then attack." No sophisticated multi-phase strategies.

**New Presets**:

```
"Divide and Conquer" (5-12 players, 2+ traitors):
  Job 1: Bot A creates a distraction (radio/decoy/false KOS) in area X
  Job 2: Bot B stalks and kills an isolated player in area Y
  Job 3: Both regroup and alibi each other

"False Flag" (6+ players, 2+ traitors):
  Job 1: Bot A kills someone with a common weapon
  Job 2: Bot B "discovers" the body and frames an innocent
  Job 3: Both push for KOS on the framed player
  Job 4: While group is focused on the lynching, Bot A kills again

"Systematic Assassination" (8+ players, 3+ traitors):
  Job 1: All traitors spread to different areas (ROAM)
  Job 2: Each traitor identifies the most isolated nearby player
  Job 3: Coordinated simultaneous kills (timed to the same 5-second window)
  Job 4: Regroup for remaining targets

"C4 Chaos" (10+ players):
  Job 1: Plant C4 in a popular area
  Job 2: Wait until C4 detonation draws attention
  Job 3: Attack survivors from behind during the confusion

"Infiltration" (any count, 1 traitor):
  Job 1: Pass the tester early to build trust
  Job 2: Get "confirmed innocent" status
  Job 3: Use trust position to isolate and kill targets
  Job 4: Frame others using established credibility

"Late Game Rush" (when traitors are outnumbered):
  Trigger: Traitor count ≤ innocent count / 3
  Job 1: All traitors converge on a single target
  Job 2: Burst-kill as many as possible before being stopped
  Job 3: Use remaining utility (C4, jihad, grenades)
```

### 6.2 Adaptive Plan System

**Problem**: Plans are selected once at round start and never revised.

**Enhancements**:

- **Plan abandonment**: If a plan is failing (assigned bot is dead, target escaped), abort and select a new plan
- **Opportunistic plan switching**: If a better opportunity arises (e.g., all innocents grouped near a C4 spot), pivot
- **Phase-based plan transitions**: Plans have early/mid/late phases that trigger based on round timer and player count
- **Human traitor integration**: If a human traitor takes an action (kills someone), bots adapt their plans accordingly
- **Success/failure tracking**: Track which plans succeeded in previous rounds; bias toward successful strategies

### 6.3 Innocent-Side Coordination

**Problem**: The plan system is entirely traitor-focused. Innocents have no coordinated strategy.

**New System — `InnocentCoordinator`**:

```
Investigation Plans:
├── "Buddy System": Pair up and watch each other
├── "Patrol Routes": Divide the map into zones, assign coverage
├── "Tester Queue": Organize orderly role testing
├── "Body Recovery": When a body is found, form a security perimeter
└── "Last Stand": When few innocents remain, turtle in a defensible position

Detective Leadership:
├── Detective issues instructions: "Everyone group up at tester"
├── Assigns testing order
├── Dispatches investigators to body locations
├── Calls for KOS with authority (other bots obey detective KOS more readily)
└── Coordinates evidence sharing between bots
```

---

## 7. Tier 6 — Personality & Immersion (Polish)

### 7.1 Deception Personality Layer (Traitor-Specific)

**Problem**: Traitor bots have no active deception behavior. They don't build alibis, don't fake-investigate, don't lie in chat.

**New Traitor-Mode Behaviors**:

- **Alibi Building**: Traitor actively stays near innocents during EARLY phase, making sure to be "seen" near populated areas
- **Fake Investigation**: Visit corpses and announce findings even when the traitor killed the victim — "I found {{victim}}'s body, no DNA. Everyone be careful!"
- **Strategic Self-Report**: Report your own kills with manufactured evidence pointing elsewhere
- **False KOS**: Call KOS on an innocent to create chaos (risk: backfires if the innocent tests clean)
- **Plausible Ignorance**: When caught near a fresh kill, claim "I just got here! I heard gunshots and came to investigate"
- **Weapon Management**: Drop traitor weapons before entering populated areas; switch to innocent weapons when being watched

### 7.2 Dynamic Personality Evolution

**Problem**: Personality is static per-bot. Real players adapt their playstyle based on what's happening.

**Enhancements**:

- **Pressure-driven personality shift**: High pressure makes `cautious` bots more `aggressive` (fight-or-flight)
- **Experience adaptation**: Bots that die to the same strategy adapt:
  - Killed by a stalker? Become more group-oriented next round
  - False-KOS'd? Become more `suspicious` of callouts
- **Social feedback**: If a bot's accusations are consistently wrong, they become less confident in future accusations
- **Momentum**: Winning fights increases confidence (aggression up); losing fights makes bots play safer
- **Cross-round memory** (optional, ConVar-gated): Remember which players were traitors in recent rounds (simulates "metagaming" that real players do)

### 7.3 Contextual Social Animations

**Problem**: The `Interact` behavior plays random animations (nods, shakes) with no semantic meaning.

**Enhancements**:

- **Nod when agreeing** with an accusation or KOS call
- **Shake head when disagreeing** or defending an accused player
- **Look at the accused** when someone is called out
- **Turn away / avoid eye contact** as traitor when lying
- **Crouch-peek** when cautiously entering a room where a kill occurred
- **Flashlight toggle** in dark areas (purely cosmetic but immersive)
- **Weapon holster** when approaching friendly players (switch to crowbar/fists to signal non-aggression)

### 7.4 Expanded Dialog Templates

**Problem**: Only 7 dialog templates exist, all trivial greetings and boredom conversations.

**New Templates**:

```
"The Investigation" (3-4 bots):
  Bot A: "Did anyone see {{victim}} before they died?"
  Bot B: "I think I saw them heading toward {{location}}"
  Bot C: "{{suspect}} was over there too..."
  Bot A: "That's suspicious. {{suspect}}, where were you?"

"The Accusation" (2-3 bots):
  Bot A: "I'm calling it — {{suspect}} is the traitor"
  Bot B: "What's your evidence?"
  Bot A: "I saw them near {{victim}}'s body with a traitor weapon"
  Bot B: "That's good enough for me" / "That's not enough, I was near there too"

"The Defense" (2-3 bots):
  Accused: "I'm not the traitor! I was with {{alibi}} the whole time"
  Accuser: "Then how do you explain {{evidence}}?"
  Accused: "I don't know, but it wasn't me. Test me if you want"

"The Standoff" (2 bots, late game):
  Bot A: "It's just us two. One of us is the traitor."
  Bot B: "Well it's not me. Drop your weapon."
  Bot A: "You first."

"Post-Round Banter" (2-4 bots):
  Winner: "GG, I knew it was {{traitor}} from the start"
  Loser: "How did you know??"
  Winner: "You were acting way too suspicious near the bodies"
```

### 7.5 Emotional Reactions to Events

**Problem**: Bots don't react emotionally to dramatic events.

**New Chatter Events**:

- **Witnessing a kill**: Panic response — "OH GOD! {{killer}} just murdered {{victim}}!" (run away while shouting)
- **Being shot at**: "Hey! Who's shooting?! Stop!" (before the combat system kicks in)
- **Finding a friend's body**: "No... {{victim}} is dead... Who did this?"
- **Round starting**: "Alright, let's figure this out" / "Here we go again"
- **Overtime/Haste**: "We're running out of time!" / "Hurry up, find the traitor!"
- **Being the last innocent**: "I'm the last one... it has to be {{suspect}}"
- **Winning as traitor**: "You never suspected a thing" / "Too easy"

---

## 8. Tier 7 — Technical Debt & Architecture (Foundation)

*These improvements strengthen the codebase for the features above.*

### 8.1 Behavior State Isolation

**Problem**: Several behavior modules store mutable state on the module table (`self.someVar`) rather than per-bot state via `GetState(bot)`. This causes state bleed between bots.

**Fix**: Audit all 50 behaviors and migrate any module-level state to `GetState(bot)` pattern. The base behavior already provides this — it just needs consistent usage.

**Known offenders** (from REFACTORING_PASSES.md): `attacktarget`, `followplan`, `jihad`, `stalk`

### 8.2 Deduplicate Role Weapon Behaviors

**Problem**: 10 "create-X" / "swap-X" / "copy-X" behaviors share ~90% identical code.

**Fix**: Create a generic `UseSpecialWeapon` behavior with configuration:

```lua
-- Instead of 10 separate files:
TTTBots.Behaviors.RegisterSpecialWeapon({
    name = "CreateSidekick",
    weaponGetter = "GetSidekickGun",
    targetFilter = function(bot, target) return not IsAllied(bot, target) end,
    requiresWitnessFree = true,
    chance = 0.05,
    chatterEvent = "CreatingSidekick",
})
```

### 8.3 Component Think Rate Optimization

**Problem**: All 7 components run `Think()` at 5Hz (200ms). Some (like `CPersonality`) do very little work per tick and could run at 1Hz.

**Fix**: Implement per-component tick rates:
- `CLocomotor`: 5Hz (movement needs high responsiveness)
- `CMorality`: 5Hz (combat decisions are time-critical)
- `CMemory`: 3Hz (position tracking can be slightly delayed)
- `CInventory`: 2Hz (weapon management is periodic)
- `CChatter`: 2Hz (chat events are low-frequency)
- `CPersonality`: 1Hz (emotional state changes slowly)
- `CObstacleTracker`: 2Hz (obstacle detection is periodic)

### 8.4 Pathfinding Improvements

**Problem**: Hard 600-node ceiling, single path per tick, no replanning.

**Enhancements**:
- **Hierarchical pathfinding**: Pre-compute region-level graph (already have regions via flood-fill); use for quick long-distance estimates, then detail-path only the next region transition
- **Path replanning trigger**: If target moves >200u from path endpoint, request a new path
- **Priority queue**: Combat paths should be processed before wandering paths
- **Path smoothing improvements**: Current Bézier smoothing works but sometimes creates paths that clip through walls — add collision validation

### 8.5 Unified Event System

**Problem**: Events are dispatched through multiple disconnected systems — hooks, component callbacks, chatter events, morality events, and direct function calls. There's no central event bus.

**Proposed**: A lightweight pub/sub event system:

```lua
TTTBots.Events.Subscribe("BODY_FOUND", function(bot, corpse, victim)
    -- Any system can react: evidence, chatter, morality, behavior tree
end)

TTTBots.Events.Publish("BODY_FOUND", { finder = bot, corpse = ent, victim = ply })
```

This would decouple systems and make it easier to add new reactions to game events without modifying existing code.

---

## 9. Tier 8 — LLM & Voice Integration Enhancements

### 9.1 Contextual LLM Prompts

**Problem**: LLM prompts include basic personality and role info but lack game-state context.

**Enhancement**: Include in every LLM prompt:
- Current round phase (early/mid/late)
- Number of players alive/dead
- Recent events (last 3 kills, last 2 KOS calls)
- Bot's evidence log summary
- Who the bot suspects and why
- Bot's current emotional state (calm/panicked/angry)

This would make LLM-generated dialogue dramatically more contextual and game-relevant.

### 9.2 Multi-Turn Conversation Memory

**Problem**: Each LLM request is stateless. Bots can't maintain a conversation thread.

**Enhancement**: Implement a conversation buffer per bot:
- Store last 5-10 exchanges (incoming message + bot's response)
- Include in LLM prompt as conversation history
- Clear on topic change or after 60 seconds of silence
- Enable LLM to reference previous statements: "Like I said before..."

### 9.3 LLM-Driven Accusation Generation

**Problem**: Accusations use pre-written locale strings. LLM could generate much more contextual and varied accusations.

**Enhancement**: When `AccusePlayer` behavior triggers, if LLM is enabled:
1. Compile evidence log into a prompt
2. Ask LLM to generate an in-character accusation citing specific evidence
3. Fall back to locale strings if LLM fails or is disabled
4. Personality-modulated prompt: "You are a paranoid player" vs "You are methodical and logical"

### 9.4 STT-Driven Evidence Processing

**Problem**: The STT system transcribes player voice but only matches basic commands ("follow me", "attack X").

**Enhancement**: If LLM is available, process STT transcriptions for richer understanding:
- Extract accusations/defenses from natural speech
- Detect lies or inconsistencies in player statements
- Respond to complex requests: "Hey bot, can you go check the lighthouse? I think I heard something there."

---

## 10. Implementation Priority Matrix

| Priority | Feature | Effort | Impact | Dependencies |
|----------|---------|--------|--------|-------------|
| **P0** | Sprint integration (4.1) | Low | High | None |
| **P0** | Karma awareness (5.2) | Low | High | None |
| **P0** | Behavior state isolation (8.1) | Low | Foundation | None |
| **P1** | Evidence Reasoning Engine (2.1) | High | Critical | None |
| **P1** | Round Phase Awareness (3.1) | Medium | High | None |
| **P1** | Suspicion decay (3.3) | Low | High | None |
| **P1** | Deduplicate role behaviors (8.2) | Medium | Foundation | None |
| **P2** | Accusation & Defense Behaviors (2.2) | High | Critical | 2.1 |
| **P2** | Proactive KOS & Callouts (2.3) | Medium | Critical | 2.1 |
| **P2** | Shop & Equipment Buying (5.1) | Medium | High | None |
| **P2** | DNA Scanner Usage (5.4) | Medium | High | None |
| **P2** | Cover-Based Combat (4.2) | High | Medium | None |
| **P3** | Vouching & Alliance Building (2.4) | Medium | High | 2.1 |
| **P3** | Player Count Reasoning (3.2) | Medium | High | 3.1 |
| **P3** | Location-Based Reasoning (3.4) | Medium | High | 2.1 |
| **P3** | Expanded Plan Presets (6.1) | Medium | High | None |
| **P3** | Innocent-Side Coordination (6.3) | High | High | 3.1 |
| **P3** | Deception Personality Layer (7.1) | High | High | 2.1, 3.1 |
| **P4** | Retreat & Flee (4.3) | Medium | Medium | None |
| **P4** | Weapon Intelligence (4.4) | Medium | Medium | None |
| **P4** | Grenade & Utility Usage (5.3) | Medium | Medium | None |
| **P4** | Traitor Buttons (5.5) | Low | Medium | None |
| **P4** | Adaptive Plan System (6.2) | High | High | 6.1 |
| **P5** | Dynamic Personality Evolution (7.2) | Medium | Low | None |
| **P5** | Contextual Animations (7.3) | Low | Low | None |
| **P5** | Expanded Dialog Templates (7.4) | Medium | Medium | None |
| **P5** | Emotional Reactions (7.5) | Low | Medium | None |
| **P5** | Component Think Rate Optimization (8.3) | Low | Foundation | None |
| **P5** | Pathfinding Improvements (8.4) | High | Foundation | None |
| **P5** | Unified Event System (8.5) | High | Foundation | None |
| **P6** | Contextual LLM Prompts (9.1) | Medium | Medium | 2.1, 3.1 |
| **P6** | Multi-Turn Conversation (9.2) | Medium | Medium | None |
| **P6** | LLM Accusation Generation (9.3) | Medium | Medium | 2.1, 9.1 |
| **P6** | STT Evidence Processing (9.4) | High | Low | 9.1 |
| **P6** | Door Manipulation (5.6) | Low | Low | None |

### Suggested Implementation Order

```
Phase 1 — Foundation & Quick Wins (2-3 weeks):
  ├── P0: Sprint, Karma, State isolation
  ├── P1: Suspicion decay, Round phase awareness
  └── P1: Deduplicate role behaviors

Phase 2 — Social Deduction Core (4-6 weeks):
  ├── P1: Evidence Reasoning Engine
  ├── P2: Accusation & Defense behaviors
  ├── P2: Proactive KOS & Callouts
  └── P2: Shop & Equipment buying

Phase 3 — Strategic Depth (4-6 weeks):
  ├── P2: DNA Scanner, Cover-based combat
  ├── P3: Vouching, Player count reasoning, Location reasoning
  └── P3: Expanded traitor plans

Phase 4 — Coordination & Deception (4-6 weeks):
  ├── P3: Innocent coordination, Deception layer
  ├── P4: Retreat, Weapon intelligence, Grenades, Traitor buttons
  └── P4: Adaptive plan system

Phase 5 — Polish & Immersion (2-4 weeks):
  ├── P5: Personality evolution, Animations, Dialog templates, Emotions
  └── P5: Technical improvements (tick rates, pathfinding, event system)

Phase 6 — AI Integration (2-3 weeks):
  ├── P6: Contextual LLM prompts
  ├── P6: Multi-turn conversations
  └── P6: LLM-driven accusations
```

---

## 11. Appendix: Current System Scorecard

| System | Current State | After Overhaul |
|--------|--------------|----------------|
| **Combat** | ⭐⭐⭐⭐ Excellent aim, strafing | ⭐⭐⭐⭐⭐ + Cover, retreat, grenades |
| **Movement** | ⭐⭐⭐⭐ Good pathing, personality-driven | ⭐⭐⭐⭐⭐ + Sprint, strategic positioning |
| **Social Deduction** | ⭐ Suspicion integers only | ⭐⭐⭐⭐ Evidence chains, accusations, deception |
| **Communication** | ⭐⭐⭐ Flavor chat, LLM support | ⭐⭐⭐⭐⭐ Evidence-based, contextual, reactive |
| **Investigation** | ⭐⭐ Basic corpse search | ⭐⭐⭐⭐ DNA, alibis, evidence correlation |
| **Coordination** | ⭐⭐ 3 basic traitor plans | ⭐⭐⭐⭐ Rich plans, innocent coordination |
| **Equipment** | ⭐⭐ Basic buying, no usage | ⭐⭐⭐⭐ Full shop, tactical equipment use |
| **Personality** | ⭐⭐⭐⭐ Rich traits, good variety | ⭐⭐⭐⭐⭐ + Dynamic evolution, deception modes |
| **Role Support** | ⭐⭐⭐⭐ 57 roles, auto-registration | ⭐⭐⭐⭐ + Role-specific strategies |
| **Technical** | ⭐⭐⭐ Modular but some debt | ⭐⭐⭐⭐ Cleaner architecture, better perf |

---

## Final Notes

The TTT2-Bots-2 mod is an impressive piece of work with a solid technical foundation. The suggestions in this document are focused on the single biggest gap: **transforming the bots from FPS combatants into social deduction participants**. The mod already has all the infrastructure (behavior trees, component model, personality system, LLM integration, rich chat library) to support these changes — it's primarily a matter of building the cognitive layer that connects these systems together.

The Evidence Reasoning Engine (2.1) is the single highest-impact addition. Once bots can reason about *why* they suspect someone, every other social feature (accusations, defenses, deception, coordination) becomes possible.

The second highest-impact change is the simplest: **sprint integration** (4.1). It's a few lines of code in the locomotor but eliminates the most visible mechanical disadvantage bots have against human players.

> *"TTT is a game where the guns are a last resort. The real weapon is information."*
> — This overhaul aims to give bots that weapon.
