if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_CURSED then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- Promote SwapDeagle and SwapRole to the top of the Cursed BTree so the bot
-- actively pursues role swaps rather than burying them inside _prior.Convert
-- alongside unrelated behaviors (CreateDefector, CreateMedic, etc.).
local bTree = {
    _prior.Requests,
    _bh.SwapDeagle,
    _bh.SwapRole,
    _bh.Interact,
    _prior.Patrol,
}

local cursed = TTTBots.RoleData.New("cursed", TEAM_NONE)
cursed:SetDefusesC4(false)
cursed:SetCanCoordinate(false)
cursed:SetCanHaveRadar(true)
cursed:SetUsesSuspicion(false)
cursed:SetTeam(TEAM_NONE)
cursed:SetKOSedByAll(false)
cursed:SetBTree(bTree)
cursed:SetLovesTeammates(true)
-- Cursed is a TEAM_NONE role that cannot deal damage; other bots should not
-- reflexively attack them on sight.
cursed:SetNeutralOverride(true)
TTTBots.Roles.RegisterRole(cursed)

-- React to mid-round role changes so bots cleanly transition into and out of the
-- Cursed role without carrying stale suspicion or attack-target state.
-- TTT2 fires "TTT2UpdatedSubrole" with (ply, newSubrole, oldSubrole).
hook.Add("TTT2UpdatedSubrole", "TTTBots.Cursed.OnRoleChange", function(ply, newSubrole, oldSubrole)
    if not (ply and IsValid(ply) and ply:IsBot()) then return end

    -- The hook fires after the subrole has already been updated, so reading
    -- ply:GetSubRole() yields the new role. oldSubrole is the previous role.
    local currentRole = ply:GetSubRole()

    -- Bot just received the Cursed role.
    if currentRole == ROLE_CURSED then
        ply:SetAttackTarget(nil)
        local morality = ply:BotMorality()
        if morality then morality.suspicions = {} end
        local chatter = ply:BotChatter()
        if chatter then chatter:On("CursedRoleReceived") end
    end

    -- Bot just left the Cursed role (oldSubrole available when hook passes 3 args).
    if oldSubrole == ROLE_CURSED and currentRole ~= ROLE_CURSED then
        ply:SetAttackTarget(nil)
        -- The behavior tree updates automatically on the next tick via GetTreeFor().
    end
end)

return true