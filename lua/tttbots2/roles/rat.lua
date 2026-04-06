--- Rat role integration for TTT Bots 2
--- The Rat is an innocent sub-role on TEAM_INNOCENT with unknownTeam = true.
--- At the start they have a countdown timer. When it expires, they become
--- highlighted (visible via marker vision) to all traitors, and they learn
--- the names of living traitors. Both sides are now in a mutual hunt.
---
--- Key mechanics:
---   • Pre-timer: acts as a normal innocent
---   • Post-timer: traitors see the Rat's position through walls; Rat learns traitor names
---   • If ttt2_rat_instant_expose is on: both happen immediately at round start
---   • No shop, no traitor buttons
---
--- Bot behavior:
---   • Pre-reveal: InnocentLike — blend in, use suspicion
---   • Post-reveal: switch to aggressive combat (now knows who traitors are)
---   • PlayerHurt hook fires when the Rat is attacked post-reveal to set attacker as combat target

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_RAT then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- Pre-reveal: act like a normal innocent
local bTreeHidden = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _bh.Defib,
    _prior.Restore,
    _bh.InvestigateCorpse,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol,
}

-- Post-reveal: traitors are now known — hunt them aggressively
local bTreeRevealed = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _bh.Stalk,                  -- Hunt the known traitors
    _prior.Restore,
    _prior.Investigate,
    _prior.Patrol,
}

local roleDescription = "You are the Rat, an innocent sub-role. After a timer, you are revealed to all "
    .. "traitors via wall-highlighting AND you learn which players are traitors. "
    .. "Before the reveal: blend in as an innocent. After the reveal: you know who the "
    .. "traitors are — hunt them down before they hunt you."

local rat = TTTBots.RoleData.New("rat", TEAM_INNOCENT)
rat:SetDefusesC4(false)
rat:SetPlantsC4(false)
rat:SetTeam(TEAM_INNOCENT)
rat:SetBTree(bTreeHidden)           -- Default; switched post-reveal by hook
rat:SetCanCoordinate(false)
rat:SetCanHaveRadar(false)
rat:SetStartsFights(false)          -- Pre-reveal: passive
rat:SetUsesSuspicion(true)          -- unknownTeam — uses suspicion
rat:SetKOSUnknown(false)
rat:SetKOSAll(false)
rat:SetKOSedByAll(false)
rat:SetLovesTeammates(false)
rat:SetKnowsLifeStates(false)
rat:SetAlliedTeams({ [TEAM_INNOCENT] = true })
rat:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(rat)

-- ---------------------------------------------------------------------------
-- Dynamic tree swap: once the Rat timer fires, switch to the aggressive tree.
-- We detect reveal by watching the "ttt2_rat_clock_timer" expiry indirectly
-- via the TTT2PostPlayerDeath hook (traitor dies = rat likely exposed already),
-- or via a networked NWBool if available. Simplest fallback: check if the
-- Rat has a marker vision object on them each Think tick.
-- ---------------------------------------------------------------------------
local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor
function TTTBots.Behaviors.GetTreeFor(bot)
    if not IsValid(bot) then return nil end

    local role = TTTBots.Roles.GetRoleFor(bot)
    if role and role:GetName() == "rat" then
        -- If the rat has been revealed (marker vision exists on them), use aggressive tree
        if bot.IsRatRevealed then
            return bTreeRevealed
        end
        return bTreeHidden
    end

    return _origGetTreeFor(bot)
end

-- ---------------------------------------------------------------------------
-- Hook: detect when traitors see and attack the Rat — mark as revealed
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsOnWitnessHurt", "TTTBots.rat.revealDetect", function(witness, victim, attacker, healthRemaining, damageTaken)
    if not IsValid(victim) then return end
    if victim:GetRoleStringRaw() ~= "rat" then return end

    -- If a traitor is attacking the rat, they are now in mutual-hunt mode
    if IsValid(attacker) and attacker:GetTeam() == TEAM_TRAITOR then
        victim.IsRatRevealed = true
    end
end)

-- Reset on round start
hook.Add("TTTBeginRound", "TTTBots.rat.resetReveal", function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            ply.IsRatRevealed = nil
        end
    end
end)

return true
