--- Speedrunner role integration for TTT Bots 2
--- The Speedrunner is a solo omniscient role on TEAM_SPEEDRUNNER. They must kill
--- all non-TEAM_NONE, non-preventWin players within a time limit to win.
---
--- Key mechanics (mostly server-driven):
---   • Custom TEAM_SPEEDRUNNER
---   • isOmniscientRole + isPublicRole — everyone knows the Speedrunner
---   • On round start: a countdown timer begins (base + N*players seconds)
---   • Each kill adds time; each Speedrunner death removes time
---   • Speedrunner respawns automatically (with smoke) until timer runs out
---   • Boosted speed, jump, and weapon fire rate (server-driven stat modifiers)
---   • Has radar, can use traitor buttons, has 2 credits but no shop
---
--- Bot behavior:
---   • Aggressive hunter — KOSAll (except TEAM_NONE and preventWin roles)
---   • Stalk priority with Chatter/FightBack at top
---   • isOmniscientRole: full life-state knowledge
---   • Respawn is automatic — no need to worry about dying
---   • Uses radar intel aggressively

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SPEEDRUNNER then return false end

TEAM_SPEEDRUNNER = TEAM_SPEEDRUNNER or "speedrunners"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "You are the Speedrunner, a solo omniscient public role. You must kill every "
    .. "non-jester, non-preventWin player within the time limit to win. Each kill adds time; "
    .. "each death costs time. You respawn automatically. You have boosted speed, jump, and fire rate. "
    .. "Everyone knows who you are. Hunt aggressively and efficiently."

-- Aggressive killer tree — omniscient, kills everyone
local bTree = {
    _prior.Chatter,
    _prior.FightBack,       -- Always react to being attacked
    _bh.Stalk,              -- Relentlessly hunt targets
    _prior.Requests,
    _prior.Restore,
    _bh.Interact,
    _bh.Decrowd,
    _prior.Patrol,
}

local speedrunner = TTTBots.RoleData.New("speedrunner", TEAM_SPEEDRUNNER)
speedrunner:SetDefusesC4(false)
speedrunner:SetPlantsC4(false)
speedrunner:SetTeam(TEAM_SPEEDRUNNER)
speedrunner:SetBTree(bTree)
speedrunner:SetCanCoordinate(false)
speedrunner:SetCanHaveRadar(true)           -- Has radar from loadout
speedrunner:SetStartsFights(true)
speedrunner:SetUsesSuspicion(false)         -- isPublicRole — no deception
speedrunner:SetKOSAll(true)                 -- Kill everyone (non-TEAM_NONE)
speedrunner:SetKOSedByAll(true)             -- Everyone should fight back
speedrunner:SetKnowsLifeStates(true)        -- isOmniscientRole
speedrunner:SetNeutralOverride(false)       -- Should absolutely be targeted
speedrunner:SetLovesTeammates(false)
speedrunner:SetAlliedTeams({ [TEAM_SPEEDRUNNER] = true })
speedrunner:SetAlliedRoles({ speedrunner = true })
speedrunner:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(speedrunner)

return true
