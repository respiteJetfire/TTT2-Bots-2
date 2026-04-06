--- Paranoid role integration for TTT Bots 2
--- The Paranoid is an innocent subrole with a passive "Dead Man's Sight" item
--- (item_ttt_dms): when they die, they briefly see the game world in a special
--- overlay mode. This is purely cosmetic/investigative and doesn't affect gameplay
--- in a way that needs bot handling.
---
--- Key mechanics:
---   • Based on ROLE_INNOCENT (innocent shop access disabled — SHOP_DISABLED)
---   • unknownTeam: true
---   • Passive item: item_ttt_dms — automatic, no bot action needed
---   • No credits, no traitor buttons
---
--- Bot behavior:
---   • InnocentLike base — investigates, uses suspicion, fights back
---   • unknownTeam awareness
---   • The DMS item is cosmetic — bot simply plays as a standard innocent

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_PARANOID then return false end

local roleDescription = "You are the Paranoid, an innocent subrole with Dead Man's Sight. "
    .. "When you die, you briefly see a ghostly overlay of the game world. "
    .. "This passive ability provides no in-game advantage — just play as a normal innocent. "
    .. "Use suspicion and combat to identify and neutralize traitors."

local paranoid = TTTBots.RoleBuilder.InnocentLike("paranoid")
paranoid:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(paranoid)

return true
