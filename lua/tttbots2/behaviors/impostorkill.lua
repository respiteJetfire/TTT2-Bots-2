--- impostorkill.lua
--- Instant-kill behavior for Impostor bots.
---
--- The Impostor's instant kill (mode 0 = interact / mode 1 = knife):
---   • Mode 0: Press E while within ttt2_impostor_kill_dist (default 150u) of an enemy.
---   • Mode 1: Equip the knife and attack at melee range.
---   • 45-second cooldown between kills.
---   • Cannot kill while inside a vent.
---
--- Bot strategy:
---   1. Find a valid, non-ally enemy target.
---   2. Close the distance to within kill_dist.
---   3. Execute the instant kill (simulate +use or knife attack).
---   4. Escape via normal locomotion after the kill.

if not (TTT2 and ROLE_IMPOSTOR) then return end

---@class BImpostorKill
TTTBots.Behaviors.ImpostorKill = {}

local lib = TTTBots.Lib

---@class BImpostorKill
local IKill = TTTBots.Behaviors.ImpostorKill
IKill.Name = "ImpostorKill"
IKill.Description = "Close in and execute an instant kill as the Impostor"
IKill.Interruptible = true

local STATUS = TTTBots.STATUS

--- Default instant kill range (matches ttt2_impostor_kill_dist default).
local DEFAULT_KILL_DIST = 150

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

---@return number
local function getKillDist()
    local cvar = GetConVar("ttt2_impostor_kill_dist")
    return cvar and cvar:GetInt() or DEFAULT_KILL_DIST
end

---@return number  0 = interact, 1 = knife
local function getKillMode()
    local cvar = GetConVar("ttt2_impostor_kill_mode")
    return cvar and cvar:GetInt() or 0
end

--- Find the best enemy target for instant kill.
---@param bot Player
---@return Player|nil
local function findTarget(bot)
    local botPos = bot:GetPos()
    local best, bestDist = nil, math.huge

    for _, ply in ipairs(TTTBots.Match.AlivePlayers or {}) do
        if not IsValid(ply) then continue end
        if ply == bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then continue end

        -- Impostor cannot instantly kill the Spy (addon restriction)
        local role = ply.GetRoleStringRaw and ply:GetRoleStringRaw() or ""
        if role == "spy" then continue end

        -- Skip jester-like roles
        if role == "jester" or role == "swapper" or role == "marker" then continue end

        local dist = botPos:Distance(ply:GetPos())
        if dist < bestDist then
            bestDist = dist
            best = ply
        end
    end

    return best
end

-- ---------------------------------------------------------------------------
-- Behavior interface
-- ---------------------------------------------------------------------------

function IKill.Validate(bot)
    if not IsValid(bot) then return false end
    if not ROLE_IMPOSTOR then return false end
    if bot:GetSubRole() ~= ROLE_IMPOSTOR then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- Cannot instant kill while venting
    if TTTBots.Impostor_IsVenting and TTTBots.Impostor_IsVenting(bot) then return false end

    -- Can we use the instant kill?
    if not (TTTBots.Impostor_CanInstakill and TTTBots.Impostor_CanInstakill(bot)) then
        return false
    end

    -- Is there a valid target?
    return findTarget(bot) ~= nil
end

function IKill.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ImpostorKill")
    state.target = findTarget(bot)
    state.mode = getKillMode()
    state.killDist = getKillDist()
    state.executed = false
    return STATUS.RUNNING
end

function IKill.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "ImpostorKill")
    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    -- Kill was just executed this frame
    if state.executed then return STATUS.SUCCESS end

    -- Re-check canInstakill
    if not (TTTBots.Impostor_CanInstakill and TTTBots.Impostor_CanInstakill(bot)) then
        return STATUS.FAILURE
    end

    -- Validate target
    local target = state.target
    if not target or not IsValid(target) or not lib.IsPlayerAlive(target) then
        state.target = findTarget(bot)
        target = state.target
        if not target then return STATUS.FAILURE end
    end

    local targetPos = target:GetPos()
    local dist = bot:GetPos():Distance(targetPos)
    local killDist = state.killDist or DEFAULT_KILL_DIST

    -- Navigate toward target
    loco:SetGoal(targetPos)
    loco:LookAt(target:EyePos())

    -- In range — execute
    if dist <= killDist and bot:Visible(target) then
        local mode = state.mode or 0

        if mode == 0 then
            -- Interact mode: simulate +use while looking at target
            local eyeTrace = bot:GetEyeTrace()
            if eyeTrace and eyeTrace.Entity == target then
                bot:ConCommand("+use")
                timer.Simple(0.1, function()
                    if IsValid(bot) then bot:ConCommand("-use") end
                end)
                state.executed = true
                return STATUS.SUCCESS
            end
        else
            -- Knife mode: equip knife and attack
            local knife = bot:GetWeapon("weapon_ttt_impo_knife")
            if IsValid(knife) then
                bot:SetActiveWeapon(knife)
                inv:PauseAutoSwitch()

                local eyeTrace = bot:GetEyeTrace()
                if eyeTrace and eyeTrace.Entity == target then
                    loco:StartAttack()
                    timer.Simple(0.2, function()
                        if IsValid(bot) then
                            loco:StopAttack()
                            inv:ResumeAutoSwitch()
                        end
                    end)
                    state.executed = true
                    return STATUS.SUCCESS
                end
            end
        end
    end

    return STATUS.RUNNING
end

function IKill.OnSuccess(bot)
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
end

function IKill.OnFailure(bot)
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
end

function IKill.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "ImpostorKill")
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end
end
