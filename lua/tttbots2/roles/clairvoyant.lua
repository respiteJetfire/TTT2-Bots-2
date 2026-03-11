if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_CLAIRVOYANT then return false end


local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- ---------------------------------------------------------------------------
-- Clairvoyant Behavior Tree
-- Enhanced: intel gathering takes strategic position, combat/defense are high priority,
-- JesterHunt is conditional (only loads if Jester+Sidekick addons exist),
-- and Accuse is included since the Clairvoyant is an information role.
-- ---------------------------------------------------------------------------
local bTree = {
    _prior.Chatter,                        -- Social presence
    _prior.FightBack,                      -- Immediate combat response (HIGH priority for survival)
    _prior.SelfDefense,                    -- Defend from accusations
    _prior.Grenades,                       -- Grenade usage if applicable
    _prior.Accuse,                         -- Accuse suspicious players (critical for info role!)
    _bh.ClairvoyantIntel,                  -- Strategic intel revelation (after combat, before support)
    -- ClairvoyantJesterHunt inserted below conditionally
    _prior.Requests,                       -- Respond to requests
    _bh.FollowInnocentPlan,                -- Follow innocent team plans
    _prior.Support,                        -- Support allies
    _bh.Defuse,                            -- Defuse C4
    _prior.Restore,                        -- Pick up weapons/health/ammo
    _bh.Interact,                          -- Interact with environment
    _prior.Investigate,                    -- Investigate corpses and noises
    _prior.Minge,                          -- Occasional minge behavior
    _bh.Decrowd,                           -- Avoid overcrowding
    _prior.Patrol                          -- Default patrol fallback
}

-- Conditionally insert JesterHunt behavior if Jester+Sidekick addons are installed.
-- This prevents a nil entry in the BTree which would crash the tree iterator.
if _bh.ClairvoyantJesterHunt then
    table.insert(bTree, 7, _bh.ClairvoyantJesterHunt) -- After ClairvoyantIntel, before Requests
end

local roleDescription = "You are the Clairvoyant — an innocent-team role with the unique ability to detect "
    .. "which players have special (non-vanilla) roles. On the scoreboard, special-role players appear "
    .. "with a purple highlight. You cannot identify WHAT role they have — only THAT they have one. "
    .. "Special roles include both dangerous ones (Serial Killer, Infected) and benign ones (Amnesiac, Drunk). "
    .. "Use this information strategically: share intel with trusted allies, raise suspicion on special-role "
    .. "players who act suspiciously, and help the innocent team deduce threats. "
    .. "WARNING: Do not reveal your ability too openly — traitors will target you if they know you're the Clairvoyant. "
    .. "If both Jester and Sidekick addons are installed, you can kill the Jester to convert them into your loyal Sidekick. "
    .. "Win condition: eliminate all traitors (standard innocent victory)."

local clairvoyant = TTTBots.RoleData.New("clairvoyant")
clairvoyant:SetDefusesC4(true)
clairvoyant:SetTeam(TEAM_INNOCENT)
clairvoyant:SetCanHide(true)
clairvoyant:SetCanSnipe(true)
clairvoyant:SetBTree(bTree)
clairvoyant:SetUsesSuspicion(true)
clairvoyant:SetIsFollower(true)               -- Follow groups for safety
clairvoyant:SetCanCoordinateInnocent(true)     -- Share intel with innocent team
clairvoyant:SetAlliedRoles({})
clairvoyant:SetAlliedTeams({})
clairvoyant:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(clairvoyant)

return true

