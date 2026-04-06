--- Elderly role integration for TTT Bots 2
--- The Elderly is a solo neutral role on TEAM_NONE. They have severely
--- reduced max HP (configurable), making them extremely fragile. They share
--- role visibility with Jesters. No shop, no special weapons.
---
--- Bot behavior:
---   • Extremely defensive — avoids all combat due to low HP
---   • Uses CombatRetreat aggressively
---   • Prioritizes finding health pickups and staying safe
---   • unknownTeam: uses suspicion system
---   • Neutral: survives by staying away from conflict

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_ELDERLY then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _bh.CombatRetreat,          -- FLEE from all combat (very low HP)
    _prior.FightBack,           -- Fight back only when cornered
    _prior.Requests,
    _prior.Restore,             -- Desperately seek health pickups
    _bh.Interact,
    _prior.Investigate,
    _bh.Decrowd,                -- Stay away from crowds (danger)
    _prior.Patrol,
}

local roleDescription = "You are the Elderly, a neutral solo role with severely reduced maximum HP. "
    .. "You are extremely fragile — avoid all combat at all costs. "
    .. "Stick to health pickups and stay away from fighting. Survive to win."

local elderly = TTTBots.RoleData.New("elderly", TEAM_NONE)
elderly:SetDefusesC4(false)
elderly:SetPlantsC4(false)
elderly:SetTeam(TEAM_NONE)
elderly:SetBTree(bTree)
elderly:SetCanCoordinate(false)
elderly:SetCanHaveRadar(false)
elderly:SetStartsFights(false)      -- Far too fragile to start fights
elderly:SetUsesSuspicion(true)      -- unknownTeam — blends in
elderly:SetKOSUnknown(false)
elderly:SetKOSAll(false)
elderly:SetKOSedByAll(false)
elderly:SetNeutralOverride(true)    -- Don't get proactively targeted
elderly:SetLovesTeammates(false)
elderly:SetKnowsLifeStates(false)
elderly:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(elderly)

-- ---------------------------------------------------------------------------
-- Suspicion hook: Elderly is neutral and unknown — treat as low threat
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.elderly.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    local role = target:GetRoleStringRaw()
    if role == "elderly" then
        return mult * 0.5   -- Somewhat suspicious (unknown team) but mostly harmless
    end
end)

return true
