--- Impostor role integration for TTT Bots 2
--- The Impostor is a Traitor inspired by Among Us with:
---   • Instant Kill: Press E (interact mode) or equip knife (knife mode) near an enemy
---     for a one-hit kill. Has a 45s cooldown. Timer pauses while in a vent.
---   • Normal weapon damage is halved (0.5× multiplier).
---   • Vent Network: 3 player-placed vents. Enter a vent to become invisible and
---     teleport between vents. Cannot attack while venting.
---   • Sabotages: Lights, Comms, O2, Reactor — each with 120s cooldown.
---     Activated by pressing V. Bot uses O2 and Reactor sabotages proactively.
---
--- Bot strategy:
---   • Rely on instant kill as primary DPS since normal damage is halved.
---   • Use ImpostorKill behavior to close the distance and execute instant kills.
---   • Use vents to escape combat and reposition.
---   • Periodically use sabotages to drain HP (O2) or finish the round (Reactor).

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_IMPOSTOR then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription =
    "You are the Impostor, a Traitor with no shop but powerful abilities. "
    .. "Your normal weapons deal only half damage — rely on your Instant Kill instead. "
    .. "Press E (or use your knife) while close to an enemy for an immediate kill (45s cooldown). "
    .. "You have 3 vents you can place and use to teleport around the map invisibly. "
    .. "You also have sabotages: use O2 to drain everyone's HP, or Reactor for a timed win condition. "
    .. "Do NOT attack inside vents. Instant kill is your main tool — get close, execute, escape."

local bTree = {
    _prior.Requests,
    _prior.Chatter,
    _prior.FightBack,
    _prior.SelfDefense,
    _bh.ImpostorKill,       -- Instant kill: close distance + execute
    _bh.ImpostorSabotage,   -- Use sabotages proactively
    _prior.Grenades,
    _prior.Support,
    _prior.Deception,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol,
}

local impostor = TTTBots.RoleData.New("impostor")
impostor:SetDefusesC4(false)
impostor:SetPlantsC4(false)
impostor:SetTeam(TEAM_TRAITOR)
impostor:SetBTree(bTree)
impostor:SetCanCoordinate(true)
impostor:SetCanHaveRadar(true)
impostor:SetStartsFights(true)
impostor:SetUsesSuspicion(false)
impostor:SetCanSnipe(false)          -- No shop, no sniper — melee/instant kill focus
impostor:SetCanHide(true)
impostor:SetKnowsLifeStates(true)    -- isOmniscientRole
impostor:SetLovesTeammates(true)
impostor:SetAlliedTeams({ [TEAM_TRAITOR] = true })
impostor:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(impostor)

-- ---------------------------------------------------------------------------
-- Helper: is the bot currently inside a vent?
-- ---------------------------------------------------------------------------
---@param bot Player
---@return boolean
function TTTBots.Impostor_IsVenting(bot)
    if not IsValid(bot) then return false end
    -- The addon sets impo_in_vent on the player entity while venting
    return bot.impo_in_vent ~= nil
end

--- Returns true if the instant kill is off cooldown.
---@param bot Player
---@return boolean
function TTTBots.Impostor_CanInstakill(bot)
    if not IsValid(bot) then return false end
    if TTTBots.Impostor_IsVenting(bot) then return false end
    return bot.impo_can_insta_kill == true
end

print("[TTT Bots 2] Impostor role integration loaded.")
return true
