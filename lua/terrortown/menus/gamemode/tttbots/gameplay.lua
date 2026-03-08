--- @ignore

CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 90
CLGAMEMODESUBMENU.title = "submenu_tttbots_gameplay_title"

function CLGAMEMODESUBMENU:Populate(parent)
    -- Combat
    local form = vgui.CreateTTT2Form(parent, "header_tttbots_gameplay_combat")

    form:MakeSlider({
        serverConvar = "ttt_bot_difficulty",
        label = "label_tttbots_difficulty",
        min = 1,
        max = 5,
        decimal = 0,
    })

    form:MakeSlider({
        serverConvar = "ttt_bot_reaction_speed",
        label = "label_tttbots_reaction_speed",
        min = 0.1,
        max = 5.0,
        decimal = 1,
    })

    form:MakeHelp({
        label = "help_tttbots_reaction_speed",
    })

    form:MakeCheckBox({
        serverConvar = "ttt_bot_flicking",
        label = "label_tttbots_flicking",
    })

    form:MakeSlider({
        serverConvar = "ttt_bot_kos_limit",
        label = "label_tttbots_kos_limit",
        min = 0,
        max = 10,
        decimal = 0,
    })

    form:MakeCheckBox({
        serverConvar = "ttt_bot_personalities",
        label = "label_tttbots_personalities",
    })

    -- Traitor Behavior
    local form2 = vgui.CreateTTT2Form(parent, "header_tttbots_gameplay_traitor")

    form2:MakeSlider({
        serverConvar = "ttt_bot_attack_delay",
        label = "label_tttbots_attack_delay",
        min = 0,
        max = 120,
        decimal = 0,
    })

    form2:MakeSlider({
        serverConvar = "ttt_bot_plans_mindelay",
        label = "label_tttbots_plans_mindelay",
        min = 0,
        max = 120,
        decimal = 0,
    })

    form2:MakeSlider({
        serverConvar = "ttt_bot_plans_maxdelay",
        label = "label_tttbots_plans_maxdelay",
        min = 0,
        max = 300,
        decimal = 0,
    })

    form2:MakeCheckBox({
        serverConvar = "ttt_bot_coordinator",
        label = "label_tttbots_coordinator",
    })

    form2:MakeSlider({
        serverConvar = "ttt_bot_radar_chance",
        label = "label_tttbots_radar_chance",
        min = 0,
        max = 100,
        decimal = 0,
    })

    -- Items
    local form3 = vgui.CreateTTT2Form(parent, "header_tttbots_gameplay_items")

    form3:MakeCheckBox({
        serverConvar = "ttt_bot_plant_c4",
        label = "label_tttbots_plant_c4",
    })

    form3:MakeCheckBox({
        serverConvar = "ttt_bot_defuse_c4",
        label = "label_tttbots_defuse_c4",
    })

    form3:MakeCheckBox({
        serverConvar = "ttt_bot_use_health",
        label = "label_tttbots_use_health",
    })

    form3:MakeCheckBox({
        serverConvar = "ttt_bot_plant_health",
        label = "label_tttbots_plant_health",
    })

    -- KOS Rules
    local form4 = vgui.CreateTTT2Form(parent, "header_tttbots_gameplay_kos")

    form4:MakeHelp({
        label = "help_tttbots_kos",
    })

    form4:MakeCheckBox({
        serverConvar = "ttt_bot_rdm",
        label = "label_tttbots_rdm",
    })

    form4:MakeCheckBox({
        serverConvar = "ttt_bot_kos_enemies",
        label = "label_tttbots_kos_enemies",
    })

    form4:MakeCheckBox({
        serverConvar = "ttt_bot_kos_nonallies",
        label = "label_tttbots_kos_nonallies",
    })

    form4:MakeCheckBox({
        serverConvar = "ttt_bot_kos_traitorweapons",
        label = "label_tttbots_kos_traitorweapons",
    })

    form4:MakeCheckBox({
        serverConvar = "ttt_bot_kos_unknown",
        label = "label_tttbots_kos_unknown",
    })

    form4:MakeCheckBox({
        serverConvar = "ttt_bot_kos_postround",
        label = "label_tttbots_kos_postround",
    })

    -- Noise
    local form5 = vgui.CreateTTT2Form(parent, "header_tttbots_noise")

    local enbNoise = form5:MakeCheckBox({
        serverConvar = "ttt_bot_noise_enable",
        label = "label_tttbots_noise_enable",
    })

    form5:MakeSlider({
        serverConvar = "ttt_bot_noise_investigate_chance",
        label = "label_tttbots_noise_investigate_chance",
        min = 0,
        max = 100,
        decimal = 0,
        master = enbNoise,
    })

    form5:MakeSlider({
        serverConvar = "ttt_bot_noise_investigate_mtb",
        label = "label_tttbots_noise_investigate_mtb",
        min = 0,
        max = 120,
        decimal = 0,
        master = enbNoise,
    })

    -- Pathfinding
    local form6 = vgui.CreateTTT2Form(parent, "header_tttbots_pathfinding")

    form6:MakeHelp({
        label = "help_tttbots_pathfinding_cpf",
    })

    form6:MakeSlider({
        serverConvar = "ttt_bot_pathfinding_cpf",
        label = "label_tttbots_pathfinding_cpf",
        min = 10,
        max = 1000,
        decimal = 0,
    })

    form6:MakeCheckBox({
        serverConvar = "ttt_bot_pathfinding_cpf_scaling",
        label = "label_tttbots_pathfinding_cpf_scaling",
    })

    form6:MakeHelp({
        label = "help_tttbots_pathfinding_max_nodes",
    })

    form6:MakeSlider({
        serverConvar = "ttt_bot_pathfinding_max_nodes",
        label = "label_tttbots_pathfinding_max_nodes",
        min = 100,
        max = 2000,
        decimal = 0,
    })

    -- Cheat abilities
    local form7 = vgui.CreateTTT2Form(parent, "header_tttbots_cheats")

    form7:MakeHelp({
        label = "help_tttbots_cheats",
    })

    form7:MakeCheckBox({
        serverConvar = "ttt_bot_cheat_know_shooter",
        label = "label_tttbots_cheat_know_shooter",
    })

    form7:MakeSlider({
        serverConvar = "ttt_bot_cheat_redhanded_time",
        label = "label_tttbots_cheat_redhanded_time",
        min = 0,
        max = 30,
        decimal = 0,
    })

    form7:MakeCheckBox({
        serverConvar = "ttt_bot_cheat_traitor_reactionspd",
        label = "label_tttbots_cheat_traitor_reactionspd",
    })

    form7:MakeCheckBox({
        serverConvar = "ttt_bot_cheat_traitor_accuracy",
        label = "label_tttbots_cheat_traitor_accuracy",
    })

    form7:MakeCheckBox({
        serverConvar = "ttt_bot_cheat_know_jester",
        label = "label_tttbots_cheat_know_jester",
    })

    form7:MakeCheckBox({
        serverConvar = "ttt_bot_cheat_know_swapper",
        label = "label_tttbots_cheat_know_swapper",
    })

    form7:MakeCheckBox({
        serverConvar = "ttt_bot_cheat_bot_zombie",
        label = "label_tttbots_cheat_bot_zombie",
    })
end
