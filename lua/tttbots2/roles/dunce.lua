--- Dunce role integration for TTT Bots 2
--- The Dunce is a punishment role on TEAM_DUNCE assigned to whoever killed
--- a Jester the previous round. It is NOT selectable normally — it can only
--- be forced via roleselection.finalRoles.
---
--- Key mechanics:
---   • isPublicRole — everyone knows who the Dunce is
---   • Cannot deal damage to players (server blocks all Dunce damage)
---   • Cannot pick up weapons (only has magneto-stick and crowbar)
---   • Wearing a dunce cap (cosmetic)
---   • If the Dunce somehow wins, everyone swaps roles next round
---   • Innocents win if only Innocents + Dunces remain
---
--- Bot behavior:
---   • StartsFights = false (can't deal damage anyway)
---   • Wanders the map, uses crowbar for pushing (harmless minge)
---   • No radar, no coordination, no shop
---   • Neutral-like: doesn't aggress anyone since attacks deal 0 damage

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DUNCE then return false end

TEAM_DUNCE = TEAM_DUNCE or "dunce"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,       -- Still flees from danger instinctively
    _prior.Requests,
    _bh.Interact,
    _prior.Minge,           -- Crowbar-minge: push people around for fun
    _prior.Investigate,     -- Wander and investigate
    _bh.Decrowd,
    _prior.Patrol,
}

local roleDescription = "You are the Dunce — a punishment role for killing the Jester. "
    .. "You cannot deal damage to anyone and cannot pick up real weapons. "
    .. "You have a magneto-stick and a crowbar. Everyone knows you are the Dunce. "
    .. "Just wander around trying not to embarrass yourself further."

local dunce = TTTBots.RoleData.New("dunce", TEAM_DUNCE)
dunce:SetDefusesC4(false)
dunce:SetPlantsC4(false)
dunce:SetTeam(TEAM_DUNCE)
dunce:SetBTree(bTree)
dunce:SetCanCoordinate(false)
dunce:SetCanHaveRadar(false)
dunce:SetStartsFights(false)        -- Damage is blocked server-side anyway
dunce:SetUsesSuspicion(false)       -- isPublicRole — no reason for suspicion system
dunce:SetKOSAll(false)
dunce:SetKOSedByAll(false)
dunce:SetNeutralOverride(true)      -- Don't be targeted proactively
dunce:SetLovesTeammates(false)
dunce:SetKnowsLifeStates(false)
dunce:SetAlliedTeams({ [TEAM_DUNCE] = true })
dunce:SetAlliedRoles({ dunce = true })
dunce:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(dunce)

-- ---------------------------------------------------------------------------
-- Suspicion hook: Dunce is harmless and public — zero suspicion
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.dunce.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    local role = target:GetRoleStringRaw()
    if role == "dunce" then
        return mult * 0.0   -- Completely harmless, never suspicious
    end
end)

return true
