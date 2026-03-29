--- @ignore
--- Custom Plans sub-menu for the TTT Bots settings panel.
--- Allows admins to create, edit, and delete custom bot coordination plans
--- scoped per non-innocent team (traitors, jackals, etc.).

CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 85
CLGAMEMODESUBMENU.title = "submenu_tttbots_plans_title"

--- Local state for the plan editor
local selectedTeam = TEAM_TRAITOR or "traitors"
local editingPlan = nil -- nil = creating new, string = editing existing plan name
local currentPlanData = nil -- the plan being edited

local function GetCPC()
    return TTTBots and TTTBots.CustomPlansClient
end

--- Get a human-readable team name
local function GetTeamDisplayName(team)
    if TEAMS and TEAMS[team] then
        -- Capitalize first letter
        return string.upper(string.sub(team, 1, 1)) .. string.sub(team, 2)
    end
    return team or "Unknown"
end

--- Build a fresh empty plan template
local function NewPlanTemplate(team)
    return {
        Name = "",
        Description = "",
        Team = team,
        IsCustom = true,
        Conditions = {
            PlyMin = 1,
            PlyMax = 16,
            MinTraitors = nil,
            MaxTraitors = nil,
            Chance = 50,
        },
        Jobs = {},
    }
end

--- Build a fresh empty job template
local function NewJobTemplate()
    return {
        Chance = 100,
        Action = "AttackAny",
        Target = "NearestEnemy",
        MaxAssigned = 99,
        MinDuration = 15,
        MaxDuration = 30,
        Repeat = false,
        Conditions = {},
    }
end

--- Build sorted choices table from an enum table (Action or Target enums)
local function BuildChoices(enumTable)
    local choices = {}
    for key, value in pairs(enumTable) do
        choices[#choices + 1] = { key = key, value = value }
    end
    table.sort(choices, function(a, b) return a.key < b.key end)
    return choices
end

--- Populate the plan list panel for the selected team
local function PopulatePlanList(listPanel, team, parent, refreshCallback)
    if not IsValid(listPanel) then return end
    listPanel:Clear()

    local CPC = GetCPC()
    if not CPC then return end

    local plans = CPC.GetPlansForTeam(team)

    if #plans == 0 then
        local lbl = vgui.Create("DLabel", listPanel)
        lbl:SetText(LANG.GetTranslation("label_tttbots_plans_none") or "No custom plans for this team.")
        lbl:SetFont("DermaDefaultBold")
        lbl:Dock(TOP)
        lbl:DockMargin(5, 5, 5, 5)
        lbl:SetAutoStretchVertical(true)
        lbl:SetWrap(true)
        return
    end

    for _, plan in ipairs(plans) do
        local panel = vgui.Create("DPanel", listPanel)
        panel:Dock(TOP)
        panel:DockMargin(2, 2, 2, 2)
        panel:SetTall(50)
        panel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
        end

        -- Plan name and description
        local info = vgui.Create("DPanel", panel)
        info:Dock(FILL)
        info:DockMargin(5, 2, 0, 2)
        info.Paint = function() end

        local nameLbl = vgui.Create("DLabel", info)
        nameLbl:Dock(TOP)
        nameLbl:SetFont("DermaDefaultBold")
        nameLbl:SetText(plan.Name or "Unnamed")
        nameLbl:SetAutoStretchVertical(true)

        local descLbl = vgui.Create("DLabel", info)
        descLbl:Dock(TOP)
        descLbl:SetText(plan.Description or "")
        descLbl:SetAutoStretchVertical(true)
        descLbl:SetTextColor(Color(180, 180, 180))

        -- Buttons
        local btnPanel = vgui.Create("DPanel", panel)
        btnPanel:Dock(RIGHT)
        btnPanel:SetWide(140)
        btnPanel.Paint = function() end

        local editBtn = vgui.Create("DButton", btnPanel)
        editBtn:Dock(LEFT)
        editBtn:SetWide(65)
        editBtn:DockMargin(2, 5, 2, 5)
        editBtn:SetText(LANG.GetTranslation("btn_tttbots_plans_edit") or "Edit")
        editBtn.DoClick = function()
            editingPlan = plan.Name
            currentPlanData = table.Copy(plan)
            if refreshCallback then refreshCallback() end
        end

        local delBtn = vgui.Create("DButton", btnPanel)
        delBtn:Dock(LEFT)
        delBtn:SetWide(65)
        delBtn:DockMargin(2, 5, 2, 5)
        delBtn:SetText(LANG.GetTranslation("btn_tttbots_plans_delete") or "Delete")
        delBtn:SetTextColor(Color(255, 80, 80))
        delBtn.DoClick = function()
            Derma_Query(
                string.format(LANG.GetTranslation("query_tttbots_plans_delete") or "Delete plan '%s'?", plan.Name),
                LANG.GetTranslation("header_tttbots_plans_delete") or "Confirm Delete",
                LANG.GetTranslation("btn_tttbots_plans_yes") or "Yes",
                function()
                    CPC.DeletePlan(plan.Name)
                end,
                LANG.GetTranslation("btn_tttbots_plans_no") or "No"
            )
        end
    end
end

--- Populate the plan editor form
local function PopulatePlanEditor(editorPanel, plan, refreshCallback)
    if not IsValid(editorPanel) then return end
    editorPanel:Clear()

    local CPC = GetCPC()
    if not CPC then return end

    local actions = CPC.Actions or {}
    local targets = CPC.Targets or {}

    -- Header
    local headerText = editingPlan
        and (LANG.GetTranslation("header_tttbots_plans_editing") or "Editing Plan")
        or (LANG.GetTranslation("header_tttbots_plans_creating") or "New Plan")

    local header = vgui.Create("DLabel", editorPanel)
    header:Dock(TOP)
    header:DockMargin(5, 5, 5, 2)
    header:SetFont("DermaLarge")
    header:SetText(headerText)
    header:SetAutoStretchVertical(true)

    -- Name
    local nameLabel = vgui.Create("DLabel", editorPanel)
    nameLabel:Dock(TOP)
    nameLabel:DockMargin(5, 8, 5, 0)
    nameLabel:SetText(LANG.GetTranslation("label_tttbots_plans_name") or "Plan Name:")

    local nameEntry = vgui.Create("DTextEntry", editorPanel)
    nameEntry:Dock(TOP)
    nameEntry:DockMargin(5, 2, 5, 2)
    nameEntry:SetValue(plan.Name or "")
    nameEntry.OnChange = function(self)
        plan.Name = self:GetValue()
    end

    -- Description
    local descLabel = vgui.Create("DLabel", editorPanel)
    descLabel:Dock(TOP)
    descLabel:DockMargin(5, 5, 5, 0)
    descLabel:SetText(LANG.GetTranslation("label_tttbots_plans_description") or "Description:")

    local descEntry = vgui.Create("DTextEntry", editorPanel)
    descEntry:Dock(TOP)
    descEntry:DockMargin(5, 2, 5, 2)
    descEntry:SetValue(plan.Description or "")
    descEntry.OnChange = function(self)
        plan.Description = self:GetValue()
    end

    -- Conditions Section
    local condHeader = vgui.Create("DLabel", editorPanel)
    condHeader:Dock(TOP)
    condHeader:DockMargin(5, 10, 5, 2)
    condHeader:SetFont("DermaDefaultBold")
    condHeader:SetText(LANG.GetTranslation("header_tttbots_plans_conditions") or "Conditions")

    local conds = plan.Conditions or {}

    -- Chance slider
    local chanceSlider = vgui.Create("DNumSlider", editorPanel)
    chanceSlider:Dock(TOP)
    chanceSlider:DockMargin(5, 2, 5, 2)
    chanceSlider:SetText(LANG.GetTranslation("label_tttbots_plans_chance") or "Selection Weight (%)")
    chanceSlider:SetMin(1)
    chanceSlider:SetMax(100)
    chanceSlider:SetDecimals(0)
    chanceSlider:SetValue(conds.Chance or 50)
    chanceSlider.OnValueChanged = function(self, val)
        plan.Conditions.Chance = math.floor(val)
    end

    -- PlyMin slider
    local plyMinSlider = vgui.Create("DNumSlider", editorPanel)
    plyMinSlider:Dock(TOP)
    plyMinSlider:DockMargin(5, 2, 5, 2)
    plyMinSlider:SetText(LANG.GetTranslation("label_tttbots_plans_plymin") or "Min Players")
    plyMinSlider:SetMin(1)
    plyMinSlider:SetMax(32)
    plyMinSlider:SetDecimals(0)
    plyMinSlider:SetValue(conds.PlyMin or 1)
    plyMinSlider.OnValueChanged = function(self, val)
        plan.Conditions.PlyMin = math.floor(val)
    end

    -- PlyMax slider
    local plyMaxSlider = vgui.Create("DNumSlider", editorPanel)
    plyMaxSlider:Dock(TOP)
    plyMaxSlider:DockMargin(5, 2, 5, 2)
    plyMaxSlider:SetText(LANG.GetTranslation("label_tttbots_plans_plymax") or "Max Players")
    plyMaxSlider:SetMin(1)
    plyMaxSlider:SetMax(32)
    plyMaxSlider:SetDecimals(0)
    plyMaxSlider:SetValue(conds.PlyMax or 16)
    plyMaxSlider.OnValueChanged = function(self, val)
        plan.Conditions.PlyMax = math.floor(val)
    end

    -- MinTraitors slider
    local minTSlider = vgui.Create("DNumSlider", editorPanel)
    minTSlider:Dock(TOP)
    minTSlider:DockMargin(5, 2, 5, 2)
    minTSlider:SetText(LANG.GetTranslation("label_tttbots_plans_minteam") or "Min Team Members")
    minTSlider:SetMin(0)
    minTSlider:SetMax(16)
    minTSlider:SetDecimals(0)
    minTSlider:SetValue(conds.MinTraitors or 1)
    minTSlider.OnValueChanged = function(self, val)
        local v = math.floor(val)
        plan.Conditions.MinTraitors = v > 0 and v or nil
    end

    -- MaxTraitors slider
    local maxTSlider = vgui.Create("DNumSlider", editorPanel)
    maxTSlider:Dock(TOP)
    maxTSlider:DockMargin(5, 2, 5, 2)
    maxTSlider:SetText(LANG.GetTranslation("label_tttbots_plans_maxteam") or "Max Team Members")
    maxTSlider:SetMin(0)
    maxTSlider:SetMax(16)
    maxTSlider:SetDecimals(0)
    maxTSlider:SetValue(conds.MaxTraitors or 0)
    maxTSlider.OnValueChanged = function(self, val)
        local v = math.floor(val)
        plan.Conditions.MaxTraitors = v > 0 and v or nil
    end

    -- Advanced conditions checkboxes
    local advHeader = vgui.Create("DLabel", editorPanel)
    advHeader:Dock(TOP)
    advHeader:DockMargin(5, 8, 5, 2)
    advHeader:SetFont("DermaDefaultBold")
    advHeader:SetText(LANG.GetTranslation("header_tttbots_plans_advanced_conditions") or "Advanced Conditions")

    local advConditions = {
        { key = "RequiresPolice",           label = "label_tttbots_plans_cond_police",         default = "Requires Police Player" },
        { key = "RequiresReviveCapability", label = "label_tttbots_plans_cond_revive",         default = "Requires Revive Capability" },
        { key = "RequiresConvertCapability",label = "label_tttbots_plans_cond_convert",        default = "Requires Convert Capability" },
        { key = "RequiresReviveOrConvert",  label = "label_tttbots_plans_cond_revive_convert", default = "Requires Revive or Convert" },
        { key = "KnifeModInstalled",        label = "label_tttbots_plans_cond_knife",          default = "Requires 200dmg Knife Mod" },
        { key = "RequiresHeavyFirepower",   label = "label_tttbots_plans_cond_heavy",          default = "Requires Heavy Firepower" },
        { key = "RequiresStealthWeapons",   label = "label_tttbots_plans_cond_stealth",        default = "Requires Stealth Weapons" },
        { key = "RequiresSmartWeapons",     label = "label_tttbots_plans_cond_smart",          default = "Requires Smart Weapons" },
        { key = "RequiresExplosives",       label = "label_tttbots_plans_cond_explosives",     default = "Requires Explosives" },
        { key = "RequiresAreaDenial",       label = "label_tttbots_plans_cond_areadenial",     default = "Requires Area Denial" },
        { key = "RequiresDisruption",       label = "label_tttbots_plans_cond_disruption",     default = "Requires Disruption" },
    }

    for _, cond in ipairs(advConditions) do
        local cb = vgui.Create("DCheckBoxLabel", editorPanel)
        cb:Dock(TOP)
        cb:DockMargin(10, 1, 5, 1)
        cb:SetText(LANG.GetTranslation(cond.label) or cond.default)
        cb:SetChecked(plan.Conditions[cond.key] or false)
        cb.OnChange = function(self, checked)
            plan.Conditions[cond.key] = checked or nil
        end
    end

    -- TeamOutnumberedRatio slider
    local outnumberedSlider = vgui.Create("DNumSlider", editorPanel)
    outnumberedSlider:Dock(TOP)
    outnumberedSlider:DockMargin(5, 4, 5, 2)
    outnumberedSlider:SetText(LANG.GetTranslation("label_tttbots_plans_cond_outnumbered") or "Team Outnumbered Ratio (0=off)")
    outnumberedSlider:SetMin(0)
    outnumberedSlider:SetMax(1)
    outnumberedSlider:SetDecimals(2)
    outnumberedSlider:SetValue(conds.TeamOutnumberedRatio or 0)
    outnumberedSlider.OnValueChanged = function(self, val)
        val = math.Round(val, 2)
        plan.Conditions.TeamOutnumberedRatio = val > 0 and val or nil
    end

    -- === JOBS SECTION ===
    local jobsHeader = vgui.Create("DLabel", editorPanel)
    jobsHeader:Dock(TOP)
    jobsHeader:DockMargin(5, 12, 5, 2)
    jobsHeader:SetFont("DermaDefaultBold")
    jobsHeader:SetText(LANG.GetTranslation("header_tttbots_plans_jobs") or "Jobs (executed in order)")

    -- Build sorted action/target choice lists
    local actionChoices = BuildChoices(actions)
    local targetChoices = BuildChoices(targets)

    -- Render each job
    local function RenderJobs()
        -- Find and clear the jobs container if it exists
        if IsValid(editorPanel._jobsContainer) then
            editorPanel._jobsContainer:Remove()
        end

        local jobsContainer = vgui.Create("DPanel", editorPanel)
        jobsContainer:Dock(TOP)
        jobsContainer:DockMargin(0, 0, 0, 0)
        jobsContainer.Paint = function() end
        editorPanel._jobsContainer = jobsContainer

        local totalHeight = 0

        for i, job in ipairs(plan.Jobs or {}) do
            local jobPanel = vgui.Create("DPanel", jobsContainer)
            jobPanel:Dock(TOP)
            jobPanel:DockMargin(5, 4, 5, 4)
            jobPanel:SetTall(185)
            jobPanel.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 50, 220))
            end
            totalHeight = totalHeight + 193

            -- Job header with index and delete button
            local jobHead = vgui.Create("DPanel", jobPanel)
            jobHead:Dock(TOP)
            jobHead:SetTall(22)
            jobHead.Paint = function(self, w, h)
                draw.RoundedBoxEx(4, 0, 0, w, h, Color(60, 60, 70, 200), true, true, false, false)
            end

            local jobLabel = vgui.Create("DLabel", jobHead)
            jobLabel:Dock(FILL)
            jobLabel:DockMargin(5, 0, 0, 0)
            jobLabel:SetFont("DermaDefaultBold")
            jobLabel:SetText(string.format(LANG.GetTranslation("label_tttbots_plans_job_n") or "Job #%d", i))

            local removeJobBtn = vgui.Create("DButton", jobHead)
            removeJobBtn:Dock(RIGHT)
            removeJobBtn:SetWide(20)
            removeJobBtn:SetText("X")
            removeJobBtn:SetTextColor(Color(255, 80, 80))
            removeJobBtn.DoClick = function()
                table.remove(plan.Jobs, i)
                RenderJobs()
            end

            -- Move up/down buttons
            if i > 1 then
                local upBtn = vgui.Create("DButton", jobHead)
                upBtn:Dock(RIGHT)
                upBtn:SetWide(20)
                upBtn:SetText("▲")
                upBtn.DoClick = function()
                    plan.Jobs[i], plan.Jobs[i - 1] = plan.Jobs[i - 1], plan.Jobs[i]
                    RenderJobs()
                end
            end
            if i < #plan.Jobs then
                local downBtn = vgui.Create("DButton", jobHead)
                downBtn:Dock(RIGHT)
                downBtn:SetWide(20)
                downBtn:SetText("▼")
                downBtn.DoClick = function()
                    plan.Jobs[i], plan.Jobs[i + 1] = plan.Jobs[i + 1], plan.Jobs[i]
                    RenderJobs()
                end
            end

            -- Action dropdown
            local actionCombo = vgui.Create("DComboBox", jobPanel)
            actionCombo:Dock(TOP)
            actionCombo:DockMargin(5, 4, 5, 1)
            actionCombo:SetValue(job.Action or "AttackAny")
            for _, choice in ipairs(actionChoices) do
                actionCombo:AddChoice(choice.key .. " (" .. choice.value .. ")", choice.value)
            end
            actionCombo.OnSelect = function(self, index, text, data)
                job.Action = data
            end

            -- Target dropdown
            local targetCombo = vgui.Create("DComboBox", jobPanel)
            targetCombo:Dock(TOP)
            targetCombo:DockMargin(5, 1, 5, 1)
            targetCombo:SetValue(job.Target or "NearestEnemy")
            for _, choice in ipairs(targetChoices) do
                targetCombo:AddChoice(choice.key .. " (" .. choice.value .. ")", choice.value)
            end
            targetCombo.OnSelect = function(self, index, text, data)
                job.Target = data
            end

            -- Row of sliders: Chance, MaxAssigned
            local row1 = vgui.Create("DPanel", jobPanel)
            row1:Dock(TOP)
            row1:SetTall(28)
            row1:DockMargin(0, 0, 0, 0)
            row1.Paint = function() end

            local chanceS = vgui.Create("DNumSlider", row1)
            chanceS:Dock(LEFT)
            chanceS:SetWide(250)
            chanceS:SetText(LANG.GetTranslation("label_tttbots_plans_job_chance") or "Chance %")
            chanceS:SetMin(1)
            chanceS:SetMax(100)
            chanceS:SetDecimals(0)
            chanceS:SetValue(job.Chance or 100)
            chanceS.OnValueChanged = function(self, val)
                job.Chance = math.floor(val)
            end

            local maxAssS = vgui.Create("DNumSlider", row1)
            maxAssS:Dock(FILL)
            maxAssS:SetText(LANG.GetTranslation("label_tttbots_plans_job_maxassigned") or "Max Bots")
            maxAssS:SetMin(1)
            maxAssS:SetMax(99)
            maxAssS:SetDecimals(0)
            maxAssS:SetValue(job.MaxAssigned or 99)
            maxAssS.OnValueChanged = function(self, val)
                job.MaxAssigned = math.floor(val)
            end

            -- Row of sliders: MinDuration, MaxDuration
            local row2 = vgui.Create("DPanel", jobPanel)
            row2:Dock(TOP)
            row2:SetTall(28)
            row2:DockMargin(0, 0, 0, 0)
            row2.Paint = function() end

            local minDurS = vgui.Create("DNumSlider", row2)
            minDurS:Dock(LEFT)
            minDurS:SetWide(250)
            minDurS:SetText(LANG.GetTranslation("label_tttbots_plans_job_mindur") or "Min Duration (s)")
            minDurS:SetMin(1)
            minDurS:SetMax(120)
            minDurS:SetDecimals(0)
            minDurS:SetValue(job.MinDuration or 15)
            minDurS.OnValueChanged = function(self, val)
                job.MinDuration = math.floor(val)
            end

            local maxDurS = vgui.Create("DNumSlider", row2)
            maxDurS:Dock(FILL)
            maxDurS:SetText(LANG.GetTranslation("label_tttbots_plans_job_maxdur") or "Max Duration (s)")
            maxDurS:SetMin(1)
            maxDurS:SetMax(300)
            maxDurS:SetDecimals(0)
            maxDurS:SetValue(job.MaxDuration or 60)
            maxDurS.OnValueChanged = function(self, val)
                job.MaxDuration = math.floor(val)
            end

            -- Repeat checkbox
            local repeatCB = vgui.Create("DCheckBoxLabel", jobPanel)
            repeatCB:Dock(TOP)
            repeatCB:DockMargin(10, 2, 5, 2)
            repeatCB:SetText(LANG.GetTranslation("label_tttbots_plans_job_repeat") or "Repeat (re-assign to same bot)")
            repeatCB:SetChecked(job.Repeat or false)
            repeatCB.OnChange = function(self, checked)
                job.Repeat = checked
            end
        end

        -- Add Job button
        local addJobBtn = vgui.Create("DButton", jobsContainer)
        addJobBtn:Dock(TOP)
        addJobBtn:DockMargin(5, 5, 5, 5)
        addJobBtn:SetTall(30)
        addJobBtn:SetText(LANG.GetTranslation("btn_tttbots_plans_addjob") or "+ Add Job")
        addJobBtn.DoClick = function()
            plan.Jobs = plan.Jobs or {}
            plan.Jobs[#plan.Jobs + 1] = NewJobTemplate()
            RenderJobs()
        end
        totalHeight = totalHeight + 40

        jobsContainer:SetTall(totalHeight)
    end

    RenderJobs()

    -- Save / Cancel buttons
    local btnRow = vgui.Create("DPanel", editorPanel)
    btnRow:Dock(TOP)
    btnRow:SetTall(40)
    btnRow:DockMargin(5, 10, 5, 10)
    btnRow.Paint = function() end

    local saveBtn = vgui.Create("DButton", btnRow)
    saveBtn:Dock(LEFT)
    saveBtn:SetWide(140)
    saveBtn:DockMargin(0, 5, 5, 5)
    saveBtn:SetText(LANG.GetTranslation("btn_tttbots_plans_save") or "Save Plan")
    saveBtn.DoClick = function()
        if not plan.Name or plan.Name == "" then
            Derma_Message(
                LANG.GetTranslation("msg_tttbots_plans_noname") or "Please enter a plan name.",
                LANG.GetTranslation("header_tttbots_plans_error") or "Error",
                LANG.GetTranslation("btn_tttbots_plans_ok") or "OK"
            )
            return
        end
        if not plan.Jobs or #plan.Jobs == 0 then
            Derma_Message(
                LANG.GetTranslation("msg_tttbots_plans_nojobs") or "Please add at least one job.",
                LANG.GetTranslation("header_tttbots_plans_error") or "Error",
                LANG.GetTranslation("btn_tttbots_plans_ok") or "OK"
            )
            return
        end

        plan.Team = selectedTeam
        plan.IsCustom = true

        local CPC = GetCPC()
        if not CPC then return end

        if editingPlan then
            CPC.UpdatePlan(editingPlan, plan)
        else
            CPC.CreatePlan(plan)
        end

        editingPlan = nil
        currentPlanData = nil
        if refreshCallback then refreshCallback() end
    end

    local cancelBtn = vgui.Create("DButton", btnRow)
    cancelBtn:Dock(LEFT)
    cancelBtn:SetWide(100)
    cancelBtn:DockMargin(5, 5, 0, 5)
    cancelBtn:SetText(LANG.GetTranslation("btn_tttbots_plans_cancel") or "Cancel")
    cancelBtn.DoClick = function()
        editingPlan = nil
        currentPlanData = nil
        if refreshCallback then refreshCallback() end
    end
end

function CLGAMEMODESUBMENU:Populate(parent)
    local CPC = GetCPC()
    if not CPC then
        local errLabel = vgui.Create("DLabel", parent)
        errLabel:Dock(TOP)
        errLabel:SetText("Custom Plans system not loaded. Is the bot addon running?")
        errLabel:SetAutoStretchVertical(true)
        return
    end

    -- Request sync from server on menu open
    CPC.RequestSync()

    -- Main container (scrollable)
    local scroll = vgui.Create("DScrollPanel", parent)
    scroll:Dock(FILL)

    local container = vgui.Create("DPanel", scroll)
    container:Dock(TOP)
    container:DockMargin(0, 0, 0, 0)
    container.Paint = function() end

    local function RefreshUI()
        if not IsValid(container) then return end
        container:Clear()

        -- Help text
        local helpForm = vgui.CreateTTT2Form(container, "header_tttbots_plans")
        helpForm:MakeHelp({
            label = "help_tttbots_plans",
        })

        -- Team Selector
        local teamLabel = vgui.Create("DLabel", container)
        teamLabel:Dock(TOP)
        teamLabel:DockMargin(5, 8, 5, 2)
        teamLabel:SetFont("DermaDefaultBold")
        teamLabel:SetText(LANG.GetTranslation("label_tttbots_plans_team") or "Team:")

        local teamCombo = vgui.Create("DComboBox", container)
        teamCombo:Dock(TOP)
        teamCombo:DockMargin(5, 2, 5, 5)
        teamCombo:SetTall(25)

        local teams = CPC.GetAvailableTeams()
        for _, team in ipairs(teams) do
            local display = GetTeamDisplayName(team)
            teamCombo:AddChoice(display, team, team == selectedTeam)
        end
        -- Ensure selected team is in the list
        if not table.HasValue(teams, selectedTeam) and #teams > 0 then
            selectedTeam = teams[1]
            teamCombo:ChooseOptionID(1)
        end

        teamCombo.OnSelect = function(self, index, text, data)
            selectedTeam = data
            editingPlan = nil
            currentPlanData = nil
            RefreshUI()
        end

        -- Show either the plan list or the editor
        if currentPlanData then
            -- Editor mode
            local editorPanel = vgui.Create("DPanel", container)
            editorPanel:Dock(TOP)
            editorPanel:DockMargin(0, 5, 0, 5)
            editorPanel.Paint = function() end

            PopulatePlanEditor(editorPanel, currentPlanData, RefreshUI)

            -- Auto-size the editor and container
            editorPanel:InvalidateLayout(true)
            editorPanel:SizeToChildren(false, true)
            container:InvalidateLayout(true)
            container:SizeToChildren(false, true)
        else
            -- List mode
            local listHeader = vgui.Create("DLabel", container)
            listHeader:Dock(TOP)
            listHeader:DockMargin(5, 10, 5, 2)
            listHeader:SetFont("DermaDefaultBold")
            listHeader:SetText(
                string.format(
                    LANG.GetTranslation("header_tttbots_plans_list") or "Custom Plans for %s",
                    GetTeamDisplayName(selectedTeam)
                )
            )

            local listPanel = vgui.Create("DPanel", container)
            listPanel:Dock(TOP)
            listPanel:DockMargin(0, 0, 0, 5)
            listPanel.Paint = function() end

            PopulatePlanList(listPanel, selectedTeam, container, RefreshUI)

            -- Auto-size the list panel after population
            listPanel:InvalidateLayout(true)
            listPanel:SizeToChildren(false, true)

            -- New Plan button
            local newBtn = vgui.Create("DButton", container)
            newBtn:Dock(TOP)
            newBtn:DockMargin(5, 10, 5, 10)
            newBtn:SetTall(35)
            newBtn:SetText(LANG.GetTranslation("btn_tttbots_plans_new") or "+ Create New Plan")
            newBtn:SetFont("DermaDefaultBold")
            newBtn.DoClick = function()
                editingPlan = nil
                currentPlanData = NewPlanTemplate(selectedTeam)
                RefreshUI()
            end

            -- Auto-size
            container:InvalidateLayout(true)
            container:SizeToChildren(false, true)
        end
    end

    -- Register sync callback to auto-refresh on server response
    CPC.OnSyncCallback = function()
        if IsValid(container) then
            RefreshUI()
        end
    end

    RefreshUI()
end

function CLGAMEMODESUBMENU:ShouldShow()
    return IsValid(LocalPlayer()) and admin.IsAdmin(LocalPlayer())
end
