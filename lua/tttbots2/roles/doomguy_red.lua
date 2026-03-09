--- DOOM SLAYER (RED TEAM) — mirrors the main Doomguy role.
--- Uses the same SSG preference and custom hunt tree as the main Doomguy variant.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DOOMGUY_RED then return false end

local _bh    = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local doomguyRedTree = {
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

local doomguy_red = TTTBots.RoleBuilder.NeutralKiller("doomguy_red", TEAM_DOOMSLAYER_RED or TEAM_DOOMSLAYER)
doomguy_red:SetPreferredWeapon("weapon_dredux_de_supershotgun")
doomguy_red:SetAutoSwitch(false)
doomguy_red:SetBTree(doomguyRedTree)
TTTBots.Roles.RegisterRole(doomguy_red)

return true

