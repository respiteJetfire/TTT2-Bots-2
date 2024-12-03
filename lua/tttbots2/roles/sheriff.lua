if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SHERIFF then return false end

local sheriff = TTTBots.RoleData.New("sheriff")
sheriff:SetDefusesC4(true)
sheriff:SetCanHaveRadar(true)
sheriff:SetTeam(TEAM_INNOCENT)
sheriff:SetBTree(TTTBots.Behaviors.DefaultTrees.detective)
sheriff:SetUsesSuspicion(true)
sheriff:SetAppearsPolice(true)
sheriff:SetEnemyTeams({[TEAM_DOOMSLAYER] = true})
TTTBots.Roles.RegisterRole(sheriff)

return true
