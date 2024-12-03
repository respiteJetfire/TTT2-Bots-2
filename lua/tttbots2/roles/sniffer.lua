if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SNIFFER then return false end

local sniffer = TTTBots.RoleData.New("sniffer")
sniffer:SetDefusesC4(true)
sniffer:SetCanHaveRadar(true)
sniffer:SetTeam(TEAM_INNOCENT)
sniffer:SetBTree(TTTBots.Behaviors.DefaultTrees.detective)
sniffer:SetEnemyTeams({[TEAM_DOOMSLAYER] = true})
sniffer:SetUsesSuspicion(true)
sniffer:SetAppearsPolice(true)
TTTBots.Roles.RegisterRole(sniffer)

return true
