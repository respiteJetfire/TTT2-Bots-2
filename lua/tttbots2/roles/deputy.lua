--- Deputy role for TTT2, a Detective role which has a Sheriff Master which they must protect at all costs!

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DEPUTY then return false end

local deputy = TTTBots.RoleData.New("deputy")

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
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

deputy:SetDefusesC4(true)
deputy:SetCanHaveRadar(true)
deputy:SetTeam(TEAM_INNOCENT)
deputy:SetKOSUnknown(false)
deputy:SetAlliedRoles('detective','sheriff','sniffer','priest','survivalist','innocent')
deputy:SetBTree(bTree)
deputy:SetUsesSuspicion(true)
deputy:SetAppearsPolice(true)
TTTBots.Roles.RegisterRole(deputy)

-- Sidekick help master when shooting a victim
hook.Add("TTTBotsOnWitnessFireBullets", "TTTBotsOnWitnessFireBullets", function(witness, attacker, data, angleDiff)
    local attackerRole = attacker:GetRoleStringRaw()
    local witnessRole = witness:GetRoleStringRaw()

    if witnessRole == 'deputy' and attackerRole == 'sheriff' then
        local eyeTracePos = attacker:GetEyeTrace().HitPos
        if not IsValid(eyeTracePos) then return end
        local target = TTTBots.Lib.GetClosest(TTTBots.Roles.GetNonAllies(witness), eyeTracePos)
        if not target then return end
        witness:SetAttackTarget(target)
    end
end)

-- Sidekick help its master when he's attacked
hook.Add("TTTBotsOnWitnessHurt", "TTTBotsOnWitnessHurt",
    function(witness, victim, attacker, healthRemaining, damageTaken)
        if not IsValid(attacker) then return end

        local victimRole = victim:GetRoleStringRaw()
        local witnessRole = witness:GetRoleStringRaw()

        if witnessRole == 'deputy' and victimRole == 'sheriff' then
            witness:SetAttackTarget(attacker)
        end
    end)


return true
