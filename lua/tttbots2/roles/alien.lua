--- Alien role integration for TTT Bots 2
--- The Alien is a solo neutral role on TEAM_ALIEN with a unique win condition:
---   probe enough players using the alien probe weapon to win.
---
--- Key mechanics:
---   • Deals NO player damage (ScaleDamage 0)
---   • Has a probe weapon (weapon_ttt2_alien_probe) that must be used on players
---   • Is a public role (everyone knows who the Alien is)
---   • Auto-revives after death (20s respawn delay)
---   • Has marker vision showing unprobed targets
---
--- Bot behavior:
---   • Non-violent: does not start fights, cannot kill players
---   • Seeks out isolated players to probe them
---   • Evades attackers (survival focus since it auto-revives)
---   • Uses the AlienProbe behavior to approach and use the probe

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_ALIEN then return false end

TEAM_ALIEN = TEAM_ALIEN or "aliens"
TEAM_JESTER = TEAM_JESTER or "jesters"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,            -- Defend self if attacked (though deals 0 damage)
    _prior.Requests,
    _bh.AlienProbe,              -- [NEW] Seek and probe unprobed players
    _prior.Restore,
    _bh.Interact,
    _bh.Decrowd,                 -- Avoid crowds (easier to probe isolated targets)
    _prior.Patrol,
}

local roleDescription = "You are the Alien, a public solo neutral role. You cannot deal damage to players. "
    .. "Use your alien probe on enough players to trigger your win condition. "
    .. "If killed, you will auto-revive after 20 seconds. Seek out isolated targets to probe. "
    .. "Everyone knows who you are, so use speed and persistence to your advantage."

local alien = TTTBots.RoleData.New("alien", TEAM_ALIEN)
alien:SetDefusesC4(false)
alien:SetPlantsC4(false)
alien:SetTeam(TEAM_ALIEN)
alien:SetBTree(bTree)
alien:SetCanCoordinate(false)
alien:SetCanHaveRadar(false)
alien:SetStartsFights(false)          -- Cannot deal damage anyway
alien:SetUsesSuspicion(false)
alien:SetKOSAll(false)
alien:SetKOSedByAll(false)
alien:SetNeutralOverride(true)         -- Don't get targeted proactively
alien:SetLovesTeammates(false)
alien:SetKnowsLifeStates(false)
alien:SetAutoSwitch(false)             -- Keep probe weapon equipped
alien:SetPreferredWeapon("weapon_ttt2_alien_probe")
alien:SetAlliedTeams({ [TEAM_ALIEN] = true })
alien:SetAlliedRoles({ alien = true })
alien:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(alien)

-- ---------------------------------------------------------------------------
-- Suspicion hook: reduce suspicion on the Alien.
-- Since the Alien is a public role and can't deal damage, bots shouldn't
-- waste time suspecting or attacking it (unless specifically hostile).
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.alien.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    local role = target:GetRoleStringRaw()
    if role == "alien" then
        return mult * 0.1  -- Near-zero suspicion (alien is harmless)
    end
end)

print("[TTT Bots 2] Alien role integration loaded — non-violent probe-to-win neutral.")

return true
