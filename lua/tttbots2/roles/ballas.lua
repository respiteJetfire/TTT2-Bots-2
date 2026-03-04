--- Ballas Behavior for TTT2, a role which is evil and wins by killing all non-allied players

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_BALLAS then return false end

local roleDescription = "The Ballas role's objective is to eliminate the other gangs and win the game. You are a member of the Ballas and can use their weapons. Be careful not to attack your own teammates!"

local ballas = TTTBots.RoleBuilder.GangRole("ballas", TEAM_BALLAS, {
    [TEAM_CRIPS]    = true,
    [TEAM_BLOODS]   = true,
    [TEAM_FAMILIES] = true,
    [TEAM_HOOVERS]  = true,
})
ballas:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(ballas)

return true
