--- @ignore

CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 95
CLGAMEMODESUBMENU.title = "submenu_tttbots_evidence_title"

function CLGAMEMODESUBMENU:Populate(parent)
    -- Evidence Thresholds
    local form = vgui.CreateTTT2Form(parent, "header_tttbots_evidence_thresholds")

    form:MakeHelp({
        label = "help_tttbots_evidence_thresholds",
    })

    form:MakeSlider({
        serverConvar = "evidence_kos_threshold",
        label = "label_evidence_kos_threshold",
        min = 5,
        max = 25,
        decimal = 0,
    })

    form:MakeSlider({
        serverConvar = "evidence_accuse_threshold",
        label = "label_evidence_accuse_threshold",
        min = 2,
        max = 15,
        decimal = 0,
    })

    form:MakeSlider({
        serverConvar = "evidence_soft_threshold",
        label = "label_evidence_soft_threshold",
        min = 1,
        max = 10,
        decimal = 0,
    })

    -- Evidence Timing
    local form2 = vgui.CreateTTT2Form(parent, "header_tttbots_evidence_timing")

    form2:MakeHelp({
        label = "help_tttbots_evidence_timing",
    })

    form2:MakeSlider({
        serverConvar = "evidence_decay_time",
        label = "label_evidence_decay_time",
        min = 30,
        max = 300,
        decimal = 0,
    })

    form2:MakeSlider({
        serverConvar = "evidence_prune_time",
        label = "label_evidence_prune_time",
        min = 60,
        max = 600,
        decimal = 0,
    })

    form2:MakeSlider({
        serverConvar = "evidence_accuse_cooldown",
        label = "label_evidence_accuse_cooldown",
        min = 10,
        max = 180,
        decimal = 0,
    })

    -- Trust Network
    local form3 = vgui.CreateTTT2Form(parent, "header_tttbots_evidence_trust")

    form3:MakeHelp({
        label = "help_tttbots_evidence_trust",
    })

    form3:MakeSlider({
        serverConvar = "evidence_companion_min_time",
        label = "label_evidence_companion_min_time",
        min = 5,
        max = 60,
        decimal = 0,
    })

    form3:MakeSlider({
        serverConvar = "evidence_trust_decay_time",
        label = "label_evidence_trust_decay_time",
        min = 30,
        max = 300,
        decimal = 0,
    })
end
