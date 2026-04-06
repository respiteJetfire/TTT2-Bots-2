--- Kobold Hoarder role integration for TTT Bots 2
--- The Kobold is a unique neutral/jester-like role on TEAM_KOBOLD.
--- Key mechanics:
---   • TEAM_KOBOLD — custom team; not Innocent or Traitor
---   • preventWin = true: cannot win normally; has a special win condition
---     (collecting a "hoard" of weapons/items before dying?)
---   • scoreKillsMultiplier = 0: gets no points for kills
---   • Small size (0.6× model scale), fast movement speed
---   • KOBOLDBAG_DATA tracks hoard accumulation
---   • Wins by surviving long enough with a full hoard (configured via convars)
---   • networkRoles = {JESTER}: Traitors may know the Kobold
---   • defaultEquipment = INNO_EQUIPMENT
---
--- Bot behavior:
---   • Wander and hoard items — avoid combat when possible
---   • FightBack if attacked (survival is needed to accumulate hoard)
---   • No coordination; no shop; no radar
---   • NeutralOverride: don't be proactively targeted

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_KOBOLD then return false end

TEAM_KOBOLD = TEAM_KOBOLD or "kobold"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,    -- Survive to build hoard
    _prior.Restore,
    _bh.Interact,        -- Pick up weapons/items for the hoard
    _prior.Minge,
    _prior.Investigate,
    _bh.Decrowd,
    _prior.Patrol,
}

local roleDescription = "You are the Kobold Hoarder — a tiny, fast neutral creature. "
    .. "Your goal is to accumulate a hoard of weapons and items. You score nothing for kills. "
    .. "Stay alive and collect as many items as possible. Avoid direct fights — "
    .. "you are small and fast; use your mobility to survive."

local kobold = TTTBots.RoleData.New("kobold", TEAM_KOBOLD)
kobold:SetDefusesC4(false)
kobold:SetPlantsC4(false)
kobold:SetTeam(TEAM_KOBOLD)
kobold:SetBTree(bTree)
kobold:SetCanCoordinate(false)
kobold:SetCanHaveRadar(false)
kobold:SetStartsFights(false)    -- Avoid combat to survive for the hoard
kobold:SetUsesSuspicion(false)
kobold:SetCanSnipe(false)
kobold:SetCanHide(true)          -- Small size = natural cover advantage
kobold:SetKnowsLifeStates(false)
kobold:SetKOSAll(false)
kobold:SetKOSedByAll(false)
kobold:SetNeutralOverride(true)
kobold:SetLovesTeammates(false)
kobold:SetAlliedTeams({ [TEAM_KOBOLD] = true })
kobold:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(kobold)

return true
