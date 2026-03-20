--- behaviors/userevealgrenade.lua
--- Uses the Reveal Grenade (weapon_ttt_reveal_nade) by throwing it onto a nearby corpse.

TTTBots.Behaviors.UseRevealGrenade = {}

local lib = TTTBots.Lib
local STATUS = TTTBots.STATUS

local UseRevealGrenade = TTTBots.Behaviors.UseRevealGrenade
UseRevealGrenade.Name = "UseRevealGrenade"
UseRevealGrenade.Description = "Throw a reveal grenade onto a corpse to expose non-allies."
UseRevealGrenade.Interruptible = false

local APPROACH_DIST = 420
local THROW_DIST = 220
local FIRE_TIMEOUT = 0.6

local function GetState(bot)
    return TTTBots.Behaviors.GetState(bot, UseRevealGrenade.Name)
end

function UseRevealGrenade.HasRevealGrenade(bot)
    return bot:HasWeapon("weapon_ttt_reveal_nade")
end

function UseRevealGrenade.GetRevealGrenade(bot)
    local wep = bot:GetWeapon("weapon_ttt_reveal_nade")
    return IsValid(wep) and wep or nil
end

local function CountRevealTargets(bot)
    local count = 0
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not lib.IsPlayerAlive(ply) then continue end
        if ply == bot then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then continue end
        count = count + 1
    end
    return count
end

function UseRevealGrenade.FindTargetCorpse(bot)
    local corpses = TTTBots.Match and TTTBots.Match.Corpses or {}
    local bestCorpse = nil
    local bestScore = -math.huge

    for _, corpse in ipairs(corpses) do
        if not IsValid(corpse) then continue end
        if not lib.IsValidBody(corpse) then continue end

        local dist = bot:GetPos():Distance(corpse:GetPos())
        if dist > 1600 then continue end

        local score = 12 - (dist / 160)
        if bot:Visible(corpse) then
            score = score + 3
        end

        if IsValid(bot.attackTarget) then
            local targetDist = bot.attackTarget:GetPos():Distance(corpse:GetPos())
            if targetDist <= 500 then
                score = score + 5
            end
        end

        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) or not lib.IsPlayerAlive(ply) then continue end
            if ply == bot then continue end
            if TTTBots.Roles.IsAllies(bot, ply) then continue end
            if ply:GetPos():Distance(corpse:GetPos()) <= 450 then
                score = score + 2
            end
        end

        if score > bestScore then
            bestScore = score
            bestCorpse = corpse
        end
    end

    return bestCorpse
end

function UseRevealGrenade.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if not UseRevealGrenade.HasRevealGrenade(bot) then return false end
    if CountRevealTargets(bot) < 2 then return false end

    local state = GetState(bot)
    if IsValid(state.targetCorpse) then return true end

    local targetCorpse = UseRevealGrenade.FindTargetCorpse(bot)
    if not IsValid(targetCorpse) then return false end

    state.targetCorpse = targetCorpse
    return true
end

function UseRevealGrenade.OnStart(bot)
    local state = GetState(bot)
    state.startedAt = CurTime()
    state.fired = false
    return STATUS.RUNNING
end

function UseRevealGrenade.OnRunning(bot)
    local state = GetState(bot)
    local corpse = state.targetCorpse

    if state.fired and not UseRevealGrenade.HasRevealGrenade(bot) then
        return STATUS.SUCCESS
    end

    if not IsValid(corpse) then return STATUS.FAILURE end
    if not UseRevealGrenade.HasRevealGrenade(bot) then
        return state.fired and STATUS.SUCCESS or STATUS.FAILURE
    end

    local loco = bot:BotLocomotor()
    local inv = bot:BotInventory()
    local wep = UseRevealGrenade.GetRevealGrenade(bot)
    if not (loco and inv and wep) then return STATUS.FAILURE end

    inv:PauseAutoSwitch()
    loco:PauseAttackCompat()

    local corpsePos = corpse:GetPos()
    local dist = bot:GetPos():Distance(corpsePos)

    if dist > APPROACH_DIST then
        loco:SetGoal(corpsePos)
        loco:LookAt(corpsePos)
        return STATUS.RUNNING
    end

    bot:SelectWeapon("weapon_ttt_reveal_nade")
    loco:LookAt(corpsePos)

    if bot:GetActiveWeapon() ~= wep then
        loco:StopAttack()
        return STATUS.RUNNING
    end

    if dist > THROW_DIST then
        loco:SetHalt(false)
        loco:SetGoal(corpsePos)
        return STATUS.RUNNING
    end

    loco:SetGoal(nil)
    loco:SetHalt(true)

    if not state.fired then
        state.fired = true
        state.firedAt = CurTime()
        loco:StartAttack()
        return STATUS.RUNNING
    end

    loco:StopAttack()
    if (CurTime() - (state.firedAt or 0)) >= FIRE_TIMEOUT then
        return STATUS.SUCCESS
    end

    return STATUS.RUNNING
end

function UseRevealGrenade.OnSuccess(bot)
end

function UseRevealGrenade.OnFailure(bot)
end

function UseRevealGrenade.OnEnd(bot)
    local loco = bot:BotLocomotor()
    local inv = bot:BotInventory()

    if loco then
        loco:StopAttack()
        loco:SetHalt(false)
        loco:ResumeAttackCompat()
    end

    if inv then
        inv:ResumeAutoSwitch()
    end

    TTTBots.Behaviors.ClearState(bot, UseRevealGrenade.Name)
end