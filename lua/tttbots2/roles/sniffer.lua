if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SNIFFER then return false end

local sniffer = TTTBots.RoleBuilder.DetectiveLike("sniffer")
TTTBots.Roles.RegisterRole(sniffer)

return true
