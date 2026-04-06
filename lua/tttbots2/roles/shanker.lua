--- Shanker role integration for TTT Bots 2
--- The Shanker is an omniscient Traitor with a custom knife (weapon_ttt_shankknife).
--- Key mechanics:
---   • isOmniscientRole: full life-state awareness, no suspicion
---   • SHOP_DISABLED: no shop; the shank knife is their only weapon
---   • Gets weapon_ttt_shankknife as role loadout — a melee-only murderer
---   • traitorButton = 1: can use traitor buttons
---   • Wins with the traitor team
---
--- Bot behavior:
---   • TraitorLike with melee emphasis — close-range stalking and striking
---   • No sniping (melee weapon only)
---   • CanHide = true to set up ambush positions before rushing
---   • Coordinates with traitor team

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SHANK then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _bh.AttackTarget,
    _prior.Restore,
    _prior.Deception,
    _bh.Stalk,
    _prior.Investigate,
    _bh.Decrowd,
    _prior.Patrol,
}

local roleDescription = "You are the Shanker — a Traitor with only a shank knife. "
    .. "You have no shop. Get close to enemies and stab them. "
    .. "Use ambush positions to close distance before attacking. "
    .. "Coordinate with traitor teammates but rely on melee for all kills."

local shanker = TTTBots.RoleData.New("shank", TEAM_TRAITOR)
shanker:SetDefusesC4(false)
shanker:SetPlantsC4(false)
shanker:SetTeam(TEAM_TRAITOR)
shanker:SetBTree(bTree)
shanker:SetCanCoordinate(true)
shanker:SetCanHaveRadar(true)
shanker:SetStartsFights(true)
shanker:SetUsesSuspicion(false)
shanker:SetCanSnipe(false)        -- Melee only
shanker:SetCanHide(true)          -- Ambush positioning
shanker:SetKnowsLifeStates(true)  -- isOmniscientRole
shanker:SetLovesTeammates(true)
shanker:SetAlliedTeams({ [TEAM_TRAITOR] = true })
shanker:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(shanker)

return true
