--- Cultist role integration for TTT Bots 2
--- The Cultist is a sub-role created when the Cult Leader converts a player.
--- Cultists are on TEAM_CULTIST, have isOmniscientRole (know MIA/life states),
--- and receive armor on conversion. They are NOT selectable at round start
--- (notSelectable = true) — only created through conversion.
---
--- Bot behavior:
---   • Plays as an aggressive team killer (like a traitor but for TEAM_CULTIST)
---   • Coordinates with other Cultists and the Cult Leader
---   • Has traitor-like shop access
---   • Receives armor on conversion (handled by role addon)

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_CULTIST then return false end

TEAM_CULTIST = TEAM_CULTIST or "cultist"
TEAM_JESTER = TEAM_JESTER or "jesters"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "You are a Cultist, converted by the Cult Leader! You are now part of the Cultist faction. "
    .. "Work with the Cult Leader and other Cultists to eliminate all other players. "
    .. "You have armor and can see who is alive or dead. Fight for your cult!"

-- Aggressive combat tree: fight alongside cult
local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Requests,
    _bh.Roledefib,
    _bh.Stalk,                 -- Hunt enemies
    _prior.Restore,
    _prior.Deception,          -- Blend in
    _bh.Interact,
    _prior.Investigate,
    _prior.Patrol,
}

local cultist = TTTBots.RoleData.New("cultist", TEAM_CULTIST)
cultist:SetDefusesC4(false)
cultist:SetPlantsC4(false)
cultist:SetTeam(TEAM_CULTIST)
cultist:SetBTree(bTree)
cultist:SetCanCoordinate(true)
cultist:SetCanHaveRadar(false)
cultist:SetStartsFights(true)
cultist:SetUsesSuspicion(false)
cultist:SetKnowsLifeStates(true)           -- isOmniscientRole
cultist:SetLovesTeammates(true)
cultist:SetAlliedTeams({ [TEAM_CULTIST] = true, [TEAM_JESTER] = true })
cultist:SetAlliedRoles({ cultleader = true, cultist = true })
cultist:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(cultist)

return true
