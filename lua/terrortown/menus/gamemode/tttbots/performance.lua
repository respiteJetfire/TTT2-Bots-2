--- @ignore

CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 85
CLGAMEMODESUBMENU.title = "submenu_tttbots_performance_title"

function CLGAMEMODESUBMENU:Populate(parent)
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
