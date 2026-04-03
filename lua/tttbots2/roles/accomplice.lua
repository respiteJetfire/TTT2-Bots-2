--- Accomplice role integration for TTT Bots 2
--- The Accomplice is a Traitor-team role that does NOT know who their
--- teammates are (unknownTeam = true). They have a corpse-radar and must
--- help their hidden allies by deduction rather than direct communication.
---
--- Bot behavior:
---   • Plays like a standard traitor (fights, stalks, coordinates)
---   • Does NOT auto-coordinate with traitors (unknownTeam)
---   • Uses suspicion system to figure out who to avoid killing
---   • Has corpse radar (identifies dead bodies to avoid suspicion)

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_ACCOMPLICE then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "You are the Accomplice, a Traitor-aligned role that does NOT know who their teammates are. "
    .. "You have a radar that shows dead body locations, helping you track the round's progress. "
    .. "Use traitor buttons and play aggressively, but be careful — you might accidentally attack your own team. "
    .. "You win when the Traitor team wins."

-- Custom tree: traitor-like but with suspicion enabled (since unknownTeam)
-- and investigation behaviors to use the corpse radar effectively.
local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Deception,          -- Alibi building (doesn't know teammates, needs cover)
    _bh.Stalk,                 -- Stalk isolated targets
    _prior.Restore,
    _prior.Investigate,        -- Investigate corpses (leverages corpse radar)
    _bh.Interact,
    _prior.Patrol,
}

local accomplice = TTTBots.RoleData.New("accomplice", TEAM_TRAITOR)
accomplice:SetDefusesC4(false)
accomplice:SetPlantsC4(true)
accomplice:SetTeam(TEAM_TRAITOR)
accomplice:SetBTree(bTree)
accomplice:SetCanCoordinate(false)        -- unknownTeam: can't coordinate with traitors
accomplice:SetCanHaveRadar(true)          -- has corpse radar
accomplice:SetStartsFights(true)
accomplice:SetUsesSuspicion(true)         -- uses suspicion since they don't know allies
accomplice:SetLovesTeammates(false)       -- doesn't know who teammates are
accomplice:SetAlliedTeams({ [TEAM_TRAITOR] = true, [TEAM_JESTER] = true })
accomplice:SetAlliedRoles({ accomplice = true })  -- only knows self
accomplice:SetKnowsLifeStates(false)
accomplice:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(accomplice)

return true
