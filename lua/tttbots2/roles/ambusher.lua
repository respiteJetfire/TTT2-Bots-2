--- Ambusher role integration for TTT Bots 2
--- The Ambusher is a Traitor subrole with a unique mechanic:
---   • Standing still grants a damage multiplier and marker vision of nearby players
---   • Moving removes the damage buff and marker vision
---
--- Bot behavior:
---   • Standard traitor tactics: stalk, coordinate, fight
---   • Prefers to camp/ambush: will find a spot and wait for targets
---   • Uses the existing Stalk behavior aggressively (stalk → stop → attack)
---   • Extra emphasis on seeking cover and sniping positions
---
--- The damage buff and marker vision are handled server-side by the Ambusher
--- addon's FinishMove and EntityTakeDamage hooks — the bot just needs to
--- stand still when it wants the buff, which naturally happens during combat.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_AMBUSHER then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "You are the Ambusher, a Traitor subrole that gains a damage buff and wallhack-style "
    .. "marker vision when standing still. Movement removes the buff instantly. "
    .. "Find a good hiding spot, let enemies come to you, and strike with boosted damage. "
    .. "Use traitor coordination and your shop to set up deadly ambushes."

-- Custom tree: emphasizes camping and sniping over active stalking
local bTree = {
    _prior.Chatter,
    _prior.FightBack,              -- React to immediate combat (standing still → damage buff!)
    _prior.Requests,
    _prior.Deception,              -- Alibi building, blend in
    _bh.Stalk,                     -- Stalk isolated targets then stop to ambush
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Patrol,
}

local ambusher = TTTBots.RoleBuilder.TraitorLike("ambusher", TEAM_TRAITOR)
ambusher:SetBTree(bTree)
ambusher:SetCanSnipe(true)          -- Ambusher benefits greatly from sniper spots
ambusher:SetCanHide(true)           -- Find hiding spots for ambushes
ambusher:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(ambusher)

print("[TTT Bots 2] Ambusher role integration loaded — camping traitor with damage buff.")

return true
