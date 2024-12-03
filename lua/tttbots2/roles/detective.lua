local detective = TTTBots.RoleData.New("detective")
detective:SetDefusesC4(true)
detective:SetCanHaveRadar(true)
detective:SetTeam(TEAM_INNOCENT)
detective:SetBTree(TTTBots.Behaviors.DefaultTrees.detective)
detective:SetAlliedRoles('deputy','sheriff','sniffer','priest','survivalist','innocent')
detective:SetUsesSuspicion(true)
detective:SetAppearsPolice(true)
detective:SetEnemyTeams({
    [TEAM_DOOMSLAYER] = true,
})
TTTBots.Roles.RegisterRole(detective)

return true
