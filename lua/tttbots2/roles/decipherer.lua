--- Decipherer role integration for TTT Bots 2
--- The Decipherer is a Detective sub-role who starts with a personal
--- role checker (weapon_ttt_traitorchecker). Unlike the Detective who must
--- place theirs on the ground, the Decipherer scans a player directly.
---
--- Bot strategy:
---   • Plays as a DetectiveLike bot with UseRoleChecker elevated to near-top
---     priority so the bot actively uses/places the scanner early.
---   • UseRoleChecker behavior handles navigation to checkers and activation.
---   • Scan results feed into morality/suspicion/evidence for downstream
---     decision making via the existing UseRoleChecker result hooks.
---   • Prioritises scanning unknown-team players before engaging.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DECIPHERER then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- Custom tree: UseRoleChecker sits between Requests and Accuse so the bot
-- deploys/uses the scanner before committing to accusations.
local bTree = {
    _bh.EvadeGravityMine,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Chatter,
    _prior.Grenades,
    _prior.Requests,        -- includes UseRoleChecker (walk to placed checker)
    _bh.UseRoleChecker,     -- elevated: deploy/use the personal role checker ASAP
    _prior.Accuse,
    _bh.InvestigateCorpse,
    _prior.DNAScanner,
    _prior.Convert,
    _prior.Restore,
    _bh.FollowInnocentPlan,
    _prior.Support,
    _prior.TacticalEquipment,
    _bh.Defuse,
    _bh.ActiveInvestigate,
    _bh.Interact,
    _prior.Minge,
    _prior.Investigate,
    _bh.Decrowd,
    _prior.Patrol
}

local roleDescription =
    "The Decipherer is a Detective sub-role with a personal role checker. "
    .. "Bots will actively prioritise deploying and using the role checker on "
    .. "suspects, feeding scan results into the suspicion and evidence systems "
    .. "before committing to accusations or attacks."

local decipherer = TTTBots.RoleData.New("decipherer", TEAM_INNOCENT)
decipherer:SetDefusesC4(true)
decipherer:SetTeam(TEAM_INNOCENT)
decipherer:SetBTree(bTree)
decipherer:SetCanHaveRadar(true)
decipherer:SetAppearsPolice(true)
decipherer:SetUsesSuspicion(true)
decipherer:SetCanCoordinateInnocent(true)
decipherer:SetKOSUnknown(false)
decipherer:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(decipherer)

print("[TTT Bots 2] Decipherer role integration loaded.")
return true
