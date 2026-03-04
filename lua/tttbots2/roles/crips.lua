--- Crips Role for TTT2, a role which is evil and wins by killing all non-allied players

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_CRIPS then return false end

local roleDescription = "The Crips role's objective is to eliminate the other gangs and win the game. You are a member of the Crips and can use their weapons. Be careful not to attack your own teammates!"

local crips = TTTBots.RoleBuilder.GangRole("crips", TEAM_CRIPS, {
    [TEAM_BLOODS]   = true,
    [TEAM_BALLAS]   = true,
    [TEAM_FAMILIES] = true,
    [TEAM_HOOVERS]  = true,
})
crips:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(crips)

return true
