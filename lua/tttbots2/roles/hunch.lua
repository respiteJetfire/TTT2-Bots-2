--- Hunch role integration for TTT Bots 2
--- The Hunch is a detective subrole with an "unknown team" mechanic and a
--- passive "death vision" item (item_ttt_hunchvision): when a player dies nearby,
--- the Hunch briefly sees a camera replay near the corpse.
---
--- Key mechanics:
---   • Based on ROLE_DETECTIVE (detective shop access via shopFallback)
---   • isPolicingRole / isPublicRole
---   • unknownTeam: true (doesn't reveal team affiliations to others)
---   • Passive item: item_ttt_hunchvision — server-driven, no bot action needed
---
--- Bot behavior:
---   • DetectiveLike builder — investigates corpses, uses DNA scanner
---   • PlayerDeath hook: feed death positions into suspicious memory
---     (simulates the "death vision" giving location intelligence)
---   • unknownTeam awareness: uses suspicion system
---   • No special shop items to manage — vision is automatic

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_HUNCH then return false end

local roleDescription = "You are the Hunch, a detective subrole with death vision. "
    .. "When a player dies within range, your hunch vision item gives you a brief camera "
    .. "near their corpse — revealing the scene of death. Use this passive intelligence "
    .. "to identify suspects and guide your team. You have the detective shop and one credit."

local hunch = TTTBots.RoleBuilder.DetectiveLike("hunch")
hunch:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(hunch)

-- ---------------------------------------------------------------------------
-- Death-vision simulation: when any player dies, feed the position into
-- nearby Hunch bots' suspicious memory. This simulates the vision item.
-- ---------------------------------------------------------------------------
hook.Add("TTT2PostPlayerDeath", "TTTBots.hunch.vision", function(victim, infl, attacker)
    if not TTTBots.Match.IsRoundActive() then return end
    if not IsValid(victim) or not victim:IsPlayer() then return end
    if not victim.GetRagdollEntity or not IsValid(victim:GetRagdollEntity()) then return end

    local deathPos = victim:GetPos()
    local minDist = GetConVarNumber("ttt_hunch_vision_distance_minimum") or 500

    for _, bot in ipairs(player.GetBots()) do
        if not IsValid(bot) then continue end
        if bot:GetSubRole() ~= ROLE_HUNCH then continue end
        if not bot:Alive() then continue end

        -- Only trigger if bot is within range (mirrors the item's distance check)
        local dist = bot:GetPos():Distance(deathPos)
        if dist > minDist then continue end

        -- Feed death position as a suspicious position
        if bot.BotMemory then
            local mem = bot:BotMemory()
            if mem then
                if mem.AddSuspiciousPosition then
                    mem:AddSuspiciousPosition(deathPos)
                end
                if IsValid(attacker) and attacker:IsPlayer() and mem.UpdateKnownPositionFor then
                    mem:UpdateKnownPositionFor(attacker)
                end
            end
        end
    end
end)

return true
