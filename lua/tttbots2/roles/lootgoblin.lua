--- Loot Goblin role integration for TTT Bots 2
--- The Loot Goblin is a neutral role on TEAM_LOOTGOBLIN.
--- Key mechanics:
---   • TEAM_LOOTGOBLIN — custom team; visibleForTeam = {TEAM_TRAITOR} (traitors see them)
---   • preventWin = true: cannot win normally; special win condition
---   • Small size (0.5× model scale), fast run speed (600), fast walk (300)
---   • scoreKillsMultiplier = 0: no points for kills
---   • Low HP (configured via ttt2_lootgoblin_health convar)
---   • networkRoles = {JESTER}: traitors/jesters know the goblin
---   • defaultEquipment = INNO_EQUIPMENT
---   • Announces goblin presence to other players at round start
---
--- Bot behavior:
---   • Speed-based survival: CombatRetreat prioritized above all combat
---   • Actively flees when ANY player is too close (flee radius based on speed)
---   • Loot and hoard items opportunistically while running between areas
---   • NeutralOverride: not proactively targeted
---   • Hides when low HP; uses speed to outrun pursuers

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_LOOTGOBLIN then return false end

TEAM_LOOTGOBLIN = TEAM_LOOTGOBLIN or "lootgoblin"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _bh.CombatRetreat,      -- FIRST: always flee from danger (speed advantage!)
    _prior.FightBack,        -- Only if cornered with no escape
    _prior.Restore,          -- Grab health/items opportunistically
    _bh.Interact,            -- Collect/interact with items
    _bh.Decrowd,             -- Avoid groups (dangerous with low HP)
    _prior.Minge,
    _prior.Investigate,
    _prior.Patrol,
}

local roleDescription = "You are the Loot Goblin — a tiny, lightning-fast neutral creature. "
    .. "You have very low HP but incredible speed. Traitors can see your role. "
    .. "RUN. Collect items and survive as long as possible. Avoid ALL combat — "
    .. "use your speed to escape. You cannot win by killing; your only goal is to outlast everyone."

local lootgoblin = TTTBots.RoleData.New("lootgoblin", TEAM_LOOTGOBLIN)
lootgoblin:SetDefusesC4(false)
lootgoblin:SetPlantsC4(false)
lootgoblin:SetTeam(TEAM_LOOTGOBLIN)
lootgoblin:SetBTree(bTree)
lootgoblin:SetCanCoordinate(false)
lootgoblin:SetCanHaveRadar(false)
lootgoblin:SetStartsFights(false)    -- Low HP; speed > combat
lootgoblin:SetUsesSuspicion(false)
lootgoblin:SetCanSnipe(false)
lootgoblin:SetCanHide(true)          -- Small size; hide when threatened
lootgoblin:SetKnowsLifeStates(false)
lootgoblin:SetKOSAll(false)
lootgoblin:SetKOSedByAll(false)
lootgoblin:SetNeutralOverride(true)
lootgoblin:SetLovesTeammates(false)
lootgoblin:SetAlliedTeams({ [TEAM_LOOTGOBLIN] = true })
lootgoblin:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(lootgoblin)

-- ---------------------------------------------------------------------------
-- Active flee behavior: Loot Goblin runs away when ANY player gets close.
-- Uses the bot's enormous speed advantage to outrun pursuers.
-- ---------------------------------------------------------------------------
local FLEE_RADIUS = 800    -- Start fleeing when anyone is within this radius
local DANGER_RADIUS = 400  -- Urgent flee when anyone is this close

local _nextGoblinCheck = 0
hook.Add("Think", "TTTBots.LootGoblin.ActiveFlee", function()
    if not TTTBots.Match.IsRoundActive() then return end
    if CurTime() < _nextGoblinCheck then return end
    _nextGoblinCheck = CurTime() + 0.5

    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and bot:IsBot() and bot:Alive()) then continue end
        if bot:GetSubRole() ~= ROLE_LOOTGOBLIN then continue end

        local botPos = bot:GetPos()
        local closestDist = math.huge
        local closestPly = nil

        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) or ply == bot or not ply:Alive() then continue end
            local dist = botPos:Distance(ply:GetPos())
            if dist < closestDist then
                closestDist = dist
                closestPly = ply
            end
        end

        if closestPly and closestDist < FLEE_RADIUS then
            local loco = bot:BotLocomotor()
            if not loco then continue end

            -- Calculate flee direction: directly away from the closest player
            local fleeDir = (botPos - closestPly:GetPos()):GetNormalized()
            local fleeTarget = botPos + fleeDir * 1000

            -- Try to find a valid nav area in the flee direction
            local fleeNav = navmesh.GetNearestNavArea(fleeTarget, true, 500)
            if fleeNav then
                loco:SetGoal(fleeNav:GetCenter())
            else
                loco:SetGoal(fleeTarget)
            end

            -- Urgent flee chatter when very close
            if closestDist < DANGER_RADIUS and math.random(1, 6) == 1 then
                local chatter = bot:BotChatter()
                if chatter and chatter.On then
                    chatter:On("LootGoblinFlee", {}, false)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Personality: keep aggression permanently at minimum.
-- ---------------------------------------------------------------------------
hook.Add("TTTBeginRound", "TTTBots.LootGoblin.SetPersonality", function()
    timer.Simple(1, function()
        for _, bot in ipairs(TTTBots.Bots or {}) do
            if not (IsValid(bot) and bot:IsBot()) then continue end
            if bot:GetSubRole() ~= ROLE_LOOTGOBLIN then continue end
            local personality = bot.BotPersonality and bot:BotPersonality()
            if personality then
                personality:SetAggression(0.05) -- Absolute minimum aggression
            end
        end
    end)
end)

print("[TTT Bots 2] Loot Goblin role integration loaded — speed-based flee survivor.")
return true
