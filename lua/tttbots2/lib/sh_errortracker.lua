--- Shared error tracker for TTT Bots 2.
--- Captures Lua errors originating from this addon on both client and server,
--- stores them in a collated list (duplicate messages get a counter), and
--- provides a simple API for the troubleshooting menu.
---
--- Server-side errors are forwarded to all connected admins via net messages
--- (see sv_errortracker.lua / cl_errortracker.lua).

TTTBots = TTTBots or {}
TTTBots.ErrorTracker = TTTBots.ErrorTracker or {}

local ET = TTTBots.ErrorTracker

--- Maximum number of unique error entries we keep (FIFO).
ET.MAX_ENTRIES = 200

--- Internal list of tracked errors.
--- Each entry: { msg = string, count = number, firstSeen = number, lastSeen = number, realm = string }
ET._errors = ET._errors or {}

--- Quick lookup: normalised message -> index into _errors
ET._index = ET._index or {}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

--- Normalise an error string so minor cosmetic differences collapse.
---@param msg string
---@return string
local function normalise(msg)
    -- Strip leading/trailing whitespace
    msg = string.Trim(msg or "")
    -- Remove file-path drive letters (C:\ etc.) for cross-platform consistency
    msg = msg:gsub("^%a:\\", "")
    return msg
end

--- Checks whether an error message originates from TTT Bots 2 code.
---@param msg string  The raw error/stack string from the engine.
---@return boolean
local function isOurError(msg)
    if not msg then return false end
    local lower = msg:lower()
    return lower:find("tttbots2", 1, true) ~= nil
        or lower:find("tttbots", 1, true) ~= nil
        or lower:find("ttt bots", 1, true) ~= nil
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Record an error.  Duplicate messages increment the counter.
---@param rawMsg string  The error message (may include stack trace).
---@param realm string   "client" or "server"
function ET.Record(rawMsg, realm)
    local key = normalise(rawMsg)
    if key == "" then return end

    local now = CurTime()

    local idx = ET._index[key]
    if idx then
        -- Existing entry — bump counter and timestamp
        local entry = ET._errors[idx]
        if entry then
            entry.count = entry.count + 1
            entry.lastSeen = now
            return
        end
    end

    -- New entry
    local entry = {
        msg       = rawMsg,
        count     = 1,
        firstSeen = now,
        lastSeen  = now,
        realm     = realm or (CLIENT and "client" or "server"),
    }

    -- FIFO eviction
    if #ET._errors >= ET.MAX_ENTRIES then
        -- Remove oldest entry and its index
        local old = table.remove(ET._errors, 1)
        if old then
            ET._index[normalise(old.msg)] = nil
        end
        -- Rebuild index (shift everything down by 1)
        ET._index = {}
        for i, e in ipairs(ET._errors) do
            ET._index[normalise(e.msg)] = i
        end
    end

    table.insert(ET._errors, entry)
    ET._index[key] = #ET._errors
end

--- Return the current list of error entries (read-only snapshot).
---@return table[]
function ET.GetAll()
    return ET._errors
end

--- Clear all tracked errors.
function ET.Clear()
    ET._errors = {}
    ET._index = {}
end

--- Build a single string suitable for clipboard copy.
---@return string
function ET.ToClipboardString()
    local lines = {}
    table.insert(lines, "=== TTT Bots 2 — Error Log ===")
    table.insert(lines, string.format("Exported: %s  |  Entries: %d", os.date("%Y-%m-%d %H:%M:%S"), #ET._errors))
    table.insert(lines, "")

    for i, e in ipairs(ET._errors) do
        local countStr = e.count > 1 and string.format(" x%d", e.count) or ""
        local realmTag = string.upper(e.realm or "?")
        table.insert(lines, string.format("[%d] [%s]%s  %s", i, realmTag, countStr, e.msg))
    end

    if #ET._errors == 0 then
        table.insert(lines, "(no errors recorded)")
    end

    table.insert(lines, "")
    table.insert(lines, "=== End of Log ===")
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Automatic capture via hook
---------------------------------------------------------------------------

--- Hook into Garry's Mod's OnLuaError (fires on both client and server).
--- We filter to only record errors that originate from our addon files.
hook.Add("OnLuaError", "TTTBots_ErrorTracker", function(msg, realm, stack, _name, _id)
    -- msg   = error string
    -- realm = "client" / "server" (string) or bool in some engine versions
    -- stack = stack trace string or table

    local fullMsg = tostring(msg or "")

    -- Append stack trace if available
    if stack and stack ~= "" then
        if istable(stack) then
            local parts = {}
            for _, frame in ipairs(stack) do
                table.insert(parts, string.format("  %s:%d in %s", frame.File or "?", frame.Line or 0, frame.Function or "?"))
            end
            fullMsg = fullMsg .. "\n" .. table.concat(parts, "\n")
        else
            fullMsg = fullMsg .. "\n" .. tostring(stack)
        end
    end

    -- Only track errors from our addon
    if not isOurError(fullMsg) then return end

    local realmStr = "unknown"
    if CLIENT then
        realmStr = "client"
    elseif SERVER then
        realmStr = "server"
    end

    ET.Record(fullMsg, realmStr)

    -- On the server, also forward to all admin clients
    if SERVER and TTTBots.ErrorTrackerNet then
        TTTBots.ErrorTrackerNet.BroadcastError(fullMsg)
    end
end)
