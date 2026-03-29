---------------------------------------------------------------------------
-- Plan Stats UI — Client-side panel for viewing bot plan statistics
--
-- Displays:
--   • Current active plan with state, jobs, and assignments
--   • Plan learning history (win rates per plan, context breakdowns)
--   • Team loadout analysis snapshot
--   • Enemy distribution analysis
--   • All known presets with conditions, synergy scores, and validity
--
-- Accessible via: ttt_bot_plan_stats_ui (console command)
-- Also integrated into the bot menu as a "Plan Stats" tab.
---------------------------------------------------------------------------

--- Shared plan stats data. This is the single source of truth — also read by cl_botmenu.lua.
TTTBots = TTTBots or {}
TTTBots.ClientPlanStats = TTTBots.ClientPlanStats or nil

local isRequestingStats = false
local planStatsWindow = nil

--- Color palette
local COLOR_BG = Color(30, 30, 30, 255)
local COLOR_PANEL = Color(40, 40, 45, 255)
local COLOR_HEADER = Color(60, 60, 70, 255)
local COLOR_GREEN = Color(100, 200, 100, 255)
local COLOR_RED = Color(200, 100, 100, 255)
local COLOR_YELLOW = Color(220, 200, 100, 255)
local COLOR_BLUE = Color(100, 150, 220, 255)
local COLOR_CYAN = Color(100, 200, 220, 255)
local COLOR_WHITE = Color(220, 220, 220, 255)
local COLOR_GRAY = Color(150, 150, 150, 255)
local COLOR_GOLD = Color(255, 215, 0, 255)
local COLOR_ORANGE = Color(230, 160, 60, 255)
local COLOR_DIMWHITE = Color(180, 180, 180, 255)

--- Single net.Receive handler for plan stats data (shared with cl_botmenu.lua)
net.Receive("TTTBots_PlanStatsData", function()
    local bytes_amt = net.ReadUInt(32)
    local compressed_data = net.ReadData(bytes_amt)
    local uncompressed_data = util.Decompress(compressed_data)
    if uncompressed_data then
        TTTBots.ClientPlanStats = util.JSONToTable(uncompressed_data)
    end
end)

--- Request plan stats from server periodically when the UI is open
timer.Create("TTTBots.Client.RequestPlanStats", 1, 0, function()
    if not isRequestingStats then return end
    net.Start("TTTBots_RequestPlanStats")
    net.SendToServer()
end)

---------------------------------------------------------------------------
-- Helper drawing functions
---------------------------------------------------------------------------

local function WinRateColor(winRate)
    if winRate >= 65 then return COLOR_GREEN end
    if winRate >= 45 then return COLOR_YELLOW end
    return COLOR_RED
end

local function BoolColor(val)
    return val and COLOR_GREEN or COLOR_RED
end

local function BoolText(val)
    return val and "YES" or "NO"
end

local function AddHeaderLabel(parent, text)
    local lbl = vgui.Create("DLabel", parent)
    lbl:SetFont("DermaDefaultBold")
    lbl:SetTextColor(COLOR_CYAN)
    lbl:SetText(text)
    lbl:Dock(TOP)
    lbl:DockMargin(4, 8, 4, 2)
    lbl:SizeToContents()
    return lbl
end

local function AddInfoLabel(parent, text, color)
    local lbl = vgui.Create("DLabel", parent)
    lbl:SetFont("DermaDefault")
    lbl:SetTextColor(color or COLOR_WHITE)
    lbl:SetText(text)
    lbl:Dock(TOP)
    lbl:DockMargin(12, 1, 4, 1)
    lbl:SizeToContents()
    return lbl
end

local function AddSpacer(parent, height)
    local spacer = vgui.Create("DPanel", parent)
    spacer:SetTall(height or 6)
    spacer:Dock(TOP)
    spacer:SetPaintBackground(false)
    return spacer
end

local function AddDivider(parent)
    local div = vgui.Create("DPanel", parent)
    div:SetTall(1)
    div:Dock(TOP)
    div:DockMargin(4, 4, 4, 4)
    div.Paint = function(self, w, h)
        surface.SetDrawColor(80, 80, 90, 255)
        surface.DrawRect(0, 0, w, h)
    end
    return div
end

---------------------------------------------------------------------------
-- Current Plan Tab
---------------------------------------------------------------------------

local function PopulateCurrentPlanTab(scroll)
    scroll:Clear()
    if not TTTBots.ClientPlanStats then
        AddInfoLabel(scroll, "Waiting for data from server...", COLOR_YELLOW)
        return
    end

    local cp = TTTBots.ClientPlanStats.CurrentPlan
    if not cp then
        AddInfoLabel(scroll, "No plan data available.", COLOR_GRAY)
        return
    end

    -- Plan header
    AddHeaderLabel(scroll, "Active Plan")
    AddInfoLabel(scroll, "Name: " .. (cp.Name or "None"), COLOR_GOLD)
    AddInfoLabel(scroll, "Description: " .. (cp.Description or "N/A"), COLOR_DIMWHITE)
    AddInfoLabel(scroll, "State: " .. (cp.State or "Unknown"), COLOR_CYAN)
    AddInfoLabel(scroll, string.format("Round Time: %.1fs", cp.RoundTime or 0), COLOR_WHITE)

    -- Jobs
    if cp.Jobs and #cp.Jobs > 0 then
        AddDivider(scroll)
        AddHeaderLabel(scroll, "Plan Jobs (" .. #cp.Jobs .. ")")

        for i, job in ipairs(cp.Jobs) do
            local skipText = job.Skip and " [SKIPPED]" or ""
            local repeatText = job.Repeat and " [REPEAT]" or ""
            local assigned = string.format("(%d/%d assigned)", job.NumAssigned or 0, job.MaxAssigned or 0)
            local jobColor = job.Skip and COLOR_GRAY or COLOR_WHITE

            AddInfoLabel(scroll,
                string.format("#%d  %s → %s  Chance:%d%%  %s%s%s",
                    i, job.Action or "?", job.Target or "?", job.Chance or 0,
                    assigned, repeatText, skipText),
                jobColor)
        end
    end

    -- Bot job statuses
    if TTTBots.ClientPlanStats.BotJobs and #TTTBots.ClientPlanStats.BotJobs > 0 then
        AddDivider(scroll)
        AddHeaderLabel(scroll, "Bot Assignments")
        for _, botJob in ipairs(TTTBots.ClientPlanStats.BotJobs) do
            AddInfoLabel(scroll,
                string.format("  %s — %s", botJob.Name or "?", botJob.Status or "?"),
                COLOR_WHITE)
        end
    end

    -- Analysis snapshot
    local analysis = TTTBots.ClientPlanStats.Analysis
    if analysis then
        AddDivider(scroll)
        AddHeaderLabel(scroll, "Team Loadout Analysis")
        local lo = analysis.Loadout
        if lo and lo.TotalCoordinators then
            AddInfoLabel(scroll, string.format("Coordinators: %d  |  Credits Remaining: %d  |  With Credits: %d",
                lo.TotalCoordinators, lo.TotalCreditsRemaining or 0, lo.CoordinatorsWithCredits or 0), COLOR_WHITE)

            -- Score bars
            local function ScoreBar(label, score, color)
                local panel = vgui.Create("DPanel", scroll)
                panel:SetTall(22)
                panel:Dock(TOP)
                panel:DockMargin(12, 2, 12, 0)
                panel.Paint = function(self, w, h)
                    -- Background
                    surface.SetDrawColor(50, 50, 55, 255)
                    surface.DrawRect(0, 0, w, h)
                    -- Fill
                    local fillW = math.Clamp((score or 0) / 100, 0, 1) * w
                    surface.SetDrawColor(color.r, color.g, color.b, 180)
                    surface.DrawRect(0, 0, fillW, h)
                    -- Text
                    surface.SetFont("DermaDefault")
                    surface.SetTextColor(255, 255, 255, 255)
                    surface.SetTextPos(4, 3)
                    surface.DrawText(string.format("%s: %.0f/100", label, score or 0))
                end
            end

            ScoreBar("Firepower", lo.TeamFirepowerScore, COLOR_RED)
            ScoreBar("Stealth", lo.TeamStealthScore, COLOR_BLUE)
            ScoreBar("Utility", lo.TeamUtilityScore, COLOR_GREEN)

            AddSpacer(scroll, 4)
            -- Weapon categories
            local cats = {
                {"Heavy Firepower", lo.HasHeavyFirepower},
                {"Stealth Weapons", lo.HasStealthWeapons},
                {"Smart Weapons", lo.HasSmartWeapons},
                {"Explosives", lo.HasExplosives},
                {"Area Denial", lo.HasAreaDenial},
                {"Revival Weapons", lo.HasRevivalWeapons},
                {"Conversion Weapons", lo.HasConversionWeapons},
                {"Grenades", lo.HasGrenades},
                {"Disruption", lo.HasDisruption},
            }
            for _, cat in ipairs(cats) do
                AddInfoLabel(scroll,
                    string.format("  %s: %s", cat[1], BoolText(cat[2])),
                    BoolColor(cat[2]))
            end
        end

        AddDivider(scroll)
        AddHeaderLabel(scroll, "Enemy Distribution")
        local ed = analysis.EnemyDist
        if ed and ed.TotalEnemies then
            AddInfoLabel(scroll, string.format("Total Enemies: %d  |  Isolated: %d  |  Clustered: %d",
                ed.TotalEnemies, ed.IsolatedEnemies or 0, ed.ClusteredEnemies or 0), COLOR_WHITE)
            AddInfoLabel(scroll, string.format("Avg Group Size: %.1f  |  Police Cluster: %s",
                ed.AvgEnemyGroupSize or 1, BoolText(ed.HasPoliceCluster)), COLOR_WHITE)
        end
    end
end

---------------------------------------------------------------------------
-- Plan History Tab
---------------------------------------------------------------------------

local function PopulatePlanHistoryTab(scroll)
    scroll:Clear()
    if not TTTBots.ClientPlanStats then
        AddInfoLabel(scroll, "Waiting for data from server...", COLOR_YELLOW)
        return
    end

    local history = TTTBots.ClientPlanStats.History
    if not history then
        AddInfoLabel(scroll, "No history data available.", COLOR_GRAY)
        return
    end

    AddHeaderLabel(scroll, "Plan Learning Overview")
    AddInfoLabel(scroll, string.format("Total Rounds Tracked: %d", history.TotalRounds or 0), COLOR_WHITE)
    if history.LastDecayTime and history.LastDecayTime > 0 then
        AddInfoLabel(scroll, string.format("Last Decay: %s", os.date("%c", history.LastDecayTime)), COLOR_GRAY)
    end

    -- Sort plans by win rate
    local sorted = {}
    for name, entry in pairs(history.Plans or {}) do
        table.insert(sorted, {
            Name = name,
            Wins = entry.Wins or 0,
            Losses = entry.Losses or 0,
            Total = entry.Total or 0,
            WinRate = entry.WinRate or 0,
            LearningModifier = entry.LearningModifier or 0,
            Contexts = entry.Contexts or {},
        })
    end
    table.sort(sorted, function(a, b) return a.WinRate > b.WinRate end)

    if #sorted == 0 then
        AddSpacer(scroll, 8)
        AddInfoLabel(scroll, "No plan history recorded yet. Play some rounds!", COLOR_YELLOW)
        return
    end

    AddDivider(scroll)
    AddHeaderLabel(scroll, string.format("Plan Win Rates (%d plans tracked)", #sorted))
    AddSpacer(scroll, 4)

    for _, info in ipairs(sorted) do
        -- Plan header with win rate bar
        local planPanel = vgui.Create("DPanel", scroll)
        planPanel:SetTall(28)
        planPanel:Dock(TOP)
        planPanel:DockMargin(8, 2, 8, 0)

        local wrColor = WinRateColor(info.WinRate)
        planPanel.Paint = function(self, w, h)
            -- Background
            surface.SetDrawColor(45, 45, 50, 255)
            surface.DrawRect(0, 0, w, h)
            -- Win rate fill bar
            local fillW = math.Clamp(info.WinRate / 100, 0, 1) * w
            surface.SetDrawColor(wrColor.r, wrColor.g, wrColor.b, 60)
            surface.DrawRect(0, 0, fillW, h)
            -- Border
            surface.SetDrawColor(70, 70, 80, 255)
            surface.DrawOutlinedRect(0, 0, w, h)
        end

        -- Plan name label
        local nameLabel = vgui.Create("DLabel", planPanel)
        nameLabel:SetFont("DermaDefaultBold")
        nameLabel:SetTextColor(COLOR_WHITE)
        nameLabel:SetText(info.Name)
        nameLabel:SetPos(6, 5)
        nameLabel:SizeToContents()

        -- Stats label (right-aligned)
        local statsText = string.format("W:%.1f  L:%.1f  Total:%.0f  WR:%.1f%%  LM:%+.1f",
            info.Wins, info.Losses, info.Total, info.WinRate, info.LearningModifier)
        local statsLabel = vgui.Create("DLabel", planPanel)
        statsLabel:SetFont("DermaDefault")
        statsLabel:SetTextColor(wrColor)
        statsLabel:SetText(statsText)
        statsLabel:SizeToContents()
        statsLabel:SetPos(planPanel:GetWide() - statsLabel:GetWide() - 8, 6)

        -- Hook to reposition on size change
        planPanel.PerformLayout = function(self, w, h)
            statsLabel:SetPos(w - statsLabel:GetWide() - 8, 6)
        end

        -- Context breakdowns (indented)
        if info.Contexts and #info.Contexts > 0 then
            for _, ctx in ipairs(info.Contexts) do
                local ctxColor = WinRateColor(ctx.WinRate)
                AddInfoLabel(scroll,
                    string.format("    [%s] W:%.1f L:%.1f WR:%.0f%%",
                        ctx.Key, ctx.Wins, ctx.Losses, ctx.WinRate),
                    ctxColor)
            end
        end
    end
end

---------------------------------------------------------------------------
-- All Presets Tab
---------------------------------------------------------------------------

local function PopulatePresetsTab(scroll)
    scroll:Clear()
    if not TTTBots.ClientPlanStats then
        AddInfoLabel(scroll, "Waiting for data from server...", COLOR_YELLOW)
        return
    end

    local presets = TTTBots.ClientPlanStats.Presets
    if not presets or table.Count(presets) == 0 then
        AddInfoLabel(scroll, "No presets available.", COLOR_GRAY)
        return
    end

    -- Sort presets: valid ones first, then by synergy score
    local sorted = {}
    for name, info in pairs(presets) do
        table.insert(sorted, {
            Name = info.Name or name,
            Description = info.Description or "",
            Chance = info.Chance or 0,
            SynergyScore = info.SynergyScore,
            IsValid = info.IsValid or false,
        })
    end
    table.sort(sorted, function(a, b)
        if a.IsValid ~= b.IsValid then return a.IsValid end
        local aScore = (a.Chance or 0) + (a.SynergyScore or 0)
        local bScore = (b.Chance or 0) + (b.SynergyScore or 0)
        return aScore > bScore
    end)

    local validCount = 0
    for _, p in ipairs(sorted) do
        if p.IsValid then validCount = validCount + 1 end
    end

    AddHeaderLabel(scroll, string.format("All Plan Presets (%d total, %d valid now)",
        #sorted, validCount))
    AddSpacer(scroll, 4)

    -- Current plan name for highlighting
    local currentPlanName = TTTBots.ClientPlanStats.CurrentPlan and TTTBots.ClientPlanStats.CurrentPlan.Name or ""

    for _, info in ipairs(sorted) do
        local isActive = info.Name == currentPlanName
        local validColor = info.IsValid and COLOR_GREEN or COLOR_RED
        local nameColor = isActive and COLOR_GOLD or COLOR_WHITE

        local presetPanel = vgui.Create("DPanel", scroll)
        presetPanel:SetTall(40)
        presetPanel:Dock(TOP)
        presetPanel:DockMargin(8, 2, 8, 0)

        presetPanel.Paint = function(self, w, h)
            -- Background
            local bgColor = isActive and Color(50, 50, 20, 255) or Color(42, 42, 48, 255)
            surface.SetDrawColor(bgColor)
            surface.DrawRect(0, 0, w, h)
            -- Valid indicator strip
            surface.SetDrawColor(validColor.r, validColor.g, validColor.b, 200)
            surface.DrawRect(0, 0, 4, h)
            -- Border
            local borderColor = isActive and Color(180, 160, 0, 120) or Color(60, 60, 70, 255)
            surface.SetDrawColor(borderColor)
            surface.DrawOutlinedRect(0, 0, w, h)
        end

        -- Name
        local nameLabel = vgui.Create("DLabel", presetPanel)
        nameLabel:SetFont("DermaDefaultBold")
        nameLabel:SetTextColor(nameColor)
        nameLabel:SetText((isActive and "★ " or "") .. info.Name)
        nameLabel:SetPos(10, 3)
        nameLabel:SizeToContents()

        -- Description
        local descLabel = vgui.Create("DLabel", presetPanel)
        descLabel:SetFont("DermaDefault")
        descLabel:SetTextColor(COLOR_DIMWHITE)
        descLabel:SetText(info.Description)
        descLabel:SetPos(10, 20)
        descLabel:SizeToContents()

        -- Stats (right side)
        local synergyText = info.SynergyScore and string.format("Synergy:%+.0f", info.SynergyScore) or "Synergy:N/A"
        local totalWeight = (info.Chance or 0) + (info.SynergyScore or 0)
        local statsText = string.format("Base:%d%%  %s  Weight:%.0f  %s",
            info.Chance, synergyText, totalWeight, info.IsValid and "VALID" or "INVALID")
        local statsLabel = vgui.Create("DLabel", presetPanel)
        statsLabel:SetFont("DermaDefault")
        statsLabel:SetTextColor(info.IsValid and COLOR_GREEN or COLOR_RED)
        statsLabel:SetText(statsText)
        statsLabel:SizeToContents()

        presetPanel.PerformLayout = function(self, w, h)
            statsLabel:SetPos(w - statsLabel:GetWide() - 8, 12)
        end
    end
end

---------------------------------------------------------------------------
-- Main Window
---------------------------------------------------------------------------

local function CreatePlanStatsWindow()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:IsAdmin() then
        chat.AddText(COLOR_RED, "[TTT Bots] ", COLOR_WHITE, "You need admin access to view plan stats.")
        return
    end

    -- Close existing window
    if IsValid(planStatsWindow) then
        planStatsWindow:Close()
    end

    isRequestingStats = true

    -- Request data immediately
    net.Start("TTTBots_RequestPlanStats")
    net.SendToServer()

    local wid, hei = 1000, 650
    planStatsWindow = vgui.Create("DFrame")
    planStatsWindow:SetSize(wid, hei)
    planStatsWindow:Center()
    planStatsWindow:SetTitle("TTT Bots 2 — Plan Stats & Learning Analytics")
    planStatsWindow:SetDraggable(true)
    planStatsWindow:ShowCloseButton(true)
    planStatsWindow:SetVisible(true)
    planStatsWindow:MakePopup()
    planStatsWindow:SetDeleteOnClose(true)

    planStatsWindow.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, COLOR_BG)
        -- Title bar
        draw.RoundedBoxEx(6, 0, 0, w, 25, COLOR_HEADER, true, true, false, false)
        surface.SetFont("DermaDefaultBold")
        surface.SetTextColor(COLOR_WHITE)
        surface.SetTextPos(8, 4)
        surface.DrawText(self:GetTitle())
    end

    function planStatsWindow:OnClose()
        isRequestingStats = false
        planStatsWindow = nil
    end

    local sheet = vgui.Create("DPropertySheet", planStatsWindow)
    sheet:Dock(FILL)
    sheet:DockMargin(4, 4, 4, 4)

    -- Tab 1: Current Plan
    local currentScroll = vgui.Create("DScrollPanel", sheet)
    currentScroll:Dock(FILL)
    sheet:AddSheet("Current Plan", currentScroll, "icon16/lightning.png")

    -- Tab 2: Plan History
    local historyScroll = vgui.Create("DScrollPanel", sheet)
    historyScroll:Dock(FILL)
    sheet:AddSheet("Win Rates", historyScroll, "icon16/chart_bar.png")

    -- Tab 3: All Presets
    local presetsScroll = vgui.Create("DScrollPanel", sheet)
    presetsScroll:Dock(FILL)
    sheet:AddSheet("All Presets", presetsScroll, "icon16/book_open.png")

    -- Refresh button
    local refreshBtn = vgui.Create("DButton", planStatsWindow)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetSize(80, 24)
    refreshBtn:SetPos(wid - 120, 1)
    refreshBtn.DoClick = function()
        net.Start("TTTBots_RequestPlanStats")
        net.SendToServer()
    end

    -- Auto-refresh timer
    local lastRefresh = 0
    timer.Create("TTTBots.PlanStatsUI.AutoRefresh", 1.5, 0, function()
        if not IsValid(planStatsWindow) then
            timer.Remove("TTTBots.PlanStatsUI.AutoRefresh")
            return
        end

        -- Only refresh the currently active tab
        local activeTab = sheet:GetActiveTab()
        if not activeTab then return end
        local tabText = activeTab:GetText()

        if tabText == "Current Plan" then
            PopulateCurrentPlanTab(currentScroll)
        elseif tabText == "Win Rates" then
            PopulatePlanHistoryTab(historyScroll)
        elseif tabText == "All Presets" then
            PopulatePresetsTab(presetsScroll)
        end
    end)

    -- Initial populate
    timer.Simple(0.5, function()
        if not IsValid(planStatsWindow) then return end
        PopulateCurrentPlanTab(currentScroll)
        PopulatePlanHistoryTab(historyScroll)
        PopulatePresetsTab(presetsScroll)
    end)
end

concommand.Add("ttt_bot_plan_stats_ui", function()
    CreatePlanStatsWindow()
end, nil, "Open the Plan Stats & Learning Analytics UI for TTT Bots 2", FCVAR_LUA_CLIENT)

print("[TTT Bots 2] Plan Stats UI loaded. Use 'ttt_bot_plan_stats_ui' to open.")
