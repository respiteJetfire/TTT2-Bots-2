if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_SPY then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- ---------------------------------------------------------------------------
-- Spy Role Registration — Phase 1 (P1-5)
-- ---------------------------------------------------------------------------

local spy = TTTBots.RoleData.New("spy")
spy:SetDefusesC4(false)
spy:SetTeam(TEAM_INNOCENT)
spy:SetCanHide(true)
spy:SetCanSnipe(true)
spy:SetUsesSuspicion(true)
spy:SetIsFollower(true)
spy:SetCanCoordinateInnocent(true)

-- Role description for LLM prompt context (BUG-6 fix)
spy:SetRoleDescription(
    "You are a Spy — an innocent-team role that appears as a traitor to all traitor-side players. "
    .. "Traitors believe you are one of them, and you know who the traitors are. "
    .. "Your goals: maintain your cover among traitors, gather intelligence on their plans, "
    .. "subtly share intel with innocent players, and survive. "
    .. "You jam traitor team chat and voice while alive. "
    .. "Traitors may catch on if you never attack innocents or follow their plans."
)

-- Custom behavior tree: enhanced innocent tree with spy-specific insertions
-- Spy behaviors (SpyBlend, SpyReport, SpyFakeBuy, SpyEavesdrop) are injected
-- between the standard innocent priorities.
local spyBTree = {
    _prior.Requests,
    _prior.Chatter,
    _prior.FightBack,
    _prior.SelfDefense,
    _bh.SpyDeadRinger,   -- Emergency: fake death when in mortal danger
    _prior.Grenades,
    _prior.Accuse,
    _bh.FollowInnocentPlan,
    -- Spy-specific behaviors inserted here (between plan following and support)
    _bh.SpyBlend,        -- Blend in with traitors to maintain cover
    _bh.SpyReport,       -- Report traitor intel to innocents
    _bh.SpyFakeBuy,      -- Fake equipment purchase
    _bh.SpyEavesdrop,    -- Eavesdrop on traitor activity
    _prior.Support,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}
spy:SetBTree(spyBTree)

TTTBots.Roles.RegisterRole(spy)

-- ---------------------------------------------------------------------------
-- Spy Knowledge Hook — Give spy knowledge of traitor identities (P1-4)
-- ---------------------------------------------------------------------------

hook.Add("TTTBeginRound", "TTTBots.Spy.SeedTraitorKnowledge", function()
    -- Delay slightly so roles are assigned
    timer.Simple(2, function()
        if not TTTBots.Match.IsRoundActive() then return end
        if not TTTBots.Perception then return end

        for _, bot in pairs(TTTBots.Bots) do
            if not (IsValid(bot) and bot:IsBot()) then continue end
            if not TTTBots.Perception.IsSpy(bot) then continue end

            -- Populate spy's evidence with known traitor identities
            local evidence = bot:BotEvidence()
            if not evidence then continue end

            local knownTraitors = TTTBots.Perception.GetKnownTraitors(bot)
            for _, traitor in pairs(knownTraitors) do
                if not IsValid(traitor) then continue end
                evidence:AddEvidence({
                    type    = "SPY_INTEL",
                    subject = traitor,
                    detail  = "known traitor (spy intel)",
                    weight  = 6, -- Strong but not auto-KOS — spy should gather more evidence
                })
            end
        end
    end)
end)

-- ---------------------------------------------------------------------------
-- Spy Traitor Detection Timer (P4-2)
-- Traitor bots periodically evaluate whether the spy is acting suspicious.
-- ---------------------------------------------------------------------------

timer.Create("TTTBots.Spy.TraitorDetection", 15, 0, function()
    if not TTTBots.Match.IsRoundActive() then return end
    if not TTTBots.Perception then return end

    for _, bot in pairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot:IsBot()) then continue end
        if not TTTBots.Perception.IsTraitorTeam(bot) then continue end

        -- Check each alive spy
        local spies = TTTBots.Perception.GetAliveSpies()
        for _, spy in pairs(spies) do
            if not IsValid(spy) then continue end
            if TTTBots.Perception.IsCoverBlown(spy) then continue end

            -- Suspicion triggers:
            -- 1. Spy hasn't attacked any innocents (check redHandedTime)
            local spyHasKilled = spy.redHandedTime and spy.redHandedTime > 0
            if not spyHasKilled then
                TTTBots.Perception.AddSpySuspicion(spy, 0.5)
            end

            -- 2. Spy is spending lots of time near innocents (via companion tracking)
            local evidence = bot:BotEvidence()
            if evidence then
                local companionDuration = evidence:GetCompanionDuration(spy)
                if companionDuration > 30 then
                    TTTBots.Perception.AddSpySuspicion(spy, 0.3)
                end
            end

            -- 3. Random chance factor (personality-based detection speed)
            local personality = bot:BotPersonality()
            local detectionBonus = 0
            if personality then
                local archetype = personality:GetClosestArchetype()
                if archetype == TTTBots.Archetypes.Tryhard or archetype == TTTBots.Archetypes.Sus then
                    detectionBonus = 0.5
                end
            end
            TTTBots.Perception.AddSpySuspicion(spy, math.random() * 0.3 + detectionBonus)

            -- Fire suspicion chatter if getting close to threshold
            local state = TTTBots.Perception.GetCoverState(spy)
            local threshold = TTTBots.Lib.GetConVarFloat("tttbots_spy_traitor_detection_threshold") or 10
            if state.suspicion >= threshold * 0.6 and not state.blown then
                local chatter = bot:BotChatter()
                if chatter and chatter.On and math.random(1, 4) == 1 then
                    chatter:On("TraitorSuspectsSpy", { player = spy:Nick(), playerEnt = spy }, false)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Spy Cover Blown via KOS (P4-5)
-- If a traitor calls KOS on the spy, cover is immediately blown.
-- ---------------------------------------------------------------------------

hook.Add("TTTBots.KOSCalled", "TTTBots.Spy.KOSBlowsCover", function(caller, target)
    if not TTTBots.Perception then return end
    if not (IsValid(target) and TTTBots.Perception.IsSpy(target)) then return end
    if not (IsValid(caller) and TTTBots.Perception.IsTraitorTeam(caller)) then return end
    TTTBots.Perception.BlowCover(target)
end)

-- ---------------------------------------------------------------------------
-- Post-Round Spy Reveal Chatter (P3-5)
-- ---------------------------------------------------------------------------

hook.Add("TTTEndRound", "TTTBots.Spy.PostRoundReveal", function(result)
    if not TTTBots.Perception then return end
    if not TTTBots.Lib.GetConVarBool("emotional_chatter") then return end

    timer.Simple(math.random(4, 8), function()
        -- Check if any spy survived
        for _, bot in pairs(TTTBots.Bots) do
            if not (IsValid(bot) and bot:IsBot()) then continue end

            if TTTBots.Perception.IsSpy(bot) and TTTBots.Lib.IsPlayerAlive(bot) then
                local chatter = bot:BotChatter()
                if chatter and chatter.On then
                    chatter:On("SpySurvival", {}, false, 0)
                end
                break
            end
        end

        -- Traitors react to spy reveal
        timer.Simple(3, function()
            for _, bot in pairs(TTTBots.Bots) do
                if not (IsValid(bot) and bot:IsBot()) then continue end
                if not TTTBots.Perception.IsTraitorTeam(bot) then continue end

                local spies = TTTBots.Perception.GetAliveSpies()
                if #spies > 0 and math.random(1, 2) == 1 then
                    local spy = spies[math.random(1, #spies)]
                    local chatter = bot:BotChatter()
                    if chatter and chatter.On then
                        chatter:On("SpyPostReveal", { player = spy:Nick(), playerEnt = spy }, false, 0)
                    end
                    break
                end
            end
        end)
    end)
end)

-- ---------------------------------------------------------------------------
-- ConVar for spy detection rate
-- ---------------------------------------------------------------------------

if not ConVarExists("tttbots_spy_traitor_detection_threshold") then
    CreateConVar("tttbots_spy_traitor_detection_threshold", "10",
        FCVAR_ARCHIVE + FCVAR_NOTIFY,
        "How much suspicion traitor bots need to accumulate before they realize a spy is fake (default 10).",
        1, 50)
end

-- ---------------------------------------------------------------------------
-- Team-Chat Jamming Awareness (P3-4)
-- When traitor bots try team-chat and it's jammed by the spy, they react.
-- The spy addon's TTT2AvoidTeamChat hook blocks the message and sends a
-- client-side warning. We add a server-side hook so traitor bots can react.
-- ---------------------------------------------------------------------------

hook.Add("TTT2AvoidTeamChat", "TTTBots.Spy.TraitorReactJam", function(sender, tm, msg)
    -- Only care about traitor team chat being jammed
    if tm ~= TEAM_TRAITOR then return end
    if not (IsValid(sender) and sender:IsBot()) then return end
    if not TTTBots.Perception then return end

    -- Check there's actually a spy causing the jam
    if not TTTBots.Perception.IsAnySpyAlive() then return end

    local chatter = sender:BotChatter()
    if chatter and chatter.On then
        chatter:On("SpyReactJam", {}, false, math.random(1, 3))
    end
end)

-- ---------------------------------------------------------------------------
-- Personality Trait Interactions (P4-6)
-- Modulates spy behavior based on personality archetype.
-- Called by behaviors to get trait-based multipliers.
-- ---------------------------------------------------------------------------

TTTBots.Spy = TTTBots.Spy or {}

--- Get personality-based spy behavior modifiers.
--- @param bot Player
--- @return table { coverDuration: number, reportEagerness: number, blendDistance: number, eavesdropChance: number }
function TTTBots.Spy.GetPersonalityModifiers(bot)
    local defaults = {
        coverDuration = 1.0,     -- multiplier for how long spy maintains cover before acting
        reportEagerness = 1.0,   -- multiplier for how quickly spy reports intel
        blendDistance = 1.0,     -- multiplier for blend-in proximity distance
        eavesdropChance = 1.0,   -- multiplier for eavesdrop frequency
        fakeBuyChance = 1.0,     -- multiplier for fake buy probability
    }

    local personality = bot.BotPersonality and bot:BotPersonality()
    if not personality then return defaults end

    local archetype = personality.GetClosestArchetype and personality:GetClosestArchetype() or "Default"

    -- Aggressive/Hothead: shorter cover, quicker to accuse, closer blend distance
    if archetype == "Hothead" then
        return {
            coverDuration = 0.6,
            reportEagerness = 1.5,
            blendDistance = 0.8,
            eavesdropChance = 0.7,
            fakeBuyChance = 0.8,
        }
    end

    -- Tryhard: optimal play, balanced but precise
    if archetype == "Tryhard" then
        return {
            coverDuration = 1.2,
            reportEagerness = 1.3,
            blendDistance = 1.1,
            eavesdropChance = 1.4,
            fakeBuyChance = 1.2,
        }
    end

    -- Stoic: patient, long cover, careful eavesdropping
    if archetype == "Stoic" then
        return {
            coverDuration = 1.5,
            reportEagerness = 0.8,
            blendDistance = 1.2,
            eavesdropChance = 1.3,
            fakeBuyChance = 1.0,
        }
    end

    -- Nice: eager to help, quick to report, but not aggressive
    if archetype == "Nice" then
        return {
            coverDuration = 1.0,
            reportEagerness = 1.4,
            blendDistance = 0.9,
            eavesdropChance = 0.9,
            fakeBuyChance = 0.7,
        }
    end

    -- Casual: relaxed, slower to act
    if archetype == "Casual" then
        return {
            coverDuration = 1.3,
            reportEagerness = 0.7,
            blendDistance = 1.0,
            eavesdropChance = 0.8,
            fakeBuyChance = 1.1,
        }
    end

    -- Bad: self-serving, late reports, risky behavior
    if archetype == "Bad" then
        return {
            coverDuration = 0.8,
            reportEagerness = 0.5,
            blendDistance = 0.7,
            eavesdropChance = 1.0,
            fakeBuyChance = 1.3,
        }
    end

    -- Dumb: unpredictable, short attention span
    if archetype == "Dumb" then
        return {
            coverDuration = 0.7,
            reportEagerness = 0.6,
            blendDistance = 0.6,
            eavesdropChance = 0.5,
            fakeBuyChance = 0.9,
        }
    end

    -- Sus: suspicious, long observation, reluctant to reveal intel
    if archetype == "Sus" then
        return {
            coverDuration = 1.4,
            reportEagerness = 0.6,
            blendDistance = 1.3,
            eavesdropChance = 1.5,
            fakeBuyChance = 1.1,
        }
    end

    -- Teamer: team-oriented, fast intel sharing
    if archetype == "Teamer" then
        return {
            coverDuration = 1.0,
            reportEagerness = 1.6,
            blendDistance = 0.9,
            eavesdropChance = 1.0,
            fakeBuyChance = 0.8,
        }
    end

    return defaults
end

return true
