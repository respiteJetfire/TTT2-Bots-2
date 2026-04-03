--- Arsonist role integration for TTT Bots 2
--- The Arsonist is a Traitor subrole with fire-themed loadout:
---   • weapon_ttt2_arsonthrower (flamethrower — primary weapon)
---   • weapon_ttt_flaregun (ranged fire starter)
---   • item_ttt_nofiredmg (immune to fire damage)
---
--- Bot behavior:
---   • Standard traitor tactics with emphasis on close-range combat
---   • Prefers the flamethrower for engagements (devastating at close range)
---   • Stalks isolated targets to maximize flamethrower effectiveness
---   • Uses deception to get close before attacking

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_ARSONIST then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "You are the Arsonist, a Traitor subrole armed with a flamethrower and flare gun. "
    .. "You are immune to fire damage. Get close to your targets and burn them down. "
    .. "The flamethrower is devastating at close range — stalk isolated victims and strike. "
    .. "Use your fire immunity to create chaos with environmental fires."

-- Custom tree: close-range aggression, stalking for flamethrower range
local bTree = {
    _prior.Chatter,
    _prior.FightBack,              -- React to combat
    _prior.Requests,
    _prior.Deception,              -- Get close under cover of deception
    _bh.Stalk,                     -- Stalk for close-range flamethrower kills
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Patrol,
}

local arsonist = TTTBots.RoleBuilder.TraitorLike("arsonist", TEAM_TRAITOR)
arsonist:SetBTree(bTree)
arsonist:SetCanSnipe(false)         -- Arsonist is a close-range fighter, not a sniper
arsonist:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(arsonist)

print("[TTT Bots 2] Arsonist role integration loaded — fire-themed traitor with flamethrower.")

return true
