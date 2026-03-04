--- DOOM SLAYER ROLE WHICH IS EVIL AND WINS BY KILLING ALL OTHER PLAYERS (KOS).

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DOOMGUY_RED then return false end

local doomguy_red = TTTBots.RoleBuilder.NeutralKiller("doomguy_red", TEAM_DOOMSLAYER_RED)
doomguy_red:SetBuyableWeapons({ "arccw_mw2_ranger" })
TTTBots.Roles.RegisterRole(doomguy_red)

return true

