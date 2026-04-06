--- Janitor role integration for TTT Bots 2
--- The Janitor is a Traitor with a broom weapon:
---   • PRIMARY FIRE (Sweep): Removes a nearby corpse entirely from the map.
---     Has a 60-second cooldown between sweeps.
---   • SECONDARY FIRE (DNA Wipe): Wipes the DNA sample from a corpse
---     (removes forensic link between killer and victim). No cooldown.
---
--- Bot strategy:
---   • Kill enemies like any Traitor.
---   • After killing, use JanitorSweep behavior to remove the body.
---   • If on cooldown, at least secondary-fire (DNA wipe) any accessible corpses.
---   • Priority: body removal > DNA removal > normal traitor behavior.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_JANITOR then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription =
    "You are the Janitor, a Traitor with a broom that lets you clean up evidence. "
    .. "After making a kill, approach the body and use primary fire to sweep it away permanently. "
    .. "This prevents teammates from identifying your kills or checking the body. "
    .. "Sweeping has a 60-second cooldown — use secondary fire (DNA removal) during the cooldown. "
    .. "Play as a normal Traitor otherwise; your strength is in denying evidence, not direct power."

local bTree = {
    _prior.Requests,
    _prior.Chatter,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Grenades,
    _bh.JanitorSweep,       -- After kills: approach corpse and sweep/wipe DNA
    _prior.Support,
    _prior.Deception,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol,
}

local janitor = TTTBots.RoleData.New("janitor")
janitor:SetDefusesC4(false)
janitor:SetPlantsC4(true)
janitor:SetTeam(TEAM_TRAITOR)
janitor:SetBTree(bTree)
janitor:SetCanCoordinate(true)
janitor:SetCanHaveRadar(true)
janitor:SetStartsFights(true)
janitor:SetUsesSuspicion(false)
janitor:SetCanSnipe(true)
janitor:SetCanHide(true)
janitor:SetKnowsLifeStates(true)
janitor:SetLovesTeammates(true)
janitor:SetAlliedTeams({ [TEAM_TRAITOR] = true })
janitor:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(janitor)

print("[TTT Bots 2] Janitor role integration loaded.")
return true
