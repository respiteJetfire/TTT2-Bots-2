--- Sus role integration for TTT Bots 2
--- The Sus is an innocent sub-role on TEAM_INNOCENT that is a highly suspicious
--- agent. They are isOmniscientRole and unknownTeam = true. They have a chance
--- (ttt2_sus_traitorchance) to actually be reassigned to TEAM_TRAITOR on spawn.
--- They appear as traitor to traitors, appear as traitor on corpse inspection,
--- and jam traitor team chat/voice when alive. Has shop (SHOP_FALLBACK_TRAITOR).
---
--- Key mechanics:
---   • Might actually be on TEAM_TRAITOR (configurable probability)
---   • Jams traitor team chat and voice while alive
---   • On death corpse shows as ROLE_TRAITOR
---   • isOmniscientRole: full life-state awareness
---   • unknownTeam = true (hidden from both sides)
---   • Traitors see the Sus as a traitor on radar
---
--- Bot behavior:
---   • If innocent-aligned: InnocentLike with omniscient awareness
---   • If traitor-aligned: TraitorLike coordination
---   • Bot cannot know which it is at registration time; default to DetectiveLike
---     (investigates, uses shop, acts suspiciously authoritative)
---   • The team-jam mechanic is fully server-driven

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SUS then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- Sus acts like a detective-level investigator with possible traitor agenda
local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _bh.FakeInvestigate,        -- Possibly blending in as innocent
    _bh.InvestigateCorpse,      -- Gather intel with omniscience
    _bh.UseDNAScanner,          -- Has shop — may have DNA scanner
    _prior.Traitor,             -- If actually traitor-aligned, coordinate
    _prior.Restore,
    _prior.Investigate,
    _prior.Patrol,
}

local roleDescription = "You are the Sus, an omniscient suspicious agent. You may or may not secretly "
    .. "be on the traitor team. You jam traitor team communication while alive. "
    .. "You appear as a traitor to traitors and on corpse inspection. "
    .. "Act like a detective — investigate, gather intel, and keep everyone guessing."

local sus = TTTBots.RoleData.New("sus", TEAM_INNOCENT)
sus:SetDefusesC4(false)
sus:SetPlantsC4(false)
sus:SetTeam(TEAM_INNOCENT)          -- May be reassigned to TEAM_TRAITOR at spawn
sus:SetBTree(bTree)
sus:SetCanCoordinate(true)          -- May coordinate if traitor-aligned
sus:SetCanHaveRadar(true)           -- isOmniscientRole
sus:SetStartsFights(true)
sus:SetUsesSuspicion(true)          -- unknownTeam
sus:SetKOSUnknown(false)
sus:SetKnowsLifeStates(true)        -- isOmniscientRole
sus:SetLovesTeammates(false)
sus:SetAlliedTeams({ [TEAM_INNOCENT] = true })
sus:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(sus)

-- ---------------------------------------------------------------------------
-- Suspicion hook: Sus is legitimately suspicious (it's in the name)
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.sus.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    local role = target:GetRoleStringRaw()
    if role == "sus" then
        return mult * 0.6   -- Suspicious but officially "innocent" until proven
    end
end)

return true
