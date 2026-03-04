
local roleDescription = "You are a Detective! One of the Classic TTT roles, you are an innocent that has the ability to buy items from the Detective shop. Your task is to take control of the round by any means necessary, to protect the innocents and hunt the Traitors, or other hostile roles to your Team. Other players know you are a detective, which gives you credibility to all innocent players and a target on your back to all hostile roles. They will try to take you out first, so make sure you are prepared for anything! You have access to the DNA Scanner, an item which allows you to trace the steps of the killer of a corpse you scan, and the ability to gather more information from corpses."
local detective = TTTBots.RoleData.New("detective")
detective:SetDefusesC4(true)
detective:SetCanHaveRadar(true)
detective:SetTeam(TEAM_INNOCENT)
detective:SetBTree(TTTBots.Behaviors.DefaultTrees.detective)
detective:SetAlliedRoles('deputy','sheriff','sniffer','priest','survivalist','innocent')
detective:SetUsesSuspicion(true)
detective:SetAppearsPolice(true)
detective:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(detective)

return true
