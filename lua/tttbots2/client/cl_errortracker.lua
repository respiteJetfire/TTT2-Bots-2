--- Client-side error tracker receiver.
--- Receives server-side errors forwarded by sv_errortracker.lua and records
--- them into the shared ErrorTracker with a "server" realm tag so the
--- troubleshooting menu can display errors from both realms.

TTTBots = TTTBots or {}

net.Receive("TTTBots_ErrorTracker_Error", function()
    local msg = net.ReadString()
    if not msg or msg == "" then return end

    -- Record with "server" realm so the UI can distinguish origin
    if TTTBots.ErrorTracker then
        TTTBots.ErrorTracker.Record(msg, "server")
    end
end)

-- ---------------------------------------------------------------------------
-- Missing locale event tracking (client side)
-- ---------------------------------------------------------------------------

TTTBots.MissingLocaleEvents = TTTBots.MissingLocaleEvents or {}  -- set: eventName -> true

--- Receive a single newly-discovered missing locale event pushed by the server.
net.Receive("TTTBots_MissingLocale_Add", function()
    local name = net.ReadString()
    if name and name ~= "" then
        TTTBots.MissingLocaleEvents[name] = true
    end
end)

--- Receive the full dump of missing locale events (response to a Request).
net.Receive("TTTBots_MissingLocale_Dump", function()
    local payload = net.ReadString()
    if not payload or payload == "" then return end
    TTTBots.MissingLocaleEvents = {}
    for _, name in ipairs(string.Explode(",", payload)) do
        if name ~= "" then
            TTTBots.MissingLocaleEvents[name] = true
        end
    end
end)
