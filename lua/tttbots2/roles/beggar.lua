--- Beggar role integration for TTT Bots 2
--- The Beggar is a jester-team role that cannot deal or take player damage.
--- They must seek out shop-bought weapons dropped by other players and pick
--- them up; doing so converts them to the team of whoever bought that weapon
--- (traitor, innocent, jackal, etc.).
---
--- Bot behavior:
---   • Cannot fight (no damage dealt or taken from players)
---   • Follows other players around trying to be noticed ("begging")
---   • Watches for dropped shop weapons on the ground
---   • Picks up any dropped shop item to trigger team conversion
---   • After conversion, defers to the new role's behavior tree
---   • Respawns on death (configurable)

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_BEGGAR then return false end

TEAM_BEGGAR = TEAM_BEGGAR or "beggar"
TEAM_JESTER = TEAM_JESTER or "jesters"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "You are the Beggar, a jester-team role that cannot deal or take damage from other players. "
    .. "Your goal is to follow players around and hope they drop a shop-bought weapon for you. "
    .. "Picking up a shop item converts you to the team of whoever bought it. "
    .. "You respawn on death, so don't worry about dying — focus on finding items."

-- Custom behavior tree: passive, follows players, seeks dropped weapons
local bTree = {
    _prior.Chatter,
    _prior.FightBack,       -- Will still flee from danger
    _prior.Requests,
    _bh.BeggarSeek,         -- [CUSTOM] Follow players and seek dropped shop weapons
    _prior.Restore,
    _bh.Interact,
    _prior.Minge,           -- Crowbar minge to get attention
    _bh.Decrowd,
    _prior.Patrol,
}

local beggar = TTTBots.RoleData.New("beggar", TEAM_BEGGAR)
beggar:SetDefusesC4(false)
beggar:SetPlantsC4(false)
beggar:SetTeam(TEAM_BEGGAR)
beggar:SetBTree(bTree)
beggar:SetCanCoordinate(false)
beggar:SetCanHaveRadar(false)
beggar:SetStartsFights(false)          -- Cannot deal damage to players
beggar:SetUsesSuspicion(false)
beggar:SetKOSUnknown(false)
beggar:SetKOSAll(false)
beggar:SetKOSedByAll(false)
beggar:SetNeutralOverride(true)        -- Other bots should not target the Beggar
beggar:SetLovesTeammates(false)
beggar:SetAlliedTeams({ [TEAM_BEGGAR] = true, [TEAM_JESTER] = true })
beggar:SetAlliedRoles({ beggar = true })
beggar:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(beggar)

-- Suspicion hook: Beggar should not be suspicious (jester-like)
hook.Add("TTTBotsModifySuspicion", "TTTBots.beggar.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    local role = target:GetRoleStringRaw()
    if role == "beggar" then
        return mult * 0.1 -- Almost zero suspicion (beggar is harmless)
    end
end)

return true
