--- Leech role integration for TTT Bots 2
--- The Leech is a solo neutral role on TEAM_NONE with a hunger mechanic.
--- They have a hunger meter that drains over time. If they stay near other
--- players (within ttt2_leech_refill_radius), the meter refills. If it hits
--- zero, they die. When the round is near its end and the Leech is "feeding"
--- (hunger change is positive), they shift to the winning team.
---
--- Key mechanics:
---   • Hunger drains unless near other players
---   • Win condition: be feeding when the last team would win; Leech joins that team
---   • Die if hunger hits 0
---   • unknownTeam = true via TEAM_NONE (networkRoles = {JESTER})
---
--- Bot behavior:
---   • Stays as close to players as possible to keep hunger refilling
---   • Uses Decrowd in REVERSE: wants to be IN crowds, not out of them
---   • Follows players around to stay fed
---   • Neutral — does not start fights (survival depends on staying near targets)
---   • Similar logic to BeggarSeek but motivated by hunger, not role swap

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_LEECH then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"
TEAM_LEECH = TEAM_LEECH or "leech"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,           -- Fight back if attacked (dying = losing hunger)
    _prior.Requests,
    _bh.BeggarSeek,             -- Follow players to stay close (repurpose follow-player logic)
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Patrol,
}

local roleDescription = "You are the Leech, a solo neutral role. You have a hunger meter that drains "
    .. "unless you stay near other players. If your hunger hits zero, you die. "
    .. "Stay close to other players at all times to keep yourself fed. "
    .. "If you are feeding when the round ends, you join and win with the winning team."

local leech = TTTBots.RoleData.New("leech", TEAM_NONE)
leech:SetDefusesC4(false)
leech:SetPlantsC4(false)
leech:SetTeam(TEAM_NONE)
leech:SetBTree(bTree)
leech:SetCanCoordinate(false)
leech:SetCanHaveRadar(false)
leech:SetStartsFights(false)        -- Survival depends on proximity, not kills
leech:SetUsesSuspicion(true)        -- unknownTeam — blends in
leech:SetKOSUnknown(false)
leech:SetKOSAll(false)
leech:SetKOSedByAll(false)
leech:SetNeutralOverride(true)      -- Don't get proactively targeted
leech:SetLovesTeammates(false)
leech:SetKnowsLifeStates(false)
leech:SetAlliedTeams({ [TEAM_NONE] = false })
leech:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(leech)

-- ---------------------------------------------------------------------------
-- Suspicion hook: Leech is unknown/neutral — moderate suspicion
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.leech.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    local role = target:GetRoleStringRaw()
    if role == "leech" then
        return mult * 0.4   -- Somewhat unknown but mostly harmless-seeming
    end
end)

return true
