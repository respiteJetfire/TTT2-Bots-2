--- Beacon role integration for TTT Bots 2
--- The Beacon is an Innocent subrole that gains passive buffs from:
---   • Searching corpses (buff depends on ttt2_beacon_buff_requires_in_person)
---   • Player deaths (if ttt2_beacon_buff_on_death is enabled)
---   • Time intervals (ttt2_beacon_buff_every_x_seconds)
---
--- Key mechanics:
---   • Gains speed, damage, resistance, armor, HP regen, fire rate, jump buffs
---   • Gets demoted to Innocent if they kill an innocent player
---   • At enough buffs, becomes "deputized" (visible to all like a detective)
---   • unknownTeam = true (doesn't know teammates)
---
--- Bot behavior:
---   • Innocent-like: investigate corpses, defuse C4, help innocents
---   • Extra emphasis on corpse investigation (primary buff source)
---   • Avoids killing innocents (demotion penalty)
---   • Becomes more aggressive as buffs accumulate

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_BEACON then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "You are the Beacon, an Innocent subrole that grows stronger over time. "
    .. "Search corpses, witness deaths, and survive to accumulate passive buffs: "
    .. "speed, damage, resistance, armor, health regen, fire rate, and jump height. "
    .. "If you kill an innocent player, you will be demoted and lose your buffs. "
    .. "At enough buffs, you become visible to all players like a detective. "
    .. "Investigate aggressively to power up, but never harm innocents."

-- Custom tree: heavy emphasis on corpse investigation for buff accumulation
local bTree = {
    _prior.Chatter,
    _prior.FightBack,              -- Defend yourself (you get stronger over time!)
    _prior.Requests,
    _prior.Support,                -- Help innocents, coordinate
    _bh.Defib,                     -- Use defibrillator if available
    _bh.Defuse,                    -- Defuse C4
    _bh.InvestigateCorpse,         -- HIGH PRIORITY: search corpses for buffs
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,            -- Investigate noises
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol,
}

local beacon = TTTBots.RoleData.New("beacon", TEAM_INNOCENT)
beacon:SetDefusesC4(true)
beacon:SetPlantsC4(false)
beacon:SetTeam(TEAM_INNOCENT)
beacon:SetBTree(bTree)
beacon:SetCanCoordinate(false)             -- unknownTeam
beacon:SetCanCoordinateInnocent(true)
beacon:SetCanHaveRadar(false)
beacon:SetStartsFights(false)
beacon:SetUsesSuspicion(true)
beacon:SetCanHide(true)
beacon:SetCanSnipe(true)
beacon:SetKOSUnknown(false)
beacon:SetLovesTeammates(false)            -- unknownTeam
beacon:SetAlliedTeams({ [TEAM_INNOCENT] = true })
beacon:SetAlliedRoles({ beacon = true })
beacon:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(beacon)

print("[TTT Bots 2] Beacon role integration loaded — buffing innocent with corpse investigation focus.")

return true
