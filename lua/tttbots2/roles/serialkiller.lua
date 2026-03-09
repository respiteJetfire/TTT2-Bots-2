if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SERIALKILLER then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local allyTeams = {
    [TEAM_SERIALKILLER] = true,
    [TEAM_JESTER] = true,
}


local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _bh.Stalk,
    _prior.Restore,
    _prior.Investigate,
    _prior.Minge,
    _prior.Patrol
}

local serialkiller = TTTBots.RoleData.New("serialkiller", TEAM_SERIALKILLER)
serialkiller:SetDefusesC4(true)
serialkiller:SetStartsFights(true)
serialkiller:SetCanCoordinate(false)
serialkiller:SetTeam(TEAM_SERIALKILLER)
serialkiller:SetBTree(bTree)
serialkiller:SetKnowsLifeStates(true)
serialkiller:SetKnowsAllPositions(true)
serialkiller:SetAlliedTeams(allyTeams)
serialkiller:SetLovesTeammates(false)
serialkiller:SetEnemyTeams({[TEAM_DOOMSLAYER] = true})
serialkiller:SetIsFollower(false)
serialkiller:SetUsesSuspicion(false)
TTTBots.Roles.RegisterRole(serialkiller)

hook.Add("TTT2UpdatedSubrole", "TTTBots.SerialKiller.RoleStateCleanup", function(ply, oldRole, newRole)
    if not IsValid(ply) or not ply:IsBot() then return end

    if newRole == ROLE_SERIALKILLER then
        -- Entering serial killer role: reset state for clean slate
        ply.attackTarget = nil
        ply.StalkTarget = nil
        local morality = ply.components and ply.components.morality
        if morality then
            morality.suspicions = {}
        end
        local chatter = ply:BotChatter()
        if chatter then
            chatter:On("SerialKillerRoleReceived", {}, false, math.random(1, 3))
        end
    elseif oldRole == ROLE_SERIALKILLER then
        -- Leaving serial killer role: clear hunting state
        ply.attackTarget = nil
        ply.StalkTarget = nil
    end
end)

return true
