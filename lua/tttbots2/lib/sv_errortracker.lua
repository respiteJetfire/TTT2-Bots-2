--- Server-side error tracker networking.
--- Forwards errors captured by sh_errortracker.lua to all connected admin
--- clients so they appear in the troubleshooting menu.

TTTBots = TTTBots or {}
TTTBots.ErrorTrackerNet = TTTBots.ErrorTrackerNet or {}

local ETN = TTTBots.ErrorTrackerNet

--- Broadcast a single error message to all connected admins.
---@param msg string  The full error message (including stack trace).
function ETN.BroadcastError(msg)
    if not SERVER then return end

    -- Truncate very long messages to fit in a net message
    local truncated = string.sub(msg or "", 1, 4096)

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and not ply:IsBot() and ply:IsAdmin() then
            net.Start("TTTBots_ErrorTracker_Error")
                net.WriteString(truncated)
            net.Send(ply)
        end
    end
end

--- Broadcast a newly-discovered missing locale event name to all admin clients.
---@param eventName string
function ETN.BroadcastMissingLocale(eventName)
    if not SERVER then return end
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and not ply:IsBot() and ply:IsAdmin() then
            net.Start("TTTBots_MissingLocale_Add")
                net.WriteString(eventName)
            net.Send(ply)
        end
    end
end

--- Handle client requesting the full missing-locale dump.
net.Receive("TTTBots_MissingLocale_Request", function(len, ply)
    if not (IsValid(ply) and ply:IsAdmin()) then return end
    local missing = TTTBots.Locale and TTTBots.Locale.MissingEvents or {}
    local names = {}
    for k in pairs(missing) do table.insert(names, k) end
    table.sort(names)
    local payload = table.concat(names, ",")
    net.Start("TTTBots_MissingLocale_Dump")
        net.WriteString(payload)
    net.Send(ply)
end)
