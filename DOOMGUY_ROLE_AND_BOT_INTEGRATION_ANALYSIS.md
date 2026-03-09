# Doomguy Role + TTT2 Bots Integration Analysis

## Purpose

This document analyzes:

- the custom Doomguy / Doom Slayer role addon in `TTT2 Roles/ttt2-role_doomguy-main`
- the current TTT2 Bots architecture in `TTT2-Bots-2`
- the current Doomguy support already present in the bot codebase
- likely bugs, integration gaps, and architectural mismatches
- a practical implementation roadmap with checklist tasks and strategies

---

## Executive Summary

The current state is **partial role registration, but not full gameplay integration**.

### What already works

- TTT2 Bots already has supported role files for:
  - `doomguy`
  - `doomguy_blue`
  - `doomguy_red`
- The main `doomguy` bot role is registered as a neutral killer and prefers `weapon_dredux_de_supershotgun`.
- The bot inventory system can classify the Doom super shotgun as a shotgun because it uses `buckshot` ammo.
- Core bot combat can already make shotgun users close distance and fight aggressively.
- The chatter system is already broad enough to support Doomguy-related callouts without any major framework rewrite.

### What does **not** work well yet

- Doomguy currently only has **minimal behavior-tree support** through the generic neutral-killer preset.
- The bot does **not** understand the super shotgun’s **meathook**, nor any of the extra Doom equipment patterns.
- The bot’s weapon evaluation likely misreads the Doom weapon’s real power, so its tactical decisions are based on bad data.
- The role addon itself appears to have several likely bugs / rough edges, especially around custom convars, loadout management, and health/armor reset behavior.
- Doomguy is not meaningfully integrated into:
  - the chatter/comms layer
  - social deduction / evidence flow
  - innocent/traitor coordination
  - planner-level gameplay adaptation

### Bottom line

The current implementation is enough for a bot to technically spawn as Doomguy and hold the super shotgun, but **not enough for the role to feel intentional, polished, or strategically integrated into larger TTT2 bot gameplay**.

---

# 1. Doomguy Addon Analysis

## 1.1 Role identity and gameplay contract

The Doomguy addon defines Doom Slayer as:

- a custom team role (`TEAM_DOOMSLAYER`)
- an omniscient, public role
- a solo or semi-solo killer archetype
- a role with:
  - high health
  - armor
  - tracking option (radar or tracker)
  - life steal on dealt damage
  - forced model option
  - intro music
  - a Doom super shotgun loadout

This maps very cleanly onto the TTT Bots concept of a **neutral public aggressor**.

### Intended gameplay fantasy

The role fantasy is clearly:

- highly visible threat
- relentless pressure role
- close-range burst killer
- survivability through aggression
- cinematic intimidation

That fantasy is good for bots, because it gives a strong behavioral shape:

- push visible enemies
- collapse on isolated targets
- weapon-centric aggression
- little or no deception
- strong public callout pressure from everyone else

---

## 1.2 Doomguy role file strengths

Main strengths from the addon side:

- clear role identity
- straightforward loadout assignment
- consistent model/sound theming
- simple, understandable life steal mechanic
- public-role semantics that bots can exploit easily

The role is easier to integrate than a hidden-information role because it is not about bluffing. It is about **threat response and target pressure**.

---

## 1.3 Likely bugs and implementation risks in the role addon

## High-priority issues

### 1. Missing or unclear custom convar creation
The role reads many custom convars, including:

- `ttt2_doomguy_armor`
- `ttt2_doomguy_tracker_mode`
- `ttt2_doomguy_force_model`
- `ttt2_doomguy_max_health`
- `ttt2_doomguy_intro_music`
- `ttt2_doomguy_lifesteal`
- `ttt2_doomguy_shotgun_base_dmg`

But in the analyzed addon files, there is no visible explicit `CreateConVar(...)` for these values.

### Why this matters
If these are not created elsewhere by TTT2 role infrastructure, then:

- `GetConVar(...)` can return `nil`
- direct calls like `GetConVar(...):GetInt()` can error
- weapon file initialization may fail early
- settings menu sliders would reference non-existent convars

### Impact on bots
If the weapon file fails or the convar is invalid, the bot cannot reliably use the Doom shotgun at all.

### Recommendation
Treat convar creation/validation as the first technical audit item before any bot-side feature work.

---

### 2. Super shotgun damage is not modeled the same way the bots read it
The weapon declares:

- `SWEP.Primary.Damage = GetConVar("ttt2_doomguy_shotgun_base_dmg"):GetInt() or 5`
- `SWEP.Primary.NumberOfShots = 10`

But actual firing uses:

- `primary.Damage = self:ScaleOutputDamage(self.Primary, "dredux_dmg_supershotgun")`

So the bot-side inventory heuristics are likely not seeing the true combat output.

### Why this matters
TTT Bots estimates weapon value from static weapon fields such as damage, delay, ammo type, and shot count.

However:

- the real shot damage is computed dynamically via Doom convars
- the weapon uses `NumberOfShots`, while bot inventory currently expects `NumShots`
- DPS / threat estimation will therefore be wrong or incomplete

### Result
Bots may:

- undervalue the weapon
- make poor spacing decisions
- misjudge reload pressure
- compare it incorrectly against vanilla TTT guns

---

### 3. Loadout reset logic is too blunt
`RemoveRoleLoadout` resets the player to:

- `Health = 100`
- `MaxHealth = 100`
- removes armor by fixed amount

### Why this is risky
This ignores interaction with:

- other role modifiers
- temporary buffs
- equipment that changed max health or armor during the round
- respawn/revival edge cases

### Bot impact
Bots depend heavily on stable post-role-change state. Hard resets can desync expected combat values and produce weird survivability behavior.

---

### 4. `GiveRoleLoadout` strips all weapons
The role strips the player’s weapon inventory and gives only the Doom weapon.

### Why this matters
This is thematically consistent, but operationally risky:

- may remove utility weapons unexpectedly
- may clash with TTT2 role equipment assumptions
- may confuse inventory caching / autoswitch logic if timing is off
- may remove fallback weapons bots expect to have

### Bot impact
The current Doomguy bot works around this somewhat by preferring the super shotgun and disabling autoswitch, but the underlying loadout model is still brittle.

---

### 5. Likely typo in score field
The role file uses:

- `self.score.bodyFoundMuliplier = 3`

This looks like a typo of `bodyFoundMultiplier`.

### Impact
Probably minor, but suggests the addon has not had a strong correctness pass.

---

### 6. Lifesteal hook is very broad
The Doomguy life steal hook heals on `PlayerTakeDamage` when the attacker is Doomguy.

Potential concerns:

- may heal on partial or armor-absorbed damage in ways not intended
- may not cleanly distinguish damage sources or weird inflictors
- may create balance spikes when shotgun pellets connect across multiple targets over time

### Bot impact
This encourages aggression, which is good, but the bot should know it is rewarded for staying in fights. Right now the bot AI does not explicitly exploit that fact.

---

### 7. Meathook is heavily player-input oriented
The super shotgun’s secondary system relies on:

- `KeyPress`
- `SetupMove`
- prediction-oriented client/server behavior
- line/hull traces and owner motion assumptions

### Why this matters
Human-facing input code does not automatically become bot-intelligent behavior.

### Bot impact
Bots currently do not have a dedicated behavior that intentionally:

- selects a meathook target
- decides when it is safe to hook
- sequences secondary fire into follow-up blast
- aborts bad hooks

So one of the role’s most distinctive mechanics is effectively unused by bots.

---

## Medium-priority issues

### 8. The Doom addon is much larger than the Doomguy role actually uses
The weapon base and autorun files are copied from a much larger Doom weapon framework.

This means the addon carries:

- unrelated convars
- unrelated weapon assumptions
- extra equipment systems
- generalized Doom framework logic

This is not inherently broken, but it increases maintenance burden and makes bot integration harder because the addon is not narrowly scoped to TTT2 Doomguy.

---

### 9. Blue/red Doomguy bot roles look like placeholders
`doomguy_blue.lua` and `doomguy_red.lua` currently buy:

- `arccw_mw2_ranger`

That appears unrelated to the analyzed Doom weapon pack and likely placeholder compatibility code.

### Impact
Those roles are not aligned with the actual Doomguy addon fantasy and should be reviewed separately.

---

# 2. Existing TTT2 Bots Doomguy Support Analysis

## 2.1 What exists right now

The bot repo already contains supported role definitions for Doomguy variants.

The main one is essentially:

- neutral killer preset
- preferred weapon = Doom super shotgun
- autoswitch disabled

This is a good start, but it is still only a **registration layer**, not a full role implementation.

---

## 2.2 What the neutral-killer preset gives Doomguy

The preset currently provides:

- starts fights
- can have radar
- does not use suspicion
- KOS all non-allies
- KOSed by all non-allies
- no traitor coordination
- allied with own team + jesters
- a very small default behavior tree

### This is conceptually correct for a public solo killer
The role classification is good.

### But the default tree is too thin
The neutral-killer default tree is basically:

- fight back
- requests
- roledefib
- restore
- interact

This is missing several things Doomguy badly needs:

- chatter
- patrol / wander pressure
- active hunt behavior
- role-specific aggression logic
- equipment usage
- target-priority logic
- public-threat awareness

### Result
A Doomguy bot may technically fight, but it will not feel like a Doom Slayer. It will feel like a generic bot with a shotgun.

---

# 3. TTT2 Bots Architecture Analysis for Doomguy Integration

## 3.1 Good fit areas

## Role model
The `RoleData` / `RoleBuilder` system is flexible enough.

Doomguy fits as:

- public hostile role
- neutral killer
- low-deception role
- solo aggressor with explicit weapon preference

No architecture rewrite is required.

---

## Inventory system
The inventory system already does some things correctly for Doomguy:

- it can respect `SetAutoSwitch(false)`
- it can force a preferred weapon
- it classifies buckshot weapons as shotguns
- `AttackTarget` already closes distance when using shotgun-type weapons

This is a strong base.

---

## Chatter framework
The chatter framework is already large and extensible.

It supports:

- event-driven chat
- team-only and public chat
- localized lines
- LLM-based lines
- STT/evidence extraction
- phase-aware and emotional chatter

This means Doomguy comms can be added as a content/configuration problem more than a systems problem.

---

## Evidence / deduction systems
Because Doomguy is public and hostile, the existing evidence systems can be extended very naturally:

- Doomguy sightings can be treated as high-confidence threat intel
- death zones around Doomguy can escalate suspicion into certainty
- players mentioning Doomguy in voice/text can become structured evidence

---

## Coordinators and round awareness
TTT2 Bots already has:

- round awareness
- innocent coordination
- traitor coordination
- danger-zone and evidence ideas

These systems can be extended to make the whole lobby respond to Doomguy more intelligently.

---

## 3.2 Current gaps in the bot architecture for Doomguy specifically

## 1. No Doomguy-specific behavior tree
The current role file uses the generic neutral-killer preset.

That is not enough for:

- pressure hunting
- meathook decisions
- equipment sequencing
- health-orb/loot exploitation
- target prioritization based on proximity/isolation

---

## 2. No Doom weapon semantic model
The bot inventory system evaluates weapons using generic TTT assumptions.

That breaks down for Doom weapons because:

- damage may be computed dynamically
- shot count field naming differs
- secondary mechanics are highly nonstandard
- equipment lives partly outside standard weapon flow

### Practical consequence
The bot knows it is holding a gun, but not the tactical identity of that gun.

---

## 3. No meathook usage layer
There is currently no role behavior that says:

- if target is visible
- and target is within hookable distance
- and hook path is safe
- and follow-up shotgun blast is favorable
- then use secondary attack to collapse

Without this, one of Doomguy’s signature mechanics is absent.

---

## 4. No Doom-specific utility/equipment behaviors
The Doom framework includes concepts like:

- grenades
- freeze bomb
- flame belch
- melee/blood punch style interactions
- loot exploitation

Even if Doomguy currently only spawns with the super shotgun in this role addon, the larger Doom framework implies future expansion potential.

The bot side has no clean abstraction for this family yet.

---

## 5. No Doomguy-specific comms content
The chatter system has broad event coverage, but there are no obvious Doomguy-specific voice lines, aliases, or callout handling.

That means:

- bots may treat Doomguy as just another enemy rather than a special round-state threat
- human STT mentions like “doomguy is at tester” may not be normalized into special urgency
- no thematic Doomguy announcements exist yet

---

## 6. Larger gameplay systems are not reacting to Doomguy enough
The rest of the bot ecosystem should react to Doomguy as a **global pressure event**, not just a normal hostile player.

Examples of missing reactions:

- innocents grouping earlier
- detectives prioritizing scanner/radar/long-range response
- traitors exploiting Doomguy as chaos pressure while avoiding direct early duels
- danger zones and “public enemy” memory weighting

---

# 4. Specific Bugs, Gaps, and Improvement Opportunities

## 4.1 Doomguy role / addon side

### Major issues
- [ ] Audit whether all `ttt2_doomguy_*` convars actually exist at runtime
- [ ] Verify Doom shotgun file can load safely before those convars are guaranteed
- [ ] Replace blunt health/armor reset logic with state-aware restoration
- [ ] Revisit `StripWeapons()` in loadout flow
- [ ] Validate scoreboard/scoring field names
- [ ] Confirm life steal timing and intended damage semantics

### Medium issues
- [ ] Reduce dependency on unrelated global Doom framework code where possible
- [ ] Decide whether Doomguy should stay minimal or gain selected Doom equipment from the larger framework
- [ ] Review blue/red Doomguy variants because their current weapon choice looks placeholder-level

---

## 4.2 Bot-side role registration

### Current state
The role registration is correct in spirit, but underpowered in execution.

### Improvements
- [ ] Replace generic neutral-killer tree with a Doomguy-specific behavior tree
- [ ] Add role description metadata for maintainability
- [ ] Explicitly document why Doomguy uses `AutoSwitch(false)` and preferred-weapon forcing
- [ ] Decide whether Doomguy should use `CanCoordinate(false)` permanently or gain limited “self-broadcast only” coordination behavior

---

## 4.3 Inventory / weapon modeling

### Major gap
The bot needs a semantic understanding of the Doom super shotgun.

### Required upgrades
- [ ] Add support for `Primary.NumberOfShots` fallback when `Primary.NumShots` is absent
- [ ] Allow role-specific or weapon-class-specific overrides for damage/DPS evaluation
- [ ] Mark meathook-capable weapons explicitly in weapon info or compatibility tables
- [ ] Optionally add a compatibility table for custom addon weapons with tactical tags

### Suggested tactical tags for Doom SSG
- `is_shotgun = true`
- `is_gapcloser = true`
- `has_hook = true`
- `burst_damage = very high`
- `effective_range = short-mid`
- `commitment_weapon = high`

---

## 4.4 Combat behavior

### Major gap
The bot currently knows how to attack with a shotgun, but not how to behave like Doomguy.

### Missing Doomguy combat behaviors
- [ ] active hunt / chase behavior
- [ ] hook decision behavior
- [ ] isolation preference
- [ ] anti-kiting behavior
- [ ] regroup-after-burst logic
- [ ] exploit-lifesteal aggression logic
- [ ] target reprioritization toward wounded or exposed enemies

### Strong candidate new behaviors
- [ ] `DoomguyHunt`
- [ ] `UseMeathook`
- [ ] `DoomguyPressureAdvance`
- [ ] `CollectDoomLoot`
- [ ] `DoomguyDisengage` (only when overwhelmed / no heal value)

---

## 4.5 Comms / chatter / STT

### Current gap
The framework is ready, but Doomguy-specific event content is missing.

### Additions that would pay off quickly
- [ ] add normalized alias parsing for:
  - Doomguy
  - Doom Slayer
  - Slayer
  - Doom
- [ ] add special urgency weighting when players mention Doomguy in STT/text
- [ ] add chatter events for public enemy sightings
- [ ] add thematic but concise Doomguy self-lines
- [ ] add team strategy lines for innocent/traitor reactions to Doomguy

### Useful new chatter events
- [ ] `DoomguySpotted`
- [ ] `DoomguyLost`
- [ ] `DoomguyAtLocation`
- [ ] `DoomguyWeak`
- [ ] `DoomguyPushNow`
- [ ] `DoomguyAvoid`
- [ ] `DoomguyChasingMe`
- [ ] `DoomguyKilledPlayer`

### STT / parser opportunities
If a human says:

- “doomguy is at tester”
- “slayer near bodies”
- “doom is weak”
- “doomguy chasing me”

The parser should normalize this into a structured alert, not treat it as casual chatter.

---

## 4.6 Evidence / morality / memory

### Strong opportunity
Doomguy is a perfect fit for explicit public-danger modeling.

### Recommended memory/evidence rules
- [ ] mark Doomguy sightings as high-confidence world knowledge
- [ ] increase danger-zone weight around recent Doomguy sightings
- [ ] weight corpse investigations near Doomguy more aggressively
- [ ] treat Doomguy combat noise as higher-priority investigate target
- [ ] let innocents share Doomguy location intel more aggressively than ordinary suspicion intel

### Important distinction
Doomguy is not a suspicion problem.
Doomguy is a **threat-location problem**.

That means the AI should react less like:

- “I suspect this player”

and more like:

- “The public enemy is currently here, weak/strong, pushing, or disengaging.”

---

## 4.7 Round coordination / larger gameplay

### Innocent-side opportunities
- [ ] innocents group up sooner when Doomguy is alive
- [ ] detectives prioritize long-range lines of fire and support tools
- [ ] bots warn each other away from close-quarters traps when Doomguy is nearby
- [ ] bots call focus fire on Doomguy when he is exposed or weak

### Traitor-side opportunities
- [ ] traitors should avoid ego-dueling Doomguy early unless advantaged
- [ ] traitors can shadow Doomguy fights and third-party the survivors
- [ ] traitors can exploit Doomguy-created panic to frame others or steal tempo
- [ ] traitors should only call coordinated pushes if Doomguy is low or isolated

### Planner-level opportunity
Doomguy should affect macro behavior for the whole round, not just his own role file.

---

# 5. Recommended Implementation Strategy

## Phase 0 — Validation and hardening
Goal: make sure the addon is technically stable before deeper bot work.

### Checklist
- [ ] Verify every `ttt2_doomguy_*` convar exists and is safe to read on load
- [ ] Verify `weapon_dredux_de_supershotgun` loads without nil-convar crashes
- [ ] Verify the Doomguy role works in an ordinary TTT2 round with humans only
- [ ] Verify bot inventory cache sees the weapon consistently after role loadout strip/give
- [ ] Verify bot preferred-weapon enforcement survives respawn / role change / round restart

### Strategy
Do not start with advanced behavior work until the Doom addon is stable under TTT2 + bots. Otherwise later behavior bugs will mask addon bugs.

---

## Phase 1 — Make Doomguy bots tactically correct with the current weapon
Goal: achieve a good Doomguy bot even before meathook/equipment sophistication.

### Checklist
- [ ] Create a Doomguy-specific behavior tree
- [ ] Add chatter node to Doomguy tree
- [ ] Add patrol / hunt node to Doomguy tree
- [ ] Improve target selection toward visible, isolated, and wounded non-allies
- [ ] Add inventory compatibility fix for `NumberOfShots`
- [ ] Add weapon metadata override for Doom SSG damage profile if needed
- [ ] Make Doomguy more aggressive when health is recoverable via life steal

### Suggested behavior tree shape
A practical first-pass Doomguy tree should look more like:

1. FightBack
2. DoomguyHunt
3. Requests
4. Chatter
5. Restore
6. Interact (optional low priority)
7. Patrol

### Strategy
Get the role feeling right with just movement, spacing, target choice, and public callouts before adding secondary-fire mechanics.

---

## Phase 2 — Add signature Doom mechanics
Goal: make the bot feel unique rather than shotgun-generic.

### Checklist
- [ ] Add `UseMeathook` behavior
- [ ] Define safe/favorable hook conditions
- [ ] Add hook follow-up blast sequencing
- [ ] Add hook abort logic
- [ ] Add close-range pressure logic after hook landing
- [ ] Add optional Doom equipment behaviors if the role gets access to them

### Good meathook rules
Only hook when:

- target is visible
- target is in hook range
- target is not inside impossible geometry / dangerous drop
- target is isolated or weak
- Doomguy is not already overwhelmed by multiple close threats
- hook leads into a favorable shotgun blast window

### Avoid hooking when:

- target is surrounded by multiple enemies
- target position is a death funnel
- Doomguy is already low and cannot convert the engage into healing
- the target is too close already

---

## Phase 3 — Integrate comms, STT, and evidence
Goal: make the rest of the lobby react intelligently to Doomguy.

### Checklist
- [ ] Add Doomguy-specific chatter events
- [ ] Add parser aliases for Doomguy mentions
- [ ] Add STT extraction for Doomguy callouts
- [ ] Increase evidence confidence for Doomguy sightings
- [ ] Add “public enemy” priority handling in comms/evidence
- [ ] Add innocent-side group/focus-fire callouts
- [ ] Add traitor-side opportunistic responses

### Strategy
This phase should improve both:

- Doomguy bot expressiveness
- everyone else’s reaction quality

The second part matters more for overall round quality.

---

## Phase 4 — Integrate Doomguy into macro round planning
Goal: make Doomguy presence change how the whole match flows.

### Checklist
- [ ] Innocent coordinator: respond to Doomguy as global threat
- [ ] Traitor coordinator: exploit Doomguy-created chaos intelligently
- [ ] Round awareness: mark Doomguy zones as high danger
- [ ] Planner: prefer anti-Doomguy positioning and weapon selection
- [ ] Danger-zone system: extend persistence/severity for Doomguy sightings
- [ ] Optional: dynamic “hunt state” when Doomguy has momentum

### Strategy
This phase is where the integration stops being “role support” and becomes “better TTT2 bot gameplay”.

---

# 6. Concrete File-Level Implementation Plan

## Doom addon audit targets
- [ ] `TTT2 Roles/ttt2-role_doomguy-main/lua/terrortown/entities/roles/doomguy/shared.lua`
- [ ] `TTT2 Roles/ttt2-role_doomguy-main/lua/weapons/weapon_dredux_de_supershotgun.lua`
- [ ] `TTT2 Roles/ttt2-role_doomguy-main/lua/weapons/weapon_dredux_base2.lua`
- [ ] `TTT2 Roles/ttt2-role_doomguy-main/lua/autorun/dredux_weapons_autorun.lua`
- [ ] `TTT2 Roles/ttt2-role_doomguy-main/lua/autorun/dredux_equipment.lua`

## Bot role/config targets
- [ ] `TTT2-Bots-2/lua/tttbots2/roles/doomguy.lua`
- [ ] `TTT2-Bots-2/lua/tttbots2/lib/sv_rolebuilder.lua`
- [ ] optional review: `TTT2-Bots-2/lua/tttbots2/roles/doomguy_blue.lua`
- [ ] optional review: `TTT2-Bots-2/lua/tttbots2/roles/doomguy_red.lua`

## Bot combat/inventory targets
- [ ] `TTT2-Bots-2/lua/tttbots2/components/sv_inventory.lua`
- [ ] `TTT2-Bots-2/lua/tttbots2/behaviors/attacktarget.lua`
- [ ] add new Doomguy-specific behavior files under `TTT2-Bots-2/lua/tttbots2/behaviors/`

## Bot chatter / evidence / planner targets
- [ ] `TTT2-Bots-2/lua/tttbots2/components/chatter/sv_chatter_events.lua`
- [ ] `TTT2-Bots-2/lua/tttbots2/components/chatter/sv_chatter_parser.lua`
- [ ] `TTT2-Bots-2/lua/tttbots2/components/chatter/sv_chatter_stt.lua`
- [ ] `TTT2-Bots-2/lua/tttbots2/components/chatter/sv_chatter_stt_evidence.lua`
- [ ] `TTT2-Bots-2/lua/tttbots2/components/sv_evidence.lua`
- [ ] `TTT2-Bots-2/lua/tttbots2/components/sv_roundawareness.lua`
- [ ] innocent / traitor coordinator files as needed

---

# 7. Recommended Minimal Viable Integration

If the goal is to get strong results quickly, the smallest high-value package is:

## MVP checklist
- [ ] Fix/verify Doomguy convars
- [ ] Fix inventory support for `Primary.NumberOfShots`
- [ ] Give Doomguy a custom behavior tree with chatter + patrol + hunt
- [ ] Add one new `DoomguyHunt` behavior
- [ ] Add one new public chatter event for Doomguy sightings
- [ ] Add parser/STT alias normalization for “doomguy / doom slayer / slayer / doom”
- [ ] Make innocent bots treat Doomguy sightings as high-priority threat intel

### Why this MVP is strong
It solves the biggest practical problems first:

- technical stability
- believable aggression
- usable communication
- lobby-wide reaction quality

without requiring the harder meathook automation immediately.

---

# 8. Recommended Full Integration Vision

A fully realized Doomguy integration would produce:

## For the Doomguy bot
- aggressive hunt behavior
- competent short-range spacing
- intelligent meathook usage
- health-sustain pressure decisions
- thematic public chatter

## For innocent bots
- rapid threat broadcasting
- better grouping and focus-fire
- smarter avoidance of close-quarters funnels
- improved danger-zone memory

## For traitor bots
- opportunistic third-party behavior
- reduced suicidal ego-pushing into Doomguy
- better timing around Doomguy-generated chaos

## For the round overall
- more distinct pacing
- more believable public-enemy dynamics
- richer STT/comms usefulness
- stronger emergent stories

---

# 9. Final Recommendations

## Highest-priority recommendations
1. **Audit/fix Doomguy convar creation and weapon initialization safety first.**
2. **Add inventory compatibility for Doom weapon shot-count / damage modeling.**
3. **Replace the generic neutral-killer behavior tree with a Doomguy-specific one.**
4. **Add Doomguy-specific chatter + STT alias support.**
5. **Teach the rest of the bots to react to Doomguy as a public threat-location problem.**

## Best next implementation order
1. stability
2. weapon modeling
3. custom behavior tree
4. comms / evidence integration
5. meathook behavior
6. macro round coordination improvements

---

# 10. Suggested Work Breakdown Checklist

## Stability / correctness
- [ ] Verify custom convars
- [ ] Verify Doom shotgun load safety
- [ ] Fix health/armor reset behavior
- [ ] Review loadout strip behavior
- [ ] Review role score fields

## Core bot support
- [ ] Add Doomguy-specific role description and behavior tree
- [ ] Add Doom weapon inventory compatibility
- [ ] Add Doomguy hunt behavior
- [ ] Improve target prioritization for public enemy gameplay

## Signature mechanics
- [ ] Add meathook behavior
- [ ] Add hook safety checks
- [ ] Add hook follow-up blast logic
- [ ] Add optional Doom utility behavior layer

## Comms / evidence
- [ ] Add Doomguy chatter events
- [ ] Add Doomguy alias parsing
- [ ] Add STT extraction for Doomguy callouts
- [ ] Increase threat weight for Doomguy sightings
- [ ] Add focus-fire and avoidance lines

## Whole-round integration
- [ ] Innocent coordinator Doomguy response
- [ ] Traitor coordinator Doomguy response
- [ ] Round awareness danger-zone tuning
- [ ] Planner / macro behavior updates

---

## Conclusion

The current implementation is a **solid compatibility stub**, not a full Doomguy integration.

The good news is that the TTT2 Bots architecture is already strong enough to support a genuinely excellent Doomguy experience. The missing work is mostly:

- role-specific behavior authoring
- weapon compatibility modeling
- comms/evidence content
- macro gameplay response logic

If implemented in the order recommended above, Doomguy can become one of the most distinctive and polished special-role integrations in the entire bot ecosystem.
