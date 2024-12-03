--- Deputy role for TTT2, a Detective role which has a Sheriff Master which they must protect at all costs!

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DECIPHERER then return false end

local decipherer = TTTBots.RoleData.New("decipherer")

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

decipherer:SetDefusesC4(true)
decipherer:SetCanHaveRadar(true)
decipherer:SetTeam(TEAM_INNOCENT)
decipherer:SetBTree(TTTBots.Behaviors.DefaultTrees.detective)
decipherer:SetUsesSuspicion(true)
decipherer:SetAppearsPolice(true)
TTTBots.Roles.RegisterRole(decipherer)

return true
