--- Undercover Agent role integration for TTT Bots 2
--- The Undercover Agent is a unique Innocent sub-role with a custom team.
--- Key mechanics:
---   • TEAM_INNOCENT (but registered with a custom team icon/color via InitCustomTeam)
---   • unknownTeam = true — hidden from both sides
---   • isSubRole = true; isInnocentRole = true
---   • SHOP_DISABLED — no regular shop
---   • surviveBonus = 2 — large bonus for surviving
---   • If the Detective dies, the Undercover Agent is promoted to Detective
---     (SetRole(ROLE_DETECTIVE) + SetDefaultCredits()) — server-driven via PostPlayerDeath
---   • Bot is effectively an elite hidden innocent who becomes detective mid-round
---
--- Bot behavior:
---   • InnocentLike — fight back, use suspicion, no coordination
---   • The detective promotion is fully server-driven; bot auto-gets detective loadout
---   • After promotion, the bot should naturally get a DetectiveLike tree via the
---     detective.lua role file that activates upon role change

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_UCA then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _bh.InvestigateCorpse,   -- Prepare for detective duties when promoted
    _prior.Restore,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol,
}

local roleDescription = "You are the Undercover Agent — a hidden innocent who becomes the Detective "
    .. "if the current Detective is killed. Stay alive and gather intel as an innocent for now. "
    .. "If the Detective dies, you will automatically be promoted and gain detective powers."

local uca = TTTBots.RoleData.New("uca", TEAM_INNOCENT)
uca:SetDefusesC4(true)
uca:SetPlantsC4(false)
uca:SetTeam(TEAM_INNOCENT)
uca:SetBTree(bTree)
uca:SetCanCoordinate(false)
uca:SetCanHaveRadar(false)
uca:SetStartsFights(true)
uca:SetUsesSuspicion(true)    -- unknownTeam
uca:SetCanSnipe(false)
uca:SetCanHide(false)
uca:SetKnowsLifeStates(false)
uca:SetLovesTeammates(false)
uca:SetAlliedTeams({ [TEAM_INNOCENT] = true })
uca:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(uca)

return true
