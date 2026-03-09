if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_NECROMANCER then return false end

local lib = TTTBots.Lib

TEAM_JESTER = TEAM_JESTER or "jesters"

local allyTeams = {
    [TEAM_NECROMANCER] = true,
    [TEAM_JESTER] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- ---------------------------------------------------------------------------
-- Necromancer tree: stealthy corpse-seeker who converts the dead into zombies.
-- Uses NecroDefib as the primary behavior after FightBack.
-- Support is removed because the generic defib behaviors don't work with
-- weapon_ttth_necrodefi (BUG-1 fix).
-- ---------------------------------------------------------------------------
local necroTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Requests,
    _bh.NecroDefib,     -- Dedicated necro defi behavior (corpse → zombie)
    _prior.Deception,   -- AlibiBuilding, FakeInvestigate, PlausibleIgnorance (EARLY blend-in)
    _prior.Restore,
    _bh.Stalk,          -- Stalk isolated targets (after deception is exhausted)
    _prior.Investigate,
    _prior.Minge,
    _prior.Patrol,
}

-- ---------------------------------------------------------------------------
-- Zombie tree: used by dynamic tree switching when this bot is a zombie.
-- Pure offensive minion — no investigation, no support.
-- ---------------------------------------------------------------------------
local zombieTree = {
    _prior.Chatter,
    _prior.FightBack,
    _bh.ZombieAttack,
    _bh.ZombieProtectMaster,
    _prior.Patrol,
}

-- ---------------------------------------------------------------------------
-- Dynamic tree selector: checks if bot is necromancer master or zombie.
-- Falls back to necromancer tree if undetermined.
-- ---------------------------------------------------------------------------
local function getNecroTree(bot)
    if not IsValid(bot) then return necroTree end

    -- Check subrole directly
    if ROLE_ZOMBIE and bot:GetSubRole() == ROLE_ZOMBIE then
        return zombieTree
    end

    -- Default: necromancer master
    return necroTree
end

-- ---------------------------------------------------------------------------
-- Helper functions for other systems to query necro/zombie status.
-- ---------------------------------------------------------------------------

--- Helper: returns true if the given bot is a necromancer zombie (not the master).
---@param bot Player
---@return boolean
function TTTBots.Roles.IsNecroZombie(bot)
    if not IsValid(bot) then return false end
    if not ROLE_ZOMBIE then return false end
    return bot:GetSubRole() == ROLE_ZOMBIE
end

--- Helper: returns true if the given bot is a necromancer master (not a zombie).
---@param bot Player
---@return boolean
function TTTBots.Roles.IsNecroMaster(bot)
    if not IsValid(bot) then return false end
    if not ROLE_NECROMANCER then return false end
    return bot:GetSubRole() == ROLE_NECROMANCER
end

--- Helper: returns the necromancer master for a given zombie bot, or nil.
---@param bot Player
---@return Player?
function TTTBots.Roles.GetNecroMaster(bot)
    if not IsValid(bot) then return nil end

    -- Check the zombieMaster field set by AddZombie()
    if IsValid(bot.zombieMaster) then
        return bot.zombieMaster
    end

    -- Fallback: find a living necromancer on the same team
    if ROLE_NECROMANCER then
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:GetSubRole() == ROLE_NECROMANCER and lib.IsPlayerAlive(ply) then
                return ply
            end
        end
    end

    return nil
end

-- ---------------------------------------------------------------------------
-- Role description for LLM prompt system (BUG-4 fix).
-- ---------------------------------------------------------------------------

local roleDescription = "You are the Necromancer — a dark master who raises the dead as zombie minions. "
    .. "You have a Necro Defibrillator that converts corpses into Zombies on your team. "
    .. "Seek out isolated corpses and revive them when no one is watching. "
    .. "Your zombies are armed with a limited-ammo deagle and will self-destruct when empty. "
    .. "You also have access to the traitor shop. Coordinate with your zombie army to outlast all other teams. "
    .. "Be stealthy about reviving — if you're caught, everyone will turn on you. "
    .. "You win when only Team Necromancer remains."

local necromancer = TTTBots.RoleData.New("necromancer", TEAM_NECROMANCER)
necromancer:SetDefusesC4(false)
necromancer:SetStartsFights(true)
necromancer:SetCanHaveRadar(true)
necromancer:SetCanCoordinate(true)
necromancer:SetUsesSuspicion(false)
necromancer:SetTeam(TEAM_NECROMANCER)
necromancer:SetKnowsLifeStates(true)
necromancer:SetAlliedTeams(allyTeams)
necromancer:SetLovesTeammates(true)
necromancer:SetRoleDescription(roleDescription)
necromancer:SetBTree(necroTree) -- default; overridden at runtime by GetTreeFor hook

TTTBots.Roles.RegisterRole(necromancer)

-- ---------------------------------------------------------------------------
-- Runtime tree override: swap tree based on necromancer/zombie status each tick.
-- We hook into GetTreeFor by storing the original function and wrapping it.
-- This follows the same pattern as the infected role's dynamic tree switching.
-- ---------------------------------------------------------------------------
local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor
function TTTBots.Behaviors.GetTreeFor(bot)
    if not IsValid(bot) then return nil end

    -- Only intercept for necromancer team roles
    local role = TTTBots.Roles.GetRoleFor(bot)
    if role then
        local roleName = role:GetName()
        if roleName == "necromancer" or roleName == "zombie" then
            return getNecroTree(bot)
        end
    end

    return _origGetTreeFor(bot)
end

return true
