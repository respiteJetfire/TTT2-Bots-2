if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DEFECTOR then return false end

TEAM_JESTER = TEAM_JESTER or 'jesters'

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local allyTeams = {
    [TEAM_TRAITOR] = true,
    [TEAM_JESTER] = true,
}

local bTree = {
    _bh.Jihad,
    -- _prior.Restore,
    -- _bh.Stalk,
    -- _prior.Minge,
    _prior.Investigate,
    _prior.Patrol
}

local defector = TTTBots.RoleData.New("defector", TEAM_TRAITOR)
defector:SetDefusesC4(false)
defector:SetPlantsC4(false)
defector:SetCanHaveRadar(true)
defector:SetCanCoordinate(false)
defector:SetStartsFights(false)
defector:SetTeam(TEAM_TRAITOR)
defector:SetBuyableWeapons("weapon_ttt_jihad_bomb")
defector:SetUsesSuspicion(false)
defector:SetIsFollower(true)
defector:SetBTree(bTree) -- TODO: Btree for defector
defector:SetAlliedTeams(allyTeams)
defector:SetLovesTeammates(true)
TTTBots.Roles.RegisterRole(defector)

return true
