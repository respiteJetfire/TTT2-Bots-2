if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_FAMILIES then return false end

local roleDescription = "The Families role's objective is to eliminate the other gangs and win the game. You are a member of the Families and can use their weapons. Be careful not to attack your own teammates!"

local families = TTTBots.RoleBuilder.GangRole("families", TEAM_FAMILIES, {
    [TEAM_CRIPS]  = true,
    [TEAM_BALLAS] = true,
    [TEAM_BLOODS] = true,
    [TEAM_HOOVERS] = true,
})
families:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(families)

return true
