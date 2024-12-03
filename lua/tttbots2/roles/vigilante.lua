if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_VIGILANTE then return false end

local vigilante = TTTBots.RoleData.New("vigilante")
vigilante:SetDefusesC4(true)
vigilante:SetCanHaveRadar(true)
vigilante:SetTeam(TEAM_INNOCENT)
vigilante:SetBTree(TTTBots.Behaviors.DefaultTrees.detective)
vigilante:SetEnemyTeams({[TEAM_DOOMSLAYER] = true})
vigilante:SetUsesSuspicion(true)
vigilante:SetAppearsPolice(true)
TTTBots.Roles.RegisterRole(vigilante)

return true
