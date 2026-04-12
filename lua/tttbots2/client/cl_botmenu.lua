local DATA = {}

local tr = TTTBots.Locale.GetLocalizedString

--- Shared plan stats data â€” populated by cl_planstats.lua's net handler.
--- Both cl_botmenu.lua and cl_planstats.lua read from this shared table.
TTTBots = TTTBots or {}
TTTBots.ClientPlanStats = TTTBots.ClientPlanStats or nil

--- Cached bot menu data from server (bots + buyables)
TTTBots.ClientBotMenuData = TTTBots.ClientBotMenuData or nil

net.Receive("TTTBots_BotMenuData", function()
    TTTBots.ClientBotMenuData = net.ReadTable()
end)

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
        planInfo:SetText(string.format("  %s â€” %s", cp.Name or "None", cp.State or "?"))
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

--- Color helpers for difficulty display
local function DifficultyColor(diff)
    if diff <= -4 then return Color(100, 200, 100) end     -- Very Easy (green)
    if diff <= -2 then return Color(150, 220, 100) end     -- Easy
    if diff <= 2  then return Color(220, 220, 100) end     -- Normal (yellow)
    if diff <= 4  then return Color(220, 150, 80) end      -- Hard (orange)
    return Color(220, 80, 80)                               -- Very Hard (red)
end

local function RoleColor(role)
    local colors = {
        traitor = Color(200, 50, 50),
        detective = Color(50, 100, 200),
        innocent = Color(50, 200, 50),
    }
    return colors[role] or Color(200, 200, 200)
end

--- Populate the Current Bots panel with a refreshable list of active bots
local function InitBotsPanel(botsP)
    botsP:Clear()

    local data = TTTBots.ClientBotMenuData
    if not data or not data.bots then
        local lbl = vgui.Create("DLabel", botsP)
        lbl:SetFont("DermaDefault")
        lbl:SetTextColor(Color(220, 200, 100))
        lbl:SetText("Waiting for bot data from server...")
        lbl:Dock(TOP)
        lbl:DockMargin(8, 8, 8, 4)
        lbl:SizeToContents()
        return
    end

    local bots = data.bots
    if #bots == 0 then
        local lbl = vgui.Create("DLabel", botsP)
        lbl:SetFont("DermaDefaultBold")
        lbl:SetTextColor(Color(180, 180, 180))
        lbl:SetText("No bots currently in the server.")
        lbl:Dock(TOP)
        lbl:DockMargin(8, 8, 8, 4)
        lbl:SizeToContents()
        return
    end

    -- Header
    local header = vgui.Create("DLabel", botsP)
    header:SetFont("DermaDefaultBold")
    header:SetTextColor(Color(100, 200, 220))
    header:SetText(string.format("  %d Bot(s) Active", #bots))
    header:Dock(TOP)
    header:DockMargin(8, 4, 8, 4)
    header:SizeToContents()

    -- Scrollable list
    local scroll = vgui.Create("DScrollPanel", botsP)
    scroll:Dock(FILL)
    scroll:DockMargin(4, 4, 4, 4)

    for _, bot in ipairs(bots) do
        local panel = vgui.Create("DPanel", scroll)
        panel:Dock(TOP)
        panel:DockMargin(4, 2, 4, 2)
        panel:SetTall(72)
        panel.Paint = function(self, w, h)
            surface.SetDrawColor(40, 40, 48, 255)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(60, 60, 70, 255)
            surface.DrawOutlinedRect(0, 0, w, h)
        end

        -- Bot name + status
        local nameLbl = vgui.Create("DLabel", panel)
        nameLbl:SetFont("DermaDefaultBold")
        nameLbl:SetTextColor(Color(255, 255, 255))
        nameLbl:SetText(bot.nick or "Unknown")
        nameLbl:Dock(NODOCK)
        nameLbl:SetPos(8, 4)
        nameLbl:SizeToContents()

        -- Alive indicator
        local statusLbl = vgui.Create("DLabel", panel)
        statusLbl:SetFont("DermaDefault")
        statusLbl:SetTextColor(bot.alive and Color(100, 220, 100) or Color(200, 80, 80))
        statusLbl:SetText(bot.alive and "ALIVE" or "DEAD")
        statusLbl:Dock(NODOCK)
        statusLbl:SetPos(200, 4)
        statusLbl:SizeToContents()

        -- Role
        local roleLbl = vgui.Create("DLabel", panel)
        roleLbl:SetFont("DermaDefault")
        roleLbl:SetTextColor(RoleColor(bot.role))
        roleLbl:SetText("Role: " .. (bot.role or "?"))
        roleLbl:Dock(NODOCK)
        roleLbl:SetPos(270, 4)
        roleLbl:SizeToContents()

        -- Difficulty
        local diffColor = DifficultyColor(bot.difficulty or 0)
        local diffLbl = vgui.Create("DLabel", panel)
        diffLbl:SetFont("DermaDefault")
        diffLbl:SetTextColor(diffColor)
        diffLbl:SetText(string.format("Difficulty: %+.0f", bot.difficulty or 0))
        diffLbl:Dock(NODOCK)
        diffLbl:SetPos(8, 22)
        diffLbl:SizeToContents()

        -- Archetype
        local archLbl = vgui.Create("DLabel", panel)
        archLbl:SetFont("DermaDefault")
        archLbl:SetTextColor(Color(180, 160, 220))
        archLbl:SetText("Archetype: " .. (bot.archetype or "default"))
        archLbl:Dock(NODOCK)
        archLbl:SetPos(160, 22)
        archLbl:SizeToContents()

        -- Mood stats (rage / boredom / pressure)
        local moodStr = string.format("Rage: %.0f%%  Boredom: %.0f%%  Pressure: %.0f%%",
            (bot.rage or 0) * 100, (bot.boredom or 0) * 100, (bot.pressure or 0) * 100)
        local moodLbl = vgui.Create("DLabel", panel)
        moodLbl:SetFont("DermaDefault")
        moodLbl:SetTextColor(Color(160, 160, 160))
        moodLbl:SetText(moodStr)
        moodLbl:Dock(NODOCK)
        moodLbl:SetPos(8, 38)
        moodLbl:SizeToContents()

        -- Traits
        local traitsStr = "Traits: "
        if bot.traits and #bot.traits > 0 then
            traitsStr = traitsStr .. table.concat(bot.traits, ", ")
        else
            traitsStr = traitsStr .. "none"
        end
        local traitsLbl = vgui.Create("DLabel", panel)
        traitsLbl:SetFont("DermaDefault")
        traitsLbl:SetTextColor(Color(200, 200, 150))
        traitsLbl:SetText(traitsStr)
        traitsLbl:Dock(NODOCK)
        traitsLbl:SetPos(8, 54)
        traitsLbl:SetSize(panel:GetWide() - 16, 16)

        -- Kick button (right side)
        local kickBtn = vgui.Create("DButton", panel)
        kickBtn:SetText("Kick")
        kickBtn:SetSize(60, 22)
        kickBtn:SetPos(panel:GetWide() - 80, 4)
        kickBtn.DoClick = function()
            RunConsoleCommand("ttt_bot_kick", bot.nick)
            timer.Simple(0.5, function()
                net.Start("TTTBots_RequestBotMenuData")
                net.SendToServer()
            end)
        end
        -- Position kick button relative to panel width
        panel.PerformLayout = function(self, w, h)
            kickBtn:SetPos(w - 70, 4)
        end
    end
end

--- Populate the Build-a-Bot panel with controls for adding/removing bots
local function InitBuildABotPanel(botsAddP)
    botsAddP:DockPadding(12, 12, 12, 12)

    -- Section: Add Bots
    local addHeader = vgui.Create("DLabel", botsAddP)
    addHeader:SetFont("DermaDefaultBold")
    addHeader:SetTextColor(Color(100, 200, 220))
    addHeader:SetText("Add Bots")
    addHeader:Dock(TOP)
    addHeader:DockMargin(0, 0, 0, 4)
    addHeader:SizeToContents()

    -- Add bot count
    local addRow = vgui.Create("DPanel", botsAddP)
    addRow:Dock(TOP)
    addRow:SetTall(30)
    addRow:DockMargin(0, 0, 0, 4)
    addRow.Paint = function() end

    local addCountLbl = vgui.Create("DLabel", addRow)
    addCountLbl:SetFont("DermaDefault")
    addCountLbl:SetTextColor(Color(220, 220, 220))
    addCountLbl:SetText("Number of bots to add:")
    addCountLbl:Dock(LEFT)
    addCountLbl:SetWide(160)

    local addCountEntry = vgui.Create("DNumberWang", addRow)
    addCountEntry:Dock(LEFT)
    addCountEntry:SetWide(80)
    addCountEntry:SetMin(1)
    addCountEntry:SetMax(64)
    addCountEntry:SetValue(1)
    addCountEntry:SetDecimals(0)

    local addBtn = vgui.Create("DButton", addRow)
    addBtn:SetText("Add Bots")
    addBtn:Dock(LEFT)
    addBtn:DockMargin(8, 0, 0, 0)
    addBtn:SetWide(100)
    addBtn.DoClick = function()
        local count = math.floor(addCountEntry:GetValue())
        RunConsoleCommand("ttt_bot_add", tostring(count))
    end

    -- Section: Kick Bots
    local kickHeader = vgui.Create("DLabel", botsAddP)
    kickHeader:SetFont("DermaDefaultBold")
    kickHeader:SetTextColor(Color(220, 100, 100))
    kickHeader:SetText("Remove Bots")
    kickHeader:Dock(TOP)
    kickHeader:DockMargin(0, 12, 0, 4)
    kickHeader:SizeToContents()

    local kickAllBtn = vgui.Create("DButton", botsAddP)
    kickAllBtn:SetText("Kick All Bots")
    kickAllBtn:SetTall(28)
    kickAllBtn:Dock(TOP)
    kickAllBtn:DockMargin(0, 0, 0, 4)
    kickAllBtn.DoClick = function()
        RunConsoleCommand("ttt_bot_kickall")
    end

    -- Kick specific bot
    local kickRow = vgui.Create("DPanel", botsAddP)
    kickRow:Dock(TOP)
    kickRow:SetTall(30)
    kickRow:DockMargin(0, 0, 0, 4)
    kickRow.Paint = function() end

    local kickNameEntry = vgui.Create("DTextEntry", kickRow)
    kickNameEntry:Dock(LEFT)
    kickNameEntry:SetWide(200)
    kickNameEntry:SetPlaceholderText("Bot name to kick...")

    local kickOneBtn = vgui.Create("DButton", kickRow)
    kickOneBtn:SetText("Kick Bot")
    kickOneBtn:Dock(LEFT)
    kickOneBtn:DockMargin(8, 0, 0, 0)
    kickOneBtn:SetWide(100)
    kickOneBtn.DoClick = function()
        local name = kickNameEntry:GetValue()
        if name and name ~= "" then
            RunConsoleCommand("ttt_bot_kick", name)
            kickNameEntry:SetText("")
        end
    end

    -- Divider
    local div1 = vgui.Create("DPanel", botsAddP)
    div1:SetTall(1)
    div1:Dock(TOP)
    div1:DockMargin(0, 8, 0, 8)
    div1.Paint = function(_, w, h)
        surface.SetDrawColor(80, 80, 90)
        surface.DrawRect(0, 0, w, h)
    end

    -- Section: Quota
    local quotaHeader = vgui.Create("DLabel", botsAddP)
    quotaHeader:SetFont("DermaDefaultBold")
    quotaHeader:SetTextColor(Color(100, 200, 220))
    quotaHeader:SetText("Bot Quota Settings")
    quotaHeader:Dock(TOP)
    quotaHeader:DockMargin(0, 0, 0, 4)
    quotaHeader:SizeToContents()

    -- Quota count
    local quotaRow = vgui.Create("DPanel", botsAddP)
    quotaRow:Dock(TOP)
    quotaRow:SetTall(30)
    quotaRow:DockMargin(0, 0, 0, 4)
    quotaRow.Paint = function() end

    local quotaLbl = vgui.Create("DLabel", quotaRow)
    quotaLbl:SetFont("DermaDefault")
    quotaLbl:SetTextColor(Color(220, 220, 220))
    quotaLbl:SetText("Bot Quota:")
    quotaLbl:Dock(LEFT)
    quotaLbl:SetWide(100)

    local quotaCvar = GetConVar("ttt_bot_quota")
    local quotaEntry = vgui.Create("DNumberWang", quotaRow)
    quotaEntry:Dock(LEFT)
    quotaEntry:SetWide(80)
    quotaEntry:SetMin(0)
    quotaEntry:SetMax(64)
    quotaEntry:SetValue(quotaCvar and quotaCvar:GetInt() or 0)
    quotaEntry:SetDecimals(0)

    local quotaApplyBtn = vgui.Create("DButton", quotaRow)
    quotaApplyBtn:SetText("Apply")
    quotaApplyBtn:Dock(LEFT)
    quotaApplyBtn:DockMargin(8, 0, 0, 0)
    quotaApplyBtn:SetWide(80)
    quotaApplyBtn.DoClick = function()
        requestServerUpdateCvar("ttt_bot_quota", tostring(math.floor(quotaEntry:GetValue())))
    end

    -- Quota mode
    local modeRow = vgui.Create("DPanel", botsAddP)
    modeRow:Dock(TOP)
    modeRow:SetTall(30)
    modeRow:DockMargin(0, 0, 0, 4)
    modeRow.Paint = function() end

    local modeLbl = vgui.Create("DLabel", modeRow)
    modeLbl:SetFont("DermaDefault")
    modeLbl:SetTextColor(Color(220, 220, 220))
    modeLbl:SetText("Quota Mode:")
    modeLbl:Dock(LEFT)
    modeLbl:SetWide(100)

    local modeCombo = vgui.Create("DComboBox", modeRow)
    modeCombo:Dock(LEFT)
    modeCombo:SetWide(150)
    modeCombo:AddChoice("fill")
    modeCombo:AddChoice("exact")
    modeCombo:AddChoice("dynamic")
    local modeCvar = GetConVar("ttt_bot_quota_mode")
    modeCombo:SetValue(modeCvar and modeCvar:GetString() or "fill")
    modeCombo.OnSelect = function(_, _, value)
        requestServerUpdateCvar("ttt_bot_quota_mode", value)
    end

    -- Divider
    local div2 = vgui.Create("DPanel", botsAddP)
    div2:SetTall(1)
    div2:Dock(TOP)
    div2:DockMargin(0, 8, 0, 8)
    div2.Paint = function(_, w, h)
        surface.SetDrawColor(80, 80, 90)
        surface.DrawRect(0, 0, w, h)
    end

    -- Section: Difficulty
    local diffHeader = vgui.Create("DLabel", botsAddP)
    diffHeader:SetFont("DermaDefaultBold")
    diffHeader:SetTextColor(Color(100, 200, 220))
    diffHeader:SetText("Difficulty")
    diffHeader:Dock(TOP)
    diffHeader:DockMargin(0, 0, 0, 4)
    diffHeader:SizeToContents()

    local diffRow = vgui.Create("DPanel", botsAddP)
    diffRow:Dock(TOP)
    diffRow:SetTall(30)
    diffRow:DockMargin(0, 0, 0, 4)
    diffRow.Paint = function() end

    local diffLblInner = vgui.Create("DLabel", diffRow)
    diffLblInner:SetFont("DermaDefault")
    diffLblInner:SetTextColor(Color(220, 220, 220))
    diffLblInner:SetText("Difficulty (1-5):")
    diffLblInner:Dock(LEFT)
    diffLblInner:SetWide(120)

    local diffCvar = GetConVar("ttt_bot_difficulty")
    local diffCombo = vgui.Create("DComboBox", diffRow)
    diffCombo:Dock(LEFT)
    diffCombo:SetWide(150)
    diffCombo:AddChoice("1 - Very Easy", "1")
    diffCombo:AddChoice("2 - Easy", "2")
    diffCombo:AddChoice("3 - Normal", "3")
    diffCombo:AddChoice("4 - Hard", "4")
    diffCombo:AddChoice("5 - Very Hard", "5")
    local curDiff = diffCvar and diffCvar:GetInt() or 3
    local diffNames = { "1 - Very Easy", "2 - Easy", "3 - Normal", "4 - Hard", "5 - Very Hard" }
    diffCombo:SetValue(diffNames[curDiff] or "3 - Normal")
    diffCombo.OnSelect = function(_, _, _, data)
        requestServerUpdateCvar("ttt_bot_difficulty", data)
    end

    -- Section: Reload
    local div3 = vgui.Create("DPanel", botsAddP)
    div3:SetTall(1)
    div3:Dock(TOP)
    div3:DockMargin(0, 8, 0, 8)
    div3.Paint = function(_, w, h)
        surface.SetDrawColor(80, 80, 90)
        surface.DrawRect(0, 0, w, h)
    end

    local reloadBtn = vgui.Create("DButton", botsAddP)
    reloadBtn:SetText("Reload Bots & Restart Round")
    reloadBtn:SetTall(28)
    reloadBtn:Dock(TOP)
    reloadBtn:DockMargin(0, 0, 0, 4)
    reloadBtn.DoClick = function()
        RunConsoleCommand("ttt_bot_reload")
    end
end

--- Populate the Traits panel with a browsable list of all available traits
local function InitTraitsPanel(traitsP)
    traitsP:DockPadding(8, 8, 8, 8)

    local header = vgui.Create("DLabel", traitsP)
    header:SetFont("DermaDefaultBold")
    header:SetTextColor(Color(100, 200, 220))
    header:SetText("All Available Bot Personality Traits")
    header:Dock(TOP)
    header:DockMargin(0, 0, 0, 8)
    header:SizeToContents()

    local traits = TTTBots.Traits
    if not traits or table.Count(traits) == 0 then
        local noLbl = vgui.Create("DLabel", traitsP)
        noLbl:SetFont("DermaDefault")
        noLbl:SetTextColor(Color(200, 100, 100))
        noLbl:SetText("No traits data available.")
        noLbl:Dock(TOP)
        noLbl:SizeToContents()
        return
    end

    -- Search bar
    local searchEntry = vgui.Create("DTextEntry", traitsP)
    searchEntry:Dock(TOP)
    searchEntry:SetTall(24)
    searchEntry:SetPlaceholderText("Search traits...")
    searchEntry:DockMargin(0, 0, 0, 4)

    local scroll = vgui.Create("DScrollPanel", traitsP)
    scroll:Dock(FILL)

    -- Sort traits alphabetically
    local sortedTraits = {}
    for name, data in pairs(traits) do
        table.insert(sortedTraits, { name = name, data = data })
    end
    table.sort(sortedTraits, function(a, b) return a.name < b.name end)

    local traitPanels = {}

    local function buildTraitPanels()
        scroll:Clear()
        traitPanels = {}
        local searchFilter = string.lower(searchEntry:GetValue() or "")

        for _, entry in ipairs(sortedTraits) do
            local name = entry.name
            local data = entry.data

            -- Apply search filter
            if searchFilter ~= "" then
                if not string.find(string.lower(name), searchFilter, 1, true)
                    and not string.find(string.lower(data.description or ""), searchFilter, 1, true) then
                    continue
                end
            end

            local panel = vgui.Create("DPanel", scroll)
            panel:Dock(TOP)
            panel:DockMargin(2, 1, 2, 1)
            panel:SetTall(54)

            local bgColor = data.traitor_only and Color(55, 35, 35, 255) or Color(38, 38, 48, 255)
            panel.Paint = function(self, w, h)
                surface.SetDrawColor(bgColor)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(60, 60, 70, 255)
                surface.DrawOutlinedRect(0, 0, w, h)
            end

            -- Trait name
            local nameLbl = vgui.Create("DLabel", panel)
            nameLbl:SetFont("DermaDefaultBold")
            nameLbl:SetTextColor(Color(255, 220, 100))
            nameLbl:SetText(name)
            nameLbl:Dock(NODOCK)
            nameLbl:SetPos(8, 2)
            nameLbl:SizeToContents()

            -- Traitor-only badge
            if data.traitor_only then
                local badgeLbl = vgui.Create("DLabel", panel)
                badgeLbl:SetFont("DermaDefault")
                badgeLbl:SetTextColor(Color(220, 80, 80))
                badgeLbl:SetText("[Traitor Only]")
                badgeLbl:Dock(NODOCK)
                badgeLbl:SetPos(120, 2)
                badgeLbl:SizeToContents()
            end

            -- Archetype
            if data.archetype then
                local archLbl = vgui.Create("DLabel", panel)
                archLbl:SetFont("DermaDefault")
                archLbl:SetTextColor(Color(150, 150, 200))
                archLbl:SetText("Archetype: " .. tostring(data.archetype))
                archLbl:Dock(NODOCK)
                archLbl:SetPos(250, 2)
                archLbl:SizeToContents()
            end

            -- Description
            local descLbl = vgui.Create("DLabel", panel)
            descLbl:SetFont("DermaDefault")
            descLbl:SetTextColor(Color(200, 200, 200))
            descLbl:SetText(data.description or "No description.")
            descLbl:Dock(NODOCK)
            descLbl:SetPos(8, 18)
            descLbl:SetSize(900, 14)

            -- Effects summary
            local effectsStr = ""
            if data.effects then
                local parts = {}
                for k, v in pairs(data.effects) do
                    if type(v) == "boolean" then
                        table.insert(parts, k)
                    elseif type(v) == "number" and v ~= 1 then
                        table.insert(parts, string.format("%s=%.1f", k, v))
                    end
                end
                effectsStr = table.concat(parts, "  |  ")
            end
            if effectsStr ~= "" then
                local effLbl = vgui.Create("DLabel", panel)
                effLbl:SetFont("DermaDefault")
                effLbl:SetTextColor(Color(140, 180, 140))
                effLbl:SetText(effectsStr)
                effLbl:Dock(NODOCK)
                effLbl:SetPos(8, 34)
                effLbl:SetSize(900, 14)
            end

            -- Conflicts
            if data.conflicts and #data.conflicts > 0 then
                local conflictsLbl = vgui.Create("DLabel", panel)
                conflictsLbl:SetFont("DermaDefault")
                conflictsLbl:SetTextColor(Color(200, 120, 120))
                conflictsLbl:SetText("Conflicts: " .. table.concat(data.conflicts, ", "))
                conflictsLbl:Dock(NODOCK)
                conflictsLbl:SetPos(600, 2)
                conflictsLbl:SizeToContents()
            end

            table.insert(traitPanels, panel)
        end
    end

    buildTraitPanels()

    searchEntry.OnChange = function()
        buildTraitPanels()
    end
end

--- Populate the Buyables panel with the registered buyable items from the server
local function InitBuyablesPanel(buyablesP)
    buyablesP:Clear()
    buyablesP:DockPadding(8, 8, 8, 8)

    local data = TTTBots.ClientBotMenuData
    if not data or not data.buyables then
        local lbl = vgui.Create("DLabel", buyablesP)
        lbl:SetFont("DermaDefault")
        lbl:SetTextColor(Color(220, 200, 100))
        lbl:SetText("Waiting for buyable data from server...")
        lbl:Dock(TOP)
        lbl:DockMargin(0, 0, 0, 4)
        lbl:SizeToContents()
        return
    end

    local buyables = data.buyables
    if #buyables == 0 then
        local lbl = vgui.Create("DLabel", buyablesP)
        lbl:SetFont("DermaDefaultBold")
        lbl:SetTextColor(Color(180, 180, 180))
        lbl:SetText("No buyable items registered.")
        lbl:Dock(TOP)
        lbl:SizeToContents()
        return
    end

    local header = vgui.Create("DLabel", buyablesP)
    header:SetFont("DermaDefaultBold")
    header:SetTextColor(Color(100, 200, 220))
    header:SetText(string.format("Registered Buyable Items (%d)", #buyables))
    header:Dock(TOP)
    header:DockMargin(0, 0, 0, 4)
    header:SizeToContents()

    -- Search bar
    local searchEntry = vgui.Create("DTextEntry", buyablesP)
    searchEntry:Dock(TOP)
    searchEntry:SetTall(24)
    searchEntry:SetPlaceholderText("Search buyables...")
    searchEntry:DockMargin(0, 0, 0, 4)

    local scroll = vgui.Create("DScrollPanel", buyablesP)
    scroll:Dock(FILL)

    local function buildBuyablePanels()
        scroll:Clear()
        local searchFilter = string.lower(searchEntry:GetValue() or "")

        for _, buyable in ipairs(buyables) do
            -- Apply search filter
            if searchFilter ~= "" then
                local nameMatch = string.find(string.lower(buyable.name or ""), searchFilter, 1, true)
                local classMatch = string.find(string.lower(buyable.class or ""), searchFilter, 1, true)
                local rolesStr = table.concat(buyable.roles or {}, " ")
                local rolesMatch = string.find(string.lower(rolesStr), searchFilter, 1, true)
                if not nameMatch and not classMatch and not rolesMatch then
                    continue
                end
            end

            local panel = vgui.Create("DPanel", scroll)
            panel:Dock(TOP)
            panel:DockMargin(2, 1, 2, 1)
            panel:SetTall(50)
            panel.Paint = function(self, w, h)
                surface.SetDrawColor(38, 38, 48, 255)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(60, 60, 70, 255)
                surface.DrawOutlinedRect(0, 0, w, h)
            end

            -- Name
            local nameLbl = vgui.Create("DLabel", panel)
            nameLbl:SetFont("DermaDefaultBold")
            nameLbl:SetTextColor(Color(255, 220, 100))
            nameLbl:SetText(buyable.name or "Unknown")
            nameLbl:Dock(NODOCK)
            nameLbl:SetPos(8, 2)
            nameLbl:SizeToContents()

            -- Class
            local classLbl = vgui.Create("DLabel", panel)
            classLbl:SetFont("DermaDefault")
            classLbl:SetTextColor(Color(150, 150, 150))
            classLbl:SetText(buyable.class or "")
            classLbl:Dock(NODOCK)
            classLbl:SetPos(200, 2)
            classLbl:SizeToContents()

            -- Price + Priority
            local priceStr = string.format("Price: %d credits  |  Priority: %d", buyable.price or 0, buyable.priority or 0)
            if buyable.primaryWeapon then
                priceStr = priceStr .. "  |  Primary Weapon"
            end
            if buyable.ttt2 then
                priceStr = priceStr .. "  |  TTT2"
            end
            local priceLbl = vgui.Create("DLabel", panel)
            priceLbl:SetFont("DermaDefault")
            priceLbl:SetTextColor(Color(180, 200, 180))
            priceLbl:SetText(priceStr)
            priceLbl:Dock(NODOCK)
            priceLbl:SetPos(8, 18)
            priceLbl:SizeToContents()

            -- Roles
            local rolesStr = "Roles: "
            if buyable.roles and #buyable.roles > 0 then
                -- Truncate if too many roles
                if #buyable.roles > 8 then
                    local shown = {}
                    for i = 1, 8 do table.insert(shown, buyable.roles[i]) end
                    rolesStr = rolesStr .. table.concat(shown, ", ") .. string.format(" (+%d more)", #buyable.roles - 8)
                else
                    rolesStr = rolesStr .. table.concat(buyable.roles, ", ")
                end
            else
                rolesStr = rolesStr .. "any"
            end
            local rolesLbl = vgui.Create("DLabel", panel)
            rolesLbl:SetFont("DermaDefault")
            rolesLbl:SetTextColor(Color(160, 160, 200))
            rolesLbl:SetText(rolesStr)
            rolesLbl:Dock(NODOCK)
            rolesLbl:SetPos(8, 34)
            rolesLbl:SetSize(900, 14)
        end
    end

    buildBuyablePanels()

    searchEntry.OnChange = function()
        buildBuyablePanels()
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
    sheet:AddSheet(tr("current.bots"), botsP, "icon16/user.png")

    local botsAddP = vgui.Create("DPanel", sheet)
    botsAddP:Dock(FILL)
    sheet:AddSheet(tr("build.a.bot"), botsAddP, "icon16/user_add.png")
    InitBuildABotPanel(botsAddP)

    local namesP = vgui.Create("DPanel", sheet)
    namesP:Dock(FILL)
    sheet:AddSheet(tr("bot.names"), namesP, "icon16/text_underline.png")
    InitNamesPanel(namesP)

    local traitsP = vgui.Create("DPanel", sheet)
    traitsP:Dock(FILL)
    sheet:AddSheet(tr("traits"), traitsP, "icon16/tag_red.png")
    InitTraitsPanel(traitsP)

    local buyablesP = vgui.Create("DPanel", sheet)
    buyablesP:Dock(FILL)
    sheet:AddSheet(tr("buyables"), buyablesP, "icon16/gun.png")

    -- Request bot menu data from server (bots + buyables)
    net.Start("TTTBots_RequestBotMenuData")
    net.SendToServer()

    -- Auto-refresh bots and buyables panels
    local botMenuRefreshTimer = "TTTBots.BotMenu.DataRefresh"
    timer.Create(botMenuRefreshTimer, 2, 0, function()
        if not IsValid(window) then
            timer.Remove(botMenuRefreshTimer)
            return
        end
        net.Start("TTTBots_RequestBotMenuData")
        net.SendToServer()
    end)

    -- Populate bots + buyables panels once data arrives (and on refresh)
    local botMenuPopulateTimer = "TTTBots.BotMenu.DataPopulate"
    timer.Create(botMenuPopulateTimer, 1, 0, function()
        if not IsValid(window) then
            timer.Remove(botMenuPopulateTimer)
            return
        end
        if TTTBots.ClientBotMenuData then
            InitBotsPanel(botsP)
            InitBuyablesPanel(buyablesP)
            -- Stop refreshing the panels themselves after first success;
            -- subsequent data updates will be picked up on the next timer fire.
        end
    end)

    -- Plan Stats tab â€” shows plan learning analytics directly in the bot menu
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
        timer.Remove(botMenuRefreshTimer)
        timer.Remove(botMenuPopulateTimer)
        timer.Remove("TTTBots.BotMenu.PlanStatsPopulate")
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

    -- Suspicion Monitor shortcut tab
    local susP = vgui.Create("DPanel", sheet)
    susP:Dock(FILL)
    susP.Paint = function(_, w, h)
        surface.SetDrawColor(30, 30, 35, 255)
        surface.DrawRect(0, 0, w, h)
    end
    sheet:AddSheet("Suspicion", susP, "icon16/magnifier.png")

    local susInfoLabel = vgui.Create("DLabel", susP)
    susInfoLabel:SetFont("DermaDefaultBold")
    susInfoLabel:SetTextColor(Color(220, 220, 220, 255))
    susInfoLabel:SetText("Real-time bot suspicion monitoring â€” track suspicion changes, KOS cascades, and threshold crossings as they happen.")
    susInfoLabel:Dock(TOP)
    susInfoLabel:DockMargin(16, 20, 16, 8)
    susInfoLabel:SetWrap(true)
    susInfoLabel:SetAutoStretchVertical(true)

    local susOpenBtn = vgui.Create("DButton", susP)
    susOpenBtn:SetText("Open Suspicion Monitor")
    susOpenBtn:SetSize(220, 36)
    susOpenBtn:Dock(TOP)
    susOpenBtn:DockMargin(16, 8, 16, 8)
    susOpenBtn.DoClick = function()
        RunConsoleCommand("ttt_bot_suspicion_monitor")
    end

    local susTip = vgui.Create("DLabel", susP)
    susTip:SetFont("DermaDefault")
    susTip:SetTextColor(Color(150, 150, 155, 255))
    susTip:SetText("You can also open this directly with the console command: ttt_bot_suspicion_monitor")
    susTip:Dock(TOP)
    susTip:DockMargin(16, 4, 16, 4)
    susTip:SetWrap(true)
    susTip:SetAutoStretchVertical(true)
end

-- timer.Create("TTTBots.Client.PopulateDebugSheet", 0.34, 0, PopulateDebugSheet)

concommand.Add("ttt_bot_menu", CreateBotMenu, nil, "Open a menu panel to manage bots", FCVAR_LUA_CLIENT)
