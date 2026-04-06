--- Occultist role integration for TTT Bots 2
--- The Occultist is a secret innocent who can revive once per round when their
--- HP drops below `ttt_occultist_health_threshold` (default ~30). On death,
--- fire rings appear and the Occultist revives after a delay.
---
--- Bot strategy:
---   • Plays as a standard innocent (InnocentLike tree base).
---   • unknownTeam: plays alone; no team coordination.
---   • Think hook watches the `occ_data.allow_revival` flag (set by the addon
---     when HP has crossed the threshold). Once revival is queued:
---       - The bot stops retreating and starts fighting back aggressively
---         (they know they will revive if they die now).
---       - After revival, reset personality to normal caution.
---   • Pre-threshold: the bot is slightly more cautious than usual (preserves
---     the revival for a meaningful moment rather than throwing it away early).

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_OCCULTIST then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _bh.EvadeGravityMine,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Requests,
    _prior.Chatter,
    _prior.Grenades,
    _prior.Accuse,
    _bh.InvestigateCorpse,
    _bh.FollowInnocentPlan,
    _prior.Support,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

local roleDescription =
    "The Occultist is a secret innocent with a one-time revival ability. "
    .. "When HP drops below the configured threshold the revival is armed. "
    .. "Bots are cautious early to preserve the revival, then become reckless "
    .. "once the revival is armed (they can afford to die)."

local occultist = TTTBots.RoleData.New("occultist", TEAM_INNOCENT)
occultist:SetDefusesC4(true)
occultist:SetTeam(TEAM_INNOCENT)
occultist:SetBTree(bTree)
occultist:SetUsesSuspicion(true)
occultist:SetCanHide(true)
occultist:SetCanSnipe(true)
occultist:SetKOSUnknown(false)
occultist:SetAlliedRoles({})
occultist:SetAlliedTeams({})
occultist:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(occultist)

-- ---------------------------------------------------------------------------
-- Revival-awareness: watch occ_data flags and adjust personality accordingly.
-- ---------------------------------------------------------------------------

local _nextOccCheck = 0

hook.Add("Think", "TTTBots.Occultist.RevivalWatch", function()
    if not TTTBots.Match.IsRoundActive() then return end
    if CurTime() < _nextOccCheck then return end
    _nextOccCheck = CurTime() + 0.5

    for _, ply in ipairs(player.GetAll()) do
        if not (IsValid(ply) and ply:IsBot() and ply:IsActive()) then continue end
        if ply:GetSubRole() ~= ROLE_OCCULTIST then continue end

        local personality = ply.BotPersonality and ply:BotPersonality()
        if not personality then continue end

        local occData = ply.occ_data
        if occData and occData.allow_revival and not occData.was_revived then
            -- Revival is armed — go reckless (bot can afford to die)
            personality:SetAggression(1.0)
        elseif occData and occData.was_revived then
            -- Already used the revival — return to cautious play
            personality:SetAggression(0.4)
        else
            -- Pre-threshold — slightly cautious to preserve revival
            personality:SetAggression(0.5)
        end
    end
end)

print("[TTT Bots 2] Occultist role integration loaded.")
return true
