local DATA = {}

local tr = TTTBots.Locale.GetLocalizedString

--- Shared plan stats data — populated by cl_planstats.lua's net handler.
--- Both cl_botmenu.lua and cl_planstats.lua read from this shared table.
TTTBots = TTTBots or {}
TTTBots.ClientPlanStats = TTTBots.ClientPlanStats or nil

--- Populate plan stats overview in the bot menu tab
local function PopulatePlanStatsInBotMenu(scroll)
    scroll:Clear()
    local data = TTTBots.ClientPlanStats
    if not data then
        local lbl = vgui.Create("DLabel", scroll)
        lbl:SetFont("DermaDefault")
        lbl:SetTextColor(Color(220, 200, 100))
        lbl:SetText("Waiting for plan stats from server...")
        lbl:Dock(TOP)
        lbl:DockMargin(8, 8, 8, 4)
        lbl:SizeToContents()

        local hint = vgui.Create("DLabel", scroll)
        hint:SetFont("DermaDefault")
        hint:SetTextColor(Color(150, 150, 150))
        hint:SetText("Tip: Use 'ttt_bot_plan_stats_ui' in console for the full analytics panel.")
        hint:Dock(TOP)
        hint:DockMargin(8, 2, 8, 4)
        hint:SizeToContents()
        return
    end

    -- Open full UI button
    local fullBtn = vgui.Create("DButton", scroll)
    fullBtn:SetText("Open Full Plan Stats Window")
    fullBtn:SetTall(28)
    fullBtn:Dock(TOP)
    fullBtn:DockMargin(8, 4, 8, 8)
    fullBtn.DoClick = function()
        RunConsoleCommand("ttt_bot_plan_stats_ui")
    end

    -- Current Plan section
    local cp = data.CurrentPlan
    if cp then
        local hdr = vgui.Create("DLabel", scroll)
        hdr:SetFont("DermaDefaultBold")
        hdr:SetTextColor(Color(100, 200, 220))
        hdr:SetText("Current Plan")
        hdr:Dock(TOP)
        hdr:DockMargin(8, 4, 8, 2)
        hdr:SizeToContents()

        local planInfo = vgui.Create("DLabel", scroll)
        planInfo:SetFont("DermaDefault")
        planInfo:SetTextColor(Color(255, 215, 0))
        planInfo:SetText(string.format("  %s — %s", cp.Name or "None", cp.State or "?"))
        planInfo:Dock(TOP)
        planInfo:DockMargin(8, 1, 8, 1)
        planInfo:SizeToContents()

        if cp.Description and cp.Description ~= "" then
            local descLbl = vgui.Create("DLabel", scroll)
            descLbl:SetFont("DermaDefault")
            descLbl:SetTextColor(Color(180, 180, 180))
            descLbl:SetText("  " .. cp.Description)
            descLbl:Dock(TOP)
            descLbl:DockMargin(8, 1, 8, 4)
            descLbl:SizeToContents()
        end
    end

    -- Top 10 plans by win rate
    local history = data.History
    if history and history.Plans and table.Count(history.Plans) > 0 then
        local div = vgui.Create("DPanel", scroll)
        div:SetTall(1)
        div:Dock(TOP)
        div:DockMargin(8, 4, 8, 4)
        div.Paint = function(self, w, h)
            surface.SetDrawColor(80, 80, 90)
            surface.DrawRect(0, 0, w, h)
        end

        local histHdr = vgui.Create("DLabel", scroll)
        histHdr:SetFont("DermaDefaultBold")
        histHdr:SetTextColor(Color(100, 200, 220))
        histHdr:SetText(string.format("Plan Win Rates (Total Rounds: %d)", history.TotalRounds or 0))
        histHdr:Dock(TOP)
        histHdr:DockMargin(8, 2, 8, 4)
        histHdr:SizeToContents()

        -- Sort
        local sorted = {}
        for name, entry in pairs(history.Plans) do
            table.insert(sorted, {
                Name = name,
                WinRate = entry.WinRate or 0,
                Total = entry.Total or 0,
                LearningModifier = entry.LearningModifier or 0,
            })
        end
        table.sort(sorted, function(a, b) return a.WinRate > b.WinRate end)

        -- Show top 10
        local count = math.min(#sorted, 10)
        for i = 1, count do
            local info = sorted[i]
            local wrColor = info.WinRate >= 65 and Color(100, 200, 100) or (info.WinRate >= 45 and Color(220, 200, 100) or Color(200, 100, 100))

            local row = vgui.Create("DPanel", scroll)
            row:SetTall(20)
            row:Dock(TOP)
            row:DockMargin(12, 1, 12, 0)
            row.Paint = function(self, w, h)
                surface.SetDrawColor(45, 45, 50, 255)
                surface.DrawRect(0, 0, w, h)
                local fillW = math.Clamp(info.WinRate / 100, 0, 1) * w
                surface.SetDrawColor(wrColor.r, wrColor.g, wrColor.b, 40)
                surface.DrawRect(0, 0, fillW, h)

                surface.SetFont("DermaDefault")
                surface.SetTextColor(220, 220, 220)
                surface.SetTextPos(4, 2)
                surface.DrawText(info.Name)

                local statsStr = string.format("WR:%.0f%%  N:%.0f  LM:%+.0f", info.WinRate, info.Total, info.LearningModifier)
                surface.SetTextColor(wrColor.r, wrColor.g, wrColor.b)
                local tw = surface.GetTextSize(statsStr)
                surface.SetTextPos(w - tw - 6, 2)
                surface.DrawText(statsStr)
            end
        end

        if #sorted > 10 then
            local moreLbl = vgui.Create("DLabel", scroll)
            moreLbl:SetFont("DermaDefault")
            moreLbl:SetTextColor(Color(150, 150, 150))
            moreLbl:SetText(string.format("  ... and %d more (open full UI for details)", #sorted - 10))
            moreLbl:Dock(TOP)
            moreLbl:DockMargin(12, 2, 8, 4)
            moreLbl:SizeToContents()
        end
    end
end

local function requestServerUpdateCvar(cvar, value)
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    local msgName = "TTTBots_RequestCvarUpdate"

    net.Start(msgName)
    net.WriteString(cvar)
    net.WriteString(value)
    net.SendToServer()
end

local function onDataChangedSetCvar(row, cvar)
    row.DataChanged = function(_, value)
        -- Create a timer
        timer.Create("TTTBots.Client.CvarTimer." .. cvar, 0.5, 1, function()
            requestServerUpdateCvar(cvar, value)
        end)
    end
end

local function getParsedNames()
    local str = GetConVar("ttt_bot_names_custom"):GetString()

    -- This is basically a csv
    ---@diagnostic disable-next-line: undefined-field This is a valid field in GLua
    local names = string.Split(str, ",")
    return names
end

local function addNameToNames(str)
    local content = GetConVar("ttt_bot_names_custom"):GetString()

    local parsed = getParsedNames()
    table.insert(parsed, str)

    local filtered = {}
    for i, v in pairs(parsed) do
        ---@diagnostic disable-next-line: undefined-field This is a valid field in GLua
        parsed[i] = string.Trim(v)
        if parsed[i] == "" then continue end
        table.insert(filtered, parsed[i])
    end

    local content = table.concat(filtered, ",")

    requestServerUpdateCvar("ttt_bot_names_custom", content)
end

local function InitNamesPanel(namesP)
    local halfWide = 500 - 8

    local rightPanel = vgui.Create("DPanel", namesP)
    rightPanel:Dock(RIGHT)
    rightPanel:SetWide(halfWide)

    local rightNameList = vgui.Create("DListView", rightPanel)
    rightNameList:Dock(FILL)
    rightNameList:AddColumn(tr("name"))
    rightNameList:SetMultiSelect(false)
    rightNameList.ResetContent = function()
        local lines = rightNameList:GetLines()
        for i, line in ipairs(lines) do
            rightNameList:RemoveLine(i)
        end

        local names = getParsedNames()
        for i, str in pairs(names) do
            rightNameList:AddLine(str)
        end
    end
    rightNameList:ResetContent()

    local leftPanel = vgui.Create("DPanel", namesP)
    leftPanel:Dock(LEFT)
    leftPanel:SetWide(halfWide)

    local leftAddInput = vgui.Create("DTextEntry", leftPanel)
    leftAddInput:Dock(TOP)
    leftAddInput:DockMargin(0, 0, 0, 5)
    leftAddInput:SetPlaceholderText(tr("add.name"))

    local leftAddBtn = vgui.Create("DButton", leftPanel)
    leftAddBtn:SetText(tr("add"))
    leftAddBtn:Dock(TOP)
    leftAddBtn:DockMargin(0, 0, 0, 5)
    leftAddBtn.DoClick = function()
        local str = leftAddInput:GetValue()
        if str == "" then return end

        addNameToNames(str)
        leftAddInput:SetText("")

        timer.Simple(0.5, rightNameList.ResetContent)
    end

    local leftRemoveBtn = vgui.Create("DButton", leftPanel)
    leftRemoveBtn:SetText(tr("remove.selected"))
    leftRemoveBtn:Dock(TOP)
    leftRemoveBtn:DockMargin(0, 0, 0, 5)
    leftRemoveBtn.DoClick = function()
        local selected = rightNameList:GetSelectedLine()
        if not selected then return end

        local line = rightNameList:GetLine(selected)
        local str = line:GetValue(1)

        local names = getParsedNames()
        local newNames = {}

        for i, v in pairs(names) do
            if v == str then continue end
            table.insert(newNames, v)
        end

        local content = table.concat(newNames, ",")
        requestServerUpdateCvar("ttt_bot_names_custom", content)

        timer.Simple(0.5, rightNameList.ResetContent)
    end
end

local function CreateBotMenu(ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end

    local wid, hei = 1000, 700
    local sW, sH = ScrW(), ScrH()
    local half_sW, half_sH = sW / 2, sH / 2
    local padding = 15

    local window = vgui.Create("DFrame")
    window:SetPos(half_sW - wid / 2, half_sH - hei / 2)
    window:SetSize(wid, hei)
    window:SetTitle("TTT Bots 2 - Bot Menu")
    window:SetDraggable(true)
    window:ShowCloseButton(true)
    window:SetVisible(true)
    window:MakePopup()

    local sheet = vgui.Create("DPropertySheet", window)
    sheet:Dock(FILL)

    local botsP = vgui.Create("DPanel", sheet)
    botsP:Dock(FILL)
    -- botsP:DockPadding(padding, padding, padding, padding)
    sheet:AddSheet(tr("current.bots"), botsP, "icon16/user.png")

    local botsAddP = vgui.Create("DPanel", sheet)
    botsAddP:Dock(FILL)
    -- botsAddP:DockPadding(padding, padding, padding, padding)
    sheet:AddSheet(tr("build.a.bot"), botsAddP, "icon16/user_add.png")

    local namesP = vgui.Create("DPanel", sheet)
    namesP:Dock(FILL)
    -- namesP:DockPadding(padding, padding, padding, padding)
    sheet:AddSheet(tr("bot.names"), namesP, "icon16/text_underline.png")
    InitNamesPanel(namesP)

    local traitsP = vgui.Create("DPanel", sheet)
    traitsP:Dock(FILL)
    -- traitsP:DockPadding(padding, padding, padding, padding)
    sheet:AddSheet(tr("traits"), traitsP, "icon16/tag_red.png")

    local buyablesP = vgui.Create("DPanel", sheet)
    buyablesP:Dock(FILL)
    -- buyablesP:DockPadding(padding, padding, padding, padding)
    sheet:AddSheet(tr("buyables"), buyablesP, "icon16/gun.png")

    -- Plan Stats tab — shows plan learning analytics directly in the bot menu
    local planStatsP = vgui.Create("DScrollPanel", sheet)
    planStatsP:Dock(FILL)
    sheet:AddSheet("Plan Stats", planStatsP, "icon16/chart_bar.png")

    -- Request plan stats data
    net.Start("TTTBots_RequestPlanStats")
    net.SendToServer()

    -- Auto-refresh plan stats in this tab
    local planStatsRefreshTimer = "TTTBots.BotMenu.PlanStats"
    timer.Create(planStatsRefreshTimer, 2, 0, function()
        if not IsValid(window) then
            timer.Remove(planStatsRefreshTimer)
            return
        end
        net.Start("TTTBots_RequestPlanStats")
        net.SendToServer()
    end)

    -- Override window close to clean up
    local origOnClose = window.OnClose
    function window:OnClose()
        timer.Remove(planStatsRefreshTimer)
        if origOnClose then origOnClose(self) end
    end

    -- Populate plan stats tab with a simple overview
    timer.Create("TTTBots.BotMenu.PlanStatsPopulate", 1.5, 0, function()
        if not IsValid(window) or not IsValid(planStatsP) then
            timer.Remove("TTTBots.BotMenu.PlanStatsPopulate")
            return
        end
        PopulatePlanStatsInBotMenu(planStatsP)
    end)
end

-- timer.Create("TTTBots.Client.PopulateDebugSheet", 0.34, 0, PopulateDebugSheet)

concommand.Add("ttt_bot_menu", CreateBotMenu, nil, "Open a menu panel to manage bots", FCVAR_LUA_CLIENT)
