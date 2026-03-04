local traitor = TTTBots.RoleBuilder.TraitorLike("traitor", TEAM_TRAITOR)
traitor:SetBTree(TTTBots.Behaviors.DefaultTrees.traitor)
traitor:SetCanSnipe(true)
TTTBots.Roles.RegisterRole(traitor)

return true
