if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_OCCULTIST then return false end

local occultist = TTTBots.RoleData.New("occultist")
occultist:SetDefusesC4(true)
occultist:SetTeam(TEAM_INNOCENT)
occultist:SetBTree(TTTBots.Behaviors.DefaultTrees.innocent)
occultist:SetCanHide(true)
occultist:SetCanSnipe(true)
occultist:SetUsesSuspicion(true)
occultist:SetAlliedRoles({})
occultist:SetAlliedTeams({})
occultist:SetEnemyTeams({[TEAM_DOOMSLAYER] = true,})
TTTBots.Roles.RegisterRole(occultist)

return true
