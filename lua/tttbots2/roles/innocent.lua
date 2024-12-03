local innocent = TTTBots.RoleData.New("innocent")
innocent:SetDefusesC4(true)
innocent:SetTeam(TEAM_INNOCENT)
innocent:SetBTree(TTTBots.Behaviors.DefaultTrees.innocent)
innocent:SetCanHide(true)
innocent:SetKOSUnknown(false)
innocent:SetCanSnipe(true)
innocent:SetUsesSuspicion(true)
innocent:SetAlliedRoles({})
innocent:SetAlliedTeams({})
innocent:SetEnemyTeams({
    [TEAM_DOOMSLAYER] = true,
})
TTTBots.Roles.RegisterRole(innocent)

return true
