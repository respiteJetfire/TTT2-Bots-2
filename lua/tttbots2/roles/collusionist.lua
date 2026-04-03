--- Collusionist role integration for TTT Bots 2
--- The Collusionist is a jester-team role similar to the Beggar. They cannot
--- deal or take player damage and must seek out shop-bought weapons dropped
--- by other players. When a Collusionist picks up a shop item, they SWAP roles
--- with the item's buyer — the Collusionist becomes the buyer's role/team, and
--- the buyer becomes the new Collusionist (set to low health).
---
--- The Collusionist appears as innocent to evil teams (or as jester, configurable).
--- They respawn on death (configurable).
---
--- Bot behavior:
---   • Cannot fight (no damage dealt or taken from players)
---   • Follows players around trying to get shop items ("begging")
---   • Picks up dropped shop items to trigger role swap
---   • After conversion, defers to the new role's behavior tree
---   • Respawns on death (configurable)

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_COLLUSIONIST then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription = "You are the Collusionist, a jester-team role that cannot deal or take damage from players. "
    .. "Your goal is to follow players around and pick up a dropped shop-bought weapon. "
    .. "When you pick one up, you SWAP roles with whoever bought it — you become their role, "
    .. "and they become the new Collusionist with very low health. "
    .. "You respawn on death, so focus on finding items rather than surviving."

-- Custom behavior tree: passive, follows players, seeks dropped weapons
-- Reuses the BeggarSeek behavior (it checks for both ROLE_BEGGAR and ROLE_COLLUSIONIST)
local bTree = {
    _prior.Chatter,
    _prior.FightBack,       -- Will still flee from danger
    _prior.Requests,
    _bh.BeggarSeek,         -- [SHARED] Follow players and seek dropped shop weapons
    _prior.Restore,
    _bh.Interact,
    _prior.Minge,           -- Crowbar minge to get attention
    _bh.Decrowd,
    _prior.Patrol,
}

local collusionist = TTTBots.RoleData.New("collusionist", TEAM_JESTER)
collusionist:SetDefusesC4(false)
collusionist:SetPlantsC4(false)
collusionist:SetTeam(TEAM_JESTER)
collusionist:SetBTree(bTree)
collusionist:SetCanCoordinate(false)
collusionist:SetCanHaveRadar(false)
collusionist:SetStartsFights(false)          -- Cannot deal damage to players
collusionist:SetUsesSuspicion(false)
collusionist:SetKOSUnknown(false)
collusionist:SetKOSAll(false)
collusionist:SetKOSedByAll(false)
collusionist:SetNeutralOverride(true)        -- Other bots should not target
collusionist:SetLovesTeammates(false)
collusionist:SetAlliedTeams({ [TEAM_JESTER] = true })
collusionist:SetAlliedRoles({ collusionist = true })
collusionist:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(collusionist)

-- Suspicion hook: Collusionist should not be suspicious (jester-like)
hook.Add("TTTBotsModifySuspicion", "TTTBots.collusionist.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    local role = target:GetRoleStringRaw()
    if role == "collusionist" then
        return mult * 0.1 -- Almost zero suspicion (harmless jester-type)
    end
end)

return true
