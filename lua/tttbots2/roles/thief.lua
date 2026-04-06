--- Thief role integration for TTT Bots 2
--- The Thief is a solo neutral role on TEAM_NONE (custom TEAM_THIEF). They win
--- by "stealing" the win: if any single team is on the verge of winning and the
--- Thief is still alive, they steal that win condition and claim victory instead.
--- Optionally announced as a public role. No shop beyond starting equipment.
---
--- Key mechanics:
---   • Custom TEAM_THIEF — joined at win-steal moment
---   • Win steal: if one team would win and the Thief is alive, Thief wins instead
---   • isPublicRole is configurable (ttt2_thief_is_public)
---
--- Bot behavior:
---   • Extremely survivalist — stay alive at all costs to enable the win steal
---   • Avoids fights unless forced (survival > aggression)
---   • Uses suspicion normally (blends in as a neutral)
---   • CombatRetreat is high priority to avoid dying

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_THIEF then return false end

TEAM_THIEF = TEAM_THIEF or "thiefs"
TEAM_JESTER = TEAM_JESTER or "jesters"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _bh.CombatRetreat,          -- Flee from combat — survival is paramount
    _prior.FightBack,           -- Only fight back when cornered
    _prior.Requests,
    _prior.Restore,             -- Seek health actively
    _bh.Interact,
    _prior.Investigate,
    _bh.Decrowd,                -- Avoid groups (dangerous)
    _prior.Patrol,
}

local roleDescription = "You are the Thief, a solo neutral role. You win by staying alive when another "
    .. "team is on the verge of winning — you steal their victory condition and claim it as your own. "
    .. "Do NOT die. Avoid all combat. Stay hidden and let the other teams fight each other out."

local thief = TTTBots.RoleData.New("thief", TEAM_THIEF)
thief:SetDefusesC4(false)
thief:SetPlantsC4(false)
thief:SetTeam(TEAM_THIEF)
thief:SetBTree(bTree)
thief:SetCanCoordinate(false)
thief:SetCanHaveRadar(false)
thief:SetStartsFights(false)        -- Purely survivalist — no aggression
thief:SetUsesSuspicion(true)        -- Blends in with neutral suspicion
thief:SetKOSUnknown(false)
thief:SetKOSAll(false)
thief:SetKOSedByAll(false)
thief:SetNeutralOverride(true)      -- Don't get proactively targeted
thief:SetLovesTeammates(false)
thief:SetKnowsLifeStates(false)
thief:SetAlliedTeams({ [TEAM_THIEF] = true })
thief:SetAlliedRoles({ thief = true })
thief:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(thief)

-- ---------------------------------------------------------------------------
-- Suspicion hook: Thief is neutral and avoidant — low-moderate suspicion
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.thief.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    local role = target:GetRoleStringRaw()
    if role == "thief" then
        return mult * 0.5   -- Blends in reasonably well
    end
end)

return true
