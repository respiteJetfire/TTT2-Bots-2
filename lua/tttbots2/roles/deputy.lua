--- Deputy role for TTT2, a Detective role which has a Sheriff Master which they must protect at all costs!

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DEPUTY then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _prior.Convert,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _bh.FollowMaster,
    _prior.Minge,
    _prior.Investigate,
    _bh.Decrowd,
    _prior.Patrol
}

local roleDescription = "The Deputy is a special detective role. When shot by a Sheriff, you become a deputy. The deputy is shown as a detective to all players, and is the ally of the Sheriff. If the Sheriff dies, the Deputy dies; so Co-operate and protect your Sheriff with your life! You have access to the Detective shop and as such can assist in finding the Traitors."

local deputy = TTTBots.RoleBuilder.DetectiveLike("deputy")
deputy:SetKOSUnknown(false)
deputy:SetAlliedRoles({ deputy = true, detective = true, sheriff = true, sniffer = true, priest = true, survivalist = true, innocent = true })
deputy:SetBTree(bTree)
deputy:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(deputy)

-- Deputy help sheriff when shooting a target
hook.Add("TTTBotsOnWitnessFireBullets", "TTTBotsOnWitnessFireBullets_deputy", function(witness, attacker, data, angleDiff)
    local attackerRole = attacker:GetRoleStringRaw()
    local witnessRole = witness:GetRoleStringRaw()

    if witnessRole == 'deputy' and attackerRole == 'sheriff' then
        local eyeTracePos = attacker:GetEyeTrace().HitPos
        if not IsValid(eyeTracePos) then return end
        local target = TTTBots.Lib.GetClosest(TTTBots.Roles.GetNonAllies(witness), eyeTracePos)
        if not target then return end
        witness:SetAttackTarget(target, "ROLE_DEFEND_ALLY", 4)
    end
end)

-- Deputy help its sheriff when he's attacked
hook.Add("TTTBotsOnWitnessHurt", "TTTBotsOnWitnessHurt_deputy",
    function(witness, victim, attacker, healthRemaining, damageTaken)
        if not IsValid(attacker) then return end

        local victimRole = victim:GetRoleStringRaw()
        local witnessRole = witness:GetRoleStringRaw()

        if witnessRole == 'deputy' and victimRole == 'sheriff' then
            witness:SetAttackTarget(attacker, "ROLE_DEFEND_ALLY", 4)
        end
    end)

return true
