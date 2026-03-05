# TTTBots2 Project Analysis and Major Improvement Plan

## Scope and method

This review examined repository structure, large/high-impact modules, command/network entry points, and maintainability signals (file size, TODO density, and state management patterns).

## Key findings

### 1) Core modules are very large and mix concerns

Several files are highly concentrated and blend multiple responsibilities:

- `lua/tttbots2/lib/sh_botlib.lua` (~1700 lines)
- `lua/tttbots2/components/sv_locomotor.lua` (~1760 lines)
- `lua/tttbots2/components/sv_chatter.lua` (~1150 lines)
- `lua/tttbots2/lib/sv_pathmanager.lua` (~1070 lines)

This increases onboarding cost, raises regression risk, and makes targeted optimization difficult.

**Major improvement:** split these files into focused modules by domain (query helpers, caches/timers, decision logic, I/O/chat output, movement primitives, and path strategy), with a stable public API per module.

---

### 2) Global-state leakage risk from non-local tables/variables

The codebase uses many cached tables and timers. In Lua, accidental non-`local` assignment creates globals and can lead to subtle cross-file coupling.

One concrete instance was found and fixed in this PR:

- `lua/tttbots2/components/sv_chatter.lua`: `speakingPlayers` is now `local speakingPlayers`.

**Major improvement:** enforce a module-level rule that mutable state must be `local`, and periodically audit for global leaks in hot modules.

---

### 3) Reliability risk from large mutable caches without clear invalidation contracts

Examples include alive-player caches, isolation scoring caches, and global weapon caches updated on timers. This pattern is valid for performance, but the invalidation policies are spread across files and not always explicitly documented.

**Major improvement:** define explicit cache contracts:

- ownership (`who writes`)
- refresh trigger (`timer`, `hook`, or event)
- maximum staleness
- safe fallback behavior if cache is stale or empty

---

### 4) Test and CI automation are currently absent in-repo

No repository-native test suite, build scripts, or workflows are present. This limits confidence for refactors and high-risk behavior changes.

**Major improvement:** add lightweight automation in phases:

1. style/static checks for Lua files
2. deterministic unit checks for pure helper logic
3. optional integration smoke checks for key bot lifecycle paths

---

### 5) Operational/security-adjacent concerns in chat/content systems

The project includes AI/TTS integrations and a large user-facing name/chat corpus. There are moderation and reputation risks (offensive strings) and potential instability risk if external API-related pathways fail.

**Major improvement:** introduce:

- configurable content safety filtering for names/chat output
- strict error handling and timeout behavior for external integrations
- telemetry/logging around external request failures and latency

## Prioritized roadmap

## P0 (high impact, low-to-medium effort)

- Localize mutable module state to prevent accidental globals.
- Add a basic quality gate (Lua static check/lint in CI).
- Document cache invariants for alive players, isolation scoring, and weapon caches.

## P1 (high impact, medium effort)

- Refactor `sv_locomotor.lua` and `sh_botlib.lua` into smaller modules with unchanged external APIs.
- Add tests for utility functions used in behavior selection and scoring.
- Harden external integration error paths (timeouts, nil/invalid response handling).

## P2 (strategic improvements)

- Introduce behavior-level diagnostics/metrics (decision latency, cache hit rate, failure reasons).
- Add content moderation policy toggles for deployment-specific server preferences.
- Build performance benchmarks for common round scenarios to prevent regression.

## Change implemented in this PR

- Fixed one concrete maintainability/reliability issue by localizing chatter state:
  - `lua/tttbots2/components/sv_chatter.lua` (`speakingPlayers` -> `local speakingPlayers`)
- Added this analysis and improvement roadmap document.
