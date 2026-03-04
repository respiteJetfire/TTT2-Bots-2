
local roleDescription = "The Innocent is a classic role in TTT. Your objective is to survive and assist your fellow Innocents, but as you do not know who they are (except Detective roles) you must exercise caution, and defend yourself against Hostile roles."
local innocent = TTTBots.RoleData.New("innocent")
innocent:SetDefusesC4(true)
innocent:SetTeam(TEAM_INNOCENT)
innocent:SetBTree(TTTBots.Behaviors.DefaultTrees.innocent)
innocent:SetCanHide(true)
innocent:SetKOSUnknown(false)
innocent:SetCanSnipe(true)
innocent:SetUsesSuspicion(true)
innocent:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(innocent)

return true
