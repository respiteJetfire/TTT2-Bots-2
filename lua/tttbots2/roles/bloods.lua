--- Bloods behavior for TTT2, a role which is evil and wins by killing all other players.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_BLOODS then return false end

local roleDescription = "The Bloods role's objective is to eliminate the other gangs and win the game. You are a member of the Bloods and can use their weapons. Be careful not to attack your own teammates!"

local bloods = TTTBots.RoleBuilder.GangRole("bloods", TEAM_BLOODS, {
    [TEAM_CRIPS]    = true,
    [TEAM_BALLAS]   = true,
    [TEAM_FAMILIES] = true,
    [TEAM_HOOVERS]  = true,
})
bloods:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(bloods)

return true
