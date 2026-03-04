--- Decpherer role for TTT2-Bots

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DECIPHERER then return false end

local roleDescription = "The Decipherer is a special Detective role equipped with a personal role checker which can be used to identify the role of any player you scan. However this has a delay, so be warned about players that might want you dead before you can reveal their role!"

local decipherer = TTTBots.RoleBuilder.DetectiveLike("decipherer")
decipherer:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(decipherer)

return true
