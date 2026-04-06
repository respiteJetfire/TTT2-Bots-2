--- The Flood role integration for TTT Bots 2
--- This addon introduces four Flood-team roles, all on TEAM_FLOOD:
---   • ROLE_FINF — Flood Infector: base flood unit, infects via claw weapon
---   • ROLE_FCF  — Flood Combat Form: frontline fighter
---   • ROLE_FTF  — Flood Tank Form: high HP tank
---   • ROLE_FEF  — Flood Elite Form: elite fighter
---
--- All Flood roles:
---   • TEAM_FLOOD — coordinated team, KOS all non-flood
---   • isOmniscientRole: full life-state awareness
---   • unknownTeam = false: publicly known flood team
---   • No shop (SHOP_DISABLED)
---   • Melee-only claw weapons; must spread infection by close combat
---   • Corpose radar showing dead bodies only (CustomRadar)
---   • traitorButton = 1 for FCF/FTF/FEF
---
--- Bot behavior:
---   • All forms: aggressive Stalk — hunt non-flood players with melee
---   • Coordinate with other flood forms
---   • KOSAll / KOSedByAll: fight everyone outside the flood team
---   • No sniping (claw weapons only)

if not TTTBots.Lib.IsTTT2() then return false end

TEAM_FLOOD = TEAM_FLOOD or "flood"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local floodTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _bh.Stalk,
    _prior.Patrol,
}

-- Helper to register a Flood-team role
local function RegisterFloodRole(roleName, roleConst)
    if not roleConst then return end

    local r = TTTBots.RoleData.New(roleName, TEAM_FLOOD)
    r:SetDefusesC4(false)
    r:SetPlantsC4(false)
    r:SetTeam(TEAM_FLOOD)
    r:SetBTree(floodTree)
    r:SetCanCoordinate(true)     -- Coordinate with other flood forms
    r:SetCanHaveRadar(false)     -- CustomRadar (corpse only); not full player radar
    r:SetStartsFights(true)
    r:SetUsesSuspicion(false)    -- unknownTeam = false; no need for suspicion
    r:SetCanSnipe(false)         -- Melee claw weapons only
    r:SetCanHide(false)
    r:SetKnowsLifeStates(true)   -- isOmniscientRole
    r:SetKOSAll(true)
    r:SetKOSedByAll(true)
    r:SetLovesTeammates(true)
    r:SetAlliedTeams({ [TEAM_FLOOD] = true })
    r:SetRoleDescription(
        "You are a member of The Flood (" .. roleName .. "). "
        .. "Spread infection using your claw weapon. Hunt and eliminate all non-Flood players. "
        .. "Coordinate with your Flood teammates. You have no shop — only your claws."
    )
    TTTBots.Roles.RegisterRole(r)
end

-- Register all four Flood forms
RegisterFloodRole("finf", ROLE_FINF)   -- Flood Infector
RegisterFloodRole("fcf",  ROLE_FCF)    -- Flood Combat Form
RegisterFloodRole("ftf",  ROLE_FTF)    -- Flood Tank Form
RegisterFloodRole("fef",  ROLE_FEF)    -- Flood Elite Form

return true
