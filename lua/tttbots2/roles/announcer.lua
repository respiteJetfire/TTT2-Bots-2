--- Announcer role integration for TTT Bots 2
--- The Announcer is a Detective subrole — a public policing role that
--- announces equipment purchases to all players. They start with armor.
---
--- Bot behavior:
---   • Standard detective-like behavior: investigate, defuse, coordinate
---   • Public role: everyone knows who the Announcer is
---   • Has access to the detective shop (shopFallback = SHOP_FALLBACK_DETECTIVE)
---   • Allied with all innocent-team roles
---
--- The purchase announcement is handled entirely server-side by the Announcer
--- addon's TTT2OrderedEquipment hook — the bot doesn't need special logic for it.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_ANNOUNCER then return false end

local roleDescription = "You are the Announcer, a public Detective-like role with access to the detective shop. "
    .. "You start with body armor and your presence is known to all players. "
    .. "When anyone purchases equipment, the purchase is broadcast to all players. "
    .. "Investigate corpses, coordinate with innocents, and hunt traitors."

local announcer = TTTBots.RoleBuilder.DetectiveLike("announcer")
announcer:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(announcer)

print("[TTT Bots 2] Announcer role integration loaded — public detective with purchase broadcasts.")

return true
