--- behaviors/usetimestop.lua
--- Uses the Time Stop weapon (weapon_ttt_timestop) to freeze nearby enemies.
--- The bot should use this when multiple enemies are near and it has a strategic
--- advantage (e.g. about to attack, or in danger with allies nearby).

local lib = TTTBots.Lib
local STATUS = TTTBots.STATUS

---@class BUseTimestop
TTTBots.Behaviors.UseTimestop = {}

local UseTimestop = TTTBots.Behaviors.UseTimestop
UseTimestop.Name = "UseTimestop"
UseTimestop.Description = "Use the Time Stop weapon to freeze nearby enemies."
UseTimestop.Interruptible = true

--- Minimum enemies that must be in range before the bot uses timestop.
local MIN_ENEMIES = 2
--- Scan radius for counting nearby enemies.
local SCAN_RADIUS = 900

--- Check if the bot has the timestop weapon.
---@param bot Bot
---@return boolean
function UseTimestop.HasTimestop(bot)
    return bot:HasWeapon("weapon_ttt_timestop")
end

--- Get the timestop weapon entity.
---@param bot Bot
---@return Weapon?
function UseTimestop.GetTimestop(bot)
    local wep = bot:GetWeapon("weapon_ttt_timestop")
    return IsValid(wep) and wep or nil
end

--- Count enemies and allies within the scan radius.
---@param bot Bot
---@return number enemies, number allies
local function CountNearbyTargets(bot)
    local enemies, allies = 0, 0
    for _, ply in pairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() or ply == bot then continue end
        if bot:GetPos():Distance(ply:GetPos()) > SCAN_RADIUS then continue end
        if TTTBots.Roles.IsAllies(bot, ply) then
            allies = allies + 1
        else
            enemies = enemies + 1
        end
    end
    return enemies, allies
end

function UseTimestop.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if not UseTimestop.HasTimestop(bot) then return false end

    -- Check that the weapon has a charge left
    local wep = UseTimestop.GetTimestop(bot)
    if not wep then return false end
    if wep:Clip1() <= 0 then return false end

    local enemies, allies = CountNearbyTargets(bot)

    -- Need enough enemies to justify the use
    if enemies < MIN_ENEMIES then return false end
    -- Prefer using when enemies outnumber allies (we freeze everyone)
    -- Unless there are lots of enemies (panic use)
    if allies >= enemies and enemies < 3 then return false end

    -- Small chance gate so bot doesn't fire immediately every time
    if math.random(1, 30) > 1 then return false end

    return true
end

function UseTimestop.OnStart(bot)
    bot._timestopStart = CurTime()

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("UsingTimestop", {}, true)
    end

    return STATUS.RUNNING
end

function UseTimestop.OnRunning(bot)
    if not UseTimestop.HasTimestop(bot) then return STATUS.SUCCESS end

    local wep = UseTimestop.GetTimestop(bot)
    if not wep or wep:Clip1() <= 0 then return STATUS.SUCCESS end

    -- Timeout
    if bot._timestopStart and (CurTime() - bot._timestopStart) > 5 then
        return STATUS.FAILURE
    end

    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    inv:PauseAutoSwitch()
    bot:SetActiveWeapon(wep)
    loco:SetHalt(true)
    -- Fire immediately — this is a "use in place" weapon
    loco:StartAttack()

    -- After firing, weapon clip becomes 0 — that's our success
    timer.Simple(0.5, function()
        if IsValid(bot) then
            local w = UseTimestop.GetTimestop(bot)
            if not w or w:Clip1() <= 0 then
                -- Weapon used up
            end
        end
    end)

    return STATUS.RUNNING
end

function UseTimestop.OnSuccess(bot)
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("TimestopUsed", {}, true)
    end
end

function UseTimestop.OnFailure(bot) end

function UseTimestop.OnEnd(bot)
    bot._timestopStart = nil
    local loco = bot:BotLocomotor()
    local inv  = bot:BotInventory()
    if loco then
        loco:StopAttack()
        loco:SetHalt(false)
    end
    if inv then
        inv:ResumeAutoSwitch()
    end
end
