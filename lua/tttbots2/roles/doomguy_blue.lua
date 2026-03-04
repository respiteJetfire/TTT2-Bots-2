--- DOOM SLAYER ROLE WHICH IS EVIL AND WINS BY KILLING ALL OTHER PLAYERS (KOS).

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DOOMGUY_BLUE then return false end

local doomguy_blue = TTTBots.RoleBuilder.NeutralKiller("doomguy_blue", TEAM_DOOMSLAYER_BLUE)
doomguy_blue:SetBuyableWeapons({ "arccw_mw2_ranger" })
TTTBots.Roles.RegisterRole(doomguy_blue)

return true

