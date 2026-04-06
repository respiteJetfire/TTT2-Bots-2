--- Revolutionary role integration for TTT Bots 2
--- The Revolutionary is a public-facing, policing, omniscient Innocent sub-role.
--- Key mechanics:
---   • isPublicRole + isPolicingRole: everyone knows the Revolutionary
---   • unknownTeam = true — uses suspicion like other unknown-team innocents
---   • SHOP_FALLBACK_TRAITOR: access to traitor shop items
---   • Credits (3) awarded on death of enemies
---   • On role change receives item_ttt_armor
---   • Scores heavily for kills (8×), penalized for team-kills (−8×)
---
--- Bot behavior:
---   • DetectiveLike builder — investigate, police, use shop
---   • The traitor-shop fallback means they can purchase aggressive items
---   • High aggression: sniper and hiding options enabled for ambush plays

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_REVOL then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _prior.Restore,
    _bh.InvestigateCorpse,
    _bh.UseDNAScanner,
    _prior.Investigate,
    _bh.Decrowd,
    _prior.Patrol,
}

local roleDescription = "You are the Revolutionary, a public policing Innocent with the traitor shop. "
    .. "Everyone knows your role. You score heavily for kills. "
    .. "Investigate corpses, use DNA scanner, and buy aggressive items from the shop to police the map. "
    .. "Coordinate openly with other innocents to take down traitors."

local revolutionary = TTTBots.RoleData.New("revol", TEAM_INNOCENT)
revolutionary:SetDefusesC4(true)
revolutionary:SetTeam(TEAM_INNOCENT)
revolutionary:SetBTree(bTree)
revolutionary:SetCanCoordinate(false)   -- public role; no need for hidden coordination
revolutionary:SetCanHaveRadar(true)
revolutionary:SetStartsFights(true)
revolutionary:SetUsesSuspicion(true)    -- unknownTeam
revolutionary:SetCanSnipe(true)
revolutionary:SetCanHide(true)
revolutionary:SetKnowsLifeStates(true)  -- isOmniscientRole
revolutionary:SetLovesTeammates(false)
revolutionary:SetAlliedTeams({ [TEAM_INNOCENT] = true })
revolutionary:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(revolutionary)

return true
