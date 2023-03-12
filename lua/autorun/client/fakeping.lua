local function CheckCompatibleGamemode() -- ripped from CommonLib
    local compatible = { "terrortown" }
    return table.HasValue(compatible, engine.ActiveGamemode())
end

if not CheckCompatibleGamemode() then return end

local scoreboard = TTTScoreboard

local function getChildByName(panel, name)
    for i, v in pairs(panel:GetChildren()) do
        if v:GetName() == name then
            return v
        end
    end
end

local function printChildrenNames(panel)
    for i, v in pairs(panel:GetChildren()) do
        print(v:GetName())
    end
end

local function GetAvgHumanPing(min)
    local total = 0
    local count = 0

    for _, ply in pairs(player.GetAll()) do
        if ply:IsBot() then continue end

        total = total + ply:Ping()
        count = count + 1
    end
    if count == 0 then return 0 end

    local amt = math.Round(total / count)
    if min then
        return math.max(min, amt)
    end

    return amt
end

local playerPings = {
    -- [nick] = { ping = 0, lastUpdate = 0 } (update very 2 - 3 seconds)
}

local function GetPingForPlayer(nick)
    local baseline = GetAvgHumanPing(50)
    local ping = playerPings[nick]
    if not ping then
        ping = { ping = baseline, lastUpdate = CurTime() }
        playerPings[nick] = ping
    end

    if CurTime() - ping.lastUpdate > 2 + (math.random(1, 10) / 10) then
        local fakeSpike = math.random(0, 100) < 20
        local randomness = math.random(-17, 17) * (fakeSpike and 2 or 1)
        if fakeSpike then randomness = math.abs(randomness) end

        ping.ping = math.max(5, baseline + randomness)
        ping.lastUpdate = CurTime()
    end

    return ping.ping
end

local function UpdatePings()
    local pnl = GAMEMODE:GetScoreboardPanel()
    if not IsValid(pnl) then return end

    for _, group in pairs(pnl.ply_groups) do
        if IsValid(group) then
            for _, row in pairs(group.rows) do
                local pingLabel = row.cols[1]
                local player = row.Player
                if not pingLabel or not player or not IsValid(player) then continue end
                if not player:IsBot() then continue end

                local ping = GetPingForPlayer(player:Nick())

                pingLabel:SetText(ping)
                row:LayoutColumns()
            end
        end
    end
end

local function _sbfunc()
    local pnl = GAMEMODE:GetScoreboardPanel()

    if not IsValid(pnl) then return end
    pnl:UpdateScoreboard()

    UpdatePings()
end

local function HijackScoreboard(tries)
    print("Attempting scoreboard hijack")
    if not scoreboard and tries < 30 then
        timer.Simple(0.1, function()
            HijackScoreboard((tries or 0) + 1)
        end)
        return
    end

    if not timer.Exists("TTTScoreboardUpdater") then
        print "no timer"
        return
    end

    local success = timer.Adjust("TTTScoreboardUpdater", 0.3, 0, function()
        _sbfunc()
    end)
end

HijackScoreboard()

-- we hijack the scoreboard and do this manually because it likes to update
-- the ping of the bots to 0 when it is closed
timer.Create("TTTBots.Client.FakePing2", 0.01, 0, function()
    local pnl = GAMEMODE:GetScoreboardPanel()
    if not (IsValid(pnl) and pnl:IsVisible()) then return end
    UpdatePings()
end)