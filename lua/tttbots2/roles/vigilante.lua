if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_VIGILANTE then return false end

local vigilante = TTTBots.RoleBuilder.DetectiveLike("vigilante")
TTTBots.Roles.RegisterRole(vigilante)

return true
