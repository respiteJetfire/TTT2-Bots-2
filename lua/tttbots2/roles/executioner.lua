--- Executioner role integration for TTT Bots 2
--- The Executioner is a Traitor with a target contract mechanic:
---   • Assigned a single "target" at round start (random enemy player).
---   • Deals 2× damage to their target and only 0.5× damage to non-targets.
---   • Killing a non-target (excluding exempt roles) breaks the contract —
---     no new target for ~60 seconds and damage stays at 0.5×.
---   • After the punishment expires, a new target is assigned.
---
--- Bot strategy:
---   • Always prioritise attacking the current contract target.
---   • Avoid shooting non-target enemies unless forced into self-defense.
---   • During punishment period, play defensively like a weakened traitor.
---   • Use ExecutionerTarget behavior to enforce focus-fire on the contract.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_EXECUTIONER then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription =
    "You are the Executioner, a Traitor with a contract system. "
    .. "You are assigned a single target at round start and deal double damage to them, "
    .. "but only half damage to everyone else. "
    .. "Killing a non-target enemy breaks your contract for 60 seconds, during which "
    .. "you deal half damage to everyone. Focus all attacks on your current contract target. "
    .. "Exempt roles (Jester, Swapper, Cursed, Amnesiac, Clown, Drunk, Marker, Beggar, Medic) "
    .. "are never assigned as targets and attacking them won't break the contract."

local bTree = {
    _prior.Requests,
    _prior.Chatter,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Grenades,
    _bh.ExecutionerTarget,  -- Focus-fire the contract target; avoid non-targets
    _prior.Support,
    _prior.Deception,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol,
}

local executioner = TTTBots.RoleData.New("executioner")
executioner:SetDefusesC4(false)
executioner:SetPlantsC4(true)
executioner:SetTeam(TEAM_TRAITOR)
executioner:SetBTree(bTree)
executioner:SetCanCoordinate(true)
executioner:SetCanHaveRadar(true)
executioner:SetStartsFights(true)
executioner:SetUsesSuspicion(false)
executioner:SetCanSnipe(true)
executioner:SetCanHide(true)
executioner:SetKnowsLifeStates(true)   -- isOmniscientRole
executioner:SetLovesTeammates(true)
executioner:SetAlliedTeams({ [TEAM_TRAITOR] = true })
executioner:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(executioner)

-- ---------------------------------------------------------------------------
-- Contract-target awareness: cache the current target from addon NW data.
-- EXCT_DATA.GetCurrentTarget(ply) is set by the Executioner addon.
-- We also fall back to reading the NW entity "exct_target" if the global
-- isn't available.
-- ---------------------------------------------------------------------------

--- Returns the Executioner's current contract target, or nil.
---@param bot Player
---@return Player|nil
function TTTBots.Executioner_GetTarget(bot)
    if not IsValid(bot) then return nil end

    -- Prefer addon API if available
    if EXCT_DATA and EXCT_DATA.GetCurrentTarget then
        local t = EXCT_DATA.GetCurrentTarget(bot)
        if IsValid(t) then return t end
    end

    -- Fallback: NW entity key used by the addon
    local t = bot:GetNWEntity("exct_target", nil)
    if IsValid(t) then return t end

    return nil
end

--- Returns true if the Executioner is currently in a punishment period
--- (contract was broken, no target, reduced damage).
---@param bot Player
---@return boolean
function TTTBots.Executioner_IsPunished(bot)
    if not IsValid(bot) then return false end

    if EXCT_DATA and EXCT_DATA.BrokeContract then
        return EXCT_DATA.BrokeContract(bot) == true
    end

    return bot:GetNWBool("exct_broke_contract", false)
end

-- ---------------------------------------------------------------------------
-- Suspicion hook: the Executioner should appear as a normal traitor.
-- ---------------------------------------------------------------------------

hook.Add("TTTBotsModifySuspicion", "TTTBots.executioner.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    if target:GetRoleStringRaw() ~= "executioner" then return end
    -- No suspicion modifier — Executioner plays like any traitor.
end)

print("[TTT Bots 2] Executioner role integration loaded.")
return true
