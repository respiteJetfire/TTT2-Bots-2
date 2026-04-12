--- Warpriest (Warrior Priest) role integration for TTT Bots 2
--- The Warpriest is an omniscient, public-facing, policing Detective sub-role.
--- Key mechanics:
---   • isPublicRole + isPolicingRole: everyone knows the Warpriest
---   • isOmniscientRole: full MIA/life-state awareness
---   • unknownTeam = true — hidden until outed or defeated
---   • SHOP_FALLBACK_DETECTIVE: detective shop access
---   • Receives weapon_ttt_sigmartome as role loadout (a special melee tome weapon)
---   • Scores heavily for kills (8×), penalized for team kills (−8×)
---   • Gains armor from shop (item_ttt_armor given on role change)
---
--- Bot behavior:
---   • DetectiveLike builder — investigate, police, use shop, use DNA scanner
---   • Prefers melee range when equipped with the tome — aggressive close-range
---   • Scales aggression based on armor status (armor = confident push)
---   • Omniscient public authority figure; no coordination (public role)
---   • Custom tree places FightBack and Stalk higher for melee engagement

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_WARP then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription =
    "You are the Warpriest, a melee-focused detective authority figure. "
    .. "You wield the Sigmar Tome — a devastating melee weapon that rewards close combat. "
    .. "You score 8× points for kills but lose 8× for team kills, so target carefully. "
    .. "You have armor and detective shop access. Push aggressively into combat — "
    .. "your melee damage output is massive at close range."

-- Custom tree: aggressive melee + detective investigation
local bTree = {
    _bh.EvadeGravityMine,
    _prior.FightBack,           -- Immediate combat response (melee range = bonus damage)
    _prior.SelfDefense,
    _prior.Chatter,
    _prior.Grenades,
    _prior.Requests,
    _prior.Accuse,
    _bh.InvestigateCorpse,      -- Detective work: ID bodies
    _prior.DNAScanner,
    _prior.Convert,
    _bh.Stalk,                  -- Proactively seek melee engagements
    _prior.Restore,
    _bh.FollowInnocentPlan,
    _prior.Support,
    _prior.TacticalEquipment,
    _bh.Defuse,
    _bh.ActiveInvestigate,
    _bh.Interact,
    _prior.Minge,
    _prior.Investigate,
    _bh.Decrowd,
    _prior.Patrol,
}

local warpriest = TTTBots.RoleBuilder.DetectiveLike("warp")
warpriest:SetBTree(bTree)
warpriest:SetCanSnipe(false)        -- Melee-focused: no sniping
warpriest:SetCanHide(false)         -- Public authority figure: push forward
warpriest:SetKnowsLifeStates(true)  -- isOmniscientRole
warpriest:SetStartsFights(true)     -- Aggressive melee fighter
warpriest:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(warpriest)

-- ---------------------------------------------------------------------------
-- Armor-based aggression scaling: Warpriest becomes more aggressive with armor.
-- ---------------------------------------------------------------------------
local _nextWarpCheck = 0
hook.Add("Think", "TTTBots.Warpriest.ArmorAggression", function()
    if not TTTBots.Match.IsRoundActive() then return end
    if CurTime() < _nextWarpCheck then return end
    _nextWarpCheck = CurTime() + 2

    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and bot:IsBot() and bot:Alive()) then continue end
        if bot:GetSubRole() ~= ROLE_WARP then continue end

        local personality = bot.BotPersonality and bot:BotPersonality()
        if not personality then continue end

        local hasArmor = bot:GetNWBool("hasArmor", false) or (bot.Armor and bot:Armor() > 0)
        local hpRatio = bot:Health() / math.max(bot:GetMaxHealth(), 1)

        if hasArmor and hpRatio > 0.5 then
            personality:SetAggression(0.9) -- Armored and healthy: push hard
        elseif hpRatio > 0.3 then
            personality:SetAggression(0.65) -- Moderate: still dangerous
        else
            personality:SetAggression(0.4) -- Low HP: cautious retreat
        end
    end
end)

print("[TTT Bots 2] Warpriest role integration loaded — melee-focused detective authority.")
return true
