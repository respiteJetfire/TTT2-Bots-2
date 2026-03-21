--- defendself.lua
--- DefendSelf Behavior — React when this bot has been accused or KOS'd.
---
--- Priority: "SelfDefense" group (just below FightBack)
---
--- Innocent branch: offer to test, cite alibi, counter-accuse, appeal to group, flee.
--- Traitor branch:  feign innocence, offer to test but delay, counter-accuse,
---                  frame someone, assassinate accuser if isolated, last-stand fight.

---@class DefendSelf
TTTBots.Behaviors.DefendSelf = {}

local lib = TTTBots.Lib
---@class DefendSelf
local DefendSelf = TTTBots.Behaviors.DefendSelf
DefendSelf.Name         = "DefendSelf"
DefendSelf.Description  = "Defend against accusations or KOS calls"
DefendSelf.Interruptible = true

local STATUS = TTTBots.STATUS

-- ===========================================================================
-- Helpers
-- ===========================================================================

--- Returns true if this bot is on the KOS list (someone has called KOS on them).
---@param bot Bot
---@return boolean, Player|nil  isKOS'd, who called it
local function isKOSed(bot)
    local kosList = TTTBots.Match.KOSList
    if not kosList then return false, nil end
    local callers = kosList[bot]
    if not callers or table.IsEmpty(callers) then return false, nil end
    -- Return the most recent caller
    for caller, _ in pairs(callers) do
        if IsValid(caller) then return true, caller end
    end
    return false, nil
end

--- Returns true if the bot is on the accused list (set by AccusePlayer).
---@param bot Bot
---@return boolean, Player|nil  isAccused, who accused
local function isAccused(bot)
    local accused = bot.accusedBy
    if not accused or not IsValid(accused) then return false, nil end
    -- Expire accusation tracking after 45s
    if (CurTime() - (bot.accusedTime or 0)) > 45 then
        bot.accusedBy  = nil
        bot.accusedTime = nil
        return false, nil
    end
    return true, accused
end

--- True if the bot is an innocent-side player.
---@param bot Bot
---@return boolean
local function isInnocent(bot)
    return bot:GetTeam() == TEAM_INNOCENT
end

--- Choose a counter-suspect — someone else to redirect blame to.
--- For traitors, this is intentional framing; for innocents it's based on evidence.
---@param bot Bot
---@param accuser Player
---@return Player|nil
local function pickCounterSuspect(bot, accuser)
    local evidence = bot:BotEvidence()
    if isInnocent(bot) then
        -- Innocent: counter-accuse the accuser if there's actual evidence
        if evidence then
            local w = evidence:EvidenceWeight(accuser)
            if w >= 3 then return accuser end
        end
    else
        -- Traitor: frame someone else entirely
        local alivePlayers = TTTBots.Match.AlivePlayers or {}
        local candidates = {}
        for _, p in ipairs(alivePlayers) do
            if p == bot or p == accuser then continue end
            if not lib.IsPlayerAlive(p) then continue end
            if TTTBots.Roles.IsAllies(bot, p) then continue end -- don't frame allies
            table.insert(candidates, p)
        end
        if #candidates > 0 then
            return candidates[math.random(1, #candidates)]
        end
    end
    return nil
end

-- ===========================================================================
-- Behavior implementation
-- ===========================================================================

function DefendSelf.Validate(bot)
    if not lib.IsPlayerAlive(bot) then return false end

    -- Don't re-enter immediately after the behavior just ended (prevents tight re-trigger loops).
    if (bot.defendSelfCooldown or 0) > CurTime() then return false end

    -- Public/police roles (detective etc.) are known to all — accusations against them
    -- are always baseless, so DefendSelf is unnecessary and just creates loops.
    local role = TTTBots.Roles.GetRoleFor(bot)
    if role and role:GetAppearsPolice() then return false end

    local isKosed, kosCaller = isKOSed(bot)
    local isAcced, accCaller = isAccused(bot)

    if not (isKosed or isAcced) then return false end

    -- If we're already in active combat, FightBack takes priority; skip
    if bot.attackTarget and IsValid(bot.attackTarget) then return false end

    -- Only seed the state when there is no active run yet.
    -- Do NOT overwrite state.phase/state.accuser here — Validate is called every
    -- tick while the behavior is running, and overwriting would reset the phase
    -- that OnStart/OnRunning have already progressed to.
    local state = TTTBots.Behaviors.GetState(bot, "DefendSelf")
    if not state.running then
        state.accuser   = kosCaller or accCaller
        state.isKOS     = isKosed
        state.phase     = "respond"
        state.startTime = CurTime()
    end

    return true
end

function DefendSelf.OnStart(bot)
    local state   = TTTBots.Behaviors.GetState(bot, "DefendSelf")
    local accuser = state.accuser
    local chatter = bot:BotChatter()

    -- Mark the behavior as actively running so Validate stops re-seeding state.
    state.running   = true
    state.startTime = CurTime()

    if not (chatter and chatter.On) then return STATUS.RUNNING end

    local personality = bot:BotPersonality()
    local archetype   = personality and personality:GetClosestArchetype() or "Default"
    local A = TTTBots.Archetypes

    -- Look toward accuser if nearby
    if IsValid(accuser) then
        local loco = bot:BotLocomotor()
        if loco then loco:LookAt(accuser:EyePos()) end
    end

    if isInnocent(bot) then
        -- Innocent defense tree
        local evidence  = bot:BotEvidence()
        local companion = evidence and evidence:GetBestAlibieCompanion()

        if archetype == A.Hothead then
            -- Hothead: rage at accuser immediately
            chatter:On("DefendRage", { player = accuser and accuser:Nick() or "someone" }, false, 0)
        elseif companion and IsValid(companion) then
            -- Has a companion alibi
            chatter:On("DefendAlibi", { player = companion:Nick() }, false, 0)
            state.phase = "alibi"
        else
            -- Default: offer to test
            chatter:On("DefendOfferTest", {}, false, 0)
            state.phase = "offer_test"
        end
    else
        -- Traitor defense tree
        if archetype == A.Dumb then
            -- Dumb traitor: panic, might say something incriminating
            chatter:On("DefendTraitorPanic", { player = accuser and accuser:Nick() or "someone" }, false, 0)
        elseif archetype == A.Hothead then
            -- Hothead traitor: attack prematurely if accuser is nearby
            if IsValid(accuser) and bot:GetPos():Distance(accuser:GetPos()) < 300 then
                local Arb = TTTBots.Morality
                Arb.RequestAttackTarget(bot, accuser, "PREMATURE_ACCUSER_ATTACK", TTTBots.Morality.PRIORITY.SUSPICION_THRESHOLD)
                return STATUS.SUCCESS
            end
        end
        -- Default traitor response: feign innocence
        chatter:On("DefendFeign", { player = accuser and accuser:Nick() or "someone" }, false, 0)
        state.phase = "feign"
    end

    state.startTime = CurTime()
    return STATUS.RUNNING
end

function DefendSelf.OnRunning(bot)
    local state   = TTTBots.Behaviors.GetState(bot, "DefendSelf")
    local accuser = state.accuser
    local chatter = bot:BotChatter()
    local Arb     = TTTBots.Morality

    -- If we're no longer KOS'd or accused, we're done
    local stillKOS, _   = isKOSed(bot)
    local stillAcc, _   = isAccused(bot)
    if not (stillKOS or stillAcc) then return STATUS.SUCCESS end

    -- Expire after 30s
    if (CurTime() - (state.startTime or 0)) > 30 then return STATUS.SUCCESS end

    local personality = bot:BotPersonality()
    local archetype   = personality and personality:GetClosestArchetype() or "Default"
    local A = TTTBots.Archetypes

    -- -------------------------------------------------------------------------
    -- INNOCENT branch
    -- -------------------------------------------------------------------------
    if isInnocent(bot) then
        local loco = bot:BotLocomotor()

        -- ACTIVE DEFENSE: Always move toward the nearest group of allies for
        -- protection, rather than standing still doing nothing.
        if loco then
            local nearestAlly = nil
            local nearestDist = math.huge
            local alivePlayers = TTTBots.Match.AlivePlayers or {}
            for _, p in ipairs(alivePlayers) do
                if not IsValid(p) or p == bot or not lib.IsPlayerAlive(p) then continue end
                if p == accuser then continue end
                -- Move toward known innocents / police for safety
                local pRole = TTTBots.Roles.GetRoleFor(p)
                local isTrusted = pRole and pRole:GetAppearsPolice()
                local morality = bot:BotMorality()
                local pSus = morality and morality:GetSuspicion(p) or 0
                if isTrusted or pSus <= -2 then
                    local d = bot:GetPos():Distance(p:GetPos())
                    if d < nearestDist then
                        nearestDist = d
                        nearestAlly = p
                    end
                end
            end
            if nearestAlly and nearestDist > 200 then
                loco:SetGoal(nearestAlly:GetPos())
            elseif IsValid(accuser) then
                -- No trusted ally nearby — actively flee from accuser
                local awayVec = (bot:GetPos() - accuser:GetPos()):GetNormalized() * 600
                loco:SetGoal(bot:GetPos() + awayVec)
            end
        end

        if state.phase == "offer_test" and not state.escalated then
            -- If no one believes us after a few seconds, counter-accuse
            if (CurTime() - state.startTime) > 5 then
                local counter = pickCounterSuspect(bot, accuser)
                if counter and chatter and chatter.On then
                    chatter:On("DefendCounterAccuse", {
                        player    = accuser and accuser:Nick() or "them",
                        counter   = counter:Nick(),
                        counterEnt = counter,
                    }, false, 0)
                end
                state.escalated = true
            end
        elseif state.phase == "alibi" and not state.escalated then
            -- Appeal to group
            if (CurTime() - state.startTime) > 5 then
                if chatter and chatter.On then
                    chatter:On("DefendAppealGroup", {}, false, 0)
                end
                state.escalated = true
            end
        end

        -- If KOS'd and enough time has passed, just finish and let other
        -- behaviors (FightBack/AttackTarget) take over naturally.
        if state.isKOS and (CurTime() - state.startTime) > 10 then
            return STATUS.SUCCESS
        end
    -- -------------------------------------------------------------------------
    -- TRAITOR branch
    -- -------------------------------------------------------------------------
    else
        local loco = bot:BotLocomotor()

        if state.phase == "feign" and not state.escalated then
            -- After a few seconds, try to counter-accuse or frame someone
            if (CurTime() - state.startTime) > 4 then
                local counter = pickCounterSuspect(bot, accuser)
                if counter then
                    -- Traitors: fabricate evidence about the counter-suspect
                    local evidence = bot:BotEvidence()
                    if evidence then
                        -- Plant fake ALIBI_BROKEN evidence on the framed player
                        evidence:AddEvidence({
                            type    = "ALIBI_BROKEN",
                            subject = counter,
                            detail  = "suspicious behavior (fabricated)",
                            weight  = 4,
                        })
                    end
                    if chatter and chatter.On then
                        chatter:On("DefendFrameOther", {
                            player    = counter:Nick(),
                            playerEnt = counter,
                        }, false, 0)
                    end
                end
                state.escalated = true
            end
        end

        -- Traitor active defense: if accuser is nearby and somewhat isolated,
        -- eliminate them. Lower threshold than before so bots actually fight.
        if state.isKOS and IsValid(accuser) then
            local isolation = lib.RateIsolation(bot, accuser)
            local dist      = bot:GetPos():Distance(accuser:GetPos())
            -- Lower isolation requirement (0.4 instead of 0.7) and larger
            -- distance range (800 instead of 400) so traitors actually respond.
            if isolation > 0.4 and dist < 800 then
                Arb.RequestAttackTarget(bot, accuser, "SILENCE_WITNESS", Arb.PRIORITY.SELF_DEFENSE)
                if chatter and chatter.On then
                    chatter:On("DefendAssassinate", { player = accuser:Nick() }, bot:GetTeam() ~= TEAM_INNOCENT, 0)
                end
                return STATUS.SUCCESS
            end
        end

        -- ACTIVE FLEEING: when KOS'd and can't fight, actively flee from the
        -- accuser rather than standing still waiting to die.
        if state.isKOS and IsValid(accuser) and loco then
            local awayVec = (bot:GetPos() - accuser:GetPos()):GetNormalized() * 800
            loco:SetGoal(bot:GetPos() + awayVec)
        end

        -- Cornered last stand: KOS'd by multiple people — accept fate and fight.
        local kosList = TTTBots.Match.KOSList
        local kosCallerCount = 0
        if kosList and kosList[bot] then
            for caller, _ in pairs(kosList[bot]) do
                if IsValid(caller) then kosCallerCount = kosCallerCount + 1 end
            end
        end
        if kosCallerCount >= 2 then
            local closest = lib.GetClosest(TTTBots.Roles.GetNonAllies(bot), bot:GetPos())
            if closest then
                Arb.RequestAttackTarget(bot, closest, "LAST_STAND", Arb.PRIORITY.SELF_DEFENSE)
            end
            return STATUS.SUCCESS
        end
    end

    return STATUS.RUNNING
end

function DefendSelf.OnSuccess(bot)
end

function DefendSelf.OnFailure(bot)
end

function DefendSelf.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "DefendSelf")
    -- Clear accusation state and impose a short cooldown so Validate can't re-trigger
    -- on the very next tick (accusedBy/accusedTime persist for 45s otherwise).
    bot.accusedBy        = nil
    bot.accusedTime      = nil
    bot.defendSelfCooldown = CurTime() + 15
end

-- ===========================================================================
-- Hook: mark bots as accused when AccusePlayer targets them
-- ===========================================================================

--- Called by AccusePlayer behavior to flag the target as accused.
--- Also hooked from TTTBodyFound and KOS call announcements.
hook.Add("TTTBots.AccusePlayer", "DefendSelf.MarkAccused", function(accuser, target)
    if not (IsValid(target) and target:IsBot()) then return end
    target.accusedBy   = accuser
    target.accusedTime = CurTime()
end)

-- When a KOS is called on a bot, also mark them as accused so DefendSelf can fire
hook.Add("TTTBots.KOSCalled", "DefendSelf.KOSMarkAccused", function(caller, target)
    if not (IsValid(target) and target:IsBot()) then return end
    target.accusedBy   = caller
    target.accusedTime = CurTime()
end)
