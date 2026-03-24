--- @ignore

CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 85
CLGAMEMODESUBMENU.title = "submenu_tttbots_performance_title"

function CLGAMEMODESUBMENU:Populate(parent)
    -- Base Tick Rate
    local form0 = vgui.CreateTTT2Form(parent, "header_tttbots_tickrate")

    form0:MakeHelp({
        label = "help_tttbots_tickrate",
    })

    form0:MakeSlider({
        serverConvar = "ttt_bot_tickrate",
        label = "label_tttbots_tickrate",
        min = 1,
        max = 20,
        decimal = 0,
    })

    -- Automatic Tick Rate Adjustment
    local form0a = vgui.CreateTTT2Form(parent, "header_tttbots_tickrate_auto")

    form0a:MakeHelp({
        label = "help_tttbots_tickrate_auto",
    })

    local enbAuto = form0a:MakeCheckBox({
        serverConvar = "ttt_bot_tickrate_auto",
        label = "label_tttbots_tickrate_auto",
    })

    form0a:MakeSlider({
        serverConvar = "ttt_bot_tickrate_auto_threshold_ms",
        label = "label_tttbots_tickrate_auto_threshold_ms",
        min = 5,
        max = 200,
        decimal = 0,
        master = enbAuto,
    })

    form0a:MakeSlider({
        serverConvar = "ttt_bot_tickrate_auto_min",
        label = "label_tttbots_tickrate_auto_min",
        min = 1,
        max = 10,
        decimal = 0,
        master = enbAuto,
    })

    form0a:MakeSlider({
        serverConvar = "ttt_bot_tickrate_auto_recover",
        label = "label_tttbots_tickrate_auto_recover",
        min = 1,
        max = 30,
        decimal = 0,
        master = enbAuto,
    })

    form0a:MakeCheckBox({
        serverConvar = "ttt_bot_tickrate_auto_debug",
        label = "label_tttbots_tickrate_auto_debug",
        master = enbAuto,
    })

    -- Emergency Escalation
    local form0b = vgui.CreateTTT2Form(parent, "header_tttbots_tickrate_escalation")

    form0b:MakeHelp({
        label = "help_tttbots_tickrate_escalation",
    })

    form0b:MakeCheckBox({
        serverConvar = "ttt_bot_tickrate_auto_escalate",
        label = "label_tttbots_tickrate_auto_escalate",
        master = enbAuto,
    })

    form0b:MakeSlider({
        serverConvar = "ttt_bot_tickrate_auto_escalate_max",
        label = "label_tttbots_tickrate_auto_escalate_max",
        min = 1,
        max = 3,
        decimal = 0,
        master = enbAuto,
    })

    form0b:MakeHelp({
        label = "help_tttbots_tickrate_escalation_levels",
    })

    -- Dynamic Tick Rate Scaler
    local form = vgui.CreateTTT2Form(parent, "header_tttbots_tickscaler")

    form:MakeHelp({
        label = "help_tttbots_tickscaler",
    })

    local enbScaler = form:MakeCheckBox({
        serverConvar = "ttt_bot_tickscaler_enabled",
        label = "label_tttbots_tickscaler_enabled",
    })

    form:MakeSlider({
        serverConvar = "ttt_bot_tickscaler_threshold",
        label = "label_tttbots_tickscaler_threshold",
        min = 1,
        max = 32,
        decimal = 0,
        master = enbScaler,
    })

    form:MakeSlider({
        serverConvar = "ttt_bot_tickscaler_factor",
        label = "label_tttbots_tickscaler_factor",
        min = 0.1,
        max = 5.0,
        decimal = 2,
        master = enbScaler,
    })

    form:MakeSlider({
        serverConvar = "ttt_bot_tickscaler_max_skip",
        label = "label_tttbots_tickscaler_max_skip",
        min = 1,
        max = 10,
        decimal = 0,
        master = enbScaler,
    })

    -- Exemptions & Behavior
    local form2 = vgui.CreateTTT2Form(parent, "header_tttbots_tickscaler_behavior")

    form2:MakeHelp({
        label = "help_tttbots_tickscaler_behavior",
    })

    form2:MakeCheckBox({
        serverConvar = "ttt_bot_tickscaler_exempt_combat",
        label = "label_tttbots_tickscaler_exempt_combat",
        master = enbScaler,
    })

    form2:MakeCheckBox({
        serverConvar = "ttt_bot_tickscaler_stagger",
        label = "label_tttbots_tickscaler_stagger",
        master = enbScaler,
    })

    -- Debug
    local form3 = vgui.CreateTTT2Form(parent, "header_tttbots_tickscaler_debug")

    form3:MakeCheckBox({
        serverConvar = "ttt_bot_tickscaler_debug",
        label = "label_tttbots_tickscaler_debug",
        master = enbScaler,
    })

    -- Reference table
    local form4 = vgui.CreateTTT2Form(parent, "header_tttbots_tickscaler_reference")

    form4:MakeHelp({
        label = "help_tttbots_tickscaler_reference",
    })
end
