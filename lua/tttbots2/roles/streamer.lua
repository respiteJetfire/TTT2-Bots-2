--- Streamer & Simp role integration for TTT Bots 2
--- This addon introduces two Streamer-team roles on TEAM_STREAMER:
---   • ROLE_STREAMER — starts as a solo Streamer; converts donors to Simps
---   • ROLE_SIMP     — converted from a player who donates a weapon to the Streamer
---
--- Key mechanics (Streamer):
---   • TEAM_STREAMER — custom team; isOmniscientRole; no shop
---   • When a player drops a weapon that the Streamer picks up, that player
---     becomes a Simp (ROLE_SIMP, TEAM_STREAMER) — server-driven via WeaponEquip hook
---   • The Streamer must survive and grow their audience (convert Simps) to win
---
--- Key mechanics (Simp):
---   • Starts as any role; converted mid-round by picking up a Streamer weapon
---   • notSelectable = true: cannot be assigned at round start
---   • isOmniscientRole: full awareness of team
---   • Coordinates with the Streamer
---
--- Bot behavior:
---   • Streamer: TraitorLike with omniscient awareness; no sniping
---     — Wanders and picks up weapons from fallen players to convert innocents
---   • Simp: TraitorLike after conversion; coordinates with Streamer
---   • Both: TEAM_STREAMER; KOS non-Streamer-team

if not TTTBots.Lib.IsTTT2() then return false end

TEAM_STREAMER = TEAM_STREAMER or "streamer"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- ============================================================
-- Streamer
-- ============================================================
if ROLE_STREAM then
    local streamerTree = {
        _prior.Chatter,
        _prior.FightBack,
        _prior.Requests,
        _prior.Support,
        _prior.Grenades,
        _prior.Restore,
        _bh.Stalk,
        _bh.Interact,     -- Pick up donated weapons to convert Simps
        _prior.Investigate,
        _bh.Decrowd,
        _prior.Patrol,
    }

    local streamer = TTTBots.RoleData.New("stream", TEAM_STREAMER)
    streamer:SetDefusesC4(false)
    streamer:SetPlantsC4(false)
    streamer:SetTeam(TEAM_STREAMER)
    streamer:SetBTree(streamerTree)
    streamer:SetCanCoordinate(true)
    streamer:SetCanHaveRadar(true)     -- isOmniscientRole
    streamer:SetStartsFights(true)
    streamer:SetUsesSuspicion(false)
    streamer:SetCanSnipe(false)
    streamer:SetCanHide(false)
    streamer:SetKnowsLifeStates(true)  -- isOmniscientRole
    streamer:SetKOSAll(false)          -- Want to convert, not just kill
    streamer:SetKOSedByAll(false)
    streamer:SetLovesTeammates(true)
    streamer:SetAlliedTeams({ [TEAM_STREAMER] = true })
    streamer:SetRoleDescription(
        "You are the Streamer. When players drop weapons you pick up, they become Simps on your team. "
        .. "Build your team by collecting dropped weapons. Fight alongside your Simps to win. "
        .. "You are omniscient and have no shop."
    )
    TTTBots.Roles.RegisterRole(streamer)
end

-- ============================================================
-- Simp (converted mid-round by the Streamer)
-- ============================================================
if ROLE_SIMP then
    local simpTree = {
        _prior.Chatter,
        _prior.FightBack,
        _prior.Requests,
        _prior.Support,
        _bh.Stalk,
        _prior.Patrol,
    }

    local simp = TTTBots.RoleData.New("simp", TEAM_STREAMER)
    simp:SetDefusesC4(false)
    simp:SetPlantsC4(false)
    simp:SetTeam(TEAM_STREAMER)
    simp:SetBTree(simpTree)
    simp:SetCanCoordinate(true)
    simp:SetCanHaveRadar(true)     -- isOmniscientRole
    simp:SetStartsFights(true)
    simp:SetUsesSuspicion(false)
    simp:SetCanSnipe(false)
    simp:SetCanHide(false)
    simp:SetKnowsLifeStates(true)  -- isOmniscientRole
    simp:SetLovesTeammates(true)
    simp:SetAlliedTeams({ [TEAM_STREAMER] = true })
    simp:SetRoleDescription(
        "You are a Simp — you donated a weapon to the Streamer and joined their team. "
        .. "Fight alongside your Streamer to win. Protect the Streamer at all costs."
    )
    TTTBots.Roles.RegisterRole(simp)
end

return true
