if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_HITMAN then return false end

local roleDescription = "The Hitman is a Traitor role, with designated targets to eliminate. You do not start with any credits, but get bonus credits every time you eliminate your Target."

local hitman = TTTBots.RoleBuilder.TraitorLike("hitman", TEAM_TRAITOR)
hitman:SetBTree(TTTBots.Behaviors.DefaultTrees.traitor)
hitman:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(hitman)

return true
