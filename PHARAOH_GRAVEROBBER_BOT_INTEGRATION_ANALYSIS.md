# Pharaoh & Graverobber Role — TTT2 Bots Integration Analysis

> **Date:** 2026-03-10
> **Scope:** Full analysis of the `ttt2_pharaoh_graverobber_role` addon, existing TTT2-Bots-2 support, bugs, gaps, and implementation strategies for deep bot integration.

---

## Table of Contents

1. [Role Mechanics Summary](#1-role-mechanics-summary)
2. [Current Bot Implementation Status](#2-current-bot-implementation-status)
3. [Bug Report](#3-bug-report)
4. [Gap Analysis](#4-gap-analysis)
5. [Implementation Strategy](#5-implementation-strategy)
6. [Detailed Implementation Plans](#6-detailed-implementation-plans)
7. [Chatter Integration](#7-chatter-integration)
8. [Morality & Suspicion Integration](#8-morality--suspicion-integration)
9. [Checklist](#9-checklist)
10. [File Map](#10-file-map)

---

## 1. Role Mechanics Summary

### 1.1 Pharaoh (Innocent Side)

| Property | Value |
|---|---|
| **Team** | `TEAM_INNOCENT` |
| **Base Role** | `ROLE_INNOCENT` (via `roles.SetBaseRole`) |
| **Abbreviation** | `pha` |
| **Color** | `Color(170, 180, 10, 255)` — golden yellow |
| **Unknown Team** | `true` — team is hidden from other players |
| **Prevent Win** | `false` — can win with innocents |
| **Min Players** | 6 |
| **Shop** | `SHOP_DISABLED` |
| **Credits** | 0 (no credit earning) |
| **Loadout Weapon** | `weapon_ttt_ankh` — given on role assignment |
| **Core Mechanic** | Place an Ankh on the ground; dying with a placed Ankh triggers auto-revival at the Ankh's position |
| **Ankh Healing** | Standing near own Ankh (< 100 units): heals both the Ankh entity and the Pharaoh player over time |
| **Spawn Protection** | On revival, receives a protective shield for `ttt_ankh_respawn_protection_time` seconds (default 4) |
| **Revival Health** | Respawns with 50 HP |
| **Anti-Suicide** | `CanPlayerSuicide` hook prevents revival if player used the `kill` command |

### 1.2 Graverobber (Traitor Side)

| Property | Value |
|---|---|
| **Team** | `TEAM_TRAITOR` |
| **Base Role** | `ROLE_TRAITOR` (via `roles.SetBaseRole`) |
| **Abbreviation** | `grav` |
| **Color** | `Color(200, 100, 60, 255)` — burnt orange |
| **Not Selectable** | `true` — can only be created when a Pharaoh places their Ankh |
| **Shop** | `SHOP_FALLBACK_TRAITOR` — full traitor shop access |
| **Credits** | 0 base, but earns credits for kills and dead players |
| **Traitor Buttons** | `traitorButton = 1` — can use traitor buttons |
| **Core Mechanic** | Find and convert the Pharaoh's Ankh to steal its revival power |
| **Reversion** | If all Ankhs are destroyed, Graverobbers revert to their previous role (`grav_prev_role`) |

### 1.3 Ankh Weapon (`weapon_ttt_ankh`)

| Property | Value |
|---|---|
| **Type** | `WEAPON_EXTRA` (slot 6) |
| **Not Buyable** | Given via role loadout only |
| **Allow Drop** | `false` — drops are auto-removed |
| **Primary/Secondary** | Both fire `AnkhStick()` — traces 100 units in front, places `ttt_ankh` entity |
| **Placement Rules** | Requires: (1) round active, (2) no existing ankh owned, (3) at least one traitor alive, (4) level ground (dot product ≤ 0.2 angle), (5) sufficient room (spawn point safe check) |
| **Side Effect** | First placement triggers `PHARAOH_HANDLER:SelectGraverobber()` — converts a random vanilla/base traitor into ROLE_GRAVEROBBER |

### 1.4 Ankh Entity (`ttt_ankh`)

| Property | Value |
|---|---|
| **Model** | `models/pharaohs_ankh/pharaohs_ankh/pharaohs_ankh.mdl` at scale 0.15 |
| **Health** | `ttt_ankh_health` (default 500 HP), damageable by any player |
| **Collision** | `COLLISION_GROUP_WEAPON`, welded to ground |
| **Use Type** | `CONTINUOUS_USE` — hold E to interact |
| **Conversion** | Graverobber/Pharaoh holds USE for `ttt_ankh_conversion_time` (default 6s) to transfer ownership |
| **Pickup** | Owner can pick up (key release after non-converting use) if `ttt_ankh_pharaoh_pickup` / `ttt_ankh_graverobber_pickup` allows it |
| **Healing Aura** | Owner within 100 units: ankh self-heals (0.1s if low HP, 0.5s normal) and heals owner (1.5s interval) |
| **Dynamic Light** | Glows in owner's role color; flickers when below 10% HP |
| **Fingerprints** | Tracks all players who interact; visible in body search |
| **Destruction** | When destroyed: plays explosion effect, notifies owner + all graverobbers, triggers `EVENT_ANKH_DESTROYED` |

### 1.5 PHARAOH_HANDLER — Core State Machine

The global `PHARAOH_HANDLER` table manages all ankh state. Key data structure:

```lua
PHARAOH_HANDLER.ankhs = {
    [original_owner_steamid64] = {
        current_owner_id = steamid64,  -- may differ if stolen by graverobber
        ankh = Entity,                 -- the ttt_ankh entity (nil if in inventory)
        health = number                -- preserved across pickup/placement cycles
    }
}
```

**Dual Ownership Model:** The key is always the Pharaoh who first placed the Ankh. `current_owner_id` updates when a Graverobber steals it. This allows tracking of theft, reconversion, and revival eligibility.

**Key Functions Used by Bots:**

| Function | Purpose |
|---|---|
| `PlayerOwnsAnAnkh(ply)` | Does this player own (original or current) any ankh? |
| `PlayerControlsAnAnkh(ply)` | Is this player the current controller of an ankh? |
| `PlayerIsOriginalOwnerOfThisAnkh(ply, ent)` | Is this player the pharaoh who first placed this specific ankh? |
| `PlayerCanReviveWithThisAnkhDataId(ply)` | Returns ankh data ID if player can revive, -1 otherwise |
| `CanPlaceAnkh(placer)` | Pre-flight: round active, no existing ankh, traitor alive? |
| `SelectGraverobber()` | Picks a random vanilla traitor → converts to graverobber |
| `TransferAnkhOwnership(ent, ply)` | Full ownership transfer with events, sounds, decals, wallhacks |
| `StartConversion(ent, ply)` | Begin the conversion process (sounds, status icons) |
| `CancelConversion(ent, ply)` | Abort conversion (stopped looking at ankh, released USE) |
| `SetClientCanConvAnkh(ply)` | Networked state: what ankh(s) can this player convert? |

### 1.6 ConVars

| ConVar | Default | Purpose |
|---|---|---|
| `ttt_ankh_health` | 500 | Ankh HP |
| `ttt_ankh_conversion_time` | 6 | Seconds to hold USE to convert |
| `ttt_ankh_respawn_time` | 10 | Seconds between death and ankh revival |
| `ttt_ankh_pharaoh_pickup` | 1 | Pharaoh can pick up their own placed ankh |
| `ttt_ankh_graverobber_pickup` | 0 | Graverobber can pick up their stolen ankh |
| `ttt_ankh_heal_ankh` | 1 | Ankh self-heals when owner is near |
| `ttt_ankh_heal_owner` | 1 | Ankh heals its owner when near |
| `ttt_ankh_light_up` | 1 | Ankh glows brighter when owner is near |
| `ttt_ankh_respawn_protection_time` | 4 | Seconds of invulnerability post-revival |

### 1.7 Event System

| Event | Trigger | Data |
|---|---|---|
| `EVENT_ANKH_CONVERSION` | Graverobber steals ankh | oldOwner, newOwner (nick, sid64, role, team) |
| `EVENT_ANKH_DESTROYED` | Ankh reduced to 0 HP | oldOwner, attacker |
| `EVENT_ANKH_REVIVE` | Player revives at ankh | owner (nick, sid64, role, team) |

### 1.8 Hooks

| Hook | Purpose |
|---|---|
| `TTT2GraverobberPreventSelection` | Allows other roles (e.g. Defective) to opt out of graverobber conversion |
| `TTT2PharaohPreventDamageToAnkh` | Prevents certain roles from damaging the ankh (anti-grief) |
| `CanPlayerSuicide` | Detects `kill` command to prevent suicide-triggered revival |

---

## 2. Current Bot Implementation Status

### 2.1 Role Definition — Pharaoh (`roles/pharaoh.lua`)

```lua
local pharaoh = TTTBots.RoleData.New("pharaoh")
pharaoh:SetDefusesC4(true)
pharaoh:SetTeam(TEAM_INNOCENT)
pharaoh:SetCanHide(true)
pharaoh:SetCanSnipe(true)
pharaoh:SetUsesSuspicion(true)
pharaoh:SetAlliedRoles({})
pharaoh:SetAlliedTeams({})
```

**Behavior Tree:**
```
Chatter → Requests → FightBack → PlantAnkh → CaptureAnkh → Support → Defuse →
Restore → Interact → Investigate → Minge → Decrowd → Patrol
```

**Assessment:** Basic registration is correct. The Pharaoh is properly set up as an innocent-team role with suspicion awareness. PlantAnkh and CaptureAnkh behaviors are included but have significant issues (see §3).

### 2.2 Role Definition — Graverobber (`roles/graverobber.lua`)

```lua
local graverobber = TTTBots.RoleData.New("graverobber")
graverobber:SetDefusesC4(false)
graverobber:SetPlantsC4(false)
graverobber:SetCanHaveRadar(true)
graverobber:SetCanCoordinate(true)
graverobber:SetStartsFights(true)
graverobber:SetTeam(TEAM_TRAITOR)
graverobber:SetUsesSuspicion(false)
graverobber:SetLovesTeammates(true)
```

**Behavior Tree:**
```
Chatter → FightBack → CaptureAnkh → Requests → Convert → Support →
Roledefib → PlantBomb → InvestigateCorpse → Restore → FollowPlan →
Interact → Minge → Investigate → Patrol
```

**Assessment:** Good overall shape. CaptureAnkh is correctly prioritized high. However, the Graverobber's behavior tree includes `PlantBomb` — this is correct since they are a traitor variant. Missing: ankh-proximity behaviors, ankh-defense behaviors, and tactical awareness of the ankh's position.

### 2.3 Behavior — PlantAnkh (`behaviors/plantankh.lua`)

**What it does:**
1. Validates the bot has `weapon_ttt_ankh` and no existing placed ankh
2. Equips the ankh weapon, looks down at current position, attacks (which calls `AnkhStick()`)
3. Has a fail counter with a 20-second cooldown timer to prevent infinite retry loops
4. Fires `PlacedAnkh` chatter event on success

**Assessment:** Functional but naive. See §3 for bugs and §4 for gaps.

### 2.4 Behavior — CaptureAnkh (`behaviors/captureankh.lua`)

**What it does:**
1. Finds the nearest `ttt_ankh` entity on the map
2. Navigates toward it
3. Every 5 seconds (timer), if within `UseRange` (50 units), **directly calls** `PHARAOH_HANDLER:StartConversion()` then 1-second delayed `PHARAOH_HANDLER:TransferAnkhOwnership()`
4. Witnesses react: Graverobbers attack Pharaohs who are converting; Innocents attack Graverobbers who are converting

**Assessment:** Partially functional but has critical issues. See §3.

### 2.5 Chatter Events

| Event | Priority | Templates Exist? |
|---|---|---|
| `PlacedAnkh` | 75 | ⚠️ Registered in priority table but **no locale strings found** |

### 2.6 Morality/Arbitration

| Reason Code | Priority | Description |
|---|---|---|
| `CAPTURE_ANKH` | 4 (`PLAYER_REQUEST`) | Forces attack target when witnessing ankh capture |

---

## 3. Bug Report

### 🐛 BUG-1: CaptureAnkh Bypasses Conversion Time

**Severity:** HIGH
**File:** `behaviors/captureankh.lua`, lines 46–51

```lua
function CaptureAnkh.UseAnkh(bot, ankh)
    PHARAOH_HANDLER:StartConversion(ankh, bot)
    timer.Simple(1, function()
        PHARAOH_HANDLER:TransferAnkhOwnership(ankh, bot)
    end)
    return STATUS.SUCCESS
end
```

**Problem:** The bot calls `TransferAnkhOwnership` after a flat 1-second delay, completely ignoring the `ttt_ankh_conversion_time` ConVar (default 6 seconds). This gives bots an unfair advantage — they convert ankhs 6× faster than human players.

**Fix:** The conversion should either:
- Respect the ConVar by using `GetConVar("ttt_ankh_conversion_time"):GetInt()` as the delay, OR
- Simulate continuous USE input over the conversion duration, letting the entity's built-in `ENT:Use()` logic handle the timer naturally

### 🐛 BUG-2: CaptureAnkh Validation Doesn't Check Role

**Severity:** MEDIUM
**File:** `behaviors/captureankh.lua`, `Validate` function

**Problem:** The `Validate` function does not check whether the bot's current role is `ROLE_GRAVEROBBER` or `ROLE_PHARAOH`. The behavior can activate for **any role**, which would silently fail (the entity's `Use()` function filters by role) but wastes behavior cycles and causes bots to walk toward ankhs purposelessly.

**Fix:** Add a role check early in `Validate`:
```lua
if bot:GetSubRole() ~= ROLE_GRAVEROBBER and bot:GetSubRole() ~= ROLE_PHARAOH then
    return false
end
```

### 🐛 BUG-3: CaptureAnkh ValidateAnkh Checks Wrong Thing

**Severity:** MEDIUM
**File:** `behaviors/captureankh.lua`, lines 17–22

```lua
function CaptureAnkh.ValidateAnkh(ankh)
    for i, v in pairs(player.GetAll()) do
        if v:HasWeapon(CaptureAnkh.TargetClass) then
            return false
        end
    end
    return IsValid(ankh) and ankh:GetClass() == CaptureAnkh.TargetClass
end
```

**Problem:** `CaptureAnkh.TargetClass` is `"ttt_ankh"` — which is an **entity class**, not a weapon class. `v:HasWeapon("ttt_ankh")` will never match any player's inventory because the weapon is `"weapon_ttt_ankh"`. This "dead code" check never triggers, making it a no-op rather than a harmful bug, but it indicates a misunderstanding of the entity vs. weapon distinction.

**Fix:** Either remove the check entirely (it serves no purpose) or replace with `"weapon_ttt_ankh"` if the intent was to skip conversion when someone is holding the ankh weapon.

### 🐛 BUG-4: PlantAnkh Looks at Bot's Own Feet

**Severity:** LOW
**File:** `behaviors/plantankh.lua`, `OnRunning` function

```lua
local spot = bot:GetPos()
locomotor:LookAt(spot)
```

**Problem:** `bot:GetPos()` returns the bot's origin (feet). `locomotor:LookAt()` expects a world position to aim at. Looking at your own feet is roughly correct for the "place ankh on the ground" mechanic (which traces 100 units forward from eye pos), but it means the bot always tries to place the ankh directly at their feet rather than finding a strategic, hidden location.

**Fix:** See §5 for strategic placement improvements.

### 🐛 BUG-5: PlantAnkh Description References C4

**Severity:** COSMETIC
**File:** `behaviors/plantankh.lua`, line 1

```lua
--- Plants a ankh in a safe location. Does not do anything if the bot does not have C4 in its inventory.
```

**Problem:** The description references C4, suggesting this was copy-pasted from `plantbomb.lua`. Should reference ankh.

### 🐛 BUG-6: CaptureAnkh Timer Has Debug Print

**Severity:** COSMETIC
**File:** `behaviors/captureankh.lua`, line 152

```lua
print("Witness is a graverobber")
```

**Problem:** Left-over debug `print()` statement that pollutes server console.

### 🐛 BUG-7: PlacedAnkh Chatter Event Has No Locale Strings

**Severity:** LOW
**File:** `components/chatter/sv_chatter_events.lua` + `locale/en/sh_chats.lua`

**Problem:** The `PlacedAnkh` event has a priority of 75 in the event table, but there are no corresponding message templates in the locale files. The chatter event fires silently.

---

## 4. Gap Analysis

### 4.1 Missing Behaviors

| Gap | Severity | Description |
|---|---|---|
| **G-1: Ankh Strategic Placement** | HIGH | Pharaoh bot places ankh at its own feet rather than choosing a strategic, hidden location away from high-traffic areas. Should consider: seclusion, line-of-sight cover, distance from common routes, proximity to health stations. |
| **G-2: Ankh Guard/Proximity** | HIGH | Pharaoh bot has no behavior to stay near or periodically return to its ankh to benefit from the healing aura and protect it. Currently the bot just wanders after placement. |
| **G-3: Ankh Defense** | HIGH | When the Pharaoh's ankh is being converted or attacked, the bot has no reactive behavior to rush back and defend it. There's no hook or awareness of ankh damage/conversion status. |
| **G-4: Graverobber Ankh Hunting** | MEDIUM | Graverobber CaptureAnkh only activates when an ankh entity is visible or was recently seen. No proactive search pattern — the bot just happens upon ankhs during normal patrol. Graverobbers should actively search the map, especially in secluded areas where Pharaohs are likely to place ankhs. |
| **G-5: Graverobber Ankh Destruction** | MEDIUM | When a Graverobber cannot convert an ankh (e.g., already controls one, or conversion is blocked because it's reviving), they should consider shooting it to destroy it. No behavior exists for this. |
| **G-6: Post-Revival Behavior** | MEDIUM | After ankh revival, the bot has no special behavior. It should: (a) use spawn protection time wisely (retreat/reposition), (b) be aware it has only 50 HP and play defensively, (c) seek health. |
| **G-7: Ankh Pickup/Relocation** | LOW | When ConVar allows pickup, Pharaoh bot never picks up and relocates its ankh to a safer spot if the current location has been compromised (e.g., enemies have found it). |
| **G-8: Graverobber Role Reversion** | LOW | When `PHARAOH_HANDLER:RevertUnnecessaryGraverobbers()` fires (all ankhs destroyed), the bot has no awareness that its role has changed. Should gracefully transition behavior. |
| **G-9: Anti-Grief Awareness** | LOW | Innocents should not randomly shoot ankhs (it hurts their own team). Currently there's no morality/hostility rule for this. |

### 4.2 Missing Suspicion/Morality Integration

| Gap | Description |
|---|---|
| **M-1: Ankh Conversion Witnessing** | If an innocent bot witnesses a Graverobber converting an ankh, it should raise maximum suspicion on them. Currently only the timer-based witness check in CaptureAnkh handles this, and it's limited. |
| **M-2: Ankh Destruction Witnessing** | If a bot witnesses someone shooting an ankh, this should raise suspicion. Shooting an allied objective is highly suspicious. |
| **M-3: Pharaoh Proximity Suspicion** | A Pharaoh bot should be suspicious of players loitering near their ankh — especially unknown-team players. |
| **M-4: Graverobber Concealment** | A Graverobber should be aware that converting an ankh in front of witnesses will get them KOS'd. They should wait for isolation. |

### 4.3 Missing Chatter

| Event | Context | Suggested Templates |
|---|---|---|
| `PlacedAnkh` | Pharaoh placed ankh | "I've secured a strategic position." / "My artifact is in place." |
| `AnkhStolen` | Pharaoh's ankh was converted | "Someone stole my ankh! I need to get it back!" / "The ankh was taken from me!" |
| `AnkhRecovered` | Pharaoh re-converted their ankh | "Got my ankh back!" / "Artifact reclaimed." |
| `AnkhDestroyed` | Anyone's ankh was destroyed | "The ankh was destroyed." / "Someone broke the ankh!" |
| `AnkhRevival` | Player revived via ankh | "I'm back! The ankh saved me." / "Revived from the dead!" |
| `GraverobberStoleAnkh` | Graverobber team chat | "I've captured the ankh. It's mine now." / "Got the pharaoh's artifact." |
| `AnkhSpotted` | Any bot sees an ankh | "I see something glowing over here..." / "There's a strange artifact here." |
| `DefendAnkh` | Pharaoh rushing to defend ankh | "Someone's messing with my ankh!" / "Get away from there!" |
| `HuntingAnkh` | Graverobber actively searching | "I need to find that ankh..." / "Where did the Pharaoh hide it?" (team chat) |

---

## 5. Implementation Strategy

### 5.1 Priority Order

The implementation should be staged to maximize gameplay impact while minimizing cross-system complexity:

**Phase 1 — Bug Fixes (Critical)**
1. Fix CaptureAnkh conversion time bypass (BUG-1)
2. Add role check to CaptureAnkh.Validate (BUG-2)
3. Fix ValidateAnkh weapon/entity confusion (BUG-3)
4. Remove debug prints (BUG-6)
5. Fix PlantAnkh docstring (BUG-5)

**Phase 2 — Core Behaviors (High Impact)**
6. Strategic ankh placement (G-1)
7. Ankh guarding/proximity behavior (G-2)
8. Ankh defense response (G-3)
9. Graverobber proactive ankh search (G-4)

**Phase 3 — Advanced Behaviors (Medium Impact)**
10. Ankh destruction behavior for Graverobber (G-5)
11. Post-revival tactical behavior (G-6)
12. Ankh pickup/relocation (G-7)

**Phase 4 — Social Systems (Polish)**
13. Chatter templates for all events (§7)
14. Suspicion/morality hooks (§8)
15. Anti-grief morality rules (G-9)
16. Role reversion awareness (G-8)

### 5.2 Architectural Approach

The Pharaoh/Graverobber integration spans multiple bot subsystems:

```
┌─────────────────────────────────────────────────────────────┐
│                    PHARAOH BOT MIND                         │
│                                                             │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │  PlantAnkh  │→ │  GuardAnkh   │→ │   DefendAnkh      │  │
│  │  (improved) │  │  (NEW)       │  │   (NEW)           │  │
│  └─────────────┘  └──────────────┘  └───────────────────┘  │
│         │                │                    │             │
│         ▼                ▼                    ▼             │
│  ┌──────────────────────────────────────────────────┐       │
│  │              AnkhAwareness (NEW)                 │       │
│  │  - Tracks ankh entity, health, conversion state  │       │
│  │  - Calculates threat level from nearby enemies   │       │
│  │  - Signals urgency to behavior tree              │       │
│  └──────────────────────────────────────────────────┘       │
│         │                                                   │
│         ▼                                                   │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  Morality   │  │   Chatter    │  │ RoundAware   │       │
│  │  (extended) │  │  (extended)  │  │ (hook into)  │       │
│  └─────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                  GRAVEROBBER BOT MIND                        │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ CaptureAnkh  │→ │ DestroyAnkh  │→ │ DefendOwnAnkh   │  │
│  │ (fixed)      │  │ (NEW)        │  │ (NEW)            │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
│         │                │                    │             │
│         ▼                ▼                    ▼             │
│  ┌──────────────────────────────────────────────────┐       │
│  │           HuntAnkh (NEW)                         │       │
│  │  - Systematic map search in secluded areas       │       │
│  │  - Uses wallhack data (if converted owner)       │       │
│  │  - Prioritizes areas not recently searched       │       │
│  └──────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. Detailed Implementation Plans

### 6.1 Fix CaptureAnkh — Respect Conversion Time (BUG-1)

**Approach:** Replace the direct `PHARAOH_HANDLER` API bypass with a simulated continuous USE hold over the correct conversion duration.

```lua
function CaptureAnkh.UseAnkh(bot, ankh)
    local conversionTime = GetConVar("ttt_ankh_conversion_time"):GetInt()

    -- Start conversion sounds/effects
    PHARAOH_HANDLER:StartConversion(ankh, bot)

    -- Store conversion state on the bot
    bot.ankhConvertingEntity = ankh
    bot.ankhConvertStartTime = CurTime()
    bot.ankhConvertEndTime = CurTime() + conversionTime

    -- The ongoing conversion is checked by OnRunning and the periodic timer
    return STATUS.RUNNING  -- NOT SUCCESS — stay in behavior until conversion completes
end
```

**OnRunning changes:**
- While `bot.ankhConvertStartTime` is set and `CurTime() < bot.ankhConvertEndTime`, keep the bot facing the ankh and staying within range
- If the bot is interrupted (attacked, ankh moved, etc.), cancel via `PHARAOH_HANDLER:CancelConversion()`
- On timer completion, call `PHARAOH_HANDLER:TransferAnkhOwnership(ankh, bot)` and return `STATUS.SUCCESS`

### 6.2 New Behavior: GuardAnkh (G-2)

**Purpose:** Pharaoh bot periodically returns to and stays near their placed ankh to benefit from the healing aura and protect it.

**Design:**
```
Validate:
  - Bot is ROLE_PHARAOH
  - Bot controls an ankh (PlayerControlsAnAnkh)
  - Ankh is placed (valid entity exists)
  - Bot is farther than GUARD_DISTANCE (300 units) from ankh
  - No active combat

OnRunning:
  - Navigate to ankh position
  - Once within 100 units (healing range), idle/patrol nearby
  - Periodically look around for threats
  - Return SUCCESS after guarding for GUARD_DURATION (15-30s, randomized by personality)
  - Return FAILURE if ankh is destroyed or combat starts
```

**Behavior Tree Placement (Pharaoh):**
```
Chatter → Requests → FightBack → PlantAnkh → DefendAnkh → GuardAnkh →
CaptureAnkh → Support → Defuse → Restore → Interact → Investigate → Minge → Patrol
```

**Phase Awareness:**
- EARLY: Guard more frequently (ankh is most vulnerable when Graverobber is first assigned)
- MID: Balance guarding with investigation/social duties
- LATE/OVERTIME: Guard less (focus on survival and team play)

### 6.3 New Behavior: DefendAnkh (G-3)

**Purpose:** Emergency response when the Pharaoh's ankh is being attacked or converted.

**Design:**
```
Validate:
  - Bot is ROLE_PHARAOH
  - Bot's ankh exists and is placed
  - One of:
    a) Ankh entity has a last_activator set (someone is converting it)
    b) Ankh HP is below threshold (someone is shooting it)
    c) Bot received a network message about conversion in progress
  - This behavior should have HIGHER priority than GuardAnkh

OnRunning:
  - Sprint to ankh position (set urgency on locomotor)
  - Once within range, attack the threat
  - If ankh is being converted: target the converter
  - If ankh is being shot: target the nearest visible enemy near the ankh
```

**Implementation Notes:**
- Need a server-side hook or periodic check to detect ankh damage/conversion
- Consider adding `DEFEND_ANKH` reason code to morality arbitration at `PLAYER_REQUEST` priority (4)
- Pharaoh's ankh reference can be obtained via `PHARAOH_HANDLER.ankhs[bot:SteamID64()]`

**Periodic Check Timer:**
```lua
timer.Create("TTTBots.Behaviors.DefendAnkh.Monitor", 1, 0, function()
    for _, bot in pairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot:GetSubRole() == ROLE_PHARAOH) then continue end
        local ankhData = PHARAOH_HANDLER.ankhs[bot:SteamID64()]
        if not ankhData or not IsValid(ankhData.ankh) then continue end

        local ankh = ankhData.ankh
        -- Check if ankh is being converted
        if ankh.last_activator and IsValid(ankh.last_activator) then
            bot.ankhUnderThreat = true
            bot.ankhThreatSource = ankh.last_activator
        -- Check if ankh HP is dropping
        elseif ankh:Health() < ankhData.health * 0.8 then
            bot.ankhUnderThreat = true
            bot.ankhThreatSource = nil -- Unknown attacker
        else
            bot.ankhUnderThreat = false
            bot.ankhThreatSource = nil
        end
    end
end)
```

### 6.4 Improved PlantAnkh — Strategic Placement (G-1)

**Current Problem:** Bot places ankh at its own feet, wherever it happens to be standing.

**Improved Approach:**
1. **Pre-compute candidate spots** during the behavior's OnStart phase:
   - Query nav mesh for areas with low foot traffic / far from high-connectivity hubs
   - Prefer areas with limited line-of-sight access (corners, dead ends, rooms with single entry)
   - Avoid wide-open areas, main corridors, and near spawn points
   - Consider distance from health stations (nearby is a plus)

2. **Navigate to chosen spot**, then place:
   ```
   OnStart:
     - Compute candidate locations (see below)
     - Choose the best candidate based on scoring
     - Set locomotor goal to that position

   OnRunning:
     - If not at target location: navigate
     - If at target location: look down, equip ankh, attack to place
     - If placement fails (too steep, etc.): try next candidate
   ```

3. **Scoring function for candidate spots:**
   ```lua
   local function ScorePlacementSpot(pos)
       local score = 0
       -- Seclusion: fewer nav connections = more secluded
       score = score + (10 - math.min(GetNavConnectionCount(pos), 10)) * 5
       -- Distance from center of map
       score = score + math.min(pos:Distance(GetMapCenter()) / 500, 5)
       -- Not too far from a health station (if they exist)
       local nearestHS = GetNearestHealthStation(pos)
       if nearestHS and nearestHS:Distance(pos) < 1000 then
           score = score + 3
       end
       -- Penalty for being near many players currently
       local nearbyPlayers = #ents.FindInSphere(pos, 500)
       score = score - nearbyPlayers * 3
       return score
   end
   ```

### 6.5 Graverobber Proactive Ankh Search (G-4)

**Purpose:** Instead of waiting to stumble upon an ankh, the Graverobber should actively search the map.

**Design — New Behavior: `HuntAnkh`**
```
Validate:
  - Bot is ROLE_GRAVEROBBER
  - No ankh currently controlled by bot
  - Round is active
  - No ttt_ankh entity currently known/visible

OnRunning:
  - Pick a search area (cycle through map areas, prioritizing unvisited ones)
  - Navigate to the area
  - Look around upon arrival (scan for ankh glow, entity presence)
  - Mark area as searched
  - Move to next area
  - If ankh becomes visible: transition to CaptureAnkh behavior (validation will pick it up)
```

**Smart Search Heuristics:**
- Check secluded areas first (dead ends, small rooms) — where Pharaohs are likely to place
- Use knowledge of where Pharaoh bot was last seen
- If Pharaoh is dead and ankh has not been found, search near their death location
- Use the `ttt_ankh_light_up` glow as a detection mechanism at moderate range

### 6.6 Ankh Destruction Behavior (G-5)

**Purpose:** When a Graverobber already controls an ankh (or conversion is blocked), shoot a competitor's ankh.

**Design — Extension to CaptureAnkh or new behavior:**
```
Validate:
  - Bot is on TEAM_TRAITOR
  - There's a ttt_ankh entity that is NOT controlled by the bot
  - The ankh is reviving someone (isReviving NW bool), OR
  - The bot already controls a different ankh

OnRunning:
  - Navigate to within weapon range of the ankh
  - Equip best weapon and shoot the ankh entity
  - When ankh:Health() <= 0, it self-destructs
```

**Note:** Any player can damage an ankh (unless `TTT2PharaohPreventDamageToAnkh` blocks them). This is a valid strategy for any non-innocent player.

### 6.7 Post-Revival Behavior (G-6)

**Purpose:** After reviving at the ankh, the bot should play smartly with 50 HP and spawn protection.

**Implementation via Hook:**
```lua
hook.Add("TTT2PostPlayerDeath", "TTTBots_PharaohRevivalAwareness", function(victim)
    if not IsValid(victim) or not victim:IsBot() then return end
    -- Track that this bot may revive soon
    local id = PHARAOH_HANDLER:PlayerCanReviveWithThisAnkhDataId(victim)
    if id ~= -1 then
        victim.tttbots_pendingAnkhRevival = true
    end
end)
```

**Post-Revival Logic (in a Think hook or timer after revival fires):**
```lua
-- After reviving:
-- 1. Set bot personality to "cautious" for 30 seconds
-- 2. Seek cover immediately
-- 3. Prioritize health station / healing
-- 4. Avoid direct combat until healed above 75 HP
bot.tttbots_justRevived = true
bot.tttbots_revivalTime = CurTime()
```

The existing RoundAwareness component and morality system can read `bot.tttbots_justRevived` to temporarily suppress aggression.

---

## 7. Chatter Integration

### 7.1 New Chatter Events to Register

Add to `sv_chatter_events.lua` priority table:

```lua
AnkhStolen                 = 85,  -- Pharaoh's ankh was converted by enemy
AnkhRecovered              = 80,  -- Pharaoh re-converted their ankh
AnkhDestroyed              = 75,  -- Any ankh was destroyed
AnkhRevival                = 80,  -- Player revived via ankh
GraverobberStoleAnkh       = 75,  -- Graverobber team chat
AnkhSpotted                = 60,  -- Any bot sees an ankh entity
DefendingAnkh              = 80,  -- Pharaoh rushing to defend
HuntingAnkh                = 50,  -- Graverobber searching (team chat)
AnkhUnderAttack            = 85,  -- Pharaoh's ankh is being damaged
```

### 7.2 Locale Templates Needed

**File:** `locale/en/sh_chats.lua`

```lua
-- Pharaoh chatter
["PlacedAnkh"] = {
    "I've placed my artifact in a safe spot.",
    "My ankh is secured. Let's hope it stays that way.",
    "Strategic position locked down.",
},
["AnkhStolen"] = {
    "Someone took my ankh! I need to get it back!",
    "My artifact was stolen! This is bad.",
    "The graverobber got to my ankh...",
},
["AnkhRecovered"] = {
    "Got my ankh back. Don't touch it again.",
    "Artifact reclaimed. Stay away from it.",
},
["DefendingAnkh"] = {
    "Someone's messing with my ankh!",
    "Get away from my artifact!",
    "I need to protect my ankh!",
},
["AnkhUnderAttack"] = {
    "My ankh is taking damage! I need help!",
    "Someone's destroying my artifact!",
},
-- Graverobber chatter (team-only)
["GraverobberStoleAnkh"] = {
    "I've captured the pharaoh's ankh. It's mine now.",
    "Got the artifact. Extra life secured.",
    "Ankh stolen. The pharaoh won't be happy.",
},
["HuntingAnkh"] = {
    "I need to find that ankh...",
    "Where did the Pharaoh hide their artifact?",
    "Searching for the ankh. Keep them busy.",
},
-- General chatter
["AnkhDestroyed"] = {
    "The ankh was destroyed!",
    "Someone broke the artifact.",
},
["AnkhRevival"] = {
    "I'm back from the dead!",
    "The ankh saved me. I'm alive again!",
    "Revived! Thanks to my artifact.",
},
["AnkhSpotted"] = {
    "I see something glowing over here...",
    "There's a strange artifact here.",
    "Is that... an ankh?",
},
```

### 7.3 Chatter Trigger Points

| Trigger | Where to Call | Team-Only? |
|---|---|---|
| Ankh placed successfully | `PlantAnkh.OnSuccess` | No |
| Pharaoh's ankh converted | Hook into `PHARAOH_HANDLER:TransferAnkhOwnership` | No |
| Pharaoh re-converts | Same hook, detect Pharaoh reclaiming | No |
| Ankh destroyed | Hook into `PHARAOH_HANDLER:DestroyAnkh` | No |
| Ankh revival complete | Hook into the `OnRevive` callback | No |
| Graverobber captures | CaptureAnkh completion | Yes (team) |
| Graverobber searching | HuntAnkh.OnStart | Yes (team) |
| Pharaoh defending | DefendAnkh.OnStart | No |
| Bot spots ankh | Perception check for `ttt_ankh` entities | No |

---

## 8. Morality & Suspicion Integration

### 8.1 Suspicion Events to Add

| Event | Suspicion Delta | Context |
|---|---|---|
| Witness someone converting an ankh | +60 to +80 | Near-KOS level — conversion is a deliberate hostile act |
| Witness someone shooting an ankh | +30 to +50 | Ankh damage is suspicious but could be accidental |
| Witness Graverobber capturing ankh | +100 (KOS) | Direct role reveal |
| Player loitering near ankh (non-owner) | +10 per interval | Mild proximity suspicion |
| Pharaoh's ankh was stolen (from Pharaoh's perspective) | Set attacker to KOS | Pharaoh knows who stole it via events |

### 8.2 Morality Hostility Rules

**New function in `sv_morality_hostility.lua`:**
```lua
--- Pharaoh bots should defend their ankh from known threats.
--- Graverobber bots should target the Pharaoh if they're near the ankh.
local function ankhBasedHostility(bot)
    local roleData = TTTBots.Roles.GetRoleFor(bot)

    -- Pharaoh: attack anyone seen converting/attacking their ankh
    if bot:GetSubRole() == ROLE_PHARAOH and bot.ankhThreatSource then
        local threat = bot.ankhThreatSource
        if IsValid(threat) and lib.IsPlayerAlive(threat) then
            Arb.RequestAttackTarget(bot, threat, "DEFEND_ANKH", PRI.PLAYER_REQUEST)
        end
    end

    -- Graverobber: target Pharaoh if they're guarding their ankh and we're trying to capture
    if bot:GetSubRole() == ROLE_GRAVEROBBER and bot.targetAnkh then
        local ankh = bot.targetAnkh
        if IsValid(ankh) and IsValid(ankh:GetOwner()) then
            local pharaoh = ankh:GetOwner()
            if pharaoh:GetSubRole() == ROLE_PHARAOH
            and bot:GetPos():Distance(ankh:GetPos()) < 200 then
                Arb.RequestAttackTarget(bot, pharaoh, "ANKH_GUARDIAN_THREAT", PRI.ROLE_HOSTILITY)
            end
        end
    end
end
```

### 8.3 New Arbitration Reason Codes

Add to `sv_morality_arbitration.lua`:
```lua
DEFEND_ANKH             = "Defending own ankh from attacker/converter",
ANKH_GUARDIAN_THREAT     = "Graverobber targeting Pharaoh guarding ankh",
ANKH_CONVERSION_WITNESS  = "Witnessed ankh conversion — hostile act",
```

### 8.4 Anti-Grief Rules (G-9)

Innocent-team bots should NOT shoot ankhs belonging to fellow innocents:

```lua
-- In morality/hostility Think:
-- If bot is innocent-team and sees a pharaoh-owned ankh, do not damage it.
-- This prevents friendly-fire on a team objective.
hook.Add("TTT2PharaohPreventDamageToAnkh", "TTTBots_AntiGriefAnkh", function(attacker)
    if not IsValid(attacker) or not attacker:IsBot() then return end
    if attacker:GetTeam() == TEAM_INNOCENT then
        return true -- Prevent damage
    end
end)
```

---

## 9. Checklist

### Phase 1 — Bug Fixes
- [x] **BUG-1:** Fix CaptureAnkh to respect `ttt_ankh_conversion_time` ConVar
- [x] **BUG-2:** Add role check (`ROLE_GRAVEROBBER` / `ROLE_PHARAOH`) to CaptureAnkh.Validate
- [x] **BUG-3:** Fix or remove `ValidateAnkh` weapon/entity class confusion
- [x] **BUG-4:** Improve PlantAnkh aiming (look slightly ahead, not at feet)
- [x] **BUG-5:** Fix PlantAnkh docstring (remove C4 reference)
- [x] **BUG-6:** Remove debug `print()` in CaptureAnkh
- [x] **BUG-7:** Add PlacedAnkh locale strings

### Phase 2 — Core Behaviors
- [x] **G-1:** Implement strategic ankh placement in PlantAnkh (nav-mesh scoring, secluded spots)
- [x] **G-2:** Create `GuardAnkh` behavior (periodic return, healing aura exploitation)
- [x] **G-3:** Create `DefendAnkh` behavior (emergency response to threats)
- [x] **G-4:** Create `HuntAnkh` behavior (Graverobber proactive search)
- [x] Update Pharaoh behavior tree: `PlantAnkh → DefendAnkh → GuardAnkh → CaptureAnkh`
- [x] Update Graverobber behavior tree: `CaptureAnkh → HuntAnkh → DestroyAnkh`

### Phase 3 — Advanced Behaviors
- [x] **G-5:** Create `DestroyAnkh` behavior (shoot enemy ankhs)
- [x] **G-6:** Implement post-revival cautious behavior
- [x] **G-7:** Implement ankh pickup/relocation behavior
- [x] **G-8:** Handle role reversion gracefully (behavior tree swap)

### Phase 4 — Social Systems
- [x] Register all new chatter events in `sv_chatter_events.lua`
- [x] Create all locale templates in `locale/en/sh_chats.lua`
- [x] Wire chatter triggers into behaviors and hooks
- [x] Add ankh-related suspicion events to morality/suspicion
- [x] Add `DEFEND_ANKH` and `ANKH_GUARDIAN_THREAT` reason codes to arbitration
- [x] Add `ankhBasedHostility` function to `sv_morality_hostility.lua`
- [x] Add anti-grief hook for innocent-team bots

### Post-Implementation Fixes
- [x] **NEW-1:** CaptureAnkh used `ankh._tttbots_converter` instead of `ankh.last_activator` (ENT:Think cancels if `last_activator` is set but bot doesn't press USE)
- [x] **NEW-2:** CaptureAnkh manually sets `ankh:SetNWInt("conversion_progress", ...)` so DefendAnkh can detect bot conversions
- [x] **NEW-3:** Suspicion timer checks both `ankh.last_activator` and `ankh._tttbots_converter`
- [x] **NEW-4:** PharaohCoordinator field name cleanup fixed (`_ankhConvertingEnt`/`_ankhConvertStart`)
- [x] **NEW-5:** PharaohCoordinator RevivalMonitor added — fires `TTT2AnkhRevive` hook (was missing, chatter was silent)
- [x] **NEW-6:** PostRevival uses dual detection: `TTT2AnkhRevive` (primary) + `PlayerSpawn` (fallback)

---

## 10. File Map

### Existing Files to Modify

| File | Changes |
|---|---|
| `lua/tttbots2/roles/pharaoh.lua` | Update behavior tree, add role description |
| `lua/tttbots2/roles/graverobber.lua` | Update behavior tree, add HuntAnkh/DestroyAnkh |
| `lua/tttbots2/behaviors/plantankh.lua` | Strategic placement, fix docstring, improve aiming |
| `lua/tttbots2/behaviors/captureankh.lua` | Fix conversion time, role check, entity validation, remove debug print |
| `lua/tttbots2/components/chatter/sv_chatter_events.lua` | Register new ankh-related events |
| `lua/tttbots2/components/morality/sv_morality_hostility.lua` | Add `ankhBasedHostility()` |
| `lua/tttbots2/components/morality/sv_morality_arbitration.lua` | Add new reason codes |
| `lua/tttbots2/components/morality/sv_morality_suspicion.lua` | Add ankh witness suspicion events |

### New Files to Create

| File | Purpose |
|---|---|
| `lua/tttbots2/behaviors/guardankh.lua` | Pharaoh guarding ankh behavior |
| `lua/tttbots2/behaviors/defendankh.lua` | Pharaoh emergency ankh defense |
| `lua/tttbots2/behaviors/huntankh.lua` | Graverobber proactive ankh search |
| `lua/tttbots2/behaviors/destroyankh.lua` | Traitor-team ankh destruction |
| `lua/tttbots2/behaviors/postrevival.lua` | Post-ankh-revival cautious behavior |
| `lua/tttbots2/behaviors/relocateankh.lua` | Ankh pickup and relocation when compromised |
| `lua/tttbots2/lib/sv_pharaohcoordinator.lua` | Role reversion cleanup, event bridging (ownership/destruction/revival monitors) |

### Source Addon Files Referenced

| File | Key Contents |
|---|---|
| `lua/terrortown/entities/roles/pharaoh/shared.lua` | Role definition, loadout, ConVars |
| `lua/terrortown/entities/roles/graverobber/shared.lua` | Role definition, loadout |
| `lua/terrortown/autorun/shared/sh_pharaoh_handler.lua` | `PHARAOH_HANDLER` — all ankh state management |
| `lua/terrortown/autorun/shared/sh_pharaoh_convars.lua` | ConVar definitions |
| `lua/terrortown/autorun/shared/sh_pharaoh_setup.lua` | Resource setup, sounds, status icons |
| `gamemodes/terrortown/entities/weapons/weapon_ttt_ankh/shared.lua` | Ankh weapon — placement mechanic |
| `gamemodes/terrortown/entities/entities/ttt_ankh/shared.lua` | Ankh entity — conversion, damage, healing, USE logic |
| `lua/terrortown/events/ankh_conversion.lua` | Conversion event |
| `lua/terrortown/events/ankh_destroyed.lua` | Destruction event |
| `lua/terrortown/events/ankh_revive.lua` | Revival event |
| `lua/terrortown/lang/en/pharaoh.lua` | All English language strings |
