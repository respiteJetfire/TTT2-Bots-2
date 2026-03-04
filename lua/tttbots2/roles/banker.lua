if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_BANKER then return false end

local roleDescription = "The Banker is a special detective role which gains credits every time someone else spends one. You can use these credits to buy items in the detective shops."

local banker = TTTBots.RoleBuilder.DetectiveLike("banker")
banker:SetEnemyTeams({ [TEAM_DOOMSLAYER] = true })
banker:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(banker)

return true
