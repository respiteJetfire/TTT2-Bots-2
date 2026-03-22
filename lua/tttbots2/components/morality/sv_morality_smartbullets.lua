--- sv_morality_smartbullets.lua
--- Smart Bullets SWEP bot integration — detection hooks, suspicion injection,
--- chatter triggers, kill tracking, buff expiry monitoring, and defensive evasion.
--- Extends the morality/suspicion system to let bots detect and react to
--- Smart Bullets usage (bright red tracer beams, lock-on sounds, kills during buff).

local lib = TTTBots.Lib
local BotMorality = TTTBots.Components.Morality
local Arb = TTTBots.Morality
local PRI = Arb.PRIORITY

-- ===========================================================================
-- Detection: EntityFireBullets hook for Smart Bullets tracer/audio detection
-- ===========================================================================

--- When a player fires with active+locked Smart Bullets, the SWEP produces
--- distinctive bright red tracer beams visible to everyone. Nearby bots should
--- notice this and raise suspicion on the shooter.
---
--- Visual detection: bots with line-of-sight to the shooter.
--- Audio detection: bots within 2000 units (gunshot range) without LOS.
hook.Add("EntityFireBullets", "TTTBots_SmartBulletsDetection", function(ent, data)
    if not (IsValid(ent) and ent:IsPlayer()) then return end
    if not ent.ttt2_smart_bullets_active then return end
    if not ent.ttt2_smart_bullets_locked then return end
    if not TTTBots.Match.RoundActive then return end

    local shooterPos = ent:GetPos()
    local shooterEyePos = ent:EyePos()
    local AUDIO_RANGE = 2000

    for _, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
        if bot == ent then continue end -- don't detect yourself
        if not (bot.components and bot.components.morality) then continue end

        -- Skip bots that don't use suspicion (traitors shouldn't "detect" their ally)
        local role = TTTBots.Roles.GetRoleFor(bot)
        if not role:GetUsesSuspicion() then continue end

        -- Also skip if the shooter is a perceived ally
        local isAlly = (TTTBots.Perception and TTTBots.Perception.IsPerceivedAlly(bot, ent))
            or TTTBots.Roles.IsAllies(bot, ent)
        if isAlly then continue end

        local morality = bot.components.morality
        local dist = bot:GetPos():Distance(shooterPos)

        -- Rate-limit per bot per shooter: max once per 3 seconds
        bot._smartBulletsDetectTimes = bot._smartBulletsDetectTimes or {}
        local lastDetect = bot._smartBulletsDetectTimes[ent] or 0
        if CurTime() - lastDetect < 3 then continue end

        local canSee = bot:VisibleVec(shooterEyePos)

        if canSee then
            -- VISUAL detection: bright red tracers are unmistakable
            bot._smartBulletsDetectTimes[ent] = CurTime()
            morality:ChangeSuspicion(ent, "SmartBulletsVisual")

            -- Feed evidence log
            local evidence = bot:BotEvidence()
            if evidence then
                evidence:AddEvidence({
                    type    = "SMART_BULLETS_VISUAL",
                    subject = ent,
                    detail  = "shooting with bright red Smart Bullets tracers",
                })
            end

            -- Record in witness memory for LLM context
            local mem = bot:BotMemory()
            if mem and mem.AddWitnessEvent then
                mem:AddWitnessEvent("smart_bullets", string.format(
                    "%s is shooting with Smart Bullets (bright red tracers)",
                    ent:Nick()
                ))
            end

            -- Fire chatter: first detection = SmartBulletsDetected
            -- Subsequent detections or KOS threshold = SmartBulletsKOS
            local chatter = bot:BotChatter()
            if chatter and chatter.On then
                local sus = morality:GetSuspicion(ent)
                if sus >= BotMorality.Thresholds.KOS then
                    chatter:On("SmartBulletsKOS", {
                        player    = ent:Nick(),
                        playerEnt = ent,
                    })
                elseif not bot._smartBulletsFirstDetect or bot._smartBulletsFirstDetect ~= ent then
                    bot._smartBulletsFirstDetect = ent
                    chatter:On("SmartBulletsDetected", {
                        player    = ent:Nick(),
                        playerEnt = ent,
                    })
                else
                    chatter:On("SmartBulletsWarning", {
                        player    = ent:Nick(),
                        playerEnt = ent,
                    })
                end
            end

        elseif dist <= AUDIO_RANGE then
            -- AUDIO detection: unusual sounds but no visual confirmation
            bot._smartBulletsDetectTimes[ent] = CurTime()
            morality:ChangeSuspicion(ent, "SmartBulletsAudio")

            -- Feed evidence log (weaker)
            local evidence = bot:BotEvidence()
            if evidence then
                evidence:AddEvidence({
                    type    = "SMART_BULLETS_AUDIO",
                    subject = ent,
                    detail  = "heard unusual Smart Bullets gunfire nearby",
                })
            end
        end
    end
end)

-- ===========================================================================
-- Kill tracking: Traitor bot killed someone during Smart Bullets buff
-- ===========================================================================

hook.Add("PlayerDeath", "TTTBots_SmartBulletsKillChatter", function(victim, weapon, attacker)
    if not TTTBots.Match.RoundActive then return end
    if not (IsValid(attacker) and attacker:IsBot()) then return end
    if not lib.IsPlayerAlive(attacker) then return end
    if not attacker.ttt2_smart_bullets_active then return end

    -- Only traitors gloat about Smart Bullets kills
    local role = TTTBots.Roles.GetRoleFor(attacker)
    if not (role and role:GetTeam() ~= TEAM_INNOCENT and role:GetTeam() ~= TEAM_NONE) then return end

    -- Rate-limit: once per 8s
    if (CurTime() - (attacker._lastSmartBulletsKillChat or 0)) < 8 then return end
    attacker._lastSmartBulletsKillChat = CurTime()

    local chatter = attacker:BotChatter()
    if chatter and chatter.On then
        chatter:On("SmartBulletsKill", {
            victim    = IsValid(victim) and victim:Nick() or "someone",
            victimEnt = victim,
        }, true) -- team-only
    end
end)

-- ===========================================================================
-- Buff expiry tracking: monitor when Smart Bullets buff wears off
-- ===========================================================================

--- Periodic timer that checks all bots for Smart Bullets buff state transitions.
--- When a traitor bot's buff expires, fire SmartBulletsExpired chatter.
--- When a bot was being targeted and the attacker's buff expires, fire SmartBulletsSurvived.
timer.Create("TTTBots_SmartBulletsExpiryMonitor", 0.5, 0, function()
    if not TTTBots.Match.RoundActive then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
        if not bot.components then continue end

        -- Track the previous buff state
        local wasActive = bot._smartBulletsPrevActive or false
        local isActive = bot.ttt2_smart_bullets_active or false

        if wasActive and not isActive then
            -- Buff just expired on this bot
            local role = TTTBots.Roles.GetRoleFor(bot)
            if role and role:GetTeam() ~= TEAM_INNOCENT and role:GetTeam() ~= TEAM_NONE then
                -- Traitor bot: fire SmartBulletsExpired chatter (team-only)
                local chatter = bot:BotChatter()
                if chatter and chatter.On then
                    chatter:On("SmartBulletsExpired", {}, true)
                end
            end
        end

        bot._smartBulletsPrevActive = isActive
    end

    -- Check if any player's Smart Bullets buff expired while they were
    -- targeting a bot — surviving bot fires SmartBulletsSurvived
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end

        local wasActive = ply._smartBulletsPrevActiveForSurvival or false
        local isActive = ply.ttt2_smart_bullets_active or false

        if wasActive and not isActive then
            -- This player's buff expired — check if any bot was their lock target
            local lockTarget = ply.ttt2_smart_bullets_lock_target
            if IsValid(lockTarget) and lockTarget:IsBot() and lib.IsPlayerAlive(lockTarget) then
                local chatter = lockTarget:BotChatter()
                if chatter and chatter.On then
                    chatter:On("SmartBulletsSurvived", {
                        player    = ply:Nick(),
                        playerEnt = ply,
                    })
                end
            end
        end

        ply._smartBulletsPrevActiveForSurvival = isActive
    end
end)

-- ===========================================================================
-- Defensive evasion: bots being targeted by Smart Bullets seek cover
-- ===========================================================================

--- Periodic check: if a bot's current attacker has Smart Bullets active,
--- the bot should prioritize cover-seeking to break line of sight (since
--- Smart Bullets redirect all shots to the head, staying in the open is death).
timer.Create("TTTBots_SmartBulletsDefensiveEvasion", 1, 0, function()
    if not TTTBots.Match.RoundActive then return end

    for _, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end
        if not bot.components then continue end

        -- Check if the bot's current attack target has Smart Bullets active
        local target = bot.attackTarget
        if not (IsValid(target) and target:IsPlayer()) then continue end
        if not target.ttt2_smart_bullets_active then continue end
        if not target.ttt2_smart_bullets_locked then continue end

        -- The target has an active Smart Bullets lock — this bot needs to
        -- get to cover ASAP. Smart Bullets redirect all shots to the head,
        -- making staying in the open extremely dangerous.

        -- If the lock target is THIS bot, urgently seek cover
        local lockTarget = target.ttt2_smart_bullets_lock_target
        if IsValid(lockTarget) and lockTarget == bot then
            -- Hothead bots still fight but even they should try to take cover
            if not IsValid(bot.coverTarget) then
                bot.coverTarget = target
            end

            -- Apply pressure event for personality system (increases urgency)
            local personality = bot:BotPersonality()
            if personality then
                personality:OnPressureEvent("Hurt")
            end
        end
    end
end)

-- ===========================================================================
-- Cleanup: clear detection tracking between rounds
-- ===========================================================================

hook.Add("TTTPrepareRound", "TTTBots_SmartBulletsCleanup", function()
    for _, bot in ipairs(TTTBots.Bots) do
        if IsValid(bot) then
            bot._smartBulletsDetectTimes = nil
            bot._smartBulletsFirstDetect = nil
            bot._smartBulletsPrevActive = nil
            bot._lastSmartBulletsKillChat = nil
        end
    end
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            ply._smartBulletsPrevActiveForSurvival = nil
        end
    end
end)

hook.Add("TTTBeginRound", "TTTBots_SmartBulletsResetFlags", function()
    for _, bot in ipairs(TTTBots.Bots) do
        if IsValid(bot) then
            bot._smartBulletsDetectTimes = nil
            bot._smartBulletsFirstDetect = nil
            bot._smartBulletsPrevActive = nil
            bot._lastSmartBulletsKillChat = nil
        end
    end
end)
