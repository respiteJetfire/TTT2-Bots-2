--- @ignore

CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 50
CLGAMEMODESUBMENU.title = "submenu_tttbots_personality_title"

function CLGAMEMODESUBMENU:Populate(parent)
    -- Boredom
    local form = vgui.CreateTTT2Form(parent, "header_tttbots_personality_boredom")

    form:MakeHelp({
        label = "help_tttbots_boredom",
    })

    local enbBoredom = form:MakeCheckBox({
        serverConvar = "ttt_bot_boredom",
        label = "label_tttbots_boredom",
    })

    form:MakeSlider({
        serverConvar = "ttt_bot_boredom_rate",
        label = "label_tttbots_boredom_rate",
        min = 0,
        max = 500,
        decimal = 0,
        master = enbBoredom,
    })

    -- Pressure
    local form2 = vgui.CreateTTT2Form(parent, "header_tttbots_personality_pressure")

    form2:MakeHelp({
        label = "help_tttbots_pressure",
    })

    local enbPressure = form2:MakeCheckBox({
        serverConvar = "ttt_bot_pressure",
        label = "label_tttbots_pressure",
    })

    form2:MakeSlider({
        serverConvar = "ttt_bot_pressure_rate",
        label = "label_tttbots_pressure_rate",
        min = 0,
        max = 500,
        decimal = 0,
        master = enbPressure,
    })

    -- Rage
    local form3 = vgui.CreateTTT2Form(parent, "header_tttbots_personality_rage")

    form3:MakeHelp({
        label = "help_tttbots_rage",
    })

    local enbRage = form3:MakeCheckBox({
        serverConvar = "ttt_bot_rage",
        label = "label_tttbots_rage",
    })

    form3:MakeSlider({
        serverConvar = "ttt_bot_rage_rate",
        label = "label_tttbots_rage_rate",
        min = 0,
        max = 500,
        decimal = 0,
        master = enbRage,
    })

    -- Misc
    local form4 = vgui.CreateTTT2Form(parent, "header_tttbots_personality_misc")

    form4:MakeCheckBox({
        serverConvar = "ttt_bot_allow_leaving",
        label = "label_tttbots_allow_leaving",
    })
end
