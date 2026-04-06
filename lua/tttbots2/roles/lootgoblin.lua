--- Loot Goblin role integration for TTT Bots 2
--- The Loot Goblin is a neutral role on TEAM_LOOTGOBLIN.
--- Key mechanics:
---   • TEAM_LOOTGOBLIN — custom team; visibleForTeam = {TEAM_TRAITOR} (traitors see them)
---   • preventWin = true: cannot win normally; special win condition
---   • Small size (0.5× model scale), fast run speed (600), fast walk (300)
---   • scoreKillsMultiplier = 0: no points for kills
---   • Low HP (configured via ttt2_lootgoblin_health convar)
---   • networkRoles = {JESTER}: traitors/jesters know the goblin
---   • defaultEquipment = INNO_EQUIPMENT
---   • Announces goblin presence to other players at round start
---
--- Bot behavior:
---   • Fast hit-and-run: use speed to evade combat
---   • Interact with items, wander the map
---   • NeutralOverride: not proactively targeted
---   • FightBack if cornered, but prefer escape via speed

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_LOOTGOBLIN then return false end

TEAM_LOOTGOBLIN = TEAM_LOOTGOBLIN or "lootgoblin"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,    -- Run away or fight if cornered
    _prior.Restore,
    _bh.Interact,        -- Collect/interact with items
    _prior.Minge,
    _prior.Investigate,
    _bh.Decrowd,
    _prior.Patrol,
}

local roleDescription = "You are the Loot Goblin — a tiny, lightning-fast neutral creature. "
    .. "You have very low HP but incredible speed. Traitors can see your role. "
    .. "Collect items and survive as long as possible. Avoid combat — escape using your speed. "
    .. "You have no kill incentive; your only goal is to outlast everyone else."

local lootgoblin = TTTBots.RoleData.New("lootgoblin", TEAM_LOOTGOBLIN)
lootgoblin:SetDefusesC4(false)
lootgoblin:SetPlantsC4(false)
lootgoblin:SetTeam(TEAM_LOOTGOBLIN)
lootgoblin:SetBTree(bTree)
lootgoblin:SetCanCoordinate(false)
lootgoblin:SetCanHaveRadar(false)
lootgoblin:SetStartsFights(false)    -- Low HP; speed > combat
lootgoblin:SetUsesSuspicion(false)
lootgoblin:SetCanSnipe(false)
lootgoblin:SetCanHide(true)          -- Small size; hide when threatened
lootgoblin:SetKnowsLifeStates(false)
lootgoblin:SetKOSAll(false)
lootgoblin:SetKOSedByAll(false)
lootgoblin:SetNeutralOverride(true)
lootgoblin:SetLovesTeammates(false)
lootgoblin:SetAlliedTeams({ [TEAM_LOOTGOBLIN] = true })
lootgoblin:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(lootgoblin)

return true
