--- Yandere/Senpai role integration for TTT Bots 2
--- This addon introduces three related roles:
---   • ROLE_YCALM  — Yandere in "calm" phase (TEAM_INNOCENT, unknownTeam)
---   • ROLE_YCRAZY — Yandere in "crazy" phase (after Senpai is killed/endangered)
---   • ROLE_SENPAI — Assigned randomly to an innocent at round start; linked to the Yandere
---
--- Key mechanics (Yandere):
---   • Starts as YCALM — acts as an innocent with a knife and radar
---   • Has a "Desire Level" (0–4) that rises as Senpai takes damage
---   • At DES_CRAZY (level 4, triggered when Senpai dies) the Yandere goes berserk —
---     speed and damage scale to maximum, heals on kill
---   • Desire level changes are tracked via NWInt "Desire_Level"
---   • GetTreeFor checks ROLE_YCRAZY vs ROLE_YCALM each tick
---
--- Key mechanics (Senpai):
---   • Innocent sub-role; linked to the Yandere protecting them
---   • If Senpai dies by someone other than the Yandere, Yandere goes crazy
---   • No special bot abilities needed — behaves as a regular innocent
---
--- Bot behavior:
---   • Pre-crazy (YCALM): InnocentLike — blend in, use suspicion, protect Senpai
---   • Post-crazy (YCRAZY): Aggressive Stalk — hunt all enemies at max speed
---   • GetTreeFor override swaps tree on ROLE_YCRAZY check
---   • Senpai: InnocentLike builder

if not TTTBots.Lib.IsTTT2() then return false end

-- ============================================================
-- Yandere calm phase (ROLE_YCALM)
-- ============================================================
if ROLE_YCALM then
    local _bh = TTTBots.Behaviors
    local _prior = TTTBots.Behaviors.PriorityNodes

    local calmTree = {
        _prior.Chatter,
        _prior.FightBack,
        _prior.Requests,
        _prior.Support,
        _prior.Restore,
        _prior.Investigate,
        _bh.Decrowd,
        _prior.Patrol,
    }

    local crazyTree = {
        _prior.Chatter,
        _prior.FightBack,
        _bh.Stalk,
        _prior.Patrol,
    }

    local ycalm = TTTBots.RoleData.New("ycalm", TEAM_INNOCENT)
    ycalm:SetDefusesC4(false)
    ycalm:SetTeam(TEAM_INNOCENT)
    ycalm:SetBTree(calmTree)
    ycalm:SetCanCoordinate(false)
    ycalm:SetCanHaveRadar(true)      -- Given item_ttt_radar on loadout
    ycalm:SetStartsFights(true)
    ycalm:SetUsesSuspicion(true)     -- unknownTeam
    ycalm:SetCanSnipe(false)
    ycalm:SetCanHide(true)
    ycalm:SetKnowsLifeStates(false)
    ycalm:SetLovesTeammates(false)
    ycalm:SetAlliedTeams({ [TEAM_INNOCENT] = true })

    -- Two-phase tree: calm blend → crazy Stalk after Senpai dies
    ycalm:SetGetTreeFor(function(bot)
        if IsValid(bot) and bot:GetSubRole() == ROLE_YCRAZY then
            return crazyTree
        end
        return calmTree
    end)

    ycalm:SetRoleDescription(
        "You are the Yandere (calm phase). Your Senpai was randomly assigned to another innocent. "
        .. "Blend in as innocent and protect your Senpai. If your Senpai is hurt, your desire level rises. "
        .. "If your Senpai dies, you go CRAZY and hunt everyone at maximum speed. "
        .. "You have a knife and radar. Act normal until forced to react."
    )
    TTTBots.Roles.RegisterRole(ycalm)
end

-- ============================================================
-- Yandere crazy phase (ROLE_YCRAZY)
-- ============================================================
if ROLE_YCRAZY then
    local _bh = TTTBots.Behaviors
    local _prior = TTTBots.Behaviors.PriorityNodes

    local crazyTree = {
        _prior.Chatter,
        _prior.FightBack,
        _bh.Stalk,
        _prior.Patrol,
    }

    local ycrazy = TTTBots.RoleData.New("ycrazy", TEAM_INNOCENT)
    ycrazy:SetDefusesC4(false)
    ycrazy:SetTeam(TEAM_INNOCENT)
    ycrazy:SetBTree(crazyTree)
    ycrazy:SetCanCoordinate(false)
    ycrazy:SetCanHaveRadar(true)
    ycrazy:SetStartsFights(true)
    ycrazy:SetUsesSuspicion(false)   -- Full aggression mode
    ycrazy:SetCanSnipe(false)
    ycrazy:SetCanHide(false)
    ycrazy:SetKnowsLifeStates(false)
    ycrazy:SetKOSAll(true)           -- Hunt everyone when crazy
    ycrazy:SetKOSedByAll(true)
    ycrazy:SetLovesTeammates(false)
    ycrazy:SetAlliedTeams({})

    ycrazy:SetRoleDescription(
        "You are the Yandere (CRAZY phase). Your Senpai is gone and you are FURIOUS. "
        .. "Attack everyone. You heal on kills and move at maximum speed. "
        .. "Win by eliminating every other player."
    )
    TTTBots.Roles.RegisterRole(ycrazy)
end

-- ============================================================
-- Senpai (ROLE_SENPAI)
-- ============================================================
if ROLE_SENPAI then
    local senpai = TTTBots.RoleBuilder.InnocentLike("senpai")
    TTTBots.Roles.RegisterRole(senpai)
end

return true
