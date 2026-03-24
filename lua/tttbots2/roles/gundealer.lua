--- Gun Dealer role integration for TTT Bots 2
--- The Gun Dealer is a neutral supply role: it delivers weapon/ammo crates to
--- players. Bots playing as Gun Dealer should NOT start fights — they only
--- shoot in self-defense. Traitors and assassin-like roles should leave the
--- Gun Dealer alone (they benefit from the supply crates too).
---
--- Bot behavior:
---   • Self-defense only (no StartsFights, no opportunistic kills)
---   • Uses the Consignment Manifest to deliver crates to nearby players
---   • Allied with no specific team (NeutralOverride = true)
---   • Communicates via chatter when delivering or being attacked

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_GUNDEALER then return false end

local _bh   = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "You are the Gun Dealer, a neutral role that supplies weapon and ammo crates to other players. "
    .. "You must NOT start fights — only defend yourself if attacked. Use your Consignment Manifest to send "
    .. "crates to players you see. The team that breaks the most of your crates earns your allegiance, "
    .. "changing you to their team's base role. If you die before switching, you drop crates for anyone to claim. "
    .. "Stay alive, stay neutral, and keep dealing."

-- Custom behavior tree: self-defense only, deliver consignments, be social
local bTree = {
    _prior.FightBack,          -- Only fires if attacked (self-defense)
    _prior.SelfDefense,        -- Defend against accusations
    _prior.Requests,           -- Respond to player requests (cease fire, follow, etc.)
    _prior.Chatter,            -- Social communication
    _bh.GunDealerDeliver,      -- Deliver consignment crates to players
    _prior.Restore,            -- Get weapons / health
    _bh.Interact,              -- Social animations
    _prior.Investigate,        -- Investigate noises/corpses
    _bh.Decrowd,               -- Spread out
    _prior.Patrol,             -- Wander / patrol
}

local gundealer = TTTBots.RoleData.New("gundealer", TEAM_GUNDEALER)
gundealer:SetDefusesC4(false)
gundealer:SetPlantsC4(false)
gundealer:SetTeam(TEAM_GUNDEALER)
gundealer:SetBTree(bTree)

-- Self-defense only: do NOT start fights, do NOT opportunistically attack
gundealer:SetStartsFights(false)
gundealer:SetCanCoordinate(false)
gundealer:SetCanCoordinateInnocent(false)
gundealer:SetCanHaveRadar(false)
gundealer:SetUsesSuspicion(false)
gundealer:SetCanHide(true)
gundealer:SetCanSnipe(false)
gundealer:SetKOSUnknown(false)
gundealer:SetKOSAll(false)
gundealer:SetKOSedByAll(false)
gundealer:SetLovesTeammates(false)

-- NeutralOverride: bots should NOT target the Gun Dealer proactively
gundealer:SetNeutralOverride(true)

-- Allied with self only (neutral)
gundealer:SetAlliedRoles({ gundealer = true })
gundealer:SetAlliedTeams({ [TEAM_GUNDEALER] = true })

gundealer:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(gundealer)

return true
