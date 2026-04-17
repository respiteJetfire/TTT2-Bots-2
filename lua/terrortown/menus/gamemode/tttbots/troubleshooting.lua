--- @ignore
--- Troubleshooting sub-menu for the TTT Bots 2 settings panel.
--- Displays a live list of collated errors captured from both client and
--- server, with buttons to copy the log to clipboard and clear it.

CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 1   -- lowest priority = appears at the bottom
CLGAMEMODESUBMENU.title = "submenu_tttbots_troubleshooting_title"

function CLGAMEMODESUBMENU:Populate(parent)
    -- -----------------------------------------------------------------------
    -- Header / help text
    -- -----------------------------------------------------------------------
    local form = vgui.CreateTTT2Form(parent, "header_tttbots_troubleshooting")

    form:MakeHelp({
        label = "help_tttbots_troubleshooting",
    })

    -- -----------------------------------------------------------------------
    -- Action buttons
    -- -----------------------------------------------------------------------
    local btnRow = vgui.Create("DPanel", parent)
    btnRow:SetTall(32)
    btnRow:DockMargin(8, 6, 8, 4)
    btnRow:Dock(TOP)
    btnRow.Paint = function() end -- transparent

    local btnCopy = vgui.Create("DButton", btnRow)
    btnCopy:SetText("Copy All to Clipboard")
    btnCopy:SetFont("DermaDefaultBold")
    btnCopy:SetWide(180)
    btnCopy:Dock(LEFT)
    btnCopy:DockMargin(0, 0, 8, 0)
    btnCopy.DoClick = function()
        if not TTTBots or not TTTBots.ErrorTracker then return end
        SetClipboardText(TTTBots.ErrorTracker.ToClipboardString())
        notification.AddLegacy("Error log copied to clipboard.", NOTIFY_GENERIC, 3)
        surface.PlaySound("buttons/button15.wav")
    end

    local btnClear = vgui.Create("DButton", btnRow)
    btnClear:SetText("Clear All Errors")
    btnClear:SetFont("DermaDefaultBold")
    btnClear:SetWide(140)
    btnClear:Dock(LEFT)
    btnClear:DockMargin(0, 0, 8, 0)
    btnClear.DoClick = function()
        if not TTTBots or not TTTBots.ErrorTracker then return end
        TTTBots.ErrorTracker.Clear()
        notification.AddLegacy("Error log cleared.", NOTIFY_CLEANUP, 2)
        surface.PlaySound("buttons/button15.wav")
    end

    -- -----------------------------------------------------------------------
    -- Error count label (auto-updating)
    -- -----------------------------------------------------------------------
    local countLabel = vgui.Create("DLabel", parent)
    countLabel:SetFont("DermaDefaultBold")
    countLabel:SetTextColor(Color(220, 220, 220))
    countLabel:SetText("Errors: 0")
    countLabel:SizeToContents()
    countLabel:DockMargin(16, 4, 0, 2)
    countLabel:Dock(TOP)

    -- -----------------------------------------------------------------------
    -- Scrollable error list
    -- -----------------------------------------------------------------------
    local scrollPanel = vgui.Create("DScrollPanel", parent)
    scrollPanel:DockMargin(8, 4, 8, 8)
    scrollPanel:Dock(TOP)
    scrollPanel:SetTall(400)

    local listContainer = scrollPanel:GetCanvas()

    -- Track panels so we can rebuild
    local errorPanels = {}

    --- Rebuild the error list UI from the tracker data.
    local function rebuildList()
        -- Clear old panels
        for _, pnl in ipairs(errorPanels) do
            if IsValid(pnl) then pnl:Remove() end
        end
        errorPanels = {}

        if not TTTBots or not TTTBots.ErrorTracker then return end

        local errors = TTTBots.ErrorTracker.GetAll()

        -- Update count label
        if IsValid(countLabel) then
            local totalCount = 0
            for _, e in ipairs(errors) do
                totalCount = totalCount + (e.count or 1)
            end
            countLabel:SetText(string.format("Unique errors: %d  |  Total occurrences: %d", #errors, totalCount))
            countLabel:SizeToContents()
        end

        if #errors == 0 then
            local noErr = vgui.Create("DLabel", listContainer)
            noErr:SetFont("DermaDefault")
            noErr:SetTextColor(Color(120, 220, 120))
            noErr:SetText("No errors recorded. Everything is running smoothly!")
            noErr:SizeToContents()
            noErr:DockMargin(8, 8, 8, 4)
            noErr:Dock(TOP)
            table.insert(errorPanels, noErr)
            return
        end

        -- Display errors in reverse order (newest first)
        for i = #errors, 1, -1 do
            local e = errors[i]

            local card = vgui.Create("DPanel", listContainer)
            card:DockMargin(0, 0, 0, 4)
            card:Dock(TOP)
            card.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 45, 240))
                -- Thin left accent: red for errors
                draw.RoundedBox(0, 0, 0, 3, h, Color(220, 60, 60, 255))
            end

            -- Realm + count badge
            local realmTag = string.upper(e.realm or "?")
            local countStr = e.count > 1 and string.format(" x%d", e.count) or ""
            local headerText = string.format("[%s]%s", realmTag, countStr)

            local headerLabel = vgui.Create("DLabel", card)
            headerLabel:SetFont("DermaDefaultBold")
            headerLabel:SetTextColor(e.count > 1 and Color(255, 180, 80) or Color(255, 100, 100))
            headerLabel:SetText(headerText)
            headerLabel:SizeToContents()
            headerLabel:DockMargin(10, 4, 4, 0)
            headerLabel:Dock(TOP)

            -- Error message (word-wrapped)
            local msgLabel = vgui.Create("DLabel", card)
            msgLabel:SetFont("DermaDefault")
            msgLabel:SetTextColor(Color(210, 210, 210))
            msgLabel:SetText(e.msg or "")
            msgLabel:SetWrap(true)
            msgLabel:SetAutoStretchVertical(true)
            msgLabel:DockMargin(10, 2, 10, 2)
            msgLabel:Dock(TOP)

            -- Timestamps
            local timeText = ""
            if e.firstSeen then
                timeText = string.format("First seen: %.0fs ago", CurTime() - e.firstSeen)
            end
            if e.lastSeen and e.count > 1 then
                timeText = timeText .. string.format("  |  Last seen: %.0fs ago", CurTime() - e.lastSeen)
            end

            if timeText ~= "" then
                local timeLabel = vgui.Create("DLabel", card)
                timeLabel:SetFont("DermaDefault")
                timeLabel:SetTextColor(Color(140, 140, 140))
                timeLabel:SetText(timeText)
                timeLabel:SizeToContents()
                timeLabel:DockMargin(10, 0, 4, 4)
                timeLabel:Dock(TOP)
            end

            -- Copy individual error button
            local btnCopyOne = vgui.Create("DButton", card)
            btnCopyOne:SetText("Copy")
            btnCopyOne:SetFont("DermaDefault")
            btnCopyOne:SetWide(60)
            btnCopyOne:SetTall(20)
            btnCopyOne:DockMargin(10, 0, 4, 4)
            btnCopyOne:Dock(TOP)
            btnCopyOne.DoClick = function()
                local copyText = string.format("[%s] x%d\n%s", realmTag, e.count, e.msg or "")
                SetClipboardText(copyText)
                notification.AddLegacy("Error copied to clipboard.", NOTIFY_GENERIC, 2)
                surface.PlaySound("buttons/button15.wav")
            end

            -- Auto-size the card to fit contents
            card:InvalidateLayout(true)
            card:SizeToChildren(false, true)

            table.insert(errorPanels, card)
        end
    end

    -- Initial build
    rebuildList()

    -- -----------------------------------------------------------------------
    -- Missing Locale Events section
    -- -----------------------------------------------------------------------
    local localeHeader = vgui.Create("DLabel", parent)
    localeHeader:SetFont("DermaDefaultBold")
    localeHeader:SetTextColor(Color(255, 210, 80))
    localeHeader:SetText("Missing Localized Events")
    localeHeader:SizeToContents()
    localeHeader:DockMargin(16, 10, 0, 2)
    localeHeader:Dock(TOP)

    local localeHelp = vgui.Create("DLabel", parent)
    localeHelp:SetFont("DermaDefault")
    localeHelp:SetTextColor(Color(160, 160, 160))
    localeHelp:SetText("Chat events that have no localized strings in 'en'. Copy the list to add them.")
    localeHelp:SetWrap(true)
    localeHelp:SetAutoStretchVertical(true)
    localeHelp:DockMargin(16, 0, 8, 4)
    localeHelp:Dock(TOP)

    -- Button row for the locale section
    local localeBtnRow = vgui.Create("DPanel", parent)
    localeBtnRow:SetTall(32)
    localeBtnRow:DockMargin(8, 2, 8, 4)
    localeBtnRow:Dock(TOP)
    localeBtnRow.Paint = function() end

    local btnRefreshLocale = vgui.Create("DButton", localeBtnRow)
    btnRefreshLocale:SetText("Refresh from Server")
    btnRefreshLocale:SetFont("DermaDefaultBold")
    btnRefreshLocale:SetWide(170)
    btnRefreshLocale:Dock(LEFT)
    btnRefreshLocale:DockMargin(0, 0, 8, 0)

    local btnCopyLocale = vgui.Create("DButton", localeBtnRow)
    btnCopyLocale:SetText("Copy List")
    btnCopyLocale:SetFont("DermaDefaultBold")
    btnCopyLocale:SetWide(100)
    btnCopyLocale:Dock(LEFT)
    btnCopyLocale:DockMargin(0, 0, 8, 0)

    -- Text area showing the deduplicated sorted event names
    local localeTextEntry = vgui.Create("DTextEntry", parent)
    localeTextEntry:SetFont("DermaDefault")
    localeTextEntry:SetMultiline(true)
    localeTextEntry:SetEditable(false)
    localeTextEntry:SetTall(120)
    localeTextEntry:DockMargin(8, 0, 8, 8)
    localeTextEntry:Dock(TOP)
    localeTextEntry:SetValue("(click Refresh from Server to load)")

    local function rebuildLocaleList()
        local missing = TTTBots.MissingLocaleEvents or {}
        local names = {}
        for k in pairs(missing) do table.insert(names, k) end
        table.sort(names)
        if #names == 0 then
            localeTextEntry:SetValue("(none — all events have localized strings!)") 
        else
            localeTextEntry:SetValue(table.concat(names, "\n"))
        end
        localeHeader:SetText(string.format("Missing Localized Events (%d unique)", #names))
        localeHeader:SizeToContents()
    end

    btnRefreshLocale.DoClick = function()
        net.Start("TTTBots_MissingLocale_Request")
        net.SendToServer()
        -- Update will arrive via net.Receive("TTTBots_MissingLocale_Dump") and rebuild on next timer tick
        notification.AddLegacy("Requesting missing locale list from server...", NOTIFY_GENERIC, 2)
        surface.PlaySound("buttons/button15.wav")
    end

    btnCopyLocale.DoClick = function()
        local missing = TTTBots.MissingLocaleEvents or {}
        local names = {}
        for k in pairs(missing) do table.insert(names, k) end
        table.sort(names)
        if #names == 0 then
            notification.AddLegacy("No missing locale events to copy.", NOTIFY_GENERIC, 2)
            return
        end
        SetClipboardText(table.concat(names, "\n"))
        notification.AddLegacy(string.format("Copied %d missing locale event names.", #names), NOTIFY_GENERIC, 3)
        surface.PlaySound("buttons/button15.wav")
    end

    -- Do an initial refresh request so the list populates when the tab opens
    net.Start("TTTBots_MissingLocale_Request")
    net.SendToServer()

    -- Rebuild the locale list on the same 2s timer as errors
    local _localeRebuildTick = 0
    timer.Create("TTTBots.Troubleshooting.LocaleRefresh", 2, 0, function()
        if not IsValid(parent) then
            timer.Remove("TTTBots.Troubleshooting.LocaleRefresh")
            return
        end
        rebuildLocaleList()
    end)
    rebuildLocaleList()

    -- -----------------------------------------------------------------------
    -- Auto-refresh timer (updates the list every 2 seconds while open)
    -- -----------------------------------------------------------------------
    timer.Create("TTTBots.Troubleshooting.Refresh", 2, 0, function()
        if not IsValid(parent) then
            timer.Remove("TTTBots.Troubleshooting.Refresh")
            return
        end
        rebuildList()
    end)
end
