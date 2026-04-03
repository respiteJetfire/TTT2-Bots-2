# Smart Bullets SWEP — TTT2 Bot Integration Analysis

## Purpose

This document analyzes:

- the custom Smart Bullets SWEP addon in `TTT2 Weapons/ttt2_smart_bullets_swep`
- how traitor bots should learn to buy, equip, activate, and fight with Smart Bullets
- how all other bots should detect, react to, and counter an enemy using Smart Bullets
- integration points within the TTT2 Bots architecture (inventory, combat, buyables, chatter, evidence, morality)
- a practical implementation roadmap with checklist tasks and strategies

---

## Executive Summary

The Smart Bullets SWEP is a **traitor-only one-time-use equipment item** (`weapon_ttt2_smart_bullets`). When activated via primary fire, the weapon is consumed and the player gains a timed buff (default 15 seconds) that silently redirects all their bullets to the nearest visible enemy's head — but only after acquiring a Titanfall-style lock-on (default 0.6s aim-cone tracking). All players can see extremely visible red tracer beams and hear distinctive energy zap sounds when locked-on shots are fired.

### What This Means for Bots

**Offensively (traitor bot using Smart Bullets):**
- The bot must learn to **buy** the item from the traitor shop
- The bot must learn to **activate** it at the right moment (not waste the timed buff)
- Once active, the bot should understand that its bullets auto-redirect — it benefits from **aggressive pushing**, **rapid firing**, and **target acquisition** rather than careful aiming
- The lock-on system requires briefly holding aim on a target (~0.6s) before bullets redirect — the bot should **hold aim on one target** rather than flicking between enemies

**Defensively (all bots reacting to Smart Bullets):**
- The bright red tracer beams and zap sounds are visible/audible to ALL players
- Bots should recognize these distinctive tracers as **evidence of Smart Bullets usage**
- A player producing perfectly accurate headshots with visible energy tracers is almost certainly a traitor
- Bots should increase suspicion / generate evidence when witnessing Smart Bullet tracers
- Bots should try to **break line of sight**, **increase distance**, or **group up** against a Smart Bullets user
- Bots should understand the buff is temporary — if they survive the duration, the threat drops

### Bottom Line

The Smart Bullets SWEP requires **two-sided integration**: traitor bots need to use it intelligently, and all other bots need to recognize and react to it as a major threat indicator and near-certain traitor reveal.

---

# 1. Smart Bullets Addon Analysis

## 1.1 Weapon Identity and Mechanics

| Property | Value |
|----------|-------|
| Classname | `weapon_ttt2_smart_bullets` |
| Kind | `WEAPON_EQUIP` (equipment slot) |
| Buyable By | `ROLE_TRAITOR` only |
| Base | `weapon_tttbase` |
| Model | SLAM model (placeholder) |
| LimitedStock | `false` (can buy multiple per round) |
| AllowDrop | `false` (cannot be dropped) |
| Activation | Primary fire — consumes the weapon |
| Effect | Timed buff on the player (not the weapon) |

### Core Mechanic Flow

```
1. Traitor buys weapon_ttt2_smart_bullets from shop
2. Traitor equips and presses primary fire
3. Weapon is consumed (stripped from inventory)
4. Player gains ttt2_smart_bullets_active = true
5. Lock-on system activates:
   a. Player aims within ~18° cone of an enemy
   b. After lock_delay seconds (default 0.6), lock completes
   c. All bullets from ANY held weapon redirect to locked target's head
   d. Bullets have zero spread — guaranteed headshots
6. Bright red tracer beams + zap sounds broadcast to ALL players
7. After duration expires (default 15s), effect ends
8. Effect also ends on player death or round end
```

### Key Server-Side State Variables

| Variable | Type | Scope | Description |
|----------|------|-------|-------------|
| `ply.ttt2_smart_bullets_active` | `boolean/nil` | Server + NW | Whether the buff is currently active |
| `ply:GetNWBool("ttt2_smart_bullets_active")` | `bool` | Networked | Client-readable active state |
| `ply:GetNWFloat("ttt2_smart_bullets_expire_time")` | `float` | Networked | CurTime() when the buff expires |
| `ply.ttt2_smart_bullets_lock_target` | `Entity/nil` | Server | Currently tracked lock target |
| `ply.ttt2_smart_bullets_lock_start` | `float/nil` | Server | When lock tracking began |
| `ply.ttt2_smart_bullets_locked` | `boolean/nil` | Server | Whether lock is fully acquired |
| `ply:GetNWFloat("ttt2_smart_bullets_lock_progress")` | `float` | Networked | Lock progress 0–1 |
| `ply:GetNWEntity("ttt2_smart_bullets_lock_entity")` | `Entity` | Networked | Entity being locked onto |

### ConVars

| ConVar | Default | Range | Description | Bot Relevance |
|--------|---------|-------|-------------|---------------|
| `ttt2_smart_bullets_duration` | `15` | 1–120 | Seconds the buff lasts | Determines urgency window for activation and enemy reaction |
| `ttt2_smart_bullets_lock_delay` | `0.6` | 0.1–5.0 | Seconds to hold aim before lock completes | Bot must hold aim on target for this duration |

---

## 1.2 Lock-On System Deep Dive

The lock-on system is the core mechanic that differentiates Smart Bullets from generic aimbot behavior. Understanding it is critical for bot integration.

### FindAimedEnemy — Lock Acquisition

```
- Iterates all players
- Skips: self, dead, spectators, teammates (HasTeam + IsInTeam)
- Requires: target within ~18° cone (dot > 0.95) of aim direction
- Requires: line-of-sight (TraceLine with MASK_SHOT)
- Returns: the best (highest dot product) visible enemy in cone
```

**Bot implication:** The bot must look toward an enemy and hold aim within the cone for `lock_delay` seconds. The existing `AttackTarget` behavior already points the bot at enemies, so the lock system should work passively — BUT the bot needs to avoid rapidly switching targets during the lock window.

### FindNearestEnemy — Bullet Redirection

Once locked, bullets redirect to the **lock target's head**, NOT the nearest enemy. The `FindNearestEnemy` function exists in the code but the `EntityFireBullets` hook actually uses the locked target specifically.

**Bot implication:** Once locked, the bot can fire any weapon and bullets will hit the locked target's head. The bot should fire its strongest weapon during the lock window.

### Lock State Machine

```
No Target → Acquiring (0% → 100% over lock_delay) → LOCKED
         ↑                                            │
         └────────── Target lost / changed ───────────┘
```

- Looking at a new target resets lock progress to 0%
- Looking away from all targets clears lock state entirely
- Lock persists as long as the same target remains in the aim cone
- Lock-on confirmation plays `buttons/button17.wav` at pitch 150 (distinctive high beep)

---

## 1.3 Tracer / Visual Tell System

The tracer system is **the primary defensive intelligence source** for other bots.

### What ALL Players See When Smart Bullets Fire

1. **Extremely visible red energy beam** from shooter's position to target's head
   - Multi-layered rendering: outer glow (48px), middle glow (28px), inner core (6px), white center (2.4px)
   - Persists for 0.45 seconds per shot
   - Dynamic lights at both muzzle and impact
   - Pulsing animation effect

2. **Impact effects at the target**
   - ManhackSpark particle effect
   - Additional Sparks particle effect
   - Bright flash sprite at impact

3. **Distinctive sounds**
   - `ambient/energy/zap1-9.wav` at impact (audible within 2000 units)
   - `ambient/energy/spark1-6.wav` at muzzle (audible within 1500 units)
   - `buttons/button17.wav` on lock-on confirmation (audible within ~40 units of shooter)

4. **Activation sound** — `buttons/button9.wav` on initial activation

### Why This Matters for Bot Detection

The tracers are **intentionally designed to be unmissable**. They:
- Use bright red/orange colors that contrast with all map environments
- Have extremely wide beam widths (up to 48 pixels)
- Create dynamic lighting on nearby surfaces
- Produce distinctive electrical sounds audible at significant range
- Travel instantly in a straight line from shooter to target head

This means any bot that is within visual or audio range of a Smart Bullets user should have strong evidence that:
1. Something abnormal is happening (energy beams, not normal bullet tracers)
2. The shooter is using non-standard technology (traitor equipment)
3. The shooter's bullets are hitting heads with unnatural accuracy

---

## 1.4 Addon Stability Assessment

### Strengths

- Clean ConVar creation with proper flags (`FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED`)
- Proper cleanup on round end, player death, and disconnect
- NWVar usage for client sync
- Team-aware lock targeting (`HasTeam` + `IsInTeam` checks)
- `AddCSLuaFile()` calls present where needed

### Potential Issues

1. **SteamID64 on bots:** `ply:SteamID64()` may return `"0"` or `nil` for bots, but the timer name uses it. The code has a fallback (`or "0"`) which means all bots would share the same timer name `"TTT2SmartBullets_Expire_0"`. This could cause timer collisions if multiple bots activate Smart Bullets.

   **Impact on bots:** If two bots activate Smart Bullets, the second bot's expiry timer would overwrite the first bot's timer, potentially leaving the first bot's Smart Bullets active permanently (until death/round end).

   **Recommended fix:** Use `ply:EntIndex()` or `ply:UserID()` as fallback instead of `"0"`.

2. **Lock cone targeting uses `GetShootPos()` and `GetAimVector()`:** These work for bots because GMod's bot system sets aim angles via `bot:SetEyeAngles()`, which is what the locomotor does. ✅ This should work correctly.

3. **Team checks use `HasTeam()` and `IsInTeam()`:** These are TTT2 team functions. If a role doesn't properly set its team, the lock system could accidentally target teammates. Standard TTT2 roles handle this correctly.

4. **No check for `ply:IsBot()`:** The addon doesn't restrict or modify behavior for bots vs humans. This is correct — bots should get the same behavior.

---

# 2. Bot Architecture Integration Points

## 2.1 Buyable System — Traitor Bots Purchasing Smart Bullets

The primary integration point is `data/sv_default_buyables.lua`. Smart Bullets should be registered as a buyable item for traitor bots.

### Smart Bullets Buyable Properties

| Property | Recommended Value | Rationale |
|----------|------------------|-----------|
| Name | `"Smart Bullets"` | Display name for chatter/announcements |
| Class | `"weapon_ttt2_smart_bullets"` | Weapon classname |
| Price | `1` | Standard equipment cost |
| Priority | `3` | Medium-high — strong but situational |
| RandomChance | `1` | Always available as an option |
| ShouldAnnounce | `true` | Announce purchase to team |
| PrimaryWeapon | `false` | It's equipment, not a primary weapon |
| Roles | Traitor team roles | Only traitors can buy it |

### Purchase Decision Logic

Smart Bullets are most valuable when:
- The traitor bot **already has a good weapon to use during the buff** (rifle, pistol, SMG)
- There are **multiple enemies alive** (more lock-on targets)
- The bot is **about to engage** or is already in combat (maximizes buff window)
- The bot is **not already carrying two equipment items** (slot limit)

Smart Bullets are less valuable when:
- The bot only has a crowbar (no weapon to fire during the buff)
- There are very few enemies left (1v1 — less need for auto-aim, and the tracer reveals you)
- The bot is trying to be stealthy (the tracers are extremely visible)

### Suggested `CanBuy` Logic

```lua
CanBuy = function(ply)
    -- Don't buy if already active
    if ply.ttt2_smart_bullets_active then return false end
    -- Don't buy if we already have it in inventory
    if ply:HasWeapon("weapon_ttt2_smart_bullets") then return false end
    -- Prefer bots with aggressive or gimmick traits
    return testPlyHasTrait(ply, "aggressive", 4)
        or testPlyHasTrait(ply, "gimmick", 3)
        or testPlyHasTrait(ply, "tryhard", 5)
end
```

### Suggested `SituationalScore` Logic

```lua
SituationalScore = function(ply)
    local base = 5
    -- More enemies alive = more value
    local enemies = countAliveNonAllies(ply)
    if enemies >= 3 then base = base + 2 end
    if enemies >= 5 then base = base + 3 end
    -- Currently in combat = higher urgency
    if IsValid(ply.attackTarget) then base = base + 4 end
    -- Has a good weapon to pair with = higher value
    local inv = ply:BotInventory()
    if inv then
        local primary = inv:GetBestPrimary()
        if primary and primary.dps and primary.dps > 80 then
            base = base + 3
        end
    end
    return base
end
```

---

## 2.2 Inventory System — Handling the Equipment Item

The Smart Bullets weapon (`weapon_ttt2_smart_bullets`) is a `WEAPON_EQUIP` kind item. It has:
- No clip (`ClipSize = -1`)
- No ammo (`Ammo = "none"`)
- `AllowDrop = false`
- It is consumed on activation (stripped after primary fire)

### Current Inventory Behavior

The inventory system in `sv_inventory.lua` evaluates weapons using `GetWeaponInfo()`. For `weapon_ttt2_smart_bullets`:

| Field | Value | Notes |
|-------|-------|-------|
| `is_gun` | `false` | ClipSize -1, no ammo → not a gun |
| `is_melee` | `true` | clip == -1 and slot != "grenade" → classified as melee |
| `kind` | `WEAPON_EQUIP` | Equipment slot |
| `damage` | `0` or `1` | No primary damage defined |
| `dps` | `0` or `1` | No meaningful DPS |
| `slot` | `"special"` or `"extra"` | Equipment slot string |

### Inventory Integration Needs

1. **Do NOT score this weapon for combat** — It's a utility activator, not a combat weapon. The bot should never try to attack with it during `AttackTarget`.

2. **Activation behavior** — The bot needs a dedicated behavior or sub-behavior that:
   - Recognizes the bot has `weapon_ttt2_smart_bullets` in inventory
   - Switches to it at the right tactical moment
   - Fires primary attack to activate
   - Immediately switches back to a combat weapon
   - Does NOT try to fire the SWEP at enemies as if it were a gun

3. **Post-activation awareness** — After activation, the inventory system should know:
   - The weapon has been consumed (it's stripped after 0.1s)
   - The bot now has `ttt2_smart_bullets_active = true`
   - The bot's current weapons now have guaranteed headshot capability (for the duration)
   - The bot should NOT waste time reloading during the buff window

---

## 2.3 Combat System — Fighting With Smart Bullets Active

Once Smart Bullets are active, the bot's combat behavior changes significantly.

### Behavioral Changes During Smart Bullets Buff

| Aspect | Normal Behavior | Smart Bullets Active |
|--------|----------------|---------------------|
| **Aiming** | Body/head targeting based on personality | Hold aim toward target for lock-on, then fire |
| **Target switching** | Switch to best tactical target | HOLD current target for lock_delay, don't flick |
| **Weapon choice** | Best weapon by DPS/situation | Use highest-DPS weapon (bullets auto-headshot anyway) |
| **Distance** | Maintain optimal range | Push aggressively (auto-aim means range doesn't matter as much) |
| **Inaccuracy** | Personality-based scatter | Reduced importance (bullets redirect) but still need aim cone |
| **Reload** | Reload when clip empty | Minimize reload time — switch weapons instead if possible |
| **Fire rate** | Normal | Maximize fire rate — every bullet is a guaranteed headshot |
| **Retreat** | When low health/ammo | Less likely to retreat — buff is temporary, maximize kills |

### AttackTarget Integration

The `attacktarget.lua` behavior needs to know about Smart Bullets to modify:

1. **`ShouldLookAtBody`** — When Smart Bullets are active, bullets redirect to head anyway. The bot should aim at center mass (body) since the lock system only requires being in the aim cone (~18°), not precise head aim. Return `true` (body shot mode).

2. **`CalculateInaccuracy`** — When Smart Bullets are active and locked, inaccuracy is irrelevant because `EntityFireBullets` overrides the direction. Reduce scatter to minimal or zero.

3. **`LookingCloseToTarget`** — The lock cone is ~18°, which is wider than the normal fire threshold (10°). When Smart Bullets are active, the threshold should be widened to match.

4. **`GetIdealApproachDistance`** — Normal weapons benefit from range management. Smart Bullets guarantee headshots at any range, so the bot can be more aggressive about closing distance (to prevent the target from breaking LOS).

5. **Target switching** — During the lock acquisition phase (0.6s), the bot should NOT switch targets. Switching resets lock progress. Add a "lock hold" window where target switching is suppressed.

### Suggested AttackTarget Modifications

Add `weapon_ttt2_smart_bullets` awareness to the existing weapon-class-specific handling:

```lua
-- In AGGRESSIVE_WEAPON_CLASSES (conceptual — Smart Bullets is a buff, not a weapon class)
-- Instead, check bot.ttt2_smart_bullets_active on the bot entity

-- ShouldLookAtBody: favor body shots (aim cone is wide enough)
if bot.ttt2_smart_bullets_active then
    return true -- body shot mode — lock cone handles the rest
end

-- CalculateInaccuracy: minimal scatter during active Smart Bullets
if bot.ttt2_smart_bullets_active and bot.ttt2_smart_bullets_locked then
    return VectorRand() * 0.15 -- near-zero scatter
end

-- LookingCloseToTarget: widen threshold during Smart Bullets
if bot.ttt2_smart_bullets_active then
    threshold = 20 -- wider to match lock cone
end
```

---

## 2.4 New Behavior: ActivateSmartBullets

A new behavior node is needed to handle the activation sequence.

### Behavior Design

**Name:** `ActivateSmartBullets`
**Description:** "Activating smart bullets"
**Interruptible:** `false` (brief — don't interrupt mid-activation)

### Validate Conditions

The behavior should activate when:
1. The bot has `weapon_ttt2_smart_bullets` in its inventory
2. The bot does NOT already have `ttt2_smart_bullets_active == true`
3. The bot is in a suitable tactical situation (has a target, is about to engage, or round is progressing)
4. The bot has at least one real weapon to fire after activation

### Action Sequence

```
1. Select weapon_ttt2_smart_bullets
2. Wait one tick for weapon switch
3. Fire primary attack (IN_ATTACK)
4. Wait 0.1s for weapon strip
5. Switch to best combat weapon
6. Resume normal combat (with Smart Bullets buff now active)
```

### Timing Considerations

When should the bot activate Smart Bullets?

| Situation | Should Activate? | Reasoning |
|-----------|-----------------|-----------|
| About to push into known enemy area | ✅ Yes | Maximizes buff value during engagement |
| Currently in active firefight | ✅ Yes (if brief pause is safe) | Immediate combat advantage |
| Just spawned, no enemies nearby | ❌ No | Wastes buff duration walking around |
| 1v1 final confrontation | ⚠️ Maybe | Overkill but guarantees the win |
| Trying to be stealthy | ❌ No | Tracers reveal you instantly |
| Multiple enemies visible | ✅ Yes | Lock system handles target acquisition |

### Suggested Validate Logic

```lua
function ActivateSmartBullets.Validate(bot)
    -- Must have the weapon
    if not bot:HasWeapon("weapon_ttt2_smart_bullets") then return false end
    -- Must not already be active
    if bot.ttt2_smart_bullets_active then return false end
    -- Must have a real weapon to use after activation
    local inv = bot:BotInventory()
    if not inv then return false end
    local hasCombatWeapon = inv:HasPrimary() or inv:HasSecondary()
    if not hasCombatWeapon then return false end
    -- Tactical check: have a target or expect combat soon
    local hasTarget = IsValid(bot.attackTarget)
    local inCombatZone = bot.dangerLevel and bot.dangerLevel > 0.5
    return hasTarget or inCombatZone
end
```

---

## 2.5 New Behavior: SmartBulletsAggression

Once Smart Bullets are active, the bot should shift to a more aggressive combat posture for the duration of the buff.

### Behavior Design

**Name:** `SmartBulletsAggression`
**Description:** "Exploiting smart bullets buff"
**Interruptible:** `true` (standard combat interruption)

### Purpose

This behavior overrides normal combat pacing to maximize the buff window:
- Push toward enemies instead of holding position
- Minimize downtime between engagements
- Seek new targets immediately after a kill
- Fire rapidly — every bullet is a guaranteed headshot
- Don't waste time reloading — switch weapons if current clip is empty

### Validate Conditions

```lua
function SmartBulletsAggression.Validate(bot)
    return bot.ttt2_smart_bullets_active == true
        and bot:IsActive()
        and IsValid(bot.attackTarget)
end
```

### Integration With AttackTarget

Rather than a fully separate behavior, this could be implemented as a **modifier layer** within AttackTarget that checks `bot.ttt2_smart_bullets_active` and adjusts:

- Approach distance → shorter (push harder)
- Reload behavior → skip reload, switch weapons
- Target hold time → minimum 0.6s on each target (respect lock delay)
- Fire threshold angle → wider (lock cone handles aim)
- Retreat threshold → higher (don't retreat during buff)

This approach is recommended over a separate behavior because it avoids duplicating combat logic.

---

## 2.6 Evidence / Morality — Detecting Smart Bullets Usage

### What Other Bots Can Observe

The Smart Bullets addon broadcasts tracer effects to ALL clients via `net.Broadcast()`. On the server side, the `EntityFireBullets` hook returns `true` (indicating modified bullet data). The distinctive behaviors are:

1. **Network message `TTT2SmartBullets_Tracer`** — Sent to all clients on every locked shot
2. **Zero-spread headshots** — Every bullet hits the locked target's head exactly
3. **Activation sound** — `buttons/button9.wav` when initially activated
4. **Lock-on sound** — `buttons/button17.wav` at pitch 150 when lock completes

### Server-Side Detection for Bots

Bots operate on the server. The most reliable detection method is to hook into the server-side state:

#### Method 1: Check NWBool (Simplest)

```lua
-- Any bot can check if a player has Smart Bullets active:
local hasSmartBullets = suspectPlayer:GetNWBool("ttt2_smart_bullets_active", false)
```

This is a "cheat" detection — bots reading networked state directly. It should be gated behind a ConVar like `tttbots_cheat_detect_equipment` to allow server operators to control how smart bots are.

#### Method 2: Observe Tracer Effects (More Realistic)

Hook into the `TTT2SmartBullets_Tracer` network message processing. Since this broadcasts to all clients, a server-side hook could be added that fires when Smart Bullets tracers occur, notifying nearby bot evidence systems.

```lua
-- Server-side hook that fires when Smart Bullets tracers are broadcast
hook.Add("EntityFireBullets", "TTTBots_DetectSmartBullets", function(ent, data)
    if not IsValid(ent) or not ent:IsPlayer() then return end
    if not ent.ttt2_smart_bullets_active then return end
    if not ent.ttt2_smart_bullets_locked then return end

    -- Notify all nearby bots that this player is using Smart Bullets
    for _, bot in ipairs(player.GetAll()) do
        if not bot:IsBot() then continue end
        if not TTTBots.Lib.IsPlayerAlive(bot) then continue end
        if bot == ent then continue end

        -- Check if bot can see the shooter or is within audio range
        local dist = bot:GetPos():DistToSqr(ent:GetPos())
        local canSee = bot:VisibleVec(ent:GetShootPos())
        local canHear = dist < (2000 * 2000) -- tracer zap sound range

        if canSee or canHear then
            -- Inject evidence: this player is using traitor equipment
            -- Implementation depends on evidence system API
        end
    end
end)
```

#### Method 3: Observe Damage Patterns (Most Realistic)

Track per-player damage patterns. If a player consistently lands headshots with zero scatter across multiple kills in rapid succession, that's suspicious even without reading NWVars.

This is the most computationally expensive but most "fair" detection method.

### Recommended Evidence Rules

| Observation | Suspicion Increase | Confidence | Notes |
|-------------|-------------------|------------|-------|
| See Smart Bullet tracers from a player | +0.6 | High | Distinctive red energy beams are unmistakable |
| Hear zap/spark sounds near a player | +0.3 | Medium | Could be environmental, but distinctive |
| Witness instant headshot kill with energy beam | +0.8 | Very High | Near-certain traitor equipment usage |
| Player activated Smart Bullets (button9 sound nearby) | +0.2 | Low | Sound alone is ambiguous |
| Multiple headshot kills in rapid succession | +0.5 | High | Pattern recognition (no NWVar needed) |

### Suspicion → KOS Escalation

If a bot accumulates enough Smart Bullets evidence, it should:
1. Internally mark the player as "likely traitor"
2. Call KOS in chat if confident enough
3. Prioritize engaging the Smart Bullets user while the buff is active (dangerous to leave alive)
4. OR avoid the Smart Bullets user entirely during the buff window and engage after it expires

The choice between "fight now" and "wait it out" should depend on:
- Bot personality (aggressive → fight, cautious → wait)
- Team situation (many allies → focus fire, alone → evade)
- Remaining buff duration (if < 3s, push; if > 10s, evade)

---

## 2.7 Defensive Reactions — All Bots vs Smart Bullets User

### Tactical Responses

When a bot detects an enemy with active Smart Bullets, it should consider several defensive strategies:

#### Strategy 1: Break Line of Sight (Recommended Default)

Smart Bullets require **line of sight for lock-on** and **visibility for bullet redirection**. If the bot can't be seen, it can't be locked.

- Move behind cover
- Use smoke grenades if available
- Stay behind walls/corners
- Avoid open areas

#### Strategy 2: Increase Distance

While Smart Bullets guarantee headshots at any range, the lock system requires the target to be within the shooter's **aim cone** (~18°). At extreme distances, even being in the cone is harder because small angular movements cover large ground distances.

- Back away from the Smart Bullets user
- Put terrain between yourself and the shooter
- Move perpendicular to their aim (harder to track)

#### Strategy 3: Focus Fire (Group Response)

If multiple bots are present, they should coordinate to take down the Smart Bullets user quickly. The user can only lock onto **one target at a time** and must hold aim for 0.6s before the lock completes. Multiple attackers from different angles prevent effective lock-on on all of them simultaneously.

- Call out the Smart Bullets user's position
- Converge from multiple angles
- Trade damage — Smart Bullets user dies faster than they can switch locks

#### Strategy 4: Wait It Out (Cautious/Survival)

The Smart Bullets buff has a limited duration (default 15s). A cautious bot could:
- Hide and survive the duration
- Re-engage after the buff expires
- Monitor the expire time via NWFloat (server-side knowledge)

### Evasion Behavior Modifications

When a bot's attack target has Smart Bullets active, the `AttackTarget` behavior should:

1. **Increase cover-seeking priority** — Prefer positions with nearby cover
2. **Reduce approach aggression** — Don't push into a Smart Bullets user
3. **Use strafing movement** — Move laterally to delay lock acquisition
4. **Consider disengagement** — If bot is alone and low health, fleeing is optimal

---

## 2.8 Chatter Integration

### New Chatter Categories

#### Traitor Bot (Using Smart Bullets)

| Category | Priority | When | Example Lines |
|----------|----------|------|---------------|
| `SmartBulletsActivated` | LOW | Bot activates Smart Bullets | "Time to show them what I've got" (team-only) |
| `SmartBulletsKill` | NORMAL | Bot kills someone during buff | "Too easy" / "Another one" (team-only or public taunt) |
| `SmartBulletsExpired` | LOW | Buff expires | "Back to normal..." (team-only) |

#### Innocent/Detective Bot (Reacting to Smart Bullets)

| Category | Priority | When | Example Lines |
|----------|----------|------|---------------|
| `SmartBulletsDetected` | IMPORTANT | Bot witnesses Smart Bullet tracers | "What was that?! Those aren't normal bullets!" |
| `SmartBulletsKOS` | CRITICAL | Bot identifies shooter as traitor | "KOS {player}! They're using some kind of auto-aim device!" |
| `SmartBulletsWarning` | IMPORTANT | Bot warns others | "Watch out, someone has aimbot bullets!" |
| `SmartBulletsEvade` | NORMAL | Bot is being targeted | "Get to cover! Those bullets are tracking!" |
| `SmartBulletsSurvived` | NORMAL | Buff expires while bot is alive | "I think the smart bullets wore off..." |

### Chatter Event Triggers

```lua
-- On detecting Smart Bullets usage:
TTTBots.Chat.Say(bot, "SmartBulletsDetected", {player = shooter:Nick()})

-- On KOS call after evidence:
TTTBots.Chat.Say(bot, "SmartBulletsKOS", {player = shooter:Nick()})

-- On surviving the buff duration:
if previousSmartBulletsTarget and not previousSmartBulletsTarget.ttt2_smart_bullets_active then
    TTTBots.Chat.Say(bot, "SmartBulletsSurvived")
end
```

### STT / Parser Aliases

If players mention Smart Bullets in voice/text chat, the parser should recognize:
- "smart bullets"
- "smart bullet"
- "auto aim"
- "autoaim"
- "aimbot"
- "aimbot bullets"
- "lock on"
- "lock-on"
- "tracking bullets"
- "homing bullets"
- "red beams"
- "energy beams"
- "red tracers"

These should be normalized to a structured alert about Smart Bullets equipment usage.

---

# 3. Gap Analysis

## 3.1 Critical Gaps (Must Fix for Basic Functionality)

| # | Gap | Description | Impact |
|---|-----|-------------|--------|
| G-1 | **No buyable entry** | Smart Bullets not in `sv_default_buyables.lua` | Traitor bots will never purchase Smart Bullets |
| G-2 | **No activation behavior** | No behavior to equip and fire the SWEP to activate | Bot will carry the weapon but never use it |
| G-3 | **No combat awareness of active buff** | `AttackTarget` doesn't know about `ttt2_smart_bullets_active` | Bot doesn't exploit the buff's guaranteed headshots |

## 3.2 High-Impact Gaps (Significantly Improve Gameplay)

| # | Gap | Description | Impact |
|---|-----|-------------|--------|
| G-4 | **No evidence/detection system** | Other bots don't detect Smart Bullets tracers | Enemies don't react to the distinctive visual tells |
| G-5 | **No defensive reaction** | Bots don't evade/take-cover from Smart Bullets users | Bots stand in the open getting headshot |
| G-6 | **No chatter** | No Smart Bullets-related dialog lines | Silent, unreactive bots during dramatic moments |
| G-7 | **No lock-hold awareness** | Bot may switch targets during lock acquisition | Wastes lock time, constantly resetting 0.6s delay |

## 3.3 Enhancement Gaps (Polish and Realism)

| # | Gap | Description | Impact |
|---|-----|-------------|--------|
| G-8 | **No trait-based activation timing** | All traitor bots activate at the same moment | Predictable, lacks personality variation |
| G-9 | **No STT/parser support** | Human callouts about Smart Bullets aren't parsed | Bots can't react to human intel about the weapon |
| G-10 | **No expire-time tracking** | Bots don't track when an enemy's buff will end | Can't time counter-attacks after buff expires |
| G-11 | **No SteamID64 bot timer fix** | Timer collision risk when multiple bots use Smart Bullets | Potential permanent buff bug for bots |
| G-12 | **No chatter announce for purchase** | Smart Bullets purchase not registered as a chatter buy event | Missing team callout on purchase |

---

# 4. Implementation Plan

## 4.1 File-Level Changes Required

### New Files

| File | Purpose |
|------|---------|
| `behaviors/activatesmartbullets.lua` | New behavior: equip and fire Smart Bullets SWEP |

### Modified Files

| File | Changes |
|------|---------|
| `data/sv_default_buyables.lua` | Add Smart Bullets buyable entry |
| `behaviors/attacktarget.lua` | Add Smart Bullets active-buff awareness (aim, inaccuracy, threshold, target hold) |
| `components/sv_inventory.lua` | Add weapon scoring exception for `weapon_ttt2_smart_bullets` (do NOT select as combat weapon) |
| `locale/en/sh_chats_misc.lua` | Add `RegisterBuyEvent("Smart Bullets")` |
| `locale/en/sh_chats.lua` or new chatter file | Add Smart Bullets chatter categories |
| `components/sv_morality.lua` or `sv_evidence.lua` | Add Smart Bullets tracer detection → suspicion/evidence injection |

### Addon-Side Fix (Optional but Recommended)

| File | Fix |
|------|-----|
| `ttt2_smart_bullets_swep/lua/autorun/sv_ttt2_smart_bullets.lua` | Replace `ply:SteamID64()` fallback with `ply:EntIndex()` to prevent timer collisions for bots |

---

## 4.2 Phase 1 — Core Functionality (Estimated: 2–3 hours)

**Goal:** Traitor bots can buy and use Smart Bullets.

### Checklist

- [ ] **P1-1.** Add `Registry.SmartBullets` entry to `sv_default_buyables.lua`
  - Class: `"weapon_ttt2_smart_bullets"`
  - Price: 1, Priority: 3
  - CanBuy: trait-based (aggressive, gimmick, tryhard)
  - SituationalScore: based on enemy count, combat state, weapon quality
  - Roles: traitor team roles
  - PrimaryWeapon: `false` (it's equipment)

- [ ] **P1-2.** Add `RegisterBuyEvent("Smart Bullets")` to `sh_chats_misc.lua`

- [ ] **P1-3.** Create `behaviors/activatesmartbullets.lua`
  - Validate: has weapon, not already active, has combat weapon, tactical opportunity
  - Action: select SWEP → fire primary → wait for strip → switch to combat weapon
  - Should fire within traitor behavior tree between Chatter and FightBack priorities

- [ ] **P1-4.** Add Smart Bullets to inventory exclusion
  - In `sv_inventory.lua` → `GetBestWeapon` / `ScoreWeapon` — if class is `"weapon_ttt2_smart_bullets"`, score = -999 (never auto-select as combat weapon)
  - If the bot's role has AutoSwitch enabled, the inventory manager should skip this weapon during auto-management

- [ ] **P1-5.** Integrate `ActivateSmartBullets` behavior into traitor default behavior tree
  - Add after the buy phase / before FightBack
  - Only traitor-like roles need this in their tree (or use a generic equipment-use behavior)

---

## 4.3 Phase 2 — Combat Exploitation (Estimated: 2–3 hours)

**Goal:** Bots fight intelligently while Smart Bullets are active.

### Checklist

- [ ] **P2-1.** Modify `AttackTarget.ShouldLookAtBody` to return `true` when `bot.ttt2_smart_bullets_active` (body aim is fine — lock cone handles the rest)

- [ ] **P2-2.** Modify `AttackTarget.CalculateInaccuracy` to reduce scatter when `bot.ttt2_smart_bullets_active and bot.ttt2_smart_bullets_locked` (bullets redirect anyway)

- [ ] **P2-3.** Modify `AttackTarget.LookingCloseToTarget` to widen threshold to ~20° when `bot.ttt2_smart_bullets_active` (match lock cone width)

- [ ] **P2-4.** Add target-hold logic during lock acquisition
  - If `bot.ttt2_smart_bullets_active` and `bot.ttt2_smart_bullets_lock_progress < 1.0`
  - Suppress target switching for `lock_delay` seconds (default 0.6)
  - Prevent `AttackTarget` from selecting a new target during lock acquisition

- [ ] **P2-5.** Increase aggression during buff window
  - Reduce approach distance (push harder)
  - Reduce retreat likelihood
  - Increase fire rate confidence

- [ ] **P2-6.** Add clip-management awareness
  - During Smart Bullets buff, if current weapon clip is empty → switch to next best weapon instead of reloading (save time — buff is ticking)
  - Or quick-reload if weapon reload time is < 1 second

---

## 4.4 Phase 3 — Defensive Reactions (Estimated: 2–3 hours)

**Goal:** All bots detect and react to enemies using Smart Bullets.

### Checklist

- [ ] **P3-1.** Add server-side Smart Bullets detection hook
  - Hook into `EntityFireBullets` → detect when any player fires locked Smart Bullets
  - Notify nearby bots (visibility + audio range check)
  - Inject evidence: "Player X is using traitor auto-aim equipment"

- [ ] **P3-2.** Add suspicion modifier for Smart Bullets detection
  - `TTTBotsModifySuspicion` hook or direct evidence injection
  - Witnessing Smart Bullet tracers from a player → +0.6 suspicion
  - Witnessing Smart Bullet kill → +0.8 suspicion
  - Multiple observations → escalate to KOS confidence

- [ ] **P3-3.** Add evasion logic to `AttackTarget`
  - When bot's attack target (or incoming attacker) has `ttt2_smart_bullets_active`
  - Increase cover-seeking weight
  - Add lateral strafing to delay lock acquisition
  - Consider disengagement if alone and low health

- [ ] **P3-4.** Add Smart Bullets awareness to morality/hostility system
  - When a player is confirmed using Smart Bullets → treat as strong traitor evidence
  - Weight similar to witnessing a murder (near-guaranteed traitor equipment)
  - Trigger KOS callout if suspicion threshold is met

- [ ] **P3-5.** Add buff expiry tracking
  - Read `ttt2_smart_bullets_expire_time` NWFloat on suspected Smart Bullets users
  - If remaining time < 3 seconds → prepare to push (buff about to expire)
  - If remaining time > 10 seconds → prioritize evasion over engagement

---

## 4.5 Phase 4 — Chatter, STT, and Polish (Estimated: 1–2 hours)

**Goal:** Bots communicate about Smart Bullets naturally.

### Checklist

- [ ] **P4-1.** Add Smart Bullets chatter categories to locale
  - Traitor-side: `SmartBulletsActivated`, `SmartBulletsKill`, `SmartBulletsExpired`
  - Innocent-side: `SmartBulletsDetected`, `SmartBulletsKOS`, `SmartBulletsWarning`, `SmartBulletsEvade`, `SmartBulletsSurvived`
  - Example lines for each category (5–10 lines per category)

- [ ] **P4-2.** Add chatter event triggers
  - On detection: fire `SmartBulletsDetected` event
  - On KOS threshold: fire `SmartBulletsKOS` event
  - On buff expiry survival: fire `SmartBulletsSurvived` event
  - On traitor activation: fire `SmartBulletsActivated` (team-only)
  - On kill during buff: fire `SmartBulletsKill` (context-appropriate)

- [ ] **P4-3.** Add STT parser aliases for Smart Bullets mentions
  - Normalize: "smart bullets", "auto aim", "aimbot", "lock on", "tracking bullets", "red beams", "energy beams"
  - Map to structured alert about traitor equipment usage

- [ ] **P4-4.** Add personality-based activation timing
  - Aggressive/hothead bots → activate immediately when they have a target
  - Cautious bots → activate only when engaging 2+ enemies
  - Tryhard bots → activate when they have optimal weapon + position
  - Gimmick bots → always excited to activate new equipment

---

# 5. Concrete Code Examples

## 5.1 Buyable Entry (sv_default_buyables.lua)

```lua
---@type Buyable
--- Smart Bullets: one-time use device that grants auto-aim headshots for a limited duration.
--- Traitor equipment, consumed on activation. Produces extremely visible tracers.
Registry.SmartBullets = {
    Name = "Smart Bullets",
    Class = "weapon_ttt2_smart_bullets",
    Price = 1,
    Priority = 3,
    RandomChance = 1,
    ShouldAnnounce = true,
    CanBuy = function(ply)
        -- Don't buy if buff is already active
        if ply.ttt2_smart_bullets_active then return false end
        -- Don't buy if we already have one in inventory
        if ply:HasWeapon("weapon_ttt2_smart_bullets") then return false end
        -- Trait preferences
        return testPlyHasTrait(ply, "aggressive", 4)
            or testPlyHasTrait(ply, "gimmick", 3)
            or testPlyHasTrait(ply, "tryhard", 5)
    end,
    SituationalScore = function(ply)
        local base = 5
        local enemies = countAliveNonAllies(ply)
        if enemies >= 3 then base = base + 2 end
        if enemies >= 5 then base = base + 3 end
        if IsValid(ply.attackTarget) then base = base + 4 end
        -- Bonus if we have a good weapon to pair with
        local inv = ply.BotInventory and ply:BotInventory()
        if inv then
            local best = inv:GetBestPrimary and inv:GetBestPrimary()
            if best then base = base + 3 end
        end
        return base
    end,
    AnnounceTeam = false,
    Roles = KillerRoles,
    PrimaryWeapon = false,
}
```

## 5.2 Activation Behavior (behaviors/activatesmartbullets.lua)

```lua
TTTBots.Behaviors.ActivateSmartBullets = {}

local lib = TTTBots.Lib
local ActivateSmartBullets = TTTBots.Behaviors.ActivateSmartBullets
ActivateSmartBullets.Name = "ActivateSmartBullets"
ActivateSmartBullets.Description = "Activating smart bullets"
ActivateSmartBullets.Interruptible = false

local STATUS = TTTBots.STATUS

function ActivateSmartBullets.Validate(bot)
    if not IsValid(bot) then return false end
    if not bot:Alive() then return false end

    -- Must have the weapon
    if not bot:HasWeapon("weapon_ttt2_smart_bullets") then return false end

    -- Must not already be active
    if bot.ttt2_smart_bullets_active then return false end

    -- Must have a combat weapon to use after activation
    local inv = bot:BotInventory()
    if not inv then return false end
    if not (inv:HasPrimary() or inv:HasSecondary()) then return false end

    -- Tactical check: have a target or expect combat
    local hasTarget = IsValid(bot.attackTarget)
    return hasTarget
end

function ActivateSmartBullets.OnStart(bot)
    bot.smartBulletsActivationStep = 0
    bot.smartBulletsActivationTime = CurTime()
    return STATUS.RUNNING
end

function ActivateSmartBullets.OnRunning(bot)
    local step = bot.smartBulletsActivationStep or 0
    local elapsed = CurTime() - (bot.smartBulletsActivationTime or CurTime())

    if step == 0 then
        -- Step 0: Select the Smart Bullets weapon
        local wep = bot:GetWeapon("weapon_ttt2_smart_bullets")
        if not IsValid(wep) then return STATUS.FAILURE end
        bot:SelectWeapon("weapon_ttt2_smart_bullets")
        bot.smartBulletsActivationStep = 1
        return STATUS.RUNNING

    elseif step == 1 and elapsed > 0.15 then
        -- Step 1: Fire primary attack to activate
        local wep = bot:GetActiveWeapon()
        if IsValid(wep) and wep:GetClass() == "weapon_ttt2_smart_bullets" then
            bot:SetAttacking(true)
            bot.smartBulletsActivationStep = 2
        else
            -- Weapon switch didn't complete, retry
            bot:SelectWeapon("weapon_ttt2_smart_bullets")
        end
        return STATUS.RUNNING

    elseif step == 2 and elapsed > 0.35 then
        -- Step 2: Stop firing and switch to combat weapon
        bot:SetAttacking(false)
        local inv = bot:BotInventory()
        if inv then
            local best = inv:GetBestWeapon()
            if best and IsValid(best) then
                bot:SelectWeapon(best:GetClass())
            end
        end
        return STATUS.SUCCESS
    end

    return STATUS.RUNNING
end

function ActivateSmartBullets.OnEnd(bot)
    bot:SetAttacking(false)
    bot.smartBulletsActivationStep = nil
    bot.smartBulletsActivationTime = nil
end
```

## 5.3 AttackTarget Modifications (Conceptual)

```lua
-- In ShouldLookAtBody:
if bot.ttt2_smart_bullets_active then
    return true -- body mode is fine; lock cone is wide (~18°)
end

-- In CalculateInaccuracy:
if bot.ttt2_smart_bullets_active and bot.ttt2_smart_bullets_locked then
    return VectorRand() * 0.15 -- near-zero; bullets redirect server-side
end

-- In LookingCloseToTarget:
if bot.ttt2_smart_bullets_active then
    threshold = 20 -- wider threshold to match lock-on cone
end

-- In target switching logic:
-- Suppress target switch during lock acquisition
if bot.ttt2_smart_bullets_active
    and bot.ttt2_smart_bullets_lock_target
    and not bot.ttt2_smart_bullets_locked
then
    -- Don't switch targets — hold current target for lock completion
    return -- skip target re-evaluation
end
```

## 5.4 Smart Bullets Detection Hook (Conceptual)

```lua
-- In a new file or sv_morality.lua / sv_evidence.lua:
hook.Add("EntityFireBullets", "TTTBots_SmartBulletsDetection", function(ent, data)
    if not IsValid(ent) or not ent:IsPlayer() then return end
    if not ent.ttt2_smart_bullets_active then return end
    if not ent.ttt2_smart_bullets_locked then return end

    local shooterPos = ent:GetPos()

    for _, bot in ipairs(player.GetAll()) do
        if not bot:IsBot() then continue end
        if not TTTBots.Lib.IsPlayerAlive(bot) then continue end
        if bot == ent then continue end

        local dist = bot:GetPos():DistToSqr(shooterPos)
        local canSee = bot:VisibleVec(ent:GetShootPos())
        local inAudioRange = dist < (2000 * 2000)

        if canSee then
            -- Strong evidence: saw the distinctive tracer beams
            TTTBots.Evidence.AddEvidence(bot, ent, "SMART_BULLETS_VISUAL", 0.6)
        elseif inAudioRange then
            -- Weaker evidence: heard the zap sounds
            TTTBots.Evidence.AddEvidence(bot, ent, "SMART_BULLETS_AUDIO", 0.3)
        end
    end
end)
```

---

# 6. Inventory / Weapon Scoring Details

## 6.1 Weapon Scoring Exclusion

`weapon_ttt2_smart_bullets` should NEVER be selected as a combat weapon. The inventory scoring function should explicitly exclude it:

```lua
-- In ScoreWeapon or GetBestWeapon:
if wepInfo.class == "weapon_ttt2_smart_bullets" then
    return -999 -- never select as combat weapon
end
```

## 6.2 Post-Activation Weapon Selection

After activation, the bot should switch to its **best available combat weapon**. The scoring should consider:

- During Smart Bullets buff: prefer high-RPM weapons (more bullets = more headshots)
- Automatic weapons are ideal (sustained fire rate)
- Shotguns are very strong (multiple pellets, each redirected to head)
- Sniper rifles are less ideal (slow fire rate, wastes the buff window on reloading)

### Suggested Buff-Active Weapon Priority Adjustments

```lua
-- When bot.ttt2_smart_bullets_active:
-- In ScoreWeapon, add bonus for high-RPM weapons:
if bot.ttt2_smart_bullets_active then
    if wepInfo.is_automatic then
        score = score + 15 -- automatic weapons maximize headshot output
    end
    if wepInfo.rpm and wepInfo.rpm > 400 then
        score = score + 10 -- high fire rate weapons
    end
    if wepInfo.is_shotgun then
        score = score + 8 -- shotgun pellets all redirect
    end
    if wepInfo.is_sniper then
        score = score - 10 -- slow fire rate wastes buff
    end
end
```

---

# 7. Addon-Side Fix Recommendations

## 7.1 SteamID64 Timer Collision Fix

**File:** `ttt2_smart_bullets_swep/lua/autorun/sv_ttt2_smart_bullets.lua`
**File:** `ttt2_smart_bullets_swep/lua/weapons/weapon_ttt2_smart_bullets.lua`

**Problem:** Multiple bots all return `"0"` from `SteamID64()`, causing timer name collisions.

**Fix:** Replace all instances of:
```lua
local timerName = "TTT2SmartBullets_Expire_" .. owner:SteamID64()
```
With:
```lua
local timerName = "TTT2SmartBullets_Expire_" .. (owner:SteamID64() or tostring(owner:EntIndex()))
```

Or more robustly:
```lua
local id = owner:IsBot() and tostring(owner:EntIndex()) or owner:SteamID64()
local timerName = "TTT2SmartBullets_Expire_" .. id
```

This affects the following locations:
1. `weapon_ttt2_smart_bullets.lua` — PrimaryAttack timer creation
2. `sv_ttt2_smart_bullets.lua` — TTTPrepareRound cleanup
3. `sv_ttt2_smart_bullets.lua` — PostPlayerDeath cleanup
4. `sv_ttt2_smart_bullets.lua` — PlayerDisconnected cleanup

---

# 8. Chatter Lines Reference

## 8.1 Traitor-Side Lines (Team-Only)

### SmartBulletsActivated
```
"Smart bullets online. Let's clean up."
"Activating auto-aim. Cover me."
"I've got smart bullets — pushing now."
"Lock and load. Smart bullets active."
"Going hot with the tracking rounds."
```

### SmartBulletsKill
```
"Got one with the tracking rounds."
"Smart bullets claimed another."
"Target down. This thing is nasty."
"Easy kill. Love these bullets."
```

### SmartBulletsExpired
```
"Smart bullets wore off."
"Auto-aim expired. Back to manual."
"Tracking rounds are done."
```

## 8.2 Innocent/Detective-Side Lines (Public)

### SmartBulletsDetected
```
"What are those red beams?! That's not normal!"
"Those tracers — someone has some kind of auto-aim!"
"I see energy beams! Someone's got special equipment!"
"Those aren't normal bullets — they're tracking!"
"RED BEAMS! Someone has traitor tech!"
```

### SmartBulletsKOS
```
"KOS {player}! They're using smart bullets!"
"It's {player}! They have auto-aim bullets, kill them!"
"{player} has tracking rounds — they're a traitor!"
"That's {player} with the red beams! Traitor!"
```

### SmartBulletsWarning
```
"Be careful, someone has homing bullets out there."
"Watch the red tracers — stay behind cover!"
"Don't go out in the open, there's a smart bullets user."
"Those tracking bullets can't miss — stay in cover!"
```

### SmartBulletsEvade
```
"I'm being tracked! Getting to cover!"
"Those bullets are following me!"
"Need cover NOW — smart bullets!"
"Can't dodge these bullets, breaking line of sight!"
```

### SmartBulletsSurvived
```
"I think the tracking effect wore off..."
"The red beams stopped. Safe to peek?"
"Smart bullets seem to be done — pushing!"
"Auto-aim must have expired. Let's go."
```

---

# 9. Testing Strategy

## 9.1 Unit Tests (Manual Verification)

| Test ID | Scenario | Expected Outcome | Priority |
|---------|----------|-------------------|----------|
| T-1 | Traitor bot buys Smart Bullets | Weapon appears in inventory | Critical |
| T-2 | Traitor bot activates Smart Bullets | Buff becomes active, weapon is consumed | Critical |
| T-3 | Traitor bot fights during buff | Aims at targets, lock-on completes, headshots land | Critical |
| T-4 | Traitor bot switches weapons after activation | Selects best combat weapon, not SWEP | Critical |
| T-5 | Bot doesn't select Smart Bullets SWEP as combat weapon | Never tries to "shoot" with the SWEP itself | Critical |
| T-6 | Innocent bot witnesses Smart Bullet tracers | Generates suspicion/evidence on shooter | High |
| T-7 | Bot calls KOS after witnessing Smart Bullets | Chatter fires with correct player name | High |
| T-8 | Bot seeks cover when enemy has Smart Bullets | Moves behind cover, avoids open areas | High |
| T-9 | Bot tracks buff expiry and pushes after | Re-engages after buff timer expires | Medium |
| T-10 | Multiple bots activate Smart Bullets (timer test) | Each bot's timer is independent, no collisions | Medium |
| T-11 | Bot holds target during lock acquisition | No target switching for 0.6s during lock | Medium |
| T-12 | Bot prefers high-RPM weapons during buff | Selects automatic/shotgun over sniper | Medium |
| T-13 | Buff expires during combat | Bot returns to normal combat behavior | Low |
| T-14 | Round ends with Smart Bullets active | Clean state reset, no errors | Low |

## 9.2 Integration Tests

| Test | Method | Duration |
|------|--------|----------|
| 10-round soak test with Smart Bullets available | Set shop to guarantee traitor + Smart Bullets | ~30 min |
| Multi-bot traitor test | Multiple traitors, verify independent activation | ~15 min |
| Defensive reaction test | Force innocent bots near a Smart Bullets user | ~10 min |
| Chatter verification | Check logs for correct chatter events | ~10 min |

---

# 10. Recommended Implementation Order

## Highest Priority (Must Have)

1. **Add buyable entry** — Without this, no bot will ever have Smart Bullets
2. **Create activation behavior** — Without this, bots carry but never use the item
3. **Add inventory exclusion** — Prevents bots from trying to shoot enemies with the SWEP
4. **Fix SteamID64 timer collision** — Prevents permanent buff bug for bots

## High Priority (Strong Gameplay Impact)

5. **Add combat modifications for active buff** — Makes the buff actually useful for bots
6. **Add target-hold during lock acquisition** — Core mechanic, without this lock never completes
7. **Add evidence/detection system** — Other bots recognize the threat
8. **Add basic chatter** — Bots communicate about the situation

## Medium Priority (Polish)

9. **Add defensive evasion behavior** — Bots react tactically to Smart Bullets users
10. **Add buff expiry tracking** — Time counter-attacks after buff ends
11. **Add weapon scoring adjustments during buff** — Prefer high-RPM weapons
12. **Add STT parser aliases** — React to human callouts

## Lower Priority (Enhancement)

13. **Add personality-based activation timing** — Varied bot behavior
14. **Add comprehensive chatter catalog** — Full set of situation-appropriate lines
15. **Add round-awareness integration** — Macro-level behavior changes

---

# 11. Recommended Minimal Viable Integration

## MVP Checklist

If the goal is to get strong results quickly:

- [ ] Add `Registry.SmartBullets` to `sv_default_buyables.lua`
- [ ] Add `RegisterBuyEvent("Smart Bullets")` to `sh_chats_misc.lua`
- [ ] Create `behaviors/activatesmartbullets.lua` with basic equip → fire → switch sequence
- [ ] Add inventory scoring exclusion for `weapon_ttt2_smart_bullets` (never auto-select)
- [ ] Add `AttackTarget` awareness: widen threshold + reduce inaccuracy when `ttt2_smart_bullets_active`
- [ ] Add target-hold suppression during lock acquisition (0.6s no-switch window)
- [ ] Add basic `EntityFireBullets` detection hook for nearby bots
- [ ] Add one chatter event: `SmartBulletsDetected` with 5 example lines
- [ ] Fix `SteamID64()` timer collision in the addon

### Why This MVP Is Strong

It solves the complete loop:
- **Buy** → traitor bots purchase Smart Bullets
- **Activate** → bots use the item at tactical moments
- **Exploit** → bots fight effectively with the buff
- **Detect** → other bots recognize the threat
- **React** → evidence and suspicion flow naturally
- **Communicate** → basic chatter creates emergent stories

Without requiring the harder defensive evasion, personality timing, or comprehensive chatter work.

---

# 12. Conclusion

The Smart Bullets SWEP is a **high-impact traitor equipment item** that creates dramatic, visible gameplay moments. Its integration into TTT2-Bots-2 requires work across the full bot stack:

- **Buyables** — So traitor bots can acquire it
- **Behaviors** — So bots can activate and exploit it
- **Inventory** — So bots handle the consumable weapon correctly
- **Combat** — So bots fight effectively during the buff
- **Evidence/Morality** — So other bots detect and respond to the threat
- **Chatter** — So bots communicate about it naturally

The most unique integration challenge is the **dual-sided nature** of the weapon: it requires both offensive AI (using it) and defensive AI (reacting to it). The distinctive visual tracers make it one of the most detectable traitor equipment items in the game, which creates rich opportunities for evidence, KOS calls, and tactical evasion.

The existing bot architecture already has strong foundations for this integration. The buyable system, inventory management, attack target behavior, evidence system, and chatter framework all have clear extension points. The recommended implementation order prioritizes getting the full buy → activate → exploit → detect loop working before adding polish.

With full implementation, Smart Bullets usage by bots (and reactions to it) should create some of the most visually dramatic and strategically interesting moments in bot-populated TTT2 rounds.
