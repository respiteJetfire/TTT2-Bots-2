# Hidden Role — Bot Integration Analysis & Implementation Plan

> **Date:** 2026-03-25
> **Scope:** TTT2-Bots-2 integration for `ttt2_hidden_role_2487229784` (Hidden + weapon_ttt_hd_knife + weapon_ttt_hd_nade)

---

## Table of Contents

1. [Hidden Role Summary](#1-hidden-role-summary)
2. [Architectural Mapping to TTT2-Bots-2](#2-architectural-mapping-to-ttt2-bots-2)
3. [Files to Create](#3-files-to-create)
4. [Files to Modify](#4-files-to-modify)
5. [Detailed Implementation — Role Registration](#5-detailed-implementation--role-registration)
6. [Detailed Implementation — Behaviors](#6-detailed-implementation--behaviors)
7. [Detailed Implementation — Stalk Exemption](#7-detailed-implementation--stalk-exemption)
8. [Detailed Implementation — Grenade Reaction Hook](#8-detailed-implementation--grenade-reaction-hook)
9. [Detailed Implementation — Perception / Invisibility Awareness](#9-detailed-implementation--perception--invisibility-awareness)
10. [Detailed Implementation — Bot Reaction to Hidden Announcement](#10-detailed-implementation--bot-reaction-to-hidden-announcement)
11. [Implementation Checklist](#11-implementation-checklist)
12. [Testing Plan](#12-testing-plan)

---

## 1. Hidden Role Summary

### 1.1 Role Mechanics (from `ttt2_hidden_role_2487229784`)

| Property | Value |
|---|---|
| **Team** | `TEAM_HIDDEN` (custom solo neutral team) |
| **Abbreviation** | `hdn` |
| **Default Equipment** | `SPECIAL_EQUIPMENT` |
| **Starting Credits** | 1 |
| **Min Players** | 8 |
| **Maximum** | 1 per round |
| **Jester Awareness** | `networkRoles = {JESTER}` — Hidden sees who is a Jester |
| **Score** | Kill multiplier (5×), negative team-kill (-16×), survival bonus (0.5×) |

### 1.2 Two-Phase Design — The Core Mechanic

The Hidden role has a **unique two-phase design** that is critical to understand:

#### Phase 1: Pre-Transformation (Disguised)
- The Hidden starts the round looking like a **normal player** with standard weapons.
- They deal **only 20% damage** (`ScalePlayerDamage` hook scales by 0.2).
- They can pick up any weapon normally.
- They appear as a **Jester** to other teams via `networkRoles = {JESTER}`.
- **Goal:** Blend in, scout the map, and choose the optimal moment to transform.

#### Phase 2: Post-Transformation (Stalker Mode)
- Triggered by pressing **Reload** (`IN_RELOAD`).
- **Permanent and irreversible** — once activated, the Hidden cannot go back.
- On activation:
  - All non-special weapons are stripped.
  - Given `weapon_ttt_hd_knife` and `weapon_ttt_hd_nade`.
  - Given `item_ttt_climb` (wall climb ability).
  - Health is boosted: `HP = clamp(current + (alive_players-1)*8, current, 300)`, max HP follows similar formula.
  - **Near-invisible cloaking** (heatwave material, alpha 3 when full cloak).
  - **60% speed bonus** (1.6× speed multiplier).
  - **50% stamina regen bonus** (1.5× stamina).
  - Cannot pick up weapons (only knife/nade allowed).
  - Cloaking is **temporarily disrupted** on taking damage (5-second partial reveal).
- An **EPOP announcement** broadcasts to all players: *"{nick} is the Hidden!"*
- On death in stalker mode, another EPOP fires: *"{nick} the Hidden has been defeated!"*

### 1.3 Hidden's Knife (`weapon_ttt_hd_knife`)

| Property | Value |
|---|---|
| **Primary Attack (M1)** | Melee slash, 60 damage, 1s auto-attack delay. **Instant-kill** (2000 dmg) when target HP < 65. Knife embeds in ragdoll on kill. Silent weapon. |
| **Secondary Attack (M2)** | Throws the knife as a projectile (`ttt_hd_knife_proj`). 50+ damage (scales with distance). Instant-kill on low-HP targets. |
| **Slot** | `WEAPON_SPECIAL` |
| **On Use** | Knife is stripped and **respawns after configurable delay** (`ttt2_hdn_knife_delay`, default 15s). During cooldown, a `ttt2_hdn_knife_recharge` status is shown. |
| **World Model** | Hidden (empty string) — the knife is invisible to other players. |

### 1.4 Hidden's Stun Grenade (`weapon_ttt_hd_nade`)

| Property | Value |
|---|---|
| **Type** | Grenade (based on `weapon_tttbasegrenade`) |
| **Damage** | 30 blast damage + stun effect |
| **Stun Effect** | Sets `ttt2_hdnade_stun` NWBool on all players in radius → motion blur screen effect for configurable duration (`ttt2_hdn_stun_duration`, default 5s) |
| **Blast Radius** | 256 units |
| **Respawn** | After configurable delay (`ttt2_hdn_nade_delay`, default 30s). Status `ttt2_hdn_nade_recharge` shown during cooldown. |
| **Max Clip** | 3 grenades |

### 1.5 Hidden's Knife Projectile (`ttt_hd_knife_proj`)

- Thrown via M2 on the knife weapon.
- Physics-based projectile (model: `w_knife_t.mdl`).
- Tracks collision with players via `Think` + trace.
- Instant-kills targets below damage threshold; otherwise deals scaling distance damage.
- After hitting something, becomes a new `weapon_ttt_hd_knife` entity (BecomeWeapon), starting the respawn timer for the Hidden.

### 1.6 Cloaking System

| State | Trigger | Visual |
|---|---|---|
| `CLOAK_FULL` | Standing still, no recent damage | Material `sprites/heatwave`, alpha 3 (near-invisible) |
| `CLOAK_PARTIAL` | After taking damage (5s decay) | Progressive alpha reveal based on HP ratio |
| `CLOAK_NONE` | Not in stalker mode, dead, round not active | Normal appearance |

The cloaking runs on a **server-side `Think` hook** that updates every tick.

### 1.7 Win Condition

The Hidden wins by killing all other players (solo team, KOS by all, KOS all). Every non-jester is an enemy.

### 1.8 ConVars

| ConVar | Default | Description |
|---|---|---|
| `ttt2_hdn_knife_delay` | 15 | Seconds before knife respawns after throw/kill |
| `ttt2_hdn_nade_delay` | 30 | Seconds before stun nade respawns |
| `ttt2_hdn_stun_duration` | 5 | Duration of stun effect on hit players |

---

## 2. Architectural Mapping to TTT2-Bots-2

### 2.1 Role Archetype

The Hidden is a **solo neutral killer** — the closest existing archetype is `NeutralKiller` (same as Serial Killer, Doomguy). Key differences from Serial Killer:

| Aspect | Serial Killer | Hidden |
|---|---|---|
| **Transformation** | Always active | Two-phase (must press Reload) |
| **Invisibility** | None | Full cloaking system |
| **Speed** | Normal | 1.6× in stalker mode |
| **Weapons** | SK Knife + regular guns | HD Knife (melee + thrown) + stun nade only |
| **Omniscient** | Wallhack/radar | Vision through walls (client-side, not bot-relevant) |
| **Announcement** | None | EPOP on transformation |
| **Knife Respawn** | Instant (always available) | Delayed (15s default cooldown) |

### 2.2 Behavior Tree Design

The Hidden needs **two behavior trees** with dynamic switching (same pattern as Serial Killer's stealth/aggressive trees):

#### Tree 1: Pre-Transformation (Disguised Phase)
```
1. Chatter                      -- Social deception to blend in
2. FightBack                    -- React to being attacked (limited: only 20% damage)
3. SelfDefense                  -- Defend from accusations
4. Requests                     -- Handle incoming requests
5. HiddenActivate               -- [NEW] Decision logic: when to press Reload and transform
6. Deception                    -- Alibi building, fake investigating
7. Restore                      -- Pick up weapons (still allowed pre-transform)
8. InvestigateCorpse            -- Appear innocent by investigating bodies
9. Minge                        -- Casual behavior for cover
10. Patrol                      -- Default patrol
```

#### Tree 2: Post-Transformation (Stalker Phase)
```
1. FightBack                    -- React to immediate combat
2. HiddenStunNade               -- [NEW] Throw stun nade for area denial/escape
3. HiddenKnifeAttack            -- [NEW] Stalk and knife-kill targets (melee M1)
4. HiddenKnifeThrow             -- [NEW] Throw knife at wounded/distant targets (M2)
5. Stalk                        -- Hunt isolated targets (existing behavior, exempt from late-game gate)
6. Requests                     -- Handle ceasefire/wait requests (rarely honored)
7. Chatter                      -- Minimal callouts
8. Wander                       -- Keep moving (speed advantage)
```

### 2.3 New Behavior Files Needed

| File | Purpose |
|---|---|
| `behaviors/hiddenactivate.lua` | Decision logic for when to press Reload and transform |
| `behaviors/hiddenknifeattack.lua` | Stalk + melee knife kill (M1) on isolated targets |
| `behaviors/hiddenknifethrow.lua` | Throw knife (M2) at wounded/distant targets |
| `behaviors/hiddenstunnade.lua` | Throw stun grenade for area denial, escape, or pre-kill distraction |

### 2.4 Role Registration File

| File | Purpose |
|---|---|
| `roles/hidden.lua` | Role definition, tree switching, Stalk exemption hook |

---

## 3. Files to Create

### 3.1 `lua/tttbots2/roles/hidden.lua`

Role registration using `RoleBuilder.NeutralKiller`. Dynamic tree switching between pre-transform (disguised) and post-transform (stalker) trees. Stalk exemption for late-game gate. `GetTreeFor` hook override following the Serial Killer pattern.

### 3.2 `lua/tttbots2/behaviors/hiddenactivate.lua`

Behavior that decides **when** the Hidden bot should press Reload to transform into stalker mode. This is the most critical and nuanced behavior.

### 3.3 `lua/tttbots2/behaviors/hiddenknifeattack.lua`

Melee knife behavior: stalk isolated targets, close to melee range, equip `weapon_ttt_hd_knife`, attack with M1. Very similar to `SKKnifeAttack` but adapted for the Hidden's knife (60 dmg, instant-kill < 65 HP, silent).

### 3.4 `lua/tttbots2/behaviors/hiddenknifethrow.lua`

Thrown knife behavior: when a target is wounded but out of melee range (or fleeing), use M2 to throw the knife projectile. Accepts the 15s respawn cooldown as a trade-off.

### 3.5 `lua/tttbots2/behaviors/hiddenstunnade.lua`

Stun grenade behavior: throw the `weapon_ttt_hd_nade` in tactical situations (escape, pre-kill distraction on groups, cover after a kill). Similar pattern to `SKShakeNade`.

---

## 4. Files to Modify

### 4.1 `lua/tttbots2/behaviors/stalk.lua`

Add a **Hidden exemption** to the late-game phase gate (same pattern as Serial Killer / Infected Host / Necromancer). The Hidden's core mechanic IS stalking + knife kills, so it must be exempt from the `PHASE.LATE`/`PHASE.OVERTIME` gate.

**Location:** Inside `Stalk.Validate()`, in the `PHASE.LATE or PHASE.OVERTIME` branch.

**Change:**
```lua
-- Existing exemptions:
local isInfectedHost = TTTBots.Roles.IsInfectedHost
    and TTTBots.Roles.IsInfectedHost(bot)
local isSerialKiller = bot.GetRoleStringRaw
    and bot:GetRoleStringRaw() == "serialkiller"
local isNecroMaster = TTTBots.Roles.IsNecroMaster
    and TTTBots.Roles.IsNecroMaster(bot)

-- ADD:
local isHidden = bot.GetRoleStringRaw
    and bot:GetRoleStringRaw() == "hidden"

if isInfectedHost or isSerialKiller or isNecroMaster or isHidden then
    -- Allow stalking to continue for these roles at all phases
```

### 4.2 `lua/tttbots2/lib/sv_perception.lua` (Optional Enhancement)

Add awareness of the Hidden's cloaking system. When a Hidden bot is in stalker mode with full cloak (`CLOAK_FULL`), non-Hidden bots should have **reduced detection range** against them. This makes the invisibility meaningful for bot-vs-bot gameplay.

**Implementation:** Hook into the perception system to check `ttt2_hd_stalker_mode` NWBool and reduce visibility range when the Hidden is fully cloaked.

---

## 5. Detailed Implementation — Role Registration

### `roles/hidden.lua`

```lua
--- Hidden — solo neutral stealth killer.
--- Wins by eliminating all non-allied players.
--- Has a two-phase design: disguised phase (normal player) and
--- stalker phase (invisible, fast, knife-only).
--- The bot must decide when to transform (press Reload) based on
--- game state, isolation, and opportunity.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_HIDDEN then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local _bh    = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
```

#### Pre-Transformation Tree (Disguised)

```lua
local bTreeDisguised = {
    _prior.Chatter,                -- Social deception to blend in
    _prior.FightBack,              -- React to attacks (only 20% damage though)
    _prior.SelfDefense,            -- Defend from accusations
    _prior.Requests,               -- Handle requests
    _bh.HiddenActivate,            -- [NEW] Decision: should we transform now?
    _prior.Deception,              -- Alibi building, fake investigating
    _prior.Restore,                -- Pick up weapons (still allowed)
    _bh.InvestigateCorpse,         -- Appear innocent
    _prior.Minge,                  -- Casual cover behavior
    _prior.Patrol,                 -- Default patrol
}
```

#### Post-Transformation Tree (Stalker)

```lua
local bTreeStalker = {
    _prior.FightBack,              -- React to immediate combat
    _bh.HiddenStunNade,            -- Throw stun nade for area denial/escape
    _bh.HiddenKnifeAttack,         -- Melee knife kills on isolated targets
    _bh.HiddenKnifeThrow,          -- Throw knife at wounded/distant targets
    _bh.Stalk,                     -- Hunt isolated targets (existing)
    _prior.Requests,               -- Handle requests (rarely honored)
    _prior.Chatter,                -- Minimal chatter
    _bh.Wander,                    -- Keep moving (speed advantage)
}
```

#### Dynamic Tree Selection

```lua
--- Check if a bot is currently in Hidden stalker mode.
---@param bot Player
---@return boolean
local function isInStalkerMode(bot)
    return bot:GetNWBool("ttt2_hd_stalker_mode", false)
end

--- Dynamic tree selection: disguised vs stalker phase.
---@param bot Player
---@return table bTree
local function getPhaseBasedBTree(bot)
    if not IsValid(bot) then return bTreeDisguised end
    if isInStalkerMode(bot) then
        return bTreeStalker
    end
    return bTreeDisguised
end
```

#### Role Registration

```lua
local roleDescription = "The Hidden is a solo stealth killer. You start disguised as a normal player. "
    .. "Press Reload at the right moment to permanently transform: you become near-invisible, "
    .. "gain 60% speed, but lose all weapons except your knife and stun grenades. "
    .. "Kill everyone before they find and kill you. You know who the Jesters are (avoid them). "
    .. "Transform when isolated or when few players remain. Use your knife (melee or thrown) "
    .. "and stun grenades tactically. You are a predator — patient, fast, and lethal."

local hidden = TTTBots.RoleBuilder.NeutralKiller("hidden", TEAM_HIDDEN)
hidden:SetDefusesC4(false)
hidden:SetKnowsLifeStates(false)      -- Hidden doesn't have wallhack/radar
hidden:SetLovesTeammates(true)
hidden:SetIsFollower(false)            -- Hidden hunts, not follows
hidden:SetBTree(bTreeDisguised)        -- Default; overridden at runtime
hidden:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(hidden)
```

#### GetTreeFor Hook Override

```lua
--- Runtime tree override: swap tree based on stalker mode.
--- Follows the Serial Killer pattern of wrapping GetTreeFor.
local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor
function TTTBots.Behaviors.GetTreeFor(bot)
    if not IsValid(bot) then return nil end

    local role = TTTBots.Roles.GetRoleFor(bot)
    if role and role:GetName() == "hidden" then
        return getPhaseBasedBTree(bot)
    end

    return _origGetTreeFor(bot)
end
```

#### Helper Function for Other Systems

```lua
--- Global helper: check if a player is a Hidden in stalker mode.
--- Used by stalk.lua exemption and perception hooks.
---@param bot Player
---@return boolean
function TTTBots.Roles.IsHiddenStalker(bot)
    if not IsValid(bot) then return false end
    local role = TTTBots.Roles.GetRoleFor(bot)
    if not role or role:GetName() ~= "hidden" then return false end
    return bot:GetNWBool("ttt2_hd_stalker_mode", false)
end

return true
```

---

## 6. Detailed Implementation — Behaviors

### 6.1 `HiddenActivate` — Transformation Decision Logic

**File:** `behaviors/hiddenactivate.lua`

This is the most strategically complex behavior. The bot must decide the optimal moment to permanently transform. Once transformed, there's no going back.

#### Decision Factors (Weighted)

| Factor | Weight | Rationale |
|---|---|---|
| **Alive player count** | High | Transform when fewer players alive = fewer enemies to fight |
| **Isolation** | High | Transform when alone / no witnesses to the transformation |
| **Round phase** | Medium | Prefer MID/LATE phase; never in first 30 seconds |
| **Bot health** | Medium | Transform when at full health (HP is boosted on transform) |
| **Nearby threats** | Negative | Don't transform if enemies are watching |
| **Random chance per tick** | Low | Adds variety; prevents all Hidden bots transforming at same time |

#### Activation Logic Pseudocode

```
function Validate(bot):
    - Must be Hidden role
    - Must NOT already be in stalker mode
    - Round must be active
    - At least 15 seconds into the round (don't transform immediately)
    - Random chance gate: 5% per validate tick

function OnRunning(bot):
    - Count alive players
    - Count nearby witnesses (within 800 units, FOV-aware)
    - Calculate "readiness score":
        + base = 0
        + if alive_count <= 6: +20
        + if alive_count <= 4: +30 (additional)
        + if no witnesses within 800u: +25
        + if 1 witness: +10
        + if health >= 90: +10
        + if round phase == LATE: +20
        + if round phase == OVERTIME: +40
        + if round time > 120s: +15
    - If readiness_score >= 40:
        → Press IN_RELOAD (simulate key press)
        → Return SUCCESS
    - Else: Return RUNNING (keep evaluating)
```

#### Key Implementation Details

- The bot presses `IN_RELOAD` to activate stalker mode. This must be done via the locomotor's key press simulation.
- After pressing Reload, the server-side `KeyPress` hook in `sh_hd_handler.lua` handles the actual transformation.
- The behavior should wait 1-2 ticks after pressing Reload to verify the NWBool `ttt2_hd_stalker_mode` is now `true`, then return SUCCESS.
- **Fallback:** If 180 seconds have passed and the bot still hasn't transformed, force-transform regardless of conditions (prevents passive Hidden bots that never activate).

### 6.2 `HiddenKnifeAttack` — Melee Knife Kill

**File:** `behaviors/hiddenknifeattack.lua`

Very similar to `SKKnifeAttack` (Serial Killer knife behavior), adapted for the Hidden's specifics.

#### Differences from SKKnifeAttack

| Aspect | SKKnifeAttack | HiddenKnifeAttack |
|---|---|---|
| **Role check** | `serialkiller` | `hidden` + stalker mode check |
| **Weapon class** | `weapon_ttt_sk_knife` | `weapon_ttt_hd_knife` |
| **Damage** | 40/hit, instant-kill < 50 HP | 60/hit, instant-kill < 65 HP |
| **Knife availability** | Always available | May be on cooldown (15s after throw) |
| **Cloak awareness** | N/A | Bot should prefer attacking from behind (cloak breaks on attack) |
| **Witness tolerance** | 1 | 0-1 (Hidden is more fragile once revealed) |

#### Target Rating Adjustments

```
function rateTarget(bot, target):
    - Base: prefer close targets (knife is melee)
    - Bonus: wounded targets (instant-kill < 65 HP) — HIGHER threshold than SK
    - Bonus: visible targets
    - Penalty: per nearby witness (STRONGER penalty than SK — Hidden relies on stealth)
    - Bonus: target NOT facing bot (backstab bonus — cloak advantage)
    - Bonus: target is stunned (ttt2_hdnade_stun NWBool) — easy kill
    - Penalty: target is in a group
```

#### Engagement Flow

1. Find best target (rate isolation + stunned + facing away).
2. Navigate toward target using locomotor.
3. When within 120 units and target is not facing bot:
   - Equip `weapon_ttt_hd_knife`.
   - Pause auto-switch.
   - Look at target's body center.
   - Assign as `attackTarget` for AttackTarget behavior to execute the M1 attack.
4. Return SUCCESS → AttackTarget takes over.

### 6.3 `HiddenKnifeThrow` — Thrown Knife Attack

**File:** `behaviors/hiddenknifethrow.lua`

Use M2 (secondary fire) to throw the knife at targets that are:
- Wounded but fleeing (out of melee range).
- At medium range (150-500 units) and visible.
- Stunned by a grenade (easy hit).

#### Key Design Decisions

- **Only throw when the target is likely to die** (HP < 60 + distance bonus). The 15s cooldown means wasting a throw is very costly.
- **Never throw if another target is within melee range** — melee is always preferred (no cooldown on M1 hit).
- **Projectile aiming:** The knife is a physics projectile with arc. The bot should aim slightly above the target's center mass to compensate. Use `loco:LookAt(targetPos + Vector(0, 0, 20))` for slight upward aim.

#### Engagement Flow

1. Validate: Hidden + stalker mode + has `weapon_ttt_hd_knife` + no melee target available.
2. Find wounded target at 150-500 unit range.
3. Equip knife, look at target (elevated aim).
4. Press M2 (secondary attack) via `loco:StartAttack2()`.
5. Hold for 0.2s, release.
6. Return SUCCESS. Knife is now on cooldown — tree will fall through to Stalk/Wander.

### 6.4 `HiddenStunNade` — Stun Grenade Usage

**File:** `behaviors/hiddenstunnade.lua`

Very similar to `SKShakeNade`, adapted for the Hidden's stun grenade.

#### Tactical Scenarios

| Scenario | Trigger | Throw Target |
|---|---|---|
| **Escape** | Being attacked / low HP | Own position (stun pursuers) |
| **Pre-kill** | 2+ enemies grouped | Center of enemy cluster |
| **Cover** | After a kill with witnesses approaching | Between self and witnesses |
| **Setup** | About to engage a target | At target's position (stun before knife attack) |

#### Key Differences from SKShakeNade

| Aspect | SKShakeNade | HiddenStunNade |
|---|---|---|
| **Weapon class** | SK knife M2 | `weapon_ttt_hd_nade` (separate weapon) |
| **Fire method** | M2 on knife | M1 (primary fire, standard grenade throw) |
| **Cooldown** | 12s (knife clip) | 30s ConVar (nade respawns after delay) |
| **Effect** | Screen shake + smoke | Blast damage + motion blur stun |
| **Ammo check** | Knife clip > 0 | Bot has `weapon_ttt_hd_nade` in inventory |
| **Post-throw** | Switch back to knife | Switch back to knife (if available) |

#### Stun Grenade Availability Check

```lua
local function hasStunNade(bot)
    return bot:HasWeapon("weapon_ttt_hd_nade")
end
```

The nade weapon is **removed from inventory** when thrown (via the base grenade system) and is **re-given** by the server after the `ttt2_hdn_nade_delay` timer. So the check is simply whether the bot currently possesses the weapon.

---

## 7. Detailed Implementation — Stalk Exemption

### Location: `behaviors/stalk.lua` → `Stalk.Validate()`

The Hidden (in stalker mode) should be **exempt from the late-game stalking phase gate**, same as the Serial Killer and Infected Host. Stalking IS the Hidden's core mechanic.

#### Exact Change

In the `PHASE.LATE or PHASE.OVERTIME` branch of `Stalk.Validate()`:

```lua
-- EXISTING (around line 135-155):
local isInfectedHost = TTTBots.Roles.IsInfectedHost
    and TTTBots.Roles.IsInfectedHost(bot)
local isSerialKiller = bot.GetRoleStringRaw
    and bot:GetRoleStringRaw() == "serialkiller"
local isNecroMaster = TTTBots.Roles.IsNecroMaster
    and TTTBots.Roles.IsNecroMaster(bot)

-- ADD after isNecroMaster:
local isHiddenStalker = TTTBots.Roles.IsHiddenStalker
    and TTTBots.Roles.IsHiddenStalker(bot)

-- UPDATE the conditional:
if isInfectedHost or isSerialKiller or isNecroMaster or isHiddenStalker then
    -- Allow stalking to continue for these roles at all phases
```

**Note:** The exemption only applies when in stalker mode (`IsHiddenStalker` checks NWBool). Pre-transformation Hidden bots should NOT be exempt — they should behave like innocent-likes and not stalk.

---

## 8. Detailed Implementation — Grenade Reaction Hook

### Non-Hidden Bots Reacting to Stun Grenades

When the Hidden throws a stun grenade (`ttt_hdnade_proj`), nearby non-Hidden bots should attempt to flee the area, similar to the SK shake nade reaction hook.

#### Hook: `OnEntityCreated`

```lua
hook.Add("OnEntityCreated", "TTTBots.Hidden.StunNadeReaction", function(ent)
    timer.Simple(0, function()
        if not IsValid(ent) then return end
        if ent:GetClass() ~= "ttt_hdnade_proj" then return end
        if not TTTBots.Match.RoundActive then return end

        local nadePos = ent:GetPos()
        local STUN_RADIUS = 350  -- slightly larger than 256 blast radius

        for _, bot in ipairs(TTTBots.Bots) do
            if not (IsValid(bot) and TTTBots.Lib.IsPlayerAlive(bot)) then continue end

            -- Skip Hidden bots — they threw it
            local role = TTTBots.Roles.GetRoleFor(bot)
            if role and role:GetName() == "hidden" then continue end

            local dist = bot:GetPos():Distance(nadePos)
            if dist > STUN_RADIUS then continue end

            -- Add danger zone to memory
            local memory = bot:BotMemory()
            if memory and type(memory.AddDangerZone) == "function" then
                memory:AddDangerZone(nadePos, STUN_RADIUS, "hidden_stun_nade", CurTime() + 8)
            end

            -- Flee away from the nade
            local loco = bot:BotLocomotor()
            if loco then
                local fleeDir = (bot:GetPos() - nadePos):GetNormalized()
                local fleePos = bot:GetPos() + fleeDir * 400
                loco:SetGoal(fleePos)
            end
        end
    end)
end)
```

**Placement:** This hook should go in `roles/hidden.lua` alongside the role registration (same pattern as SK shake nade reaction in `skshakenade.lua`).

---

## 9. Detailed Implementation — Perception / Invisibility Awareness

### 9.1 Problem

The Hidden's cloaking makes them nearly invisible to human players. However, bots use trace-based visibility checks (`bot:Visible(target)`) that ignore render mode / material changes. Without modification, bots will see a cloaked Hidden as if they were fully visible.

### 9.2 Proposed Solution

Add a perception hook that **reduces effective visibility range** against a cloaked Hidden.

#### Hook: Modify visibility check results

In `roles/hidden.lua`, add a hook into the bot perception system:

```lua
--- Reduce bot detection range against cloaked Hidden players.
--- When a Hidden is in full cloak mode, bots can only "see" them within
--- a very short range (simulating the heatwave distortion).
hook.Add("TTTBots.Visibility.CanSee", "HiddenCloakPerception", function(bot, target)
    if not IsValid(target) or not target:IsPlayer() then return end
    if target:GetSubRole() ~= ROLE_HIDDEN then return end
    if not target:GetNWBool("ttt2_hd_stalker_mode", false) then return end

    local dist = bot:GetPos():Distance(target:GetPos())

    -- Full cloak (not taking damage): only visible within 150 units
    -- Partial cloak (recently damaged): visible within 400 units
    local cloakTimeout = target.hiddenCloakTimeout
    local isPartialCloak = cloakTimeout and cloakTimeout > CurTime()

    local maxDetectionRange = isPartialCloak and 400 or 150

    if dist > maxDetectionRange then
        return false  -- Bot cannot see the cloaked Hidden
    end
end)
```

**Note:** This depends on whether TTT2-Bots-2 has a `TTTBots.Visibility.CanSee` hook point. If not, the alternative is to modify `sv_perception.lua` to check for the Hidden's NWBool and reduce the visibility range constant for that specific target. This would require a targeted modification:

#### Alternative: Direct Perception Modification

If no hook point exists, add a check in the perception update loop:

```lua
-- In the visibility/threat detection logic:
local function getEffectiveVisRange(bot, target)
    local baseRange = TTTBots.Lib.BASIC_VIS_RANGE  -- typically 2048-3000

    -- Hidden cloaking reduces detection range
    if IsValid(target) and target:IsPlayer()
       and target.GetNWBool
       and target:GetNWBool("ttt2_hd_stalker_mode", false) then
        local cloakTimeout = target.hiddenCloakTimeout
        local isPartialCloak = cloakTimeout and cloakTimeout > CurTime()
        return isPartialCloak and 400 or 150
    end

    return baseRange
end
```

### 9.3 Impact on Bot-vs-Bot Gameplay

Without this perception modification:
- Bots will perfectly track a cloaked Hidden, making the invisibility useless.
- The Hidden bot becomes a strictly worse Serial Killer (no radar, no regular weapons).

With the modification:
- Hidden can genuinely sneak up on bot targets.
- Bots will "spot" the Hidden at close range (simulating the heatwave shimmer).
- Taking damage temporarily increases detection range (matching the visual reveal).

---

## 10. Detailed Implementation — Bot Reaction to Hidden Announcement

### 10.1 Problem

When the Hidden transforms, an EPOP announcement fires to all players. Human players react to this (increased alertness, grouping up). Bots should react similarly.

### 10.2 Proposed Hook

```lua
--- When the Hidden activates stalker mode, all non-Hidden bots should
--- increase their alertness / threat level.
hook.Add("PlayerSay", "TTTBots.Hidden.ActivationAwareness", function() end)

-- Better: hook into the NWBool change
hook.Add("Think", "TTTBots.Hidden.MonitorActivation", function()
    -- Check once per second
    if (CurTime() - (TTTBots._lastHiddenCheck or 0)) < 1 then return end
    TTTBots._lastHiddenCheck = CurTime()

    if not TTTBots.Match.RoundActive then return end

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then continue end
        if ply:GetSubRole() ~= ROLE_HIDDEN then continue end
        if not ply:GetNWBool("ttt2_hd_stalker_mode", false) then continue end

        -- Hidden is active — mark this for bot awareness
        if not TTTBots._hiddenActivated then
            TTTBots._hiddenActivated = true

            -- All non-Hidden bots: increase paranoia / group up tendency
            for _, bot in ipairs(TTTBots.Bots) do
                if not IsValid(bot) or not TTTBots.Lib.IsPlayerAlive(bot) then continue end
                local role = TTTBots.Roles.GetRoleFor(bot)
                if role and role:GetName() == "hidden" then continue end

                -- Fire chatter event for awareness
                local chatter = bot:BotChatter()
                if chatter and chatter.On then
                    chatter:On("HiddenSpotted", {}, false)
                end
            end
        end
    end
end)

-- Reset on round start
hook.Add("TTTBeginRound", "TTTBots.Hidden.ResetActivation", function()
    TTTBots._hiddenActivated = false
end)
```

---

## 11. Implementation Checklist

### Phase 1: Core Role Registration
- [ ] Create `lua/tttbots2/roles/hidden.lua`
  - [ ] Role definition via `RoleBuilder.NeutralKiller("hidden", TEAM_HIDDEN)`
  - [ ] Set role properties (no radar, no follower, solo team)
  - [ ] Define `bTreeDisguised` (pre-transformation)
  - [ ] Define `bTreeStalker` (post-transformation)
  - [ ] Implement `getPhaseBasedBTree()` dynamic tree selection
  - [ ] Override `TTTBots.Behaviors.GetTreeFor` (Serial Killer pattern)
  - [ ] Add `TTTBots.Roles.IsHiddenStalker()` global helper
  - [ ] Add role description string
  - [ ] Add stun nade reaction hook (`OnEntityCreated`)
  - [ ] Add Hidden activation monitoring hook (`Think`)
  - [ ] Add round-start reset hook

### Phase 2: Transformation Behavior
- [ ] Create `lua/tttbots2/behaviors/hiddenactivate.lua`
  - [ ] `Validate`: role check, not already in stalker mode, round active, time gate (15s+)
  - [ ] `OnStart`: initialize readiness evaluation
  - [ ] `OnRunning`: calculate readiness score based on alive count, witnesses, health, phase
  - [ ] Score threshold (>= 40) → press IN_RELOAD via locomotor
  - [ ] Verify transformation success (NWBool check)
  - [ ] Fallback: force-transform after 180s regardless
  - [ ] `OnEnd`: cleanup state

### Phase 3: Combat Behaviors
- [ ] Create `lua/tttbots2/behaviors/hiddenknifeattack.lua`
  - [ ] `Validate`: Hidden + stalker mode + has knife + no current attack target
  - [ ] `rateTarget()`: isolation, health, facing direction, stun status
  - [ ] `findBestKnifeTarget()`: iterate all players, score and rank
  - [ ] `OnRunning`: navigate to target, engage at melee range (120u)
  - [ ] Backstab preference (check if target facing away)
  - [ ] Equip knife → assign attackTarget → SUCCESS
  - [ ] Witness check: stricter than SK (0-1 max witnesses)
  - [ ] `OnEnd`: cleanup, resume auto-switch

- [ ] Create `lua/tttbots2/behaviors/hiddenknifethrow.lua`
  - [ ] `Validate`: Hidden + stalker mode + has knife + no melee target available
  - [ ] Only throw at wounded targets (HP < 60) or stunned targets
  - [ ] Range check: 150-500 units (not too close for melee, not too far for accuracy)
  - [ ] Aim compensation: look slightly above target center
  - [ ] M2 attack via `loco:StartAttack2()` / `loco:StopAttack2()`
  - [ ] Post-throw: knife is now on 15s cooldown, behavior becomes unavailable

- [ ] Create `lua/tttbots2/behaviors/hiddenstunnade.lua`
  - [ ] `Validate`: Hidden + stalker mode + has `weapon_ttt_hd_nade`
  - [ ] Scenario detection: escape / pre-kill / cover / setup
  - [ ] Phase system: equip → aim → throw → done
  - [ ] Equip nade weapon, aim at throw position, M1 attack (standard nade throw)
  - [ ] Switch back to knife after throw
  - [ ] `OnEnd`: cleanup, stop attacks, resume auto-switch

### Phase 4: Stalk Integration
- [ ] Modify `lua/tttbots2/behaviors/stalk.lua`
  - [ ] Add `isHiddenStalker` check in `PHASE.LATE`/`PHASE.OVERTIME` exemption block
  - [ ] Only exempt when in stalker mode (not pre-transformation)

### Phase 5: Perception (Optional but Recommended)
- [ ] Add cloaking awareness to bot perception
  - [ ] Determine if hook point exists (`TTTBots.Visibility.CanSee`)
  - [ ] If yes: add hook to reduce detection range for cloaked Hidden
  - [ ] If no: modify `sv_perception.lua` with `getEffectiveVisRange()` helper
  - [ ] Full cloak: 150 unit detection range
  - [ ] Partial cloak (damaged): 400 unit detection range
  - [ ] No cloak (pre-transform): normal detection range

### Phase 6: Polish & Edge Cases
- [ ] Handle role change mid-round (e.g., Swapper → Hidden)
  - [ ] Ensure tree switching works correctly on late role assignment
- [ ] Handle Hidden bot dying pre-transformation
  - [ ] No special handling needed (NeutralKiller defaults apply)
- [ ] Handle knife cooldown gracefully
  - [ ] When knife is on 15s cooldown, tree falls through to Stalk/Wander
  - [ ] Bot should still chase targets (Stalk behavior) even without knife
  - [ ] Once knife respawns, HiddenKnifeAttack re-validates
- [ ] Handle stun nade cooldown (30s)
  - [ ] When nade is on cooldown, HiddenStunNade.Validate returns false
  - [ ] Bot relies on knife-only during cooldown
- [ ] Prevent Hidden bot from buying shop items post-transform
  - [ ] The weapon restriction hook already handles this server-side
  - [ ] Bot inventory system should not attempt purchases in stalker mode

---

## 12. Testing Plan

### 12.1 Unit Tests

| Test | Expected Result |
|---|---|
| Bot assigned Hidden role → correct tree selected | `bTreeDisguised` until transform |
| Bot transforms (IN_RELOAD pressed) → tree switches | `bTreeStalker` after NWBool change |
| `IsHiddenStalker()` returns false pre-transform | Confirmed |
| `IsHiddenStalker()` returns true post-transform | Confirmed |
| Stalk.Validate allows Hidden in LATE/OVERTIME | Confirmed (with stalker mode) |
| Stalk.Validate does NOT exempt pre-transform Hidden | Confirmed |

### 12.2 Integration Tests

| Test | Expected Result |
|---|---|
| Hidden bot blends in during disguised phase | Behaves like innocent: patrols, investigates, chats |
| Hidden bot transforms at appropriate time | Transforms after ~30-120s, when isolated or few players remain |
| Hidden bot never transforms in first 15s | Time gate enforced |
| Hidden bot force-transforms after 180s | Fallback activates |
| Post-transform: bot uses knife melee | Stalks isolated targets, closes to melee range |
| Post-transform: bot throws knife at wounded fleeing target | M2 used when target is 150-500u away and low HP |
| Post-transform: bot throws stun nade | Used in escape, pre-kill, or cover scenarios |
| Post-transform: bot handles knife cooldown | Falls through to Stalk/Wander during 15s cooldown |
| Post-transform: bot handles nade cooldown | Relies on knife-only during 30s cooldown |
| Non-Hidden bots react to EPOP announcement | Increased alertness behavior |
| Non-Hidden bots flee stun nade | AddDangerZone + flee locomotor goal |
| Non-Hidden bots have reduced detection of cloaked Hidden | 150u range for full cloak, 400u for partial |

### 12.3 Gameplay Scenarios

| Scenario | Expected Bot Behavior |
|---|---|
| **8-player round, Hidden is a bot** | Blends in for 30-90s, transforms when 1-2 players have died and bot is isolated. Uses knife to pick off lone targets. Throws stun nade at groups. |
| **Hidden bot vs group of 3** | Throws stun nade first, then rushes in with knife during stun effect. Targets the weakest player first. |
| **Hidden bot being chased** | Uses stun nade behind self to disorient pursuers. Uses speed advantage (1.6×) to break line of sight. Re-cloaks after 5s without damage. |
| **Hidden bot with knife on cooldown** | Stalks targets at safe distance. Engages with Stalk behavior. Switches to HiddenKnifeAttack once knife respawns. |
| **Hidden bot in late game (2 players left)** | Aggressive: directly hunts remaining player with knife. No stealth concerns. |
| **Bot encounters cloaked Hidden** | Does not detect at > 150u. Detects at < 150u. Fights back when Hidden attacks (partial cloak at 400u range). |

---

## Appendix A: File Summary

| File | Action | Description |
|---|---|---|
| `lua/tttbots2/roles/hidden.lua` | **CREATE** | Role registration, tree switching, hooks |
| `lua/tttbots2/behaviors/hiddenactivate.lua` | **CREATE** | Transformation decision behavior |
| `lua/tttbots2/behaviors/hiddenknifeattack.lua` | **CREATE** | Melee knife kill behavior |
| `lua/tttbots2/behaviors/hiddenknifethrow.lua` | **CREATE** | Thrown knife behavior |
| `lua/tttbots2/behaviors/hiddenstunnade.lua` | **CREATE** | Stun grenade behavior |
| `lua/tttbots2/behaviors/stalk.lua` | **MODIFY** | Add Hidden stalker exemption to late-game gate |
| `lua/tttbots2/lib/sv_perception.lua` | **MODIFY** (optional) | Add cloaking detection range reduction |

## Appendix B: Reference — Similar Implementations

| Pattern | Reference File | Relevance |
|---|---|---|
| NeutralKiller role registration | `roles/serialkiller.lua` | Team setup, NeutralKiller preset |
| Dynamic tree switching | `roles/serialkiller.lua` (`getPhaseBasedBTree`) | Two-tree pattern with GetTreeFor override |
| Melee knife behavior | `behaviors/skknifeattack.lua` | Target rating, engagement flow, witness checks |
| Grenade throw behavior | `behaviors/skshakenade.lua` | Phase-based throw (equip→aim→throw→done) |
| Grenade reaction hook | `behaviors/skshakenade.lua` (`OnEntityCreated`) | Flee + danger zone pattern |
| Role weapon factory | `behaviors/meta_roleweapon.lua` | Reference for weapon equip/fire patterns |
| Stalk exemption | `behaviors/stalk.lua` (line ~137-155) | IsInfectedHost/isSerialKiller pattern |
| Role builder preset | `lib/sv_rolebuilder.lua` | NeutralKiller factory method |
