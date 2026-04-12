--- Thief role integration for TTT Bots 2
--- The Thief is a solo neutral role on TEAM_NONE (custom TEAM_THIEF). They win
--- by "stealing" the win: if any single team is on the verge of winning and the
--- Thief is still alive, they steal that win condition and claim victory instead.
--- Optionally announced as a public role. No shop beyond starting equipment.
---
--- Key mechanics:
---   • Custom TEAM_THIEF — joined at win-steal moment
---   • Win steal: if one team would win and the Thief is alive, Thief wins instead
---   • isPublicRole is configurable (ttt2_thief_is_public)
---
--- Bot behavior:
---   • Extremely survivalist — stay alive at all costs to enable the win steal
---   • Avoids fights unless forced (survival > aggression)
---   • Uses suspicion normally (blends in as a neutral)
---   • CombatRetreat is high priority to avoid dying

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_THIEF then return false end

TEAM_THIEF = TEAM_THIEF or "thiefs"
TEAM_JESTER = TEAM_JESTER or "jesters"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- Two trees: early-game "blend in" and late-game "hide and survive"
local bTreeBlendIn = {
    _prior.Chatter,
    _bh.CombatRetreat,          -- Flee from combat — survival is paramount
    _prior.FightBack,           -- Only fight back when cornered
    _prior.Requests,
    _prior.Restore,             -- Seek health actively
    _bh.Interact,
    _prior.Investigate,         -- Blend in: investigate like an innocent
    _bh.Decrowd,                -- Avoid groups (dangerous)
    _prior.Patrol,
}

local bTreeSurvival = {
    _bh.CombatRetreat,          -- FIRST priority: run
    _prior.FightBack,           -- Last resort only
    _prior.Restore,             -- Stay healthy
    _bh.Decrowd,                -- Actively avoid all groups
    _bh.Follow,                 -- Stick near innocents for cover (blend in)
    _prior.Patrol,              -- Move unpredictably — don't sit still
}

local roleDescription = "You are the Thief, a solo neutral role. You win by staying alive when another "
    .. "team is on the verge of winning — you steal their victory condition and claim it as your own. "
    .. "Do NOT die. Avoid all combat. Stay hidden and let the other teams fight each other out. "
    .. "In early rounds, blend in by investigating like an innocent. In late rounds, hide and run."

local thief = TTTBots.RoleData.New("thief", TEAM_THIEF)
thief:SetDefusesC4(false)
thief:SetPlantsC4(false)
thief:SetTeam(TEAM_THIEF)
thief:SetBTree(bTreeBlendIn)
thief:SetCanCoordinate(false)
thief:SetCanHaveRadar(false)
thief:SetStartsFights(false)        -- Purely survivalist — no aggression
thief:SetUsesSuspicion(true)        -- Blends in with neutral suspicion
thief:SetKOSUnknown(false)
thief:SetKOSAll(false)
thief:SetKOSedByAll(false)
thief:SetNeutralOverride(true)      -- Don't get proactively targeted
thief:SetLovesTeammates(false)
thief:SetKnowsLifeStates(false)
thief:SetCanHide(true)              -- Actively use hiding spots
thief:SetCanSnipe(false)            -- No sniping; stay mobile
thief:SetAlliedTeams({ [TEAM_THIEF] = true })
thief:SetAlliedRoles({ thief = true })
thief:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(thief)

-- ---------------------------------------------------------------------------
-- Dynamic tree: switch to survival mode in late/overtime rounds
-- ---------------------------------------------------------------------------
local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor
TTTBots.Behaviors.GetTreeFor = function(bot)
    if IsValid(bot) and bot:GetSubRole() == ROLE_THIEF then
        local roundAwareness = bot.BotRoundAwareness and bot:BotRoundAwareness()
        if roundAwareness then
            local phase = roundAwareness:GetPhase()
            if phase == "LATE" or phase == "OVERTIME" then
                return bTreeSurvival
            end
        end

        -- Also switch to survival if few players remain (high win-steal chance)
        local alivePlayers = 0
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() and not ply:IsSpec() then
                alivePlayers = alivePlayers + 1
            end
        end
        if alivePlayers <= 4 then
            return bTreeSurvival
        end

        return bTreeBlendIn
    end
    return _origGetTreeFor(bot)
end

-- ---------------------------------------------------------------------------
-- Suspicion hook: Thief is neutral and avoidant — low-moderate suspicion
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.thief.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    local role = target:GetRoleStringRaw()
    if role == "thief" then
        return mult * 0.5   -- Blends in reasonably well
    end
end)

-- ---------------------------------------------------------------------------
-- Personality: cap aggression low; decrease further as round progresses
-- ---------------------------------------------------------------------------
local _nextThiefCheck = 0
hook.Add("Think", "TTTBots.Thief.SurvivalMode", function()
    if not TTTBots.Match.IsRoundActive() then return end
    if CurTime() < _nextThiefCheck then return end
    _nextThiefCheck = CurTime() + 2

    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and bot:IsBot() and bot:Alive()) then continue end
        if bot:GetSubRole() ~= ROLE_THIEF then continue end

        local personality = bot.BotPersonality and bot:BotPersonality()
        if not personality then continue end

        local roundAwareness = bot.BotRoundAwareness and bot:BotRoundAwareness()
        local phase = roundAwareness and roundAwareness:GetPhase() or "EARLY"

        -- Scale aggression down as round progresses
        local aggression = 0.3
        if phase == "MID" then
            aggression = 0.2
        elseif phase == "LATE" then
            aggression = 0.1
        elseif phase == "OVERTIME" then
            aggression = 0.05
        end

        personality:SetAggression(aggression)
    end
end)

print("[TTT Bots 2] Thief role integration loaded — phase-based survival behavior.")
return true
