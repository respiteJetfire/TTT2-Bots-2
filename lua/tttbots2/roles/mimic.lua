--- Mimic role integration for TTT Bots 2
--- The Mimic is a neutral role that can copy the role of another player by
--- walking up to them and looking at them (the addon's melee/touch mechanic).
--- After copying, the Mimic behaves as the copied role for the rest of the round.
---
--- Bot strategy:
---   • Pre-copy: completely non-aggressive — wanders and tries to approach
---     players to copy them. CopyRole behavior drives navigation.
---   • CopyRole targets rare roles (lower roleCount = higher value copy);
---     avoids copying slave, deputy, or sidekick (inherently broken sub-roles).
---   • Post-copy: TTT2UpdateSubrole hook hot-swaps the behaviour tree to the
---     copied role's RoleData tree (same mechanism as Drunk reveal).
---   • Suspicion hook: Mimic appears 0.5× suspicious to other innocents pre-copy.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_MIMIC then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,   -- Don't die before copying
    _prior.SelfDefense,
    _prior.Support,
    _prior.Requests,
    _prior.Restore,
    _bh.CopyRole,       -- High-priority: actively approach and copy a target
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

local roleDescription =
    "The Mimic is a neutral that copies another player's role by approaching them. "
    .. "Bots will actively seek out rare roles to copy and immediately adopt the "
    .. "new role's behaviour tree after a successful copy."

local mimic = TTTBots.RoleData.New("mimic", TEAM_MIMIC)
mimic:SetDefusesC4(false)
mimic:SetStartsFights(false)
mimic:SetTeam(TEAM_MIMIC)
mimic:SetBTree(bTree)
mimic:SetKOSUnknown(false)
mimic:SetAlliedTeams({})
mimic:SetNeutralOverride(true)
mimic:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(mimic)

-- ---------------------------------------------------------------------------
-- Post-copy tree handoff: when CopyRole succeeds (TTT2UpdateSubrole fires),
-- hot-swap the bot's active behaviour tree to match the copied role.
-- ---------------------------------------------------------------------------
hook.Add("TTT2UpdateSubrole", "TTTBots.Mimic.PostCopyHandoff",
    function(ply, oldRole, newRole)
        if not (IsValid(ply) and ply:IsBot()) then return end
        if oldRole ~= ROLE_MIMIC then return end
        if newRole == ROLE_MIMIC then return end

        timer.Simple(0.2, function()
            if not (IsValid(ply) and ply:IsActive()) then return end

            local roleStr = ply:GetRoleStringRaw()
            local revealedData = TTTBots.Roles.GetRoleData(roleStr)

            if revealedData then
                local newTree = revealedData:GetBTree()
                if newTree then
                    local loco = ply.BotLocomotor and ply:BotLocomotor()
                    if loco and loco.SetBTree then
                        loco:SetBTree(newTree)
                    end
                end

                local startsFights = revealedData:GetStartsFights()
                local usesSusp    = revealedData:GetUsesSuspicion()
                local morality = ply.BotMorality and ply:BotMorality()
                if morality then
                    if startsFights ~= nil then morality:SetStartsFights(startsFights) end
                    if usesSusp    ~= nil then morality:SetUsesSuspicion(usesSusp)    end
                end
            end

            local chatter = ply:BotChatter()
            if chatter and chatter.On then
                chatter:On("MimicCopied", { player = ply:Nick() }, false)
            end
        end)
    end)

-- ---------------------------------------------------------------------------
-- Suspicion modifier: Mimic appears innocent-like until they copy a role.
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.mimic.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    if target:GetSubRole() ~= ROLE_MIMIC then return end
    return mult * 0.5  -- Mimic blends in as innocent
end)

print("[TTT Bots 2] Mimic role integration loaded.")
return true