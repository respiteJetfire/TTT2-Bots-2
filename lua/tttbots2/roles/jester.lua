--- Jester behaviour for TTT2, a role which is evil and wins by being killed by a player.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_JESTER then return false end

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_TRAITOR] = true,
    [TEAM_JACKAL] = true,
    [TEAM_RESTLESS] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _prior.Restore,
    _bh.Stalk,
    _prior.Minge,
    _prior.Investigate,
    _prior.Patrol
}

local jester = TTTBots.RoleData.New("jester", TEAM_JESTER)
jester:SetDefusesC4(false)
jester:SetStartsFights(true)
jester:SetNeutralOverride(true)
jester:SetTeam(TEAM_JESTER)
jester:SetBTree(bTree)
jester:SetAlliedTeams(allyTeams)
jester:SetNeutralOverride(true)
TTTBots.Roles.RegisterRole(jester)

-- TTTBotsModifySuspicion hook
hook.Add("TTTBotsModifySuspicion", "TTTBots.jester.sus", function(bot, target, reason, mult)
    local role = target:GetRoleStringRaw()
    if role == 'jester' then
        if TTTBots.Lib.GetConVarBool("cheat_know_jester") then
            return mult * 0.2
        end
    end
end)

return true
