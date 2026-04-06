--- Suicide Grunt (Covenant) role integration for TTT Bots 2
--- The Suicide Grunt is an omniscient Covenant-team kamikaze role.
--- Key mechanics:
---   • TEAM_COVENANT — same team as the Hunter; coordinate together
---   • isOmniscientRole: full life-state awareness
---   • No shop (SHOP_DISABLED)
---   • Receives weapon_grunt_bomb as role loadout — a suicide bomb weapon
---   • Small model (Grunt); very excitable and loud
---   • When a Hunter is in the round, the Grunt follows their Hunter as "commander"
---   • On activation of the bomb, the Grunt explodes for area damage — server-driven
---   • networkRoles = {JESTER}, traitorButton = 1
---   • KOSAll / KOSedByAll: hunts all non-Covenant
---   • Revive system: Grunt may respawn a limited number of times (sv_sg_handler.lua)
---
--- Bot behavior:
---   • Rush targets aggressively — the Grunt wants to get close and detonate
---   • Jihad-like behavior: close distance rapidly for explosion value
---   • Coordinate with Hunter teammates
---   • No sniping; no hiding — maximum aggression

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SG then return false end

TEAM_COVENANT = TEAM_COVENANT or "covenant"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _bh.Jihad,          -- Rush in and detonate
    _bh.Stalk,
    _prior.Patrol,
}

local roleDescription = "You are the Suicide Grunt (Covenant) — a small, fast, explosive kamikaze. "
    .. "Equip your grunt bomb and RUSH towards enemies to detonate. "
    .. "Follow your Hunter commander if one is alive. "
    .. "Coordinate with the Covenant team. You may respawn a limited number of times."

local sgrunt = TTTBots.RoleData.New("sg", TEAM_COVENANT)
sgrunt:SetDefusesC4(false)
sgrunt:SetPlantsC4(false)
sgrunt:SetTeam(TEAM_COVENANT)
sgrunt:SetBTree(bTree)
sgrunt:SetCanCoordinate(true)    -- Coordinate with Hunter/sgrunt teammates
sgrunt:SetCanHaveRadar(true)     -- isOmniscientRole
sgrunt:SetStartsFights(true)
sgrunt:SetUsesSuspicion(false)   -- Public team
sgrunt:SetCanSnipe(false)
sgrunt:SetCanHide(false)
sgrunt:SetKnowsLifeStates(true)  -- isOmniscientRole
sgrunt:SetKOSAll(true)
sgrunt:SetKOSedByAll(true)
sgrunt:SetLovesTeammates(true)
sgrunt:SetAlliedTeams({ [TEAM_COVENANT] = true })
sgrunt:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(sgrunt)

return true
