--- Decpherer role for TTT2-Bots

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DECIPHERER then return false end

local decipherer = TTTBots.RoleData.New("decipherer")

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "The Decipherer is a special Detective role equipped with a personal role checker which can be used to identify the role of any player you scan. However this has a delay, so be warned about players that might want you dead before you can reveal their role!"

decipherer:SetDefusesC4(true)
decipherer:SetCanHaveRadar(true)
decipherer:SetTeam(TEAM_INNOCENT)
decipherer:SetBTree(TTTBots.Behaviors.DefaultTrees.detective)
decipherer:SetUsesSuspicion(true)
decipherer:SetAppearsPolice(true)
decipherer:SetRoleDescription(true)
TTTBots.Roles.RegisterRole(decipherer)

return true
