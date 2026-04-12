--- Duelist role integration for TTT Bots 2
--- The Duelist is a solo neutral role on TEAM_NONE. When a round starts, all
--- Duelists are paired for a fight to the death. They gain immunity from all
--- non-Duelists (configurable). The survivor of the duel is rewarded with
--- either the dead Duelist's original role, a random role, or ROLE_UNDECIDED.
---
--- Bot behavior:
---   • Plays like a normal innocent pre-duel assignment
---   • Once activated as a Duelist, aggressively hunts the paired opponent
---   • Uses Stalk to seek out the opponent; ActiveInvestigate for area search
---   • Think hook reads the Duelist addon's pairing data and injects the
---     opponent as a priority enemy via the evidence system
---   • Ignores non-Duelists (immunity is server-driven)
---   • unknownTeam: uses suspicion normally

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DUELIST then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,           -- Fight back if attacked (duel is to the death)
    _prior.Requests,
    _bh.Stalk,                  -- Hunt your duelist opponent aggressively
    _bh.ActiveInvestigate,      -- Search areas for the opponent
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Patrol,
}

local roleDescription = "You are the Duelist. At the start of the round you are paired with another "
    .. "Duelist for a fight to the death. You are immune to non-Duelists (configurable). "
    .. "Defeat your opponent — the survivor wins their role as a reward. "
    .. "Seek your opponent aggressively and fight to win the duel. Ignore all other players."

local duelist = TTTBots.RoleData.New("duelist", TEAM_NONE)
duelist:SetDefusesC4(false)
duelist:SetPlantsC4(false)
duelist:SetTeam(TEAM_NONE)
duelist:SetBTree(bTree)
duelist:SetCanCoordinate(false)
duelist:SetCanHaveRadar(false)
duelist:SetStartsFights(true)           -- Actively hunts the opponent
duelist:SetUsesSuspicion(true)          -- Acts like innocent otherwise
duelist:SetKOSUnknown(false)
duelist:SetKOSAll(false)
duelist:SetKOSedByAll(false)
duelist:SetNeutralOverride(true)        -- Don't get cross-team targeted
duelist:SetLovesTeammates(false)
duelist:SetKnowsLifeStates(false)
duelist:SetCanSnipe(true)               -- Snipe the opponent from range
duelist:SetCanHide(false)               -- Aggressor, not hider
duelist:SetAlliedTeams({ [TEAM_NONE] = false })
duelist:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(duelist)

-- ---------------------------------------------------------------------------
-- Think hook: find the paired opponent from the Duelist addon data and inject
-- them as a priority enemy into the bot's evidence/morality system.
-- The Duelist addon typically stores the partner as a networked entity or
-- in a global Duelist data table.
-- ---------------------------------------------------------------------------
local _nextDuelistCheck = 0
hook.Add("Think", "TTTBots.Duelist.TargetOpponent", function()
    if not TTTBots.Match.IsRoundActive() then return end
    if CurTime() < _nextDuelistCheck then return end
    _nextDuelistCheck = CurTime() + 1.5

    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and bot:IsBot() and bot:Alive()) then continue end
        if bot:GetSubRole() ~= ROLE_DUELIST then continue end

        -- Try to find the paired opponent from the Duelist addon
        -- The addon typically stores the opponent as a NWEntity or in a data table
        local opponent = nil

        -- Method 1: NWEntity (common for TTT2 roles)
        if bot.GetNWEntity then
            local nwOpponent = bot:GetNWEntity("DuelistPartner", NULL)
            if not nwOpponent then
                nwOpponent = bot:GetNWEntity("duelist_partner", NULL)
            end
            if not nwOpponent then
                nwOpponent = bot:GetNWEntity("DuelistTarget", NULL)
            end
            if IsValid(nwOpponent) and nwOpponent:IsPlayer() and nwOpponent:Alive() then
                opponent = nwOpponent
            end
        end

        -- Method 2: Global duelist pairing table
        if not opponent and DUELIST_PAIRS then
            local paired = DUELIST_PAIRS[bot]
            if IsValid(paired) and paired:IsPlayer() and paired:Alive() then
                opponent = paired
            end
        end

        -- Method 3: Find the other living duelist (fallback — works for 2-player duels)
        if not opponent then
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply ~= bot and ply:Alive()
                   and ply:GetSubRole() == ROLE_DUELIST then
                    opponent = ply
                    break
                end
            end
        end

        if not opponent then continue end

        -- Inject the opponent as an enemy via evidence system
        local evidence = bot.BotEvidence and bot:BotEvidence()
        if evidence and evidence.AddEvidence then
            evidence:AddEvidence(opponent, "duelist_target", 1.0)
        end

        -- Set high aggression for the duel
        local personality = bot.BotPersonality and bot:BotPersonality()
        if personality then
            personality:SetAggression(0.95)
        end

        -- Chatter about the duel occasionally
        if math.random(1, 10) == 1 then
            local chatter = bot.BotChatter and bot:BotChatter()
            if chatter and chatter.On then
                chatter:On("DuelistHunt", { opponent = opponent }, false)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Suspicion hook: Duelists are neutral — low suspicion from bystanders
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.duelist.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    local role = target:GetRoleStringRaw()
    if role == "duelist" then
        return mult * 0.4   -- Somewhat suspicious (they are fighting someone)
    end
end)

print("[TTT Bots 2] Duelist role integration loaded — opponent targeting + evidence injection.")
return true
