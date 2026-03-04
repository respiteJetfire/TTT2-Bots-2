if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_PRIEST then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _bh.CreateSidekick,
    _prior.Restore,
    _bh.Stalk,
    _prior.Minge,
    _prior.Investigate,
    _prior.Patrol
}

local priest = TTTBots.RoleBuilder.DetectiveLike("priest")
priest:SetCanHaveRadar(false)
priest:SetAutoSwitch(true)
priest:SetBTree(bTree)
TTTBots.Roles.RegisterRole(priest)

return true
