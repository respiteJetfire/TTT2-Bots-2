--- Sacrifice role integration for TTT Bots 2
--- The Sacrifice is a no-shop, corpse-radar Innocent sub-role.
--- Key mechanics:
---   • unknownTeam = true — hidden team alignment
---   • No shop (SHOP_DISABLED), no credits
---   • Receives weapon_ttt_sacrificedefi on loadout — a special defibrillator
---     that can revive dead players (exact conditions depend on server convars)
---   • Has a CustomRadar that shows corpses (prop_ragdoll) and ttt_decoy positions
---   • Winning condition: survive with innocents
---
--- Bot behavior:
---   • InnocentLike with corpse investigation priority — they want to find and
---     interact with corpses (the defibrillator is their core tool)
---   • unknownTeam: uses suspicion system
---   • No shop; relies on starting weapons and the defibrillator
---   • Corpse radar is fully server-driven; no bot tracking needed

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SACRIFICE then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _bh.InvestigateCorpse,   -- Core loop: find corpses to use the defibrillator
    _prior.Restore,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol,
}

local roleDescription = "You are the Sacrifice — an Innocent with a defibrillator and corpse radar. "
    .. "You can see all dead bodies on the radar. Approach corpses and use your defibrillator "
    .. "to potentially revive fallen innocents. Fight back if attacked, but your priority is "
    .. "finding and reviving the dead rather than hunting traitors."

local sacrifice = TTTBots.RoleData.New("sacrifice", TEAM_INNOCENT)
sacrifice:SetDefusesC4(true)
sacrifice:SetTeam(TEAM_INNOCENT)
sacrifice:SetBTree(bTree)
sacrifice:SetCanCoordinate(false)
sacrifice:SetCanHaveRadar(false)   -- Has CustomRadar (corpse-only), not full player radar
sacrifice:SetStartsFights(true)
sacrifice:SetUsesSuspicion(true)   -- unknownTeam
sacrifice:SetCanSnipe(false)
sacrifice:SetCanHide(false)
sacrifice:SetKnowsLifeStates(false)
sacrifice:SetLovesTeammates(false)
sacrifice:SetAlliedTeams({ [TEAM_INNOCENT] = true })
sacrifice:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(sacrifice)

return true
