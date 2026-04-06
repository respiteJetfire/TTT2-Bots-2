--- Vigilante role integration for TTT Bots 2
--- The Vigilante is an innocent detective sub-role whose damage scales with
--- performance: +0.2 multiplier per enemy kill, −0.1 per team kill.
--- Multiplier stored on bot as NWFloat "ttt2_vig_multiplier" (default 1.0).
---
--- Bot strategy:
---   • Plays as a DetectiveLike bot (policing, DNA scanner, corpse ID).
---   • TTT2PostPlayerDeath hook: when the Vigilante bot scores an enemy kill,
---     record the new multiplier and increase aggression; on a team-kill,
---     lower aggression (reduce personality risk-taking).
---   • unknownTeam: no friendly-fire coordination — must rely on suspicion.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_VIGILANTE then return false end

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
    _prior.Convert,
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
    "The Vigilante is a Detective sub-role whose damage scales with enemy kills. "
    .. "Each enemy kill increases damage by +0.2×; each team-kill decreases by −0.1×. "
    .. "Bots will track this multiplier and adjust aggression accordingly — "
    .. "becoming more aggressive as multiplier rises and more cautious after friendly fire."

local vigilante = TTTBots.RoleData.New("vigilante", TEAM_INNOCENT)
vigilante:SetDefusesC4(true)
vigilante:SetTeam(TEAM_INNOCENT)
vigilante:SetBTree(bTree)
vigilante:SetCanHaveRadar(true)
vigilante:SetAppearsPolice(true)
vigilante:SetUsesSuspicion(true)
vigilante:SetCanCoordinateInnocent(true)
vigilante:SetKOSUnknown(false)
vigilante:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(vigilante)

-- ---------------------------------------------------------------------------
-- Multiplier tracking: read the addon's NWFloat and adjust bot personality.
-- ---------------------------------------------------------------------------

--- Returns the Vigilante's current damage multiplier (1.0 default).
---@param bot Player
---@return number
local function getVigMultiplier(bot)
    return bot:GetNWFloat("ttt2_vig_multiplier", 1.0)
end

hook.Add("TTT2PostPlayerDeath", "TTTBots.Vigilante.TrackMultiplier",
    function(victim, inflictor, attacker)
        if not (IsValid(attacker) and attacker:IsBot()) then return end
        if attacker:GetSubRole() ~= ROLE_VIGILANTE then return end
        if not IsValid(victim) then return end

        -- NWFloat is updated server-side by the addon; read it next tick.
        timer.Simple(0.1, function()
            if not (IsValid(attacker) and attacker:IsActive()) then return end

            local mult = getVigMultiplier(attacker)
            local personality = attacker.BotPersonality and attacker:BotPersonality()
            if not personality then return end

            -- Scale aggression with multiplier: ×1.0 → base, ×2.0 → very aggro,
            -- multiplier below 1.0 (from team kill) → cautious.
            local aggr = math.Clamp((mult - 0.5) / 1.5, 0.1, 1.0)
            personality:SetAggression(aggr)

            local chatter = attacker:BotChatter()
            if chatter and chatter.On then
                if attacker:GetTeam() ~= victim:GetTeam() then
                    -- Enemy kill — celebrate the bonus
                    if mult >= 1.5 and math.random(1, 3) == 1 then
                        chatter:On("VigilanteOnARoll", {}, false)
                    end
                end
            end
        end)
    end)

-- ---------------------------------------------------------------------------
-- Suspicion modifier: Vigilante should appear as a cooperative innocent.
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.vigilante.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    if target:GetRoleStringRaw() ~= "vigilante" then return end
    return mult * 0.7  -- Slightly less suspicious than a typical unknown-team role
end)

print("[TTT Bots 2] Vigilante role integration loaded.")
return true
