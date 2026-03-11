if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_AMNESIAC then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local allyTeams = {
    [TEAM_JESTER] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- ---------------------------------------------------------------------------
-- Pre-conversion tree: focused on finding and searching corpses ASAP.
-- AmnesiacSeek is placed at HIGH priority (above InvestigateCorpse) because
-- corpse-seeking is the Amnesiac's primary objective — not just evidence gathering.
-- FightBack stays above it so the bot can still defend itself.
-- ---------------------------------------------------------------------------
local preConversionTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _bh.AmnesiacSeek,       -- HIGH PRIORITY: dedicated corpse-seeking (no dice roll)
    _bh.InvestigateCorpse,  -- Fallback: standard corpse investigation
    _prior.Restore,
    _bh.Interact,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

-- Post-conversion: handled automatically by GetTreeFor() returning the new role's tree.
-- Once TTT2UpdateSubrole fires, GetRoleStringRaw() returns the new role name, and
-- GetRoleFor(bot):GetBTree() returns that role's registered behavior tree.

local roleDescription = "The Amnesiac is a neutral role with no team allegiances and cannot win on its own. "
    .. "Your primary objective is to search unconfirmed corpses — doing so copies the dead player's role and team. "
    .. "Be warned: when you convert, a global popup announces it to all players, so discretion after conversion is critical. "
    .. "You have a built-in radar that shows unconfirmed corpse locations. "
    .. "You can also kill a player and search their body to steal their role."

local amnesiac = TTTBots.RoleData.New("amnesiac", TEAM_NONE)
amnesiac:SetDefusesC4(false)
amnesiac:SetStartsFights(false)
amnesiac:SetCanCoordinate(false)
amnesiac:SetUsesSuspicion(false)
amnesiac:SetTeam(TEAM_NONE)
amnesiac:SetBTree(preConversionTree)
amnesiac:SetBuyableWeapons({})
amnesiac:SetKnowsLifeStates(true)
amnesiac:SetAlliedTeams(allyTeams)
amnesiac:SetLovesTeammates(false)
amnesiac:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(amnesiac)

-- ---------------------------------------------------------------------------
-- Runtime tree override: ensure the pre-conversion tree is used while
-- the bot is still Amnesiac, and the new role's tree takes over seamlessly
-- after conversion. Uses the chain pattern (Infected, Necromancer, Cupid).
-- ---------------------------------------------------------------------------
local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor
function TTTBots.Behaviors.GetTreeFor(bot)
    if not IsValid(bot) then return nil end

    -- Only intercept for Amnesiac role
    if bot:GetSubRole() == ROLE_AMNESIAC then
        return preConversionTree
    end

    -- During the transition grace period, force re-evaluation from the new role's tree
    -- by clearing stale behavior state (coordinator handles the heavy lifting)
    if bot._amnesiacTransitionGrace and CurTime() < bot._amnesiacTransitionGrace then
        -- Let the chain resolve to the new role's tree
        return _origGetTreeFor(bot)
    end

    return _origGetTreeFor(bot)
end

return true
