--- Trapper role integration for TTT Bots 2
--- The Trapper is an Innocent who can activate Traitor Buttons.
--- • When a non-Trapper uses a traitor button, the Trapper is notified of its position.
--- • When the Trapper activates a traitor button, other eligible players are notified.
--- • No shop, no credits — purely a utility/environmental role.
--- • Only selected on maps that have traitor buttons.
---
--- Bot strategy:
---   • Seek out traitor buttons on the map and activate them.
---   • Use button position notifications to know where traitors have recently acted.
---   • Otherwise, play as a standard Innocent (investigate, patrol, help teammates).

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_TRAPPER then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription =
    "You are the Trapper, an innocent-team role with access to Traitor Buttons. "
    .. "Activating traitor buttons can trap or harm enemies. "
    .. "When a traitor uses a button, you receive its position — a useful clue about enemy activity. "
    .. "You have no shop or credits, so rely entirely on traitor buttons and your weapons. "
    .. "Seek out buttons on the map and press them to set traps for traitors."

local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _bh.TrapperButton,      -- Seek and activate traitor buttons
    _prior.Support,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol,
}

local trapper = TTTBots.RoleData.New("trapper")
trapper:SetDefusesC4(true)
trapper:SetPlantsC4(false)
trapper:SetTeam(TEAM_INNOCENT)
trapper:SetBTree(bTree)
trapper:SetCanCoordinate(false)     -- unknownTeam = true
trapper:SetCanHaveRadar(false)      -- SHOP_DISABLED
trapper:SetStartsFights(false)
trapper:SetUsesSuspicion(true)
trapper:SetCanSnipe(true)
trapper:SetCanHide(false)
trapper:SetKOSUnknown(false)
trapper:SetLovesTeammates(true)
trapper:SetAlliedTeams({ [TEAM_INNOCENT] = true })
trapper:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(trapper)

print("[TTT Bots 2] Trapper role integration loaded.")
return true
