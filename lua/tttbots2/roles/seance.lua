--- Seance role integration for TTT Bots 2
--- The Seance is a passive Innocent information role:
---   • When a player dies, the Seance is notified (after ~30s delay) of
---     the death position and the running total of dead players.
---   • Client-side sees yellow orbs at spectator positions.
---   • No shop, no weapons — purely a passive intel-gathering role.
---   • unknownTeam = true.
---
--- Bot strategy:
---   • Play as a standard Innocent — investigate, patrol, and fight back.
---   • Use death-position intel to guide investigation targets (navigate toward
---     areas where players recently died).
---   • The delay (30s default) means intel is stale; treat it as "area of interest"
---     rather than live position.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SEANCE then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription =
    "You are the Seance, an innocent-team information role. "
    .. "When players die, you are notified of their last known position after a short delay. "
    .. "Use this positional intel to guide your investigation — head to areas where "
    .. "deaths occurred, as the killer may still be nearby or evidence may remain. "
    .. "You have no shop or special weapons. Survive and help innocents win by "
    .. "locating suspicious areas and uncovering traitors."

local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol,
}

local seance = TTTBots.RoleData.New("seance")
seance:SetDefusesC4(true)
seance:SetPlantsC4(false)
seance:SetTeam(TEAM_INNOCENT)
seance:SetBTree(bTree)
seance:SetCanCoordinate(false)     -- unknownTeam = true
seance:SetCanHaveRadar(false)      -- SHOP_DISABLED
seance:SetStartsFights(false)
seance:SetUsesSuspicion(true)
seance:SetCanSnipe(true)
seance:SetCanHide(false)
seance:SetKOSUnknown(false)
seance:SetLovesTeammates(true)
seance:SetAlliedTeams({ [TEAM_INNOCENT] = true })
seance:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(seance)

-- ---------------------------------------------------------------------------
-- Death position intel: when the addon notifies the Seance of a death
-- position, we feed it into the bot's memory / investigation queue.
-- The addon sends a net message "SeanDeathNotif" with the position.
-- We hook a server-side equivalent or use a timer check on NW data.
-- ---------------------------------------------------------------------------

hook.Add("PlayerDeath", "TTTBots.Seance.DeathIntel", function(victim, inflictor, attacker)
    if not TTTBots.Match.IsRoundActive() then return end
    if not IsValid(victim) then return end

    local deathPos = victim:GetPos()
    local notifyDelay = GetConVar("ttt2_seance_notification_time")
    local delay = notifyDelay and notifyDelay:GetInt() or 30

    -- Schedule notification for Seance bots after the addon's delay
    timer.Simple(delay, function()
        if not TTTBots.Match.IsRoundActive() then return end

        for _, bot in ipairs(TTTBots.Bots or {}) do
            if not (IsValid(bot) and bot:IsBot()) then continue end
            if not ROLE_SEANCE then continue end
            if bot:GetSubRole() ~= ROLE_SEANCE then continue end

            -- Feed the death position into the bot's memory as a suspicious area
            local memory = bot.components and bot.components.memory
            if memory then
                if memory.AddSuspiciousPosition then
                    memory:AddSuspiciousPosition(deathPos)
                end
                -- Also update known position for the victim (even though dead)
                -- so the Investigate behavior may route toward the corpse.
                if memory.UpdateKnownPositionFor then
                    memory:UpdateKnownPositionFor(victim, deathPos)
                end
            end
        end
    end)
end)

print("[TTT Bots 2] Seance role integration loaded.")
return true
