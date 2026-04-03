--- @ignore

CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 69
CLGAMEMODESUBMENU.title = "submenu_tttbots_ratelimiter_title"

function CLGAMEMODESUBMENU:Populate(parent)
    -- -----------------------------------------------------------------------
    -- Section 1: Rate Limits Configuration
    -- -----------------------------------------------------------------------
    local form = vgui.CreateTTT2Form(parent, "header_tttbots_ratelimiter")

    form:MakeHelp({
        label = "help_tttbots_ratelimiter",
    })

    form:MakeSlider({
        serverConvar = "ttt_bot_llm_max_rpm",
        label = "label_tttbots_llm_max_rpm",
        min = 0,
        max = 120,
        decimal = 0,
    })

    form:MakeSlider({
        serverConvar = "ttt_bot_llm_max_per_round",
        label = "label_tttbots_llm_max_per_round",
        min = 0,
        max = 1000,
        decimal = 0,
    })

    -- -----------------------------------------------------------------------
    -- Section 2: Cost Tracking
    -- -----------------------------------------------------------------------
    local form2 = vgui.CreateTTT2Form(parent, "header_tttbots_cost_tracking")

    form2:MakeHelp({
        label = "help_tttbots_cost_tracking",
    })

    form2:MakeSlider({
        serverConvar = "ttt_bot_llm_cost_per_1k_tokens",
        label = "label_tttbots_llm_cost_per_1k_tokens",
        min = 0,
        max = 1.0,
        decimal = 4,
    })

    form2:MakeSlider({
        serverConvar = "ttt_bot_llm_budget_per_round",
        label = "label_tttbots_llm_budget_per_round",
        min = 0,
        max = 50.0,
        decimal = 2,
    })

    -- -----------------------------------------------------------------------
    -- Section 3: Debug
    -- -----------------------------------------------------------------------
    local form3 = vgui.CreateTTT2Form(parent, "header_tttbots_ratelimiter_debug")

    form3:MakeCheckBox({
        serverConvar = "ttt_bot_llm_ratelimit_debug",
        label = "label_tttbots_llm_ratelimit_debug",
    })

    -- -----------------------------------------------------------------------
    -- Section 4: Live Dashboard (admin-only, read from networked stats)
    -- -----------------------------------------------------------------------
    local form4 = vgui.CreateTTT2Form(parent, "header_tttbots_ratelimiter_dashboard")

    form4:MakeHelp({
        label = "help_tttbots_ratelimiter_dashboard",
    })

    -- Dashboard labels — updated by a recurring think
    local dashLabels = {}
    local labelDefs = {
        { key = "rpm",           fmt = function(s) return string.format("Requests/min: %d / %d", s.rpm or 0, s.maxRPM or 0) end },
        { key = "roundReqs",     fmt = function(s) return string.format("Round requests: %d / %d", s.roundRequests or 0, s.maxPerRound or 0) end },
        { key = "roundTokens",   fmt = function(s) return string.format("Round tokens: %d", s.roundTokens or 0) end },
        { key = "totalTokens",   fmt = function(s) return string.format("Total tokens (session): %d", s.totalTokens or 0) end },
        { key = "roundCost",     fmt = function(s) return string.format("Round cost: $%.4f / $%.2f", s.roundCost or 0, s.budgetPerRound or 0) end },
        { key = "totalCost",     fmt = function(s) return string.format("Total cost (session): $%.4f", s.totalCost or 0) end },
        { key = "allowed",       fmt = function(s) return string.format("Round allowed: %d | rejected: %d", s.roundAllowed or 0, s.roundRejected or 0) end },
    }

    for _, def in ipairs(labelDefs) do
        local lbl = vgui.Create("DLabel", parent)
        lbl:SetFont("DermaDefaultBold")
        lbl:SetTextColor(Color(220, 220, 220))
        lbl:SetText(def.fmt({}))
        lbl:SizeToContents()
        lbl:DockMargin(16, 2, 0, 2)
        lbl:Dock(TOP)
        dashLabels[def.key] = { label = lbl, fmt = def.fmt }
    end

    -- Add a "last updated" timestamp label
    local tsLabel = vgui.Create("DLabel", parent)
    tsLabel:SetFont("DermaDefault")
    tsLabel:SetTextColor(Color(150, 150, 150))
    tsLabel:SetText("Waiting for server data...")
    tsLabel:SizeToContents()
    tsLabel:DockMargin(16, 6, 0, 2)
    tsLabel:Dock(TOP)

    -- Periodic updater
    timer.Create("TTTBots.RateLimiterDashboard.Update", 1, 0, function()
        if not IsValid(parent) then
            timer.Remove("TTTBots.RateLimiterDashboard.Update")
            return
        end

        local stats = TTTBots and TTTBots.RateLimiterStats or {}

        for _, def in ipairs(labelDefs) do
            local entry = dashLabels[def.key]
            if entry and IsValid(entry.label) then
                entry.label:SetText(def.fmt(stats))
                entry.label:SizeToContents()
            end
        end

        if IsValid(tsLabel) then
            if stats.lastUpdate then
                local ago = math.floor(CurTime() - stats.lastUpdate)
                tsLabel:SetText(string.format("Updated %ds ago", ago))
            else
                tsLabel:SetText("Waiting for server data... (admin-only)")
            end
            tsLabel:SizeToContents()
        end
    end)
end
