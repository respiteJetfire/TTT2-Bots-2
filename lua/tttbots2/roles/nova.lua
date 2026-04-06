--- Nova role integration for TTT Bots 2
--- The Nova is an innocent subrole with a hidden ticking doom: after a random
--- delay (configured by ttt_nova_min/max_explode_time), the Nova dies and
--- explodes, dealing massive area damage to nearby players.
---
--- Key mechanics (all server-driven):
---   • unknownTeam: true — not publicly revealed
---   • On death: large env_explosion centered on corpse; corpse is removed
---   • No shop, no credits
---   • Timer is started at GiveRoleLoadout and removed on death
---
--- Bot behavior:
---   • InnocentLike base — fights normally, uses suspicion
---   • unknownTeam awareness
---   • As the timer approaches expiry, bot should seek isolated positions
---     (avoid friendly fire) — simulated via urgency-based behavior
---   • No special actions needed: explosion is automatic

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_NOVA then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "You are the Nova, an innocent with a hidden detonation timer. "
    .. "After a random delay, you will spontaneously die and explode — dealing massive damage "
    .. "in a large radius. Play as a normal innocent but be aware of your timer. "
    .. "If you are going to explode soon, try to position yourself near enemies, not allies."

-- Standard innocent tree — explosion is handled server-side automatically
local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Restore,
    _bh.Interact,
    _bh.InvestigateCorpse,
    _prior.Investigate,
    _bh.Decrowd,
    _prior.Patrol,
}

local nova = TTTBots.RoleData.New("nova", TEAM_INNOCENT)
nova:SetDefusesC4(true)
nova:SetPlantsC4(false)
nova:SetTeam(TEAM_INNOCENT)
nova:SetBTree(bTree)
nova:SetCanCoordinate(false)        -- unknownTeam: no coordination
nova:SetCanHaveRadar(false)
nova:SetStartsFights(false)
nova:SetUsesSuspicion(true)         -- unknownTeam awareness
nova:SetKOSUnknown(false)
nova:SetKOSAll(false)
nova:SetKOSedByAll(false)
nova:SetLovesTeammates(true)
nova:SetAlliedTeams({ [TEAM_INNOCENT] = true })
nova:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(nova)

-- ---------------------------------------------------------------------------
-- Timer urgency: when the Nova bot is close to exploding, it should move
-- away from allies and toward enemies to maximise the explosion impact.
-- We use the TTTPlayerSpeedModifier-equivalent: watch the server timer
-- and feed a suspicious position update toward the nearest enemy.
-- ---------------------------------------------------------------------------
hook.Add("Think", "TTTBots.nova.urgency", function()
    if not TTTBots.Match.IsRoundActive() then return end

    for _, bot in ipairs(player.GetBots()) do
        if not IsValid(bot) then continue end
        if bot:GetSubRole() ~= ROLE_NOVA then continue end
        if not bot:Alive() then continue end

        -- Check if the nova explode timer exists and is almost done
        local timerName = "nova-kill-explode" .. (bot.SteamID64 and bot:SteamID64() or "")
        if not timer.Exists(timerName) then continue end

        local timeLeft = timer.TimeLeft(timerName)
        if timeLeft == nil then continue end

        -- If less than 10 seconds remain, attempt to move toward enemies
        if timeLeft < 10 then
            local mem = bot.BotMemory and bot:BotMemory()
            if not mem then continue end

            -- Find nearest non-innocent player to walk toward (maximize blast radius)
            for _, target in ipairs(player.GetAll()) do
                if not IsValid(target) then continue end
                if target == bot then continue end
                if not target:Alive() then continue end
                if target:GetTeam() == TEAM_INNOCENT then continue end

                if mem.AddSuspiciousPosition then
                    mem:AddSuspiciousPosition(target:GetPos())
                end
                break
            end
        end
    end
end)

return true
