--- Pure role integration for TTT Bots 2
--- The Pure is a passive, no-shop Innocent sub-role on TEAM_INNOCENT.
--- Key mechanics:
---   • unknownTeam = true — hidden from both sides
---   • No shop (SHOP_DISABLED), no credits
---   • On-death penalty: if someone kills the Pure (and isn't the Pure), that attacker
---     is temporarily blinded for ttt2_pure_blind_time seconds — server-driven
---   • If the Pure kills anyone, the Pure is demoted to a plain Innocent (loses role)
---   • Winning condition: survive as a regular innocent
---
--- Bot behavior:
---   • Pacifist playstyle: avoids initiating combat at all costs
---   • CombatRetreat placed high in tree — flee before fight
---   • Stays near groups for safety but avoids getting into firefights
---   • If cornered, only then will FightBack engage (self-preservation)
---   • Personality locked to very low aggression to prevent kill → demotion

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_PURE then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "You are the Pure, a passive innocent sub-role. "
    .. "If you are killed, your killer is temporarily blinded — a powerful deterrent. "
    .. "However, if YOU kill anyone, you are demoted to a regular Innocent and lose your power. "
    .. "Avoid combat at all costs. Flee from fights. Stay with groups for safety. "
    .. "Your death is your weapon — make your killer pay the price."

-- Pacifist tree: flee > investigate > group up > fight only as absolute last resort
local bTree = {
    _bh.EvadeGravityMine,
    _bh.CombatRetreat,         -- FLEE from combat first — killing = demotion!
    _prior.FightBack,          -- Only if cornered with no escape
    _prior.Requests,
    _prior.Chatter,
    _bh.InvestigateCorpse,     -- Can still investigate safely
    _prior.Support,            -- Heal others (non-lethal support)
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _bh.Decrowd,               -- Avoid crowds to avoid crossfire
    _bh.Follow,                -- Follow safe players for protection
    _bh.GroupUp,               -- Safety in numbers
    _bh.Wander,
}

local pure = TTTBots.RoleData.New("pure", TEAM_INNOCENT)
pure:SetDefusesC4(true)
pure:SetTeam(TEAM_INNOCENT)
pure:SetBTree(bTree)
pure:SetUsesSuspicion(true)
pure:SetCanHide(true)              -- Hide from danger
pure:SetCanSnipe(false)            -- No sniping — pacifist
pure:SetKOSUnknown(false)
pure:SetStartsFights(false)        -- Never start fights
pure:SetCanCoordinateInnocent(false) -- unknownTeam
pure:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(pure)

-- ---------------------------------------------------------------------------
-- Personality enforcement: keep the Pure at very low aggression at all times.
-- Any personality randomization or combat event must not push aggression up.
-- ---------------------------------------------------------------------------
local _nextPureCheck = 0
hook.Add("Think", "TTTBots.Pure.PacifistEnforce", function()
    if not TTTBots.Match.IsRoundActive() then return end
    if CurTime() < _nextPureCheck then return end
    _nextPureCheck = CurTime() + 2

    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and bot:IsBot() and bot:Alive()) then continue end
        if bot:GetSubRole() ~= ROLE_PURE then continue end

        local personality = bot.BotPersonality and bot:BotPersonality()
        if not personality then continue end

        -- Hard-cap aggression: Pure should NEVER be aggressive
        local currentAggr = personality.GetAggression and personality:GetAggression() or 0.5
        if currentAggr > 0.15 then
            personality:SetAggression(0.15)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Suspicion hook: Pure appears completely harmless and innocent.
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.pure.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    if target:GetRoleStringRaw() ~= "pure" then return end
    return mult * 0.15  -- Nearly zero suspicion — Pure is extremely passive
end)

print("[TTT Bots 2] Pure role integration loaded — pacifist survival role.")
return true
