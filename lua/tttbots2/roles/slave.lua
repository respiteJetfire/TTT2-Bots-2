if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SLAVE then return false end

local slave = TTTBots.RoleBuilder.TraitorLike("slave", TEAM_TRAITOR)
slave:SetDefusesC4(false)
slave:SetPlantsC4(true)
slave:SetBTree(TTTBots.Behaviors.DefaultTrees.traitor)
slave:SetCanSnipe(true)
TTTBots.Roles.RegisterRole(slave)

return true
