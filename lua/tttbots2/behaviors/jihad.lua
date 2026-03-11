

---@class BJihad
TTTBots.Behaviors.Jihad = {}

local lib = TTTBots.Lib

---@class BJihad
local BehaviorJihad = TTTBots.Behaviors.Jihad
BehaviorJihad.Name = "Jihad"
BehaviorJihad.Description = "Equip and use a 'weapon_ttt_jihad_bomb' when enough enemies are nearby with ally/jester protection."
BehaviorJihad.Interruptible = true

local STATUS = TTTBots.STATUS

--- Detonation radius — should match the actual weapon's blast radius
local DETONATION_RADIUS = 500

--- Phase-aware minimum enemy thresholds for defectors.
--- In early game the defector should wait for larger groups; in late game any
--- enemy cluster is worth detonating on (the defector is about to be exposed).
local DEFECTOR_THRESHOLDS = {
    EARLY = 3,
    MID   = 2,
    LATE  = 1,
}

--- Minimum enemies for non-defector roles (traitors with jihad bomb)
local DEFAULT_MIN_ENEMIES = 4

--- Get the current game phase or nil if round awareness is unavailable
---@param bot Bot
---@return string? phase  One of PHASE enum values or nil
local function GetPhase(bot)
    local ra = bot.BotRoundAwareness and bot:BotRoundAwareness()
    local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
    if not (ra and PHASE) then return nil end
    return ra:GetPhase()
end

--- Get the phase-aware minimum enemy threshold for the given bot
---@param bot Bot
---@return number
local function GetMinEnemies(bot)
    local isDefector = ROLE_DEFECTOR and bot:GetSubRole() == ROLE_DEFECTOR
    if not isDefector then return DEFAULT_MIN_ENEMIES end

    local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
    local phase = GetPhase(bot)

    if not phase or not PHASE then return DEFECTOR_THRESHOLDS.MID end

    if phase == PHASE.EARLY then
        return DEFECTOR_THRESHOLDS.EARLY
    elseif phase == PHASE.MID then
        return DEFECTOR_THRESHOLDS.MID
    else
        -- LATE / OVERTIME
        return DEFECTOR_THRESHOLDS.LATE
    end
end

--- Count enemies and allies within the detonation radius.
--- Also checks for jesters (instant abort if any jester in range).
---@param bot Bot
---@return number enemies
---@return number allies
---@return boolean jesterPresent
local function CountBlastTargets(bot)
    local players = lib.FindCloseTargets(bot, DETONATION_RADIUS, true)
    local enemies = 0
    local allies = 0
    local jesterPresent = false

    for _, ply in ipairs(players) do
        -- Jester check — never detonate if a jester is in the blast
        if TEAM_JESTER and ply:GetTeam() == TEAM_JESTER then
            jesterPresent = true
            return enemies, allies, jesterPresent
        end

        if ply:GetTeam() ~= bot:GetTeam() then
            enemies = enemies + 1
        else
            allies = allies + 1
        end
    end

    return enemies, allies, jesterPresent
end

--- Calculate the chance of detonation based on net kills and personality.
--- Returns true if the bot should proceed with detonation.
---@param bot Bot
---@param enemies number
---@param allies number
---@return boolean
local function ShouldDetonate(bot, enemies, allies)
    local isDefector = ROLE_DEFECTOR and bot:GetSubRole() == ROLE_DEFECTOR

    -- Net kills must be positive (we'd kill more enemies than allies)
    local netKills = enemies - allies
    if netKills <= 0 then return false end

    -- Base chance proportional to net kills
    local chance = netKills * 8

    -- Defector gets a significant boost (suicide bombing is their ONLY attack)
    if isDefector then
        chance = chance * 2.5
    end

    -- Personality modifiers
    local personality = bot:BotPersonality()
    if personality then
        local archetype = personality:GetClosestArchetype()
        if archetype == "Hothead" then
            chance = chance * 1.5 -- Hotheads are more trigger-happy
        elseif archetype == "Tryhard/nerd" then
            chance = chance * 0.8 -- Tryhards are more calculated
        elseif archetype == "Dumb" then
            chance = chance * 1.3 -- Dumb bots don't think twice
        end

        -- Trait-based modifiers
        if personality:GetTraitBool("aggressive") then
            chance = chance * 1.3
        end
        if personality:GetTraitBool("cautious") then
            chance = chance * 0.7
        end
        if personality:GetTraitBool("risktaker") then
            chance = chance * 1.4
        end
    end

    -- Phase modifier: more desperate in late game
    local phase = GetPhase(bot)
    local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
    if phase and PHASE then
        if phase == PHASE.LATE then
            chance = chance * 1.5
        elseif phase == PHASE.OVERTIME then
            chance = chance * 2.0
        end
    end

    -- Negative penalty for allies in the blast
    local allyPenalty = allies * 10
    chance = chance - allyPenalty

    return math.random(1, 100) <= math.max(chance, 1)
end

--- Validate the behavior before we can start it (or continue running)
---@param bot Bot
---@return boolean
function BehaviorJihad.Validate(bot)
    if not TTTBots.Lib.IsTTT2() then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not IsValid(bot) then return false end
    if not bot:Alive() then return false end

    if not BehaviorJihad.HasJihadBomb(bot) then return false end

    local enemies, allies, jesterPresent = CountBlastTargets(bot)

    -- Never detonate near jesters
    if jesterPresent then return false end

    -- Phase-aware minimum enemy threshold
    local minEnemies = GetMinEnemies(bot)
    if enemies < minEnemies then return false end

    -- Ally protection: don't detonate if allies >= enemies
    if allies >= enemies then return false end

    -- Chance/willingness check
    if not ShouldDetonate(bot, enemies, allies) then return false end

    return true
end

--- Start the behavior
---@param bot Bot
function BehaviorJihad.OnStart(bot)
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("JihadBombWarn", {}, true)
    end
    return STATUS.RUNNING
end

--- Run the behavior
---@param bot Bot
---@return STATUS
function BehaviorJihad.OnRunning(bot)
    local inventory, loco = bot:BotInventory(), bot:BotLocomotor()
    local jihad = BehaviorJihad.GetJihadBomb(bot)
    if not (inventory and loco and jihad) then return STATUS.FAILURE end

    -- Re-validate conditions (enemies may have moved)
    local enemies, allies, jesterPresent = CountBlastTargets(bot)
    if jesterPresent then return STATUS.FAILURE end
    if enemies < 1 then return STATUS.FAILURE end
    if allies >= enemies then return STATUS.FAILURE end

    inventory:PauseAutoSwitch()
    bot:SetActiveWeapon(jihad)
    loco:PauseAttackCompat()

    -- Calculate the midpoint of enemy positions to move toward
    local midpoint = Vector(0, 0, 0)
    local count = 0
    local players = lib.FindCloseTargets(bot, DETONATION_RADIUS, true)

    for _, ply in ipairs(players) do
        if ply:GetTeam() ~= bot:GetTeam() then
            midpoint = midpoint + ply:GetPos()
            count = count + 1
        end
    end

    if count > 0 then
        midpoint = midpoint / count
        loco:SetGoal(midpoint)
    else
        loco:SetGoal() -- clear goal
    end

    if not BehaviorJihad.HasJihadBomb(bot) then return STATUS.FAILURE end

    -- Trigger the attack (primary fire to detonate)
    loco:StartAttack()

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("JihadBombUse")
    end

    return STATUS.RUNNING
end

--- End the behavior
---@param bot Bot
function BehaviorJihad.OnEnd(bot)
    local inventory, loco = bot:BotInventory(), bot:BotLocomotor()
    if not (inventory and loco) then return end
    inventory:ResumeAutoSwitch()
    loco:StopAttack()
    bot:SetAttackTarget(nil, "BEHAVIOR_END")
    loco:ResumeAttackCompat()
end

function BehaviorJihad.OnSuccess(bot)
end

function BehaviorJihad.OnFailure(bot)
end

--- Check if the bot has the jihad bomb
---@param bot Bot
---@return boolean
function BehaviorJihad.HasJihadBomb(bot)
    return bot:HasWeapon("weapon_ttt_jihad_bomb")
end

--- Get the jihad bomb weapon entity
---@param bot Bot
---@return Weapon?
function BehaviorJihad.GetJihadBomb(bot)
    return bot:GetWeapon("weapon_ttt_jihad_bomb")
end