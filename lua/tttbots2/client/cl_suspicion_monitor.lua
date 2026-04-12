---------------------------------------------------------------------------
-- cl_suspicion_monitor.lua
-- Real-time suspicion monitoring UI for TTT2-Bots-2.
--
-- Shows:
--   Tab 1 — Live Event Feed:  scrolling log of every suspicion change as it
--           happens, colour-coded by severity, with threshold-cross alerts.
--   Tab 2 — Suspicion Matrix:  grid of Bot × Player with colour-coded cells
--           showing current suspicion values at a glance.
--   Tab 3 — Bot Detail:  select a bot and see its full suspicion breakdown
--           for every player, plus role guesses and attack target.
--
-- Opens via:  ttt_bot_suspicion_monitor   (console command, superadmin only)
---------------------------------------------------------------------------

TTTBots = TTTBots or {}
TTTBots.SuspicionMonitor = TTTBots.SuspicionMonitor or {}

local SM = TTTBots.SuspicionMonitor

-- -----------------------------------------------------------------------
-- State
-- -----------------------------------------------------------------------

local isRequesting   = false
local monitorWindow  = nil
local suspicionData  = nil     -- latest decoded payload from server
local eventLog       = {}      -- accumulated event list across refreshes
local lastEventIndex = 0       -- how many events the server has sent us so far

-- -----------------------------------------------------------------------
-- Colours
-- -----------------------------------------------------------------------

local C = {
    BG        = Color(25, 25, 30, 255),
    PANEL     = Color(35, 35, 40, 255),
    HEADER    = Color(55, 55, 65, 255),
    WHITE     = Color(220, 220, 220, 255),
    DIMWHITE  = Color(160, 160, 165, 255),
    GRAY      = Color(120, 120, 125, 255),
    GREEN     = Color(80, 200, 80, 255),
    YELLOW    = Color(220, 200, 60, 255),
    ORANGE    = Color(230, 150, 50, 255),
    RED       = Color(220, 70, 70, 255),
    DARKRED   = Color(160, 40, 40, 255),
    BLUE      = Color(80, 140, 220, 255),
    CYAN      = Color(80, 200, 210, 255),
    GOLD      = Color(255, 215, 0, 255),
    PURPLE    = Color(180, 100, 220, 255),
    MAGENTA   = Color(220, 80, 180, 255),
    -- Threshold-specific
    KOS_BG    = Color(200, 50, 50, 40),
    SUS_BG    = Color(200, 160, 40, 30),
    TRUST_BG  = Color(50, 160, 50, 30),
    INNO_BG   = Color(40, 120, 200, 30),
}

-- -----------------------------------------------------------------------
-- Networking
-- -----------------------------------------------------------------------

net.Receive("TTTBots_SuspicionData", function()
    local bytes = net.ReadUInt(32)
    local compressed = net.ReadData(bytes)
    local json = util.Decompress(compressed)
    if not json then return end
    suspicionData = util.JSONToTable(json)
    if not suspicionData then return end

    -- Merge new events into our local log
    if suspicionData.events and #suspicionData.events > 0 then
        for _, ev in ipairs(suspicionData.events) do
            eventLog[#eventLog + 1] = ev
        end
        lastEventIndex = suspicionData.eventTotal or lastEventIndex
    end
end)

timer.Create("TTTBots.Client.RequestSuspicionData", 0.5, 0, function()
    if not isRequesting then return end
    net.Start("TTTBots_RequestSuspicionData")
    net.WriteUInt(lastEventIndex, 32)
    net.SendToServer()
end)

-- -----------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------

local function SusColor(value, thresholds)
    if not thresholds then thresholds = { KOS = 10, Sus = 5, Trust = -3, Innocent = -7 } end
    -- Accept either a raw number or a table with an 'eff' field
    if type(value) == "table" then value = value.eff or 0 end
    if value >= thresholds.KOS then return C.RED end
    if value >= thresholds.Sus then return C.ORANGE end
    if value > 0 then return C.YELLOW end
    if value == 0 then return C.DIMWHITE end
    if value <= thresholds.Innocent then return C.CYAN end
    if value <= thresholds.Trust then return C.GREEN end
    return C.DIMWHITE
end

local function SusBgColor(value, thresholds)
    if not thresholds then thresholds = { KOS = 10, Sus = 5, Trust = -3, Innocent = -7 } end
    if type(value) == "table" then value = value.eff or 0 end
    if value >= thresholds.KOS then return C.KOS_BG end
    if value >= thresholds.Sus then return C.SUS_BG end
    if value <= thresholds.Innocent then return C.INNO_BG end
    if value <= thresholds.Trust then return C.TRUST_BG end
    return Color(40, 40, 45, 255)
end

local function DeltaColor(delta)
    if delta > 0 then return C.RED end
    if delta < 0 then return C.GREEN end
    return C.GRAY
end

local function ThresholdBadge(thr)
    if thr == "KOS" then return " !! KOS CROSSED !!", C.RED end
    if thr == "Sus" then return " ! SUS CROSSED !", C.ORANGE end
    if thr == "Trust" then return " ✓ TRUSTED", C.GREEN end
    if thr == "Innocent" then return " ✓✓ INNOCENT", C.CYAN end
    return nil, nil
end

local function AddLabel(parent, text, color, font)
    local lbl = vgui.Create("DLabel", parent)
    lbl:SetFont(font or "DermaDefault")
    lbl:SetTextColor(color or C.WHITE)
    lbl:SetText(text)
    lbl:Dock(TOP)
    lbl:DockMargin(6, 1, 6, 1)
    lbl:SizeToContents()
    return lbl
end

local function AddDivider(parent)
    local div = vgui.Create("DPanel", parent)
    div:SetTall(1)
    div:Dock(TOP)
    div:DockMargin(4, 3, 4, 3)
    div.Paint = function(_, w, h)
        surface.SetDrawColor(70, 70, 80, 255)
        surface.DrawRect(0, 0, w, h)
    end
    return div
end

-- -----------------------------------------------------------------------
-- Tab 1: Live Event Feed
-- -----------------------------------------------------------------------

local eventScroll     = nil
local autoScrollEvent = true
local lastRenderedEventCount = 0

local function PopulateEventFeed()
    if not eventScroll then return end
    if not suspicionData then
        if lastRenderedEventCount == 0 then
            eventScroll:Clear()
            AddLabel(eventScroll, "Waiting for data from server...", C.YELLOW)
            lastRenderedEventCount = -1  -- sentinel
        end
        return
    end

    local thresholds = suspicionData.thresholds

    -- Only add NEW events (incremental rendering)
    local startFrom = (lastRenderedEventCount < 0) and 1 or (lastRenderedEventCount + 1)
    if startFrom > #eventLog then return end

    -- If we had the "waiting" message, clear it first
    if lastRenderedEventCount < 0 then
        eventScroll:Clear()
    end

    for i = startFrom, #eventLog do
        local ev = eventLog[i]

        -- Build the event line
        local deltaSign = ev.d > 0 and "+" or ""
        local timeStr = string.format("[%5.1fs]", ev.rt or 0)
        local mainText = string.format("%s  %s → %s :  %s  %s%d  (= %d)",
            timeStr, ev.bot, ev.tgt, ev.rsn, deltaSign, ev.d, ev.tot)

        -- Extra info
        local extras = {}
        if ev.mul and ev.mul ~= 1 then extras[#extras + 1] = string.format("mult=%.2f", ev.mul) end
        if ev.prs and ev.prs ~= 1 then extras[#extras + 1] = string.format("pressure=%.2f", ev.prs) end
        if ev.raw then extras[#extras + 1] = string.format("raw=%d", ev.raw) end
        -- Multi-dimensional channel info
        if ev.threat then extras[#extras + 1] = string.format("T=%.1f", ev.threat) end
        if ev.trust then extras[#extras + 1] = string.format("Tr=%.1f", ev.trust) end
        if ev.conf then extras[#extras + 1] = string.format("C=%.2f", ev.conf) end
        if #extras > 0 then
            mainText = mainText .. "  [" .. table.concat(extras, ", ") .. "]"
        end

        -- Colour based on delta direction
        local lineColor = DeltaColor(ev.d)

        -- Create the event panel
        local evPanel = vgui.Create("DPanel", eventScroll)
        evPanel:SetTall(18)
        evPanel:Dock(TOP)
        evPanel:DockMargin(2, 0, 2, 0)

        local bgColor = Color(35, 35, 40, 255)
        if ev.thr then
            if ev.thr == "KOS" then bgColor = Color(120, 30, 30, 80)
            elseif ev.thr == "Sus" then bgColor = Color(120, 100, 20, 60)
            elseif ev.thr == "Trust" then bgColor = Color(30, 100, 30, 60)
            elseif ev.thr == "Innocent" then bgColor = Color(30, 80, 120, 60)
            end
        end

        evPanel.Paint = function(_, w, h)
            surface.SetDrawColor(bgColor)
            surface.DrawRect(0, 0, w, h)
        end

        local lbl = vgui.Create("DLabel", evPanel)
        lbl:SetFont("DermaDefault")
        lbl:SetTextColor(lineColor)
        lbl:SetText(mainText)
        lbl:Dock(FILL)
        lbl:DockMargin(4, 0, 4, 0)

        -- Threshold badge
        if ev.thr then
            local badge, badgeCol = ThresholdBadge(ev.thr)
            if badge then
                local badgeLbl = vgui.Create("DLabel", evPanel)
                badgeLbl:SetFont("DermaDefaultBold")
                badgeLbl:SetTextColor(badgeCol)
                badgeLbl:SetText(badge)
                badgeLbl:Dock(RIGHT)
                badgeLbl:DockMargin(0, 0, 8, 0)
                badgeLbl:SizeToContents()
            end
        end
    end

    lastRenderedEventCount = #eventLog

    -- Auto-scroll to bottom
    if autoScrollEvent then
        local vbar = eventScroll:GetVBar()
        if vbar then
            timer.Simple(0, function()
                if IsValid(vbar) then vbar:SetScroll(vbar.CanvasSize) end
            end)
        end
    end
end

-- -----------------------------------------------------------------------
-- Tab 2: Suspicion Matrix
-- -----------------------------------------------------------------------

local matrixScroll = nil

local function PopulateMatrix()
    if not matrixScroll then return end
    matrixScroll:Clear()

    if not suspicionData or not suspicionData.snapshot then
        AddLabel(matrixScroll, "Waiting for data...", C.YELLOW)
        return
    end

    local thresholds = suspicionData.thresholds
    local snapshot = suspicionData.snapshot

    -- Collect all unique target names across all bots
    local targetSet = {}
    local botNames = {}
    for botName, data in SortedPairs(snapshot) do
        botNames[#botNames + 1] = botName
        for targetName, _ in pairs(data.sus or {}) do
            targetSet[targetName] = true
        end
    end
    local targetNames = {}
    for name, _ in SortedPairs(targetSet) do
        targetNames[#targetNames + 1] = name
    end

    if #botNames == 0 then
        AddLabel(matrixScroll, "No bots active.", C.GRAY)
        return
    end

    -- Header: round state
    local roundText = suspicionData.roundActive
        and string.format("Round Active  |  Time: %.1fs", suspicionData.roundTime or 0)
        or "Round Inactive"
    AddLabel(matrixScroll, roundText, suspicionData.roundActive and C.GREEN or C.GRAY, "DermaDefaultBold")

    -- Legend
    AddLabel(matrixScroll,
        string.format("Thresholds — KOS: ≥%d  |  Sus: ≥%d  |  Trust: ≤%d  |  Innocent: ≤%d",
            thresholds.KOS, thresholds.Sus, thresholds.Trust, thresholds.Innocent),
        C.DIMWHITE)
    AddDivider(matrixScroll)

    -- Build a grid-like display using DListView
    if #targetNames == 0 then
        AddLabel(matrixScroll, "No suspicion data yet — bots haven't formed opinions.", C.GRAY)
        return
    end

    -- For each bot, show a row with their suspicions
    for _, botName in ipairs(botNames) do
        local botData = snapshot[botName]
        local meta = botData.meta or {}
        local susMap = botData.sus or {}

        -- Bot header
        local roleStr = meta.role and (" [" .. meta.role .. "]") or ""
        local phaseStr = meta.phase and ("  Phase: " .. meta.phase) or ""
        local atkStr = meta.atkTarget and ("  ATK: " .. meta.atkTarget .. " (" .. (meta.atkReason or "?") .. ")") or ""

        local headerPanel = vgui.Create("DPanel", matrixScroll)
        headerPanel:SetTall(22)
        headerPanel:Dock(TOP)
        headerPanel:DockMargin(2, 4, 2, 0)
        headerPanel.Paint = function(_, w, h)
            surface.SetDrawColor(C.HEADER)
            surface.DrawRect(0, 0, w, h)
        end
        local headerLbl = vgui.Create("DLabel", headerPanel)
        headerLbl:SetFont("DermaDefaultBold")
        headerLbl:SetTextColor(C.GOLD)
        headerLbl:SetText("  " .. botName .. roleStr .. phaseStr .. atkStr)
        headerLbl:Dock(FILL)

        -- Suspicion values — compact horizontal layout
        local susPanel = vgui.Create("DPanel", matrixScroll)
        susPanel:Dock(TOP)
        susPanel:DockMargin(8, 0, 8, 0)
        susPanel:SetPaintBackground(false)

        -- Use a DIconLayout for nice wrapping
        local layout = vgui.Create("DIconLayout", susPanel)
        layout:Dock(FILL)
        layout:SetSpaceX(4)
        layout:SetSpaceY(2)

        -- Sort targets by suspicion value (highest first)
        local sorted = {}
        for _, tgtName in ipairs(targetNames) do
            local entry = susMap[tgtName]
            local val = 0
            local thr, tru, conf = 0, 0, 0
            if type(entry) == "table" then
                val  = entry.eff or 0
                thr  = entry.thr or 0
                tru  = entry.tru or 0
                conf = entry.conf or 0
            elseif type(entry) == "number" then
                val = entry
            end
            sorted[#sorted + 1] = { name = tgtName, value = val, thr = thr, tru = tru, conf = conf }
        end
        table.sort(sorted, function(a, b) return a.value > b.value end)

        local cellHeight = 20
        for _, entry in ipairs(sorted) do
            local val = entry.value
            if val == 0 and entry.thr == 0 and entry.tru == 0 then continue end  -- skip zeros for cleaner display

            local cell = vgui.Create("DPanel", layout)
            local textStr
            if entry.thr > 0 or entry.tru > 0 then
                textStr = string.format("%s: %+d (T:%.0f Tr:%.0f C:%.0f%%)", entry.name, val, entry.thr, entry.tru, entry.conf * 100)
            else
                textStr = string.format("%s: %+d", entry.name, val)
            end

            -- Calculate width based on text
            surface.SetFont("DermaDefault")
            local tw, _ = surface.GetTextSize(textStr)
            cell:SetSize(tw + 16, cellHeight)

            local cellBg = SusBgColor(val, thresholds)
            local cellFg = SusColor(val, thresholds)

            cell.Paint = function(_, w, h)
                surface.SetDrawColor(cellBg)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(60, 60, 70, 200)
                surface.DrawOutlinedRect(0, 0, w, h)
            end

            local cellLbl = vgui.Create("DLabel", cell)
            cellLbl:SetFont("DermaDefault")
            cellLbl:SetTextColor(cellFg)
            cellLbl:SetText(textStr)
            cellLbl:Dock(FILL)
            cellLbl:SetContentAlignment(5) -- center
        end

        -- Calculate height based on number of cells
        local numCells = #sorted
        -- Filter zeros
        local nonZero = 0
        for _, e in ipairs(sorted) do if e.value ~= 0 or e.thr > 0 or e.tru > 0 then nonZero = nonZero + 1 end end

        -- Estimate rows (approx 8 cells per row at ~120px each in ~900px panel)
        local estRows = math.max(1, math.ceil(nonZero / 7))
        susPanel:SetTall(estRows * (cellHeight + 4) + 4)

        -- Role guesses
        if meta.guesses and next(meta.guesses) then
            local guessStrs = {}
            for tgt, role in SortedPairs(meta.guesses) do
                guessStrs[#guessStrs + 1] = tgt .. "=" .. role
            end
            AddLabel(matrixScroll, "    Guesses: " .. table.concat(guessStrs, ", "), C.PURPLE)
        end
    end
end

-- -----------------------------------------------------------------------
-- Tab 3: Bot Detail View
-- -----------------------------------------------------------------------

local detailScroll   = nil
local detailCombo    = nil
local selectedBot    = nil

local function PopulateBotDetail()
    if not detailScroll then return end
    detailScroll:Clear()

    if not suspicionData or not suspicionData.snapshot then
        AddLabel(detailScroll, "Waiting for data...", C.YELLOW)
        return
    end

    local thresholds = suspicionData.thresholds

    -- Update combo box options
    if detailCombo then
        local existingItems = {}
        for _, item in ipairs(detailCombo.Choices or {}) do
            existingItems[item] = true
        end
        for botName, _ in SortedPairs(suspicionData.snapshot) do
            if not existingItems[botName] then
                detailCombo:AddChoice(botName)
            end
        end
    end

    if not selectedBot then
        AddLabel(detailScroll, "Select a bot from the dropdown above.", C.GRAY)
        return
    end

    local botData = suspicionData.snapshot[selectedBot]
    if not botData then
        AddLabel(detailScroll, "Bot '" .. selectedBot .. "' not found in snapshot.", C.RED)
        return
    end

    local meta = botData.meta or {}
    local susMap = botData.sus or {}

    -- Header
    AddLabel(detailScroll, selectedBot, C.GOLD, "DermaDefaultBold")
    if meta.role then AddLabel(detailScroll, "  Role: " .. meta.role .. " (" .. (meta.team or "?") .. ")", C.CYAN) end
    if meta.phase then AddLabel(detailScroll, "  Phase: " .. meta.phase, C.DIMWHITE) end
    if meta.atkTarget then
        AddLabel(detailScroll,
            "  Attack Target: " .. meta.atkTarget .. " (" .. (meta.atkReason or "?") .. ")",
            C.RED, "DermaDefaultBold")
    end

    AddDivider(detailScroll)
    AddLabel(detailScroll, "Suspicion Breakdown", C.CYAN, "DermaDefaultBold")

    -- Sort targets by value
    local sorted = {}
    for tgt, entry in pairs(susMap) do
        local val = 0
        local thr, tru, conf = 0, 0, 0
        if type(entry) == "table" then
            val  = entry.eff or 0
            thr  = entry.thr or 0
            tru  = entry.tru or 0
            conf = entry.conf or 0
        elseif type(entry) == "number" then
            val = entry
        end
        sorted[#sorted + 1] = { name = tgt, value = val, thr = thr, tru = tru, conf = conf }
    end
    table.sort(sorted, function(a, b) return a.value > b.value end)

    if #sorted == 0 then
        AddLabel(detailScroll, "  No suspicion data for any player.", C.GRAY)
    end

    for _, entry in ipairs(sorted) do
        local val = entry.value
        local color = SusColor(val, thresholds)

        -- Determine label
        local label = ""
        if val >= thresholds.KOS then label = "  [KOS]"
        elseif val >= thresholds.Sus then label = "  [SUS]"
        elseif val <= thresholds.Innocent then label = "  [INNOCENT]"
        elseif val <= thresholds.Trust then label = "  [TRUSTED]"
        end

        -- Channel breakdown suffix
        local channelStr = ""
        if entry.thr > 0 or entry.tru > 0 then
            channelStr = string.format("  (Threat: %.1f | Trust: %.1f | Conf: %.0f%%)", entry.thr, entry.tru, entry.conf * 100)
        end

        -- Bar visualization — dual bars for threat (red) and trust (green)
        local barPanel = vgui.Create("DPanel", detailScroll)
        barPanel:SetTall(26)
        barPanel:Dock(TOP)
        barPanel:DockMargin(8, 1, 8, 1)

        local bgColor = SusBgColor(val, thresholds)
        local eThr = entry.thr
        local eTru = entry.tru
        local eConf = entry.conf
        barPanel.Paint = function(_, w, h)
            -- Background
            surface.SetDrawColor(40, 40, 45, 255)
            surface.DrawRect(0, 0, w, h)

            -- Dual-bar: threat (right of center, red) and trust (left of center, green)
            local mid = w * 0.5
            local maxChannel = 20  -- channels cap at 20

            -- Threat bar (right side, red)
            if eThr > 0 then
                local thrW = (eThr / maxChannel) * mid
                thrW = math.min(thrW, mid - 2)
                -- Modulate alpha by confidence
                local alpha = math.Clamp(eConf * 180, 40, 180)
                surface.SetDrawColor(220, 70, 70, alpha)
                surface.DrawRect(mid, 2, thrW, h - 4)
            end

            -- Trust bar (left side, green)
            if eTru > 0 then
                local truW = (eTru / maxChannel) * mid
                truW = math.min(truW, mid - 2)
                local alpha = math.Clamp(eConf * 180, 40, 180)
                surface.SetDrawColor(80, 200, 80, alpha)
                surface.DrawRect(mid - truW, 2, truW, h - 4)
            end

            -- Center line
            surface.SetDrawColor(80, 80, 90, 200)
            surface.DrawRect(mid - 1, 0, 2, h)

            -- Border
            surface.SetDrawColor(60, 60, 70, 200)
            surface.DrawOutlinedRect(0, 0, w, h)
        end

        local barLbl = vgui.Create("DLabel", barPanel)
        barLbl:SetFont("DermaDefault")
        barLbl:SetTextColor(color)
        barLbl:SetText(string.format("  %s:  %+d%s%s", entry.name, val, label, channelStr))
        barLbl:Dock(FILL)
    end

    -- Role guesses
    if meta.guesses and next(meta.guesses) then
        AddDivider(detailScroll)
        AddLabel(detailScroll, "Role Guesses", C.PURPLE, "DermaDefaultBold")
        for tgt, role in SortedPairs(meta.guesses) do
            AddLabel(detailScroll, "  " .. tgt .. " → " .. role, C.PURPLE)
        end
    end

    -- Recent events for this bot
    AddDivider(detailScroll)
    AddLabel(detailScroll, "Recent Events (last 30)", C.CYAN, "DermaDefaultBold")

    local botEvents = {}
    for i = #eventLog, 1, -1 do
        local ev = eventLog[i]
        if ev.bot == selectedBot then
            botEvents[#botEvents + 1] = ev
            if #botEvents >= 30 then break end
        end
    end

    if #botEvents == 0 then
        AddLabel(detailScroll, "  No events recorded for this bot.", C.GRAY)
    else
        for _, ev in ipairs(botEvents) do
            local deltaSign = ev.d > 0 and "+" or ""
            local text = string.format("  [%5.1fs]  %s  %s%d → %d   on %s",
                ev.rt or 0, ev.rsn, deltaSign, ev.d, ev.tot, ev.tgt)
            local lineColor = DeltaColor(ev.d)

            if ev.thr then
                local badge, _ = ThresholdBadge(ev.thr)
                if badge then text = text .. badge end
            end

            AddLabel(detailScroll, text, lineColor)
        end
    end
end

-- -----------------------------------------------------------------------
-- Main Window
-- -----------------------------------------------------------------------

local function CreateSuspicionMonitor()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        chat.AddText(C.RED, "[TTT Bots] ", C.WHITE, "Superadmin access required.")
        return
    end

    -- Close existing
    if IsValid(monitorWindow) then
        monitorWindow:Close()
    end

    -- Reset state
    isRequesting = true
    eventLog = {}
    lastEventIndex = 0
    lastRenderedEventCount = 0
    selectedBot = nil

    -- Request immediately
    net.Start("TTTBots_RequestSuspicionData")
    net.WriteUInt(0, 32)
    net.SendToServer()

    local wid, hei = 1100, 700
    monitorWindow = vgui.Create("DFrame")
    monitorWindow:SetSize(wid, hei)
    monitorWindow:Center()
    monitorWindow:SetTitle("TTT Bots 2 — Suspicion Monitor")
    monitorWindow:SetDraggable(true)
    monitorWindow:ShowCloseButton(true)
    monitorWindow:SetVisible(true)
    monitorWindow:MakePopup()
    monitorWindow:SetDeleteOnClose(true)

    monitorWindow.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, C.BG)
        draw.RoundedBoxEx(6, 0, 0, w, 25, C.HEADER, true, true, false, false)
        surface.SetFont("DermaDefaultBold")
        surface.SetTextColor(C.WHITE)
        surface.SetTextPos(8, 4)
        surface.DrawText(self:GetTitle())
    end

    function monitorWindow:OnClose()
        isRequesting = false
        monitorWindow = nil
        eventScroll = nil
        matrixScroll = nil
        detailScroll = nil
        detailCombo = nil
        timer.Remove("TTTBots.SusMonitor.AutoRefresh")
    end

    local sheet = vgui.Create("DPropertySheet", monitorWindow)
    sheet:Dock(FILL)
    sheet:DockMargin(4, 4, 4, 4)

    -- ------ Tab 1: Live Event Feed ------
    local eventPanel = vgui.Create("DPanel", sheet)
    eventPanel:Dock(FILL)
    eventPanel.Paint = function(_, w, h) surface.SetDrawColor(C.PANEL); surface.DrawRect(0, 0, w, h) end

    -- Controls bar at top
    local eventControls = vgui.Create("DPanel", eventPanel)
    eventControls:SetTall(28)
    eventControls:Dock(TOP)
    eventControls:DockMargin(4, 4, 4, 2)
    eventControls:SetPaintBackground(false)

    local clearBtn = vgui.Create("DButton", eventControls)
    clearBtn:SetText("Clear Log")
    clearBtn:SetSize(80, 24)
    clearBtn:Dock(LEFT)
    clearBtn:DockMargin(0, 0, 4, 0)
    clearBtn.DoClick = function()
        eventLog = {}
        lastRenderedEventCount = 0
        if eventScroll then eventScroll:Clear() end
    end

    local autoScrollBtn = vgui.Create("DButton", eventControls)
    autoScrollBtn:SetText("Auto-Scroll: ON")
    autoScrollBtn:SetSize(110, 24)
    autoScrollBtn:Dock(LEFT)
    autoScrollBtn.DoClick = function()
        autoScrollEvent = not autoScrollEvent
        autoScrollBtn:SetText("Auto-Scroll: " .. (autoScrollEvent and "ON" or "OFF"))
    end

    -- Event count label
    local countLabel = vgui.Create("DLabel", eventControls)
    countLabel:SetFont("DermaDefault")
    countLabel:SetTextColor(C.DIMWHITE)
    countLabel:SetText("Events: 0")
    countLabel:Dock(RIGHT)
    countLabel:DockMargin(0, 4, 8, 0)
    countLabel:SetWide(120)
    countLabel:SetContentAlignment(6) -- right align

    -- Refresh the event count periodically
    timer.Create("TTTBots.SusMonitor.EventCount", 0.5, 0, function()
        if not IsValid(countLabel) then
            timer.Remove("TTTBots.SusMonitor.EventCount")
            return
        end
        countLabel:SetText("Events: " .. #eventLog)
    end)

    eventScroll = vgui.Create("DScrollPanel", eventPanel)
    eventScroll:Dock(FILL)
    eventScroll:DockMargin(4, 2, 4, 4)

    sheet:AddSheet("Live Events", eventPanel, "icon16/lightning.png")

    -- ------ Tab 2: Suspicion Matrix ------
    matrixScroll = vgui.Create("DScrollPanel", sheet)
    matrixScroll:Dock(FILL)
    sheet:AddSheet("Suspicion Matrix", matrixScroll, "icon16/table.png")

    -- ------ Tab 3: Bot Detail ------
    local detailPanel = vgui.Create("DPanel", sheet)
    detailPanel:Dock(FILL)
    detailPanel.Paint = function(_, w, h) surface.SetDrawColor(C.PANEL); surface.DrawRect(0, 0, w, h) end

    -- Combo box for bot selection
    local comboPanel = vgui.Create("DPanel", detailPanel)
    comboPanel:SetTall(30)
    comboPanel:Dock(TOP)
    comboPanel:DockMargin(4, 4, 4, 2)
    comboPanel:SetPaintBackground(false)

    local comboLabel = vgui.Create("DLabel", comboPanel)
    comboLabel:SetFont("DermaDefaultBold")
    comboLabel:SetTextColor(C.WHITE)
    comboLabel:SetText("Select Bot: ")
    comboLabel:Dock(LEFT)
    comboLabel:DockMargin(4, 4, 4, 0)
    comboLabel:SizeToContents()

    detailCombo = vgui.Create("DComboBox", comboPanel)
    detailCombo:SetWide(250)
    detailCombo:Dock(LEFT)
    detailCombo:DockMargin(0, 2, 0, 2)
    detailCombo:SetValue("-- select --")
    detailCombo.OnSelect = function(_, _, value)
        selectedBot = value
        PopulateBotDetail()
    end

    detailScroll = vgui.Create("DScrollPanel", detailPanel)
    detailScroll:Dock(FILL)
    detailScroll:DockMargin(4, 2, 4, 4)

    sheet:AddSheet("Bot Detail", detailPanel, "icon16/user_magnify.png")

    -- ------ Auto-refresh timer ------
    timer.Create("TTTBots.SusMonitor.AutoRefresh", 0.6, 0, function()
        if not IsValid(monitorWindow) then
            timer.Remove("TTTBots.SusMonitor.AutoRefresh")
            return
        end

        local activeTab = sheet:GetActiveTab()
        if not activeTab then return end
        local tabText = activeTab:GetText()

        if tabText == "Live Events" then
            PopulateEventFeed()
        elseif tabText == "Suspicion Matrix" then
            PopulateMatrix()
        elseif tabText == "Bot Detail" then
            PopulateBotDetail()
        end
    end)

    -- Initial populate after a short delay for data to arrive
    timer.Simple(0.8, function()
        if not IsValid(monitorWindow) then return end
        PopulateEventFeed()
        PopulateMatrix()
        PopulateBotDetail()
    end)
end

concommand.Add("ttt_bot_suspicion_monitor", function()
    CreateSuspicionMonitor()
end, nil, "Open the real-time Suspicion Monitor for TTT Bots 2", FCVAR_LUA_CLIENT)

print("[TTT Bots 2] Suspicion Monitor UI loaded. Use 'ttt_bot_suspicion_monitor' to open.")
