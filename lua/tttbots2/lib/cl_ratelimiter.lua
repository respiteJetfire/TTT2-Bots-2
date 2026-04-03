-- cl_ratelimiter.lua
-- Client-side receiver for the rate limiter / cost tracker admin dashboard.
-- Stats are networked from sv_providers.lua every 5 seconds to admins.

TTTBots = TTTBots or {}
TTTBots.RateLimiterStats = TTTBots.RateLimiterStats or {}

net.Receive("TTTBots_RateLimiterStats", function()
    TTTBots.RateLimiterStats = {
        rpm            = net.ReadUInt(16),
        maxRPM         = net.ReadUInt(16),
        roundRequests  = net.ReadUInt(16),
        maxPerRound    = net.ReadUInt(16),
        roundTokens    = net.ReadUInt(32),
        totalTokens    = net.ReadUInt(32),
        roundCost      = net.ReadFloat(),
        totalCost      = net.ReadFloat(),
        budgetPerRound = net.ReadFloat(),
        roundRejected  = net.ReadUInt(16),
        roundAllowed   = net.ReadUInt(16),
        lastUpdate     = CurTime(),
    }
end)
