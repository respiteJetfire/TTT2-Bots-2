--- Shinigami role integration for TTT Bots 2
--- The Shinigami is a hidden-sync Innocent sub-role with a unique death/revival mechanic.
--- Key mechanics:
---   • TEAM_INNOCENT, unknownTeam = true
---   • disableSync = true: other players see the Shinigami as ROLE_INNOCENT (synced as none)
---   • On death: automatically queues a revival after ttt2_shini_revive_time seconds
---     — respawns with only weapon_ttt_shinigamiknife
---   • Post-revival phase ("SpawnedAsShinigami" NWBool = true):
---     — Can see traitor life states
---     — Takes ttt2_shinigami_health_loss damage per second
---     — Cannot pick up weapons other than the shini knife
---     — Cannot use radio commands
---     — Appears as ROLE_INNOCENT to all; gets traitor intel on radar
---     — Speed multiplied by ttt2_shinigami_speed
---   • The Shinigami can optionally choose respawn position (corpse or spawn)
---
--- Bot behavior:
---   • Pre-death: InnocentLike — blend in as innocent, use suspicion, no coordination
---   • Post-revival: aggressive Stalk against traitors with knowledge of their positions
---     — GetTreeFor checks SpawnedAsShinigami NWBool
---   • Revival and speed changes are fully server-driven; bot benefits automatically

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SHINI then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- Pre-revival: act like an innocent
local innocentTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _prior.Restore,
    _prior.Investigate,
    _bh.Decrowd,
    _prior.Patrol,
}

-- Post-revival: knows traitor positions; hunt them down fast
local revivedTree = {
    _prior.Chatter,
    _prior.FightBack,
    _bh.Stalk,
    _prior.Patrol,
}

local shinigami = TTTBots.RoleData.New("shini", TEAM_INNOCENT)
shinigami:SetDefusesC4(false)
shinigami:SetPlantsC4(false)
shinigami:SetTeam(TEAM_INNOCENT)
shinigami:SetBTree(innocentTree)
shinigami:SetCanCoordinate(false)
shinigami:SetCanHaveRadar(false)
shinigami:SetStartsFights(true)
shinigami:SetUsesSuspicion(true)    -- unknownTeam
shinigami:SetCanSnipe(false)
shinigami:SetCanHide(false)
shinigami:SetKnowsLifeStates(false)
shinigami:SetLovesTeammates(false)
shinigami:SetAlliedTeams({ [TEAM_INNOCENT] = true })

-- Swap to aggressive traitor-hunter tree after revival
shinigami:SetGetTreeFor(function(bot)
    if IsValid(bot) and bot:GetNWBool("SpawnedAsShinigami", false) then
        return revivedTree
    end
    return innocentTree
end)

shinigami:SetRoleDescription(
    "You are the Shinigami — an Innocent who respawns after death with a knife and traitor intel. "
    .. "Before death: act like an innocent and stay under the radar. "
    .. "After revival: you know where traitors are. Hunt them down with your shini-knife — "
    .. "but you lose HP every second, so act fast."
)
TTTBots.Roles.RegisterRole(shinigami)

-- ---------------------------------------------------------------------------
-- Suspicion hook: Pre-revival Shinigami appears as innocent to all bots
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.shinigami.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    if target:GetSubRole() ~= ROLE_SHINI then return end
    if not target:GetNWBool("SpawnedAsShinigami", false) then
        -- Appears completely innocent before revival
        return mult * 0.2
    end
end)

return true
