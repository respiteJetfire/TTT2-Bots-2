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
