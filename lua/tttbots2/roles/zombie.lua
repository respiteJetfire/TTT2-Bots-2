--- zombie.lua (necromancer zombie)
--- RoleData for the Necromancer's zombie minion.
--- Zombies are created when the Necromancer uses the Necro Defibrillator on a corpse.
--- They can ONLY carry weapon_ttth_zombpistol (zombie deagle) with 7 finite rounds.
--- When ammo runs out, the zombie self-destructs. They are overt — everyone can see
--- their zombie player model and knows they are hostile.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_ZOMBIE then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"
TEAM_NECROMANCER = TEAM_NECROMANCER or "necromancers"

local allyTeams = {
    [TEAM_NECROMANCER] = true,
    [TEAM_JESTER] = true,
}

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- ---------------------------------------------------------------------------
-- Zombie behavior tree: pure offensive minion.
-- No investigation, no support, no health stations, no weapon gathering.
-- ---------------------------------------------------------------------------
local zombieTree = {
    _prior.Chatter,
    _prior.FightBack,        -- Defend if being attacked
    _bh.ZombieAttack,        -- Proactively hunt non-allies with deagle
    _bh.ZombieProtectMaster, -- Stay near necromancer when idle
    _prior.Patrol,           -- Wander if nothing else to do
}

local zombieRoleDescription = "You are a Zombie, raised from the dead by the Necromancer. "
    .. "You are hostile to all players except your Necromancer master and other zombies. "
    .. "You can ONLY use the Zombie Deagle — a powerful pistol with just 7 rounds and no reserve ammo. "
    .. "When your ammo runs out, you will self-destruct and die. Every shot counts! "
    .. "Your goal is to protect your master and eliminate all non-allies. "
    .. "You are slow (half walk speed) and visibly a zombie — everyone knows you are hostile. "
    .. "Speak in broken, groaning sentences. You are undead and barely coherent."

local zombie = TTTBots.RoleData.New("zombie", TEAM_NECROMANCER)
zombie:SetDefusesC4(false)
zombie:SetStartsFights(true)
zombie:SetCanHaveRadar(false)         -- Zombies don't use radar
zombie:SetCanCoordinate(true)         -- Can coordinate with necro team
zombie:SetUsesSuspicion(false)        -- Omniscient, no need for suspicion
zombie:SetTeam(TEAM_NECROMANCER)
zombie:SetBuyableWeapons({})          -- Zombies cannot buy anything
zombie:SetKnowsLifeStates(true)      -- Knows who is alive/dead
zombie:SetAlliedTeams(allyTeams)
zombie:SetLovesTeammates(true)        -- Won't attack TEAM_NECROMANCER members
zombie:SetKOSAll(true)                -- Zombies attack all non-allies
zombie:SetKOSedByAll(true)            -- Everyone knows zombies are hostile
zombie:SetAutoSwitch(false)           -- Don't auto-switch away from zombie deagle
zombie:SetPreferredWeapon("weapon_ttth_zombpistol")
zombie:SetRoleDescription(zombieRoleDescription)
zombie:SetBTree(zombieTree)

TTTBots.Roles.RegisterRole(zombie)

return true
