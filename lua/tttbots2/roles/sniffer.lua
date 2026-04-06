--- Sniffer role integration for TTT Bots 2
--- The Sniffer is a Detective sub-role who receives a Lens (magnifying glass)
--- that reveals footsteps on the ground. Searching a body tags the KILLER with
--- a "blood trail" visible while the Lens is active (within lifetime window).
---
--- Bot strategy:
---   • Plays as a DetectiveLike bot (investigates corpses, uses DNA scanner).
---   • TTTBodyFound hook: when a Sniffer bot finds a body whose killer is
---     flagged (snifferIsKiller), the killer's position is fed into suspicious
---     memory so the bot prioritises hunting that player.
---   • unknownTeam: cannot coordinate with Innocents (public policing role).

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SNIFFER then return false end

local sniffer = TTTBots.RoleBuilder.DetectiveLike("sniffer")
sniffer:SetKOSUnknown(false)
TTTBots.Roles.RegisterRole(sniffer)

-- ---------------------------------------------------------------------------
-- Blood-trail intel: when a Sniffer bot searches a body, check if the addon
-- has flagged the killer with `snifferIsKiller` (set by TTT2PostPlayerDeath).
-- Feed that position into the bot's suspicious memory to guide pursuit.
-- ---------------------------------------------------------------------------
hook.Add("TTTBodyFound", "TTTBots.Sniffer.BloodIntel", function(finder, deadPly)
    if not (IsValid(finder) and finder:IsBot()) then return end
    if finder:GetSubRole() ~= ROLE_SNIFFER then return end
    if not IsValid(deadPly) then return end

    local killer = deadPly.snifferKilled
    if not (IsValid(killer) and killer:IsPlayer() and killer:IsActive()) then return end

    -- The killer has a blood trail — update the bot's suspicious position memory.
    local memory = finder.components and finder.components.memory
    if memory then
        memory:UpdateKnownPositionFor(killer, killer:GetPos())
        memory:AddSuspiciousPosition(killer:GetPos())
    end

    local morality = finder.BotMorality and finder:BotMorality()
    if morality then
        morality:AddSuspicion(killer, "sniffer_blood_trail", 80)
    end

    -- Immediately assign the killer as an attack target at policing priority.
    local PRI = TTTBots.Morality and TTTBots.Morality.PRIORITY
    local pri = PRI and PRI.ROLE_HOSTILITY or 3
    finder:SetAttackTarget(killer, "SNIFFER_BLOOD_TRAIL", pri)

    local chatter = finder:BotChatter()
    if chatter and chatter.On then
        chatter:On("SnifferFoundKiller", { player = killer:Nick(), playerEnt = killer }, false)
    end
end)

print("[TTT Bots 2] Sniffer role integration loaded.")
return true
