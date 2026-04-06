--- Suicide Barrel role integration for TTT Bots 2
--- The Suicide Barrel is a custom-team (TEAM_BARRELS) omniscient explosive role.
--- Key mechanics:
---   • TEAM_BARRELS — completely independent team; KOSAll / KOSedByAll
---   • isOmniscientRole: full life-state awareness
---   • No shop (SHOP_DISABLED)
---   • Strips all weapons on loadout and gives only sb_barrelsuicider
---     (a weapon that, when activated, triggers a barrel explosion)
---   • Player model changed to an explosive barrel (props_c17/oildrum001_explosive)
---   • Movement is altered (barrel-like)
---   • The explosion is triggered by using the barrel weapon — server-driven barrel
---   • score.timelimitMultiplier = -2: strongly penalized for time wasting
---   • networkRoles = {JESTER}: jesters know the barrel
---
--- Bot behavior:
---   • Rush targets aggressively (barrel must get close to be effective)
---   • Jihad-like: close distance rapidly, trigger explosion
---   • Solo role: no teammates, no coordination
---   • NeutralOverride false; KOSAll ensures bot is always fighting someone

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SBARREL then return false end

TEAM_BARRELS = TEAM_BARRELS or "barrels"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _bh.Jihad,      -- Rush and explode
    _bh.Stalk,
    _prior.Patrol,
}

local roleDescription = "You are the Suicide Barrel — a mobile explosive disguised as a barrel. "
    .. "You have only your barrel bomb weapon. Rush towards enemies and detonate. "
    .. "You are alone; no teammates. Everyone is your target. "
    .. "Move fast and get close before exploding."

local sbarrel = TTTBots.RoleData.New("sbarrel", TEAM_BARRELS)
sbarrel:SetDefusesC4(false)
sbarrel:SetPlantsC4(false)
sbarrel:SetTeam(TEAM_BARRELS)
sbarrel:SetBTree(bTree)
sbarrel:SetCanCoordinate(false)
sbarrel:SetCanHaveRadar(false)
sbarrel:SetStartsFights(true)
sbarrel:SetUsesSuspicion(false)
sbarrel:SetCanSnipe(false)
sbarrel:SetCanHide(false)
sbarrel:SetKnowsLifeStates(true)  -- isOmniscientRole
sbarrel:SetKOSAll(true)
sbarrel:SetKOSedByAll(true)
sbarrel:SetLovesTeammates(false)
sbarrel:SetAlliedTeams({})
sbarrel:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(sbarrel)

return true
