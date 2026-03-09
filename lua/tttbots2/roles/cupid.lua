--- Cupid behaviour for TTT2, a role that can link two players as "Lovers".
--- Once linked, both lovers move to TEAM_LOVER and share death (one dies → other dies).
--- This file provides:
---   - Dynamic behavior tree switching (pre-link vs post-link)
---   - Helper functions for other systems to query Cupid/Lover status
---   - GetTreeFor chain hook following the Infected/Necromancer pattern

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_CUPID then return false end

local lib = TTTBots.Lib

TEAM_JESTER = TEAM_JESTER or "jesters"

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_LOVER] = true,
}

local allyRoles = {
    sidekick = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- ---------------------------------------------------------------------------
-- Pre-link tree: Cupid still has the weapon, urgently find targets to pair.
-- CreateLovers handles urgency escalation internally.
-- ---------------------------------------------------------------------------
local preLinkTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _bh.CreateLovers,
    _prior.Restore,
    _prior.Minge,
    _bh.Stalk,
    _prior.Investigate,
    _prior.Patrol,
}

-- ---------------------------------------------------------------------------
-- Post-link tree: Lovers are created, fight to win with partner coordination.
-- ProtectLover keeps the bot near their lover (shared death = self-preservation).
-- Stalk/FightBack handle aggressive combat.
-- ---------------------------------------------------------------------------
local postLinkTree = {
    _prior.Chatter,
    _prior.FightBack,
    _bh.ProtectLover,
    _prior.Requests,
    _prior.Restore,
    _prior.Minge,
    _bh.Stalk,
    _prior.Investigate,
    _prior.Patrol,
}

-- ---------------------------------------------------------------------------
-- Dynamic tree selector: check if Cupid has linked lovers yet.
-- ---------------------------------------------------------------------------
local function getCupidTree(bot)
    if not IsValid(bot) then return preLinkTree end

    -- If the bot is in love (lover pairing complete), use post-link tree
    if bot.inLove then
        return postLinkTree
    end

    -- Check if the global lovedones table contains this bot
    if lovedones and istable(lovedones) and #lovedones >= 3 then
        for _, v in ipairs(lovedones) do
            if v == bot then
                return postLinkTree
            end
        end
    end

    -- Check if the bot still has the Cupid weapon
    local inv = bot:BotInventory()
    if inv then
        local gun = inv:GetLoversGun()
        if not gun then
            -- Weapon stripped but not in love — time ran out, fall back to post-link
            -- (effectively an innocent-like tree without CreateLovers)
            return postLinkTree
        end
    end

    return preLinkTree
end

-- ---------------------------------------------------------------------------
-- Helper functions for other systems to query Cupid/Lover status
-- ---------------------------------------------------------------------------

--- Returns true if the given bot/player is a linked Cupid (lovers created).
---@param ply Player
---@return boolean
function TTTBots.Roles.IsCupidLinked(ply)
    if not IsValid(ply) then return false end
    if ply.inLove then return true end
    if lovedones and istable(lovedones) and #lovedones >= 3 then
        for _, v in ipairs(lovedones) do
            if v == ply then return true end
        end
    end
    return false
end

--- Returns true if the given player is a lover (not necessarily the Cupid).
---@param ply Player
---@return boolean
function TTTBots.Roles.IsLover(ply)
    if not IsValid(ply) then return false end
    return ply.inLove == true
end

--- Returns the lover partner of the given player, or nil.
---@param ply Player
---@return Player?
function TTTBots.Roles.GetCupidLover(ply)
    if not IsValid(ply) then return nil end
    if not lovedones or not istable(lovedones) or #lovedones < 2 then return nil end

    if lovedones[1] == ply then return lovedones[2] end
    if lovedones[2] == ply then return lovedones[1] end

    return nil
end

--- Returns the Cupid player (lovedones[3]) if the given player is in the lover pair.
---@param ply Player
---@return Player?
function TTTBots.Roles.GetCupidForLover(ply)
    if not IsValid(ply) then return nil end
    if not lovedones or not istable(lovedones) or #lovedones < 3 then return nil end

    if lovedones[1] == ply or lovedones[2] == ply then
        return lovedones[3]
    end

    return nil
end

-- ---------------------------------------------------------------------------
-- Role definition
-- ---------------------------------------------------------------------------

local roleDescription = "The Cupid is a special role with a unique twist. "
    .. "You have a Cupid Crossbow that links two players as Lovers. "
    .. "Once linked, both lovers (and optionally Cupid) move to Team Lovers. "
    .. "Lovers share death — if one dies, the other follows. "
    .. "Your goal is to kill all non-lovers. Protect your partner!"

local cupid = TTTBots.RoleData.New("cupid", TEAM_LOVER)
cupid:SetDefusesC4(false)
cupid:SetCanCoordinate(true)
cupid:SetCanHaveRadar(true)
cupid:SetStartsFights(true)
cupid:SetUsesSuspicion(false)
cupid:SetTeam(TEAM_LOVER)
cupid:SetBTree(preLinkTree)  -- default; overridden at runtime by GetTreeFor
cupid:SetAlliedTeams(allyTeams)
cupid:SetAlliedRoles(allyRoles)
cupid:SetLovesTeammates(true)
cupid:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(cupid)

-- ---------------------------------------------------------------------------
-- Runtime tree override: swap tree based on pre-link/post-link status.
-- Follows the Infected/Necromancer chain pattern.
-- ---------------------------------------------------------------------------
local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor
function TTTBots.Behaviors.GetTreeFor(bot)
    if not IsValid(bot) then return nil end

    -- Only intercept for cupid role or players on TEAM_LOVER
    local role = TTTBots.Roles.GetRoleFor(bot)
    if role then
        local roleName = role:GetName()
        if roleName == "cupid" then
            return getCupidTree(bot)
        end
    end

    -- Players who got pulled to TEAM_LOVER but aren't Cupid should also get post-link tree
    if bot.inLove and bot:GetTeam() == TEAM_LOVER then
        return postLinkTree
    end

    return _origGetTreeFor(bot)
end

return true
