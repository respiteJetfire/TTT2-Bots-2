if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SHERIFF then return false end

local sheriff = TTTBots.RoleBuilder.DetectiveLike("sheriff")
TTTBots.Roles.RegisterRole(sheriff)

return true
