--- Lunk role integration for TTT Bots 2
--- The Lunk is a solo public killer on TEAM_LUNK. They have:
---   • High HP and armor (configurable via convars)
---   • weapon_lunkfist as their ONLY weapon (cannot pick up others)
---   • Increased movement speed
---   • isOmniscientRole and isPublicRole (everyone knows they exist)
---   • Cannot use radar or coordinate with anyone
---
--- Bot behavior:
---   • Aggressive melee chaser — always tries to close distance and punch
---   • KOSAll / KOSedByAll (everyone is an enemy)
---   • Prefers weapon_lunkfist; ignores all other weapons
---   • No shop, no C4, no coordination
---   • Omniscient: knows all player life states

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_LUNK then return false end

TEAM_LUNK = TEAM_LUNK or "lunk"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "You are the Lunk, a solo public melee killer. Everyone knows you are the Lunk. "
    .. "You have high HP, armor, and increased movement speed, but your only weapon is your Lunk Fist. "
    .. "You cannot pick up other weapons. You must punch every other player to death. "
    .. "You are alone against the world — but you are built to survive it."

-- Aggressive melee tree: chase and punch everyone
local bTree = {
    _prior.Chatter,
    _prior.FightBack,       -- Immediately fight back if attacked
    _bh.Stalk,              -- Aggressively hunt the nearest target
    _bh.Decrowd,
    _prior.Patrol,
}

local lunk = TTTBots.RoleData.New("lunk", TEAM_LUNK)
lunk:SetDefusesC4(false)
lunk:SetPlantsC4(false)
lunk:SetTeam(TEAM_LUNK)
lunk:SetBTree(bTree)
lunk:SetCanCoordinate(false)
lunk:SetCanHaveRadar(false)
lunk:SetStartsFights(true)
lunk:SetUsesSuspicion(false)
lunk:SetKOSAll(true)
lunk:SetKOSedByAll(true)
lunk:SetKnowsLifeStates(true)           -- isOmniscientRole
lunk:SetNeutralOverride(false)          -- Should be targeted by everyone
lunk:SetLovesTeammates(false)
lunk:SetPreferredWeapon("weapon_lunkfist")
lunk:SetAutoSwitch(false)               -- Always stay on the fist
lunk:SetAlliedTeams({ [TEAM_LUNK] = true })
lunk:SetAlliedRoles({ lunk = true })
lunk:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(lunk)

return true
