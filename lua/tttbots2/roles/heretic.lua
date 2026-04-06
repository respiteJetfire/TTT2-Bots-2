--- Heretic role integration for TTT Bots 2
--- The Heretic is a highly complex Traitor that transforms into one of many "Demon" forms
--- at the start of the round. Each demon has unique stat modifiers (HP, damage, speed,
--- size, etc.) drawn from DemonNameTable. Categories: Sin, Solomon, Other.
---
--- Key mechanics:
---   • TEAM_TRAITOR — coordinates with traitors
---   • Demon form is assigned at round start; modifies HP, damage multiplier, speed, size
---   • Some demons (Belphegor) get 4× HP but normal damage; others (Lucifer) get 2× damage
---     but also 2× damage received — server-driven stat changes
---   • Infects others with a "virus" entity (ent_heretic_snake / heretic_virus)
---   • isOmniscientRole (implied by traitor base role)
---   • No shop (shopFallback disabled by default based on demon form)
---
--- Bot behavior:
---   • TraitorLike — full aggression, coordination, and stalking
---   • Stat modifiers are server-driven; bot benefits automatically from HP/speed boosts
---   • Infection mechanics are handled by the role's virus entity — no special bot action

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_HERETIC then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _prior.Grenades,
    _prior.Restore,
    _prior.Deception,
    _bh.Stalk,
    _prior.Investigate,
    _bh.Decrowd,
    _prior.Patrol,
}

local roleDescription = "You are the Heretic — a Traitor transformed into a Demon form. "
    .. "Your stats (HP, damage, speed, size) vary by demon type assigned at round start. "
    .. "You spread a virus infection to enemies. Coordinate with traitors and overwhelm opponents. "
    .. "Your demon buffs are automatic — just fight aggressively."

local heretic = TTTBots.RoleData.New("heretic", TEAM_TRAITOR)
heretic:SetDefusesC4(false)
heretic:SetPlantsC4(true)
heretic:SetTeam(TEAM_TRAITOR)
heretic:SetBTree(bTree)
heretic:SetCanCoordinate(true)
heretic:SetCanHaveRadar(true)
heretic:SetStartsFights(true)
heretic:SetUsesSuspicion(false)
heretic:SetCanSnipe(false)        -- Close-range demon; infection requires proximity
heretic:SetCanHide(true)
heretic:SetKnowsLifeStates(true)
heretic:SetLovesTeammates(true)
heretic:SetAlliedTeams({ [TEAM_TRAITOR] = true })
heretic:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(heretic)

return true
