---------------------------------------------------------------------------
-- Custom Plan Management
--
-- Server-side module that persists admin-created plan presets to JSON,
-- merges them into the main PRESETS table, and handles client<->server
-- networking for the Plans sub-menu CRUD operations.
--
-- Custom plans are stored in data/tttbots2/custom_plans.json and are
-- loaded at startup and after each hot-reload.
--
-- Each custom plan carries a Team field so it only applies to bots on
-- that specific team (e.g. TEAM_TRAITOR, TEAM_JACKAL, etc.).
---------------------------------------------------------------------------

TTTBots.CustomPlans = TTTBots.CustomPlans or {}
local CP = TTTBots.CustomPlans

local DATA_DIR = "tttbots2"
local DATA_FILE = DATA_DIR .. "/custom_plans.json"

--- In-memory store of custom plan data (keyed by plan name).
--- Each entry is a full preset table with Name, Description, Team, Conditions, Jobs.
CP.Plans = CP.Plans or {}

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function CP.Load()
    file.CreateDir(DATA_DIR)
    local raw = file.Read(DATA_FILE, "DATA")
    if raw and raw ~= "" then
        local ok, tbl = pcall(util.JSONToTable, raw)
        if ok and istable(tbl) then
            CP.Plans = tbl
            CP.MergeIntoPresets()
            print("[TTT Bots 2] Loaded " .. table.Count(CP.Plans) .. " custom plan(s).")
            return
        end
    end
    CP.Plans = {}
end

function CP.Save()
    file.CreateDir(DATA_DIR)
    local json = util.TableToJSON(CP.Plans, true)
    if json then
        file.Write(DATA_FILE, json)
    end
end

--- Merge all custom plans into TTTBots.Plans.PRESETS so the plan selection
--- engine considers them alongside built-in presets.
function CP.MergeIntoPresets()
    if not TTTBots.Plans or not TTTBots.Plans.PRESETS then return end
    for name, plan in pairs(CP.Plans) do
        TTTBots.Plans.PRESETS[name] = plan
    end
end

--- Remove a custom plan from PRESETS (but not built-in ones).
function CP.RemoveFromPresets(name)
    if not TTTBots.Plans or not TTTBots.Plans.PRESETS then return end
    if CP.Plans[name] then
        TTTBots.Plans.PRESETS[name] = nil
    end
end

---------------------------------------------------------------------------
-- CRUD Operations
---------------------------------------------------------------------------

--- Validate a plan table has required fields.
--- @param plan table
--- @return boolean valid
--- @return string|nil error message
function CP.ValidatePlan(plan)
    if not plan then return false, "Plan is nil" end
    if not isstring(plan.Name) or plan.Name == "" then return false, "Missing or empty Name" end
    if not isstring(plan.Description) then plan.Description = "" end
    if not isstring(plan.Team) or plan.Team == "" then return false, "Missing Team" end
    if not istable(plan.Conditions) then return false, "Missing Conditions table" end
    if not istable(plan.Jobs) or #plan.Jobs == 0 then return false, "Missing or empty Jobs table" end

    -- Validate each job
    local ACTIONS = TTTBots.Plans.ACTIONS
    local TARGETS = TTTBots.Plans.PLANTARGETS

    -- Build lookup tables for valid actions and targets
    local validActions = {}
    for _, v in pairs(ACTIONS) do validActions[v] = true end
    local validTargets = {}
    for _, v in pairs(TARGETS) do validTargets[v] = true end

    for i, job in ipairs(plan.Jobs) do
        if not validActions[job.Action] then
            return false, "Job " .. i .. " has invalid Action: " .. tostring(job.Action)
        end
        if not validTargets[job.Target] then
            return false, "Job " .. i .. " has invalid Target: " .. tostring(job.Target)
        end
        job.Chance = tonumber(job.Chance) or 100
        job.MaxAssigned = tonumber(job.MaxAssigned) or 99
        job.MinDuration = tonumber(job.MinDuration) or 15
        job.MaxDuration = tonumber(job.MaxDuration) or 60
        if job.Repeat == nil then job.Repeat = false end
        if not istable(job.Conditions) then job.Conditions = {} end
    end

    -- Sanitize conditions
    plan.Conditions.Chance = tonumber(plan.Conditions.Chance) or 100
    plan.Conditions.PlyMin = tonumber(plan.Conditions.PlyMin)
    plan.Conditions.PlyMax = tonumber(plan.Conditions.PlyMax)
    plan.Conditions.MinTraitors = tonumber(plan.Conditions.MinTraitors)
    plan.Conditions.MaxTraitors = tonumber(plan.Conditions.MaxTraitors)

    return true
end

--- Create a new custom plan.
--- @param plan table  the plan preset data
--- @return boolean success
--- @return string|nil error
function CP.Create(plan)
    local valid, err = CP.ValidatePlan(plan)
    if not valid then return false, err end

    local name = plan.Name
    if CP.Plans[name] then
        return false, "A custom plan with this name already exists"
    end

    -- Strip any SynergyScore function (can't persist functions to JSON)
    plan.SynergyScore = nil
    plan.IsCustom = true

    CP.Plans[name] = plan
    CP.Save()
    CP.MergeIntoPresets()
    return true
end

--- Update an existing custom plan.
--- @param name string  the name of the plan to update
--- @param plan table  the new plan data
--- @return boolean success
--- @return string|nil error
function CP.Update(name, plan)
    if not CP.Plans[name] then
        return false, "Custom plan not found: " .. tostring(name)
    end

    local valid, err = CP.ValidatePlan(plan)
    if not valid then return false, err end

    -- If the name changed, remove the old entry
    if plan.Name ~= name then
        CP.RemoveFromPresets(name)
        CP.Plans[name] = nil
    end

    plan.SynergyScore = nil
    plan.IsCustom = true

    CP.Plans[plan.Name] = plan
    CP.Save()
    CP.MergeIntoPresets()
    return true
end

--- Delete a custom plan.
--- @param name string
--- @return boolean success
function CP.Delete(name)
    if not CP.Plans[name] then return false end
    CP.RemoveFromPresets(name)
    CP.Plans[name] = nil
    CP.Save()
    return true
end

--- Get all custom plans as a list (for networking).
--- @return table plans  list of plan tables
function CP.GetAll()
    local result = {}
    for name, plan in pairs(CP.Plans) do
        result[#result + 1] = plan
    end
    return result
end

--- Get custom plans filtered by team.
--- @param team string
--- @return table plans
function CP.GetForTeam(team)
    local result = {}
    for name, plan in pairs(CP.Plans) do
        if plan.Team == team then
            result[#result + 1] = plan
        end
    end
    return result
end

---------------------------------------------------------------------------
-- Networking
---------------------------------------------------------------------------

--- Send all custom plans to a client (compressed JSON).
--- @param ply Player
function CP.SyncToClient(ply)
    if not IsValid(ply) then return end
    local payload = {
        Plans = CP.Plans,
        --- Include the list of valid ACTIONS and PLANTARGETS for the menu
        Actions = TTTBots.Plans.ACTIONS,
        Targets = TTTBots.Plans.PLANTARGETS,
    }
    local json = util.TableToJSON(payload)
    local compressed = util.Compress(json)

    net.Start("TTTBots_CustomPlan_Sync")
    net.WriteUInt(#compressed, 32)
    net.WriteData(compressed, #compressed)
    net.Send(ply)
end

--- Handle client request to sync custom plans
net.Receive("TTTBots_CustomPlan_RequestSync", function(len, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() then return end
    CP.SyncToClient(ply)
end)

--- Handle client request to create a custom plan
net.Receive("TTTBots_CustomPlan_Create", function(len, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() then return end

    local dataLen = net.ReadUInt(32)
    local data = net.ReadData(dataLen)
    local json = util.Decompress(data)
    if not json then return end
    local plan = util.JSONToTable(json)
    if not plan then return end

    local ok, err = CP.Create(plan)
    if ok then
        -- Sync updated plans back to the requesting client
        CP.SyncToClient(ply)
        TTTBots.Chat.MessagePlayer(ply, "Custom plan '" .. plan.Name .. "' created successfully.")
    else
        TTTBots.Chat.MessagePlayer(ply, "Failed to create plan: " .. (err or "unknown error"))
    end
end)

--- Handle client request to update a custom plan
net.Receive("TTTBots_CustomPlan_Update", function(len, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() then return end

    local oldName = net.ReadString()
    local dataLen = net.ReadUInt(32)
    local data = net.ReadData(dataLen)
    local json = util.Decompress(data)
    if not json then return end
    local plan = util.JSONToTable(json)
    if not plan then return end

    local ok, err = CP.Update(oldName, plan)
    if ok then
        CP.SyncToClient(ply)
        TTTBots.Chat.MessagePlayer(ply, "Custom plan '" .. plan.Name .. "' updated successfully.")
    else
        TTTBots.Chat.MessagePlayer(ply, "Failed to update plan: " .. (err or "unknown error"))
    end
end)

--- Handle client request to delete a custom plan
net.Receive("TTTBots_CustomPlan_Delete", function(len, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() then return end

    local name = net.ReadString()
    local ok = CP.Delete(name)
    if ok then
        CP.SyncToClient(ply)
        TTTBots.Chat.MessagePlayer(ply, "Custom plan '" .. name .. "' deleted.")
    else
        TTTBots.Chat.MessagePlayer(ply, "Failed to delete plan: not found.")
    end
end)

---------------------------------------------------------------------------
-- Initial load
---------------------------------------------------------------------------
CP.Load()

print("[TTT Bots 2] Custom plans module loaded.")
