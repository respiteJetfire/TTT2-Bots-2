--- behaviors/swaprole.lua
--- Cursed-role proximity tag-swap behavior.
--- Walks up to a valid target and triggers CURS_DATA.AttemptSwap() to swap roles.
--- Uses the addon's native swap pipeline so backsies timers, detective protection,
--- sticky team handling, and status icons all work correctly.

if not (TTT2 and ROLE_CURSED) then return end

---@class BSwapRole : BBase
TTTBots.Behaviors.SwapRole = {}

local lib = TTTBots.Lib

---@class BSwapRole
local SwapRole = TTTBots.Behaviors.SwapRole
SwapRole.Name = "SwapRole"
SwapRole.Description = "Walks up to a player and swaps roles via CURS_DATA.AttemptSwap."
SwapRole.Interruptible = true

local STATUS = TTTBots.STATUS

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Urgency-scaled chance to attempt a swap. Higher as more players die.
---@param bot Player
---@return number chance 0-100
local function GetSwapChance(bot)
    local alive = #TTTBots.Lib.GetAlivePlayers()
    local total = player.GetCount()
    if total <= 0 then return 70 end
    -- Base 50%, scales toward ~100% when few players remain
    local ratio = 1 - (alive / total)
    return math.Clamp(50 + ratio * 50, 50, 100)
end

--- Score a potential swap target. Higher = more desirable.
---@param bot Player
---@param ply Player
---@return number
local function ScoreTarget(bot, ply)
    local score = 0
    local botPos = bot:GetPos()
    local plyPos = ply:GetPos()
    local dist = botPos:Distance(plyPos)

    -- Closer is much better (invert distance, max 20 pts)
    score = score + math.Clamp(2000 - dist, 0, 2000) / 100

    -- Prefer isolated players (fewer nearby witnesses)
    local witnesses = 0
    for _, other in ipairs(player.GetAll()) do
        if other ~= bot and other ~= ply and lib.IsPlayerAlive(other) then
            if plyPos:Distance(other:GetPos()) < 500 then
                witnesses = witnesses + 1
            end
        end
    end
    score = score - witnesses * 3

    -- Slight penalty for detective targets (less predictable outcome)
    if ROLE_DETECTIVE and ply:GetBaseRole() == ROLE_DETECTIVE then
        score = score - 5
    end

    -- Bonus for distracted/in-combat players
    if ply.attackTarget and IsValid(ply.attackTarget) then
        score = score + 3
    end

    return score
end

-- ---------------------------------------------------------------------------
-- Target Selection
-- ---------------------------------------------------------------------------

--- Find the best valid swap target respecting all addon convars.
---@param bot Player
---@return Player?
function SwapRole.GetTarget(bot)
    local detAllowed = GetConVar("ttt2_cursed_affect_det") and GetConVar("ttt2_cursed_affect_det"):GetBool() or false

    local bestTarget = nil
    local bestScore = -math.huge

    for _, ply in ipairs(player.GetAll()) do
        if ply == bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end

        -- Addon's native backsies protection
        if ply.curs_last_tagged ~= nil then continue end

        -- Detective protection (respects convar)
        if not detAllowed then
            if ROLE_DETECTIVE and ply:GetBaseRole() == ROLE_DETECTIVE then continue end
            if ROLE_DEFECTIVE and ply:GetSubRole() == ROLE_DEFECTIVE then continue end
        end

        -- Don't target allies
        if TTTBots.Roles.IsAllies(bot, ply) then continue end

        -- Counter-curse item
        if ply.HasEquipmentItem and ply:HasEquipmentItem("item_ttt_countercurse_mantra") then continue end

        -- Same-role early exit (waste of a swap)
        if ply:GetSubRole() == bot:GetSubRole() then continue end

        -- Skip defectors
        if ROLE_DEFECTOR and ply:GetSubRole() == ROLE_DEFECTOR then continue end

        -- Round state check
        if GetRoundState and GetRoundState() ~= ROUND_ACTIVE then continue end

        local score = ScoreTarget(bot, ply)
        if score > bestScore then
            bestScore = score
            bestTarget = ply
        end
    end

    return bestTarget
end

-- ---------------------------------------------------------------------------
-- Behavior Lifecycle
-- ---------------------------------------------------------------------------

function SwapRole.Validate(bot)
    if not CURS_DATA then return false end
    if bot:GetSubRole() ~= ROLE_CURSED then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not lib.IsPlayerAlive(bot) then return false end

    local state = TTTBots.Behaviors.GetState(bot, "SwapRole")
    local existingTarget = state.target
    if existingTarget and IsValid(existingTarget) and lib.IsPlayerAlive(existingTarget) then
        return true
    end

    -- Urgency-scaled gate
    local chance = GetSwapChance(bot)
    if math.random(1, 100) > chance then return false end

    local target = SwapRole.GetTarget(bot)
    if target then
        state.target = target
        return true
    end
    return false
end

function SwapRole.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "SwapRole")
    local target = state.target

    if target and IsValid(target) then
        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("CursedChasing", { player = target:Nick() })
        end
    end
    return STATUS.RUNNING
end

function SwapRole.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "SwapRole")
    local target = state.target

    -- Re-validate target
    if not target or not IsValid(target) or not lib.IsPlayerAlive(target) then
        target = SwapRole.GetTarget(bot)
        if not target then return STATUS.FAILURE end
        state.target = target
    end

    -- Check if target became invalid (e.g. tagged by someone else)
    if target.curs_last_tagged ~= nil then
        target = SwapRole.GetTarget(bot)
        if not target then return STATUS.FAILURE end
        state.target = target
    end

    local targetPos = target:GetPos()
    local botPos = bot:GetPos()
    local dist = botPos:Distance(targetPos)
    local loco = bot:BotLocomotor()
    if not loco then return STATUS.FAILURE end

    local tagDist = GetConVar("ttt2_cursed_tag_dist") and GetConVar("ttt2_cursed_tag_dist"):GetInt() or 150

    if dist <= tagDist then
        -- In range — look at target and attempt swap via native addon system
        local bodyPos = (TTTBots.Behaviors.AttackTarget and TTTBots.Behaviors.AttackTarget.GetTargetBodyPos)
            and TTTBots.Behaviors.AttackTarget.GetTargetBodyPos(target)
            or target:EyePos()
        loco:LookAt(bodyPos)

        -- CURS_DATA.AttemptSwap handles all validation, backsies, detective checks, sticky teams
        local didSwap = CURS_DATA.AttemptSwap(bot, target, 0)

        if didSwap then
            local chatter = bot:BotChatter()
            if chatter and chatter.On then
                chatter:On("CursedSwapSuccess", { player = target:Nick() })
            end
            return STATUS.SUCCESS
        else
            -- Fire appropriate failure chatter
            local chatter = bot:BotChatter()
            if chatter and chatter.On then
                local detAllowed = GetConVar("ttt2_cursed_affect_det") and GetConVar("ttt2_cursed_affect_det"):GetBool() or false
                if not detAllowed and ROLE_DETECTIVE and (target:GetBaseRole() == ROLE_DETECTIVE or (ROLE_DEFECTIVE and target:GetSubRole() == ROLE_DEFECTIVE)) then
                    chatter:On("CursedCantTagDet", {})
                elseif target.curs_last_tagged ~= nil then
                    chatter:On("CursedNoBacksies", {})
                end
            end
            state.target = nil
            return STATUS.RUNNING
        end
    else
        -- Navigate toward target
        loco:SetGoal(targetPos)
        return STATUS.RUNNING
    end
end

function SwapRole.OnSuccess(bot)
end

function SwapRole.OnFailure(bot)
end

function SwapRole.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "SwapRole")
    local loco = bot:BotLocomotor()
    if loco then
        loco:SetGoal(nil)
    end
end