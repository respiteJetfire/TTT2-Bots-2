--- Master Chief role integration for TTT Bots 2
--- The Master Chief is a powerful, omniscient, public policing role on the innocent team.
--- It spawns with the BR55 Battle Rifle (burst-fire precision weapon), extra HP (150 by default),
--- body armor, and optionally a radar or tracker depending on server configuration.
---
--- Key mechanics:
---   • isOmniscientRole = true    → knows everyone's role immediately
---   • isPublicRole = true         → all players know who Master Chief is (KOS target for traitors)
---   • isPolicingRole = true       → can police and call out suspects publicly
---   • unknownTeam = true          → doesn't know who their specific teammates are (uses suspicion)
---   • defaultTeam = TEAM_INNOCENT → allied with innocents; defuses C4
---   • shopFallback = SHOP_FALLBACK_DETECTIVE → has access to the detective shop
---   • Extra HP (150) and armor — more durable than standard innocents
---   • High kill score multiplier (8x) — reward-driven role designed to hunt aggressively
---
--- Bot behavior:
---   • DetectiveLike base: investigate corpses, DNA scan, coordinate with innocents
---   • Omniscient: no suspicion system needed (knows roles directly)
---   • Prefers BR55 battle rifle — accurate burst-fire weapon, suited to mid-range hunting
---   • Radar awareness: bot respects CanHaveRadar flag (set conditionally based on tracker_mode)
---   • Aggressive hunter: FightBack priority is high; actively stalks known traitors
---   • Public role: bot doesn't hide (everyone already knows who it is)
---   • Higher durability means it can sustain fights longer than standard bots

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_MASTERCHIEF then return false end

local _bh    = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- Resolve the custom team — InitCustomTeam creates TEAM_MASTERCHIEF dynamically.
-- Fall back to TEAM_INNOCENT if the addon hasn't initialised the team yet.
local MC_TEAM = TEAM_MASTERCHIEF or TEAM_INNOCENT

-- ---------------------------------------------------------------------------
-- Custom behavior tree
-- Master Chief is an omniscient, heavily armored public hunter.
-- Priorities:
--   1. React to immediate combat — Chief's high HP lets it sustain fights
--   2. Actively stalk known-hostile targets (omniscient: knows traitors immediately)
--   3. Support allied innocents (defibrillator, call for backup)
--   4. Corpse investigation (detective-like intel gathering + score)
--   5. Standard detective support flow (defuse, restore, investigate, patrol)
-- No Minge / Deception (public role — cover is irrelevant)
-- No Patrol alone (Chief should be hunting, not wandering aimlessly)
-- ---------------------------------------------------------------------------
local masterChiefTree = {
    _prior.Chatter,             -- 1. Callouts (public role: Chief calls out traitors loudly)
    _prior.FightBack,           -- 2. React to incoming fire (high HP = sustain and fight back)
    _bh.Stalk,                  -- 3. Proactively hunt known-hostile targets (omniscient)
    _prior.Requests,            -- 4. Respond to wait/ceasefire requests
    _prior.Support,             -- 5. Defibrillator / help allied players
    _bh.Defib,                  -- 6. Revive fallen innocents
    _bh.Defuse,                 -- 7. Defuse C4 (innocent-team duty)
    _bh.InvestigateCorpse,      -- 8. Search bodies for intel (detective-like scoring)
    _prior.Accuse,              -- 9. Issue KOS calls on confirmed traitors (omniscient)
    _prior.Restore,             -- 10. Grab ammo/health/weapons when not in combat
    _bh.Interact,               -- 11. Interact with environment
    _prior.Investigate,         -- 12. Investigate suspicious noises / events
    _bh.Decrowd,                -- 13. Avoid clustering (Chief is a high-value target)
    _prior.Patrol,              -- 14. Patrol when nothing else to do
}

local roleDescription = "You are Master Chief — the super-soldier hero of TTT2. "
    .. "You have 150 HP, body armor, and the Battle Rifle (BR55), a precise burst-fire weapon. "
    .. "You are an omniscient public policing role: you know the role of every player, "
    .. "and everyone knows who you are. You are allied with the innocents. "
    .. "Your job is to hunt traitors and other hostile roles aggressively. "
    .. "You may have a radar or tracker depending on server configuration. "
    .. "You cannot coordinate with standard teammates directly (unknownTeam), "
    .. "but you have detective shop access and can call out traitors publicly. "
    .. "Do not hesitate — you have the health, armor, and knowledge to win every fight."

-- ---------------------------------------------------------------------------
-- Role registration
-- ---------------------------------------------------------------------------
-- Use DetectiveLike as the foundation: it sets up innocent-team defaults,
-- detective tree base, radar capability, policing appearance, and suspicion.
-- We then override with Master Chief's specific tweaks.
local masterchief = TTTBots.RoleBuilder.DetectiveLike("masterchief")

-- Override the generic detective tree with the Chief-specific hunting tree
masterchief:SetBTree(masterChiefTree)

-- Omniscient: Chief knows everyone's roles — no need for the suspicion system
masterchief:SetUsesSuspicion(false)

-- Omniscient roles know who is alive/dead at all times
masterchief:SetKnowsLifeStates(true)

-- unknownTeam = true: Chief doesn't know specific teammate identities via coordination
-- but still appears as innocent/policing to other bots
masterchief:SetCanCoordinate(false)          -- No traitor-side coordination (innocent role)
masterchief:SetCanCoordinateInnocent(true)   -- Can still work with detective-side coordinator

-- Public role: don't hide, don't snipe from cover (Chief fights in the open)
-- Allow sniper positions only if it gives a tactical advantage
masterchief:SetCanHide(false)   -- Public role — hiding is pointless, Chief is always known
masterchief:SetCanSnipe(true)   -- BR55 is accurate; sniping from elevated positions is valid

-- Chief doesn't know teammates by team membership (unknownTeam = true)
masterchief:SetLovesTeammates(false)

-- Radar: respect the tracker_mode convar — if set to RADAR (mode 1), Chief has radar.
-- The loadout hook gives item_ttt_radar only when tracker_mode == 1.
-- We conservatively enable radar (the role *can* have it depending on settings).
masterchief:SetCanHaveRadar(true)

-- Chief is KOS to traitors (public role). Chief should KOS unknown players who
-- become confirmed hostile via omniscient knowledge, but NOT random unknowns
-- (behave like a detective: KOS based on evidence, not paranoia).
masterchief:SetKOSUnknown(false)

-- Allied with the innocent team; also allied with jester team (don't attack jesters)
TEAM_JESTER = TEAM_JESTER or "jesters"
masterchief:SetAlliedTeams({
    [TEAM_INNOCENT] = true,
    [MC_TEAM]       = true,   -- allied with own custom team
    [TEAM_JESTER]   = true,   -- don't KOS jesters (treat as neutral)
})

-- Chief knows itself and detective-adjacent roles as confirmed allies
masterchief:SetAlliedRoles({
    masterchief = true,
    detective   = true,
    deputy      = true,
    sheriff     = true,
})

-- Prefer the BR55 battle rifle — Chief's signature weapon
masterchief:SetPreferredWeapon("br55")

-- Keep auto-switch enabled so Chief can pick up better weapons during combat
-- The BR55 is given by loadout so it will always be available
masterchief:SetAutoSwitch(true)

-- Chief starts fights with known hostiles (omniscient = confident aggression)
masterchief:SetStartsFights(true)

masterchief:SetRoleDescription(roleDescription)

TTTBots.Roles.RegisterRole(masterchief)

-- ---------------------------------------------------------------------------
-- Hook: react to tracker_mode convar — if the server gives radar/tracker,
-- we ensure the bot's CanHaveRadar flag matches the active configuration.
-- Called once at role load to set the initial value cleanly.
-- ---------------------------------------------------------------------------
hook.Add("InitPostEntity", "TTTBots.masterchief.TrackerModeCheck", function()
    local roleData = TTTBots.Roles and TTTBots.Roles.GetRoleData and TTTBots.Roles.GetRoleData("masterchief")
    if not roleData then return end

    local trackerMode = GetConVar("ttt2_masterchief_tracker_mode")
    if trackerMode then
        -- Mode 0 = no tracking device; still allow since omniscient role compensates
        -- Mode 1 = radar; mode 2 = tracker → both give extra info
        local mode = trackerMode:GetInt()
        roleData:SetCanHaveRadar(mode >= 1)
    end
end)

print("[TTT Bots 2] Master Chief role integration loaded — omniscient public hunter with BR55.")

return true
