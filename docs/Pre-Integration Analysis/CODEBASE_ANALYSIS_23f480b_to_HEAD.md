# TTT Bots 2 Codebase Analysis
## Focus period: `23f480bea6caa5703e0b1f0aef477220962766b9` → `9718b6e0dae260e29580e8d2edabdce7f3e418ab`

Date prepared: 2026-03-04

Refactoring roadmap: see [REFACTORING_PASSES.md](REFACTORING_PASSES.md).

---

## 1) Executive summary

This codebase has shifted from a mostly classic TTT2 bot framework into a **much broader AI-driven bot platform** with:

- A major role-compatibility expansion (TTT2-heavy)
- A large new behavior surface for role abilities and player commands
- Multi-provider LLM chat support (ChatGPT, Gemini, DeepSeek)
- Multi-provider TTS support (Free TTS, ElevenLabs, Azure)
- A much larger runtime configuration surface (CVars)

The biggest structural change is not one file but the **interaction of four subsystems**:

1. `RoleData` and role modules
2. Behavior-tree priorities
3. `Chatter` (text + AI + voice)
4. Morality/targeting logic

The repository appears to have moved from “bot combat and navigation first” to “bot social/gameplay role fidelity first”.

---

## 2) Change scope (quantitative)

### Git range totals

- **46 commits**
- **127 files changed**
- **14,201 insertions / 1,118 deletions**

### Directory concentration (by files touched)

- `lua/tttbots2/roles/` → **43.3%**
- `lua/tttbots2/behaviors/` → **29.9%**
- `lua/tttbots2/lib/` → **10.2%**
- `lua/tttbots2/components/` → **4.7%**

### Module growth

- Behaviors: **21 → 51** (+30)
- Roles: **14 → 57** (+43)
- Lib files: **16 → 22** (+6)
- Locale files: **4 → 2** (French files removed)

### Largest commits by size

1. `e704ec1` (~12.5k line changes): massive role/behavior import and integration
2. `a328bde` (~1.2k): ChatGPT/TTS integration wave
3. `9718b6e` (~1.1k): role descriptions expansion pass
4. `38bc363` (~1.1k): major TTS architecture changes

---

## 3) Current architecture (high-level)

### Core runtime loop

- Shared bootstrap in `lua/tttbots2/sh_tttbots2.lua`
- Tick-driven AI (`TTTBots_Tick` timer) runs:
  - match logic
  - behavior trees
  - plan coordinator
  - per-bot component `Think()`

### Behavior model

- Behavior modules in `lua/tttbots2/behaviors/`
- Priority composition in `lua/tttbots2/lib/sv_tree.lua`
- Per-role behavior tree assigned via role registration

### Role abstraction

- `RoleData` class in `lua/tttbots2/lib/sv_roledata.lua`
- Role registry/resolution in `lua/tttbots2/lib/sv_roles.lua`
- Explicit role modules in `lua/tttbots2/roles/*.lua`
- Auto-registration fallback for unknown custom roles

### Bot “mind” components

- `sv_morality.lua` (suspicion, KOS, witnesses, combat heuristics)
- `sv_chatter.lua` (text events, command parsing, LLM responses, TTS dispatch)
- `sv_personality.lua` (archetypes, trait multipliers, AI/TTS provider/voice assignment)
- `sv_inventory.lua`, `sv_locomotor.lua`, `sv_memory.lua`

---

## 4) Major functional changes since 23f480b

## 4.1 Role ecosystem expansion (dominant change)

The role layer has been dramatically expanded:

- **43 new role modules** added
- Existing role modules updated for ally/enemy semantics and behavior trees
- Role metadata now includes:
  - `EnemyTeams` and `EnemyRoles`
  - `KOSUnknown`, `KOSAll`, `KOSedByAll`
  - `NeutralOverride`
  - `RoleDescription`

Impact:

- Better explicit compatibility for popular TTT2 role packs
- More deterministic ally/enemy logic
- Better behavior tree specialization per role
- Better downstream chatter quality (role-aware prompts/lines)

### Notable secondary pass

Latest commit (`9718b6e`) adds broad role descriptions, improving explainability/debug UX and paving way for richer role-aware prompts.

---

## 4.2 Behavior tree expansion and reprioritization

`sv_tree.lua` has evolved from simpler combat/investigate/patrol to a richer layered model with new groups:

- `Chatter`
- `Convert`
- `Support`
- `Requests`

and new priority entries such as:

- `ChatterHelp`
- role-conversion actions (`CreateDefector`, `CreateMedic`, etc.)
- command-response behaviors (`Wait`, `FollowMe`, `ComeHere`, role checker)
- `Healgun`, `Roledefib`, `GetPirateContract`, `Jihad`

Impact:

- Bots are now significantly more interactive and commandable
- More role ability execution inside the generic behavior framework
- Higher behavior complexity and more state interactions to test

---

## 4.3 Chatter system evolution into AI interaction bus

`sv_chatter.lua` is now a major subsystem, not just canned chatter:

- Event-driven text chatter with per-event probability modeling
- Player command parsing (follow, wait, attack, heal, ceasefire, role checker)
- Name-matching and fuzzy matching logic for selecting responding bots
- LLM-backed generated replies with provider abstraction
- Voice mode routing (`textorTTS`) and speaking-bot gating
- Optional local STT transcription polling (`data/transcribed`)

Impact:

- Huge gameplay flavor increase
- More emergent behavior and “social bot” feel
- Much larger reliability surface (network, APIs, timing, parsing)

---

## 4.4 Multi-provider LLM support

New library modules:

- `sv_chatGPT.lua`
- `sv_gemini.lua`
- `sv_deepSeek.lua`
- prompt helper `sh_chatgpt_prompts.lua`

New provider control via CVar (`chatter_api_provider`):

- 0 ChatGPT
- 1 Gemini
- 2 DeepSeek
- 3 mixed/personality-assigned

Impact:

- Provider redundancy and experimentation flexibility
- More operational complexity (keys, rate limits, output variability)

---

## 4.5 TTS and voice chat architecture

New voice stack:

- `sv_TTS.lua` (chunking/compression/net path)
- `sv_TTS_url.lua` (URL-mode playback path)
- `cl_TTS.lua` client path
- network channels (`SayTTSEL`, `SayTTSBad`)

Voice providers include:

- Free TTS (SAPI endpoint)
- ElevenLabs
- Azure Speech

with per-bot voice assignment logic in `sv_personality.lua`.

Impact:

- Strong immersion upgrade
- Introduces latency, chunking, and provider-failure edge cases
- Adds more config burden on server operators

---

## 4.6 Morality and targeting logic broadening

`sv_morality.lua` now includes broader tactical rules:

- More suspicion events and thresholds
- Role- and team-aware KOS rules
- Optional KOS modes via CVars (`kos_enemies`, `kos_nonallies`, `kos_traitorweapons`, `kos_unknown`)
- Added handling for disguised/cloaked/NPC/zombie-ish conditions
- Common-sense timer path now acts as a central “combat sanity” layer

Impact:

- Better adaptation to complex role ecosystems
- Higher risk of contradictory targeting decisions due to many overlapping heuristics

---

## 4.7 Operational/configuration expansion

`sh_cvars.lua` has expanded heavily, especially for:

- AI providers and models
- chatter/voice probabilities
- API key management
- TTS mode and quality
- dynamic quota mode min/max
- broader KOS control flags

And `CVARS.md` was added as dedicated documentation.

Impact:

- Better operator control
- Higher tuning complexity
- Greater risk of misconfiguration due to many interacting toggles

---

## 5) Key files with highest churn

Top net-churn files include:

- `lua/tttbots2/locale/en/sh_chats.lua`
- `lua/tttbots2/components/sv_chatter.lua`
- `lua/tttbots2/data/sv_default_buyables.lua`
- `lua/tttbots2/components/sv_personality.lua`
- `lua/tttbots2/lib/sh_botlib.lua`
- `lua/tttbots2/components/sv_morality.lua`

Interpretation:

- Chatter + role economy + personality now define a large part of behavior identity
- Localization text volume rose significantly, matching increased event diversity

---

## 6) Behavior/role inventory highlights

### Newly added behavior modules (sample of high-impact ones)

- Command-response: `followme`, `comehere`, `wait`, `requestattack`, `requestuserolechecker`
- Role conversion/equipment: `createcursed`, `createdefector`, `createmedic`, `createdoctor`, `swaprole`, `swapdeagle`
- Utility/support: `healgun`, `roledefib`, `defibplayer`, `ceasefire`
- Role-specific actions: `captureankh`, `plantankh`, `dropcontract`, `getpiratecontract`, `jihad`

### Newly added roles

Large compatibility expansion, including: `medic`, `doctor`, `defector`, `oracle`, `pirate`, `pharaoh`, `cursed`, `marker`, `mimic`, `priest`, `vigilante`, `wicked`, and many others.

---

## 7) Risks and technical debt hotspots

This section focuses on engineering risk visible from current code shape.

1. **Global/shared behavior state risk**
   - Some behavior modules (e.g., `chatterhelp.lua`) store mutable state on the module table (`AskStatus`, `target`), which can bleed between bots if multiple bots run the same behavior concurrently.

2. **Chatter subsystem complexity risk**
   - `sv_chatter.lua` combines event routing, parsing, LLM calls, voice routing, STT polling, and delivery logic in one large file.
   - This increases regression probability and debugging difficulty.

3. **Provider error-path inconsistency**
   - Different API adapters have slightly different failure-handling patterns and escaping/sanitization approaches.

4. **Heuristic overlap in targeting**
   - Morality + role metadata + KOS toggles + request behaviors can produce competing target assignments.

5. **Documentation drift risk**
   - Rapid role/behavior additions can outpace per-role caveat documentation and test matrix updates.

---

## 8) Quality and maintainability assessment

### Strengths

- Clear modular directory layout (`behaviors`, `roles`, `components`, `lib`)
- Good use of role abstraction (`RoleData`) to avoid hardcoding everywhere
- Strong configurability via CVars
- Impressive compatibility breadth for TTT2 ecosystems

### Weaknesses

- Chatter/voice subsystem is now monolithic and highly stateful
- Event and request handling has many nested condition branches
- Some naming/style inconsistencies and occasional debug prints in hot paths
- Large merge-style import commit makes provenance and review granularity difficult

---

## 9) Recommended next steps (pragmatic)

1. **Refactor `sv_chatter.lua` into focused modules**
   - parser/router
   - LLM client adapter layer
   - TTS dispatch layer
   - command handlers

2. **Make behavior state instance-scoped**
   - Move mutable fields from module tables to bot-scoped state where needed.

3. **Create a role-behavior compatibility matrix doc**
   - Role name, team semantics, key behavior tree overrides, known caveats.

4. **Add sanity tests/check hooks**
   - Validate ally/enemy graph consistency after role registration.
   - Validate no contradictory KOS flags for core roles unless intentional.

5. **Add minimal API resilience policy**
   - shared retry/backoff/timeout handling for all providers.

6. **Prioritize telemetry-style debug toggles**
   - uniform debug categories for chatter request lifecycle and TTS lifecycle.

---

## 10) Bottom-line conclusion

From `23f480b` to current `HEAD`, this project has undergone a **major feature expansion phase** centered on:

- role coverage explosion,
- social/command-driven bot behavior,
- AI-generated text replies,
- and TTS voice interaction.

The direction is strong for player experience and TTT2 ecosystem compatibility. The main challenge now is **stabilization and modular hardening**: reducing complexity concentration in chatter/voice logic and formalizing test/validation around role-behavior interactions.

If this stabilization pass is done, the current architecture can support further role packs and richer interaction modes with lower regression risk.
