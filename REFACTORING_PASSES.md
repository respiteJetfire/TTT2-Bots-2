# TTT Bots 2 — Major Refactoring Passes

Date: 2026-03-04
Scope: High-impact maintainability refactors without changing intended gameplay behavior.

---

## Refactor strategy (order matters)

The codebase currently has three high-coupling hotspots:

1. `sv_chatter.lua` (1109 lines)
2. `sv_personality.lua` (978 lines)
3. `sv_morality.lua` (795 lines)

The safest approach is **progressive extraction**:

- extract pure helpers first,
- keep runtime behavior stable,
- add lightweight guardrails/logging,
- only then adjust deeper APIs.

---

## Pass 0 — Safety baseline and instrumentation

### Goal
Freeze behavior before large movement so regressions are visible.

### Target files
- lua/tttbots2/components/sv_chatter.lua
- lua/tttbots2/components/sv_morality.lua
- lua/tttbots2/components/sv_personality.lua
- lua/tttbots2/lib/sv_roles.lua

### Tasks
- Add a `ttt_bot_debug_refactor` cvar gate for targeted diagnostics.
- Add structured debug wrappers (`DebugRefactor(category, msg)`) instead of ad-hoc `print` calls.
- Add one-line startup summary of active provider selections (`text API`, `TTS mode`, `URL mode`).
- Add assertions/guards around nil-sensitive entry points:
  - `BotChatter:On()`
  - `BotChatter:textorTTS()`
  - `TTTBots.Roles.GetRoleFor()`

### Exit criteria
- No gameplay behavior changes.
- Logs provide traceability for event→provider→delivery flow.

---

## Pass 1 — Chatter decomposition (highest ROI)

### Goal
Split `sv_chatter.lua` into cohesive modules while preserving public API.

### New module layout
- lua/tttbots2/components/chatter/sv_chatter_core.lua
- lua/tttbots2/components/chatter/sv_chatter_events.lua
- lua/tttbots2/components/chatter/sv_chatter_parser.lua
- lua/tttbots2/components/chatter/sv_chatter_commands.lua
- lua/tttbots2/components/chatter/sv_chatter_dispatch.lua
- lua/tttbots2/components/chatter/sv_chatter_stt.lua

### Responsibilities
- `sv_chatter_core.lua`: `New()`, `Initialize()`, `Think()`, component wiring.
- `sv_chatter_events.lua`: event probability table, `CanSayEvent()`, event filtering.
- `sv_chatter_parser.lua`: name matching, levenshtein, text sanitization.
- `sv_chatter_commands.lua`: follow/wait/heal/ceasefire/attack request handlers.
- `sv_chatter_dispatch.lua`: provider call selection and `text` vs `TTS` routing.
- `sv_chatter_stt.lua`: local transcription polling timer and processing.

### Key constraints
- Keep `BotChatter:On()` signature stable.
- Keep `BotChatter:RespondToPlayerMessage()` signature stable.
- Do not alter cvar names or network string names.

### Exit criteria
- Existing behavior scripts still call chatter with no call-site changes.
- All timers/hooks still register once and only once.

---

## Pass 2 — Provider adapter unification (LLM + TTS)

### Goal
Make API provider code consistent and centrally managed.

### Target files
- lua/tttbots2/lib/sv_chatGPT.lua
- lua/tttbots2/lib/sv_gemini.lua
- lua/tttbots2/lib/sv_deepSeek.lua
- lua/tttbots2/lib/sv_TTS.lua
- lua/tttbots2/lib/sv_TTS_url.lua

### Tasks
- Introduce adapter interface:
  - `SendText(prompt, bot, opts, callback)`
  - `SendVoice(bot, text, opts, callback)`
- Standardize error envelope shape (`ok`, `provider`, `code`, `message`, `raw`).
- Centralize retry/timeout policy and sanitize policy.
- Centralize response truncation and quote stripping.
- Ensure provider fallback rules are deterministic when mixed mode is active.

### Exit criteria
- Chatter dispatch no longer contains provider-specific branching complexity.
- Provider modules are mostly transport implementations, not policy owners.

---

## Pass 3 — Behavior state isolation

### Goal
Remove module-global mutable behavior state that can bleed across bots.

### Target files
- lua/tttbots2/behaviors/chatterhelp.lua
- other behavior files with module-level mutable fields

### Tasks
- Move fields like `AskStatus`, `target` to bot-scoped state:
  - `bot.behaviorState = bot.behaviorState or {}`
  - `bot.behaviorState.ChatterHelp = {...}`
- Add helper in behavior base for state access:
  - `TTTBots.Behaviors.GetState(bot, behaviorName)`
- Ensure `OnEnd()` clears only instance state.

### Exit criteria
- Two bots can run same behavior concurrently without state collision.
- No behavior relies on global mutable fields for per-bot execution.

---

## Pass 4 — Morality policy extraction and conflict resolver

### Goal
Make targeting and suspicion policies composable and easier to reason about.

### Target files
- lua/tttbots2/components/sv_morality.lua
- lua/tttbots2/lib/sv_roles.lua
- lua/tttbots2/lib/sv_roledata.lua

### Tasks
- Split `sv_morality.lua` into policy modules:
  - witness/suspicion updates
  - role/team hostility policy
  - attack-target arbitration
- Add target arbitration function with explicit precedence (example):
  1. self-defense
  2. explicit player request
  3. hard KOS role flags
  4. suspicion thresholds
  5. opportunistic aggression
- Add debug reason codes for every target assignment/clear.

### Exit criteria
- Every `SetAttackTarget()` path records a reason code.
- Contradictory clear/set loops are reduced and explainable.

---

## Pass 5 — Role registration normalization

### Goal
Reduce duplicated role boilerplate and make role metadata safer.

### Target files
- lua/tttbots2/lib/sv_roles.lua
- lua/tttbots2/lib/sv_roledata.lua
- lua/tttbots2/roles/*.lua

### Tasks
- Add `RoleBuilder` helper utilities for common presets:
  - innocent-like
  - detective-like
  - traitor-like
  - neutral public-killer
- Add registration validators:
  - unknown ally/enemy references
  - impossible team combinations
  - conflicting `KOSAll`/`NeutralOverride`
- Generate compatibility report at startup in debug mode.

### Exit criteria
- New role file setup shrinks materially.
- Role registration emits actionable warnings before round start.

---

## Pass 6 — Configuration and docs hardening

### Goal
Make runtime tuning safer for operators.

### Target files
- lua/tttbots2/commands/sh_cvars.lua
- CVARS.md
- README.md

### Tasks
- Group cvars by subsystem and add explicit dependency notes.
- Add startup warnings for invalid cvar combinations.
- Add “known-good preset” profiles (low-latency, no-cloud, full-AI, debugging).

### Exit criteria
- Fewer invalid combinations silently producing bad behavior.
- Faster operator onboarding and support.

---

## Suggested branch/PR slicing

- PR1: Pass 0 + scaffolding for Pass 1
- PR2: Pass 1 (chatter decomposition only)
- PR3: Pass 2 (provider adapters)
- PR4: Pass 3 (behavior state isolation)
- PR5: Pass 4 (morality policy extraction)
- PR6: Pass 5 (role normalization)
- PR7: Pass 6 (cvar/docs hardening)

Keep each PR reviewable and gameplay-equivalent where possible.

---

## First pass to start now

If you want immediate execution, start with **Pass 1** and do it in this exact order:

1. extract parser helpers,
2. extract command handlers,
3. extract provider dispatch,
4. leave `BotChatter` public methods as wrappers.

This gives maximum maintainability gain with low gameplay-risk.
