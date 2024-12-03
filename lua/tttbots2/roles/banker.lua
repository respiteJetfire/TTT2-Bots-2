if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_BANKER then return false end

local banker = TTTBots.RoleData.New("banker")
banker:SetDefusesC4(true)
banker:SetCanHaveRadar(true)
banker:SetTeam(TEAM_INNOCENT)
banker:SetBTree(TTTBots.Behaviors.DefaultTrees.detective)
banker:SetEnemyTeams({[TEAM_DOOMSLAYER] = true})
banker:SetUsesSuspicion(true)
banker:SetAppearsPolice(true)
TTTBots.Roles.RegisterRole(banker)

return true
