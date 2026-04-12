--- Patient role integration for TTT Bots 2
--- The Patient is an Innocent sub-role with a contagious cough weapon.
--- Key mechanics:
---   • unknownTeam = true — hidden alignment
---   • No shop (SHOP_DISABLED), no credits
---   • Receives ttt_patient_cough as role loadout — a weapon to infect other players
---     with a sickness DoT (ttt2_pat_sickness_timer seconds duration)
---   • The cough has a cooldown (ttt2_pat_cough_cooldown_timer seconds)
---   • item_pat_immunity can be bought to become immune
---   • item_pat_infection is a deployable that infects an area
---   • Winning condition: survive with innocents
---
--- Bot behavior:
---   • InnocentLike with active cough usage — walks near suspicious players
---     and fires the cough weapon to weaken potential traitors
---   • Uses suspicion to identify targets: prioritises coughing on suspects
---   • Stays near groups to maximize cough spread on suspicious individuals
---   • Falls back to standard innocent investigation/combat otherwise

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_PAT then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "You are the Patient, an innocent sub-role with a contagious cough weapon. "
    .. "Your cough infects nearby players with a sickness DoT that damages them over time. "
    .. "Walk near suspicious players and fire your cough to weaken potential traitors. "
    .. "Stay near groups to maximize your impact. Use suspicion to identify targets."

local bTree = {
    _bh.EvadeGravityMine,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Requests,
    _prior.Chatter,
    _prior.Accuse,
    _bh.InvestigateCorpse,
    _bh.FollowInnocentPlan,
    _prior.Support,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _prior.Patrol,          -- Patrol near groups (no Decrowd — Patient WANTS to be near people)
}

local patient = TTTBots.RoleData.New("pat", TEAM_INNOCENT)
patient:SetDefusesC4(true)
patient:SetTeam(TEAM_INNOCENT)
patient:SetBTree(bTree)
patient:SetUsesSuspicion(true)
patient:SetCanHide(false)           -- Patient needs to be near others to use cough
patient:SetCanSnipe(false)          -- Close-range support role
patient:SetKOSUnknown(false)
patient:SetCanCoordinateInnocent(true)
patient:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(patient)

-- ---------------------------------------------------------------------------
-- Cough weapon usage: periodically attempt to fire the cough at suspicious
-- players who are nearby. This simulates the Patient's core mechanic.
-- ---------------------------------------------------------------------------
local _nextCoughCheck = 0

hook.Add("Think", "TTTBots.Patient.CoughUsage", function()
    if not TTTBots.Match.IsRoundActive() then return end
    if CurTime() < _nextCoughCheck then return end
    _nextCoughCheck = CurTime() + 3 -- Check every 3 seconds

    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and bot:IsBot() and bot:Alive()) then continue end
        if bot:GetSubRole() ~= ROLE_PAT then continue end

        -- Check if we have the cough weapon and it's off cooldown
        local coughWep = bot:GetWeapon("ttt_patient_cough")
        if not IsValid(coughWep) then continue end

        -- Find nearby suspicious players (within cough range)
        local COUGH_RANGE = 300
        local morality = bot.BotMorality and bot:BotMorality()
        if not morality then continue end

        for _, target in ipairs(player.GetAll()) do
            if not IsValid(target) then continue end
            if target == bot then continue end
            if not target:Alive() then continue end

            local dist = bot:GetPos():Distance(target:GetPos())
            if dist > COUGH_RANGE then continue end

            -- Only cough at suspicious players (suspicion > 30)
            local suspicion = morality.GetSuspicion and morality:GetSuspicion(target) or 0
            if suspicion < 30 then continue end

            -- Equip and fire the cough weapon
            if bot:GetActiveWeapon() ~= coughWep then
                bot:SelectWeapon("ttt_patient_cough")
            end

            local loco = bot:BotLocomotor()
            if loco then
                loco:LookAt(target:EyePos())
                loco:StartAttack()
                -- Stop attacking after a brief moment
                timer.Simple(0.5, function()
                    if IsValid(bot) and loco then
                        loco:StopAttack()
                        local inv = bot:BotInventory()
                        if inv then inv:ResumeAutoSwitch() end
                    end
                end)
            end
            break -- Only cough at one target per cycle
        end
    end
end)

print("[TTT Bots 2] Patient role integration loaded — cough weapon support role.")
return true
