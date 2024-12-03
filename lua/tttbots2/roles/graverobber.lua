if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_GRAVEROBBER then return false end


local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.FightBack,
    _bh.CaptureAnkh,
    _prior.Requests,
    _prior.Convert,
    _prior.Support,
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
TTTBots.Roles.RegisterRole(graverobber)

return true

