--- Survivalist role integration for TTT Bots 2
--- The Survivalist is an innocent sub-role (isPolicingRole, unknownTeam).
--- Their identity is unknown to allies. They have access to the detective shop.
---
--- Bot strategy:
---   • unknownTeam — plays alone, uses suspicion system to identify enemies.
---   • Scavenger emphasis: GetWeapons / LootNearby are placed at high priority
---     so the bot actively grabs dropped weapons and ammo to stay armed.
---   • Favours CombatRetreat when health is low (survivalist instinct: live
---     to fight another day).
---   • Accuses/investigates to fulfil the policing role.
---   • No team coordination (no InnocentCoordinator).

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SURVIVALIST then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _bh.EvadeGravityMine,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Requests,
    _prior.Chatter,
    _prior.Grenades,
    _prior.Accuse,
    _bh.InvestigateCorpse,  -- Detectives investigate; survivalist does too for intel
    _prior.Restore,         -- GetWeapons / LootNearby elevated: scavenger priority
    _bh.FollowInnocentPlan,
    _prior.Support,
    _bh.Defuse,
    _prior.Investigate,
    _bh.ActiveInvestigate,
    _bh.Interact,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

local roleDescription =
    "The Survivalist is a secret innocent policing role (unknownTeam). "
    .. "Bots prioritise looting dropped weapons and ammo (scavenger playstyle), "
    .. "retreat when low on health, and use the suspicion system to identify "
    .. "traitors without relying on team coordination."

local survivalist = TTTBots.RoleData.New("survivalist", TEAM_INNOCENT)
survivalist:SetDefusesC4(true)
survivalist:SetTeam(TEAM_INNOCENT)
survivalist:SetBTree(bTree)
survivalist:SetUsesSuspicion(true)
survivalist:SetCanHide(true)
survivalist:SetCanSnipe(true)
survivalist:SetKOSUnknown(false)
survivalist:SetAlliedRoles({})
survivalist:SetAlliedTeams({})
survivalist:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(survivalist)

-- ---------------------------------------------------------------------------
-- Survivalist personality: low-health caution.
-- Uses the BotRoundAwareness component's aggressionMult field to modulate
-- how aggressively the bot engages, based on remaining health.
-- ---------------------------------------------------------------------------
hook.Add("Think", "TTTBots.Survivalist.LowHealthCaution", function()
    if not TTTBots.Match.IsRoundActive() then return end

    for _, ply in ipairs(player.GetAll()) do
        if not (IsValid(ply) and ply:IsBot() and ply:IsActive()) then continue end
        if ply:GetSubRole() ~= ROLE_SURVIVALIST then continue end

        local ra = ply.BotRoundAwareness and ply:BotRoundAwareness()
        if not ra then continue end

        local hpRatio = ply:Health() / math.max(ply:GetMaxHealth(), 1)
        if hpRatio < 0.35 then
            ra.aggressionMult = 0.2   -- Very cautious when nearly dead
        elseif hpRatio < 0.6 then
            ra.aggressionMult = 0.4   -- Moderately cautious
        else
            ra.aggressionMult = 0.65  -- Confident when healthy
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Suspicion modifier: appears as a slightly-trustworthy unknown-team role.
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.survivalist.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    if target:GetRoleStringRaw() ~= "survivalist" then return end
    return mult * 0.65 -- Appears fairly innocent
end)

print("[TTT Bots 2] Survivalist role integration loaded.")
return true
