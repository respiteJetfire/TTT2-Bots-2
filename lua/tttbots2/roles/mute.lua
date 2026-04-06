--- Mute role integration for TTT Bots 2
--- The Mute is an innocent subrole who starts the round completely silenced:
---   • Cannot speak in voice or text chat (server-enforced)
---   • Cannot use most weapons (only unarmed + optionally magneto)
---   • Has a custom radar showing all other players as innocents
---   • unknownTeam: true
---
--- Bot behavior:
---   • InnocentLike base — does not fight aggressively
---   • unknownTeam: uses suspicion to identify threats
---   • Has radar (given at loadout) — acts as if it always has position intel
---   • Cannot equip weapons: bot will use the unarmed attack only
---   • Patrols and avoids danger; relies on other players to handle killers

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_MUTE then return false end

TEAM_MUTE = TEAM_MUTE or "mutes"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "You are the Mute, an innocent subrole who cannot speak or use weapons. "
    .. "You start silenced — no voice or text chat — and can only use the unarmed attack. "
    .. "However, you have a radar that shows all players' positions (shown as innocents). "
    .. "Survive and use your positional intel to help guide innocent players — just don't expect "
    .. "to win any fights."

local bTree = {
    _prior.Chatter,         -- Chatter (blocked server-side anyway)
    _prior.FightBack,       -- Flee/defend if attacked (limited weapon options)
    _prior.Requests,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,     -- Investigate suspicious positions from radar
    _bh.Decrowd,
    _prior.Patrol,
}

local mute = TTTBots.RoleData.New("mute", TEAM_MUTE)
mute:SetDefusesC4(false)
mute:SetPlantsC4(false)
mute:SetTeam(TEAM_MUTE)
mute:SetBTree(bTree)
mute:SetCanCoordinate(false)        -- Can't communicate
mute:SetCanHaveRadar(true)          -- Has radar from loadout
mute:SetStartsFights(false)         -- Can't really fight
mute:SetUsesSuspicion(true)         -- unknownTeam, uses suspicion
mute:SetKOSUnknown(false)
mute:SetKOSAll(false)
mute:SetKOSedByAll(false)
mute:SetLovesTeammates(true)
mute:SetAlliedTeams({ [TEAM_INNOCENT] = true, [TEAM_MUTE] = true })
mute:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(mute)

return true
