--- Slave role integration for TTT Bots 2
--- The Slave is a player converted by the Brainwasher. They fight alongside
--- the traitors as a loyal sub-traitor who obeys the Brainwasher's commands.
---
--- Bot strategy:
---   • Full traitor tree — plants C4, coordinates with traitors, uses Stalk.
---   • FollowMaster behavior: the Slave bot will follow the Brainwasher in the
---     patrol/idle phase when there are no immediate threats, providing backup.
---   • TTTBotsOnWitnessHurt hook: when the Brainwasher ("master") is attacked,
---     the Slave immediately retaliates to protect them.
---   • Avoids using defibrillators to prevent accidentally reviving innocents.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SLAVE then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _bh.EvadeGravityMine,
    _bh.Jihad,
    _bh.UsePeacekeeper,
    _bh.ActivateSmartBullets,
    _prior.Grenades,
    _prior.Chatter,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Requests,
    _prior.TacticalEquipment,
    _prior.TrapPlayer,
    _prior.KnifeStalk,
    _bh.Roledefib,
    _bh.PlantBomb,
    _prior.TraitorButton,
    _bh.InvestigateCorpse,
    _prior.Restore,
    _bh.FollowMaster,   -- Follow the Brainwasher when idle/patrolling
    _bh.FollowPlan,
    _prior.Deception,
    _bh.Interact,
    _prior.Minge,
    _prior.Investigate,
    _prior.Patrol
}

local roleDescription =
    "The Slave is converted by the Brainwasher and fights alongside the traitors. "
    .. "Bots will follow the Brainwasher when idle and immediately defend them "
    .. "if they come under attack."

local slave = TTTBots.RoleData.New("slave", TEAM_TRAITOR)
slave:SetDefusesC4(false)
slave:SetPlantsC4(true)
slave:SetTeam(TEAM_TRAITOR)
slave:SetBTree(bTree)
slave:SetCanCoordinate(true)
slave:SetCanHaveRadar(true)
slave:SetStartsFights(true)
slave:SetUsesSuspicion(false)
slave:SetCanSnipe(true)
slave:SetCanHide(true)
slave:SetLovesTeammates(true)
slave:SetAlliedTeams({ [TEAM_TRAITOR] = true })
slave:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(slave)

-- ---------------------------------------------------------------------------
-- Obedience: when the Brainwasher (master) is attacked, the Slave retaliates.
-- ---------------------------------------------------------------------------

--- Returns the Brainwasher that converted this Slave, or nil.
---@param slaveBot Player
---@return Player|nil
local function getBrainwasher(slaveBot)
    -- The brainwasher addon sets an NW entity or player field on the slave.
    if slaveBot.GetMaster then
        local m = slaveBot:GetMaster()
        if IsValid(m) then return m end
    end
    local nwMaster = slaveBot:GetNWEntity("brainwasher_master", nil)
    if IsValid(nwMaster) then return nwMaster end
    -- Fall back: find the nearest alive Brainwasher on the same team
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsActive() and ply:GetSubRole() == ROLE_BRAINWASHER then
            return ply
        end
    end
    return nil
end

hook.Add("TTTBotsOnWitnessHurt", "TTTBots.Slave.DefendMaster",
    function(witness, victim, attacker, healthRemaining, damageTaken)
        if not (IsValid(witness) and witness:IsBot()) then return end
        if witness:GetSubRole() ~= ROLE_SLAVE then return end
        if not IsValid(attacker) then return end

        local master = getBrainwasher(witness)
        if not (IsValid(master) and victim == master) then return end

        -- Master is under attack — retaliate immediately
        witness:SetAttackTarget(attacker, "SLAVE_PROTECT_MASTER", 4)

        local chatter = witness:BotChatter()
        if chatter and chatter.On then
            chatter:On("SlaveDefendingMaster", { player = attacker:Nick(), playerEnt = attacker }, true)
        end
    end)

print("[TTT Bots 2] Slave role integration loaded.")
return true
