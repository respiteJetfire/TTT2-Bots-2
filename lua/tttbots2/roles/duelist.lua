--- Duelist role integration for TTT Bots 2
--- The Duelist is a solo neutral role on TEAM_NONE. When a round starts, all
--- Duelists are paired for a fight to the death. They gain immunity from all
--- non-Duelists (configurable). The survivor of the duel is rewarded with
--- either the dead Duelist's original role, a random role, or ROLE_UNDECIDED.
---
--- Bot behavior:
---   • Plays like a normal innocent pre-duel assignment
---   • Once activated as a Duelist, aggressively hunts the other Duelist
---   • Uses Stalk to seek out the opponent
---   • Does not fight non-Duelists (immunity is server-driven)
---   • unknownTeam: uses suspicion normally

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DUELIST then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,           -- Fight back if attacked (duel is to the death)
    _prior.Requests,
    _bh.Stalk,                  -- Hunt your duelist opponent aggressively
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Patrol,
}

local roleDescription = "You are the Duelist. At the start of the round you are paired with another "
    .. "Duelist for a fight to the death. You are immune to non-Duelists (configurable). "
    .. "Defeat your opponent — the survivor wins their role as a reward. "
    .. "Seek your opponent aggressively and fight to win the duel."

local duelist = TTTBots.RoleData.New("duelist", TEAM_NONE)
duelist:SetDefusesC4(false)
duelist:SetPlantsC4(false)
duelist:SetTeam(TEAM_NONE)
duelist:SetBTree(bTree)
duelist:SetCanCoordinate(false)
duelist:SetCanHaveRadar(false)
duelist:SetStartsFights(true)           -- Actively hunts the opponent
duelist:SetUsesSuspicion(true)          -- Acts like innocent otherwise
duelist:SetKOSUnknown(false)
duelist:SetKOSAll(false)
duelist:SetKOSedByAll(false)
duelist:SetNeutralOverride(true)        -- Don't get cross-team targeted
duelist:SetLovesTeammates(false)
duelist:SetKnowsLifeStates(false)
duelist:SetAlliedTeams({ [TEAM_NONE] = false })
duelist:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(duelist)

-- ---------------------------------------------------------------------------
-- Suspicion hook: Duelists are neutral — low suspicion from bystanders
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.duelist.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    local role = target:GetRoleStringRaw()
    if role == "duelist" then
        return mult * 0.4   -- Somewhat suspicious (they are fighting someone)
    end
end)

return true
