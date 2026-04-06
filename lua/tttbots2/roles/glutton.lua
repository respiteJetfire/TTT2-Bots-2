--- Glutton / Ravenous role integration for TTT Bots 2
--- Two-phase traitor role:
---
--- Phase 1 (Glutton): Traitor with a hunger mechanic.
---   • Hunger ticks down 1/sec from ~120-180 starting points.
---   • weapon_ttt_glut_bite: Primary heals + feeds (attacks deal damage + heal 20%).
---     Secondary: eat nearby corpse to restore 50 HP and hunger.
---   • When hungry: faster + more damage. When full: slower.
---   • At 0 hunger: either transforms into Ravenous or starts taking passive damage.
---
--- Phase 2 (Ravenous): Custom solo team TEAM_RAVENOUS.
---   • Stripped to bite weapon only; cannot pick up weapons.
---   • Omniscient radar shows ALL players.
---   • Takes 5 HP every 2 seconds — must keep biting to survive.
---
--- Bot strategy (Glutton):
---   • Prefer melee combat (bite weapon) to manage hunger via combat.
---   • After kills, find the corpse and eat it with secondary fire.
---   • When hunger is critically low (<20), immediately hunt and bite.
---
--- Bot strategy (Ravenous):
---   • Always hunting — use Stalk + FightBack.
---   • Always use bite weapon (no other weapons).
---   • Urgency when below 40 HP due to passive starvation drain.

if not TTTBots.Lib.IsTTT2() then return false end

local hasGlutton = ROLE_GLUTTON ~= nil
local hasRavenous = ROLE_RAVENOUS ~= nil
if not hasGlutton and not hasRavenous then return false end

TEAM_RAVENOUS = TEAM_RAVENOUS or "ravenous"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- ---------------------------------------------------------------------------
-- Glutton behavior tree
-- ---------------------------------------------------------------------------
local gluttonTree = {
    _prior.Requests,
    _prior.Chatter,
    _prior.FightBack,
    _prior.SelfDefense,
    _bh.GluttonBite,       -- Hunger management: bite enemies, eat corpses
    _prior.Grenades,
    _prior.Support,
    _prior.Deception,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol,
}

-- ---------------------------------------------------------------------------
-- Ravenous behavior tree — aggressive solo hunter
-- ---------------------------------------------------------------------------
local ravenousTree = {
    _prior.Chatter,
    _prior.FightBack,
    _bh.Stalk,              -- Omniscient radar: hunt all visible players
    _prior.Requests,
    _prior.Restore,
    _bh.Interact,
    _bh.Wander,
}

-- ---------------------------------------------------------------------------
-- Register Glutton
-- ---------------------------------------------------------------------------
if hasGlutton then
    local gluttonDesc =
        "You are the Glutton, a Traitor with a hunger bar that depletes every second. "
        .. "Your bite weapon (primary fire) damages enemies and feeds you — it also heals you slightly. "
        .. "Secondary fire on a corpse lets you eat it for a large HP + hunger restore. "
        .. "When hungry, you are faster and deal more damage. "
        .. "At zero hunger you transform into the Ravenous — a solo-team monster that must keep biting to survive. "
        .. "Prefer melee combat, eat corpses after kills, and stay fed to avoid the transformation."

    local glutton = TTTBots.RoleData.New("glutton")
    glutton:SetDefusesC4(false)
    glutton:SetPlantsC4(true)
    glutton:SetTeam(TEAM_TRAITOR)
    glutton:SetBTree(gluttonTree)
    glutton:SetCanCoordinate(true)
    glutton:SetCanHaveRadar(true)
    glutton:SetStartsFights(true)
    glutton:SetUsesSuspicion(false)
    glutton:SetCanSnipe(false)       -- Melee/close-range fighter
    glutton:SetCanHide(true)
    glutton:SetKnowsLifeStates(true)
    glutton:SetLovesTeammates(true)
    glutton:SetPreferredWeapon("weapon_ttt_glut_bite")
    glutton:SetAlliedTeams({ [TEAM_TRAITOR] = true })
    glutton:SetRoleDescription(gluttonDesc)
    TTTBots.Roles.RegisterRole(glutton)
end

-- ---------------------------------------------------------------------------
-- Register Ravenous
-- ---------------------------------------------------------------------------
if hasRavenous then
    local ravenousDesc =
        "You are the Ravenous, a transformed solo-team monster. "
        .. "You only have your bite weapon and cannot pick up anything else. "
        .. "You take passive HP drain every 2 seconds — keep biting enemies to stay alive via healing. "
        .. "Your radar shows ALL living players. Hunt everyone aggressively — you win alone."

    local ravenous = TTTBots.RoleData.New("ravenous", TEAM_RAVENOUS)
    ravenous:SetDefusesC4(false)
    ravenous:SetPlantsC4(false)
    ravenous:SetTeam(TEAM_RAVENOUS)
    ravenous:SetBTree(ravenousTree)
    ravenous:SetCanCoordinate(false)
    ravenous:SetCanHaveRadar(true)
    ravenous:SetStartsFights(true)
    ravenous:SetUsesSuspicion(false)
    ravenous:SetCanSnipe(false)
    ravenous:SetCanHide(false)
    ravenous:SetKOSAll(true)
    ravenous:SetKOSedByAll(true)
    ravenous:SetKnowsLifeStates(true)
    ravenous:SetLovesTeammates(true)
    ravenous:SetPreferredWeapon("weapon_ttt_glut_bite")
    ravenous:SetAlliedTeams({ [TEAM_RAVENOUS] = true })
    ravenous:SetRoleDescription(ravenousDesc)
    TTTBots.Roles.RegisterRole(ravenous)
end

-- ---------------------------------------------------------------------------
-- Runtime tree override: swap tree when Glutton transforms into Ravenous.
-- ---------------------------------------------------------------------------
local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor
function TTTBots.Behaviors.GetTreeFor(bot)
    if not IsValid(bot) then return nil end

    local roleString = bot:GetRoleStringRaw()
    if roleString == "glutton"  then return gluttonTree  end
    if roleString == "ravenous" then return ravenousTree end

    return _origGetTreeFor(bot)
end

-- ---------------------------------------------------------------------------
-- Suspicion hook: Glutton plays as a traitor; Ravenous is omniscient/obvious.
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.glutton.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    local role = target:GetRoleStringRaw()
    if role == "ravenous" then
        return mult * 2.0  -- Ravenous is obviously hostile
    end
end)

print("[TTT Bots 2] Glutton/Ravenous role integration loaded.")
return true
