# Defector Role — TTT2 Bot Integration Design & Code Analysis

> **Author:** AI Analysis  
> **Date:** 2026-03-10  
> **Target Codebase:** TTT2-Bots-2 (branch: `development`)  
> **Role Addon:** `ttt_defector_role-master`  
> **Status:** Current implementation exists but has critical incompatibilities with the actual role addon

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Role Mechanics Deep Dive](#2-role-mechanics-deep-dive)
3. [Current Bot Implementation Audit](#3-current-bot-implementation-audit)
4. [Incompatibility Analysis](#4-incompatibility-analysis)
5. [Recommended Architecture](#5-recommended-architecture)
6. [File-by-File Implementation Plan](#6-file-by-file-implementation-plan)
7. [Behavior Tree Design](#7-behavior-tree-design)
8. [Morality & Combat Integration](#8-morality--combat-integration)
9. [Conversion Flow (Traitor → Defector Creation)](#9-conversion-flow-traitor--defector-creation)
10. [Jihad Behavior Refinements](#10-jihad-behavior-refinements)
11. [Buyable Equipment Design](#11-buyable-equipment-design)
12. [Personality & Trait Integration](#12-personality--trait-integration)
13. [Chatter & Locale Additions](#13-chatter--locale-additions)
14. [Edge Cases & Failure Modes](#14-edge-cases--failure-modes)
15. [Testing Strategy](#15-testing-strategy)
16. [Implementation Priority & Phasing](#16-implementation-priority--phasing)

---

## 1. Executive Summary

### What Is the Defector?

The Defector is a **mid-round conversion role** on `TEAM_TRAITOR`. An innocent player is converted to Defector when they pick up a `weapon_ttt_defector_jihad` that a traitor has dropped for them. Upon conversion:

- **The Defector joins TEAM_TRAITOR** but cannot deal normal damage to other players
- **Their only offensive capability is the Jihad Bomb** (`weapon_ttt_jihad_bomb`) — a suicide explosion
- **Explosive (DMG_BLAST) damage is NOT blocked** — this is how the Jihad bomb works
- They receive 0 starting credits, cannot use traitor buttons, and have a traitor shop fallback

### Current State in TTT2-Bots-2

The bot mod already has a **partial implementation** consisting of:
- `roles/defector.lua` — Role registration with a custom behavior tree
- `behaviors/jihad.lua` — Jihad bomb usage behavior (with defector-specific logic)
- `behaviors/createdefector.lua` — Traitor behavior to create defectors (uses a fictional `weapon_ttt2_defector_deagle`)
- `data/sv_default_buyables.lua` — Two buyable entries (DefectorDeagle, DefectorJihad)
- `data/sh_traits.lua` — `defector` personality trait
- `locale/en/sh_chats.lua` — Chatter lines for `CreatingDefector`, `JihadBombWarn`, `JihadBombUse`

### Critical Finding

**The bot mod's `CreateDefector` behavior assumes a weapon (`weapon_ttt2_defector_deagle`) that does NOT exist in the actual defector role addon.** The real addon uses `weapon_ttt_defector_jihad` — a droppable item that converts an innocent on pickup via a `WeaponEquip` hook. This fundamental mismatch means the entire conversion flow needs to be redesigned.

---

## 2. Role Mechanics Deep Dive

### 2.1 Role Definition (`shared.lua`)

```lua
-- Key properties:
self.color = Color(184, 148, 114, 255)     -- Tan/brown color
self.abbr = "defec"
self.notSelectable = true                    -- Cannot be assigned at round start
self.preventFindCredits = true               -- Cannot find credits on bodies
self.preventKillCredits = true               -- No credits for kills
self.preventTraitorAloneCredits = true       -- No "last traitor" credits
self.defaultTeam = TEAM_TRAITOR
self.conVarData = {
    credits = 0,
    traitorButton = 0,                       -- CANNOT use traitor buttons
    shopFallback = SHOP_FALLBACK_TRAITOR
}
```

**Role inheritance:** `roles.SetBaseRole(self, ROLE_TRAITOR)` — inherits from traitor base.

### 2.2 Damage Blocking System

The defector has a custom `PlayerTakeDamage` hook that **blocks ALL non-explosive damage**:

```lua
hook.Add("PlayerTakeDamage", "DefectorNoDamage", function(ply, inflictor, killer, amount, dmginfo)
    if not ShouldDefectorDealNoDamage(ply, killer) then return end
    -- Explosive damage is ALLOWED (for jihad bomb)
    if dmginfo:GetDamageType() != DMG_BLAST then
        dmginfo:ScaleDamage(0)
        dmginfo:SetDamage(0)
    end
end)
```

**Implication for bots:** A defector bot must **never attempt to use guns/melee against players**. The ONLY way to deal damage is through the Jihad bomb explosion. This is the core behavioral constraint.

### 2.3 Conversion Mechanism

The actual conversion happens in `weapon_ttt_defector_jihad.lua` via a `WeaponEquip` hook:

```lua
hook.Add('WeaponEquip', 'DefectorJihadPickup', function(weapon, owner)
    if weapon:GetClass() == 'weapon_ttt_defector_jihad' then
        if owner:GetRole() == ROLE_INNOCENT and owner:GetTeam() == TEAM_INNOCENT then
            -- Strip the defector jihad
            owner:StripWeapon(class)
            -- Give actual jihad bomb
            owner:SafePickupWeaponClass("weapon_ttt_jihad_bomb", true)
            -- Convert to defector
            ConvertDefector(owner)
        end
    end
end)
```

**Key conversion rules:**
1. Only `ROLE_INNOCENT` on `TEAM_INNOCENT` can be converted
2. Pharaoh conversion is controlled by a ConVar (`ttt_defector_convert_pharaoh`)
3. The `weapon_ttt_defector_jihad` is stripped and replaced with `weapon_ttt_jihad_bomb`
4. `SendFullStateUpdate()` is called to sync role state to all clients
5. The weapon itself **cannot be fired** — `PrimaryAttack()` just prints a help message

### 2.4 Pharaoh/Ankh Interaction

```lua
hook.Add("TTT2PharaohPreventDamageToAnkh", "TTT2PharaohPreventDamageToAnkhDefector", function(attacker)
    if attacker:GetSubRole() == ROLE_DEFECTOR then return true end
end)
```

Defectors cannot damage Ankhs — this is a secondary damage prevention mechanic.

---

## 3. Current Bot Implementation Audit

### 3.1 Role Registration (`roles/defector.lua`)

**Current code:**
```lua
local bTree = {
    _bh.Jihad,
    _prior.Chatter,
    _prior.Investigate,
    _prior.Patrol
}

local defector = TTTBots.RoleData.New("defector", TEAM_TRAITOR)
defector:SetStartsFights(false)
defector:SetCanCoordinate(false)
defector:SetIsFollower(true)
defector:SetUsesSuspicion(false)
defector:SetBuyableWeapons("weapon_ttt_jihad_bomb")
defector:SetBTree(bTree)
defector:SetAlliedTeams(allyTeams)
defector:SetLovesTeammates(true)
```

**Assessment:**
- ✅ `StartsFights = false` — Correct, defector should not initiate normal fights
- ✅ `IsFollower = true` — Good, defectors should blend in with innocents
- ✅ `UsesSuspicion = false` — Correct, defector knows who the enemies are
- ✅ `CanCoordinate = false` — Reasonable, defector acts independently
- ⚠️ `BuyableWeapons = "weapon_ttt_jihad_bomb"` — Should verify this is actually in the defector's shop
- ⚠️ `CanHaveRadar = true` — The role has 0 credits and `preventFindCredits/preventKillCredits`, so radar is unbuyable unless credits are given externally
- ❌ Missing: `SetPlantsC4(false)` — Defector cannot plant C4 (0 credits, no traitor buttons)
- ❌ Missing: `SetDefusesC4(false)` — Explicitly set
- ❌ Missing: `SetAutoSwitch(false)` — Should not auto-switch to conventional weapons
- ❌ Missing: `SetCanSnipe(false)` — Cannot deal gun damage
- ❌ Missing: `SetCanHide(true)` — Defector should blend with innocents
- ❌ Missing: `SetPreferredWeapon("weapon_ttt_jihad_bomb")` — Should prefer the jihad bomb

### 3.2 Behavior Tree Analysis

**Current tree:**
```
1. Jihad               ← Use jihad bomb (highest priority)
2. PriorityNodes.Chatter   ← ChatterHelp, VouchForPlayer
3. PriorityNodes.Investigate  ← InvestigateCorpse, InvestigateNoise
4. PriorityNodes.Patrol     ← Follow, GroupUp, Wander
```

**Assessment:**
- ❌ **Missing FightBack/SelfDefense** — If attacked, the defector has no way to escape or defend. While they can't deal damage, they should still be able to `SeekCover` and `Retreat`.
- ❌ **Missing Requests** — Cannot respond to CeaseFire, ComeHere, FollowMe, Wait
- ❌ **Missing Grenades** — If the defector happens to have grenades, they can use them (DMG_BLAST passes through!)
- ❌ **Missing Deception** — Defector was an innocent and should maintain cover via AlibiBuilding, FakeInvestigate, PlausibleIgnorance
- ❌ **Missing Restore** — GetWeapons, LootNearby, UseHealthStation — defector should heal/arm
- ⚠️ **Jihad at position 1 with no gating** — Means the bot will immediately try to jihad as soon as it has the bomb and sees enemies, which can be too aggressive in early game
- ⚠️ **Missing approach/stalking behavior** — Defector should try to get close to large groups before detonating

### 3.3 Jihad Behavior (`behaviors/jihad.lua`)

**Current defector-specific logic:**
```lua
-- Defector needs only 1+ enemy (others need 4+)
if differentTeams < 4 and role ~= ROLE_DEFECTOR then return false end
if differentTeams < 1 and role == ROLE_DEFECTOR then return false end

-- Defector gets 3x chance multiplier
if role == ROLE_DEFECTOR then chance = chance * 3 end
```

**Assessment:**
- ✅ Lower enemy threshold for defectors (1 vs 4) makes sense since they only have this weapon
- ⚠️ `chance * 3` may be too aggressive — defector should wait for optimal moment
- ❌ **No phase-awareness** — Defector should wait for MID/LATE game when groups are larger
- ❌ **No teammate protection** — No check for nearby traitor allies before detonating
- ❌ **No "approach first" logic** — Bot should pathfind toward enemy clusters before triggering
- ❌ **Radius is fixed at 500** — Should be configurable and possibly vary by game phase
- ❌ **Midpoint calculation includes all non-team** — Should weight by cluster density

### 3.4 CreateDefector Behavior (`behaviors/createdefector.lua`)

**Critical Issue:** Uses `weapon_ttt2_defector_deagle` which **does not exist** in the actual role addon.

The actual defector conversion mechanism is:
1. Traitor buys `weapon_ttt_defector_jihad` from shop
2. Traitor **drops** the weapon near an innocent
3. Innocent **picks up** the dropped weapon
4. `WeaponEquip` hook detects the pickup and converts the innocent

**This is a fundamentally different mechanic** from the deagle-style "shoot to convert" pattern used by other roles (Cursed, Medic, Doctor, Sidekick). The defector weapon requires **cooperation from the target** (picking up a dropped item), not being shot.

---

## 4. Incompatibility Analysis

### 4.1 Weapon Class Mismatch

| Component | Bot Mod Expects | Actual Addon Has |
|-----------|----------------|-----------------|
| Traitor conversion weapon | `weapon_ttt2_defector_deagle` | `weapon_ttt_defector_jihad` |
| Conversion mechanism | Shoot target (deagle pattern) | Drop item → target picks up |
| Target receives | `weapon_ttt_jihad_bomb` (given by `onFireFn`) | `weapon_ttt_jihad_bomb` (given by `WeaponEquip` hook) |
| Who initiates conversion | Traitor bot fires at target | Target picks up dropped weapon |

### 4.2 Behavioral Mismatch

| Aspect | Bot Mod Assumes | Actual Behavior |
|--------|----------------|----------------|
| Defector can fight | `StartsFights = false` ✅ but tree allows normal combat via FightBack | Defector literally deals 0 damage with all non-explosive weapons |
| Defector damage model | Not explicitly handled | All non-DMG_BLAST damage is zeroed |
| Weapon auto-switch | Not configured | Defector should never switch to a gun to attack |
| Inventory management | Standard traitor inventory | Defector has extremely limited inventory (only jihad + whatever they had as innocent) |

### 4.3 Missing Game Hook Integration

The bot mod does **not** hook into these role-addon events:
- `DefectorJihadPickup` — When a bot innocent picks up a defector jihad, the bot needs to immediately switch its role registration
- `DefectorNoDamage` — The morality/hostility system doesn't know defectors can't deal gun damage
- `ConvertDefector` — No hook for when a bot is converted mid-round

### 4.4 Buyable Registration Issues

```lua
Registry.DefectorDeagle = {
    Class = "weapon_ttt2_defector_deagle",  -- This weapon doesn't exist!
    ...
    Roles = GetRolesByTeam(TEAM_TRAITOR),
}

Registry.DefectorJihad = {
    Class = "weapon_ttt_defector_jihad",    -- Correct class name
    ...
    Roles = { "defector" },                 -- But defector has 0 credits to buy it
}
```

**Issues:**
1. `DefectorDeagle` references a non-existent weapon class
2. `DefectorJihad` is registered for the defector role, but defectors have 0 credits and `preventKillCredits`/`preventFindCredits`, so they can never buy anything
3. The actual `weapon_ttt_defector_jihad` should be bought by **traitors**, not defectors — traitors drop it for innocents to pick up

---

## 5. Recommended Architecture

### 5.1 Two-Phase Design

The defector integration involves **two completely separate bot behavior contexts:**

**Phase A — Traitor Creating a Defector:**
1. Traitor bot buys `weapon_ttt_defector_jihad` from shop
2. Traitor bot finds an isolated innocent bot/player
3. Traitor bot drops the weapon near the target
4. Target picks up the weapon → `WeaponEquip` hook fires → conversion happens

**Phase B — Bot Playing as Defector:**
1. Former-innocent bot is now `ROLE_DEFECTOR` on `TEAM_TRAITOR`
2. Bot's behavior tree switches to the defector tree
3. Bot must blend with innocents while maneuvering toward enemy clusters
4. Bot detonates jihad bomb at optimal moment (max enemy kills, min ally kills)

### 5.2 Design Principles

| Principle | Implementation |
|-----------|---------------|
| **No gun combat** | Defector tree must NOT include `AttackTarget` or any weapon-firing behavior except Jihad |
| **Deception-first** | Defector was an innocent — they should maintain innocent cover behaviors |
| **Patient detonation** | Jihad should be phase-aware: wait for MID/LATE game clusters, not detonate immediately |
| **Ally protection** | Check for nearby traitor allies before detonation |
| **Graceful degradation** | If both weapons exist (deagle and jihad item), support both conversion methods |
| **Drop-based conversion** | New behavior for traitor bots: navigate to isolated innocent, drop item |

---

## 6. File-by-File Implementation Plan

### 6.1 Files to Modify

| File | Changes | Priority |
|------|---------|----------|
| `roles/defector.lua` | Overhaul role properties, expand behavior tree | **P0** |
| `behaviors/jihad.lua` | Phase-awareness, ally protection, approach logic, configurable thresholds | **P0** |
| `behaviors/createdefector.lua` | Rewrite: drop-based conversion OR support both weapons | **P1** |
| `data/sv_default_buyables.lua` | Fix buyable registration (correct weapon class, correct roles) | **P1** |
| `data/sh_traits.lua` | Verify trait effects, possibly add "suicide_bomber" trait | **P2** |

### 6.2 Files to Create

| File | Purpose | Priority |
|------|---------|----------|
| `behaviors/defectorapproach.lua` | New: Stalk/approach enemy clusters before jihad | **P0** |
| `behaviors/defectorblend.lua` | New: Maintain innocent cover (optional, may use existing Deception node) | **P2** |

### 6.3 Files to Update (Minor)

| File | Changes | Priority |
|------|---------|----------|
| `locale/en/sh_chats.lua` | Add `DefectorConverted` event lines, expand Jihad archetype lines | **P2** |
| `lib/sv_morality_hostility.lua` | Add defector-awareness: don't try gun attacks when defector | **P1** |
| `components/chatter/sv_chatter_events.lua` | Register new chatter events | **P2** |

---

## 7. Behavior Tree Design

### 7.1 Proposed Defector Behavior Tree

```
Defector BTree (Priority Order):
─────────────────────────────────
1.  Requests           ← CeaseFire, Wait, ComeHere, FollowMe (maintain cover)
2.  Chatter            ← ChatterHelp, VouchForPlayer (maintain innocent facade)
3.  DefectorApproach   ← NEW: Approach enemy clusters when conditions are right
4.  Jihad              ← Detonate when in optimal position
5.  SelfDefense        ← Retreat, DefendSelf (flee, can't fight)
6.  Accuse             ← AccusePlayer (maintain innocent cover by accusing)
7.  Deception          ← AlibiBuilding, FakeInvestigate, PlausibleIgnorance
8.  Restore            ← GetWeapons, LootNearby, UseHealthStation
9.  Investigate        ← InvestigateCorpse, InvestigateNoise
10. Minge              ← MingeCrowbar (adds noise)
11. Patrol             ← Follow, GroupUp, Wander
```

### 7.2 Rationale for Each Node

| Position | Node | Rationale |
|----------|------|-----------|
| 1 | Requests | Must respond to player commands to avoid suspicion |
| 2 | Chatter | Maintain social presence — defector was an innocent, so they should still chat like one |
| 3 | DefectorApproach | **NEW** — The key differentiator. When the defector has a jihad bomb and conditions are favorable (phase ≥ MID, enemy cluster detected), begin approaching the cluster |
| 4 | Jihad | Only fires when within blast radius of enemies (validates proximity + enemy count) |
| 5 | SelfDefense | Defector can't fight, but can flee. Retreat + DefendSelf (crowbar only? or just run) |
| 6 | Accuse | Accusing others helps maintain cover as innocent |
| 7 | Deception | Build alibis, fake investigate — defector should act innocent until the bomb moment |
| 8 | Restore | Heal, pick up items (defector might find health kits, armor, etc.) |
| 9 | Investigate | Investigate corpses/noises — maintaining innocent behavior |
| 10 | Minge | Low-priority fun behavior |
| 11 | Patrol | Default idle behavior — follow groups, wander |

### 7.3 Tree Implementation Code

```lua
-- roles/defector.lua (proposed)
local bTree = {
    _prior.Requests,
    _prior.Chatter,
    _bh.DefectorApproach,    -- NEW behavior
    _bh.Jihad,
    _prior.SelfDefense,
    _prior.Accuse,
    _prior.Deception,
    _prior.Restore,
    _prior.Investigate,
    _prior.Minge,
    _prior.Patrol,
}
```

---

## 8. Morality & Combat Integration

### 8.1 The Core Problem

The morality system (`sv_morality_hostility.lua`) runs every 1 second and calls `attackEnemies`, `attackNonAllies`, etc. These functions use `RequestAttackTarget()` which causes the bot to start shooting at targets. **For a defector, this is useless** — all gun damage is zeroed.

### 8.2 Morality Hostility Patch

Add a defector guard to `runHostilityPolicy`:

```lua
-- In sv_morality_hostility.lua, inside runHostilityPolicy(bot):
local function runHostilityPolicy(bot)
    -- Defector cannot deal normal damage — skip all attack policies
    if bot:GetSubRole() == ROLE_DEFECTOR then
        -- Still run prevention policies (clear invalid targets)
        preventAttackAlly(bot)
        preventCloaked(bot)
        preventAttack(bot)
        preventAttackAllies(bot)
        -- But do NOT run attack policies (attackEnemies, attackNonAllies, etc.)
        return
    end
    
    -- ... existing policy chain ...
end
```

### 8.3 Morality Arbitration Awareness

In `sv_morality_arbitration.lua`, the `RequestAttackTarget` function should reject requests for defector bots:

```lua
-- Guard: defector bots should never accept attack targets
-- (except via Jihad behavior which doesn't use the morality system)
function Arb.RequestAttackTarget(bot, target, reason, priority)
    if bot:GetSubRole() == ROLE_DEFECTOR then
        -- Defector cannot attack with guns — always reject
        return false
    end
    -- ... existing logic ...
end
```

### 8.4 Self-Defense Handling

Even though defectors can't deal damage, they should still **flee** when attacked. The `SelfDefense` priority node includes `Retreat` and `DefendSelf`:

- **Retreat** — Run away from attacker. ✅ Works for defectors.
- **DefendSelf** — May try to fight back. ⚠️ Needs a guard: if defector, only flee, don't try to shoot.

### 8.5 Suspicion System

Defectors should **not build suspicion** on others (they know who the enemies are), but they **should be observed** by the suspicion system. The current `UsesSuspicion = false` setting handles this correctly.

However, defectors should still **appear innocent** to the suspicion system. Since they're on `TEAM_TRAITOR`, other bots will eventually recognize them as hostile. This is fine — the defector's job is to detonate before being identified.

---

## 9. Conversion Flow (Traitor → Defector Creation)

### 9.1 Understanding the Actual Mechanic

The defector role addon uses a **drop-and-pickup** conversion mechanism:

```
Traitor buys weapon_ttt_defector_jihad from shop
    ↓
Traitor drops the weapon near an innocent
    ↓
Innocent picks up the weapon
    ↓
WeaponEquip hook fires:
  - Validates: target is ROLE_INNOCENT on TEAM_INNOCENT
  - Validates: target is not Pharaoh (unless ConVar allows)
  - Strips weapon_ttt_defector_jihad
  - Gives weapon_ttt_jihad_bomb
  - Calls ConvertDefector(target)
```

### 9.2 Bot-to-Bot Conversion Scenarios

| Scenario | Traitor Bot | Target | How It Works |
|----------|------------|--------|-------------|
| Bot→Bot | Bot traitor | Bot innocent | Traitor drops weapon, innocent bot picks it up via auto-pickup |
| Bot→Human | Bot traitor | Human innocent | Traitor drops weapon near human, human must manually pick up |
| Human→Bot | Human traitor | Bot innocent | Human drops weapon, bot picks it up via auto-pickup |

### 9.3 Redesigned CreateDefector Behavior

The `CreateDefector` behavior needs to be completely rewritten to use the drop-based mechanism:

```lua
-- behaviors/createdefector.lua (proposed redesign)

-- Validate:
--   1. Bot is a traitor-team role
--   2. Bot has weapon_ttt_defector_jihad in inventory
--   3. A suitable innocent target exists (isolated, low witnesses)
--   4. Phase-aware: prefer EARLY game conversion

-- OnStart:
--   1. Find isolated innocent target
--   2. Set movement goal toward target
--   3. Chatter: "CreatingDefector"

-- OnRunning:
--   1. Navigate toward target
--   2. When within drop range (~150 units):
--      a. Equip weapon_ttt_defector_jihad
--      b. Look at ground near target
--      c. Drop the weapon (bot:DropWeapon(wep))
--   3. Wait for target to pick up
--   4. If target picks up → SUCCESS (conversion handled by addon hook)
--   5. If target doesn't pick up within timeout → re-approach or FAILURE

-- OnEnd:
--   1. Clean up state
--   2. Resume normal behavior
```

### 9.4 Handling the "Deagle" vs "Drop" Duality

There may be other server configurations that use a deagle-style defector weapon. To support both:

```lua
-- Determine which conversion method is available
local function GetConversionMethod(bot)
    if bot:HasWeapon("weapon_ttt2_defector_deagle") then
        return "deagle"  -- Shoot-to-convert (TTT2 custom weapon)
    elseif bot:HasWeapon("weapon_ttt_defector_jihad") then
        return "drop"    -- Drop-and-pickup (ttt_defector_role addon)
    end
    return nil
end
```

The behavior should branch based on which weapon the bot actually has.

### 9.5 Innocent Bot Receiving Conversion

When an innocent bot picks up a `weapon_ttt_defector_jihad`, the addon's `WeaponEquip` hook handles the conversion automatically. However, the bot mod needs to:

1. **Detect the role change** — The bot's role data needs to switch from innocent to defector
2. **Switch behavior tree** — From innocent tree to defector tree
3. **Update morality** — Stop being hostile to traitors, start planning jihad
4. **Update inventory management** — Stop auto-switching to guns for combat

The role manager's `GetRoleFor(bot)` should handle this automatically since it reads `bot:GetSubRole()` which the addon updates via `ConvertDefector()`.

### 9.6 Hook for Role Change Detection

```lua
-- Proposed hook to detect mid-round role changes:
hook.Add("TTT2UpdateSubrole", "TTTBots_DefectorConversion", function(ply, oldSubrole, newSubrole)
    if not ply:IsBot() then return end
    if newSubrole == ROLE_DEFECTOR then
        -- Force behavior tree refresh
        ply.lastBehavior = nil  -- Clear current behavior
        
        -- Clear any existing attack targets (can't fight anymore)
        ply:SetAttackTarget(nil, "ROLE_CHANGED")
        
        -- Log the conversion
        local chatter = ply:BotChatter()
        if chatter and chatter.On then
            chatter:On("DefectorConverted", {}, false)
        end
    end
end)
```

---

## 10. Jihad Behavior Refinements

### 10.1 Current Issues

1. **No phase awareness** — Detonates as soon as 1 enemy is nearby
2. **No approach behavior** — Bot doesn't actively seek out enemy clusters
3. **No ally protection** — May kill traitor teammates in the blast
4. **Fixed 500 unit radius** — Not configurable
5. **No "optimal moment" calculation** — Doesn't consider kill/death ratio
6. **Missing sameTeams counting** — `sameTeams` is calculated AFTER the chance check

### 10.2 Proposed Jihad Behavior (Defector-Aware)

```lua
function BehaviorJihad.Validate(bot)
    if not TTTBots.Lib.IsTTT2() then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not IsValid(bot) then return false end
    if not bot:Alive() then return false end
    if not BehaviorJihad.HasJihadBomb(bot) then return false end

    local role = bot:GetSubRole()
    local isDefector = (role == ROLE_DEFECTOR)
    local radius = 500
    local players = lib.FindCloseTargets(bot, radius, true)
    
    local enemies = 0
    local allies = 0
    local jesters = 0
    
    for _, player in ipairs(players) do
        if player:GetTeam() == TEAM_JESTER then
            jesters = jesters + 1
        elseif player:GetTeam() ~= bot:GetTeam() then
            enemies = enemies + 1
        else
            allies = allies + 1
        end
    end
    
    -- Never detonate near jesters (they want to be killed)
    if jesters > 0 then return false end
    
    -- Phase-aware minimum enemy threshold
    local ra = bot.BotRoundAwareness and bot:BotRoundAwareness()
    local phase = ra and ra:GetPhase()
    local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
    
    local minEnemies
    if isDefector then
        if phase == PHASE.EARLY then
            minEnemies = 3      -- Wait for good opportunity in early game
        elseif phase == PHASE.MID then
            minEnemies = 2      -- More willing in mid game
        else
            minEnemies = 1      -- Desperate in late game / overtime
        end
    else
        minEnemies = 4          -- Non-defectors need large groups
    end
    
    if enemies < minEnemies then return false end
    
    -- Ally protection: don't detonate if allies outnumber enemies
    if allies >= enemies and isDefector then return false end
    
    -- Kill/death ratio check: enemies should significantly outnumber allies in blast
    local netKills = enemies - allies
    if netKills < 1 then return false end
    
    -- Chance calculation
    local chance = enemies * 2
    if isDefector then chance = chance * 3 end
    chance = chance - (allies * 5)  -- Heavy penalty for ally casualties
    
    local value = math.random(1, 100)
    if value > chance then return STATUS.FAILURE end
    
    return true
end
```

### 10.3 New: DefectorApproach Behavior

This is a **new behavior** that makes the defector actively seek out enemy clusters:

```lua
-- behaviors/defectorapproach.lua (proposed)

TTTBots.Behaviors.DefectorApproach = {}
local BehaviorDefectorApproach = TTTBots.Behaviors.DefectorApproach
BehaviorDefectorApproach.Name = "DefectorApproach"
BehaviorDefectorApproach.Description = "Approach clusters of enemy players to set up a Jihad detonation."
BehaviorDefectorApproach.Interruptible = true

function BehaviorDefectorApproach.Validate(bot)
    if not IsValid(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot:GetSubRole() ~= ROLE_DEFECTOR then return false end
    if not bot:HasWeapon("weapon_ttt_jihad_bomb") then return false end
    
    -- Only approach when in MID phase or later
    local ra = bot.BotRoundAwareness and bot:BotRoundAwareness()
    if not ra then return false end
    local PHASE = TTTBots.Components.RoundAwareness.PHASE
    local phase = ra:GetPhase()
    if phase == PHASE.EARLY then
        -- 10% chance to start approaching in early game (eager defectors)
        return math.random(1, 10) == 1
    end
    
    -- Find enemy clusters
    local cluster = BehaviorDefectorApproach.FindBestCluster(bot)
    if not cluster then return false end
    
    return true
end

function BehaviorDefectorApproach.FindBestCluster(bot)
    local allPlayers = player.GetAll()
    local bestCluster = nil
    local bestScore = 0
    
    for _, ply in ipairs(allPlayers) do
        if not lib.IsPlayerAlive(ply) then continue end
        if ply == bot then continue end
        if ply:GetTeam() == bot:GetTeam() then continue end
        
        -- Count nearby enemies around this player (potential cluster center)
        local nearbyEnemies = 0
        local nearbyAllies = 0
        for _, other in ipairs(allPlayers) do
            if other == bot or other == ply then continue end
            if not lib.IsPlayerAlive(other) then continue end
            local dist = ply:GetPos():Distance(other:GetPos())
            if dist < 600 then
                if other:GetTeam() ~= bot:GetTeam() then
                    nearbyEnemies = nearbyEnemies + 1
                else
                    nearbyAllies = nearbyAllies + 1
                end
            end
        end
        
        -- Score: enemies minus allies penalty
        local score = (nearbyEnemies + 1) - (nearbyAllies * 2)
        if score > bestScore then
            bestScore = score
            bestCluster = ply:GetPos()
        end
    end
    
    return bestCluster, bestScore
end

function BehaviorDefectorApproach.OnStart(bot)
    return STATUS.RUNNING
end

function BehaviorDefectorApproach.OnRunning(bot)
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end
    
    local cluster = BehaviorDefectorApproach.FindBestCluster(bot)
    if not cluster then return STATUS.FAILURE end
    
    loco:SetGoal(cluster)
    
    -- Check if we're close enough for Jihad to take over
    local dist = bot:GetPos():Distance(cluster)
    if dist < 500 then
        return STATUS.SUCCESS  -- Close enough, Jihad behavior will take over
    end
    
    return STATUS.RUNNING
end

function BehaviorDefectorApproach.OnSuccess(bot) end
function BehaviorDefectorApproach.OnFailure(bot) end
function BehaviorDefectorApproach.OnEnd(bot) end
```

---

## 11. Buyable Equipment Design

### 11.1 Corrected Buyable Registration

```lua
-- The Defector Jihad weapon (for TRAITORS to buy and drop)
Registry.DefectorJihad = {
    Name = "Defector Jihad",
    Class = "weapon_ttt_defector_jihad",
    Price = 1,                          -- Costs 1 credit for traitors
    Priority = 4,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = true,                -- Announce to traitor team
    CanBuy = function(ply)
        return testPlyHasTrait(ply, "defector", 12)
    end,
    Roles = GetRolesByTeam(TEAM_TRAITOR),  -- Any traitor can buy it
    PrimaryWeapon = false,
}

-- Remove the DefectorDeagle entry entirely (or keep for backwards compat)
-- Registry.DefectorDeagle should only exist if weapon_ttt2_defector_deagle addon is installed
Registry.DefectorDeagle = {
    Name = "Defector Deagle",
    Class = "weapon_ttt2_defector_deagle",
    Price = 1,
    Priority = 4,
    RandomChance = 1,
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        -- Only register if the weapon entity actually exists
        if not weapons.Get("weapon_ttt2_defector_deagle") then return false end
        return testPlyHasTrait(ply, "defector", 12)
    end,
    Roles = GetRolesByTeam(TEAM_TRAITOR),
    PrimaryWeapon = true,
}
```

### 11.2 Defector's Own Purchases

The defector has 0 credits and `preventFindCredits`/`preventKillCredits`, so they **cannot buy anything**. This is correct — the defector's only weapon is the jihad bomb they received during conversion. No buyable registration is needed for the defector role itself.

However, if a server gives defectors credits via other means (e.g., admin commands, custom addons), the defector shop fallback is `SHOP_FALLBACK_TRAITOR`, meaning they could theoretically buy traitor items. The `BuyableWeapons = "weapon_ttt_jihad_bomb"` setting in the role data should be updated to reflect this is their primary loadout, not a buyable.

---

## 12. Personality & Trait Integration

### 12.1 Current "defector" Trait

```lua
defector = {
    name = "defector",
    description = "Will buy the defector deagle if available in their shop.",
    conflicts = {},
    traitor_only = true,
    effects = { defector = true }
}
```

This trait controls whether a **traitor** bot will buy the defector weapon to convert others. This is correct in concept but needs updating:

```lua
defector = {
    name = "defector",
    description = "Will buy the defector jihad item to convert an innocent into a defector.",
    conflicts = { "jihad" },  -- Don't buy both jihad bomb AND defector jihad
    traitor_only = true,
    effects = { defector = true }
}
```

### 12.2 Defector-Specific Archetype Behaviors

| Archetype | Defector Playstyle |
|-----------|-------------------|
| **Tryhard** | Waits for optimal 3+ enemy cluster in MID/LATE phase. Maximum efficiency. |
| **Hothead** | Detonates as soon as possible, even with just 1 enemy. Impatient. |
| **Stoic** | Patient approach, waits for LATE game, detonates calmly. |
| **Dumb** | Might detonate near allies, doesn't check surroundings carefully. |
| **Nice** | Reluctant to use jihad (feels bad about suicide bombing), delays until necessary. |
| **Bad** | Eager to detonate, targets the largest possible group. |
| **Teamer** | Avoids detonating near traitor allies at all costs, very team-conscious. |
| **Sus/Quirky** | Unpredictable timing, might warn enemies or taunt before detonating. |
| **Casual** | Standard behavior, moderate patience, moderate caution. |

### 12.3 Personality Modifiers for Jihad Behavior

```lua
-- Inside BehaviorJihad.Validate (proposed)
local personality = bot:BotPersonality()
local archetype = personality and personality:GetClosestArchetype()

-- Archetype-based modifiers
local patienceMultiplier = 1.0
local allyCareFactor = 1.0

if archetype == A.Hothead then
    patienceMultiplier = 0.3    -- Very impatient
    allyCareFactor = 0.5        -- Doesn't care as much about allies
elseif archetype == A.Tryhard then
    patienceMultiplier = 2.0    -- Very patient
    allyCareFactor = 1.5        -- Very careful about allies
elseif archetype == A.Dumb then
    patienceMultiplier = 0.5    -- Somewhat impatient
    allyCareFactor = 0.3        -- Might blow up allies
elseif archetype == A.Nice then
    patienceMultiplier = 1.5    -- Patient
    allyCareFactor = 2.0        -- Very protective of allies
elseif archetype == A.Teamer then
    patienceMultiplier = 1.0
    allyCareFactor = 3.0        -- Extremely protective of allies
end

-- Apply modifiers
minEnemies = math.ceil(minEnemies * patienceMultiplier)
local maxAlliesInBlast = math.floor(1 / allyCareFactor)
```

---

## 13. Chatter & Locale Additions

### 13.1 New Chatter Events Needed

| Event | When | Team-Only? |
|-------|------|-----------|
| `DefectorConverted` | When a bot is converted to defector | No (public surprise) |
| `DefectorApproaching` | When defector is moving toward a cluster | Yes (traitor team) |
| `DefectorDropping` | When traitor drops the defector jihad for a target | Yes (traitor team) |

### 13.2 Proposed Locale Additions

```lua
-- locale/en/sh_chats.lua additions:

RegisterCategory("DefectorConverted", P.IMPORTANT, "When a bot has been converted to a defector.")
Line("What just happened to me?", A.Default)
Line("I feel... different", A.Stoic)
Line("Oh god, what was that weapon?", A.Nice)
Line("Heh, interesting... very interesting", A.Bad)
Line("WHAT THE HELL DID THEY DO TO ME", A.Hothead)
Line("Wait, I'm a traitor now?", A.Dumb)
Line("I'll make the most of this...", A.Tryhard)
Line("Oh no... I've become one of them", A.Teamer)
Line("Oops! Didn't mean to pick that up", A.Sus)
Line("Cool, free weapon!", A.Casual)

RegisterCategory("DefectorApproaching", P.MODERATE, "When a defector bot is approaching an enemy cluster.")
Line("Moving in...", A.Default)
Line("Getting close, don't be near me", A.Tryhard)
Line("Here I come...", A.Bad)
Line("This is it...", A.Stoic)
Line("LEEROY JENKINS", A.Hothead)
Line("Should I really do this?", A.Nice)
Line("Walking toward them now", A.Casual)

RegisterCategory("DefectorDropping", P.IMPORTANT, "When a traitor drops the defector jihad for someone.")
Line("Dropping the defector bomb near {{player}}", A.Default)
Line("Hey {{player}}, free weapon!", A.Sus)
Line("Leaving a little present for {{player}}", A.Bad)
Line("Dropping the defector jihad for {{player}} to pick up", A.Tryhard)
Line("{{player}} is getting a surprise", A.Hothead)
```

### 13.3 Expand Existing Jihad Lines

The current `JihadBombWarn` and `JihadBombUse` events only have `A.Default` lines. Adding archetype-specific lines:

```lua
RegisterCategory("JihadBombWarn", P.IMPORTANT, "When a bot is warning about a Jihad bomb.")
-- Existing Default lines...
Line("ALLAHU AKBAR!!!!", A.Hothead)
Line("I'm sorry, but this has to happen", A.Nice)
Line("Detonating in 3... 2... 1...", A.Tryhard)
Line("What does this button do?", A.Dumb)
Line("For the greater good", A.Stoic)
Line("See you all in hell!", A.Bad)
Line("Sorry guys, team needs this", A.Teamer)
Line("Oops, wrong button!", A.Sus)
Line("Welp, here goes nothing", A.Casual)

RegisterCategory("JihadBombUse", P.IMPORTANT, "When a bot uses a Jihad bomb.")
-- Existing Default lines...
Line("BOOM BABY!", A.Hothead)
Line("I'm so sorry...", A.Nice)
Line("Calculated.", A.Tryhard)
Line("Wait what happened", A.Dumb)
Line("...", A.Stoic)
Line("HAHAHAHA DIE", A.Bad)
Line("For my team!", A.Teamer)
Line("Just a prank bro!", A.Sus)
Line("GG", A.Casual)
```

---

## 14. Edge Cases & Failure Modes

### 14.1 Role Conversion Edge Cases

| Edge Case | Description | Handling |
|-----------|-------------|---------|
| **Bot picks up defector jihad but isn't innocent** | The `WeaponEquip` hook only converts `ROLE_INNOCENT` on `TEAM_INNOCENT` | Safe — non-innocents keep the weapon but aren't converted. Bot should drop it. |
| **Defector dies before detonating** | Normal death, no special handling needed | Bot respawns (if applicable) as whatever the respawn system gives them |
| **Multiple defectors** | Multiple traitors could create multiple defectors | Each operates independently with their own jihad bomb |
| **Defector with no jihad bomb** | Bug: conversion happened but no bomb given | Fallback: defector should still blend/patrol, has no offensive capability |
| **Pharaoh as target** | ConVar `ttt_defector_convert_pharaoh` controls this | Bot should check this ConVar before targeting Pharaohs |
| **Target already has full weapons** | Innocent might not be able to pick up the dropped weapon (full slots) | Bot should try a different target after timeout |
| **Role change mid-behavior** | Bot is doing innocent things when suddenly converted | Clear `lastBehavior`, let tree re-evaluate on next tick |

### 14.2 Jihad Detonation Edge Cases

| Edge Case | Description | Handling |
|-----------|-------------|---------|
| **Detonating in closed room** | Blast radius limited by walls | Bot should prefer open areas with line-of-sight to many enemies |
| **Only allies in blast radius** | No enemies, only friendlies | Jihad.Validate must return false if `enemies < 1` |
| **Jester in blast radius** | Killing jester is bad for the team | Jihad.Validate returns false if any jester is present |
| **Bot is last traitor** | Should detonate ASAP (desperation) | Lower thresholds dramatically in OVERTIME phase |
| **Jihad bomb removed** | Another player steals/removes the bomb | Jihad.Validate returns false, bot falls through to Patrol |
| **Bot disconnects during approach** | Standard bot disconnection | No special handling needed |

### 14.3 CreateDefector Edge Cases

| Edge Case | Description | Handling |
|-----------|-------------|---------|
| **No innocents alive** | Can't create a defector | CreateDefector.Validate returns false |
| **All innocents are near witnesses** | Risky to drop weapon visibly | Prefer isolated innocents, add witness check |
| **Innocent doesn't pick up weapon** | Dropped weapon sits on ground | Timeout after ~10 seconds, try different target or pick weapon back up |
| **Weapon entity removed** | Map cleanup or admin removes the dropped weapon | Behavior fails gracefully |
| **Traitor has no credits** | Can't buy `weapon_ttt_defector_jihad` | Buyable system handles this — won't trigger behavior |

---

## 15. Testing Strategy

### 15.1 Unit-Level Tests

| Test | Description | Expected Result |
|------|-------------|----------------|
| Role Registration | `TTTBots.Roles.GetRole("defector")` returns valid RoleData | All properties match design |
| BTree Assignment | Defector bot gets correct behavior tree | Tree contains DefectorApproach + Jihad |
| Jihad Validation (empty) | No enemies nearby | Returns false |
| Jihad Validation (1 enemy, EARLY) | 1 enemy, EARLY phase | Returns false (need 3+) |
| Jihad Validation (2 enemies, MID) | 2 enemies, MID phase | Returns true |
| Jihad Validation (jester present) | 1+ enemies but jester in radius | Returns false |
| Jihad Validation (allies outnumber enemies) | 3 allies, 2 enemies | Returns false |
| Morality hostility skip | Defector bot runs hostility policy | No attack target set |
| Buyable registration | `weapon_ttt_defector_jihad` in traitor shop | Buyable registered with correct roles |

### 15.2 Integration Tests

| Test | Description | How to Verify |
|------|-------------|--------------|
| Full conversion flow | Traitor bot buys item → drops → innocent bot picks up → becomes defector | Watch bot behavior change, check `bot:GetSubRole()` |
| Post-conversion behavior | Defector bot patrols, approaches clusters, detonates | Observe behavior tree transitions via debug overlay |
| Gun damage blocked | Defector bot tries to use gun (shouldn't, but if forced) | Confirm 0 damage dealt |
| Jihad damage works | Defector bot detonates near enemies | Confirm enemies take damage |
| Multi-bot scenario | Multiple defectors in same round | Each operates independently |
| Human target conversion | Traitor bot drops weapon near human innocent | Human receives weapon, can pick up |

### 15.3 Stress Tests

| Test | Description |
|------|-------------|
| 16-bot match, 3 traitors, 1 buys defector | Full bot match with defector conversion |
| Defector + Pharaoh interaction | Defector near Pharaoh's ankh, confirm no ankh damage |
| Rapid role changes | Convert defector → defector dies → gets revived → check role state |
| No jihad addon installed | `ROLE_DEFECTOR` doesn't exist, all defector code gracefully no-ops |

---

## 16. Implementation Priority & Phasing

### Phase 1 — Critical Fixes (Immediate)

**Goal:** Make the existing defector bot work correctly with the actual role addon.

| Task | File | Effort |
|------|------|--------|
| Fix `roles/defector.lua` — expand properties, new BTree | `roles/defector.lua` | Medium |
| Add morality hostility guard for defectors | `sv_morality_hostility.lua` | Small |
| Add morality arbitration guard for defectors | `sv_morality_arbitration.lua` | Small |
| Fix jihad.lua — add ally protection, phase awareness | `behaviors/jihad.lua` | Medium |
| Fix buyable registration — correct weapon class and roles | `data/sv_default_buyables.lua` | Small |

### Phase 2 — Core New Behaviors (Next Sprint)

**Goal:** Add the drop-based conversion mechanism and DefectorApproach behavior.

| Task | File | Effort |
|------|------|--------|
| Rewrite `createdefector.lua` for drop-based conversion | `behaviors/createdefector.lua` | Large |
| Create `defectorapproach.lua` — cluster seeking behavior | `behaviors/defectorapproach.lua` | Medium |
| Add `TTT2UpdateSubrole` hook for conversion detection | `roles/defector.lua` or new file | Small |
| Update `sv_tree.lua` — register DefectorApproach in behavior list | `lib/sv_tree.lua` | Small |

### Phase 3 — Polish & Personality (Future)

**Goal:** Make defector bots feel human and varied.

| Task | File | Effort |
|------|------|--------|
| Add archetype-specific jihad timing modifiers | `behaviors/jihad.lua` | Medium |
| Add new chatter events (DefectorConverted, DefectorApproaching, DefectorDropping) | `locale/en/sh_chats.lua` | Small |
| Register chatter events in probability table | `sv_chatter_events.lua` | Small |
| Expand JihadBombWarn/Use lines with archetype variants | `locale/en/sh_chats.lua` | Small |
| Update trait description text | `data/sh_traits.lua` | Trivial |

### Phase 4 — Advanced Intelligence (Optional)

**Goal:** Make defector bots genuinely strategic.

| Task | File | Effort |
|------|------|--------|
| Cluster heatmap — track where players tend to gather | New component | Large |
| Predictive detonation timing — based on player movement patterns | `behaviors/jihad.lua` | Large |
| Deception refinement — defector actively lies about suspicions | `behaviors/defectorblend.lua` | Medium |
| Inter-bot coordination — traitor warns defector of good detonation spots | Chatter/coordination system | Large |

---

## Appendix A: Complete Proposed `roles/defector.lua`

```lua
if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DEFECTOR then return false end

TEAM_JESTER = TEAM_JESTER or 'jesters'

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local allyTeams = {
    [TEAM_TRAITOR] = true,
    [TEAM_JESTER] = true,
}

local bTree = {
    _prior.Requests,
    _prior.Chatter,
    _bh.DefectorApproach,
    _bh.Jihad,
    _prior.SelfDefense,
    _prior.Accuse,
    _prior.Deception,
    _prior.Restore,
    _prior.Investigate,
    _prior.Minge,
    _prior.Patrol,
}

local roleDescription = "The Defector is a former innocent converted to the traitor team. " ..
    "They cannot deal normal weapon damage and must use the Jihad Bomb to suicide-bomb " ..
    "enemy clusters. They should blend with innocents until the optimal moment to detonate."

local defector = TTTBots.RoleData.New("defector", TEAM_TRAITOR)
defector:SetDefusesC4(false)
defector:SetPlantsC4(false)
defector:SetCanHaveRadar(false)         -- 0 credits, can't buy radar
defector:SetCanCoordinate(false)        -- Acts independently
defector:SetStartsFights(false)         -- Cannot initiate gun combat
defector:SetTeam(TEAM_TRAITOR)
defector:SetBuyableWeapons("")          -- Cannot buy anything (0 credits)
defector:SetUsesSuspicion(false)        -- Knows who enemies are
defector:SetIsFollower(true)            -- Blends with innocent groups
defector:SetAutoSwitch(false)           -- Don't auto-switch weapons
defector:SetCanSnipe(false)             -- Cannot use guns for damage
defector:SetCanHide(true)              -- Should try to blend in
defector:SetBTree(bTree)
defector:SetAlliedTeams(allyTeams)
defector:SetLovesTeammates(true)
defector:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(defector)

-- Hook: detect mid-round conversion to defector
hook.Add("TTT2UpdateSubrole", "TTTBots_DefectorConversion", function(ply, oldSubrole, newSubrole)
    if not ply:IsBot() then return end
    if not (ROLE_DEFECTOR and newSubrole == ROLE_DEFECTOR) then return end
    
    -- Clear current behavior to force tree re-evaluation
    ply.lastBehavior = nil
    
    -- Clear any existing attack targets (defector can't fight)
    if ply.SetAttackTarget then
        ply:SetAttackTarget(nil, "ROLE_CHANGED_DEFECTOR")
    end
    
    -- Announce conversion via chatter
    timer.Simple(2, function()
        if not IsValid(ply) then return end
        local chatter = ply:BotChatter()
        if chatter and chatter.On then
            chatter:On("DefectorConverted", {}, false)
        end
    end)
end)

return true
```

## Appendix B: Weapon Class Reference

| Weapon Class | Source Addon | Who Holds It | Purpose |
|-------------|-------------|-------------|---------|
| `weapon_ttt_defector_jihad` | `ttt_defector_role-master` | Traitor (buys from shop, drops for innocent) | Conversion item — picked up by innocent to convert them |
| `weapon_ttt_jihad_bomb` | TTT2 / jihad addon | Defector (received on conversion) | The actual detonatable suicide bomb |
| `weapon_ttt2_defector_deagle` | Unknown/fictional | (Bot mod assumes) Traitor | Shoot-to-convert deagle — **does not exist in ttt_defector_role addon** |

## Appendix C: ConVar Reference

| ConVar | Default | Description |
|--------|---------|-------------|
| `ttt_defector_convert_pharaoh` | 1 | Whether Pharaohs can be converted to Defector (0 = no, 1 = yes) |

## Appendix D: Hook Reference

| Hook | Source | Purpose |
|------|--------|---------|
| `WeaponEquip` / `DefectorJihadPickup` | `weapon_ttt_defector_jihad.lua` | Detects innocent picking up defector jihad → triggers conversion |
| `PlayerTakeDamage` / `DefectorNoDamage` | `defector/shared.lua` | Blocks all non-explosive damage from defectors |
| `TTT2PharaohPreventDamageToAnkh` / `TTT2PharaohPreventDamageToAnkhDefector` | `defector/shared.lua` | Prevents defectors from damaging ankhs |
| `TTT2UpdateSubrole` | TTT2 core | Fires when any player's subrole changes (used for conversion detection) |

---

*End of Analysis Document*
