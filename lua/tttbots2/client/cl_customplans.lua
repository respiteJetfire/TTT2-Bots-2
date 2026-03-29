---------------------------------------------------------------------------
-- Client-Side Custom Plan Networking
--
-- Handles receiving custom plan data from the server and provides
-- functions for the Plans sub-menu to send CRUD requests.
---------------------------------------------------------------------------

TTTBots = TTTBots or {}
TTTBots.CustomPlansClient = TTTBots.CustomPlansClient or {}
local CPC = TTTBots.CustomPlansClient

--- Cached custom plans received from the server
CPC.Plans = CPC.Plans or {}
--- Valid ACTIONS enum received from server
CPC.Actions = CPC.Actions or {}
--- Valid PLANTARGETS enum received from server
CPC.Targets = CPC.Targets or {}
--- Callback to refresh the menu when data changes
CPC.OnSyncCallback = nil

---------------------------------------------------------------------------
-- Receiving sync data
---------------------------------------------------------------------------

net.Receive("TTTBots_CustomPlan_Sync", function()
    local dataLen = net.ReadUInt(32)
    local data = net.ReadData(dataLen)
    local json = util.Decompress(data)
    if not json then return end
    local payload = util.JSONToTable(json)
    if not payload then return end

    CPC.Plans = payload.Plans or {}
    CPC.Actions = payload.Actions or {}
    CPC.Targets = payload.Targets or {}

    -- Notify the menu to refresh if a callback is registered
    if CPC.OnSyncCallback then
        CPC.OnSyncCallback()
    end
end)

---------------------------------------------------------------------------
-- Sending CRUD requests
---------------------------------------------------------------------------

--- Request the server to send all custom plans
function CPC.RequestSync()
    net.Start("TTTBots_CustomPlan_RequestSync")
    net.SendToServer()
end

--- Request creation of a new plan
--- @param plan table  the plan preset data
function CPC.CreatePlan(plan)
    local json = util.TableToJSON(plan)
    local compressed = util.Compress(json)
    if not compressed then return end

    net.Start("TTTBots_CustomPlan_Create")
    net.WriteUInt(#compressed, 32)
    net.WriteData(compressed, #compressed)
    net.SendToServer()
end

--- Request update of an existing plan
--- @param oldName string  the original name of the plan
--- @param plan table  the updated plan data
function CPC.UpdatePlan(oldName, plan)
    local json = util.TableToJSON(plan)
    local compressed = util.Compress(json)
    if not compressed then return end

    net.Start("TTTBots_CustomPlan_Update")
    net.WriteString(oldName)
    net.WriteUInt(#compressed, 32)
    net.WriteData(compressed, #compressed)
    net.SendToServer()
end

--- Request deletion of a custom plan
--- @param name string
function CPC.DeletePlan(name)
    net.Start("TTTBots_CustomPlan_Delete")
    net.WriteString(name)
    net.SendToServer()
end

--- Get plans filtered by team (from client cache)
--- @param team string
--- @return table plans
function CPC.GetPlansForTeam(team)
    local result = {}
    for name, plan in pairs(CPC.Plans) do
        if plan.Team == team then
            result[#result + 1] = plan
        end
    end
    table.sort(result, function(a, b) return a.Name < b.Name end)
    return result
end

--- Get all available teams from the cached plans + known TTT2 teams
--- @return table teams  list of team strings excluding innocents
function CPC.GetAvailableTeams()
    local teamSet = {}
    -- Always include traitors
    teamSet[TEAM_TRAITOR or "traitors"] = true

    -- Add teams from existing custom plans
    for _, plan in pairs(CPC.Plans) do
        if plan.Team and plan.Team ~= TEAM_INNOCENT and plan.Team ~= TEAM_NONE then
            teamSet[plan.Team] = true
        end
    end

    -- Add teams from TTT2's TEAMS global if available
    if TEAMS then
        for teamName, teamData in pairs(TEAMS) do
            if teamName ~= TEAM_INNOCENT and teamName ~= TEAM_NONE then
                teamSet[teamName] = true
            end
        end
    end

    local result = {}
    for team in pairs(teamSet) do
        result[#result + 1] = team
    end
    table.sort(result)
    return result
end
