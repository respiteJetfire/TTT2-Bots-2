# Priest Role — TTT2 Bots Integration Analysis

> **Date:** 2026-03-25  
> **Addon:** `[TTT2] Priest [ROLE]` (Workshop ID: 1789489722)  
> **Scope:** Full analysis of the Priest role addon, existing TTT2-Bots-2 priest support, bugs, gaps, and implementation strategies for deep bot integration.

---

## Table of Contents

1. [Priest Role Mechanics Summary](#1-priest-role-mechanics-summary)
2. [Current Bot Implementation Status](#2-current-bot-implementation-status)
3. [Bug Report](#3-bug-report)
4. [Gap Analysis](#4-gap-analysis)
5. [Implementation Strategy](#5-implementation-strategy)
6. [Checklist](#6-checklist)
7. [File Map](#7-file-map)

---

## 1. Priest Role Mechanics Summary

### 1.1 Priest (the converter)

| Property | Value |
|---|---|
| **Team** | `TEAM_INNOCENT` |
| **Base Role** | `ROLE_INNOCENT` (set via `roles.SetBaseRole`) |
| **Color** | `Color(185, 210, 95, 255)` (yellow-green) |
| **Abbreviation** | `pri` |
| **Unknown Team** | `true` — role is hidden like other innocents |
| **Prevent Find Credits** | `true` |
| **Prevent Kill Credits** | `true` |
| **Prevent Win** | `false` — participates in normal innocent win condition |
| **Shop** | `SHOP_DISABLED` — no shop access |
| **Credits** | 0 |
| **Min Players** | 7 |
| **Maximum** | 1 per round |
| **Loadout Weapon** | `weapon_ttt2_holydeagle` (Holy Deagle — a role conversion deagle) |
| **Loadout Armor** | +10 armor points on role assignment |
| **Win Condition** | Wins with innocents — standard innocent team victory |

### 1.2 The Brotherhood System (`PRIEST_DATA`)

The Priest's core mechanic is a **brotherhood** — a group of confirmed innocent players the Priest builds by shooting them with the Holy Deagle. The brotherhood provides:

- **Mutual identification:** Brotherhood members see each other in the scoreboard with a "Brotherhood" column (yes/no)
- **Target ID overlay:** Brotherhood members see a "PLAYER IS IN BROTHERHOOD" label and icon when looking at other brothers
- **Status icon:** Brotherhood members get a HUD status icon (`ttt2_role_priest_brotherhood`)
- **Death tracking:** When a brother dies, they are removed from the brotherhood and all brothers are notified
- **Round reset:** Brotherhood is cleared at the end of each round

**Brotherhood data structure** (`PRIEST_DATA.brotherhood`):
- Server: `table` keyed by `SteamID64` (or `EntIndex` for bots) → `true`
- Client: Same structure, synced via net messages
- The Priest themselves are automatically added to the brotherhood on role assignment (`GiveRoleLoadout` calls `PRIEST_DATA:AddToBrotherhood(nil, ply)`)

### 1.3 Holy Deagle (`weapon_ttt2_holydeagle`)

| Property | Value |
|---|---|
| **Base** | `weapon_tttbase` |
| **Slot** | 7 (WEAPON_EXTRA) |
| **Clip** | 1 round, no reserve ammo |
| **Damage** | 0 (damage is intercepted and set to 0 by `ScalePlayerDamage` hook) |
| **Recharge (hit)** | Configurable via `ttt_pri_refill_time` (default 45s) |
| **Recharge (miss)** | Configurable via `ttt_pri_refill_time_missed` (default 5s) |
| **Allow Drop** | `false` — drops are auto-removed |
| **Not Buyable** | `true` — given as role loadout only |
| **HoldType** | `revolver` |
| **Model** | Desert Eagle (CS:S model) |
| **Sound** | `Weapon_Deagle.Single` |
| **Cone** | `0.00001` (virtually perfect accuracy) |

### 1.4 Holy Deagle Outcomes — `PRIEST_DATA:ShootBrotherhood(ply, attacker)`

This is the core decision logic when the Holy Deagle hits a player. The outcomes depend on the target's role and team:

| Target Condition | Outcome | Effect on Priest | Recharge Time |
|---|---|---|---|
| **Innocent team (non-detective, non-priest)** | ✅ **Added to brotherhood** | Message: "player was added" | `ttt_pri_refill_time` (45s) |
| **Unknown role (`ROLE_UNKNOWN`)** | ✅ **Added to brotherhood** | Message: "player was added" | `ttt_pri_refill_time` (45s) |
| **Detective (base role)** | ❌ **Deals damage to detective** | `ttt_pri_damage_dete` damage (default 30) | `ttt_pri_refill_time` (45s) |
| **Priest** | ❌ **Nothing happens** | Message: "Can't add a priest" | `ttt_pri_refill_time` (45s) |
| **Infected team** | ☠️ **250 damage to target** | Kills the infected | `ttt_pri_refill_time` (45s) |
| **Necromancer** | ☠️ **250 damage to target** | Kills the necromancer | `ttt_pri_refill_time` (45s) |
| **Sidekick** | ☠️ **250 damage to target** | Kills the sidekick | `ttt_pri_refill_time` (45s) |
| **Marker** | ⚠️ **Deals `ttt_pri_damage_marker` damage + marks brotherhood** | All brothers become marked via `MARKER_DATA:SetMarkedPlayer()` | `ttt_pri_refill_time` (45s) |
| **Any other evil role** | 💀 **250 damage to PRIEST** | **The priest dies** | N/A |

**Critical behavioral insight:** The Holy Deagle is a **high-risk, high-reward tool**. Shooting the wrong target (any evil role not in the special-case list) kills the Priest. This means bots MUST exercise caution and target selection intelligence.

### 1.5 Brotherhood Role Conversion Cascades

When the Priest's own role changes, the entire brotherhood can be converted:

| Priest Role Change | Brotherhood Effect |
|---|---|
| **Priest → Sidekick** (Jackal conversion) | All brothers become Sidekicks via `AddSidekick()` |
| **Priest → Zombie** (Necromancer revive) | All brothers become Zombies via `AddZombie()` |
| **Priest dies while Infected** (Infected kills priest) | All brothers become Infected via hook `TTT2InfectedAddGroup` |

These cascades are handled by hooks on `TTT2UpdateSubrole` and `TTT2InfectedAddGroup`.

### 1.6 ConVars

| ConVar | Default | Description |
|---|---|---|
| `ttt_pri_refill_time` | 45 | Seconds to recharge Holy Deagle after hitting a player |
| `ttt_pri_refill_time_missed` | 5 | Seconds to recharge Holy Deagle after missing |
| `ttt_pri_damage_dete` | 30 | Damage dealt to detectives when shot |
| `ttt_pri_damage_marker` | 30 | Damage dealt to markers when shot |
| `ttt_pri_show_messages` | 1 | Show brotherhood status messages (1=on, 0=off) |

---

## 2. Current Bot Implementation Status

### 2.1 What Exists

**File:** `lua/tttbots2/roles/priest.lua` (20 lines)

The current implementation uses the `DetectiveLike` RoleBuilder preset:

```lua
local priest = TTTBots.RoleBuilder.DetectiveLike("priest")
priest:SetCanHaveRadar(false)
priest:SetAutoSwitch(true)
priest:SetBTree(bTree)
TTTBots.Roles.RegisterRole(priest)
```

**RoleData flags inherited from `DetectiveLike`:**
- ✅ `TEAM_INNOCENT`
- ✅ `DefusesC4 = true`
- ✅ `AppearsPolice = true` — **WRONG:** Priest is NOT a detective-like role, it's `unknownTeam = true`
- ✅ `CanHaveRadar = false` (overridden)
- ✅ `UsesSuspicion = true`
- ✅ `CanCoordinateInnocent = true`

**Behavior Tree:**
```lua
local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _bh.CreateSidekick,   -- ← WRONG: Priest doesn't have a Sidekick Deagle
    _prior.Restore,
    _bh.Stalk,            -- ← WRONG: Priest is innocent, shouldn't stalk
    _prior.Minge,
    _prior.Investigate,
    _prior.Patrol
}
```

**Inventory support:** The `sv_inventory.lua` component already has `GetPriestGun()` and `EquipPriestGun()` methods that correctly access `weapon_ttt2_holydeagle` and check `Clip1() > 0`.

**Holy Deagle refill for bots:** The `createdeputy.lua` file contains a `DEAGLE_REFILL_CONFIG` table and `EntityFireBullets` hook that handles bot-side deagle clip refills. **However, `weapon_ttt2_holydeagle` is NOT in this config table.** The Holy Deagle's refill is handled server-side by its own timer system in the weapon code (`ttt2_priest_refill_holy_deagle_*` timers), which should work for bots without client-side net messages.

### 2.2 What's Missing

| Component | Status | Impact |
|---|---|---|
| **Holy Deagle behavior** | ❌ Missing | No `CreateBrother` / `PriestConvert` behavior exists. The bot never uses the Holy Deagle to build the brotherhood |
| **Brotherhood awareness** | ❌ Missing | Bot doesn't know who is in its brotherhood or use this information strategically |
| **Target selection intelligence** | ❌ Missing | No logic to choose safe (innocent-looking) targets or avoid dangerous (evil) targets |
| **Role misclassification** | 🔴 Wrong | `DetectiveLike` preset sets `AppearsPolice = true`, but the Priest is a hidden role with `unknownTeam = true` |
| **Wrong behavior tree** | 🔴 Wrong | Tree includes `CreateSidekick` (Priest has no sidekick deagle) and `Stalk` (Priest is innocent, doesn't stalk) |
| **No role description** | ❌ Missing | `SetRoleDescription()` never called — LLM prompt shows placeholder text |
| **No brotherhood protection** | ❌ Missing | No behavior to protect or avoid shooting confirmed brothers |
| **No Holy Deagle recharge awareness** | ❌ Missing | No status tracking for when the deagle is ready to fire again |
| **Chatter events** | ❌ Missing | No priest-specific chatter events (converting, brother died, etc.) |
| **Locale lines** | ❌ Missing | No localized chat strings for priest behaviors |
| **Risk assessment** | ❌ Missing | No logic to evaluate whether a target is safe to shoot (could kill the priest if evil) |

---

## 3. Bug Report

### BUG-1: Priest RoleData Uses Wrong Archetype (DetectiveLike)

**Severity:** 🔴 Critical  
**Location:** `roles/priest.lua`

The Priest is registered via `TTTBots.RoleBuilder.DetectiveLike("priest")`, which sets:
- `AppearsPolice = true` — **Wrong.** The Priest is a hidden innocent role (`unknownTeam = true`). It does NOT appear as a detective or police role. Other bots may incorrectly trust the Priest as a confirmed detective.
- `DefaultTrees.detective` behavior tree (overridden by custom tree, so this is less impactful).

**Result:** Bots treat the Priest as a known-good detective, which undermines the role's hidden nature. The Priest should behave like an `InnocentLike` role with the added conversion mechanic.

### BUG-2: Behavior Tree Contains Incompatible Behaviors

**Severity:** 🔴 Critical  
**Location:** `roles/priest.lua` — behavior tree

The tree includes:
- `_bh.CreateSidekick` — The Priest does NOT have `weapon_ttt2_sidekickdeagle`. This behavior will always fail its `HasWeapon` check and waste a tick every frame.
- `_bh.Stalk` — The Priest is an innocent role. Stalking isolated players is traitor/evil behavior and makes no sense for the Priest.

**Missing from tree:**
- No `PriestConvert` / `CreateBrother` behavior to use the Holy Deagle
- No `_prior.Investigate` (wait — it IS present, good)
- No `_prior.Support` (Priest should support as an innocent)

**Result:** The Priest bot plays like a broken detective that tries to use a sidekick deagle it doesn't have, then stalks players like a traitor. It never uses its Holy Deagle.

### BUG-3: Holy Deagle Refill Not Handled for Bots (Partial)

**Severity:** 🟡 Medium  
**Location:** `weapon_ttt2_holydeagle.lua` (server refill timers), `createdeputy.lua` (bot deagle refill system)

The Holy Deagle's refill uses **server-side timers** (`ttt2_priest_refill_holy_deagle_*`) tied to the weapon's `EntIndex`. The refill icon/status is sent to the client via `ttt2_role_priest_recharge_icon` net message, which bots don't process (no client realm).

**However**, the actual clip refill (`wep:SetClip1(1)`) happens server-side via the timer, so **bots DO get their ammo back**. The missing part is:
- Bot has no awareness of WHEN the deagle will be ready (no client-side `PRIEST_DATA.local_priest.time` tracking)
- The `createdeputy.lua` `DEAGLE_REFILL_CONFIG` does NOT include `weapon_ttt2_holydeagle`, so the backup bot-side refill-on-miss system doesn't cover it

**Mitigation:** The weapon's own server-side timer handles refill correctly. The bot just needs to check `Clip1() > 0` before attempting to use it (which `GetPriestGun()` already does).

### BUG-4: No SetRoleDescription for LLM Prompts

**Severity:** 🟢 Low (quality)  
**Location:** `roles/priest.lua`

`SetRoleDescription()` is never called. The LLM prompt system shows: *"No description available. Say that Callum needs to add a description for this role."*

---

## 4. Gap Analysis

### 4.1 Behavior Gaps

| Gap | Priority | Comparable Implementation |
|---|---|---|
| **PriestConvert behavior** — Use Holy Deagle on innocent players to build brotherhood. Must select targets wisely (innocent-looking, avoid evil roles) | P0 | `behaviors/createdeputy.lua` (pattern), `behaviors/createmedic.lua` (pattern) — uses `RegisterRoleWeapon` factory |
| **Target risk assessment** — Before shooting, evaluate likelihood target is innocent vs evil. Shooting evil = priest death | P0 | New concept — combine with suspicion system |
| **Brotherhood tracking** — Track who is in the brotherhood, use this for ally confirmation and coordination | P1 | `PRIEST_DATA:IsBrother()` / `PRIEST_DATA:GetBrotherhood()` already exist server-side |
| **Brotherhood protection** — Avoid friendly fire on confirmed brothers, prefer patrolling near brothers | P2 | `behaviors/protecthost.lua` (patrol-near pattern) |
| **Recharge awareness** — Know when Holy Deagle is ready (check `Clip1() > 0`) | P1 | Already handled by `GetPriestGun()` returning nil when clip is empty |

### 4.2 Strategic Intelligence Gaps

| Gap | Priority |
|---|---|
| **Suspicion-based target selection** — Priest should target players with LOW suspicion (likely innocent). Shooting high-suspicion players risks death | P0 |
| **Brotherhood size awareness** — Early game: aggressively convert. Late game: use confirmed brothers for information | P1 |
| **Witness management** — Convert players when few witnesses are around (the Priest role is hidden) | P1 |
| **Detective avoidance** — Never shoot detectives (wastes a shot and damages them). Bot should know detective roles | P1 |
| **Evil role avoidance** — Never shoot known/suspected evil players (kills the priest). Use suspicion data | P0 |
| **Round phase awareness** — Convert early, fight late. Brotherhood is most valuable when built early | P1 |
| **Post-conversion behavior** — After building brotherhood, shift to standard innocent behavior (investigate, patrol) | P2 |

### 4.3 Chatter/Comms Gaps

| Gap | Priority |
|---|---|
| **PriestConverting** — "Come here, I need to check something..." / "Trust me, this will help us" | P1 |
| **PriestConvertSuccess** — "Welcome to the brotherhood" / "You're one of us now" | P1 |
| **PriestBrotherDied** — "We lost a brother..." / "One of ours is down" | P2 |
| **PriestDetectiveShot** — Reacting to accidentally shooting a detective | P2 |
| **PriestEvilKill** — Celebrating killing an infected/necromancer/sidekick | P2 |
| **PriestDying** — Last words when shot an evil role and is about to die | P3 |
| **PriestBrotherhoodFull** — Brotherhood is large, feeling confident | P3 |

### 4.4 Integration with Existing Systems

| System | Integration Need |
|---|---|
| **Suspicion system** | Priest should LOWER suspicion of brotherhood members (confirmed innocents) |
| **Morality system** | Brotherhood members should be marked as confirmed allies |
| **Evidence system** | Brotherhood deaths should trigger KOS on suspects |
| **Coordination** | Brotherhood members should coordinate like detective-confirmed innocents |

---

## 5. Implementation Strategy

### Phase 1: Core Functionality (P0) — Make It Work

#### 5.1 Fix Priest RoleData — Switch from DetectiveLike to InnocentLike

The Priest should use `InnocentLike` as its base archetype, NOT `DetectiveLike`:

```
- Switch from TTTBots.RoleBuilder.DetectiveLike("priest") to TTTBots.RoleBuilder.InnocentLike("priest")
- Remove AppearsPolice (inherited from DetectiveLike)
- Keep CanHaveRadar = false
- Set AutoSwitch = true (keep existing)
- Add SetRoleDescription() with accurate description
- Set AlliedTeams = { [TEAM_INNOCENT] = true }
- Override with custom bTree (see 5.3)
```

**Why InnocentLike:** The Priest is a hidden innocent role. It uses the suspicion system, can hide, can snipe, defuses C4, and has `unknownTeam = true`. This exactly matches the `InnocentLike` archetype.

#### 5.2 Create PriestConvert Behavior (`behaviors/priestconvert.lua`)

Use the `RegisterRoleWeapon` factory pattern (same as `CreateDeputy`, `CreateSidekick`, `CreateMedic`):

```
TTTBots.Behaviors.RegisterRoleWeapon({
    name         = "PriestConvert",
    description  = "Use the Holy Deagle to convert a player into the brotherhood.",
    interruptible = true,
    stateKey     = "PriestTarget",
    getWeaponFn  = function(inv) return inv:GetPriestGun() end,
    equipFn      = function(inv) return inv:EquipPriestGun() end,
    findTargetFn = <custom safe target finder>,
    engageDistance = 1500,
    witnessThreshold = 2,
    startChance  = 25,
    isConversion = true,
    clipEmptyFails = true,
    chatterEvent = "PriestConverting",
    chatterTeamOnly = true,
})
```

**Key difference from other deagle behaviors:** The Priest's `findTargetFn` must be **extremely selective** because shooting the wrong target kills the Priest. The function should:

1. Get all alive, visible players within range
2. Filter OUT:
   - Players already in the brotherhood (`PRIEST_DATA:IsBrother(ply)`)
   - Players the bot knows are detectives (base role DETECTIVE — shooting them wastes a shot and deals damage)
   - Players the bot knows are evil (KOS'd, high suspicion, witnessed killing)
   - Players with the Priest role (can't add priests)
   - The bot itself
3. Prefer:
   - Players with LOW suspicion (likely innocent)
   - Isolated players (fewer witnesses to the conversion)
   - Players the bot has positive interactions with (defended them, patrolled with them)
4. Return the best candidate or nil if no safe target exists

```lua
local function FindSafeBrotherhoodTarget(bot)
    local candidates = {}
    local allies = TTTBots.Roles.GetAllies(bot)
    local nonAllies = TTTBots.Roles.GetNonAllies(bot)

    for _, ply in pairs(player.GetAll()) do
        if not IsValid(ply) or ply == bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end

        -- Skip players already in brotherhood
        if PRIEST_DATA and PRIEST_DATA:IsBrother(ply) then continue end

        -- Skip known detectives (shooting them wastes a shot + deals damage)
        if ply:GetBaseRole() == ROLE_DETECTIVE then continue end

        -- Skip known Priests
        if ply:GetSubRole() == ROLE_PRIEST then continue end

        -- Skip players on the bot's KOS list or with very high suspicion
        local morality = bot:BotMorality()
        if morality then
            local suspicion = morality:GetSuspicion(ply)
            if suspicion and suspicion > 0.6 then continue end  -- High suspicion = risky
        end

        -- Skip players the bot has witnessed doing evil things
        local evidence = bot:BotEvidence()
        if evidence and evidence:IsKOS(ply) then continue end

        -- Score: prefer low-suspicion, close, isolated players
        local dist = bot:GetPos():Distance(ply:GetPos())
        local score = 1000 - dist
        if morality then
            local suspicion = morality:GetSuspicion(ply)
            if suspicion then
                score = score - (suspicion * 500)  -- Penalize suspicious players
            end
        end

        table.insert(candidates, { ply = ply, score = score })
    end

    if #candidates == 0 then return nil end

    table.sort(candidates, function(a, b) return a.score > b.score end)
    return candidates[1].ply
end
```

#### 5.3 Fix Behavior Tree

Replace the current broken tree with an appropriate innocent + conversion tree:

```
Priest bTree:
    _prior.Chatter,
    _prior.FightBack,
    _bh.PriestConvert,      -- Use Holy Deagle to build brotherhood (P0 behavior)
    _prior.Requests,
    _prior.Support,          -- Standard innocent support (defib allies, etc.)
    _bh.Defuse,              -- Defuse C4 like a good innocent
    _prior.Restore,          -- Heal at health stations
    _bh.Interact,            -- Interact with map elements
    _prior.Investigate,      -- Investigate bodies and gunshots
    _prior.Minge,            -- Standard minge behaviors
    _bh.Decrowd,             -- Avoid crowded areas
    _prior.Patrol            -- Patrol the map
```

**Key:** `PriestConvert` is placed HIGH in the tree (after FightBack) so the bot prioritizes building the brotherhood in the early/mid game. The `RegisterRoleWeapon` factory's `isConversion = true` flag will boost the start chance in early game phases.

#### 5.4 Add Role Description for LLM Prompts

```lua
local roleDescription = "You are the Priest, a hidden innocent role. "
    .. "You have a Holy Deagle that can confirm innocent players by adding them to your brotherhood. "
    .. "Brotherhood members can see each other in the scoreboard and through target ID overlays. "
    .. "Be careful: shooting a detective wastes your shot and damages them, "
    .. "shooting infected/necromancer/sidekick kills them (good!), "
    .. "but shooting any other evil role KILLS YOU. Only shoot players you believe are innocent!"
```

### Phase 2: Intelligence & Awareness (P1)

#### 5.5 Brotherhood Tracking Integration

Add server-side hooks to integrate brotherhood awareness into the bot's morality/suspicion system:

```
Hook: "ttt2_role_priest_new_brother" (or TTT2UpdateSubrole / custom)
- When a player is added to brotherhood, mark them as "confirmed innocent" in the bot's morality
- Lower suspicion to 0 for all brotherhood members
- Update morality for ALL bots that are in the brotherhood (they know each other)

Hook: PlayerDeath for brotherhood members
- When a brother dies, increase suspicion of nearby non-brothers
- Trigger investigation behavior toward the brother's death location
```

**Implementation approach:** Since `PRIEST_DATA:AddToBrotherhood()` broadcasts a net message, we can hook into the server-side `AddToBrotherhood` function to notify bot components:

```lua
-- In priest role file or a new lib file
hook.Add("PlayerDeath", "TTTBots_Priest_BrotherDied", function(victim)
    if not PRIEST_DATA then return end
    if not PRIEST_DATA:IsBrother(victim) then return end

    -- Notify all bot brothers about the death
    for _, bot in pairs(player.GetAll()) do
        if not bot:IsBot() or not IsValid(bot) then continue end
        if not PRIEST_DATA:IsBrother(bot) then continue end

        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("PriestBrotherDied", { player = victim:Nick() }, true)
        end
    end
end)
```

#### 5.6 Round Phase-Aware Conversion Strategy

Integrate with `RoundAwareness` component:

| Phase | Conversion Strategy |
|---|---|
| **EARLY** | Aggressively seek targets to convert. `startChance` boosted to ~90% by `isConversion` flag. Target nearby players with low suspicion. |
| **MID** | Continue converting but be more selective. Prefer isolated targets. Start using brotherhood info for coordination. |
| **LATE** | Stop converting, focus on combat and investigation. Brotherhood should already be built. |
| **OVERTIME** | Pure survival mode. Use brotherhood for coordination only. |

This is largely handled by the `RegisterRoleWeapon` factory's built-in phase-aware `isConversion` boost, but the `findTargetFn` should also factor in phase:
- EARLY: wider target acceptance (lower suspicion threshold for rejection)
- LATE/OVERTIME: much stricter target acceptance (only shoot very-low-suspicion players)

#### 5.7 Detective/Evil Role Avoidance Logic

The `findTargetFn` must include robust avoidance:

```
1. NEVER target players with base role DETECTIVE
   - The bot's evidence/morality should track known detectives
   - Use ply:GetBaseRole() == ROLE_DETECTIVE server-side

2. NEVER target KOS'd players
   - If the bot has KOS'd someone, they're suspected evil → shooting = death

3. Suspicion threshold
   - Only target players with suspicion < 0.4 (low suspicion = likely innocent)
   - In EARLY game, threshold can be relaxed to 0.5
   - In LATE game, threshold should be strict at 0.3

4. Witnessed behavior
   - Skip players the bot has seen committing hostile acts
   - Skip players other bots have called out
```

#### 5.8 Holy Deagle Recharge Tracking

The bot needs to know when the Holy Deagle is recharged. Since `GetPriestGun()` already checks `Clip1() > 0`, the `RegisterRoleWeapon` factory's `clipEmptyFails = true` config handles this:
- When clip is empty, the behavior returns `STATUS.FAILURE`
- The behavior tree moves on to other behaviors
- Next tick, `Validate()` calls `HasWeapon()` which calls `GetPriestGun()` → returns nil if clip is 0
- The behavior won't activate until the clip is refilled by the weapon's server-side timer

**No additional tracking needed** — the existing infrastructure handles this correctly.

### Phase 3: Chatter & Immersion (P2)

#### 5.9 Register Chatter Events

Add to chatter events configuration (chancesOf100):

```lua
PriestConverting = 70,        -- About to shoot someone with Holy Deagle
PriestConvertSuccess = 80,    -- Successfully added someone to brotherhood
PriestBrotherDied = 85,       -- A brotherhood member died
PriestDetectiveShot = 60,     -- Accidentally shot a detective
PriestEvilKill = 90,          -- Killed an infected/necromancer/sidekick
PriestDying = 95,             -- About to die from shooting evil role
PriestBrotherhoodStrong = 50, -- Brotherhood has 3+ members, feeling confident
```

#### 5.10 Add Locale Lines (`locale/en/sh_chats.lua`)

```lua
RegisterCategory("PriestConverting", P.MODERATE, "Priest bot is about to shoot someone with Holy Deagle to add to brotherhood")
-- Default: "I need to verify something about {{player}}..."
-- Casual: "Hey {{player}}, hold still for a sec..."
-- Nice: "Trust me {{player}}, this is for the best..."
-- Stoic: "{{player}}. Stand still."
-- Hothead: "Don't move {{player}}! I'm doing something important!"
-- Bad: "lol shooting {{player}} with my special gun"
-- Teamer: "Adding {{player}} to our group, let's go team!"
-- Tryhard: "Confirming {{player}} via holy deagle, building our network"
-- Sus: "I just need to... check {{player}} real quick..."
-- Dumb: "pew pew {{player}} is my friend now"

RegisterCategory("PriestBrotherDied", P.IMPORTANT, "A brotherhood member has died")
-- Default: "We lost one of our own..."
-- Casual: "Damn, one of the brothers is dead"
-- Hothead: "WHO KILLED MY BROTHER?!"

RegisterCategory("PriestConvertSuccess", P.MODERATE, "Successfully added someone to the brotherhood")
-- Default: "Welcome to the fold."
-- Casual: "Nice, one more on our side"
```

#### 5.11 Brotherhood Death Reaction Hooks

Wire up chatter events to priest-specific game events:

```lua
-- When a brother dies, priest bots in the brotherhood react
hook.Add("PlayerDeath", "TTTBots_Priest_BrotherDeathChatter", function(victim, inflictor, attacker)
    if not PRIEST_DATA or not PRIEST_DATA:IsBrother(victim) then return end
    -- Notify priest bots
end)

-- When the priest successfully converts (listen to ShootBrotherhood result)
-- This needs to be hooked into the PRIEST_DATA:AddToBrotherhood function
```

### Phase 4: Polish & Advanced (P3)

#### 5.12 Brotherhood Coordination

When the brotherhood has 2+ members (including the priest), enable enhanced coordination:

- Brotherhood bots share suspicion data (if one brother KOS's someone, all brothers respect it)
- Brotherhood bots prefer patrolling near each other (safety in numbers)
- Brotherhood bots prioritize investigating deaths of other brothers

#### 5.13 Cascade Awareness

The Priest bot should be aware of the role-conversion cascades:

- **Avoid Jackal:** If the priest suspects someone is a Jackal, avoid them at all costs (being converted to Sidekick converts the whole brotherhood)
- **Avoid Necromancer corpse areas:** Don't die near Necromancers (being revived as zombie converts brotherhood)
- **Avoid Infected hosts:** Being converted to infected converts the brotherhood

This is advanced and requires deep integration with the suspicion/threat assessment systems.

#### 5.14 Post-Conversion Feedback

After shooting a player with the Holy Deagle, the bot should observe the outcome and adjust:

| Outcome | Bot Reaction |
|---|---|
| Player added to brotherhood | Lower suspicion of target to 0, mark as confirmed |
| Detective damaged | Remember this player is a detective, never target again |
| Evil player killed | Mark the kill, feel validated |
| Priest died (shot evil) | N/A (bot is dead) — but other brotherhood bots should react |

This requires hooking into the `ScalePlayerDamage` / `ShootBrotherhood` results, which happen server-side after the deagle fires.

#### 5.15 Holy Deagle Outcome Detection for Bots

Since the `ShootBrotherhood` function handles all outcomes server-side, we need a way for the bot to learn what happened:

**Approach:** Add a post-fire callback in the `PriestConvert` behavior's `onFireFn`:

```lua
onFireFn = function(bot, target)
    -- After firing, wait briefly and check if target is in brotherhood
    timer.Simple(0.3, function()
        if not IsValid(bot) or not IsValid(target) then return end
        if PRIEST_DATA:IsBrother(target) then
            -- Success! Lower suspicion, fire chatter
            local morality = bot:BotMorality()
            if morality then morality:SetSuspicion(target, 0) end
            local chatter = bot:BotChatter()
            if chatter then chatter:On("PriestConvertSuccess", { player = target:Nick() }, true) end
        elseif not lib.IsPlayerAlive(bot) then
            -- Priest died! (shot an evil role)
            -- Bot is dead, no action needed
        end
    end)
end
```

---

## 6. Checklist

### Phase 1: Core Functionality (P0)

- [ ] **TASK-1:** Rewrite `roles/priest.lua` — Switch from `DetectiveLike` to `InnocentLike`, add `SetRoleDescription()`, set correct flags (`AppearsPolice = false` implicit with InnocentLike), fix `AlliedTeams`
- [ ] **TASK-2:** Create `behaviors/priestconvert.lua` — Register via `RegisterRoleWeapon` factory with `getWeaponFn = inv:GetPriestGun()`, `equipFn = inv:EquipPriestGun()`, `isConversion = true`, `clipEmptyFails = true`
- [ ] **TASK-3:** Implement `FindSafeBrotherhoodTarget(bot)` — Target finder that filters out detectives, priests, brotherhood members, KOS'd players, and high-suspicion players. Score by inverse suspicion and distance
- [ ] **TASK-4:** Fix behavior tree — Replace broken tree (remove `CreateSidekick`, `Stalk`) with correct innocent + conversion tree: `Chatter → FightBack → PriestConvert → Requests → Support → Defuse → Restore → Interact → Investigate → Minge → Decrowd → Patrol`
- [ ] **TASK-5:** Test that the priest bot correctly equips Holy Deagle, approaches low-suspicion targets, and fires
- [ ] **TASK-6:** Test that the priest bot does NOT shoot detectives, KOS'd players, or high-suspicion players
- [ ] **TASK-7:** Test that the `clipEmptyFails` config correctly prevents the bot from trying to use the Holy Deagle while it's recharging

### Phase 2: Intelligence & Awareness (P1)

- [ ] **TASK-8:** Add brotherhood morality integration — When `PRIEST_DATA:AddToBrotherhood()` fires, update bot morality to mark the new brother as `suspicion = 0` / confirmed innocent for all bot brothers
- [ ] **TASK-9:** Add detective detection — `findTargetFn` must check `ply:GetBaseRole() == ROLE_DETECTIVE` and skip. Also skip `ply:GetSubRole() == ROLE_SNIFFER` (detective-like)
- [ ] **TASK-10:** Add round-phase-aware suspicion threshold — EARLY game: accept targets with suspicion < 0.5. MID: < 0.4. LATE: < 0.3. OVERTIME: don't convert at all
- [ ] **TASK-11:** Add post-fire outcome detection — After firing Holy Deagle, check if target joined brotherhood (success) or if priest died (shot evil). Update morality accordingly
- [ ] **TASK-12:** Add brotherhood death investigation hook — When a brother dies, priest bot prioritizes investigating the death location and suspects nearby players

### Phase 3: Chatter & Immersion (P2)

- [ ] **TASK-13:** Register priest chatter events in chatter events config — `PriestConverting`, `PriestConvertSuccess`, `PriestBrotherDied`, `PriestDetectiveShot`, `PriestEvilKill`, `PriestBrotherhoodStrong`
- [ ] **TASK-14:** Add locale lines in `locale/en/sh_chats.lua` — Full archetype coverage (Default, Casual, Nice, Stoic, Hothead, Bad, Teamer, Tryhard, Sus, Dumb) for all priest chatter events
- [ ] **TASK-15:** Wire up `PriestBrotherDied` chatter — Hook into `PlayerDeath` to detect brotherhood member deaths and fire chatter event for bot priest/brothers
- [ ] **TASK-16:** Wire up `PriestConvertSuccess` chatter — Fire after successful brotherhood conversion (detected via `onFireFn` timer check)
- [ ] **TASK-17:** Wire up `PriestEvilKill` chatter — Fire when Holy Deagle kills an infected/necromancer/sidekick (detected via target death after fire)

### Phase 4: Polish & Advanced (P3)

- [ ] **TASK-18:** Brotherhood coordination — Brotherhood bots share suspicion data, patrol near each other, investigate brother deaths together
- [ ] **TASK-19:** Cascade awareness — Priest bot avoids Jackal/Necromancer/Infected to prevent brotherhood cascade conversion
- [ ] **TASK-20:** Post-conversion feedback loop — Bot learns from Holy Deagle outcomes: detective shot → never target again, evil killed → feel validated, brother added → confirm innocent
- [ ] **TASK-21:** Brotherhood size-based strategy — Small brotherhood: convert aggressively. Large brotherhood (3+): shift to investigation/coordination. Full brotherhood: stop converting
- [ ] **TASK-22:** Witness management for conversion — Prefer converting when fewer non-brothers are watching (hidden role, avoid revealing the conversion mechanic)
- [ ] **TASK-23:** Add priest to `TTTBots.Roles.ValidateAllRoles()` cross-reference to verify alliance symmetry with other innocent roles

---

## 7. File Map

### Files to Modify

| File | Changes |
|---|---|
| `lua/tttbots2/roles/priest.lua` | **Complete rewrite**: Switch from `DetectiveLike` to `InnocentLike`, add `SetRoleDescription()`, replace behavior tree with correct innocent + conversion tree, add brotherhood-awareness hooks |

### New Files to Create

| File | Purpose |
|---|---|
| `lua/tttbots2/behaviors/priestconvert.lua` | `PriestConvert` behavior using `RegisterRoleWeapon` factory — Holy Deagle conversion with safe target selection, suspicion-based filtering, witness management |

### Existing Files That May Need Minor Changes

| File | Changes |
|---|---|
| `lua/tttbots2/components/chatter/sv_chatter_events.lua` | Add priest chatter event probabilities + hooks (brotherhood death, conversion success) |
| `lua/tttbots2/locale/en/sh_chats.lua` | Add locale line categories + archetype lines for priest events |

### Reference Files (patterns to follow)

| File | Pattern Used For |
|---|---|
| `roles/deputy.lua` | Innocent-side role with a deagle conversion mechanic + ally protection hooks |
| `roles/doctor.lua` | InnocentLike role with support behaviors and role description |
| `behaviors/createdeputy.lua` | `RegisterRoleWeapon` factory pattern for deagle behaviors + bot-side deagle refill handling |
| `behaviors/createmedic.lua` | `RegisterRoleWeapon` with `hasWeaponFn`/`equipDirectFn` pattern |
| `behaviors/createsidekick.lua` | `RegisterRoleWeapon` with `getWeaponFn`/`equipFn` pattern (via inventory component) |
| `behaviors/protecthost.lua` | Proximity-based escort/protection behavior (for brotherhood coordination) |
| `behaviors/meta_roleweapon.lua` | The factory implementation itself — understand all config options |
| `components/sv_inventory.lua` | Already has `GetPriestGun()` and `EquipPriestGun()` — no changes needed |
| `lib/sv_rolebuilder.lua` | `InnocentLike()` preset definition |

### External Addon Files (read-only reference)

| File | Purpose |
|---|---|
| `ttt2_priest_role_1789489722/lua/terrortown/entities/roles/priest/shared.lua` | Role definition, loadout, settings menu |
| `ttt2_priest_role_1789489722/lua/terrortown/autorun/shared/sh_priest_handler.lua` | `PRIEST_DATA` global — brotherhood system, `ShootBrotherhood()` logic, all server-side hooks |
| `ttt2_priest_role_1789489722/gamemodes/terrortown/entities/weapons/weapon_ttt2_holydeagle.lua` | Holy Deagle weapon — refill timers, `ScalePlayerDamage` hook, clip management |
| `ttt2_priest_role_1789489722/lua/terrortown/autorun/shared/sh_priest_sidebar.lua` | Status icon registration (client-only, informational) |
| `ttt2_priest_role_1789489722/lua/terrortown/events/brotherhood.lua` | Round event for brotherhood additions |

---

## Appendix A: Key Architectural Decisions

### A.1: Why InnocentLike Instead of DetectiveLike

The Priest has `unknownTeam = true` in its role definition, meaning other players cannot see the Priest's role. This is fundamentally different from detectives who are publicly known. Using `DetectiveLike` causes:
1. `AppearsPolice = true` — other bots wrongly treat the Priest as a known-good detective
2. Wrong default behavior tree (detective tree focuses on investigation and authority)
3. Wrong social dynamics (detective bots are trusted by all, Priest bots should earn trust through gameplay)

`InnocentLike` correctly models:
- Hidden role identity
- Uses suspicion system (since role is unknown, others still need to evaluate)
- Can hide and blend in
- Defuses C4 (good citizen behavior)
- No special authority or public trust

### A.2: Target Selection Strategy — The "Safe Shot" Problem

The Priest's Holy Deagle is unique among all role weapons because **shooting the wrong target kills the SHOOTER, not the target** (for most evil roles). This creates a fundamentally different target selection problem:

| Other Deagle Roles | Risk Model |
|---|---|
| Deputy Deagle | Shooting wrong target: target is converted to wrong team (recoverable) |
| Sidekick Deagle | Shooting wrong target: target becomes hostile sidekick (bad but you survive) |
| Slave Deagle | Shooting wrong target: nothing happens or target is wrong team |
| **Holy Deagle** | **Shooting wrong target: YOU DIE** |

This means the Priest's `findTargetFn` must be the **most conservative target finder** of any role deagle. The implementation should:

1. **Default to NOT shooting** — Unlike other deagles that try to convert anyone, the Priest should only shoot when highly confident
2. **Use the suspicion system as a safety net** — Only target players with suspicion below a strict threshold
3. **Leverage brotherhood intelligence** — Players already in the brotherhood are confirmed innocent; the Priest can use them to triangulate who else might be innocent (seen together, defended each other, etc.)
4. **Accept "no valid target" gracefully** — If no safe target exists, the behavior returns nil and the tree falls through to normal innocent behavior. This is fine — the Priest doesn't NEED to convert everyone.

### A.3: RegisterRoleWeapon Factory Suitability

The `RegisterRoleWeapon` factory in `meta_roleweapon.lua` is an excellent fit for the PriestConvert behavior because:

1. **Inventory integration** — `GetPriestGun()` and `EquipPriestGun()` already exist in `sv_inventory.lua`
2. **Clip-empty handling** — `clipEmptyFails = true` naturally handles the Holy Deagle's recharge mechanic
3. **Witness management** — `witnessThreshold` controls when the bot fires (hidden role should be cautious)
4. **Phase-aware conversion** — `isConversion = true` automatically boosts start chance in early game
5. **Chatter integration** — Built-in `chatterEvent` support for conversion-related chat
6. **Target validation** — `ValidateTarget` checks ensure the target is still alive and valid
7. **onFireFn callback** — Allows post-fire outcome detection (did the target join brotherhood? did the priest die?)

The only customization needed is the `findTargetFn` — everything else can be configured via the factory's options.

### A.4: Holy Deagle vs Other Deagles — Refill Mechanism Comparison

| Deagle | Refill Mechanism | Bot Handling |
|---|---|---|
| Deputy Deagle | Client-side net message → `ttt2_dep_deagle_refill` | `createdeputy.lua` has server-side `EntityFireBullets` hook for bots |
| Sidekick Deagle | Client-side net message → `ttt2_siki_deagle_refill` | `createdeputy.lua` has server-side `EntityFireBullets` hook for bots |
| Slave Deagle | Client-side net message → `ttt2_slave_deagle_refill` | `createdeputy.lua` has server-side `EntityFireBullets` hook for bots |
| **Holy Deagle** | **Server-side timer** (`ttt2_priest_refill_holy_deagle_*`) | **Already works for bots** — timer calls `wep:SetClip1(1)` server-side |

The Holy Deagle is unique in that its refill is entirely server-side, making it the most bot-friendly deagle. No additional refill handling is needed — the weapon's own code handles it. The bot just needs to check `Clip1() > 0` (via `GetPriestGun()`) before attempting to use it.

### A.5: Brotherhood Cascade Risk Assessment

The brotherhood cascade mechanic (entire brotherhood converts when priest's role changes) creates an interesting risk/reward dynamic that advanced bot integration could leverage:

**Risk factors the bot should eventually track:**
- How many players are in the brotherhood? (Higher count = more impactful cascade)
- Are there known Jackals alive? (Jackal → Sidekick cascade)
- Are there known Necromancers alive? (Necromancer → Zombie cascade via revive)
- Are there known Infected alive? (Infected → Infected cascade)

**For Phase 4+** — the Priest bot could adjust its behavior based on cascade risk:
- With a large brotherhood, play more defensively to avoid being converted
- With a small brotherhood, play more aggressively (less to lose)
- Avoid isolated areas if Jackal/Necromancer are suspected alive

This is a P3+ consideration and not needed for initial implementation.
