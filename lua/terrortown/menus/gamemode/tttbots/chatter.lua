--- @ignore

CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 80
CLGAMEMODESUBMENU.title = "submenu_tttbots_chatter_title"

function CLGAMEMODESUBMENU:Populate(parent)
    local form = vgui.CreateTTT2Form(parent, "header_tttbots_chatter_general")

    form:MakeHelp({
        label = "help_tttbots_chatter",
    })

    form:MakeSlider({
        serverConvar = "ttt_bot_chatter_lvl",
        label = "label_tttbots_chatter_lvl",
        min = 0,
        max = 3,
        decimal = 0,
    })

    local enbSilly = form:MakeCheckBox({
        serverConvar = "ttt_bot_chatter_silly",
        label = "label_tttbots_chatter_silly",
    })

    local enbDialogue = form:MakeCheckBox({
        serverConvar = "ttt_bot_chatter_dialogue",
        label = "label_tttbots_chatter_dialogue",
    })

    local form2 = vgui.CreateTTT2Form(parent, "header_tttbots_chatter_timing")

    form2:MakeSlider({
        serverConvar = "ttt_bot_chatter_cps",
        label = "label_tttbots_chatter_cps",
        min = 1,
        max = 120,
        decimal = 0,
    })

    form2:MakeSlider({
        serverConvar = "ttt_bot_chatter_minrepeat",
        label = "label_tttbots_chatter_minrepeat",
        min = 0,
        max = 120,
        decimal = 0,
    })

    form2:MakeSlider({
        serverConvar = "ttt_bot_chatter_chance_multi",
        label = "label_tttbots_chatter_chance_multi",
        min = 0,
        max = 5,
        decimal = 1,
    })

    form2:MakeSlider({
        serverConvar = "ttt_bot_chatter_reply_chance_multi",
        label = "label_tttbots_chatter_reply_chance_multi",
        min = 0,
        max = 5,
        decimal = 1,
    })

    form2:MakeSlider({
        serverConvar = "ttt_bot_chatter_koschance",
        label = "label_tttbots_chatter_koschance",
        min = 0,
        max = 5,
        decimal = 1,
    })

    local form3 = vgui.CreateTTT2Form(parent, "header_tttbots_chatter_style")

    form3:MakeSlider({
        serverConvar = "ttt_bot_chatter_typo_chance",
        label = "label_tttbots_chatter_typo_chance",
        min = 0,
        max = 100,
        decimal = 0,
    })

    form3:MakeSlider({
        serverConvar = "ttt_bot_chatter_temperature",
        label = "label_tttbots_chatter_temperature",
        min = 0,
        max = 2,
        decimal = 1,
    })

    form3:MakeSlider({
        serverConvar = "ttt_bot_chatter_gpt_chance",
        label = "label_tttbots_chatter_gpt_chance",
        min = 0,
        max = 5,
        decimal = 1,
    })
end
