--- @ignore

CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 10
CLGAMEMODESUBMENU.title = "submenu_tttbots_debug_title"

function CLGAMEMODESUBMENU:Populate(parent)
    local form = vgui.CreateTTT2Form(parent, "header_tttbots_debug_drawing")

    form:MakeHelp({
        label = "help_tttbots_debug",
    })

    form:MakeCheckBox({
        serverConvar = "ttt_bot_debug_pathfinding",
        label = "label_tttbots_debug_pathfinding",
    })

    form:MakeCheckBox({
        serverConvar = "ttt_bot_debug_look",
        label = "label_tttbots_debug_look",
    })

    form:MakeCheckBox({
        serverConvar = "ttt_bot_debug_stuckpositions",
        label = "label_tttbots_debug_stuckpositions",
    })

    form:MakeCheckBox({
        serverConvar = "ttt_bot_debug_obstacles",
        label = "label_tttbots_debug_obstacles",
    })

    form:MakeCheckBox({
        serverConvar = "ttt_bot_debug_strafe",
        label = "label_tttbots_debug_strafe",
    })

    form:MakeCheckBox({
        serverConvar = "ttt_bot_debug_navpopularity",
        label = "label_tttbots_debug_navpopularity",
    })

    local form2 = vgui.CreateTTT2Form(parent, "header_tttbots_debug_misc")

    form2:MakeCheckBox({
        serverConvar = "ttt_bot_debug_misc",
        label = "label_tttbots_debug_misc",
    })

    form2:MakeCheckBox({
        serverConvar = "ttt_bot_debug_doors",
        label = "label_tttbots_debug_doors",
    })

    form2:MakeCheckBox({
        serverConvar = "ttt_bot_debug_attack",
        label = "label_tttbots_debug_attack",
    })

    form2:MakeCheckBox({
        serverConvar = "ttt_bot_debug_evil",
        label = "label_tttbots_debug_evil",
    })

    form2:MakeCheckBox({
        serverConvar = "ttt_bot_debug_inventory",
        label = "label_tttbots_debug_inventory",
    })

    form2:MakeCheckBox({
        serverConvar = "ttt_bot_debug_brain",
        label = "label_tttbots_debug_brain",
    })

    form2:MakeCheckBox({
        serverConvar = "ttt_bot_debug_chatter_voice_team_color",
        label = "label_tttbots_debug_chatter_voice_team_color",
    })

    form2:MakeTextEntry({
        serverConvar = "ttt_bot_debug_forceweapon",
        label = "label_tttbots_debug_forceweapon",
    })
end
