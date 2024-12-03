if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SPY then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local spy = TTTBots.RoleData.New("spy")
spy:SetDefusesC4(false)
spy:SetTeam(TEAM_INNOCENT)
spy:SetBTree(TTTBots.Behaviors.DefaultTrees.innocent)
spy:SetCanHide(true)
spy:SetCanSnipe(true)
spy:SetUsesSuspicion(true)
spy:SetEnemyTeams({[TEAM_DOOMSLAYER] = true})
spy:SetIsFollower(true)
TTTBots.Roles.RegisterRole(spy)

return true
