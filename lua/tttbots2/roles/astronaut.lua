--- Astronaut role integration for TTT Bots 2
--- The Astronaut is a public, policing Detective subrole on the Innocent team.
---
--- Key mechanics:
---   • isPublicRole + isPolicingRole: everyone sees the Astronaut's role badge.
---   • unknownTeam = true: uses the suspicion system (can't see team auras).
---   • SHOP_FALLBACK_DETECTIVE: access to the detective item shop.
---   • 1 credit at round start; earns +1 charge per non-innocent kill.
---   • Loadout weapon: weapon_ast_meeting (Meeting Maker megaphone).
---
--- Meeting Maker behavior:
---   • Hold PRIMARY FIRE on a dead body within 64 units for `charge_time` seconds
---     → calls a community-wide vote to execute one living player.
---   • The vote GUI, tallying, and kill are ENTIRELY server-driven.
---     The bot only needs to initiate the meeting; it cannot "vote" in the GUI.
---   • Each corpse may only host one meeting (UsedPlayers table server-side).
---   • After a kill-vote resolves, a ~20s cooldown applies before the next meeting.
---   • Default charges: 6 total, 3 per meeting → 2 meetings by default.
---     Gains +1 charge whenever a non-innocent dies while the Astronaut is alive.
---   • Several convars configure timing, anonymous votes, tie-kills, etc.
---
--- Bot strategy:
---   • AstronautMeeting: seek the nearest unused corpse, navigate within 64 units,
---     hold primary fire for the charge time to call the meeting.
---   • After calling a meeting, impose a self-side cooldown to avoid spam.
---   • Otherwise play as a standard Detective: investigate, DNA scan, defuse C4.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_ASTRONAUT then return false end

local _bh  = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription =
    "You are the Astronaut, a public innocent-team role with a Meeting Maker weapon. "
    .. "Hold primary fire on a dead body to call a community vote — all living players vote "
    .. "on who to execute, and the majority target is killed. "
    .. "You start with 6 charges (3 per meeting = 2 total meetings) and gain charges when "
    .. "non-innocents die. Everyone knows you are the Astronaut. "
    .. "Between meetings, investigate corpses and behave like a Detective."

-- Custom behavior tree: AstronautMeeting sits between Requests and Support,
-- so the bot prioritises calling a meeting once a usable corpse appears but
-- will still fight back, respond to requests, and investigate otherwise.
local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Grenades,
    _prior.Requests,
    _prior.Accuse,
    _bh.InvestigateCorpse,       -- ID bodies for intel (detective priority)
    _bh.AstronautMeeting,        -- Call a vote-meeting on an unused corpse
    _prior.DNAScanner,           -- DNA scanning for forensic leads
    _prior.Support,
    _prior.TacticalEquipment,    -- Spend detective-shop credits
    _bh.Defuse,
    _bh.ActiveInvestigate,
    _prior.Restore,
    _bh.FollowInnocentPlan,
    _bh.Interact,
    _prior.Minge,
    _prior.Investigate,
    _bh.Decrowd,
    _prior.Patrol,
}

local astronaut = TTTBots.RoleData.New("astronaut")
astronaut:SetDefusesC4(true)
astronaut:SetPlantsC4(false)
astronaut:SetTeam(TEAM_INNOCENT)
astronaut:SetBTree(bTree)
astronaut:SetCanCoordinate(false)         -- unknownTeam = true
astronaut:SetCanCoordinateInnocent(true)  -- still polices with innocents
astronaut:SetCanHaveRadar(true)           -- isPolicingRole
astronaut:SetAppearsPolice(true)          -- isPublicRole + isPolicingRole
astronaut:SetStartsFights(true)           -- will fight traitors
astronaut:SetUsesSuspicion(true)          -- unknownTeam
astronaut:SetCanSnipe(true)
astronaut:SetCanHide(false)
astronaut:SetKOSUnknown(false)
astronaut:SetLovesTeammates(false)        -- unknownTeam, no team aura
astronaut:SetAlliedTeams({ [TEAM_INNOCENT] = true })
astronaut:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(astronaut)

print("[TTT Bots 2] Astronaut role integration loaded — public detective with Meeting Maker.")

return true
