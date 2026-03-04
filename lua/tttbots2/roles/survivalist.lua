if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SURVIVALIST then return false end

local survivalist = TTTBots.RoleBuilder.InnocentLike("survivalist")
survivalist:SetAlliedRoles({})
survivalist:SetAlliedTeams({})
TTTBots.Roles.RegisterRole(survivalist)

return true
