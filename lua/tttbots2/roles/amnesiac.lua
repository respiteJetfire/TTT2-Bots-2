if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_AMNESIAC then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local allyTeams = {
    [TEAM_JESTER] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _bh.InvestigateCorpse,
    _prior.Support,
    _bh.Defib,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

local roleDescription = "This role is a neutral role with no Team Allegiances, you will assume the role of any unidentified corpse that you examine. Be warned that other users will be notified when that an Amnesiac has switched roles so discretion is advised. You can attack other players to steal their role also by identifying them when you have killed them."

local amnesiac = TTTBots.RoleData.New("amnesiac", TEAM_NONE)
amnesiac:SetDefusesC4(false)
amnesiac:SetStartsFights(false)
amnesiac:SetCanCoordinate(false)
amnesiac:SetUsesSuspicion(false)
amnesiac:SetTeam(TEAM_NONE)
amnesiac:SetBTree(bTree)
amnesiac:SetBuyableWeapons({})
amnesiac:SetKnowsLifeStates(true)
amnesiac:SetAlliedTeams(allyTeams)
amnesiac:SetLovesTeammates(false)
amnesiac:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(amnesiac)

return true
