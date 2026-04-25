# TTT Bots 2 — Code Review

**Reviewer:** GitHub Copilot (automated, evidence-based pass)
**Date:** 2026-04-18
**Scope:** Full addon at `d:\Development Mods\TTT2-Bots-2`
**Footprint:** 411 Lua files, ~3.94 MB of source.

---

## 1. Executive Summary

TTT Bots 2 is an ambitious, mature addon. The architecture is largely sound:
a clear behavior-tree system, well-isolated components, a unified provider
adapter for LLM/TTS calls (`sv_providers.lua`), a real rate-limiter & cost
tracker, and a robust hibernation-aware boot sequence in `sh_tttbots2.lua`.

However, the codebase has accumulated friction in three categories:

1. **Hot-path waste & dead code** — duplicate includes, dead assignments,
   `print()` spam in tight loops, repeated `player.GetAll()` calls.
2. **Inconsistent conventions** — case-mixing on component keys, two parallel
   APIs on every LLM provider (`SendText` vs legacy `SendRequest`), one
   `.bak` file shipping in the addon, manual JSON building despite a
   `BuildRequestBody` helper.
3. **Security & networking hygiene** — at least one net handler that lets a
   superadmin invoke arbitrary console commands via `RunConsoleCommand`,
   heavy `net.WriteTable` payloads where structured writes would be safer
   and cheaper, and unvalidated payload sizes on a few admin endpoints.

None of these are catastrophic; the addon clearly works in production. The
recommendations below are ordered by **impact / effort** so the first ten
items will yield most of the win.

---

## 2. High-Impact Findings

### 2.1 Duplicate `include` of `sv_debug.lua`

[sh_tttbots2.lua](lua/tttbots2/sh_tttbots2.lua#L60-L73) calls
`include("tttbots2/lib/sv_debug.lua")` twice. Same file, same realm. Harmless
but wastes a load and any side-effects (hook registrations, network strings)
are duplicated. `sh_botlib.lua` is also included twice in `includeShared`.

**Fix:** Remove the duplicates. ~30 seconds of work.

### 2.2 Dead `bot.components.Inventory = self` assignment

[sv_inventory.lua#L26](lua/tttbots2/components/sv_inventory.lua#L26) sets
`bot.components.Inventory = self` (capital I), but
[sh_botlib.lua#L1405-L1414](lua/tttbots2/lib/sh_botlib.lua#L1405-L1414)
immediately overwrites `bot.components` with a fresh literal whose key is
lowercase `inventory`. The capital key is silently wiped before any caller
sees it. `BotInventory()` returns the lowercase key, so things still work,
but the line in `Initialize` is dead code that suggests broken intent.

The same dead pattern exists in [meta_base.lua#L33](lua/tttbots2/components/meta_base.lua#L33)
and [behaviors/meta_base.lua](lua/tttbots2/behaviors/meta_base.lua). The meta
files are documented as never executed, but the inventory case is real and
confusing.

**Fix:** Remove `bot.components.Inventory = self` from `Initialize`, or
standardise so every component sets its own key (lowercase) inside
`Initialize` and remove the literal-table assignment in
`createPlayerBot`.

### 2.3 Backup file shipping in workshop content

`lua/tttbots2/lib/sv_chatGPT.lua.bak` is a 3 KB stale copy from 2025-03-03.
[addon.json](addon.json) does not list `*.bak` in `ignore`, so it will be
packed when uploaded to the workshop. Lua does not load `.bak` files but it
still bloats the GMA and confuses contributors.

**Fix:** Delete the file; add `"*.bak"` to the `ignore` array in `addon.json`.

### 2.4 Provider adapters bypass their own JSON helper

[sv_providers.lua#L249-L256](lua/tttbots2/lib/sv_providers.lua#L249-L256)
exposes `TTTBots.Providers.BuildRequestBody(tbl)` "to prevent JSON injection
from untrusted prompt text". Yet [sv_chatGPT.lua#L36-L62](lua/tttbots2/lib/sv_chatGPT.lua#L36-L62)
builds the body via `string.format` with a hand-rolled `jsonEscape` that only
escapes control chars, `"` and `\`. It does **not** escape forward slashes
inside `</script>`-style payloads (low risk for OpenAI but still a smell), and
silently breaks if `model` ever contains a quote or backslash. The other
adapters likely have similar manual JSON. This entire class of bug is
eliminated by feeding a Lua table to `util.TableToJSON` once.

**Fix:** Replace every manual JSON in `sv_chatGPT.lua`, `sv_gemini.lua`,
`sv_deepSeek.lua`, `sv_ollama.lua`, `sv_openrouter.lua` with
`TTTBots.Providers.BuildRequestBody{ ... }`.

### 2.5 `RunConsoleCommand` invoked on attacker-controlled strings

[sv_miscnetwork.lua#L102-L108](lua/tttbots2/lib/sv_miscnetwork.lua#L102-L108)
handles `TTTBots_RequestCvarUpdate`:

```lua
net.Receive("TTTBots_RequestCvarUpdate", function(len, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    local cvar  = net.ReadString()
    local value = net.ReadString()
    RunConsoleCommand(cvar, value)
end)
```

Gating on `IsSuperAdmin` keeps random players out, but the handler still
allows an authenticated superadmin to execute arbitrary server console
commands (`exit`, `rcon_password`, `sv_cheats`, `quit`, `_restart` etc.) by
naming them as a "cvar". This is a privilege escalation surface if a
superadmin's account is compromised, and it bypasses ULX/ULib audit logs.

**Fix:** Maintain a whitelist of `ttt_bot_*`/`chatter_*` cvars allowed to be
mutated this way and reject anything not on it. As a bonus, validate the
`value` length and type per cvar.

### 2.6 Inventory & other components use `net.WriteTable` for cross-net data

Five sites use `net.WriteTable` ([grep](lua/tttbots2/lib/sv_miscnetwork.lua#L93),
[167](lua/tttbots2/lib/sv_miscnetwork.lua#L167),
[sv_debug.lua#L43](lua/tttbots2/lib/sv_debug.lua#L43),
[sh_concommands.lua#L54](lua/tttbots2/commands/sh_concommands.lua#L54),
[createlovers.lua#L215](lua/tttbots2/behaviors/createlovers.lua#L215)).

`net.WriteTable` is the slowest possible serialiser: it walks every entry
with `net.WriteType`, encoding each value's type tag. The Bot Menu payload in
particular (`bots[]` + `buyables[]`) is sent on every admin click and can
easily exceed a few KB.

**Fix:** Replace with `util.Compress(util.TableToJSON(tbl))` followed by
`net.WriteUInt(#data, 32) ; net.WriteData(data, #data)`. The
[sv_customplans.lua#L221-L226](lua/tttbots2/lib/sv_customplans.lua#L221-L226)
sync handler already does exactly this and is the right model.

### 2.7 Massive `print()` spam in production paths

289 `print(` calls outside debug-only modules. Top offenders:
`sh_botlib.lua` (20), `sh_concommands.lua` (19), `sv_roles.lua` (13),
`sv_headless.lua` (10), `behaviors/wait.lua` (10), `sv_planlearning.lua` (10),
`behaviors/attacktarget.lua` (9). Many run inside the per-tick
loop; on a 32-bot match these can flood the console and `console.log` very
quickly, hurting tickrate and making real errors invisible.

The codebase already has a `lib.GetConVarBool("debug_*")` helper used in
some places. It is not used consistently.

**Fix:** Wrap every operational `print` in `if lib.GetDebugFor("...") then`,
or route through a logger that respects `ttt_bot_log_level`. Strip the
`[ALIVE-DIAG]` 10-second diagnostic in `sh_botlib.lua` once you trust the
fix.

### 2.8 `player.GetAll()` called 115 times across the codebase

`sh_tttbots2.lua` already caches it once per tick into `TTTBots._tickPlayers`
([here](lua/tttbots2/sh_tttbots2.lua#L348-L350)) — but very few sites use
that cache. Each `player.GetAll()` allocates a new table.

**Fix:** Audit the 115 sites and replace per-tick callsites with
`TTTBots._tickPlayers` (or expose `TTTBots.Lib.GetPlayersCached()` and use
it everywhere). This is mechanical but high-leverage on busy servers.

### 2.9 `RealTime()`-vs-`CurTime()` mixing in the rate limiter

The sliding-window rate limiter in
[sv_providers.lua#L57-L65](lua/tttbots2/lib/sv_providers.lua#L57-L65) uses
`CurTime()` for timestamps. `CurTime()` does not advance during hibernation
or between ticks the same way `RealTime()` does, and it is reset by certain
map-change scenarios. Since the rest of the addon already uses `RealTime()`
for the boot loop, mixing the two here can cause the per-minute window to
prune incorrectly during long pauses.

**Fix:** Use `RealTime()` consistently for wall-clock budgeting and reserve
`CurTime()` for in-game logic (round timing, respawn delays, etc.).

### 2.10 188 `timer.Create` / `timer.Simple` calls — many are never explicitly removed

Over the codebase there are 188 timer registrations. A grep for
`timer.Remove` shows far fewer cleanup paths. On `gamemode reload` /
`TTTBots.Reload()` these timers will accumulate (each `timer.Create("name", ...)`
silently replaces the old one only if the name is identical and unique).

**Fix:** Audit timers for: (a) deterministic names (no random IDs), (b) a
matching `timer.Remove` in `OnReloaded` / round-reset flow, (c) consider a
`TTTBots.Lib.AddTimer(name, ...)` wrapper that records every registration
into a registry so a single `TTTBots.ClearAllTimers()` can wipe them on
reload.

---

## 3. Architecture & Design Observations

### 3.1 Provider stack is good — finish the migration

`sv_providers.lua` is the strongest single file in the codebase: clean
contracts (`MakeOk`/`MakeError` envelopes), priority-aware rate-limiter,
cost tracker, admin dashboard, voice-vs-text dispatch.

The legacy `SendRequest(text, bot, teamOnly, wasVoice, callback)` shim in
each provider exists for backwards compatibility. Search shows it is still
used by older chatter paths. **Plan a deprecation:** mark `SendRequest`
with a one-time `print("[TTT Bots 2] DEPRECATED: ...")` per session and a
`TODO_REMOVE_BY = "1.4"` comment. Remove in a future release.

### 3.2 `Tickrate = 5` baseline is a good design choice

The behavior tree always runs (correctly noted in
[sh_tttbots2.lua#L350-L362](lua/tttbots2/sh_tttbots2.lua#L350-L362));
component `ThinkRate` throttles do the heavy lifting. The
`AdaptiveThinkRateMultiplier` + `TickRateAuto` + `TickScaler` combination
gives genuine multi-stage degradation under load. Keep this.

One nit: the inner-loop variable `i` is shadowed —
[sh_tttbots2.lua#L383](lua/tttbots2/sh_tttbots2.lua#L383) iterates
`for i, bot in pairs(bots)` and then
[L416](lua/tttbots2/sh_tttbots2.lua#L416) does
`for i, component in pairs(bot.components)` reusing the same name. Lua
allows it, but it makes the code harder to debug. Rename the inner index.

### 3.3 Coordinator proliferation

`sv_*coordinator.lua` files: amnesiac, clown, cursed, doomguy, infected,
innocent, necro, pharaoh, plan. Each is a per-role singleton tick-driver.
Most share three patterns: round-reset state, a `Tick()` called from
the master tick, and a per-role gate. Consider a
`TTTBots.Coordinators.Register(name, def)` registry so the
`includeServer()` block doesn't need a manual entry per role and the
master tick doesn't have to enumerate them by hand.

This would also let third-party role addons participate without
monkey-patching `sh_tttbots2.lua`.

### 3.4 `meta_defs.lua` is included nowhere

[meta_defs.lua](lua/tttbots2/meta_defs.lua) is a `---@meta` annotation file.
That is correct, but it is also not in any `ignore` list, so it ships in
the addon. Lua won't `require` it but it is still dead weight. Either add
`meta_defs.lua` to `addon.json -> ignore` or move it under a path the
workshop packer skips.

### 3.5 Two co-existing chat-line stores

`locale/en/sh_chats_*.lua` is enormous (tens of thousands of lines) and
duplicated in spirit by `sh_casual_chats.lua` and the LLM prompt-generated
text. Consider documenting (or pruning) the canonical source so future
contributors know whether to add a line to the locale or to the LLM prompt
context.

---

## 4. Per-Subsystem Notes

### 4.1 Boot / Headless

- The `Think` + `PlayerInitialSpawn` belt-and-suspenders init in
  [sh_tttbots2.lua#L191-L290](lua/tttbots2/sh_tttbots2.lua#L191-L290) is
  excellent. The comments alone are worth keeping.
- `HEADLESS_INIT_TIMEOUT = 30` is hard-coded; expose as a cvar
  (`ttt_bot_init_timeout`) for slow map loads.
- `EnsureNoHibernation` ([sv_headless.lua](lua/tttbots2/lib/sv_headless.lua#L52))
  calls `RunConsoleCommand` to flip `sv_hibernate_when_empty`, which is
  deferred one frame. Add a `cv:SetInt(0)` fallback for immediacy.

### 4.2 Locomotor (2176 lines)

- File is big enough to split: stuck-detection, path-following,
  look/aim, jump/duck/strafe, debug-rendering. Each is independently
  testable.
- 4× `--TODO: Move to botlib` comments around lines 1292-1326 — these are
  pure utility functions; do the move.
- `getSet(varname, default)` factory at line 38 is fine but creates two
  closures per field. Prefer a single accessor method or generate
  accessors at module load time.

### 4.3 Inventory (1168 lines)

- Beyond the dead `Inventory = self` line, the component re-derives
  `WeaponInfo` for the held weapon many times per tick. Cache last
  `(class, clip, ammo)` tuple and skip recompute when unchanged.
- `ThinkRate = 2` is good.

### 4.4 Chatter / events

- [sv_chatter_events.lua](lua/tttbots2/components/chatter/sv_chatter_events.lua)
  is 109 KB — the biggest source file. Most of it is a giant dispatch
  table mapping event-name → handler. Consider splitting by domain
  (combat, social, suspicion, role) into sibling files that each
  register into one shared table.

### 4.5 Roles

- 60+ role files under `lua/tttbots2/roles/`. Verify each is registered
  through one consistent factory (`sv_rolebuilder.lua`) so adding a new
  role is one file plus one entry, not edits to includeServer.

### 4.6 Net handlers

- Several handlers (`createlovers.lua` line 154/169, `cursedimmolate.lua`
  line 100, `gundealerdeliver.lua` line 80) are server-side `net.Receive`
  blocks **inside behavior files**. This couples networking to behaviors
  and makes it hard to audit security in one place. Move all
  `util.AddNetworkString` + `net.Receive` for cross-realm comms into
  `sv_miscnetwork.lua` or per-role `*_net.lua` files.

### 4.7 Error tracker

- `sh_errortracker.lua` is loaded first, which is correct. Make sure the
  16 `ErrorNoHaltWithStack` callsites all funnel into it (a quick grep
  shows several still call directly). The point of having a tracker is
  to centralise.

---

## 5. Quick-Win Checklist (do these first)

1. Delete `lua/tttbots2/lib/sv_chatGPT.lua.bak` and add `"*.bak"` to
   `addon.json` ignore list.
2. Remove the duplicate `include` of `sv_debug.lua` and `sh_botlib.lua`
   in `sh_tttbots2.lua`.
3. Delete the dead `bot.components.Inventory = self` line in
   `sv_inventory.lua` (and `Base = self` in `meta_base.lua` if you keep
   it shipping).
4. Whitelist allowed cvars in `TTTBots_RequestCvarUpdate`.
5. Replace `net.WriteTable` with compressed JSON in the five callsites.
6. Convert all five LLM adapters to use
   `TTTBots.Providers.BuildRequestBody`.
7. Gate the top-20 `print(` callsites behind `lib.GetDebugFor(...)`.
8. Rename inner-loop `i` shadow in the master tick.
9. Move the four `--TODO: Move to botlib` helpers in `sv_locomotor.lua`
   to `sh_botlib.lua`.
10. Add `meta_defs.lua` to `addon.json` ignore.

Estimated total effort: **half a day**. Estimated impact: removes the
biggest source of confusion for new contributors, plugs one real
security hole, and measurably reduces serialisation cost.

---

## 6. Medium-Term Roadmap

| Theme | Action | Effort |
|---|---|---|
| Logger | Introduce `TTTBots.Log(level, fmt, ...)` and route every `print` through it | 1 day |
| Coordinator registry | Refactor `sv_*coordinator.lua` to register into one table | 1 day |
| Player cache | Replace 115 `player.GetAll()` calls with `TTTBots._tickPlayers` | 0.5 day |
| Net hygiene | Centralise all `util.AddNetworkString` in one file; audit each receiver for length caps | 1 day |
| Locomotor split | Break the 2176-line file into 4-5 modules behind the same `BotLocomotor` table | 1-2 days |
| Provider deprecation | Mark legacy `SendRequest` deprecated with one-shot warning | 0.5 day |
| Timer registry | Wrap `timer.Create` so all bot timers can be wiped on `Reload` | 0.5 day |

---

## 7. Things That Are Already Right

To balance the criticism — these should be preserved across any refactor:

- `sv_providers.lua` rate-limiter, cost tracker, priority bypass, and
  admin dashboard are well-designed.
- The hibernation-aware boot in `sh_tttbots2.lua` (Think+InitialSpawn)
  is documented exhaustively and shows real production scars.
- `safeInclude(path)` pattern in `sh_botlib.lua` lets a single broken
  component fail loudly without taking down the whole addon.
- LuaLS annotations in `meta_defs.lua` are thorough and aid IDE work.
- The behavior-tree `STATUS.RUNNING/SUCCESS/FAILURE` contract with
  `OnEnd` cleanup is canonical and easy to reason about.
- `TTTBots.Behaviors.GetState(bot, name)` provides per-bot per-behavior
  scratch storage cleanly — encourage every behavior to use it instead
  of stuffing fields onto the bot directly.
- Component `ThinkRate` system + adaptive multipliers + emergency
  escalation gives strong runtime headroom without changing code.
- Dedicated docs folder under `docs/Pre-Integration Analysis/` with
  per-role analyses is exemplary; keep that practice for new roles.

---

## 8. Suggested Next Steps

1. **Open issues** for items 1-10 in §5; tag them `good first issue`.
2. **Add a CONTRIBUTING note** about the `print` → logger convention so new
   PRs don't add to the count.
3. **Wire a CI step** (GitHub Actions running `luacheck` with a project
   `.luacheckrc`) to catch unused locals, shadowed `i`, and globals
   sneaking in. The .vscode settings folder suggests local linting already
   exists; just promote it.
4. After §5 is done, plan §6 in two milestones: 1.4 (logger + coordinator
   registry + player cache) and 1.5 (locomotor split + timer registry +
   `SendRequest` removal).
