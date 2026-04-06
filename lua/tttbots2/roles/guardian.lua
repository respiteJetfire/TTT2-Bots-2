--- Guardian role integration for TTT Bots 2
--- The Guardian is an Innocent with a special 0-damage deagle:
---   • Shooting an ally with the deagle grants them +100 HP (bonus health)
---     and links the Guardian to them as their protector.
---   • While the link is active, damage taken by the protected player is
---     redirected to the Guardian instead (100% by default).
---   • Cannot protect Detectives (the shot has no effect on them).
---   • unknownTeam = true (appears as Unknown to others, not listed as Innocent).
---
--- Bot strategy:
---   1. Find the closest non-Detective alive Innocent ally and shoot them
---      once with the guardian deagle to establish the link.
---   2. After linking, stay close to the protected player (within ~300 units).
---   3. Intercept attackers: if someone shoots the ward, attack them.
---   4. Play cautiously — incoming damage from the ward's fights is redirected
---      to the Guardian, so the Guardian will take damage at range.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_GUARDIAN then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription =
    "You are the Guardian, an innocent-team support role. "
    .. "You have a special 0-damage deagle that, when fired at an ally, "
    .. "grants them +100 bonus health and links you as their protector. "
    .. "While linked, all damage your ward takes is redirected to you instead. "
    .. "Your job: find a teammate, shoot them once with your deagle to protect them, "
    .. "then stay close and defend them from attackers. "
    .. "You cannot protect Detectives with the deagle. "
    .. "Be aware — you will take damage from fights your ward is in, even across the map."

local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Requests,
    _bh.GuardianProtect,    -- Find a ward and shoot them with the deagle; then follow and defend
    _prior.Support,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol,
}

local guardian = TTTBots.RoleData.New("guardian")
guardian:SetDefusesC4(true)
guardian:SetPlantsC4(false)
guardian:SetTeam(TEAM_INNOCENT)
guardian:SetBTree(bTree)
guardian:SetCanCoordinate(false)     -- unknownTeam = true, no team voice
guardian:SetCanHaveRadar(false)      -- SHOP_DISABLED
guardian:SetStartsFights(false)
guardian:SetUsesSuspicion(true)
guardian:SetCanSnipe(false)          -- Close-range protector role
guardian:SetCanHide(false)
guardian:SetKOSUnknown(false)
guardian:SetLovesTeammates(true)
guardian:SetAlliedTeams({ [TEAM_INNOCENT] = true })
guardian:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(guardian)

print("[TTT Bots 2] Guardian role integration loaded.")
return true
