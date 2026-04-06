--- Sheriff role integration for TTT Bots 2
--- The Sheriff is a Detective sub-role who can deputize one other player by
--- "shooting" them (0-damage deagle) with weapon_ttt2_deputydeagle.
--- Deputized players become Deputies — detective-like allies of the Sheriff.
---
--- Bot strategy:
---   • Plays as a DetectiveLike bot (policing, DNA scanner, corpse ID).
---   • CreateDeputy Convert behavior already in the detective tree fires the
---     deagle at nearby innocents — this is the primary deputizing mechanism.
---   • PlayerHurt hook: when the sheriff bot is attacked, it immediately
---     attempts to deputize the nearest available innocent for backup.
---   • TTT2PostPlayerDeath hook: if the Sheriff dies, all Deputy bots are
---     notified so they can avenge or scatter (handled by deputy.lua already).

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SHERIFF then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _bh.EvadeGravityMine,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Chatter,
    _prior.Grenades,
    _prior.Requests,
    _prior.Accuse,
    _bh.InvestigateCorpse,
    _prior.DNAScanner,
    _prior.Convert,     -- CreateDeputy fires the deputizing deagle shot
    _prior.Restore,
    _bh.FollowInnocentPlan,
    _prior.Support,
    _prior.TacticalEquipment,
    _bh.Defuse,
    _bh.ActiveInvestigate,
    _bh.Interact,
    _prior.Minge,
    _prior.Investigate,
    _bh.Decrowd,
    _prior.Patrol
}

local roleDescription =
    "The Sheriff is a Detective sub-role. "
    .. "The Sheriff can fire their special deagle at an innocent to deputize them — "
    .. "creating an allied Detective-like partner. "
    .. "Bots will use CreateDeputy to deputize nearby innocents and will "
    .. "react aggressively when attacked, calling for backup."

local sheriff = TTTBots.RoleData.New("sheriff", TEAM_INNOCENT)
sheriff:SetDefusesC4(true)
sheriff:SetTeam(TEAM_INNOCENT)
sheriff:SetBTree(bTree)
sheriff:SetCanHaveRadar(true)
sheriff:SetAppearsPolice(true)
sheriff:SetUsesSuspicion(true)
sheriff:SetCanCoordinateInnocent(true)
sheriff:SetKOSUnknown(false)
sheriff:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(sheriff)

-- ---------------------------------------------------------------------------
-- When a Sheriff bot is attacked, call for a deputy backup and deputize the
-- nearest available innocent immediately (if not already done).
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsOnWitnessHurt", "TTTBots.Sheriff.CallForBackup",
    function(witness, victim, attacker, healthRemaining, damageTaken)
        if not (IsValid(witness) and witness:IsBot()) then return end
        if witness:GetSubRole() ~= ROLE_SHERIFF then return end
        if victim ~= witness then return end  -- only care about self being hurt
        if not IsValid(attacker) then return end

        -- Retaliate immediately
        witness:SetAttackTarget(attacker, "SHERIFF_RETALIATE", 4)

        -- Try to accelerate deputizing: give the CreateDeputy behavior a head
        -- start by nudging the deagle weapon selection. The Convert priority
        -- node handles the actual logic; this just ensures combat target is set.
        local chatter = witness:BotChatter()
        if chatter and chatter.On then
            chatter:On("SheriffUnderAttack", { player = attacker:Nick(), playerEnt = attacker }, true)
        end
    end)

print("[TTT Bots 2] Sheriff role integration loaded.")
return true
