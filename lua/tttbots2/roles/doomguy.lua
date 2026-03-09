--- DOOM SLAYER — neutral public killer.
--- Wins by eliminating all non-allied players (KOS by all, KOS all).
--- Uses a custom behavior tree tuned for aggressive close-range SSG gameplay,
--- active hunting, meathook usage, and life-steal exploitation.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DOOMGUY then return false end

local _bh    = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

--- Custom Doomguy behavior tree.
--- Order: combat first, then hunt/pressure, then meathook, then chatter,
--- then restoration, then interaction.  No patrol/hiding — Doomguy always hunts.
local doomguyTree = {
    _prior.FightBack,                       -- 1. React to immediate combat (AttackTarget, SeekCover if overwhelmed)
    _bh.DoomguyPressureAdvance,             -- 2. Maintain forward pressure / suppress cover-retreat during combat
    _bh.UseMeathook,                        -- 3. Attempt meathook grapple when in SSG range
    _bh.DoomguyHunt,                        -- 4. Actively seek and close on the best non-ally target
    _prior.Requests,                        -- 5. Respond to wait/ceasefire requests (very rarely honored)
    _prior.Chatter,                         -- 6. Callouts and communication
    _bh.Roledefib,                          -- 7. Revive Doomguy teammates if the role supports it
    _prior.Restore,                         -- 8. Grab weapons/loot/health stations when not in combat
    _bh.Interact,                           -- 9. Interact with props / environment
    _bh.Wander,                             -- 10. Last resort: wander (keeps the bot moving)
}

local doomguy = TTTBots.RoleBuilder.NeutralKiller("doomguy", TEAM_DOOMSLAYER)
doomguy:SetPreferredWeapon("weapon_dredux_de_supershotgun")
-- Disable auto-switch so the bot always holds the SSG instead of downgrading to a pistol.
doomguy:SetAutoSwitch(false)
-- Override the generic NeutralKiller tree with the Doomguy-specific one.
doomguy:SetBTree(doomguyTree)
TTTBots.Roles.RegisterRole(doomguy)

return true

