--- Vulture role integration for TTT Bots 2
--- The Vulture is a solo independent role on TEAM_VULTURE. They must eat a
--- percentage of all corpses in the round to win. They have:
---   • weapon_ttt_vult_knife — talon melee weapon that heals on kill; can eat corpses
---   • Marker vision on all corpses (see them through walls)
---   • No shop, no credits, no coordination
---   • Win condition: eat ttt2_vult_consumed_bodies_win_threshold × player_count corpses
---
--- Bot behavior:
---   • VultureEat behavior: seek and consume corpses (primary objective)
---   • Stalk: hunt players for kills to create more corpses
---   • Aggressive melee fighter — uses the knife to kill and then eat
---   • Omniscient-level corpse awareness via marker vision (simulated by behavior)

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_VULTURE then return false end

TEAM_VULTURE = TEAM_VULTURE or "vulture"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "You are the Vulture, a solo independent role. You win by consuming a percentage "
    .. "of all corpses in the round using your talon knife. Kill players to create corpses, then eat them. "
    .. "You can see all corpses through walls. No shop, no allies — just hunt, kill, and feast."

-- Corpse-eating is highest priority; then hunting for more corpses
local bTree = {
    _prior.Chatter,
    _prior.FightBack,           -- Fight back if attacked
    _bh.VultureEat,             -- [CUSTOM] Seek and eat corpses
    _prior.Requests,
    _bh.Stalk,                  -- Hunt players to create more corpses
    _prior.Restore,
    _bh.Decrowd,
    _prior.Patrol,
}

local vulture = TTTBots.RoleData.New("vulture", TEAM_VULTURE)
vulture:SetDefusesC4(false)
vulture:SetPlantsC4(false)
vulture:SetTeam(TEAM_VULTURE)
vulture:SetBTree(bTree)
vulture:SetCanCoordinate(false)
vulture:SetCanHaveRadar(false)
vulture:SetStartsFights(true)
vulture:SetUsesSuspicion(false)
vulture:SetKOSAll(true)             -- Everyone is a potential corpse
vulture:SetKOSedByAll(true)
vulture:SetKnowsLifeStates(false)
vulture:SetNeutralOverride(false)
vulture:SetLovesTeammates(false)
vulture:SetPreferredWeapon("weapon_ttt_vult_knife")
vulture:SetAlliedTeams({ [TEAM_VULTURE] = true })
vulture:SetAlliedRoles({ vulture = true })
vulture:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(vulture)

-- ---------------------------------------------------------------------------
-- Suspicion hook: Vulture is an independent unknown — moderate suspicion
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.vulture.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    local role = target:GetRoleStringRaw()
    if role == "vulture" then
        return mult * 0.8  -- Slightly suspicious but not obvious
    end
end)

return true
