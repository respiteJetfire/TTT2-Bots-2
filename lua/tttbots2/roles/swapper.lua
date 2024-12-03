if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SWAPPER then return false end
if not ROLE_JESTER then return false end

local allyTeams = {
    [TEAM_JESTER] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.Requests,
    _prior.Restore,
    _bh.Stalk,
    _prior.Minge,
    _prior.Investigate,
    _prior.Patrol
}

local swapper = TTTBots.RoleData.New("swapper", TEAM_JESTER)
swapper:SetDefusesC4(false)
swapper:SetStartsFights(true)
swapper:SetKOSUnknown(false)
swapper:SetTeam(TEAM_JESTER)
swapper:SetBTree(bTree)
swapper:SetAlliedTeams(allyTeams)
TTTBots.Roles.RegisterRole(swapper)

-- TTTBotsModifySuspicion hook
hook.Add("TTTBotsModifySuspicion", "TTTBots.swapper.sus", function(bot, target, reason, mult)
    local role = target:GetRoleStringRaw()
    if role == 'swapper' then
        if TTTBots.Lib.GetConVarBool("cheat_know_swapper") then
            return mult * 0.3
        end
    end
end)

return true
