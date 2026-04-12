--- Mutant role integration for TTT Bots 2
--- The Mutant is a damage-scaling Innocent sub-role on TEAM_INNOCENT.
--- Key mechanics:
---   • unknownTeam = true — hidden alignment
---   • No shop (SHOP_DISABLED), no credits
---   • Gains resistance to fire, explosion, fall, and prop damage (configurable)
---   • Has a status system with 4 mutation tiers driven by cumulative damage taken
---   • At higher tiers: gains radar, speed boosts, increased max HP, and shop access
---   • Damage scaling and tier progression are fully server-driven
---   • ply.mutant_damage_taken tracks cumulative incoming damage
---
--- Bot behavior:
---   • InnocentLike base — fight back, use suspicion, no coordination
---   • Dynamic aggression: becomes more aggressive at higher mutation tiers
---   • At Tier 3+: gains radar; transitions from cautious to proactive hunter
---   • At Tier 4: full aggression; actively seeks out enemies
---   • Low tiers: plays cautiously to survive and accumulate damage for tier-up

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_MUT then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "You are the Mutant, an innocent sub-role that grows stronger from damage. "
    .. "Each hit you take accumulates mutation energy. At higher tiers, you gain speed, "
    .. "max HP, radar, and shop access. Play cautiously at first — absorb damage without dying. "
    .. "At higher tiers, become aggressive and use your enhanced abilities to hunt enemies."

-- Low-tier tree: cautious innocent play
local bTreeCautious = {
    _bh.EvadeGravityMine,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Requests,
    _prior.Chatter,
    _bh.InvestigateCorpse,
    _prior.Support,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol,
}

-- High-tier tree: aggressive hunter with enhanced stats
local bTreeAggressive = {
    _bh.EvadeGravityMine,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Chatter,
    _prior.Grenades,
    _prior.Requests,
    _prior.Accuse,
    _bh.InvestigateCorpse,
    _bh.Stalk,              -- Proactively hunt enemies with enhanced stats
    _prior.Restore,
    _bh.ActiveInvestigate,
    _bh.Interact,
    _prior.Investigate,
    _prior.Patrol,
}

local mutant = TTTBots.RoleData.New("mut", TEAM_INNOCENT)
mutant:SetDefusesC4(true)
mutant:SetTeam(TEAM_INNOCENT)
mutant:SetBTree(bTreeCautious)
mutant:SetUsesSuspicion(true)
mutant:SetCanHide(true)
mutant:SetCanSnipe(true)
mutant:SetKOSUnknown(false)
mutant:SetCanCoordinateInnocent(false) -- unknownTeam
mutant:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(mutant)

-- ---------------------------------------------------------------------------
-- Dynamic tree swap + aggression scaling based on mutation tier.
-- The addon tracks tiers via ply.mutant_damage_taken and NWInt "mutant_tier".
-- ---------------------------------------------------------------------------
local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor
function TTTBots.Behaviors.GetTreeFor(bot)
    if not IsValid(bot) then return nil end

    local role = TTTBots.Roles.GetRoleFor(bot)
    if role and role:GetName() == "mut" then
        local tier = bot:GetNWInt("mutant_tier", 0)
        if tier >= 3 then
            return bTreeAggressive
        end
        return bTreeCautious
    end

    return _origGetTreeFor(bot)
end

-- ---------------------------------------------------------------------------
-- Aggression scaling: adjust personality based on mutation tier.
-- ---------------------------------------------------------------------------
local _nextMutantCheck = 0
hook.Add("Think", "TTTBots.Mutant.TierAggression", function()
    if not TTTBots.Match.IsRoundActive() then return end
    if CurTime() < _nextMutantCheck then return end
    _nextMutantCheck = CurTime() + 1.5

    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and bot:IsBot() and bot:Alive()) then continue end
        if bot:GetSubRole() ~= ROLE_MUT then continue end

        local personality = bot.BotPersonality and bot:BotPersonality()
        if not personality then continue end

        local tier = bot:GetNWInt("mutant_tier", 0)
        if tier >= 4 then
            personality:SetAggression(1.0)  -- Maximum power: full aggression
        elseif tier >= 3 then
            personality:SetAggression(0.8)  -- Strong: proactive hunting
        elseif tier >= 2 then
            personality:SetAggression(0.55) -- Moderate: starting to feel powerful
        elseif tier >= 1 then
            personality:SetAggression(0.35) -- Low tier: cautious
        else
            personality:SetAggression(0.25) -- Base: very cautious, absorb damage
        end
    end
end)

print("[TTT Bots 2] Mutant role integration loaded — tier-based aggression scaling.")
return true
