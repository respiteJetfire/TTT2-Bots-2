--- Zombie behaviour for TTT2, a sub-role raised by the Necromancer.
--- Zombies are limited-ammo undead allies of the Necromancer that fight against all other players.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_ZOMBIE then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local allyTeams = {
    [TEAM_NECROMANCER] = true,
    [TEAM_JESTER] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _bh.FollowMaster,
    _bh.Stalk,
    _prior.Patrol,
}

local zombie = TTTBots.RoleData.New("zombie", TEAM_NECROMANCER)
zombie:SetDefusesC4(false)
zombie:SetPlantsC4(false)
zombie:SetCanCoordinate(false)
zombie:SetCanHaveRadar(false)
zombie:SetStartsFights(true)
zombie:SetUsesSuspicion(false)
zombie:SetTeam(TEAM_NECROMANCER)
zombie:SetBTree(bTree)
zombie:SetAlliedTeams(allyTeams)
zombie:SetLovesTeammates(true)
zombie:SetKnowsLifeStates(true)
zombie:SetKOSAll(true)
zombie:SetKOSedByAll(true)
zombie:SetAutoSwitch(false)
zombie:SetPreferredWeapon("weapon_ttth_zombpistol")
TTTBots.Roles.RegisterRole(zombie)

return true
