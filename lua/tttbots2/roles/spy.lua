if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SPY then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

--- Custom behavior tree for the Spy role.
--- Prioritises active surveillance of suspicious players while retaining the
--- standard innocent fallback chain for combat, support, and investigation.
local bTree = {
    _prior.Requests,
    _prior.FightBack,
    _prior.Support,
    _bh.SpySurveillance,
    _bh.SpyIntelReport,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

local spy = TTTBots.RoleData.New("spy")
spy:SetDefusesC4(false)
spy:SetTeam(TEAM_INNOCENT)
spy:SetBTree(bTree)
spy:SetCanHide(true)
spy:SetCanSnipe(true)
spy:SetUsesSuspicion(true)
spy:SetKnowsLifeStates(true)
spy:SetEnemyTeams({[TEAM_DOOMSLAYER] = true})
spy:SetIsFollower(true)
TTTBots.Roles.RegisterRole(spy)

--- Spy bots are more perceptive: they build suspicion 1.5x faster than ordinary innocents.
--- NOTE: The hook contract multiplies the existing `mult` by whatever we return, so returning 1.5
--- correctly applies a 50% boost without squaring the existing modifier.
hook.Add("TTTBotsModifySuspicion", "TTTBots.Spy.EnhancedSuspicion", function(bot, target, reason, mult)
    if not IsValid(bot) then return nil end
    if bot:GetSubRole() ~= ROLE_SPY then return nil end
    return 1.5
end)

return true
