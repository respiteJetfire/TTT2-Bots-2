if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_INFECTED then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local allyTeams = {
    [TEAM_INFECTED] = true,
    [TEAM_JESTER] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- ---------------------------------------------------------------------------
-- Host tree: the original infected player who has full weapons + fists.
-- Plays like a stealthy killer — stalk isolated victims to convert them.
-- ---------------------------------------------------------------------------
local hostTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Requests,
    _prior.Deception,   -- AlibiBuilding, PlausibleIgnorance (EARLY blend-in)
    _prior.Restore,
    _bh.Stalk,          -- Stalk isolated targets (core mechanic)
    _prior.Investigate,
    _prior.Minge,
    _prior.Patrol,
}

-- ---------------------------------------------------------------------------
-- Zombie tree: converted players who only have fists.
-- Pure melee aggression — rush targets, protect the host.
-- ---------------------------------------------------------------------------
local zombieTree = {
    _prior.Chatter,
    _prior.FightBack,
    _bh.InfectedRush,
    _bh.ProtectHost,
    _prior.Patrol,
}

-- ---------------------------------------------------------------------------
-- Dynamic tree selector: checks INFECTEDS global to determine host vs zombie.
-- Host = key in INFECTEDS table (has a zombie list).
-- Zombie = NOT a key, but IS a value in one of the zombie lists.
-- Falls back to host tree if undetermined (e.g. round start before any infections).
-- ---------------------------------------------------------------------------
local function getInfectedTree(bot)
    if not IsValid(bot) then return hostTree end

    -- If INFECTEDS global exists and this bot is a key, they are the host
    if INFECTEDS and INFECTEDS[bot] then
        return hostTree
    end

    -- Check if this bot appears in any host's zombie list
    if INFECTEDS then
        for _, zombies in pairs(INFECTEDS) do
            if istable(zombies) then
                for _, zombie in ipairs(zombies) do
                    if zombie == bot then
                        return zombieTree
                    end
                end
            end
        end
    end

    -- Default: if INFECTEDS is empty or bot isn't tracked yet, assume host
    return hostTree
end

--- Helper: returns true if the given bot is a zombie (converted infected).
---@param bot Player
---@return boolean
function TTTBots.Roles.IsInfectedZombie(bot)
    if not IsValid(bot) then return false end
    if not INFECTEDS then return false end

    -- Quick check: if the bot IS a host key, they are NOT a zombie
    if INFECTEDS[bot] then return false end

    for _, zombies in pairs(INFECTEDS) do
        if istable(zombies) then
            for _, zombie in ipairs(zombies) do
                if zombie == bot then
                    return true
                end
            end
        end
    end

    return false
end

--- Helper: returns true if the given bot is a host (original infected).
---@param bot Player
---@return boolean
function TTTBots.Roles.IsInfectedHost(bot)
    if not IsValid(bot) then return false end
    if not INFECTEDS then return false end
    return INFECTEDS[bot] ~= nil
end

--- Helper: returns the host player entity for a given zombie bot, or nil.
---@param bot Player
---@return Player?
function TTTBots.Roles.GetInfectedHost(bot)
    if not IsValid(bot) then return nil end
    if not INFECTEDS then return nil end

    for host, zombies in pairs(INFECTEDS) do
        if istable(zombies) then
            for _, zombie in ipairs(zombies) do
                if zombie == bot then
                    return host
                end
            end
        end
    end

    return nil
end

local roleDescription = "The Infected role is hostile to all players. "
    .. "As the Host, you stalk and kill isolated players — each kill converts the victim into a melee-only Zombie on your team. "
    .. "As a Zombie, you rush enemies with your fists and protect your Host. If the Host dies, all Zombies die too!"

local infected = TTTBots.RoleData.New("infected", TEAM_INFECTED)
infected:SetDefusesC4(false)
infected:SetStartsFights(true)
infected:SetCanHaveRadar(true)
infected:SetCanCoordinate(true)
infected:SetUsesSuspicion(false)
infected:SetTeam(TEAM_INFECTED)
infected:SetBuyableWeapons({})  -- Infected has no shop
infected:SetKnowsLifeStates(true)
infected:SetAlliedTeams(allyTeams)
infected:SetLovesTeammates(true)
infected:SetKOSAll(true)         -- Infected attacks everyone non-allied
infected:SetKOSedByAll(true)     -- Everyone should attack visible zombies
infected:SetAutoSwitch(false)    -- Don't auto-switch away from fists
infected:SetPreferredWeapon("weapon_ttt_inf_fists")
infected:SetRoleDescription(roleDescription)

-- Use a wrapper that returns the dynamically-selected tree
infected:SetBTree(hostTree) -- default; overridden at runtime by GetTreeFor hook

TTTBots.Roles.RegisterRole(infected)

-- ---------------------------------------------------------------------------
-- Runtime tree override: swap tree based on host/zombie status each tick.
-- We hook into GetTreeFor by storing the original function and wrapping it.
-- ---------------------------------------------------------------------------
local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor
function TTTBots.Behaviors.GetTreeFor(bot)
    if not IsValid(bot) then return nil end

    -- Only intercept for infected role
    local role = TTTBots.Roles.GetRoleFor(bot)
    if role and role:GetName() == "infected" then
        return getInfectedTree(bot)
    end

    return _origGetTreeFor(bot)
end

return true
