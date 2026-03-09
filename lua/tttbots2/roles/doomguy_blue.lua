--- DOOM SLAYER (BLUE TEAM) — mirrors the main Doomguy role.
--- Uses the same SSG preference and custom hunt tree as the main Doomguy variant.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DOOMGUY_BLUE then return false end

local _bh    = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local doomguyBlueTree = {
    _prior.FightBack,
    _bh.DoomguyPressureAdvance,
    _bh.UseMeathook,
    _bh.DoomguyHunt,
    _prior.Requests,
    _prior.Chatter,
    _bh.Roledefib,
    _prior.Restore,
    _bh.Interact,
    _bh.Wander,
}

local doomguy_blue = TTTBots.RoleBuilder.NeutralKiller("doomguy_blue", TEAM_DOOMSLAYER_BLUE or TEAM_DOOMSLAYER)
doomguy_blue:SetPreferredWeapon("weapon_dredux_de_supershotgun")
doomguy_blue:SetAutoSwitch(false)
doomguy_blue:SetBTree(doomguyBlueTree)
TTTBots.Roles.RegisterRole(doomguy_blue)

return true

