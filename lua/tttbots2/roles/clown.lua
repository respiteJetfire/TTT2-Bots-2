--- Clown / Killer Clown bot behavior — two-phase role with dynamic tree switching.
--- Phase 1 (Clown): Passive survival — act jester-like, avoid environmental hazards,
---   stockpile weapons for post-transformation. Cannot deal or receive player damage.
--- Phase 2 (Killer Clown): Aggressive hunting — buy equipment, stalk and kill everyone.
---   Transformation is server-driven (automatic when one team remains).
--- Uses the GetTreeFor chain pattern (Infected, Necromancer, Amnesiac, Cupid) to
--- dynamically swap behavior trees when TTT2UpdateSubrole fires.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_CLOWN then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"
TEAM_CLOWN = TEAM_CLOWN or "clowns"

local allyTeams = {
    [TEAM_JESTER] = true,
    [TEAM_CLOWN] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- ---------------------------------------------------------------------------
-- Pre-Transformation Tree (Clown Phase): Passive survival focus
-- Priorities: Social blending → weapon stockpiling → jester-like minging
-- No FightBack (cannot deal damage), no Stalk (no kill intent)
-- Follow/GroupUp for safety in numbers; Restore for weapon stockpiling
-- ---------------------------------------------------------------------------
local preTransformTree = {
    _prior.Chatter,          -- Social presence (maintain cover as "harmless")
    _prior.Requests,         -- Respond to requests (appear cooperative)
    _bh.Interact,            -- Interact with props (jester-like behavior)
    _prior.Restore,          -- Pick up weapons (stockpile for post-transform!)
    _prior.Investigate,      -- Investigate corpses/noises (appear innocent)
    _prior.Minge,            -- Crowbar minge (classic jester behavior)
    _bh.Decrowd,             -- Avoid overly crowded areas (survival balance)
    _bh.Follow,              -- Follow players (blend in, stay near groups)
    _bh.Wander,              -- Default fallback
}

-- ---------------------------------------------------------------------------
-- Post-Transformation Tree (Killer Clown Phase): Aggressive hunting
-- Priorities: Immediate combat → active hunting → weapon management
-- No Investigate/Minge/Deception (transformation is PUBLIC, everyone knows)
-- Stalk is HIGH priority for proactive target acquisition
-- ---------------------------------------------------------------------------
local postTransformTree = {
    _prior.Chatter,          -- Callouts and taunts
    _prior.FightBack,        -- React to immediate combat (AttackTarget, SeekCover)
    _bh.Stalk,               -- Actively hunt isolated targets
    _prior.Requests,         -- Handle requests (mostly ignore — killing time)
    _prior.Restore,          -- Grab weapons/health/ammo
    _bh.Interact,            -- Interact with environment
    _bh.Wander,              -- Fallback when no targets found
}

local roleDescription = "The Clown is a Jester-like role that transforms into a Killer Clown. "
    .. "Traitors and hostile roles see you as a Jester — use this to survive. "
    .. "You cannot deal or receive player damage pre-transformation, but environmental hazards can still kill you. "
    .. "When only one team remains alive, you automatically transform into a Killer Clown with the traitor shop, "
    .. "bonus damage, and a mission to kill all remaining players. "
    .. "Pre-transformation: Act harmless, blend with crowds, stockpile weapons. "
    .. "Post-transformation: Hunt aggressively, buy equipment, eliminate everyone."

local clown = TTTBots.RoleData.New("clown", TEAM_CLOWN)
clown:SetDefusesC4(false)
clown:SetStartsFights(false)
clown:SetCanCoordinate(false)
clown:SetUsesSuspicion(false)
clown:SetTeam(TEAM_CLOWN)
clown:SetBTree(preTransformTree)  -- default; overridden at runtime by GetTreeFor hook
clown:SetBuyableWeapons({})
clown:SetKnowsLifeStates(true)
clown:SetNeutralOverride(true)
clown:SetAlliedTeams(allyTeams)
clown:SetLovesTeammates(false)
clown:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(clown)

-- ---------------------------------------------------------------------------
-- Runtime tree override: swap tree based on Clown vs Killer Clown status.
-- Handles BOTH role strings in one chain link to avoid double-chaining.
-- When TTT2UpdateSubrole fires and changes Clown → Killer Clown,
-- GetRoleStringRaw() immediately returns "killerclown" and the next tick
-- the tree switches to postTransformTree.
-- ---------------------------------------------------------------------------
local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor
function TTTBots.Behaviors.GetTreeFor(bot)
    if not IsValid(bot) then return nil end

    local roleString = bot:GetRoleStringRaw()

    -- Pre-transformation: passive survival tree
    if roleString == "clown" then
        return preTransformTree
    end

    -- Post-transformation: aggressive hunting tree
    if roleString == "killerclown" then
        return postTransformTree
    end

    return _origGetTreeFor(bot)
end

-- ---------------------------------------------------------------------------
-- Suspicion hook: reduce suspicion on the Clown (pre-transformation),
-- consistent with the Jester/Swapper pattern. Since traitors see the Clown
-- as a Jester, bots that "cheat_know_jester" should avoid suspecting it.
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.clown.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    local role = target:GetRoleStringRaw()
    if role == "clown" then
        if TTTBots.Lib.GetConVarBool("cheat_know_jester") then
            return mult * 0.1  -- Nearly zero suspicion (Clown mimics Jester)
        end
    end
end)

return true