--- Chef role integration for TTT Bots 2
--- The Chef is an innocent subrole with unknownTeam (doesn't know teammates).
--- The Chef automatically cooks food on a timer that heals ALL alive players.
--- The cooking is entirely server-driven (ChefCooking timer) — no bot action needed.
---
--- The Chef has disableSync = true (role is hidden from the player) and
--- unknownTeam = true (doesn't know who their teammates are). This means
--- the bot should act like a cautious innocent who doesn't know allies.
---
--- Bot behavior:
---   • InnocentLike base with unknownTeam awareness
---   • Cannot start fights (passive healer role)
---   • Uses suspicion system (since unknownTeam = true)
---   • No shop access (SHOP_DISABLED)
---   • Cooking is automatic — bot just plays normally

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_CHEF then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "You are the Chef, an innocent subrole that doesn't know who their teammates are. "
    .. "You automatically cook food on a timer that heals all alive players. "
    .. "You have no shop and cannot buy items. Play carefully — you don't know who is on your side. "
    .. "Your cooking benefits everyone, so stay alive to keep healing the round."

-- Custom tree: innocent-like but with unknownTeam (no coordination, uses suspicion)
local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Requests,
    _prior.Accuse,
    _bh.InvestigateCorpse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol,
}

local chef = TTTBots.RoleData.New("chef", TEAM_INNOCENT)
chef:SetDefusesC4(true)
chef:SetPlantsC4(false)
chef:SetTeam(TEAM_INNOCENT)
chef:SetBTree(bTree)
chef:SetCanCoordinate(false)           -- unknownTeam: can't coordinate
chef:SetCanCoordinateInnocent(false)   -- unknownTeam: can't coordinate with innocents
chef:SetCanHaveRadar(false)
chef:SetStartsFights(false)            -- Passive role
chef:SetUsesSuspicion(true)            -- unknownTeam: uses suspicion to figure out allies
chef:SetKOSUnknown(false)
chef:SetLovesTeammates(false)          -- unknownTeam: doesn't know who teammates are
chef:SetCanHide(true)
chef:SetCanSnipe(true)
chef:SetAlliedTeams({ [TEAM_INNOCENT] = true })
chef:SetAlliedRoles({ chef = true })   -- Only knows self
chef:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(chef)

return true
