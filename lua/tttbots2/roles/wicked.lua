if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_WICKED then return false end


local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _bh.ClairvoyantWicked,
    _bh.Jihad,
    _prior.FightBack,
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

local wicked = TTTBots.RoleData.New("wicked")
wicked:SetDefusesC4(false)
wicked:SetPlantsC4(false)
wicked:SetCanHaveRadar(true)
wicked:SetCanCoordinate(true)
wicked:SetStartsFights(true)
wicked:SetTeam(TEAM_TRAITOR)
wicked:SetUsesSuspicion(false)
wicked:SetBTree(bTree)
wicked:SetAlliedTeams(allyTeams)
wicked:SetLovesTeammates(true)
TTTBots.Roles.RegisterRole(wicked)

return true

