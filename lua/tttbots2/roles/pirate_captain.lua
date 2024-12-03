if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_PIRATE_CAPTAIN then return false end

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_PIRATE] = true,
}

local allyRoles = {
    pirate = true
}


local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.FightBack,
    _prior.Requests,
    _prior.Convert,
    _prior.Support,
    _bh.FollowMaster,
    _prior.FightBack,
    _prior.Restore,
    _bh.Stalk,
    _prior.Investigate,
    _prior.Patrol
}

local pirate_captain = TTTBots.RoleData.New("pirate_captain", TEAM_PIRATE)
pirate_captain:SetDefusesC4(false)
pirate_captain:SetCanCoordinate(true)
pirate_captain:SetStartsFights(true)
pirate_captain:SetUsesSuspicion(false)
pirate_captain:SetAutoSwitch(true)
pirate_captain:SetPreferredWeapon("weapon_ttt2_contract")
pirate_captain:SetCanHaveRadar(true)
pirate_captain:SetTeam(TEAM_PIRATE)
pirate_captain:SetBTree(bTree)
pirate_captain:SetEnemyRoles({"unknown"})
pirate_captain:SetAlliedTeams(allyTeams)
pirate_captain:SetAlliedRoles(allyRoles)
pirate_captain:SetEnemyTeams({[TEAM_DOOMSLAYER] = true,})
pirate_captain:SetLovesTeammates(true)
TTTBots.Roles.RegisterRole(pirate_captain)

-- Sidekick help master when shooting a victim
hook.Add("TTTBotsOnWitnessFireBullets", "TTTBotsOnWitnessFireBullets", function(witness, attacker, data, angleDiff)
    local attackerRole = attacker:GetRoleStringRaw()
    local witnessRole = witness:GetRoleStringRaw()

    if witnessRole == 'pirate_captain' and attackerRole == 'pirate' then
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

        if witnessRole == 'pirate_captain' and victimRole == 'pirate' then
            witness:SetAttackTarget(attacker)
        end
    end)

-- If new contract master is Team Innocent, Pirate Captain will use suspicion
net.Receive("TTT2PirContractMaster", function(len, ply)
    local master = net.ReadEntity()

    if not IsValid(master) then return end

    pirate_captain:SetUsesSuspicion(master:Team() == TEAM_INNOCENT or master:Team() == TEAM_NONE)
    pirate_captain:SetStartsFights(master:Team() ~= TEAM_INNOCENT and master:Team() ~= TEAM_NONE)

end)

return true