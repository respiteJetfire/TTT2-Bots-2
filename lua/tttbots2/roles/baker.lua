--- Baker / Famine role integration for TTT Bots 2
--- The Baker is a custom-team role (TEAM_HORSEMEN) with a two-phase design:
---
---   Phase 1 (Baker): Neutral baking role. The Baker distributes bread using
---     their baking weapon (weapon_ttt2_baker_baking). Players who eat bread
---     get healed. Once enough bread is eaten, the Baker transforms into the Famine.
---
---   Phase 2 (Famine): Aggressive horseman. The Famine starves all non-Horsemen
---     players periodically and gains extra health for each bread eaten.
---     The Famine should hunt and kill remaining players.
---
--- Transformation is server-driven (famine_handler.lua triggers it).
--- The bot detects its current subrole to pick the right behavior tree.

if not TTTBots.Lib.IsTTT2() then return false end

-- Baker and Famine may not both be defined if the addon isn't loaded
local hasBaker = ROLE_BAKER ~= nil
local hasFamine = ROLE_FAMINE ~= nil
if not hasBaker and not hasFamine then return false end

TEAM_HORSEMEN = TEAM_HORSEMEN or "horsemen"
TEAM_JESTER = TEAM_JESTER or "jesters"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- ---------------------------------------------------------------------------
-- Phase 1: Baker Tree — distribute bread, stay alive, act neutral
-- The Baker should seek out players to give bread to (using the baking weapon)
-- but otherwise play passively and avoid combat.
-- ---------------------------------------------------------------------------
local bakerTree = {
    _prior.Chatter,
    _prior.FightBack,              -- Self-defense only
    _prior.Requests,
    _bh.BakerBake,                 -- [NEW] Use baking weapon to create/distribute bread
    _prior.Restore,
    _bh.Interact,
    _bh.Decrowd,
    _prior.Patrol,
}

-- ---------------------------------------------------------------------------
-- Phase 2: Famine Tree — aggressive hunter
-- The Famine has extra health and players are starving.
-- Hunt aggressively to finish off weakened players.
-- ---------------------------------------------------------------------------
local famineTree = {
    _prior.Chatter,
    _prior.FightBack,
    _bh.Stalk,                     -- Hunt weakened/starving players
    _prior.Requests,
    _prior.Restore,
    _bh.Interact,
    _bh.Wander,
}

-- ---------------------------------------------------------------------------
-- Baker Registration
-- ---------------------------------------------------------------------------
if hasBaker then
    local bakerDesc = "You are the Baker, a neutral Horseman role. Use your baking weapon to create bread for players. "
        .. "When enough bread has been eaten, you will transform into the Famine — a deadly horseman "
        .. "that starves all non-allied players. Stay alive and distribute bread to trigger your transformation."

    local baker = TTTBots.RoleData.New("baker", TEAM_HORSEMEN)
    baker:SetDefusesC4(false)
    baker:SetPlantsC4(false)
    baker:SetTeam(TEAM_HORSEMEN)
    baker:SetBTree(bakerTree)
    baker:SetCanCoordinate(false)
    baker:SetCanHaveRadar(false)
    baker:SetStartsFights(false)          -- Baker is passive pre-transformation
    baker:SetUsesSuspicion(false)
    baker:SetNeutralOverride(true)         -- Don't get targeted proactively
    baker:SetKOSAll(false)
    baker:SetKOSedByAll(false)
    baker:SetLovesTeammates(true)
    baker:SetKnowsLifeStates(true)         -- isOmniscientRole = true
    baker:SetAutoSwitch(false)
    baker:SetPreferredWeapon("weapon_ttt2_baker_baking")
    baker:SetAlliedTeams({ [TEAM_HORSEMEN] = true })
    baker:SetAlliedRoles({ baker = true, famine = true })
    baker:SetRoleDescription(bakerDesc)
    TTTBots.Roles.RegisterRole(baker)
end

-- ---------------------------------------------------------------------------
-- Famine Registration
-- ---------------------------------------------------------------------------
if hasFamine then
    local famineDesc = "You are the Famine, a transformed Horseman. All non-Horsemen players are starving, "
        .. "taking periodic damage. You have bonus health that scales with how much bread was eaten. "
        .. "Hunt down weakened players and eliminate them. You win when all enemies are dead."

    local famine = TTTBots.RoleData.New("famine", TEAM_HORSEMEN)
    famine:SetDefusesC4(false)
    famine:SetPlantsC4(false)
    famine:SetTeam(TEAM_HORSEMEN)
    famine:SetBTree(famineTree)
    famine:SetCanCoordinate(false)
    famine:SetCanHaveRadar(false)
    famine:SetStartsFights(true)           -- Famine is aggressive
    famine:SetUsesSuspicion(false)
    famine:SetKOSAll(true)                 -- Kill all non-allies
    famine:SetKOSedByAll(true)             -- Everyone should fight the Famine
    famine:SetLovesTeammates(true)
    famine:SetKnowsLifeStates(true)        -- isOmniscientRole = true
    famine:SetAlliedTeams({ [TEAM_HORSEMEN] = true })
    famine:SetAlliedRoles({ baker = true, famine = true })
    famine:SetRoleDescription(famineDesc)
    TTTBots.Roles.RegisterRole(famine)
end

-- ---------------------------------------------------------------------------
-- Runtime tree override: swap tree when Baker transforms into Famine.
-- The TTT2 famine_handler.lua changes the role via SetRole(), so
-- GetRoleStringRaw() will return "famine" after transformation.
-- ---------------------------------------------------------------------------
local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor
function TTTBots.Behaviors.GetTreeFor(bot)
    if not IsValid(bot) then return nil end

    local roleString = bot:GetRoleStringRaw()

    if roleString == "baker" then
        return bakerTree
    end

    if roleString == "famine" then
        return famineTree
    end

    return _origGetTreeFor(bot)
end

-- ---------------------------------------------------------------------------
-- Suspicion hooks: Baker is neutral, Famine is hostile
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.baker.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    local role = target:GetRoleStringRaw()
    if role == "baker" then
        return mult * 0.1  -- Baker is neutral and harmless pre-transformation
    end
end)

print("[TTT Bots 2] Baker/Famine role integration loaded — two-phase horseman (baker → famine).")

return true
