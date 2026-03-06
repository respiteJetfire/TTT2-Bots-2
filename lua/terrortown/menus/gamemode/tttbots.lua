--- @ignore

CLGAMEMODEMENU.base = "base_gamemodemenu"

CLGAMEMODEMENU.icon = Material("icon16/group.png")
CLGAMEMODEMENU.title = "menu_tttbots_title"
CLGAMEMODEMENU.description = "menu_tttbots_description"
CLGAMEMODEMENU.priority = 45

function CLGAMEMODEMENU:IsAdminMenu()
    return true
end
