

---@class BDefib
TTTBots.Behaviors.Defib = {}

local lib = TTTBots.Lib

---@class BDefib
local Defib = TTTBots.Behaviors.Defib
Defib.Name = "Defib"
Defib.Description = "Use the defibrillator on a corpse."
Defib.Interruptible = true
Defib.WeaponClasses = { "weapon_ttt_defibrillator", "weapon_ttt2_medic_defibrillator" }

local STATUS = TTTBots.STATUS

local function printf(...) print(string.format(...)) end

---Get the closest revivable corpse to our bot
---@param bot any
---@param allyOnly boolean
---@return Player? closest
---@return any? ragdoll
function Defib.GetCorpse(bot, allyOnly)
    local closest, rag = TTTBots.Lib.GetClosestRevivable(bot, allyOnly, true, true, 2000)
    if not (closest and rag) then
        closest, rag = TTTBots.Lib.GetClosestRevivable(bot, allyOnly or true, false, 1000)
        -- if not rag then return end
        -- local canSee = lib.CanSeeArc(bot, rag:GetPos() + Vector(0, 0, 16), 120)
        -- if not canSee then return end
    end

    -- local canSee = lib.CanSeeArc(bot, rag:GetPos() + Vector(0, 0, 16), 120)
    -- print(canSee)
    -- if canSee then
    -- if closest and rag then
        -- printf("bot %s, closest: %s, rag: %s", tostring(bot), tostring(closest), tostring(rag))
    -- end
    return closest, rag
    -- end
end

function Defib.HasDefib(bot)
    for i, class in pairs(Defib.WeaponClasses) do
        -- print("Checking for weapon: ", class)
        if bot:HasWeapon(class) then return true end
        -- if bot:HasWeapon(class) then return true end
    end

    return false
end

---Get the defib weapon, if the bot has one.
---@param bot Bot
---@return Weapon?
function Defib.GetDefib(bot)
    for i, class in pairs(Defib.WeaponClasses) do
        local wep = bot:GetWeapon(class)
        if IsValid(wep) then return wep end
    end
end

local function failFunc(bot, target)
    target.reviveCooldown = CurTime() + 30
    local defib = Defib.GetDefib(bot)
    if not (defib and IsValid(defib)) then return end

    defib:StopSound("hum")
    defib:PlaySound("beep")
end

local function startFunc(bot)
    local defib = Defib.GetDefib(bot)
    if not (defib and IsValid(defib)) then return end

    defib:PlaySound("hum")
end

local function successFunc(bot)
    local defib = Defib.GetDefib(bot)
    local botRole = bot:GetSubRole()
    if not (defib and IsValid(defib)) then return end

    defib:StopSound("hum")
    defib:PlaySound("zap")

    timer.Simple(1, function()
        if not (defib and IsValid(defib)) then return end
        if botRole == ROLE_MEDIC or botRole == ROLE_DOCTOR then return end
        defib:Remove()
    end)
    return STATUS.SUCCESS
end
---Revives a player from the dead, assuming the target is alive
---@param bot Bot
---@param target Player
function Defib.FullDefib(bot, target)
    target:Revive(
        0,                                    -- delay number=3
        function() successFunc(bot) end,      -- OnRevive function?
        nil,                                  -- DoCheck function?
        true,                                 -- needsCorpse
        REVIVAL_BLOCK_NONE,                   -- blockRound number=REVIVAL_BLOCK_NONE
        function() failFunc(bot, target) end, -- OnFail function?
        nil,                                  -- spawnPos Vector?
        nil                                   -- spawnAng Angle?
    )
end

function Defib.ValidateCorpse(bot, corpse)
    return lib.IsValidBody(corpse or bot.defibRag)
end

function Defib.Validate(bot)
    local role = bot:GetSubRole()
    if not TTTBots.Lib.IsTTT2() then return false end -- This is TTT2-specific.
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.preventDefib then return false end         -- just an extra feature to prevent defibbing
    -- if TTTBots.Match.MarkedForDefib[bot.defibTarget] and TTTBots.Match.MarkedForDefib[bot.defibTarget] ~= bot then
    --     print("Defib.Cant Validate marked: ", TTTBots.Match.MarkedForDefib[bot.defibTarget], bot)
    --     return false
    -- end

    -- cant defib without defib
    local hasDefib = Defib.HasDefib(bot)

    if not hasDefib then return false end

    -- re-use existing
    local hasCorpse = Defib.ValidateCorpse(bot, bot.defibRag)
    if hasCorpse then return true end

    if not bot.defibTarget or not bot.defibRag then
        if role == ROLE_DOCTOR then
            bot.defibTarget, bot.defibRag = Defib.GetCorpse(bot, true)
        elseif role == ROLE_MEDIC then
            bot.defibTarget, bot.defibRag = Defib.GetCorpse(bot, false)
        else
            bot.defibTarget, bot.defibRag = Defib.GetCorpse(bot, true)
        end
    end

    if not (bot.defibTarget and bot.defibRag) then 
        -- print("Defib.Validate: No body")
        return false
    end

    if TTTBots.Match.MarkedForDefib[bot.defibTarget] and TTTBots.Match.MarkedForDefib[bot.defibTarget] ~= bot then
        return false
    end
    local hasCorpse = Defib.ValidateCorpse(bot, bot.defibRag)
    if not hasCorpse then return false end

    return true
end

function Defib.OnStart(bot)
    local role = bot:GetSubRole()

    if not (TTTBots.Match.MarkedForDefib[bot.defibTarget]) and bot.defibTarget ~= bot then
        TTTBots.Match.MarkedForDefib[bot.defibTarget] = bot
    end
    -- print("Defib.OnStart", bot, role)
    if not bot.defibTarget or not bot.defibRag then
        if role == ROLE_DOCTOR then
            bot.defibTarget, bot.defibRag = Defib.GetCorpse(bot, true)
        elseif role == ROLE_MEDIC then
            bot.defibTarget, bot.defibRag = Defib.GetCorpse(bot, false)
        else
            bot.defibTarget, bot.defibRag = Defib.GetCorpse(bot, true)
        end
    end

    local chatter = bot:BotChatter()
    chatter:On("RevivingPlayer", {player = bot.defibTarget:Nick()})

    return STATUS.RUNNING
end

function Defib.GetSpinePos(rag)
    local default = rag:GetPos()

    local spineName = "ValveBiped.Bip01_Spine"
    local spine = rag:LookupBone(spineName)

    if spine then
        return rag:GetBonePosition(spine)
    end

    return default
end

---@class Bot
---@field defibTarget Player? The PLAYER of the defibRag we found
---@field defibRag Entity? The ragdoll we found to defib
---@field defibStartTime number? When we started defibbing our defibTarget

---@param bot Bot
function Defib.OnRunning(bot)
    -- print("Defib.OnRunning")
    local inventory, loco = bot:BotInventory(), bot:BotLocomotor()
    local botRole = bot:GetSubRole()
    if not (inventory and loco) then return STATUS.FAILURE end

    local defib = Defib.GetDefib(bot)
    local hasDefib = Defib.HasDefib(bot)
    local target = bot.defibTarget
    local rag = bot.defibRag
    -- if (target and rag) then
    --     -- print("Defib.OnRunning: ", target, rag)
    -- end
    -- mark the target and bot as defibbing if the defib target does not have a bot

    -- print(TTTBots.Match.MarkedForDefib[bot.defibTarget], bot)
    -- -print every bot that is marked for defib
    -- for k, v in pairs(TTTBots.Match.MarkedForDefib) do
    --     print(k, v)
    -- end

    
    -- if TTTBots.Match.MarkedForDefib[bot.defibTarget] and TTTBots.Match.MarkedForDefib[bot.defibTarget] ~= bot then
    --     print("Defib.OnFailure: ", TTTBots.Match.MarkedForDefib[bot.defibTarget], bot)
    --     return STATUS.FAILURE
    -- end
    if not (target and rag) and HasDefib then return STATUS.FAILURE end
    if not (IsValid(target) and IsValid(rag)) then return STATUS.FAILURE end
    local ragPos = Defib.GetSpinePos(rag)

    loco:SetGoal(ragPos)
    loco:LookAt(ragPos)

    local dist = bot:GetPos():Distance(ragPos)

    if dist < 50 then
        inventory:PauseAutoSwitch()
        bot:SetActiveWeapon(defib)
        loco:SetGoal() -- reset goal to stop moving
        loco:PauseAttackCompat()
        loco:Crouch(true)
        loco:PauseRepel()
        if bot.defibStartTime == nil then
            bot.defibStartTime = CurTime()
            startFunc(bot)
            -- print("Starting defib")
        end
        if bot.defibStartTime + (botRole == ROLE_DOCTOR and 3 or botRole == ROLE_MEDIC and 5 or 5) < CurTime() then
            Defib.FullDefib(bot, target)
            -- print("Finished defib")
            return STATUS.SUCCESS
        end
    else
        -- print("Failed to defib, too far away")
        inventory:ResumeAutoSwitch()
        loco:ResumeAttackCompat()
        loco:SetHalt(false)
        loco:ResumeRepel()
        bot.defibStartTime = nil
    end
    return STATUS.RUNNING
end

function Defib.OnSuccess(bot)
    if TTTBots.Match.MarkedForDefib[bot.defibTarget] then
        TTTBots.Match.MarkedForDefib[bot.defibTarget] = nil
    end
    -- print("Defib.OnSuccess")
end

function Defib.OnFailure(bot)
    -- print("Defib.OnFailure")
end

function Defib.HandleRequest(bot, target)
    local response = true
    if not IsValid(target) then response = false end
    if not Defib.ValidateCorpse(bot, target) then response = false end
    if response then
        bot.defibTarget, bot.defibRag = target, target
    end
end


--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function Defib.OnEnd(bot)
    if TTTBots.Match.MarkedForDefib[bot.defibTarget] then
        TTTBots.Match.MarkedForDefib[bot.defibTarget] = nil
    end
    bot.defibTarget, bot.defibRag = nil, nil
    bot.defibStartTime = nil
    local inventory, loco = bot:BotInventory(), bot:BotLocomotor()
    if not (inventory and loco) then return end
    loco:ResumeAttackCompat()
    loco:Crouch(false)
    loco:SetHalt(false)
    loco:ResumeRepel()
    inventory:ResumeAutoSwitch()
end
