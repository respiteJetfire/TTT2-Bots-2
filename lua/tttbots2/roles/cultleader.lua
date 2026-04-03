--- Cult Leader role integration for TTT Bots 2
--- The Cult Leader heads the TEAM_CULTIST faction, a custom team.
--- They wield weapon_ttt_culttome — a melee weapon that:
---   • Converts non-cultist players into Cultists on hit (up to max conversions)
---   • Heals existing Cultists on hit
---
--- The Cult Leader has traitor-like shop access, armor, and isOmniscientRole.
--- They win when the cultist team is the last standing.
---
--- Bot behavior:
---   • Uses CultTomeConvert behavior to convert players with the tome
---   • Falls back to aggressive combat when conversions are maxed
---   • Heals injured Cultists by hitting them with the tome
---   • Coordinates with Cultists (lovesTeammates)
---   • Has shop access (SHOP_FALLBACK_TRAITOR)

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_CULTLEADER then return false end

TEAM_CULTIST = TEAM_CULTIST or "cultist"
TEAM_JESTER = TEAM_JESTER or "jesters"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "You are the Cult Leader, head of the Cultist faction. You wield the Cult Tome — "
    .. "a melee weapon that converts players into Cultists when you hit them (up to the configured max). "
    .. "Hitting existing Cultists with the tome heals them instead. "
    .. "You have traitor-shop access and armor. Coordinate with your Cultists to eliminate all other factions."

-- Custom behavior tree: conversion priority, then combat
local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Requests,
    _bh.CultTomeConvert,       -- [CUSTOM] Use tome to convert or heal
    _prior.Support,
    _bh.Roledefib,
    _prior.Restore,
    _bh.Stalk,                 -- Hunt isolated targets when conversions are done
    _bh.Interact,
    _prior.Investigate,
    _prior.Patrol,
}

local cultleader = TTTBots.RoleData.New("cultleader", TEAM_CULTIST)
cultleader:SetDefusesC4(false)
cultleader:SetPlantsC4(true)
cultleader:SetTeam(TEAM_CULTIST)
cultleader:SetBTree(bTree)
cultleader:SetCanCoordinate(true)
cultleader:SetCanHaveRadar(true)
cultleader:SetStartsFights(true)
cultleader:SetUsesSuspicion(false)
cultleader:SetKnowsLifeStates(true)           -- isOmniscientRole
cultleader:SetLovesTeammates(true)
cultleader:SetAlliedTeams({ [TEAM_CULTIST] = true, [TEAM_JESTER] = true })
cultleader:SetAlliedRoles({ cultleader = true, cultist = true })
cultleader:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(cultleader)

return true
