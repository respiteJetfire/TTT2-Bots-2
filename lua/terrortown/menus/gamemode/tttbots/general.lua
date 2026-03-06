--- @ignore

CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 100
CLGAMEMODESUBMENU.title = "submenu_tttbots_general_title"

function CLGAMEMODESUBMENU:Populate(parent)
    local form = vgui.CreateTTT2Form(parent, "header_tttbots_general")

    form:MakeCheckBox({
        serverConvar = "ttt_bot_pfps",
        label = "label_tttbots_pfps",
    })

    form:MakeCheckBox({
        serverConvar = "ttt_bot_pfps_humanlike",
        label = "label_tttbots_pfps_humanlike",
    })

    form:MakeCheckBox({
        serverConvar = "ttt_bot_emulate_ping",
        label = "label_tttbots_emulate_ping",
    })

    form:MakeTextEntry({
        serverConvar = "ttt_bot_language",
        label = "label_tttbots_language",
    })

    local form2 = vgui.CreateTTT2Form(parent, "header_tttbots_misc")

    form2:MakeCheckBox({
        serverConvar = "ttt_bot_chat_cmds",
        label = "label_tttbots_chat_cmds",
    })

    form2:MakeCheckBox({
        serverConvar = "ttt_bot_names_prefixes",
        label = "label_tttbots_names_prefixes",
    })

    form2:MakeTextEntry({
        serverConvar = "ttt_bot_playermodel",
        label = "label_tttbots_playermodel",
    })

    form2:MakeCheckBox({
        serverConvar = "ttt_bot_notify_always",
        label = "label_tttbots_notify_always",
    })

    local form3 = vgui.CreateTTT2Form(parent, "header_tttbots_quota")

    form3:MakeHelp({
        label = "help_tttbots_quota",
    })

    form3:MakeSlider({
        serverConvar = "ttt_bot_quota",
        label = "label_tttbots_quota",
        min = 0,
        max = 32,
        decimal = 0,
    })

    local quotaMode = form3:MakeComboBox({
        serverConvar = "ttt_bot_quota_mode",
        label = "label_tttbots_quota_mode",
        choices = {
            { title = "Fill",    value = "fill" },
            { title = "Exact",   value = "exact" },
            { title = "Dynamic", value = "dynamic" },
        },
    })

    form3:MakeCheckBox({
        serverConvar = "ttt_bot_quota_cull_difficulty",
        label = "label_tttbots_quota_cull_difficulty",
    })

    local form4 = vgui.CreateTTT2Form(parent, "header_tttbots_quota_dynamic")

    form4:MakeHelp({
        label = "help_tttbots_quota_dynamic",
    })

    form4:MakeSlider({
        serverConvar = "ttt_bot_quota_mode_dynamic_min",
        label = "label_tttbots_quota_mode_dynamic_min",
        min = 0,
        max = 32,
        decimal = 0,
    })

    form4:MakeSlider({
        serverConvar = "ttt_bot_quota_mode_dynamic_max",
        label = "label_tttbots_quota_mode_dynamic_max",
        min = 0,
        max = 64,
        decimal = 0,
    })
end
