--- Hunter (Covenant) role integration for TTT Bots 2
--- The Hunter is an omniscient, custom-team role on TEAM_COVENANT.
--- This is the Halo-themed Hunter paired with the Suicide Grunt (sgrunt).
--- Key mechanics:
---   • TEAM_COVENANT — custom team; omniscient (no suspicion)
---   • No shop (SHOP_DISABLED)
---   • Receives weapon_ttt_hunter_cannon as role loadout (heavy cannon)
---   • Large model (1.3× scale), high HP (Belphegor-style tank)
---   • Bondmate system: if a second Hunter is in the round, they are bonded;
---     if bondmate dies, the surviving Hunter enters RAGE MODE (speed boost, color change)
---   • networkRoles = {JESTER}: Jester knows the Hunter
---   • KOSAll / KOSedByAll: hunts everyone outside TEAM_COVENANT
---
--- Bot behavior:
---   • Aggressive Stalk — hunt all non-Covenant players
---   • Prefer the cannon at range; no sniping (heavy weapon, not a sniper)
---   • Coordinate with other Covenant members (sgrunt)
---   • Rage mode after bondmate death: speed boost is server-driven; bot auto-benefits

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_HUNTER then return false end

TEAM_COVENANT = TEAM_COVENANT or "covenant"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _bh.Stalk,
    _prior.Patrol,
}

local roleDescription = "You are the Hunter (Covenant) — an enormous armored tank with a heavy cannon. "
    .. "You have a bondmate Hunter partner; if they die, you enter RAGE MODE with a speed boost. "
    .. "Coordinate with Suicide Grunts on your team. Hunt all non-Covenant players. "
    .. "Your cannon deals heavy damage — use it at medium range."

local hunter = TTTBots.RoleData.New("hunter", TEAM_COVENANT)
hunter:SetDefusesC4(false)
hunter:SetPlantsC4(false)
hunter:SetTeam(TEAM_COVENANT)
hunter:SetBTree(bTree)
hunter:SetCanCoordinate(true)    -- Coordinate with sgrunt teammates
hunter:SetCanHaveRadar(true)     -- isOmniscientRole
hunter:SetStartsFights(true)
hunter:SetUsesSuspicion(false)   -- unknownTeam = false
hunter:SetCanSnipe(false)        -- Heavy cannon; not a sniper
hunter:SetCanHide(false)         -- Too large to hide
hunter:SetKnowsLifeStates(true)  -- isOmniscientRole
hunter:SetKOSAll(true)
hunter:SetKOSedByAll(true)
hunter:SetLovesTeammates(true)
hunter:SetAlliedTeams({ [TEAM_COVENANT] = true })
hunter:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(hunter)

return true
