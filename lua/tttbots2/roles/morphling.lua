--- Morphling role integration for TTT Bots 2
--- The Morphling is a traitor sub-role on TEAM_TRAITOR. They are given
--- weapon_ttt_morph_disguise, which lets them take on the appearance and
--- displayed role of any player they look at. isOmniscientRole.
---
--- Bot behavior:
---   • TraitorLike builder — fights, coordinates with traitors, uses shop
---   • Deception blend: alibi-building and fake-investigating while disguised
---   • Prefers maintaining their disguise (plays as the mimicked role)
---   • isOmniscientRole: full life-state knowledge
---   • The disguise weapon is automatic — no special behavior node needed

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_MORPHLING then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,             -- Social chatter for cover while disguised
    _prior.FightBack,
    _prior.Requests,
    _bh.FakeInvestigate,        -- Blend in as innocent while disguised
    _bh.AlibiBbuilding,         -- Build alibis to maintain cover
    _prior.Traitor,             -- Core traitor coordination
    _bh.InvestigateCorpse,
    _prior.Restore,
    _prior.Investigate,
    _prior.Patrol,
}

local roleDescription = "You are the Morphling, a traitor sub-role equipped with a disguise device. "
    .. "You can copy the appearance and displayed role of any player you aim at. "
    .. "Use your disguise to blend in with innocents and coordinate with your traitor team. "
    .. "Act like whoever you are disguised as to maintain cover as long as possible."

local morphling = TTTBots.RoleBuilder.TraitorLike("morphling", TEAM_TRAITOR)
morphling:SetBTree(bTree)
morphling:SetKnowsLifeStates(true)      -- isOmniscientRole
morphling:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(morphling)

-- ---------------------------------------------------------------------------
-- Suspicion hook: Morphling is disguised — trust them like an innocent
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.morphling.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    local role = target:GetRoleStringRaw()
    if role == "morphling" then
        -- Appears as innocent/other role via disguise; lower suspicion
        return mult * 0.5
    end
end)

return true
