--- Hanfei role integration for TTT Bots 2
--- The Hanfei is an omniscient Traitor inspired by a suicide bomber + AK47 soldier.
--- Key mechanics:
---   • isOmniscientRole: full life-state awareness, no suspicion
---   • Receives weapon_ttt_hanf_ak47 + weapon_ttt_hanf_c4 on loadout
---   • Radar or tracker given based on ttt2_hanfei_tracker_mode convar
---   • Enhanced HP and armor (ttt2_hanfei_hp / ttt2_hanfei_armor convars)
---   • On death: triggers a large explosion (jihad-style) after 2 seconds,
---     dealing up to 350 damage in a ~476-unit radius — server-driven
---   • Optional timed auto-expose: after N seconds reveals Hanfei to all
---   • preventFindCredits = false: can pick up credits normally
---
--- Bot behavior:
---   • TraitorLike with Jihad awareness — rush targets aggressively
---   • Prefer close-range engagements (AK47 + explosion synergy)
---   • Use PlantBomb behavior for the C4
---   • No sniping — prefer to close distance for explosion value on death
---   • Coordinates with traitor team; full omniscience

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_HANF then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _bh.Jihad,              -- Rush targets; death explosion is a bonus
    _bh.PlantBomb,          -- Place C4 in traitor-heavy areas
    _prior.Grenades,
    _prior.Restore,
    _prior.Deception,
    _bh.Stalk,
    _prior.Investigate,
    _bh.Decrowd,
    _prior.Patrol,
}

local roleDescription = "You are Hanfei — an omniscient Traitor with an AK47 and C4. "
    .. "You have enhanced HP and armor. On death, you explode in a large blast radius. "
    .. "Prioritize getting close to enemies; your death explosion punishes anyone nearby. "
    .. "Plant C4 at chokepoints and coordinate with your traitor teammates."

local hanfei = TTTBots.RoleData.New("hanf", TEAM_TRAITOR)
hanfei:SetDefusesC4(false)
hanfei:SetPlantsC4(true)
hanfei:SetTeam(TEAM_TRAITOR)
hanfei:SetBTree(bTree)
hanfei:SetCanCoordinate(true)
hanfei:SetCanHaveRadar(true)
hanfei:SetStartsFights(true)
hanfei:SetUsesSuspicion(false)
hanfei:SetCanSnipe(false)         -- Prefers close range for explosion synergy
hanfei:SetCanHide(false)
hanfei:SetKnowsLifeStates(true)   -- isOmniscientRole
hanfei:SetLovesTeammates(true)
hanfei:SetAlliedTeams({ [TEAM_TRAITOR] = true })
hanfei:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(hanfei)

-- ---------------------------------------------------------------------------
-- Track auto-expose timer — if exposed, bot can be more aggressive (cover blown)
-- ---------------------------------------------------------------------------
hook.Add("InitPostEntity", "TTTBots.hanfei.inittrack", function()
    if not SERVER then return end
    -- Watch for ttt2_hanfei_exposetime_enabled convar: when expose fires, the
    -- bot loses its "hidden" advantage but gains nothing special. No tree swap needed.
end)

return true
