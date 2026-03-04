if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_PIRATE then return false end

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_PIRATE] = true,
}

local allyRoles = {
    pirate_captain = true
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
    _bh.FollowMaster,
    _bh.Interact
}

local pirate = TTTBots.RoleData.New("pirate", TEAM_PIRATE)
pirate:SetDefusesC4(false)
pirate:SetCanCoordinate(true)
pirate:SetCanHaveRadar(true)
pirate:SetStartsFights(true)
pirate:SetUsesSuspicion(false)
pirate:SetTeam(TEAM_PIRATE)
pirate:SetBTree(bTree)
pirate:SetAlliedTeams(allyTeams)
pirate:SetAlliedRoles(allyRoles)
pirate:SetLovesTeammates(true)
TTTBots.Roles.RegisterRole(pirate)

-- Pirate follows captain direction when shooting
hook.Add("TTTBotsOnWitnessFireBullets", "TTTBotsOnWitnessFireBullets_pirate", function(witness, attacker, data, angleDiff)
    local attackerRole = attacker:GetRoleStringRaw()
    local witnessRole = witness:GetRoleStringRaw()

    if witnessRole == 'pirate' and (attackerRole == 'pirate_captain' or attackerRole == 'pirate') then
        local eyeTracePos = attacker:GetEyeTrace().HitPos
        if not IsValid(eyeTracePos) then return end
        local target = TTTBots.Lib.GetClosest(TTTBots.Roles.GetNonAllies(witness), eyeTracePos)
        if not target then return end
        witness:SetAttackTarget(target, "ROLE_DEFEND_ALLY", 4)
    end
end)

-- Pirate defends captain and fellow pirates when attacked
hook.Add("TTTBotsOnWitnessHurt", "TTTBotsOnWitnessHurt_pirate",
    function(witness, victim, attacker, healthRemaining, damageTaken)
        if not IsValid(attacker) then return end

        local victimRole = victim:GetRoleStringRaw()
        local witnessRole = witness:GetRoleStringRaw()

        if witnessRole == 'pirate' and (victimRole == 'pirate_captain' or victimRole == 'pirate') then
            witness:SetAttackTarget(attacker, "ROLE_DEFEND_ALLY", 4)
        end
    end)

-- If new contract master is Team Innocent, Pirate will use suspicion
net.Receive("TTT2PirContractMaster", function(len, ply)
    local master = net.ReadEntity()

    if not IsValid(master) then return end

    if master:GetTeam() == TEAM_INNOCENT then
        local pirates = TTTBots.Roles.GetRolesByTeam(TEAM_PIRATE)
        for _, pirate in ipairs(pirates) do
            pirate:SetUsesSuspicion(true)
            pirate:SetStartsFights(false)
        end
    else
        local pirates = TTTBots.Roles.GetRolesByTeam(TEAM_PIRATE)
        for _, pirate in ipairs(pirates) do
            pirate:SetUsesSuspicion(false)
            pirate:SetStartsFights(true)
        end
    end
end)

return true