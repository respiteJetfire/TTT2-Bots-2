--- DOOM SLAYER ROLE WHICH IS EVIL AND WINS BY KILLING ALL OTHER PLAYERS (KOS).

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DOOMGUY then return false end

local doomguy = TTTBots.RoleBuilder.NeutralKiller("doomguy", TEAM_DOOMSLAYER)
doomguy:SetPreferredWeapon("weapon_dredux_de_supershotgun")
doomguy:SetAutoSwitch(false)
TTTBots.Roles.RegisterRole(doomguy)

return true

