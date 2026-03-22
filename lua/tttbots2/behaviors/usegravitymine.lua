--- behaviors/usegravitymine.lua
--- Bot behavior: throw a gravity mine near a group of enemies.

---@class BUseGravityMine
TTTBots.Behaviors.UseGravityMine = {}

local lib = TTTBots.Lib
local STATUS = TTTBots.STATUS

local UseGravityMine = TTTBots.Behaviors.UseGravityMine
UseGravityMine.Name = "UseGravityMine"
UseGravityMine.Description = "Throw a gravity mine toward a cluster of enemies"
UseGravityMine.Interruptible = true

local MIN_ENEMIES_FOR_MINE = 2
local THROW_RANGE = 600

--- Find the best position to throw the mine (center of enemy cluster)
---@param bot Bot
---@return Vector|nil throwPos
---@return number enemyCount
function UseGravityMine.FindThrowTarget(bot)
    local myPos = bot:GetPos()
    local enemies = {}

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then continue end
        if ply == bot then continue end
        if ply:IsSpec() then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then continue end
        if myPos:Distance(ply:GetPos()) > THROW_RANGE then continue end
        if not bot:Visible(ply) then continue end

        enemies[#enemies + 1] = ply
    end

    if #enemies < MIN_ENEMIES_FOR_MINE then return nil, 0 end

    -- Compute centroid of enemy positions
    local center = Vector(0, 0, 0)
    for _, e in ipairs(enemies) do
        center = center + e:GetPos()
    end
    center = center / #enemies

    return center, #enemies
end

function UseGravityMine.Validate(bot)
    if not IsValid(bot) or not bot:Alive() then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not bot:HasWeapon("weapon_ttt2_gravity_mine") then return false end

    -- Random chance gate
    if math.random(1, 40) > 1 then return false end

    local throwPos, count = UseGravityMine.FindThrowTarget(bot)
    return throwPos ~= nil
end

function UseGravityMine.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "UseGravityMine")
    state.step = 0
    state.startTime = CurTime()

    local throwPos = UseGravityMine.FindThrowTarget(bot)
    state.throwPos = throwPos

    local inv = bot:BotInventory()
    if inv then inv:PauseAutoSwitch() end

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("DeployingGravityMine", {}, true)
    end

    return STATUS.RUNNING
end

function UseGravityMine.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "UseGravityMine")
    local elapsed = CurTime() - (state.startTime or CurTime())

    if elapsed > 4.0 then return STATUS.FAILURE end
    if not state.throwPos then return STATUS.FAILURE end

    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    -- If the weapon was consumed (stripped after deploy), we're done
    if state.fired and not bot:HasWeapon("weapon_ttt2_gravity_mine") then
        return STATUS.SUCCESS
    end

    if state.step == 0 then
        -- Equip the mine
        bot:SelectWeapon("weapon_ttt2_gravity_mine")
        state.step = 1
        return STATUS.RUNNING

    elseif state.step == 1 and elapsed > 0.2 then
        -- Aim at throw position
        local activeWep = bot:GetActiveWeapon()
        if not IsValid(activeWep) or activeWep:GetClass() ~= "weapon_ttt2_gravity_mine" then
            if elapsed > 1.0 then
                local wep = bot:GetWeapon("weapon_ttt2_gravity_mine")
                if IsValid(wep) then
                    bot:SetActiveWeapon(wep)
                end
            else
                bot:SelectWeapon("weapon_ttt2_gravity_mine")
            end
            return STATUS.RUNNING
        end

        loco:LookAt(state.throwPos)

        -- Check aim alignment
        local aimDir = (state.throwPos - bot:GetShootPos()):GetNormalized()
        local eyeDir = bot:GetAimVector()
        if aimDir:Dot(eyeDir) > 0.85 then
            -- Call PrimaryAttack directly — bypasses locomotor's reactionDelay
            -- and semi-auto click gates which are designed for combat, not utility
            activeWep:PrimaryAttack()
            state.fired = true
            state.firedTime = CurTime()
            state.step = 2
        end

        return STATUS.RUNNING

    elseif state.step == 2 then
        -- Wait for weapon to be consumed
        if CurTime() - (state.firedTime or CurTime()) < 0.3 then
            return STATUS.RUNNING
        end

        if not bot:HasWeapon("weapon_ttt2_gravity_mine") then
            return STATUS.SUCCESS
        end

        return STATUS.FAILURE
    end

    return STATUS.RUNNING
end

function UseGravityMine.OnEnd(bot)
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end

    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end

    TTTBots.Behaviors.ClearState(bot, "UseGravityMine")
end

function UseGravityMine.OnSuccess(bot) end
function UseGravityMine.OnFailure(bot) end
