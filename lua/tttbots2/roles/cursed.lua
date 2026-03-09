if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_CURSED then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

--- Revised Cursed BTree:
--- - CursedEvade high priority (can't do damage, must flee attackers)
--- - SwapDeagle + SwapRole promoted to top-level (the Cursed's entire purpose)
--- - CursedImmolate for corpse destruction / repositioning
--- - No combat behaviors (Cursed deals zero damage)
--- - No _prior.Convert (Cursed shouldn't use Defector/Medic/Deputy deagles)
local bTree = {
    _prior.Chatter,         -- Social behaviors
    _bh.CursedEvade,        -- Flee from attackers (speed advantage)
    _bh.SwapDeagle,         -- RoleSwap Deagle — ranged swap (high priority)
    _bh.SwapRole,           -- Proximity tag swap (primary objective)
    _bh.CursedImmolate,     -- Self-immolation (evidence destruction / reposition)
    _prior.Requests,        -- Respond to player commands
    _bh.Interact,           -- General interaction
    _prior.Patrol           -- Follow, GroupUp, Wander (find targets)
}

local roleDescription = "The Cursed is a TEAM_NONE role that cannot win alone or deal damage. "
    .. "It must swap roles with another player by walking up to them and pressing USE (tag), "
    .. "or by shooting them with the RoleSwap Deagle at range. "
    .. "The Cursed has a speed boost, reduced stamina drain, and auto-respawns after death. "
    .. "It can self-immolate to destroy its corpse and reposition on respawn."

local cursed = TTTBots.RoleData.New("cursed", TEAM_NONE)
cursed:SetDefusesC4(false)
cursed:SetCanCoordinate(false)       -- TEAM_NONE, no team chat
cursed:SetCanHaveRadar(true)         -- Useful for finding targets
cursed:SetUsesSuspicion(false)       -- No team to suspect for
cursed:SetTeam(TEAM_NONE)
cursed:SetKOSedByAll(false)          -- Not universally KOS'd
cursed:SetStartsFights(false)        -- Cannot deal damage
cursed:SetBTree(bTree)
cursed:SetLovesTeammates(false)      -- TEAM_NONE has no teammates to love
cursed:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(cursed)

return true