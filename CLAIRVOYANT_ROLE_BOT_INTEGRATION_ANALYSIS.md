# 🔮 Clairvoyant Role — Bot Integration Analysis

> **Date:** March 10, 2026
> **Scope:** Full analysis of the Clairvoyant role addon and best implementation path for TTT2-Bots-2 integration
> **Role Addon:** `[TTT2] Clairvoyant [ROLE]` (Workshop ID: 1357255271)
> **Existing Bot File:** `behaviors/clairvoyantwicked.lua` + `roles/clairvoyant.lua`

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Role Mechanics Deep Dive](#2-role-mechanics-deep-dive)
3. [Current Bot Implementation Audit](#3-current-bot-implementation-audit)
4. [Gap Analysis](#4-gap-analysis)
5. [Architecture & Design Decisions](#5-architecture--design-decisions)
6. [Implementation Plan](#6-implementation-plan)
7. [File-by-File Specifications](#7-file-by-file-specifications)
8. [Chatter System Enhancements](#8-chatter-system-enhancements)
9. [Integration with Existing Systems](#9-integration-with-existing-systems)
10. [Testing Strategy](#10-testing-strategy)
11. [Risk Assessment](#11-risk-assessment)

---

## 1. Executive Summary

### The Role
The Clairvoyant is an **innocent-aligned information broker** who can see which players have "special" (non-vanilla) roles via purple scoreboard highlighting. It cannot identify *what* the special role is — only *that* one exists. The role also has a unique Jester+Sidekick interaction: the Clairvoyant can kill a Jester to convert them into a loyal Sidekick, bypassing the normal Jester death penalty.

### Current State
The existing bot implementation (`ClairvoyantWicked` behavior) is a **minimal stub** — one of the simplest role integrations in the mod. It picks a random special-role player and announces their existence via chat on a 15–60 second cooldown. It does not:
- Feed information into the suspicion/evidence systems
- Respect the `ttt2_cv_visible` server configuration
- Exhibit strategic self-preservation (the role warns against being too vocal)
- Interact with the Jester/Sidekick mechanic
- Use personality-driven decision making
- Leverage the multi-tick behavior state system

### Recommendation
Replace the current `ClairvoyantWicked` behavior with a purpose-built **Clairvoyant-only** behavior system consisting of:
1. **`ClairvoyantIntel`** — A new multi-phase behavior that processes intelligence at round start, feeds the suspicion/evidence systems, and strategically reveals information
2. **`ClairvoyantJesterHunt`** — A new behavior for the Jester→Sidekick conversion opportunity
3. **Enhanced chatter** — 20+ new lines across all archetypes with strategic variation
4. **Personality integration** — Archetype-driven modifiers for reveal eagerness, caution, and Jester hunt aggression
5. **Evidence system hooks** — A new `CLAIRVOYANT_INTEL` evidence type for persistent knowledge tracking

The Wicked role should retain a **separate copy** or a refactored shared utility to avoid coupling two fundamentally different team-aligned roles.

---

## 2. Role Mechanics Deep Dive

### 2.1 Core Ability: Special Role Detection

**Server-side logic** (runs once at `TTTBeginRound`):

```
1. Gather all alive, active players
2. Filter to those whose subrole is NOT:
   - ROLE_INNOCENT
   - ROLE_TRAITOR
   - Base ROLE_DETECTIVE
   - ROLE_CLAIRVOYANT (self)
3. Apply ttt2_cv_visible percentage:
   - At 100%: all special-role players are visible
   - At <100%: randomly select a proportional subset
4. Cache the result as entity indices in `cachedTable`
5. Send entity indices to Clairvoyant clients via `TTT2CVSpecialRole` net message
```

**Client-side rendering:**
- Players with `cv_specialRole = true` appear with a **purple highlight** (`Color(204, 153, 255)`) on the scoreboard
- Highlight disappears if the player's role becomes publicly known (`ply:IsSpecial()`)
- All flags are cleared at round end

**Critical design characteristics:**
| Property | Implication for Bots |
|----------|---------------------|
| Information is **passive** (scoreboard-only) | Bot must simulate "checking" this information rather than always knowing |
| Computed **once at round start** | Bot should process intel once, not re-scan continuously |
| Subject to **percentage gating** (`ttt2_cv_visible`) | Bot must respect this ConVar — not all special roles may be visible |
| Reveals **existence** not **identity** | Bot knows "Player X has a special role" but not which one |
| **Does not update** mid-round | Role changes (Amnesiac conversion, team swaps) are invisible |
| `unknownTeam = true` | Other bots cannot verify the Clairvoyant's team affiliation |

### 2.2 Jester + Sidekick Interaction

When both the Jester and Sidekick addons are installed:
- The Clairvoyant **can** kill the Jester without triggering the normal death penalty
- The killed Jester is converted into a **Sidekick** — a loyal ally to the Clairvoyant
- This is a **high-risk, high-reward** play: the Clairvoyant must correctly identify the Jester among special-role players

**Conditions:**
- `JESTER` global exists (Jester addon installed)
- `SIDEKICK` global exists (Sidekick addon installed)
- Attacker is `ROLE_CLAIRVOYANT`
- Victim is `ROLE_JESTER`

### 2.3 Scoring & Team

| Property | Value | Strategic Impact |
|----------|-------|------------------|
| Team | `TEAM_INNOCENT` | Wins when traitors are eliminated |
| Base Role | `ROLE_INNOCENT` | Gets innocent equipment shop |
| `unknownTeam` | `true` | Cannot be verified by Detectives — protects from targeting but also prevents trust-building |
| `killsMultiplier` | `2×` | Rewarded for eliminating enemies |
| `teamKillsMultiplier` | `-8×` | **Severely punished** for killing innocents — reinforces information-over-violence playstyle |

### 2.4 ConVars

| ConVar | Default | Range | Effect |
|--------|---------|-------|--------|
| `ttt2_cv_visible` | `100` | `1–100` | Percentage of special-role players visible to the Clairvoyant |
| `ttt_cv_pct` | `0.13` | — | Spawn chance per player slot |
| `ttt_cv_maximum` | `1` | — | Max Clairvoyants per round |
| `ttt_cv_minPlayers` | `8` | — | Minimum players required |

---

## 3. Current Bot Implementation Audit

### 3.1 Role Registration (`roles/clairvoyant.lua`)

```lua
-- Current implementation
local clairvoyant = TTTBots.RoleData.New("clairvoyant")
clairvoyant:SetDefusesC4(true)
clairvoyant:SetTeam(TEAM_INNOCENT)
clairvoyant:SetCanHide(true)
clairvoyant:SetCanSnipe(true)
clairvoyant:SetBTree(bTree)
clairvoyant:SetUsesSuspicion(true)
clairvoyant:SetAlliedRoles({})
clairvoyant:SetAlliedTeams({})
clairvoyant:SetRoleDescription(roleDescription)
```

**Assessment:** ✅ Mostly correct. The role is properly registered as innocent-team with suspicion enabled. However:
- Missing `SetCanCoordinateInnocent(true)` — Clairvoyants should coordinate with innocents
- Missing `SetIsFollower(true)` — as an info role, following others makes strategic sense
- `roleDescription` could be more detailed for LLM context

### 3.2 Behavior Tree

```
Current tree:
1. _prior.Chatter
2. _bh.ClairvoyantWicked    ← Role-specific (position 2)
3. _prior.Requests
4. _prior.FightBack
5. _prior.Support
6. _bh.Defuse
7. _prior.Restore
8. _bh.Interact
9. _prior.Investigate
10. _prior.Minge
11. _bh.Decrowd
12. _prior.Patrol
```

**Issues:**
- ❌ `FightBack` is at position 4 — should be higher (position 2–3) for survival
- ❌ `SelfDefense` is missing entirely
- ❌ `Grenades` priority node is missing
- ❌ `Accuse` priority node is missing — critical for an info role that should accuse players
- ❌ `ClairvoyantWicked` at position 2 runs before combat — information reveal shouldn't block self-defense
- ❌ No Jester-hunt behavior in the tree

### 3.3 Behavior (`behaviors/clairvoyantwicked.lua`)

**What it does:**
1. Validates bot is `ROLE_WICKED` or `ROLE_CLAIRVOYANT` + alive + off cooldown
2. Finds a random player with a non-base role (filters out Innocent/Detective/Traitor)
3. Fires `"ClairvoyantReveal"` chatter: `"{{name}} is a special role"`
4. Sets 15–60 second cooldown
5. Completes in a single tick

**Fundamental Problems:**

| Issue | Severity | Description |
|-------|----------|-------------|
| **Shared with Wicked** | 🟡 Medium | Two fundamentally different roles (innocent vs traitor) share one behavior. The Wicked's additional team filter is a bolted-on check. They should be separated for independent evolution. |
| **No suspicion integration** | 🔴 High | The Clairvoyant reveals info via chat but never adjusts its own suspicion values. A real player would mentally flag special-role players as "uncertain" — the bot should too. |
| **No evidence integration** | 🔴 High | No entries are added to the evidence system. The Clairvoyant's knowledge should create persistent evidence records. |
| **Ignores `ttt2_cv_visible`** | 🟡 Medium | The bot treats ALL special-role players as visible, ignoring the server's percentage gate. At `ttt2_cv_visible=50`, the bot "sees" twice as many players as it should. |
| **No personality modulation** | 🟡 Medium | All bot archetypes behave identically. A Tryhard should be more strategic; a Dumb bot should reveal info carelessly. |
| **Immediate revelation** | 🔴 High | The bot broadcasts findings immediately. The role's own description warns: *"Do not talk too much about your ability, or you will quickly pay for it!"* There's no self-preservation delay or strategic timing. |
| **No Jester awareness** | 🔴 High | The Jester→Sidekick conversion is completely unimplemented. This is one of the role's defining strategic options. |
| **Cooldown is arbitrary** | 🟡 Medium | 15–60 second random cooldown doesn't match the real ability (passive, immediate at round start). Should process all intel at round start, then strategically reveal over time. |
| **Sparse chatter** | 🟡 Medium | Only 3 chat lines across 3 archetypes. Compare Oracle: 9 lines across 9 archetypes. |
| **Single-tick execution** | 🟢 Low | The behavior fires and completes instantly. While info-reveal doesn't need locomotion, the lack of deliberation feels artificial. |

---

## 4. Gap Analysis

### Feature Coverage Matrix

| Clairvoyant Ability | Human Player Experience | Current Bot Implementation | Gap |
|---------------------|------------------------|---------------------------|-----|
| See special roles on scoreboard | Purple highlights at round start | Random target selection on cooldown | 🔴 Fundamental mismatch |
| Know who has a special role (not which) | Deductive reasoning from known info | Omniscient `GetSubRole()` check | 🟡 Bot has MORE info than human |
| Strategic info sharing | Careful, timed reveals to trusted allies | Immediate public broadcast | 🔴 No self-preservation |
| Avoid drawing attention | Stay inconspicuous, don't over-share | Broadcasts on fixed cooldown | 🔴 Opposite of intended play |
| Kill Jester → get Sidekick | Identify Jester, execute, gain ally | Not implemented | 🔴 Missing entirely |
| Adjust play based on intel | Target isolation, alibi checking, deduction | No behavioral change from intel | 🔴 Intel is wasted |
| `ttt2_cv_visible` gating | See only X% of special roles | See 100% always | 🟡 Over-informed |
| Round-start snapshot | Info is static from round start | Re-scans on each cooldown | 🟡 Wrong timing model |
| `unknownTeam` protection | Leverage anonymity for survival | No awareness of own anonymity | 🟡 Missed tactical layer |

### System Integration Coverage

| Bot Framework System | Used by Clairvoyant? | Should Be Used? | Priority |
|---------------------|---------------------|-----------------|----------|
| Suspicion/Morality | ❌ No | ✅ Yes — raise suspicion on special-role players | High |
| Evidence Engine | ❌ No | ✅ Yes — new `CLAIRVOYANT_INTEL` evidence type | High |
| Personality System | ❌ No | ✅ Yes — archetype-driven reveal strategy | Medium |
| Chatter System | ⚠️ Minimal (3 lines) | ✅ Yes — 20+ lines, strategic timing | Medium |
| Round Awareness | ❌ No | ✅ Yes — phase-aware reveal pacing | Medium |
| Memory System | ❌ No | ✅ Yes — track which reveals have been made | Low |
| Locomotor | ❌ No | ⚠️ Optional — for Jester hunt approach | Low |
| Coordination | ❌ No | ⚠️ Optional — share intel with team coordinator | Low |

---

## 5. Architecture & Design Decisions

### Decision 1: Separate from Wicked

**Recommendation: Split `ClairvoyantWicked` into two independent behaviors.**

**Rationale:**
- The Clairvoyant (TEAM_INNOCENT) needs suspicion integration, self-preservation, evidence tracking, and Jester awareness
- The Wicked (TEAM_TRAITOR) needs deception mechanics, traitor coordination, and offensive use of role knowledge
- Shared logic (target filtering) is trivial and can be a utility function
- Separate files enable independent evolution without regression risk

**Impact:**
- `behaviors/clairvoyantwicked.lua` → Wicked-only (rename to `behaviors/wickedreveal.lua` or keep as-is with Clairvoyant check removed)
- New `behaviors/clairvoyantintel.lua` → Clairvoyant-only intelligence behavior
- New `behaviors/clairvoyantjesterhunt.lua` → Jester conversion behavior

### Decision 2: Intel Processing Model

**Recommendation: Round-start snapshot with phased revelation.**

```
Round Start (TTTBeginRound hook):
  └─ Process all special-role players
  └─ Apply ttt2_cv_visible percentage filter
  └─ Store as bot._cvIntelTargets = { {ply=..., revealed=false}, ... }
  └─ Add CLAIRVOYANT_INTEL evidence entries for all known targets

During Round (behavior tree tick):
  └─ ClairvoyantIntel.Validate():
      ├─ Has unrevealed targets?
      ├─ Cooldown expired?
      ├─ Phase-appropriate? (more cautious early, bolder late)
      └─ Personality check (reveal eagerness)
  └─ ClairvoyantIntel.OnRunning():
      ├─ Select next target to reveal (priority: most suspicious, nearest, etc.)
      ├─ Fire chatter event with personality-appropriate line
      ├─ Mark target as revealed
      ├─ Adjust own suspicion of target
      └─ Set personality-scaled cooldown
```

### Decision 3: Suspicion Integration Strategy

**Recommendation: Moderate suspicion increase for special-role players, with personality modulation.**

A Clairvoyant knows someone has a special role but not which one. Special roles include both dangerous ones (Serial Killer, Infected) and benign ones (Amnesiac, Drunk). The suspicion adjustment should reflect this uncertainty:

| Situation | Suspicion Change | Rationale |
|-----------|-----------------|-----------|
| Initial detection of special role | +1 to +3 (personality-scaled) | Mild increase — special ≠ dangerous |
| Special role player acting suspiciously | +2 bonus on top of normal | Compound evidence |
| Special role player acting innocently | No additional modifier | Don't punish innocuous specials |
| Jester-identified target | Custom handling (see §6.4) | Different goal: kill, not accuse |

### Decision 4: Jester Hunt Implementation

**Recommendation: Conditional behavior that activates only when both Jester and Sidekick addons are present.**

```
Activation conditions:
  1. JESTER global exists
  2. SIDEKICK global exists
  3. Bot has identified a likely Jester candidate
  4. Personality eagerness check (Tryhard=eager, Nice=reluctant, Dumb=random)

Jester identification heuristic:
  - Player is in bot._cvIntelTargets (confirmed special role)
  - Player is acting "Jester-like": getting in people's faces, not fighting back,
    trying to provoke, crowbar swinging, etc.
  - Low suspicion from others (Jesters often seem harmless)
  - Has not been KOS'd (Jesters want to be killed by players, not by KOS)

Execution:
  - Approach target
  - Attack with priority ROLE_HOSTILITY (3)
  - On kill, fire "ClairvoyantJesterKill" chatter
  - Post-conversion, adjust behavior to account for new Sidekick ally
```

### Decision 5: Personality Modifier Table

Following the Spy role's pattern (`TTTBots.Spy.GetPersonalityModifiers`):

| Archetype | `revealEagerness` | `cautionLevel` | `jesterHuntChance` | `intelProcessDelay` | `suspicionBonus` |
|-----------|--------------------|----------------|---------------------|--------------------|-------------------|
| **Default** | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |
| **Tryhard** | 1.4 | 1.3 | 1.5 | 0.7 | 1.3 |
| **Hothead** | 1.6 | 0.5 | 1.8 | 0.4 | 1.5 |
| **Stoic** | 0.6 | 1.5 | 0.8 | 1.5 | 0.8 |
| **Nice** | 1.2 | 1.0 | 0.4 | 1.0 | 0.7 |
| **Casual** | 0.8 | 0.8 | 0.6 | 1.3 | 0.9 |
| **Bad** | 0.5 | 0.6 | 1.3 | 0.8 | 1.1 |
| **Dumb** | 1.3 | 0.3 | 0.9 | 0.5 | 0.6 |
| **Sus** | 0.7 | 1.6 | 0.7 | 1.4 | 1.4 |
| **Teamer** | 1.5 | 1.1 | 1.0 | 0.8 | 1.0 |

**Modifier explanations:**
- `revealEagerness` — How quickly/frequently the bot shares intel via chat (higher = more talkative)
- `cautionLevel` — How much the bot self-censors to avoid drawing attention (higher = more strategic)
- `jesterHuntChance` — Likelihood of pursuing Jester→Sidekick conversion (higher = more aggressive)
- `intelProcessDelay` — How long after round start before the bot begins acting on intel (higher = more patient)
- `suspicionBonus` — Multiplier on suspicion changes from clairvoyant intel (higher = more paranoid)

---

## 6. Implementation Plan

### Phase 1: Core Intelligence System (Priority: HIGH)

#### 6.1 New File: `behaviors/clairvoyantintel.lua`

**Purpose:** Replace the Clairvoyant half of `ClairvoyantWicked` with a proper multi-phase intelligence behavior.

**Lifecycle:**

```
┌─────────────────────────────────────────────────────┐
│                   ROUND START                        │
│  Hook: TTTBeginRound                                 │
│  ├─ Gather all alive players                         │
│  ├─ Filter: exclude Innocent, Traitor, Detective,    │
│  │   Clairvoyant, dead, spectators                   │
│  ├─ Apply ttt2_cv_visible percentage                 │
│  ├─ Store in bot._cvIntelTargets                     │
│  ├─ Add CLAIRVOYANT_INTEL evidence for each target   │
│  └─ Apply initial suspicion bump (+1 to +3)          │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│               BEHAVIOR TREE (per tick)               │
│                                                      │
│  Validate():                                         │
│  ├─ Is ROLE_CLAIRVOYANT?                             │
│  ├─ Is alive?                                        │
│  ├─ Has unrevealed intel targets?                    │
│  ├─ Cooldown expired?                                │
│  ├─ Phase check (delay early, act later)             │
│  └─ Personality check (cautionLevel gate)            │
│                                                      │
│  OnRunning():                                        │
│  ├─ Select best target to reveal:                    │
│  │   ├─ Highest suspicion (compound intel)           │
│  │   ├─ Nearest (natural conversation)               │
│  │   └─ Most recently seen (fresh intel feels real)  │
│  ├─ Fire "ClairvoyantReveal" chatter                 │
│  ├─ Mark target as revealed                          │
│  ├─ Boost suspicion by +1 (re-evaluation trigger)    │
│  └─ Set next cooldown (personality-scaled, 20–90s)   │
│                                                      │
│  OnEnd():                                            │
│  └─ Clear transient state                            │
└─────────────────────────────────────────────────────┘
```

**Key design details:**

1. **ConVar Awareness:**
   ```lua
   local cv_visible = GetConVar("ttt2_cv_visible")
   local pct = cv_visible and cv_visible:GetInt() or 100
   ```
   Apply the percentage by randomly selecting `math.ceil(#targets * pct / 100)` from the full list.

2. **Evidence Integration:**
   ```lua
   local evidence = bot:BotEvidence()
   evidence:AddEvidence({
       type    = "CLAIRVOYANT_INTEL",
       subject = target,
       detail  = "special role detected (clairvoyant ability)",
       weight  = 3,  -- Moderate: special ≠ hostile
   })
   ```
   This creates a persistent evidence floor that prevents suspicion decay below the intel level. Weight of 3 is below `AccuseWeightThreshold` (7) but above `SoftSusThreshold` (3), meaning the Clairvoyant will internally flag the target as mildly suspicious but won't auto-accuse.

3. **Suspicion Scaling:**
   ```lua
   local morality = bot:BotMorality()
   local personality = bot:BotPersonality()
   local susMult = getPersonalityModifiers(bot).suspicionBonus
   morality:ChangeSuspicion(target, "CurseWitnessed", 0.5 * susMult)
   -- Using "CurseWitnessed" (value=3) as closest analog, multiplied down
   ```
   The initial suspicion bump should be small (+1.5 effective) — enough to shift the bot's attention but not enough to trigger KOS.

4. **Phase-Aware Pacing:**
   ```lua
   local ra = bot:BotRoundAwareness()
   local phase = ra:GetPhase()
   if phase == "EARLY" then
       -- Long cooldowns, cautious reveals
       cooldown = math.random(40, 90) / modifiers.revealEagerness
   elseif phase == "MID" then
       -- Standard pacing
       cooldown = math.random(25, 50) / modifiers.revealEagerness
   else -- LATE / OVERTIME
       -- Rapid reveals, time is running out
       cooldown = math.random(10, 25) / modifiers.revealEagerness
   end
   ```

5. **Self-Preservation Logic:**
   A high `cautionLevel` bot should:
   - Delay reveals when many players are nearby (don't draw attention)
   - Prefer revealing via team chat (if coordinating with innocents)
   - Skip reveals entirely if the bot's own health is low (survival mode)
   - Avoid revealing if the Clairvoyant has been called out or KOS'd

#### 6.2 New Evidence Type: `CLAIRVOYANT_INTEL`

Add to the evidence weights table in `sv_evidence.lua`:

```lua
CLAIRVOYANT_INTEL = 3  -- Between SUSPICIOUS_MOVEMENT (2) and NEAR_BODY (4)
```

**Rationale:** Knowing someone has a special role is mildly suspicious but not damning. It's stronger than suspicious movement (the bot has concrete ability-derived knowledge) but weaker than being found near a body (no direct crime evidence).

#### 6.3 Updated Role Registration (`roles/clairvoyant.lua`)

```lua
local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Grenades,
    _prior.Accuse,          -- NEW: Clairvoyants should accuse suspicious players
    _bh.ClairvoyantIntel,   -- CHANGED: new behavior replaces ClairvoyantWicked
    _bh.ClairvoyantJesterHunt, -- NEW: Jester conversion opportunity
    _prior.Requests,
    _prior.Support,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

local roleDescription = "You are the Clairvoyant — an innocent-team role with the unique ability to detect "
    .. "which players have special (non-vanilla) roles. On the scoreboard, special-role players appear "
    .. "with a purple highlight. You know SOMEONE has a special role, but not WHICH special role. "
    .. "Special roles include both dangerous ones (Serial Killer, Infected, Traitors-in-disguise) and "
    .. "benign ones (Amnesiac, Drunk, other Innocents). Use this information carefully — sharing too "
    .. "much reveals that you're the Clairvoyant, making you a target. "
    .. "If both the Jester and Sidekick addons are installed, you can kill the Jester to convert them "
    .. "into your personal Sidekick ally — a powerful but risky play. "
    .. "Win condition: eliminate all traitors (standard innocent victory)."

local clairvoyant = TTTBots.RoleData.New("clairvoyant")
clairvoyant:SetDefusesC4(true)
clairvoyant:SetTeam(TEAM_INNOCENT)
clairvoyant:SetCanHide(true)
clairvoyant:SetCanSnipe(true)
clairvoyant:SetBTree(bTree)
clairvoyant:SetUsesSuspicion(true)
clairvoyant:SetIsFollower(true)               -- NEW: follow groups for safety
clairvoyant:SetCanCoordinateInnocent(true)     -- NEW: share intel with team
clairvoyant:SetAlliedRoles({})
clairvoyant:SetAlliedTeams({})
clairvoyant:SetRoleDescription(roleDescription) -- IMPROVED: LLM-optimized description
TTTBots.Roles.RegisterRole(clairvoyant)
```

### Phase 2: Jester Conversion System (Priority: MEDIUM)

#### 6.4 New File: `behaviors/clairvoyantjesterhunt.lua`

**Purpose:** Implement the Jester→Sidekick conversion mechanic.

**Activation Guard:**
```lua
function ClairvoyantJesterHunt.Validate(bot)
    -- Guard: both addons must be present
    if not (JESTER and SIDEKICK) then return false end
    if not ROLE_JESTER or not ROLE_SIDEKICK then return false end
    if bot:GetSubRole() ~= ROLE_CLAIRVOYANT then return false end
    if not lib.IsPlayerAlive(bot) then return false end

    -- Must have a Jester candidate identified
    local state = getState(bot)
    if not state.jesterCandidate then
        state.jesterCandidate = identifyJesterCandidate(bot)
    end
    return state.jesterCandidate ~= nil
end
```

**Jester Identification Heuristic:**
The Clairvoyant knows who has a special role but must *deduce* which one is the Jester. The heuristic should consider:

```lua
function identifyJesterCandidate(bot)
    local targets = bot._cvIntelTargets
    if not targets then return nil end

    local personality = bot:BotPersonality()
    local modifiers = getPersonalityModifiers(bot)

    for _, entry in ipairs(targets) do
        local ply = entry.ply
        if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end

        local jesterScore = 0

        -- Behavioral signals that suggest Jester:
        -- 1. Player has been crowbar-swinging (Jesters often provoke with crowbar)
        if ply.lastCrowbarSwing and CurTime() - ply.lastCrowbarSwing < 30 then
            jesterScore = jesterScore + 3
        end

        -- 2. Player has low suspicion from all bots (Jesters are harmless)
        local morality = bot:BotMorality()
        local sus = morality:GetSuspicion(ply) or 0
        if sus < 2 then
            jesterScore = jesterScore + 2
        end

        -- 3. Player is approaching others aggressively but not shooting
        -- (Jester wants to be killed)
        if ply.isApproachingPlayers and not ply.hasFireedRecently then
            jesterScore = jesterScore + 2
        end

        -- 4. Player is on a known Jester team
        if ply:GetTeam and ply:GetTeam() == TEAM_JESTER then
            jesterScore = jesterScore + 5  -- Strong signal
        end

        -- Personality gate: some archetypes are more willing to gamble
        local threshold = 4 / modifiers.jesterHuntChance
        if jesterScore >= threshold then
            return ply
        end
    end

    return nil
end
```

**Execution Flow:**
1. Validate: Jester candidate exists and is alive
2. OnStart: Fire "ClairvoyantJesterApproach" chatter (subtle, e.g., "I think I know what you are, {{name}}")
3. OnRunning: Navigate toward target, request attack via morality system with `ROLE_HOSTILITY` priority
4. OnSuccess: Fire "ClairvoyantJesterKill" chatter (triumphant, e.g., "Welcome to the team, {{name}}")
5. OnEnd: Clear state, update intel targets

### Phase 3: Chatter Enhancement (Priority: MEDIUM)

See §8 for full chatter specification.

### Phase 4: Personality Integration (Priority: MEDIUM)

#### 6.5 Personality Modifier Function

Add to `roles/clairvoyant.lua`:

```lua
TTTBots.Clairvoyant = TTTBots.Clairvoyant or {}

function TTTBots.Clairvoyant.GetPersonalityModifiers(bot)
    local defaults = {
        revealEagerness   = 1.0,
        cautionLevel      = 1.0,
        jesterHuntChance  = 1.0,
        intelProcessDelay = 1.0,
        suspicionBonus    = 1.0,
    }

    local personality = bot.BotPersonality and bot:BotPersonality()
    if not personality then return defaults end

    local archetype = personality.GetClosestArchetype
        and personality:GetClosestArchetype() or "Default"

    local modifierTable = {
        Hothead = { revealEagerness = 1.6, cautionLevel = 0.5,
                    jesterHuntChance = 1.8, intelProcessDelay = 0.4, suspicionBonus = 1.5 },
        Tryhard = { revealEagerness = 1.4, cautionLevel = 1.3,
                    jesterHuntChance = 1.5, intelProcessDelay = 0.7, suspicionBonus = 1.3 },
        Stoic   = { revealEagerness = 0.6, cautionLevel = 1.5,
                    jesterHuntChance = 0.8, intelProcessDelay = 1.5, suspicionBonus = 0.8 },
        Nice    = { revealEagerness = 1.2, cautionLevel = 1.0,
                    jesterHuntChance = 0.4, intelProcessDelay = 1.0, suspicionBonus = 0.7 },
        Casual  = { revealEagerness = 0.8, cautionLevel = 0.8,
                    jesterHuntChance = 0.6, intelProcessDelay = 1.3, suspicionBonus = 0.9 },
        Bad     = { revealEagerness = 0.5, cautionLevel = 0.6,
                    jesterHuntChance = 1.3, intelProcessDelay = 0.8, suspicionBonus = 1.1 },
        Dumb    = { revealEagerness = 1.3, cautionLevel = 0.3,
                    jesterHuntChance = 0.9, intelProcessDelay = 0.5, suspicionBonus = 0.6 },
        Sus     = { revealEagerness = 0.7, cautionLevel = 1.6,
                    jesterHuntChance = 0.7, intelProcessDelay = 1.4, suspicionBonus = 1.4 },
        Teamer  = { revealEagerness = 1.5, cautionLevel = 1.1,
                    jesterHuntChance = 1.0, intelProcessDelay = 0.8, suspicionBonus = 1.0 },
    }

    return modifierTable[archetype] or defaults
end
```

### Phase 5: Wicked Decoupling (Priority: LOW)

#### 6.6 Refactor `ClairvoyantWicked` for Wicked-Only Use

**Option A: Rename and simplify** — Remove the `ROLE_CLAIRVOYANT` check from `ClairvoyantWicked.Validate()`, making it Wicked-only. The behavior name can remain for backward compatibility.

**Option B: Create shared utility** — Extract the target-finding logic into a helper:
```lua
TTTBots.Lib.FindSpecialRolePlayers(bot, excludeSameTeam)
```
Both `ClairvoyantIntel` and the Wicked behavior can call this utility independently.

**Recommended: Option A** (simpler, less risk, the Clairvoyant no longer uses this behavior).

---

## 7. File-by-File Specifications

### New Files

| File | Purpose | Lines (est.) | Priority |
|------|---------|-------------|----------|
| `behaviors/clairvoyantintel.lua` | Core intel processing & strategic reveal behavior | ~180 | P1 |
| `behaviors/clairvoyantjesterhunt.lua` | Jester→Sidekick conversion behavior | ~120 | P2 |

### Modified Files

| File | Changes | Priority |
|------|---------|----------|
| `roles/clairvoyant.lua` | New behavior tree, personality modifiers, enhanced role description, round-start hook | P1 |
| `behaviors/clairvoyantwicked.lua` | Remove `ROLE_CLAIRVOYANT` check from `Validate()` | P5 |
| `locale/en/sh_chats.lua` | Add 20+ new chatter lines (see §8) | P3 |
| `components/sv_evidence.lua` | Add `CLAIRVOYANT_INTEL` evidence type (weight: 3) | P1 |

### Files NOT Modified (preserved)

| File | Reason |
|------|--------|
| `roles/wicked.lua` | Wicked still uses `ClairvoyantWicked` behavior — unaffected |
| `components/sv_morality_suspicion.lua` | Use existing `ChangeSuspicion()` API — no changes needed |
| `components/sv_personality.lua` | Use existing personality API — no changes needed |

---

## 8. Chatter System Enhancements

### New Chatter Categories

#### `ClairvoyantReveal` (Enhanced — replace existing 3 lines)

```
Category: ClairvoyantReveal
Priority: P.IMPORTANT
Description: "When a Clairvoyant bot reveals that a player has a special role. Args: {{name}}"

Lines:
  Default:  "{{name}} is a special role."
  Default:  "I can tell {{name}} isn't what they seem."
  Casual:   "{{name}} is a special role, interesting"
  Casual:   "hmm, {{name}}'s got something going on"
  Nice:     "you got anything to hide, {{name}}?"
  Nice:     "hey {{name}}, your role is... interesting"
  Stoic:    "{{name}} has a non-standard role. Noted."
  Stoic:    "My ability confirms {{name}} is not a base role."
  Hothead:  "HEY {{name}} I KNOW you have a special role!"
  Hothead:  "{{name}} is definitely not innocent or traitor, watch them!"
  Bad:      "{{name}} has a special role... not that I care"
  Bad:      "so {{name}} isn't vanilla, whatever"
  Tryhard:  "Intel update: {{name}} is confirmed special role. Everyone take note."
  Tryhard:  "Marking {{name}} as special — we need to figure out what they are."
  Dumb:     "uhhh is {{name}} like... a special role or something?"
  Dumb:     "i think {{name}} has one of those fancy roles idk"
  Sus:      "I'm watching you, {{name}}. You're not what you seem."
  Sus:      "{{name}}... something tells me you're hiding something."
  Teamer:   "team, {{name}} has a special role — let's keep tabs on them"
  Teamer:   "everyone watch {{name}}, they're a special role"
```

#### `ClairvoyantCautious` (NEW)

```
Category: ClairvoyantCautious
Priority: P.NORMAL
Description: "When a cautious Clairvoyant hints at knowledge without revealing it fully. Args: {{name}}"

Lines:
  Default:  "I'd keep an eye on {{name}} if I were you."
  Casual:   "just a feeling about {{name}}, nothing concrete"
  Nice:     "{{name}}, no offense, but I'm a little wary of you"
  Stoic:    "I have my reasons to watch {{name}} closely."
  Bad:      "{{name}} is sus, trust me on this one"
  Sus:      "not saying anything specific, but {{name}}..."
  Tryhard:  "I've got intel on {{name}} but I'll share when the time is right."
```

#### `ClairvoyantJesterApproach` (NEW — if Jester addon exists)

```
Category: ClairvoyantJesterApproach
Priority: P.IMPORTANT
Description: "When a Clairvoyant bot approaches a suspected Jester. Args: {{name}}"

Lines:
  Default:  "I know what you are, {{name}}."
  Casual:   "nice try {{name}}, I see right through you"
  Hothead:  "{{name}}, you're the jester aren't you? Come here!"
  Tryhard:  "Engaging suspected Jester {{name}} for tactical advantage."
  Dumb:     "wait are you the jester {{name}}? only one way to find out"
```

#### `ClairvoyantJesterKill` (NEW — post-conversion)

```
Category: ClairvoyantJesterKill
Priority: P.IMPORTANT
Description: "When a Clairvoyant kills the Jester and gains a Sidekick. Args: {{name}}"

Lines:
  Default:  "Welcome to my team, {{name}}."
  Casual:   "gg {{name}}, you're with me now"
  Hothead:  "GOT YOU {{name}}! Now you work for ME!"
  Nice:     "Sorry about that {{name}}, but now we're partners!"
  Tryhard:  "Jester eliminated. Sidekick acquired. Let's win this."
```

#### `ClairvoyantRoundStart` (NEW)

```
Category: ClairvoyantRoundStart
Priority: P.LOW
Description: "When a Clairvoyant bot first processes their intel at round start. No args."

Lines:
  Default:  "Interesting round... I can see a lot of special roles."
  Stoic:    "My abilities are active. I see the truth."
  Dumb:     "whoa, my scoreboard is all glowy and purple"
  Tryhard:  "Alright, scanning for specials... got a few hits."
  Casual:   "oh nice, i can see who's special this round"
```

#### `ClairvoyantNoSpecials` (NEW — edge case)

```
Category: ClairvoyantNoSpecials
Priority: P.LOW
Description: "When the Clairvoyant detects no special roles (vanilla round). No args."

Lines:
  Default:  "Huh, nobody special this round. Just the basics."
  Casual:   "boring, no specials this time"
  Tryhard:  "Clean scan — no special roles detected. Standard protocol."
```

---

## 9. Integration with Existing Systems

### 9.1 Evidence System

**New evidence type registration** in `sv_evidence.lua`:

```lua
BotEvidence.EvidenceWeights["CLAIRVOYANT_INTEL"] = 3
```

**How it flows:**
1. At round start, `ClairvoyantIntel` adds `CLAIRVOYANT_INTEL` evidence for each detected target
2. Evidence creates a suspicion floor of 3 (above `SoftSusThreshold`, below `AccuseWeightThreshold`)
3. If other evidence accumulates (witnessed kill, body found near, etc.), the floor compounds
4. The Clairvoyant may later reference this intel when accusing players (via `FormatEvidenceSummary`)

### 9.2 Suspicion System

**Integration points:**
- Initial detection: `ChangeSuspicion(target, "CurseWitnessed", 0.5 * suspicionBonus)` → effective +1.5 base
- On reveal (after chatting): Additional `ChangeSuspicion(target, "Hurt", 0.3 * suspicionBonus)` → small bump to re-trigger threshold checks
- Hook into `TTTBotsModifySuspicion`: Clairvoyant targets get a 1.2× suspicion multiplier from all sources (the Clairvoyant pays more attention to known specials)

```lua
hook.Add("TTTBotsModifySuspicion", "TTTBots.Clairvoyant.SusMod", function(bot, target, reason, mult)
    if bot:GetSubRole() ~= ROLE_CLAIRVOYANT then return end
    if not bot._cvIntelTargets then return end

    for _, entry in ipairs(bot._cvIntelTargets) do
        if entry.ply == target then
            return mult * 1.2  -- 20% more suspicious of known specials
        end
    end
end)
```

### 9.3 Round Awareness System

**Phase-dependent behavior:**

| Phase | Reveal Cooldown | Behavior |
|-------|----------------|----------|
| EARLY | 40–90s (scaled by personality) | Very cautious. Process intel silently, rarely reveal. Build trust first. |
| MID | 25–50s | Standard reveals. Share info to help team coordinate. |
| LATE | 10–25s | Rapid reveals. Time pressure, share everything useful. |
| OVERTIME | 5–15s | Emergency mode. Dump all remaining intel. |

### 9.4 Coordination System

If `SetCanCoordinateInnocent(true)` is set:
- The Clairvoyant's intel feeds into the `InnocentCoordinator`
- When coordinating, the bot may prioritize investigating known special-role players
- Intel shared via coordination is less overt than public chatter (team-only)

### 9.5 Memory System

Track which targets have been revealed:
```lua
bot._cvRevealedTargets = bot._cvRevealedTargets or {}
-- After revealing target:
bot._cvRevealedTargets[target:EntIndex()] = CurTime()
```

This prevents re-revealing the same player and allows the bot to track "intel freshness."

---

## 10. Testing Strategy

### Unit Tests

| Test | What to Verify |
|------|----------------|
| Intel gathering | At round start with 10 players (3 innocent, 2 traitor, 1 detective, 4 special), the Clairvoyant should detect exactly 4 targets |
| ConVar gating | With `ttt2_cv_visible=50` and 4 special-role players, the bot should detect ~2 |
| Evidence creation | Each detected target gets a `CLAIRVOYANT_INTEL` evidence entry with weight 3 |
| Suspicion floor | After intel processing, detected targets have suspicion ≥ 1.5 |
| Jester identification | With a Jester in the special-role list + behavioral signals, the Jester hunt activates |

### Integration Tests

| Test | What to Verify |
|------|----------------|
| Full round simulation | Clairvoyant bot processes intel at round start, reveals 1-2 players during the round, adjusts suspicion appropriately |
| Jester conversion | Clairvoyant identifies and kills Jester, Sidekick is created, bot acknowledges new ally |
| Personality variation | Two Clairvoyant bots with different archetypes (Hothead vs Stoic) exhibit measurably different reveal pacing and caution levels |
| Cross-role interaction | When the Clairvoyant reveals a special-role player, other bots react to the chatter (increased suspicion via KOS/accusation pathways) |
| Wicked independence | After decoupling, Wicked role continues to function with `ClairvoyantWicked` behavior unchanged |

### Regression Tests

| Test | What to Verify |
|------|----------------|
| Behavior tree priority | FightBack still triggers before ClairvoyantIntel when the bot is under attack |
| Round cleanup | All `_cvIntelTargets` and `_cvRevealedTargets` are cleared at round end |
| Null safety | Behavior handles disconnected players, role changes mid-round, and missing addons gracefully |

---

## 11. Risk Assessment

### High Risk

| Risk | Mitigation |
|------|-----------|
| **Over-informing**: Bot Clairvoyant has server-side access to `GetSubRole()` — technically omniscient | Apply `ttt2_cv_visible` filter AND add randomization. Never reveal role identity, only "special" status. Consider adding a chance to "miss" targets based on personality. |
| **Jester misidentification**: Bot incorrectly identifies a non-Jester as Jester and kills an innocent | Use conservative Jester scoring threshold. Gate behind personality (Nice/Stoic rarely hunt). Add `TEAM_JESTER` check as strong signal. Consider requiring multiple behavioral signals before acting. |

### Medium Risk

| Risk | Mitigation |
|------|-----------|
| **Information flooding**: Clairvoyant reveals too much, too fast, making the role feel cheaty | Phase-aware cooldowns + personality `cautionLevel` + self-preservation logic (stop revealing if being targeted) |
| **Breaking Wicked**: Decoupling shared behavior may introduce bugs in the Wicked role | Test Wicked independently. Option A (just remove Clairvoyant check) is minimal-change. |
| **Evidence weight tuning**: Wrong weight for `CLAIRVOYANT_INTEL` could make bots too suspicious or not suspicious enough | Start conservative (weight=3), playtest, adjust. The evidence system has decay (90s half-life) as a natural balancing mechanism. |

### Low Risk

| Risk | Mitigation |
|------|-----------|
| **Missing addon guards**: Jester or Sidekick addons not installed | Robust `if not (JESTER and SIDEKICK)` guards at every entry point |
| **Personality modifier imbalance**: Some archetypes may be too effective or ineffective | Compare with Spy's modifier ranges (which are already playtested) and use similar spreads |
| **Chatter spam**: New lines flood the chat | Rate-limited by existing chatter system (`CanSayEvent`) and personality `textchat` trait |

---

## Appendix A: Comparison with Similar Roles

| Dimension | Clairvoyant (Proposed) | Oracle (Current) | Spy (Current) |
|-----------|----------------------|------------------|----------------|
| **Info type** | "Player X has a special role" | "One of Player A or B is on Team T" | "Player X is a traitor" |
| **Info certainty** | High (knows WHO) but low (doesn't know WHAT) | Low (50/50 between two players) | High (knows exactly) |
| **Suspicion integration** | ✅ `CLAIRVOYANT_INTEL` evidence + suspicion bump | ❌ Chatter only | ✅ `SPY_INTEL` evidence (weight=6) |
| **Personality modifiers** | ✅ 5-axis modifier table | ❌ None | ✅ 5-axis modifier table |
| **Multi-phase behavior** | ✅ Round-start processing + phased reveals | ❌ Single-tick cooldown | ✅ Multi-behavior with state management |
| **Self-preservation** | ✅ Caution scaling + phase awareness | ❌ None | ✅ Cover state + blown mechanics |
| **Special interaction** | ✅ Jester→Sidekick conversion | ❌ None | ✅ Traitor chat jamming |
| **Chatter lines** | 20+ across all archetypes | 9 lines | 4+ chatter events |

---

## Appendix B: Priority Implementation Order

```
Sprint 1 (Core - P1):
├── behaviors/clairvoyantintel.lua (new)
├── roles/clairvoyant.lua (modified - new btree + hooks + description)
├── sv_evidence.lua (add CLAIRVOYANT_INTEL weight)
└── TTTBotsModifySuspicion hook (in roles/clairvoyant.lua)

Sprint 2 (Jester + Personality - P2/P3):
├── behaviors/clairvoyantjesterhunt.lua (new)
├── TTTBots.Clairvoyant.GetPersonalityModifiers (in roles/clairvoyant.lua)
└── locale/en/sh_chats.lua (all new chatter lines)

Sprint 3 (Polish + Decoupling - P4/P5):
├── behaviors/clairvoyantwicked.lua (remove Clairvoyant check)
├── Round-start chatter events
├── Edge case handling (no specials, disconnects, mid-round role changes)
└── Playtesting + tuning (evidence weight, suspicion multipliers, cooldowns)
```

---

## Appendix C: Quick Reference — Bot Framework APIs Used

```lua
-- Role registration
TTTBots.RoleData.New(name)
TTTBots.Roles.RegisterRole(roleData)

-- Behavior state
TTTBots.STATUS.RUNNING / SUCCESS / FAILURE
bot._customProperty = value  -- ad-hoc state on bot entity

-- Suspicion
bot:BotMorality():ChangeSuspicion(target, reason, mult)
bot:BotMorality():GetSuspicion(target)

-- Evidence
bot:BotEvidence():AddEvidence({ type, subject, detail, weight })

-- Personality
bot:BotPersonality():GetClosestArchetype()

-- Chatter
bot:BotChatter():On(eventName, args, teamOnly, delay, description)

-- Round awareness
bot:BotRoundAwareness():GetPhase()  -- EARLY / MID / LATE / OVERTIME

-- Locomotion
bot:BotLocomotor():SetGoal(pos)
bot:BotLocomotor():StopMoving()

-- Memory
bot:BotMemory():UpdateKnownPositionFor(ply, pos)

-- Utility
TTTBots.Lib.IsPlayerAlive(ply)
TTTBots.Lib.GetConVarFloat(name)
TTTBots.Match.IsRoundActive()
player.GetAll()
ply:GetSubRole()
ply:GetBaseRole()
ply:GetTeam()
GetSubRoleFilter(ROLE_X)
```
