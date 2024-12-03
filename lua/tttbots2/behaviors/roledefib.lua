

---@class BRoledefib
TTTBots.Behaviors.Roledefib = {}

local lib = TTTBots.Lib

---@class BRoledefib
local Roledefib = TTTBots.Behaviors.Roledefib
Roledefib.Name = "Roledefib"
Roledefib.Description = "Use the roledefibrillator on a corpse."
Roledefib.Interruptible = true
Roledefib.WeaponClasses = { "weapon_ttt_defib_traitor", "weapon_ttt_mesdefi", "weapon_ttt2_markerdefi" }


local STATUS = TTTBots.STATUS

local function printf(...) print(string.format(...)) end

---Get the closest revivable corpse to our bot
---@param bot any
---@return Player? closest
---@return any? ragdoll
function Roledefib.GetCorpse(bot)
    -- print("GetCorpse", bot)
    local closest, rag = TTTBots.Lib.GetClosestRevivable(bot, false, true, true)
    if not closest then
        closest, rag = TTTBots.Lib.GetClosestRevivable(bot, false, false, true)
    end
    -- print("Role Defib: Bot GetCorpse", closest, rag)
    if not closest then return end

    -- local canSee = lib.CanSeeArc(bot, rag:GetPos() + Vector(0, 0, 16), 120)
    -- print(canSee)
    -- if canSee then
    return closest, rag
    -- end
end

---Check if the bot has a roledefib weapon
---@param bot Bot
---@return boolean
function Roledefib.HasRoledefib(bot)
    for i, class in pairs(Roledefib.WeaponClasses) do
        -- print("HasRoledefib", class)
        if bot:HasWeapon(class) then return true end
    end

    return false
end

---Get the roledefib weapon, if the bot has one.
---@param bot Bot
---@return Weapon?
function Roledefib.GetRoledefib(bot)
    for i, class in pairs(Roledefib.WeaponClasses) do
        local wep = bot:GetWeapon(class)
        if IsValid(wep) then return wep end
    end
end

local function failFunc(bot, target)
    target.reviveCooldown = CurTime() + 5
    local roledefib = Roledefib.GetRoledefib(bot)
    if not (roledefib and IsValid(roledefib)) then return end

    roledefib:StopSound("hum")
    roledefib:PlaySound("beep")
end

local function startFunc(bot)
    local roledefib = Roledefib.GetRoledefib(bot)
    if not (roledefib and IsValid(roledefib)) then return end

    roledefib:PlaySound("hum")
end

local function successFunc(bot)
    local roledefib = Roledefib.GetRoledefib(bot)
    if not (roledefib and IsValid(roledefib)) then return end

    roledefib:StopSound("hum")
    roledefib:PlaySound("zap")

    timer.Simple(1, function()
        if not (roledefib and IsValid(roledefib)) then return end
        roledefib:Remove()
    end)
end
---Revives a player from the dead and sets their role to the bot, assuming the target is alive
---@param bot Bot
---@param target Player
function Roledefib.FullRoledefib(bot, target)
    -- print("FullRoledefib", bot, target)
    target:Revive(
        0,
        function()
            if SIDEKICK and bot:GetSubRole() == ROLE_SIDEKICK then
                bot = bot:GetSidekickMate() or nil
            end

            target:SetRole(bot:GetSubRole(), bot:GetTeam())
            target:SetDefaultCredits()

            SendFullStateUpdate()
        end,
        nil,
        true,
        REVIVAL_BLOCK_NONE,
        function() successFunc(bot) end,
        nil,
        nil
    )
end

function Roledefib.ValidateCorpse(bot, corpse)
    return lib.IsValidBody(corpse or bot.roledefibRag)
end

function Roledefib.Validate(bot)
    if not TTTBots.Lib.IsTTT2() then return false end -- This is TTT2-specific.
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.preventRoledefib then return false end         -- just an extra feature to prevent roledefibbing

    -- cant roledefib without roledefib
    local hasRoledefib = Roledefib.HasRoledefib(bot)
    -- print("Role Defib: Bot Validate", hasRoledefib)
    if not hasRoledefib then return false end

    -- re-use existing
    local hasCorpse = Roledefib.ValidateCorpse(bot, bot.roledefibRag)
    -- print("Role Defib: Bot Validate Corpse", hasCorpse)
    if hasCorpse then return true end

    -- get new target
    local corpse, rag = Roledefib.GetCorpse(bot)
    -- print("Role Defib: Bot Validate Corpse", corpse, rag)
    if not corpse then return false end

    -- one last valid check
    local cValid = Roledefib.ValidateCorpse(bot, rag)
    -- print("Role Defib: Bot Validate Corpse Valid", cValid)
    if not cValid then return false end

    --- add a chance component to prevent bots from roledefibbing the same body
    local chance = math.random(0, 100) <= 2
    if not chance then return false end

    if TTTBots.Match.MarkedForDefib[corpse] and TTTBots.Match.MarkedForDefib[corpse] ~= bot then return false end
    return true
end

function Roledefib.OnStart(bot)
    bot.roledefibTarget, bot.roledefibRag = Roledefib.GetCorpse(bot)


    return STATUS.RUNNING
end

function Roledefib.GetSpinePos(rag)
    local default = rag:GetPos()

    local spineName = "ValveBiped.Bip01_Spine"
    local spine = rag:LookupBone(spineName)

    if spine then
        return rag:GetBonePosition(spine)
    end

    return default
end

---@class Bot
---@field roledefibTarget Player? The PLAYER of the roledefibRag we found
---@field roledefibRag Entity? The ragdoll we found to roledefib
---@field roledefibStartTime number? When we started roledefibbing our roledefibTarget

---@param bot Bot
function Roledefib.OnRunning(bot)
    local inventory, loco = bot:BotInventory(), bot:BotLocomotor()
    if not (inventory and loco) then return STATUS.FAILURE end

    local hasRoledefib = Roledefib.HasRoledefib(bot)
    if not hasRoledefib then return STATUS.FAILURE end

    local roledefib = Roledefib.GetRoledefib(bot)
    local target = bot.roledefibTarget
    local rag = bot.roledefibRag
    if not (target and rag) then return STATUS.FAILURE end
    if not (IsValid(target) and IsValid(rag)) then return STATUS.FAILURE end
    local ragPos = Roledefib.GetSpinePos(rag)

    loco:SetGoal(ragPos)
    loco:LookAt(ragPos)
    if not TTTBots.Match.MarkedForDefib[target] then
        TTTBots.Match.MarkedForDefib[target] = bot
    else
        return STATUS.FAILURE
    end

    local dist = bot:GetPos():Distance(ragPos)

    if dist < 40 then
        inventory:PauseAutoSwitch()
        bot:SetActiveWeapon(roledefib)
        loco:SetGoal() -- reset goal to stop moving
        loco:PauseAttackCompat()
        loco:Crouch(true)
        loco:PauseRepel()
        if bot.roledefibStartTime == nil then
            bot.roledefibStartTime = CurTime()
            startFunc(bot)
        end
        if bot.roledefibStartTime + 1 < CurTime() then
            Roledefib.FullRoledefib(bot, target)
            return STATUS.SUCCESS
        end
    else
        inventory:ResumeAutoSwitch()
        loco:ResumeAttackCompat()
        loco:SetHalt(false)
        loco:ResumeRepel()
        bot.roledefibStartTime = nil
    end

    return STATUS.RUNNING
end

function Roledefib.OnSuccess(bot)
end

function Roledefib.OnFailure(bot)
end

--- Called when the behavior succeeds or fails. Useful for cleanup, as it is always called once the behavior is a) interrupted, or b) returns a success or failure state.
---@param bot Bot
function Roledefib.OnEnd(bot)
    if TTTBots.Match.MarkedForDefib[bot.roledefibTarget] then
        TTTBots.Match.MarkedForDefib[bot.roledefibTarget] = nil
    end
    bot.roledefibTarget, bot.roledefibRag = nil, nil
    bot.roledefibStartTime = nil
    local inventory, loco = bot:BotInventory(), bot:BotLocomotor()
    if not (inventory and loco) then return end

    loco:ResumeAttackCompat()
    loco:Crouch(false)
    loco:SetHalt(false)
    loco:ResumeRepel()
    inventory:ResumeAutoSwitch()
end
