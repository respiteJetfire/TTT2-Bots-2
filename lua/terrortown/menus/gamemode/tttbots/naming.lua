--- @ignore

CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 40
CLGAMEMODESUBMENU.title = "submenu_tttbots_naming_title"

function CLGAMEMODESUBMENU:Populate(parent)
    local form = vgui.CreateTTT2Form(parent, "header_tttbots_naming_generation")

    form:MakeHelp({
        label = "help_tttbots_naming_community",
    })

    local enbCommunity = form:MakeCheckBox({
        serverConvar = "ttt_bot_names_allowcommunity",
        label = "label_tttbots_names_allowcommunity",
    })

    form:MakeCheckBox({
        serverConvar = "ttt_bot_names_communityonly",
        label = "label_tttbots_names_communityonly",
        master = enbCommunity,
    })

    form:MakeCheckBox({
        serverConvar = "ttt_bot_names_allowgeneric",
        label = "label_tttbots_names_allowgeneric",
    })

    local form2 = vgui.CreateTTT2Form(parent, "header_tttbots_naming_format")

    form2:MakeCheckBox({
        serverConvar = "ttt_bot_names_canleetify",
        label = "label_tttbots_names_canleetify",
    })

    form2:MakeCheckBox({
        serverConvar = "ttt_bot_names_canusenumbers",
        label = "label_tttbots_names_canusenumbers",
    })

    form2:MakeCheckBox({
        serverConvar = "ttt_bot_names_canusespaces",
        label = "label_tttbots_names_canusespaces",
    })

    local form3 = vgui.CreateTTT2Form(parent, "header_tttbots_naming_custom")

    form3:MakeTextEntry({
        serverConvar = "ttt_bot_names_custom",
        label = "label_tttbots_names_custom",
    })
end
