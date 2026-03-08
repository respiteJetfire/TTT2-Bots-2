--- RoleBuilder: factory presets for common role archetypes.
--- Call a preset to get a pre-populated RoleData, then override only the fields
--- that differ from the archetype before calling TTTBots.Roles.RegisterRole().
---
--- Available presets:
---   TTTBots.RoleBuilder.InnocentLike(name)
---   TTTBots.RoleBuilder.DetectiveLike(name)
---   TTTBots.RoleBuilder.TraitorLike(name, team?)
---   TTTBots.RoleBuilder.NeutralKiller(name, team)
---   TTTBots.RoleBuilder.GangRole(name, team, enemyTeamsTbl, bTree?)

TTTBots.RoleBuilder = TTTBots.RoleBuilder or {}

local _bh   = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

--- Innocent-like preset.
--- Inherits: TEAM_INNOCENT, DefaultTrees.innocent, DefusesC4=true, UsesSuspicion=true,
---           CanHide=true, CanSnipe=true, KOSUnknown=false.
--- AlliedRoles defaults to {[name]=true} (no auto-medic, no auto-innocents).
--- Override AlliedRoles / AlliedTeams if you want explicit allies.
---@param name string
---@return RoleData
function TTTBots.RoleBuilder.InnocentLike(name)
    local role = TTTBots.RoleData.New(name, TEAM_INNOCENT)
    role:SetDefusesC4(true)
    role:SetTeam(TEAM_INNOCENT)
    role:SetBTree(TTTBots.Behaviors.DefaultTrees.innocent)
    role:SetUsesSuspicion(true)
    role:SetCanHide(true)
    role:SetCanSnipe(true)
    role:SetKOSUnknown(false)
    role:SetCanCoordinateInnocent(true)
    return role
end

--- Detective-like preset.
--- Inherits: TEAM_INNOCENT, DefaultTrees.detective, DefusesC4=true, CanHaveRadar=true,
---           AppearsPolice=true, UsesSuspicion=true.
---@param name string
---@return RoleData
function TTTBots.RoleBuilder.DetectiveLike(name)
    local role = TTTBots.RoleData.New(name, TEAM_INNOCENT)
    role:SetDefusesC4(true)
    role:SetTeam(TEAM_INNOCENT)
    role:SetBTree(TTTBots.Behaviors.DefaultTrees.detective)
    role:SetCanHaveRadar(true)
    role:SetAppearsPolice(true)
    role:SetUsesSuspicion(true)
    role:SetCanCoordinateInnocent(true)
    return role
end

--- Traitor-like preset.
--- Inherits: team (default TEAM_TRAITOR), DefaultTrees.traitor, PlantsC4=true,
---           CanCoordinate=true, CanHaveRadar=true, StartsFights=true,
---           UsesSuspicion=false, LovesTeammates=true,
---           AlliedTeams = {[team]=true, [TEAM_JESTER]=true}.
---@param name string
---@param team? string Defaults to TEAM_TRAITOR
---@return RoleData
function TTTBots.RoleBuilder.TraitorLike(name, team)
    TEAM_JESTER = TEAM_JESTER or "jesters"
    local t = team or TEAM_TRAITOR
    local role = TTTBots.RoleData.New(name, t)
    role:SetPlantsC4(true)
    role:SetDefusesC4(false)
    role:SetTeam(t)
    role:SetBTree(TTTBots.Behaviors.DefaultTrees.traitor)
    role:SetCanCoordinate(true)
    role:SetCanHaveRadar(true)
    role:SetStartsFights(true)
    role:SetUsesSuspicion(false)
    role:SetLovesTeammates(true)
    role:SetAlliedTeams({ [t] = true, [TEAM_JESTER] = true })
    return role
end

--- Neutral-killer preset (Doomslayer-like).
--- Inherits: team, StartsFights=true, KOSAll=true, KOSedByAll=true,
---           UsesSuspicion=false, LovesTeammates=true,
---           AlliedTeams = {[team]=true, [TEAM_JESTER]=true}.
--- BTree defaults to a minimal FightBack tree; pass your own if needed.
---@param name string
---@param team string  TEAM_* constant for this role
---@return RoleData
function TTTBots.RoleBuilder.NeutralKiller(name, team)
    TEAM_JESTER = TEAM_JESTER or "jesters"
    local defaultBTree = {
        _prior.FightBack,
        _prior.Requests,
        _bh.Roledefib,
        _prior.Restore,
        _bh.Interact,
    }
    local role = TTTBots.RoleData.New(name, team)
    role:SetDefusesC4(false)
    role:SetTeam(team)
    role:SetCanCoordinate(false)
    role:SetCanHaveRadar(true)
    role:SetStartsFights(true)
    role:SetUsesSuspicion(false)
    role:SetKOSAll(true)
    role:SetKOSedByAll(true)
    role:SetLovesTeammates(true)
    role:SetAlliedTeams({ [team] = true, [TEAM_JESTER] = true })
    role:SetBTree(defaultBTree)
    return role
end

--- Gang-role preset (GTA gang teams — Ballas/Bloods/Crips/Families/Hoovers pattern).
--- Inherits: team, StartsFights=true, CanCoordinate=true, CanHaveRadar=true,
---           UsesSuspicion=false, LovesTeammates=true,
---           AlliedTeams={[team]=true}, EnemyTeams=enemyTeamsTbl.
--- Provides a default bTree suitable for gang fights; override if needed.
---@param name string
---@param team string  TEAM_* constant
---@param enemyTeamsTbl table  Table keyed by TEAM_* string → true
---@param bTree? table  Optional custom behavior tree
---@return RoleData
function TTTBots.RoleBuilder.GangRole(name, team, enemyTeamsTbl, bTree)
    local defaultBTree = bTree or {
        _prior.Chatter,
        _prior.FightBack,
        _prior.Requests,
        _bh.Roledefib,
        _prior.AttackTarget,
        _prior.Restore,
        _bh.Interact,
    }
    local role = TTTBots.RoleData.New(name, team)
    role:SetDefusesC4(false)
    role:SetTeam(team)
    role:SetCanCoordinate(true)
    role:SetCanHaveRadar(true)
    role:SetStartsFights(true)
    role:SetUsesSuspicion(false)
    role:SetLovesTeammates(true)
    role:SetAlliedTeams({ [team] = true })
    role:SetEnemyTeams(enemyTeamsTbl)
    role:SetBTree(defaultBTree)
    return role
end
