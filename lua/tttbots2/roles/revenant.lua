--- Revenant behaviour for TTT2, a role which is evil and wins by killing all non-allied players
--- but can also convert someone to their side using the sidekick deagle

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_REVENANT then return false end

TEAM_JESTER = TEAM_JESTER or 'jesters'

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_REVENANT] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _prior.Convert,
    _prior.Restore,
    _prior.Minge,
    _bh.Stalk,
    _prior.Investigate,
    _prior.Patrol
}

local revenant = TTTBots.RoleData.New("revenant", TEAM_REVENANT)
revenant:SetDefusesC4(false)
revenant:SetCanCoordinate(true)
revenant:SetCanHaveRadar(true)
revenant:SetStartsFights(true)
revenant:SetUsesSuspicion(false)
revenant:SetTeam(TEAM_REVENANT)
revenant:SetBTree(bTree)
revenant:SetAlliedTeams(allyTeams)
revenant:SetLovesTeammates(false)
TTTBots.Roles.RegisterRole(revenant)

-- Ensure revenant_state is initialized for bots before TTT2SpecialRoleSyncing fires.
-- Without this, shared.lua compares nil < 2 and errors.
hook.Add("TTTBeginRound", "TTTBots.revenant.InitState", function()
    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not IsValid(bot) then continue end
        if bot:GetSubRole() == ROLE_REVENANT then
            if bot.revenant_state == nil then
                bot.revenant_state = 1
                bot.isRevenantWorldspawn = false
            end
        end
    end
end)

return true
