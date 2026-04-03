--- Ajin role integration for TTT Bots 2
--- The Ajin is a Traitor subrole with a two-phase design:
---   Phase 1 (Dormant): Normal traitor — coordinate, stalk, kill.
---   Phase 2 (Transformed): Last traitor standing triggers transformation
---     with speed boost, damage multiplier, health regen, and extra armor.
---     The bot becomes more aggressive and relies on its combat advantages.
---
--- Transformation is server-driven (TTT2 Ajin addon triggers it when
--- the Ajin is the last traitor alive). The NWBool "AjinTransformed"
--- signals the state change.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_AJIN then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- ---------------------------------------------------------------------------
-- Phase 1: Standard traitor tree (pre-transformation)
-- Coordinate with teammates, stalk, use deception
-- ---------------------------------------------------------------------------
local dormantTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Deception,
    _bh.Stalk,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Patrol,
}

-- ---------------------------------------------------------------------------
-- Phase 2: Aggressive solo killer tree (post-transformation)
-- The Ajin is now the last traitor standing with massive combat buffs.
-- Go all-out: stalk, hunt, and overwhelm.
-- ---------------------------------------------------------------------------
local transformedTree = {
    _prior.Chatter,
    _prior.FightBack,
    _bh.Stalk,                  -- Actively hunt isolated targets (speed advantage)
    _prior.Requests,
    _prior.Restore,
    _bh.Interact,
    _bh.Wander,                 -- Keep moving (speed advantage)
}

local roleDescription = "You are the Ajin, a Traitor subrole that transforms when you are the last traitor alive. "
    .. "Pre-transformation: play as a standard traitor — coordinate, deceive, and eliminate. "
    .. "Post-transformation: you gain massive speed, damage, health regen, and armor. "
    .. "Use your combat advantages to overwhelm the remaining players. You are a one-man army."

local ajin = TTTBots.RoleBuilder.TraitorLike("ajin", TEAM_TRAITOR)
ajin:SetBTree(dormantTree)
ajin:SetCanSnipe(true)
ajin:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(ajin)

-- ---------------------------------------------------------------------------
-- Runtime tree override: swap tree based on AjinTransformed NWBool
-- ---------------------------------------------------------------------------
local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor
function TTTBots.Behaviors.GetTreeFor(bot)
    if not IsValid(bot) then return nil end

    if bot:GetSubRole() == ROLE_AJIN then
        if bot:GetNWBool("AjinTransformed", false) then
            return transformedTree
        end
        return dormantTree
    end

    return _origGetTreeFor(bot)
end

print("[TTT Bots 2] Ajin role integration loaded — two-phase traitor (dormant/transformed).")

return true
