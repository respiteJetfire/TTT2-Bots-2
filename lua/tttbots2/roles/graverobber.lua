if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_GRAVEROBBER then return false end


local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _bh.PostRevival,
    _bh.CaptureAnkh,
    _bh.DestroyAnkh,
    _bh.HuntAnkh,
    _prior.Requests,
    _prior.Convert,
    _prior.Support,
    _bh.GuardAnkh,
    _bh.Roledefib,
    _bh.PlantBomb,
    _bh.InvestigateCorpse,
    _prior.Restore,
    _bh.FollowPlan,
    _bh.Interact,
    _prior.Minge,
    _prior.Investigate,
    _prior.Patrol
}

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_TRAITOR] = true
}

local roleDescription = "The Graverobber is a special Traitor role. When a Pharoah places their Ankh, a random Traitor is assigned as their opposing counterpart, the Graverobber. The Graverobber maintains the same objective and allegiances as the Traitor, but with a twist. If you find the Ankh, you can capture it and gain it's extra life and healing properties for yourself!"

local graverobber = TTTBots.RoleData.New("graverobber")
graverobber:SetDefusesC4(false)
graverobber:SetPlantsC4(false)
graverobber:SetCanHaveRadar(true)
graverobber:SetCanCoordinate(true)
graverobber:SetStartsFights(true)
graverobber:SetTeam(TEAM_TRAITOR)
graverobber:SetUsesSuspicion(false)
graverobber:SetBTree(bTree)
graverobber:SetAlliedTeams(allyTeams)
graverobber:SetLovesTeammates(true)
graverobber:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(graverobber)

return true

