if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_OCCULTIST then return false end

local occultist = TTTBots.RoleBuilder.InnocentLike("occultist")
occultist:SetAlliedRoles({})
occultist:SetAlliedTeams({})
TTTBots.Roles.RegisterRole(occultist)

return true
