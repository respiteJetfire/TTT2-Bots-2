--- Haunted role integration for TTT Bots 2
--- The Haunted is an omniscient traitor with a unique passive: when they are killed
--- by another player, that player becomes "haunted" — tracked with a smoke effect.
--- If the haunted player is later killed by anyone else, the Haunted revives.
---
--- Key mechanics (all server-driven via hooks):
---   • isOmniscientRole: knows MIA/life states
---   • On Haunted's death: killer becomes "haunted" (NW smoke + status)
---   • If haunted player dies: Haunted revives at configurable HP
---   • No shop, no credits — pure passive revival mechanic
---
--- Bot behavior:
---   • Standard TraitorLike tree — fights, coordinates, uses traitor actions
---   • Survival is slightly less critical because of the revival mechanic
---   • isOmniscientRole gives radar-level awareness

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_HAUNTED then return false end

local roleDescription = "You are the Haunted, an omniscient traitor. When you are killed by another player, "
    .. "they become 'haunted' — marked with a smoke effect. If your haunted killer is then killed by anyone, "
    .. "you revive with a configurable amount of HP. You have no shop or credits, but you can use traitor "
    .. "buttons. Fight as a normal traitor — your revival mechanic handles itself."

local haunted = TTTBots.RoleBuilder.TraitorLike("haunted", TEAM_TRAITOR)
haunted:SetKnowsLifeStates(true)    -- isOmniscientRole
haunted:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(haunted)

-- ---------------------------------------------------------------------------
-- Awareness hook: when the Haunted gets killed, record the killer for
-- "haunt awareness". The bot will prioritize engaging the haunted killer
-- to bait others into killing them (or just die trying — the revival handles it).
-- ---------------------------------------------------------------------------
hook.Add("TTT2PostPlayerDeath", "TTTBots.haunted.awareness", function(victim, infl, attacker)
    if not TTTBots.Match.IsRoundActive() then return end
    if not IsValid(victim) or not victim:IsPlayer() then return end
    if victim:GetSubRole() ~= ROLE_HAUNTED then return end
    if not IsValid(attacker) or not attacker:IsPlayer() then return end

    -- Mark the attacker as a high-value target in bot memory:
    -- Any bot on TEAM_TRAITOR should know this player is "haunted" and try to kill them
    -- (killing the haunted player revives the Haunted).
    for _, bot in ipairs(player.GetBots()) do
        if not IsValid(bot) then continue end
        if not bot.BotMemory then continue end
        if bot:GetTeam() ~= TEAM_TRAITOR then continue end

        local mem = bot:BotMemory()
        if mem and mem.AddKOSFor then
            mem:AddKOSFor(attacker, "HauntedTarget")
        end
    end
end)

return true
