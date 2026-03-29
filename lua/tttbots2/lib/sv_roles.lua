--- This module is an abstraction layer for TTT/2 compatibility.

TTTBots.Roles = {}

local lib = TTTBots.Lib
TTTBots.Roles.m_roles = {}

include("sv_roledata.lua")
include("sv_rolebuilder.lua")

--- Emits a debug warning through the refactor-debug gate.
---@param msg string
local function RoleWarn(msg)
    if TTTBots.Lib.GetConVarBool and TTTBots.Lib.GetConVarBool("ttt_bot_debug_refactor") then
        print("[TTT Bots 2][RoleWarn] " .. msg)
    end
end

--- Validates a RoleData instance at registration time.
--- Emits warnings for known bad configurations but never blocks registration.
---@param roleData RoleData
local function ValidateRoleAtRegistration(roleData)
    local name = roleData:GetName() or "<nil>"

    -- KOSAll + NeutralOverride is contradictory
    if roleData:GetKOSAll() and roleData:GetNeutralOverride() then
        RoleWarn(string.format(
            "Role '%s': KOSAll=true AND NeutralOverride=true are contradictory — role will KOS all but also be immune to attack.",
            name
        ))
    end

    -- BTree should be a non-empty table
    local bt = roleData:GetBTree()
    if type(bt) ~= "table" or #bt == 0 then
        RoleWarn(string.format(
            "Role '%s': BTree is empty or not a table — bot will have no behaviors.",
            name
        ))
    end

    -- AlliedRoles, AlliedTeams, EnemyRoles, EnemyTeams must all be tables
    for _, field in ipairs({ "GetAlliedRoles", "GetAlliedTeams", "GetEnemyRoles", "GetEnemyTeams" }) do
        local val = roleData[field](roleData)
        if val ~= nil and type(val) ~= "table" then
            RoleWarn(string.format(
                "Role '%s': %s() returned a non-table value (%s) — will likely cause alliance errors.",
                name, field, tostring(val)
            ))
        end
    end

    -- RoleDescription must be a string
    local desc = roleData:GetRoleDescription()
    if type(desc) ~= "string" then
        RoleWarn(string.format(
            "Role '%s': RoleDescription is not a string (got %s).",
            name, type(desc)
        ))
    end
end

function TTTBots.Roles.RegisterRole(roleData)
    ValidateRoleAtRegistration(roleData)
    TTTBots.Roles.m_roles[roleData:GetName()] = roleData
end

--- Return a role by its name.
---@param name string
---@return RoleData
---@return boolean - Whether or not the role is the default role.
function TTTBots.Roles.GetRole(name)
    local selected = TTTBots.Roles.m_roles[name]
    local isDefault = false
    if not selected then
        selected = TTTBots.Roles.m_roles["innocent"]
        isDefault = true
    end

    return selected, isDefault
end

---Returns the RoleData of the player.
---Always returns a valid RoleData (falls back to innocent) so callers can
---safely chain method calls without nil-checking every time.
---@param ply Player
---@return RoleData
---@return boolean - Whether or not the role is the default role.
function TTTBots.Roles.GetRoleFor(ply)
    if not IsValid(ply) or not ply.GetRoleStringRaw then
        return TTTBots.Roles.GetRole("innocent") -- safe fallback, never nil
    end
    local roleString = ply:GetRoleStringRaw()
    return TTTBots.Roles.GetRole(roleString)
end

--- Return a comprehensive table of the defined roles.
---@return table<RoleData>
function TTTBots.Roles.GetRoles() return TTTBots.Roles.m_roles end

--- Return a random role from the defined roles.
---@return RoleData
function TTTBots.Roles.GetRandomRole()
    local roles = TTTBots.Roles.GetRoles()
    local keys = table.GetKeys(roles)
    local randomKey = table.Random(keys)
    return roles[randomKey]
end

function TTTBots.Roles.GetLivingAllies(player)
    local alive = TTTBots.Match.AlivePlayers
    return TTTBots.Lib.FilterTable(alive, function(other)
        return TTTBots.Roles.IsAllies(player, other)
    end)
end

---Gets if the player is the ally of another player. This is based on the role's allies.
---@param ply1 Player
---@param ply2 Player
---@return boolean
function TTTBots.Roles.IsAllies(ply1, ply2)
    if not (IsValid(ply1) and IsValid(ply2)) then return false end
    local role1 = TTTBots.Roles.GetRoleFor(ply1)
    local role2 = TTTBots.Roles.GetRoleFor(ply2)
    if not role1 or not role2 then return false end

    -- Workaround for roles like Bodyguard where player team is adjusted on-the-fly
    if (
        (role1:GetLovesTeammates() or role2:GetLovesTeammates())
        and (ply1:GetTeam() == ply2:GetTeam())
    ) then return true end

    -- Now just testing if the roles are setup to care about each other.
    local allied1 = role1:GetAlliedRoles()[role2:GetName()] or role1:GetAlliedTeams()[role2:GetTeam()] or false
    local allied2 = role2:GetAlliedRoles()[role1:GetName()] or role2:GetAlliedTeams()[role1:GetTeam()] or false

    -- Using 'or' here intentionally, as the mode does not currently support one-sided alliances.
    return allied1 or allied2
end

---Gets if the player is the enemy of another player. This is based on the role's enemies.
---@param ply1 Player
---@param ply2 Player
---@return boolean
function TTTBots.Roles.IsEnemies(ply1, ply2)
    if not (IsValid(ply1) and IsValid(ply2)) then return false end
    local role1 = TTTBots.Roles.GetRoleFor(ply1)
    local role2 = TTTBots.Roles.GetRoleFor(ply2)
    if not role1 or not role2 then return false end

    -- Workaround for roles like Bodyguard where player team is adjusted on-the-fly
    if (
        (role1:GetLovesTeammates() or role2:GetLovesTeammates())
        and (ply1:GetTeam() == ply2:GetTeam())
    ) then return false end

    -- Now just testing if the roles are setup to hate each other.
    local enemy1 = role1:GetEnemyRoles()[role2:GetName()] or role1:GetEnemyTeams()[role2:GetTeam()] or false

    -- Using 'or' here intentionally, as the mode does not currently support one-sided alliances.
    return enemy1 or false
end

---Is this player GetKOSAll?
---@param ply Player
---@return boolean
function TTTBots.Roles.IsKOSAll(ply)
    local role = TTTBots.Roles.GetRoleFor(ply)
    if not role then return false end
    return role:GetKOSAll()
end

---Is this player GetKOSedByAll?
---@param ply Player
---@return boolean
function TTTBots.Roles.IsKOSedByAll(ply)
    local role = TTTBots.Roles.GetRoleFor(ply)
    if not role then return false end
    return role:GetKOSedByAll()
end

---Get a table of players that are IsKOSedByAll, and are alive.
---@return table<Player>
function TTTBots.Roles.GetKOSedByAllPlayers()
    local alive = TTTBots.Match.AlivePlayers
    return TTTBots.Lib.FilterTable(alive, function(ply)
        return TTTBots.Roles.IsKOSedByAll(ply)
    end)
end

---Get a table of players that are IsKOSAll, and are alive.
---@return table<Player>
function TTTBots.Roles.GetKOSAllPlayers()
    local alive = TTTBots.Match.AlivePlayers
    return TTTBots.Lib.FilterTable(alive, function(ply)
        return TTTBots.Roles.IsKOSAll(ply)
    end)
end

---Get a table of players that are not allies with ply1, and are alive.
---@param ply1 Player
---@return table<Player>
function TTTBots.Roles.GetNonAllies(ply1)
    local alive = TTTBots.Match.AlivePlayers
    return TTTBots.Lib.FilterTable(alive, function(other)
        if not (IsValid(other) and lib.IsPlayerAlive(other)) then return false end
        return not TTTBots.Roles.IsAllies(ply1, other)
    end)
end

---Determine if a player is on Team Innocent.
---@param ply Player
---@return boolean
function TTTBots.Roles.IsInnocent(ply)
    return ply:GetTeam() == TEAM_INNOCENT
end

---Get a table of players that are enemies with ply1, and are alive.
---@param ply1 Player
---@return table<Player>
function TTTBots.Roles.GetEnemies(ply1)
    local alive = TTTBots.Match.AlivePlayers
    return TTTBots.Lib.FilterTable(alive, function(other)
        if not (IsValid(other) and lib.IsPlayerAlive(other)) then return false end
        return TTTBots.Roles.IsEnemies(ply1, other)
    end)
end

---Get a table of players that have the role "unknown" and are alive.
---@return table<Player>
function TTTBots.Roles.GetUnknownPlayers()
    if not TTTBots.Lib.IsTTT2() then return false end
    if not ROLE_UNKNOWN then return false end
    local alive = TTTBots.Match.AlivePlayers
    return TTTBots.Lib.FilterTable(alive, function(ply)
        -- print("Checking if player is unknown: ", ply:GetRoleStringRaw())
        return ply:GetRoleStringRaw() == "unknown"
    end)
end


---Returns if the bot's team is that of a traitor. Not recommende for determining who is friendly, as this is only based on the team, and not the role's allies.
---@param bot any
---@return boolean
function TTTBots.Roles.IsTraitor(bot)
    return bot:GetTeam() == TEAM_TRAITOR
end

--- Tries to automatically register a role, based on its base role or role info. This is far from perfect, but it's better than nothing.
---@param roleString string
---@return boolean - Whether or not we successfully registered a role.
function TTTBots.Roles.GenerateRegisterForRole(roleString)
    -- If we are in this function, this is definitely TTT2. But check anyway :)))
    if not TTTBots.Lib.IsTTT2() then return false end
    local roleObj = roles.GetByName(roleString)
    if not roleObj then return false end
    local baseRole = roleObj.baserole and roles.GetByIndex(roleObj.baserole)
    if baseRole then
        local baseData = TTTBots.Roles.GetRole(baseRole.name)
        if baseData:GetName() ~= "default" then
            local copy = table.Copy(baseData)
            copy:SetName(roleString)
            TTTBots.Roles.RegisterRole(copy)
            print(string.format("[TTT Bots 2] Auto-registered role '%s' based off of '%s'", roleString, baseRole.name))
            return true
        end
    end

    local roleTeam = roleObj.defaultTeam
    local isOmniscient = roleObj.isOmniscientRole or false
    -- local isPublicRole = role.isPublicRole or false     -- If the role is known to everyone. Unused here
    local isPolicingRole = roleObj.isPolicingRole or false -- if the role is a policing role
    local GetKOSedByAll = roleObj.GetKOSedByAll or false
    local GetKOSAll = roleObj.GetKOSAll or false

    local data = TTTBots.RoleData.New(roleString)
    data:SetTeam(roleTeam)
    data:SetUsesSuspicion(not isOmniscient)
    data:SetCanCoordinate(roleTeam == TEAM_TRAITOR)
    data:SetCanCoordinateInnocent(roleTeam == TEAM_INNOCENT)
    data:SetCanHaveRadar(isPolicingRole or roleTeam == TEAM_TRAITOR)
    data:SetAlliedRoles({ [roleString] = true })
    data:SetKOSAll(GetKOSAll)
    data:SetKOSedByAll(GetKOSedByAll)
    data:SetKnowsLifeStates(isOmniscient)
    data:SetBTree(TTTBots.Behaviors.DefaultTreesByTeam[roleTeam] or TTTBots.Behaviors.DefaultTrees.innocent)
    data:SetStartsFights(roleTeam == TEAM_TRAITOR)
    if roleString ~= 'none' then
        local registeredManually = hook.Run("TTTBotsRoleRegistered", data)
        print(string.format("[TTT Bots 2] Registered role '%s' as a part of team '%s'!", roleString, data:GetTeam()))
        if not registeredManually then
            print(
                "[TTT Bots 2] The above role was not caught by any compatibility scripts! You may experience strange bot behavior for this role.")
        end
    end
    TTTBots.Roles.RegisterRole(data)
    return true
end

--- Create a timer on 2-second intervals to auto-generate roles if round started and we find an unknown role
timer.Create("TTTBots.AutoRegisterRoles", 2, 0, function()
    for _, bot in pairs(TTTBots.Bots) do
        if not IsValid(bot) then continue end
        local roleString = bot:GetRoleStringRaw()
        local roleObj, isDefault = TTTBots.Roles.GetRole(roleString)
        if isDefault then
            TTTBots.Roles.GenerateRegisterForRole(roleString)
        end
    end
end)

local includedFilesTbl = TTTBots.Lib.IncludeDirectory("tttbots2/roles")
local includedFilesStr = TTTBots.Lib.StringifyTable(includedFilesTbl)
print("[TTT Bots 2] Registered officially supported roles: " .. string.gsub(includedFilesStr, ".lua", ""))

--- Cross-reference all registered roles for unknown ally/enemy references,
--- impossible team combinations, and conflicting flag pairs.
--- Emits actionable warnings before round start.
--- In debug mode (ttt_bot_debug_refactor=1) also prints a full compatibility report.
function TTTBots.Roles.ValidateAllRoles()
    local roles  = TTTBots.Roles.m_roles
    local names  = {}
    local teams  = {}
    for n, r in pairs(roles) do
        names[n] = true
        teams[r:GetTeam()] = true
    end

    local debugMode = TTTBots.Lib.GetConVarBool and TTTBots.Lib.GetConVarBool("debug_refactor")
    local warnings  = {}

    local function warn(msg)
        table.insert(warnings, msg)
        print("[TTT Bots 2][RoleWarn] " .. msg)
    end

    for roleName, role in pairs(roles) do
        -- Unknown AlliedRoles references
        local allied = role:GetAlliedRoles()
        if type(allied) == "table" then
            for ref, _ in pairs(allied) do
                if not names[ref] then
                    warn(string.format("Role '%s': AlliedRoles references unknown role '%s'.", roleName, ref))
                end
            end
        end

        -- Unknown AlliedTeams references
        local alliedTeams = role:GetAlliedTeams()
        if type(alliedTeams) == "table" then
            for ref, _ in pairs(alliedTeams) do
                if not teams[ref] then
                    warn(string.format("Role '%s': AlliedTeams references unregistered team '%s'.", roleName, ref))
                end
            end
        end

        -- Unknown EnemyRoles references
        local enemyRoles = role:GetEnemyRoles()
        if type(enemyRoles) == "table" then
            for ref, _ in pairs(enemyRoles) do
                if not names[ref] then
                    warn(string.format("Role '%s': EnemyRoles references unknown role '%s'.", roleName, ref))
                end
            end
        end

        -- Unknown EnemyTeams references
        local enemyTeams = role:GetEnemyTeams()
        if type(enemyTeams) == "table" then
            for ref, _ in pairs(enemyTeams) do
                if not teams[ref] then
                    warn(string.format("Role '%s': EnemyTeams references unregistered team '%s'.", roleName, ref))
                end
            end
        end

        -- KOSAll + NeutralOverride conflict (cross-check after all roles loaded)
        if role:GetKOSAll() and role:GetNeutralOverride() then
            warn(string.format("Role '%s': KOSAll=true conflicts with NeutralOverride=true.", roleName))
        end

        -- KOSAll + allied with own team but enemies with everyone — sanity
        if role:GetKOSAll() and role:GetLovesTeammates() == false then
            -- This is technically valid (doomguy) but worth noting in debug
            if debugMode then
                print(string.format("[TTT Bots 2][RoleDebug] Role '%s': KOSAll=true with LovesTeammates=false — solo killer.", roleName))
            end
        end
    end

    -- Priest-specific cross-reference: verify ally symmetry against innocent-side roles.
    local priestRole = roles["priest"]
    if priestRole then
        local priestAlliedRoles = priestRole:GetAlliedRoles() or {}
        local priestAlliedTeams = priestRole:GetAlliedTeams() or {}

        for roleName, role in pairs(roles) do
            if roleName == "priest" then continue end
            if role:GetTeam() ~= TEAM_INNOCENT then continue end

            local priestSeesRole =
                (priestAlliedRoles[roleName] == true)
                or (priestAlliedTeams[role:GetTeam()] == true)

            local roleAlliedRoles = role:GetAlliedRoles() or {}
            local roleAlliedTeams = role:GetAlliedTeams() or {}
            local roleSeesPriest =
                (roleAlliedRoles["priest"] == true)
                or (roleAlliedTeams[priestRole:GetTeam()] == true)

            if priestSeesRole ~= roleSeesPriest then
                warn(string.format(
                    "Priest alliance asymmetry: priest->%s=%s, %s->priest=%s.",
                    roleName,
                    tostring(priestSeesRole),
                    roleName,
                    tostring(roleSeesPriest)
                ))
            end
        end
    end

    -- Compatibility report (debug mode only)
    if debugMode then
        print("[TTT Bots 2] === Role Compatibility Report ===")
        local sortedNames = table.GetKeys(roles)
        table.sort(sortedNames)
        for _, n in ipairs(sortedNames) do
            local r    = roles[n]
            local team = r:GetTeam() or "?"
            local kos  = r:GetKOSAll() and "KOSAll" or "-"
            local kosb = r:GetKOSedByAll() and "KOSedByAll" or "-"
            local neut = r:GetNeutralOverride() and "Neutral" or "-"
            local sus  = r:GetUsesSuspicion() and "Sus" or "-"
            print(string.format("  %-20s  team=%-20s  %s %s %s %s",
                n, team, kos, kosb, neut, sus))
        end
        if #warnings > 0 then
            print("[TTT Bots 2] Warnings (" .. #warnings .. "):")
            for _, w in ipairs(warnings) do
                print("  " .. w)
            end
        else
            print("[TTT Bots 2] No warnings.")
        end
        print("[TTT Bots 2] === End Role Compatibility Report ===")
    end
end

-- Schedule validation after all role files have had a chance to finish loading
timer.Simple(0, function()
    TTTBots.Roles.ValidateAllRoles()
end)

if TTTBots.Lib.IsTTT2() then return end

local plyMeta = FindMetaTable("Player")

function plyMeta:GetTeam()
    if self:IsTraitor() then return 'traitors' end
    if self:IsDetective() then return 'detectives' end
    return 'innocents'
end

function plyMeta:IsInTeam(ply1, ply2)
    return ply1:Team() == ply2:Team()
end
