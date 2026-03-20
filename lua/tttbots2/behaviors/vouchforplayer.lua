--- vouchforplayer.lua
--- VouchForPlayer Behavior — When a travel companion is under suspicion,
--- this bot speaks up to confirm their innocence and share evidence.
---
--- Priority: "Chatter" group (alongside ChatterHelp)

---@class VouchForPlayer
TTTBots.Behaviors.VouchForPlayer = {}

local lib = TTTBots.Lib
---@class VouchForPlayer
local VouchForPlayer = TTTBots.Behaviors.VouchForPlayer
VouchForPlayer.Name         = "VouchForPlayer"
VouchForPlayer.Description  = "Vouch for a travel companion who is under suspicion"
VouchForPlayer.Interruptible = true

local STATUS = TTTBots.STATUS

function VouchForPlayer.Validate(bot)
    if not lib.IsPlayerAlive(bot) then return false end
    if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then return false end

    local evidence = bot:BotEvidence()
    if not evidence then return false end

    -- Find a travel companion who has been with us long enough and is being accused
    local companions = evidence.trustNetwork.travelCompanions
    for ply, entry in pairs(companions) do
        if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end
        -- Never vouch for someone who is our current attack target (e.g. they are shooting us)
        if bot.attackTarget == ply then continue end
        if not entry.continuous then continue end
        local duration = CurTime() - entry.since
        local minTime = lib.GetConVarInt("evidence_companion_min_time") or evidence.CompanionMinTime
        if duration < minTime then continue end

        -- Is this companion being suspected?
        local morality = bot:BotMorality()
        if not morality then continue end
        local sus = morality:GetSuspicion(ply)
        if sus < 3 then continue end -- only vouch if they're actually suspected

        -- Cooldown: don't vouch for the same person within 45s
        local lastVouch = bot.lastVouchTime and bot.lastVouchTime[ply] or 0
        if (CurTime() - lastVouch) < 45 then continue end

        local state = TTTBots.Behaviors.GetState(bot, "VouchForPlayer")
        state.target = ply
        return true
    end

    return false
end

function VouchForPlayer.OnStart(bot)
    local state  = TTTBots.Behaviors.GetState(bot, "VouchForPlayer")
    local target = state.target
    if not (IsValid(target) and lib.IsPlayerAlive(target)) then return STATUS.FAILURE end

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("VouchChat", { player = target:Nick(), playerEnt = target }, false, 0)
    end

    -- Record the vouch in evidence and confirm innocent
    local evidence = bot:BotEvidence()
    if evidence then
        evidence:ConfirmInnocent(target, "travel companion (" .. bot:Nick() .. ")")
        evidence:Vouch(target, bot)
    end

    -- Share evidence with the travel companion (cooperative investigation)
    local theirEvidence = target:BotEvidence()
    if theirEvidence and evidence then
        evidence:ShareEvidence(target)
    end

    -- Record vouch cooldown
    bot.lastVouchTime = bot.lastVouchTime or {}
    bot.lastVouchTime[target] = CurTime()

    -- Also reduce their suspicion in morality
    local morality = bot:BotMorality()
    if morality then
        local cur = morality:GetSuspicion(target)
        if cur > 0 then
            morality.suspicions[target] = math.max(cur - 4, -2)
        end
    end

    return STATUS.SUCCESS
end

function VouchForPlayer.OnRunning(bot)
    return STATUS.SUCCESS
end

function VouchForPlayer.OnSuccess(bot)
end

function VouchForPlayer.OnFailure(bot)
end

function VouchForPlayer.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "VouchForPlayer")
end
