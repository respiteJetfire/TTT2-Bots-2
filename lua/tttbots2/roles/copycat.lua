--- Copycat role support for TTT2 Bots.
--- The Copycat is a solo team role that:
---   1. Inspects corpses to transcribe roles into the "Copycat Files"
---   2. Uses the Copycat Files weapon to switch subrole (stays on TEAM_COPYCAT)
---   3. Gains the abilities/appearance of the chosen role to infiltrate and kill
---   4. Wins by being the last team standing (or fulfilling team win conditions)
---
--- Bot strategy:
---   PRE-SWITCH: Aggressively seek and search corpses to build the role collection.
---               Prioritize policing-style investigation since the Copycat is a policing role.
---   SWITCH:     Once a desirable role is collected (or enough time has passed), switch.
---               Prefer combat/traitor-like roles for killing efficiency.
---   POST-SWITCH: Behavior tree dynamically resolves to a combat-focused tree
---               since the bot's subrole changes but team stays TEAM_COPYCAT.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_COPYCAT then return false end

TEAM_COPYCAT = TEAM_COPYCAT or "copycats"
TEAM_JESTER = TEAM_JESTER or "jesters"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- ---------------------------------------------------------------------------
-- Behavior Trees
-- ---------------------------------------------------------------------------

--- Pre-switch tree: focused on finding corpses and transcribing roles.
--- CopycatSeek is the primary objective (like AmnesiacSeek for Amnesiac).
--- CopycatSwitchRole fires when the bot decides to switch roles.
--- The Copycat can also fight back and investigate normally.
local preSwitchTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Requests,
    _bh.CopycatSwitchRole,  -- HIGH: switch roles when conditions are met
    _bh.CopycatSeek,        -- HIGH: dedicated corpse-seeking for role transcription
    _bh.InvestigateCorpse,  -- Fallback: standard corpse investigation
    _prior.Restore,
    _bh.Interact,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol,
}

--- Post-switch tree: aggressive combat tree since the Copycat is a solo killer
--- after role switching. Similar to a traitor tree but without coordination.
local postSwitchTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Requests,
    _prior.Grenades,
    _prior.KnifeStalk,
    _prior.Support,
    _bh.InvestigateCorpse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol,
}

-- ---------------------------------------------------------------------------
-- Role Registration
-- ---------------------------------------------------------------------------

local roleDescription = "The Copycat is a solo team role that must eliminate everyone else to win. "
    .. "Your primary objective is to inspect corpses to collect roles into your Copycat Files. "
    .. "Once you have a useful role collected, use your Copycat Files weapon to switch your appearance and abilities. "
    .. "You remain on Team Copycat regardless of which role you copy — other Copycats are your allies. "
    .. "You are a policing and omniscient role: you can always inspect bodies and see MIA players. "
    .. "Strategy: collect roles from corpses first, then switch to a powerful combat role to eliminate threats."

local copycat = TTTBots.RoleData.New("copycat", TEAM_COPYCAT)
copycat:SetDefusesC4(false)
copycat:SetStartsFights(true)
copycat:SetCanCoordinate(false)
copycat:SetUsesSuspicion(false)
copycat:SetTeam(TEAM_COPYCAT)
copycat:SetBTree(preSwitchTree)
copycat:SetKnowsLifeStates(true)
copycat:SetCanHaveRadar(true)
copycat:SetLovesTeammates(true)
copycat:SetAlliedTeams({ [TEAM_COPYCAT] = true, [TEAM_JESTER] = true })
copycat:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(copycat)

-- ---------------------------------------------------------------------------
-- Runtime tree override: use the pre-switch tree while the bot is still in
-- the base Copycat subrole, and switch to the post-switch combat tree once
-- the bot has changed subrole (but remains on TEAM_COPYCAT).
-- Uses the same chain pattern as Amnesiac, Infected, Necromancer, etc.
-- ---------------------------------------------------------------------------
local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor
function TTTBots.Behaviors.GetTreeFor(bot)
    if not IsValid(bot) then return nil end

    -- Only intercept for players on TEAM_COPYCAT with the was_copycat flag
    local isCopycatTeam = bot:GetTeam() == TEAM_COPYCAT
    if not isCopycatTeam then
        return _origGetTreeFor(bot)
    end

    -- If the bot is still in the base Copycat subrole, use the pre-switch tree
    if bot:GetSubRole() == ROLE_COPYCAT then
        return preSwitchTree
    end

    -- The bot has switched subrole but is still on TEAM_COPYCAT — use combat tree
    return postSwitchTree
end

-- ---------------------------------------------------------------------------
-- Cooldown tracking: bots need to know when they can switch roles again.
-- We hook into the same net message the addon uses for cooldown status.
-- For bots we track the cooldown server-side via a simple timestamp.
-- ---------------------------------------------------------------------------

hook.Add("TTTBeginRound", "TTTBots.Copycat.ResetState", function()
    timer.Simple(1, function()
        for _, bot in pairs(TTTBots.Bots) do
            if not IsValid(bot) then continue end
            bot._copycatSwitchTime = nil
            bot._copycatCollectedRoles = nil
        end
    end)
end)

return true
