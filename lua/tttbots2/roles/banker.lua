--- Banker role integration for TTT Bots 2
--- The Banker gains credits every time ANY other player buys something from the
--- shop (credits transfer to the Banker). The Banker may also give out credits
--- as "handouts" from their own pool.
---
--- Bot strategy:
---   • Plays as a DetectiveLike bot (policing, DNA scanner, corpse ID).
---   • Passively accumulates credits via server-side hooks (no bot action needed).
---   • Think hook: watch credit count; scale aggression with wealth.
---   • unknownTeam: no team coordination; relies on suspicion system.
---   • Prioritises survival (avoids risky fights early) to maximise credit gain
---     over time — reflected in reduced early-game aggression.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_BANKER then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _bh.EvadeGravityMine,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Chatter,
    _prior.Grenades,
    _prior.Requests,
    _prior.Accuse,
    _bh.InvestigateCorpse,
    _prior.DNAScanner,
    _prior.Convert,
    _prior.Restore,
    _bh.FollowInnocentPlan,
    _prior.Support,
    _prior.TacticalEquipment,  -- Spend those credits on gear
    _bh.Defuse,
    _bh.ActiveInvestigate,
    _bh.Interact,
    _prior.Minge,
    _prior.Investigate,
    _bh.Decrowd,
    _prior.Patrol
}

local roleDescription =
    "The Banker is a Detective sub-role who gains credits every time anyone buys "
    .. "from the shop. Bots will play defensively early to maximise passive credit "
    .. "accumulation, then spend freely on tactical equipment in the mid/late game."

local banker = TTTBots.RoleData.New("banker", TEAM_INNOCENT)
banker:SetDefusesC4(true)
banker:SetTeam(TEAM_INNOCENT)
banker:SetBTree(bTree)
banker:SetCanHaveRadar(true)
banker:SetAppearsPolice(true)
banker:SetUsesSuspicion(true)
banker:SetCanCoordinateInnocent(true)
banker:SetKOSUnknown(false)
if TEAM_DOOMSLAYER then
    banker:SetEnemyTeams({ [TEAM_DOOMSLAYER] = true })
end
banker:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(banker)

-- ---------------------------------------------------------------------------
-- Credit-gain awareness: scale aggression with current credit wealth.
-- ---------------------------------------------------------------------------

local _bankerCreditCache = {}

hook.Add("Think", "TTTBots.Banker.CreditWatch", function()
    if not TTTBots.Match.IsRoundActive() then return end

    for _, ply in ipairs(player.GetAll()) do
        if not (IsValid(ply) and ply:IsBot()) then continue end
        if ply:GetSubRole() ~= ROLE_BANKER then continue end

        local credits = ply:GetCredits()
        local prev = _bankerCreditCache[ply] or 0

        if credits > prev then
            local personality = ply.BotPersonality and ply:BotPersonality()
            if personality then
                -- Richer = slightly more confident, but never reckless.
                -- Map current credits to confidence and apply only the delta.
                if personality.GetMood and personality.ShiftMood then
                    local targetConfidence = math.Clamp(credits / 20, 0, 0.5)
                    local currentConfidence = personality:GetMood("confidence") or 0
                    personality:ShiftMood("confidence", targetConfidence - currentConfidence)
                end
            end
        end

        _bankerCreditCache[ply] = credits
    end
end)

hook.Add("TTTPrepareRound", "TTTBots.Banker.ResetCache", function()
    _bankerCreditCache = {}
end)

print("[TTT Bots 2] Banker role integration loaded.")
return true
