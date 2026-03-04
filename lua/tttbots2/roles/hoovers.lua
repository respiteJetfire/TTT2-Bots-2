if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_HOOVERS then return false end

local roleDescription = "The Hoovers role's objective is to eliminate the other gangs and win the game. You are a member of the Hoovers and can use their weapons. Be careful not to attack your own teammates!"

local hoovers = TTTBots.RoleBuilder.GangRole("hoovers", TEAM_HOOVERS, {
    [TEAM_CRIPS]    = true,
    [TEAM_BALLAS]   = true,
    [TEAM_BLOODS]   = true,
    [TEAM_FAMILIES] = true,
})
hoovers:SetBuyableWeapons({ "arccw_mw2_ak47", "arccw_mw2_m4" })
hoovers:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(hoovers)

return true
