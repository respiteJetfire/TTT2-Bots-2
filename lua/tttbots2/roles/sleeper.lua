--- Sleeper role integration for TTT Bots 2
--- The Sleeper is an innocent sub-role on TEAM_INNOCENT with unknownTeam = true
--- and disableSync = true (doesn't even know their own role initially).
--- When the LAST living traitor dies, the Sleeper activates: they are converted
--- to TEAM_TRAITOR, gain omniscience, and learn who their allies are.
---
--- Key mechanics:
---   • Pre-activation: appears and behaves as Innocent (disableSync hides true role)
---   • Post-activation: becomes TEAM_TRAITOR with full omniscience
---   • Cannot earn credits, no shop while innocent-phase
---   • Has traitor button access (shopFallback = SHOP_FALLBACK_TRAITOR)
---
--- Bot behavior:
---   • Pre-activation: InnocentLike — fully acts as an innocent (doesn't even know it's a Sleeper)
---   • Post-activation: switches to traitor tree (KOS all remaining players)
---   • TTT2SleeperConvertNetMsg triggers the tree swap

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SLEEPER then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- Phase 1: Act as a completely normal innocent
local bTreeInnocent = {
    _prior.Chatter,
    _prior.Support,
    _prior.FightBack,
    _prior.Requests,
    _bh.Defib,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol,
}

-- Phase 2: Last traitor threat — Sleeper awakens and hunts survivors
local bTreeTraitor = {
    _prior.Chatter,
    _prior.FightBack,
    _bh.Stalk,              -- Hunt remaining players (they are the last threat)
    _prior.Requests,
    _prior.Restore,
    _prior.Patrol,
}

local roleDescription = "You are the Sleeper, an innocent sub-role that doesn't know its own identity. "
    .. "You don't know you are the Sleeper. Act as a normal innocent and survive. "
    .. "When the last traitor dies, you awaken: you are converted to the traitor team "
    .. "with full omniscience. Hunt the remaining players to prevent an innocent victory."

local sleeper = TTTBots.RoleData.New("sleeper", TEAM_INNOCENT)
sleeper:SetDefusesC4(false)
sleeper:SetTeam(TEAM_INNOCENT)
sleeper:SetBTree(bTreeInnocent)         -- Default pre-activation tree
sleeper:SetCanCoordinate(false)
sleeper:SetCanHaveRadar(false)
sleeper:SetStartsFights(false)          -- Pre-activation: innocent
sleeper:SetUsesSuspicion(true)          -- unknownTeam — uses suspicion
sleeper:SetKOSUnknown(false)
sleeper:SetKOSAll(false)
sleeper:SetKOSedByAll(false)
sleeper:SetLovesTeammates(false)
sleeper:SetKnowsLifeStates(false)
sleeper:SetAlliedTeams({ [TEAM_INNOCENT] = true })
sleeper:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(sleeper)

-- ---------------------------------------------------------------------------
-- Track awakened state per bot
-- ---------------------------------------------------------------------------
local awokenSleepers = {}

-- ---------------------------------------------------------------------------
-- Dynamic tree swap: switch to traitor tree after the Sleeper converts
-- ---------------------------------------------------------------------------
local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor
function TTTBots.Behaviors.GetTreeFor(bot)
    if not IsValid(bot) then return nil end

    local role = TTTBots.Roles.GetRoleFor(bot)
    if role and role:GetName() == "sleeper" then
        if awokenSleepers[bot] then
            return bTreeTraitor
        end
        return bTreeInnocent
    end

    return _origGetTreeFor(bot)
end

-- ---------------------------------------------------------------------------
-- Hook: when last traitor dies and Sleeper converts, update bot state
-- ---------------------------------------------------------------------------
hook.Add("TTT2PostPlayerDeath", "TTTBots.sleeper.watchConvert", function(victim, inflictor, attacker)
    -- Check if all traitors are now dead and any Sleeper bot should activate
    timer.Simple(2.5, function()   -- Small delay matching the server's 2s ConvertToSleeper timer
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then continue end
            if ply:GetSubRole() ~= ROLE_SLEEPER then continue end
            if not (ply.IsBot and ply:IsBot()) then continue end
            -- If the Sleeper has been converted to traitor team, mark as awoken
            if ply:GetTeam() == TEAM_TRAITOR then
                awokenSleepers[ply] = true
                -- Update bot's combat settings
                local roleData = TTTBots.Roles.GetRoleFor(ply)
                if roleData then
                    roleData:SetStartsFights(true)
                    roleData:SetKnowsLifeStates(true)
                    roleData:SetKOSAll(false)
                    roleData:SetUsesSuspicion(false)
                end
            end
        end
    end)
end)

-- Reset on round start
hook.Add("TTTBeginRound", "TTTBots.sleeper.reset", function()
    awokenSleepers = {}
end)

return true
