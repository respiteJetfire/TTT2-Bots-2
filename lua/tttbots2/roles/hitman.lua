--- Hitman role integration for TTT Bots 2
--- The Hitman is a Traitor who receives a random contract target each round.
--- Killing the target awards bonus credits; killing non-targets may reveal them.
---
--- Bot strategy:
---   • HitmanTarget behavior runs at high priority to always focus the contract.
---   • Normal traitor tree handles combat, deception, C4, etc. otherwise.
---   • When no target exists the bot plays as a regular traitor.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_HITMAN then return false end

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
    _bh.HitmanTarget,   -- Focus-fire the contract target above everything else
    _prior.Convert,
    _prior.TacticalEquipment,
    _prior.TrapPlayer,
    _prior.KnifeStalk,
    _prior.Support,
    _bh.Roledefib,
    _bh.PlantBomb,
    _prior.TraitorButton,
    _bh.InvestigateCorpse,
    _prior.Restore,
    _bh.FollowPlan,
    _prior.Deception,
    _bh.Interact,
    _prior.Minge,
    _prior.Investigate,
    _prior.Patrol
}

local roleDescription =
    "The Hitman is a Traitor with a contract system. "
    .. "A random non-traitor target is assigned at round start. "
    .. "Killing that target awards bonus credits. "
    .. "Bots will always prioritise their contract target above other enemies."

local hitman = TTTBots.RoleData.New("hitman", TEAM_TRAITOR)
hitman:SetDefusesC4(false)
hitman:SetPlantsC4(true)
hitman:SetTeam(TEAM_TRAITOR)
hitman:SetBTree(bTree)
hitman:SetCanCoordinate(true)
hitman:SetCanHaveRadar(true)
hitman:SetStartsFights(true)
hitman:SetUsesSuspicion(false)
hitman:SetCanSnipe(true)
hitman:SetCanHide(true)
hitman:SetKnowsLifeStates(true) -- isOmniscientRole
hitman:SetLovesTeammates(true)
hitman:SetAlliedTeams({ [TEAM_TRAITOR] = true })
hitman:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(hitman)

-- ---------------------------------------------------------------------------
-- When the round begins, cache the contract target into bot memory so that
-- the HitmanTarget behavior can find it immediately.
-- ---------------------------------------------------------------------------
hook.Add("TTTBeginRound", "TTTBots.Hitman.CacheTargets", function()
    timer.Simple(1, function()
        for _, ply in ipairs(player.GetAll()) do
            if not (IsValid(ply) and ply:IsBot()) then continue end
            if ply:GetSubRole() ~= ROLE_HITMAN then continue end

            local target = nil
            if ply.GetTargetPlayer then
                target = ply:GetTargetPlayer()
            end
            if not IsValid(target) then
                target = ply:GetNWEntity("hit_target", nil)
            end

            if IsValid(target) then
                local memory = ply.components and ply.components.memory
                if memory then
                    memory:UpdateKnownPositionFor(target, target:GetPos())
                end
            end
        end
    end)
end)

print("[TTT Bots 2] Hitman role integration loaded.")
return true
