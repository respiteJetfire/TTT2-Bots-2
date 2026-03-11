--- Factory for role-specific weapon behaviors (the "deagle family").
--- Instead of 13+ near-identical files, call RegisterRoleWeapon(config) once.
---
--- Config table fields:
---   name          (string)   Behavior name, e.g. "CreateSidekick"
---   description   (string?)  Human-readable description (optional)
---   interruptible (boolean?) Defaults to true
---
---   -- Weapon access (one of three patterns):
---   getWeaponFn   (function(inv) -> weapon|nil)   Return weapon from inventory component
---   equipFn       (function(inv) -> boolean)       Equip the weapon via inventory component
---   -- OR for weapons held directly on the bot (not via CInventory):
---   hasWeaponFn   (function(bot) -> boolean)       bot:HasWeapon(...) style check
---   equipDirectFn (function(bot) -> weapon|nil)    bot:GetWeapon(...) style getter
---
---   -- Targeting:
---   findTargetFn  (function(bot) -> Player?, number?)   Find + score a target
---   stateKey      (string)    Key used in GetState table to store the target, e.g. "SidekickTarget"
---
---   -- Engagement rules:
---   engageDistance (number)   Max distance to start firing. Default 1000.
---   minDistance    (number?)  Minimum distance required (for "stand-off" weapons). Default nil.
---   witnessThreshold (number?) Max witnesses allowed before firing. Default nil (no check).
---   startChance    (number)   0-100 percent chance to start per Validate call. Default 2.
---   alwaysStart    (boolean?) If true, ignores startChance (startChance = 100). Default false.
---
---   -- Side-effects:
---   chatterEvent   (string?)  Chatter event to fire in OnStart, e.g. "CreatingSidekick"
---   chatterTeamOnly (boolean?) Whether the chatter event is team-only. Default true.
---   onFireFn       (function(bot, target) -> BStatus?)  Extra logic called when eyetrace hits target.
---                  If it returns a BStatus, that status is immediately returned from OnRunning.
---   onSuccessFn    (function(bot, target)?)  Extra logic in OnSuccess.
---   onEndFn        (function(bot, target)?)  Extra logic prepended to OnEnd.
---   validateExtraFn (function(bot) -> boolean?)  Additional Validate guard.
---   successConditionFn (function(bot, target) -> boolean?)
---                  If provided, checked each OnRunning tick; returns SUCCESS when true.
---   clipEmptyFails (boolean?) If true, return FAILURE when active weapon Clip1 == 0.
---   validateStartBothConditions (boolean?) If true, Validate requires BOTH target AND chance.
---   equipFailureFails (boolean?) If true, return FAILURE (not RUNNING) when equip fails.
---   cleanupOnSuccess (boolean?) If true, perform full loco/inv cleanup in OnSuccess (healgun-style).
---
--- Example:
---   TTTBots.Behaviors.RegisterRoleWeapon({
---       name         = "CreateSidekick",
---       getWeaponFn  = function(inv) return inv:GetJackalGun() end,
---       equipFn      = function(inv) return inv:EquipJackalGun() end,
---       findTargetFn = TTTBots.Lib.FindIsolatedTarget,
---       stateKey     = "Target",
---       witnessThreshold = 1,
---       startChance  = 2,
---       chatterEvent = "CreatingSidekick",
---   })

TTTBots = TTTBots or {}
TTTBots.Behaviors = TTTBots.Behaviors or {}

local lib = TTTBots.Lib

--- Registry of all role-weapon behaviors created through this factory.
--- Maps behavior name -> config table.
TTTBots.Behaviors.RoleWeaponRegistry = TTTBots.Behaviors.RoleWeaponRegistry or {}

---@param config table See field descriptions above.
function TTTBots.Behaviors.RegisterRoleWeapon(config)
    assert(type(config.name) == "string", "RegisterRoleWeapon: 'name' is required")
    assert(type(config.stateKey) == "string", "RegisterRoleWeapon: 'stateKey' is required")

    local name = config.name
    local stateKey = config.stateKey
    local STATUS = TTTBots.STATUS

    local engageDist    = config.engageDistance or 1000
    local minDist       = config.minDistance or nil
    local witnessThresh = config.witnessThreshold or nil  -- nil = no witness check
    local startChance   = config.alwaysStart and 100 or (config.startChance or 2)
    local interruptible = (config.interruptible ~= nil) and config.interruptible or true

    -- ----------------------------------------------------------------
    -- Internal helpers
    -- ----------------------------------------------------------------

    local function GetState(bot)
        return TTTBots.Behaviors.GetState(bot, name)
    end

    local function GetTarget(bot)
        return GetState(bot)[stateKey]
    end

    local function SetTarget(bot, target)
        GetState(bot)[stateKey] = target or (config.findTargetFn and config.findTargetFn(bot)) or nil
    end

    local function ClearTarget(bot)
        GetState(bot)[stateKey] = nil
    end

    local function ValidateTarget(bot, target)
        target = target or GetTarget(bot)
        return target and IsValid(target) and lib.IsPlayerAlive(target)
    end

    local function CheckForBetterTarget(bot)
        if not config.findTargetFn then return end
        local alternative = config.findTargetFn(bot)
        if not alternative then return end
        if not ValidateTarget(bot, alternative) then return end
        SetTarget(bot, alternative)
    end

    local function HasWeapon(bot)
        local inv = bot:BotInventory()
        if config.getWeaponFn then
            return inv and config.getWeaponFn(inv)
        elseif config.hasWeaponFn then
            return config.hasWeaponFn(bot)
        end
        return false
    end

    local function EquipWeapon(bot)
        local inv = bot:BotInventory()
        if config.equipFn then
            return inv and config.equipFn(inv)
        elseif config.equipDirectFn then
            local wep = config.equipDirectFn(bot)
            if IsValid(wep) then
                bot:SetActiveWeapon(wep)
                return true
            end
        end
        return false
    end

    -- ----------------------------------------------------------------
    -- Build the behavior table
    -- ----------------------------------------------------------------

    local Behavior = {}
    TTTBots.Behaviors[name] = Behavior

    Behavior.Name         = name
    Behavior.Description  = config.description or (name .. " role weapon behavior")
    Behavior.Interruptible = interruptible

    --- Internal accessors exposed so external code (e.g. hooks, HandleRequest) can use them.
    Behavior.GetTarget      = GetTarget
    Behavior.SetTarget      = SetTarget
    Behavior.ClearTarget    = ClearTarget
    Behavior.ValidateTarget = ValidateTarget

    function Behavior.Validate(bot)
        if not IsValid(bot) then return false end
        if bot.attackTarget ~= nil then return false end
        if not HasWeapon(bot) then return false end
        if not TTTBots.Match.IsRoundActive() then return false end
        if config.validateExtraFn and not config.validateExtraFn(bot) then return false end

        -- Phase-aware startChance boost for conversion behaviors:
        -- In EARLY game, conversion roles should strongly prefer converting over killing.
        local effectiveChance = startChance
        if config.isConversion then
            local ra = bot.BotRoundAwareness and bot:BotRoundAwareness()
            if ra then
                local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
                if PHASE then
                    local phase = ra:GetPhase()
                    if phase == PHASE.EARLY then
                        -- Almost always attempt conversion in early game
                        effectiveChance = math.max(effectiveChance * 8, 90)
                    elseif phase == PHASE.MID then
                        -- Strong boost in mid game
                        effectiveChance = math.max(effectiveChance * 4, 60)
                    end
                    -- LATE/OVERTIME: use base startChance (killing becomes more important)
                end
            end
        end

        local chancePass = (effectiveChance >= 100) or (math.random(0, 100) <= effectiveChance)
        if config.validateStartBothConditions then
            -- For conversion behaviors: if we already have a valid target, skip the chance gate
            -- to ensure we follow through on conversion attempts.
            if config.isConversion and ValidateTarget(bot) then
                return true
            end
            return ValidateTarget(bot) and chancePass
        end
        -- If this behavior uses a findTargetFn and alwaysStart is set, only validate when
        -- a real target exists -- otherwise the bot spins in a None→Behavior→Failure loop
        -- every tick when no eligible target is nearby (e.g. medic with no low-HP players).
        if config.alwaysStart and config.findTargetFn then
            return ValidateTarget(bot) or (chancePass and config.findTargetFn(bot) ~= nil)
        end
        return ValidateTarget(bot) or (chancePass and TTTBots.Match.IsRoundActive())
    end

    function Behavior.OnStart(bot)
        if not ValidateTarget(bot) then
            SetTarget(bot)
        end
        local target = GetTarget(bot)
        if config.chatterEvent and target and IsValid(target) then
            local chatter = bot:BotChatter()
            if chatter and chatter.On then
                local teamOnly = (config.chatterTeamOnly ~= false) -- default true
                chatter:On(config.chatterEvent, { player = target:Nick() }, teamOnly)
            end
        end
        return STATUS.RUNNING
    end

    function Behavior.OnRunning(bot)
        if not ValidateTarget(bot) then return STATUS.FAILURE end
        local target = GetTarget(bot)
        local targetPos = target:GetPos()
        local targetEyes = target:EyePos()

        -- Periodically check for a better target when not about to fire
        if not (math.random(1, TTTBots.Tickrate * 2) == 1 and bot:Visible(target)) then
            CheckForBetterTarget(bot)
            if GetTarget(bot) ~= target then return STATUS.RUNNING end
        end

        local loco = bot:BotLocomotor()
        local inv  = bot:BotInventory()
        if not (loco and inv) then return STATUS.FAILURE end

        local dist = bot:GetPos():Distance(targetPos)
        loco:SetGoal(targetPos)

        -- Engagement distance check (with optional minimum distance for stand-off weapons)
        local inRange = bot:Visible(target) and dist <= engageDist
        if minDist then
            inRange = inRange and dist >= minDist
        end

        if not inRange then return STATUS.RUNNING end

        -- In range — look, equip, aim, fire
        loco:LookAt(targetEyes)
        loco:SetGoal()
        inv:PauseAutoSwitch()

        local equipped = EquipWeapon(bot)
        if not equipped then
            return config.equipFailureFails and STATUS.FAILURE or STATUS.RUNNING
        end

        -- Optional clip-empty failure (SwapDeagle)
        if config.clipEmptyFails then
            local wep = bot:GetActiveWeapon()
            if wep and wep:Clip1() == 0 then
                return STATUS.FAILURE
            end
        end

        local bodyPos = TTTBots.Behaviors.AttackTarget.GetTargetBodyPos(target)
        loco:LookAt(bodyPos)

        local eyeTrace = bot:GetEyeTrace()
        local tracedTarget = eyeTrace and eyeTrace.Entity

        -- Optional witness check (FOV-aware + earshot instead of old 360° VisibleVec)
        if witnessThresh then
            local EARSHOT = 550
            local FOV_ARC = 120
            local nonAllies = TTTBots.Roles.GetNonAllies(bot)
            local witnessSet = {}
            for _, ply in pairs(nonAllies) do
                if ply == NULL or not IsValid(ply) then continue end
                if ply == bot or ply == target then continue end
                if not lib.IsPlayerAlive(ply) then continue end
                -- Check at both bot and target positions
                for _, checkPos in ipairs({bot:EyePos(), targetPos}) do
                    local d = ply:GetPos():Distance(checkPos)
                    if d <= EARSHOT then
                        witnessSet[ply] = true
                    elseif d <= TTTBots.Lib.BASIC_VIS_RANGE then
                        if lib.CanSeeArc and lib.CanSeeArc(ply, checkPos, FOV_ARC) then
                            witnessSet[ply] = true
                        end
                    end
                end
            end
            if table.Count(witnessSet) > witnessThresh then
                inv:ResumeAutoSwitch()
                loco:StopAttack()
                return STATUS.RUNNING
            end
        end

        if tracedTarget == target then
            loco:StartAttack()
            if config.onFireFn then
                local fireResult = config.onFireFn(bot, target)
                if fireResult then return fireResult end
            end
        end

        -- Optional success condition (healgun-style: success when target is full HP)
        if config.successConditionFn and config.successConditionFn(bot, target) then
            return STATUS.SUCCESS
        end

        return STATUS.RUNNING
    end

    function Behavior.OnSuccess(bot)
        if config.onSuccessFn then
            config.onSuccessFn(bot, GetTarget(bot))
        end
        if config.cleanupOnSuccess then
            ClearTarget(bot)
            local loco = bot:BotLocomotor()
            if loco then
                loco:StopAttack()
            end
            bot:SetAttackTarget(nil, "BEHAVIOR_END")
            timer.Simple(1, function()
                if not IsValid(bot) then return end
                local inv = bot:BotInventory()
                if not inv then return end
                inv:ResumeAutoSwitch()
            end)
        end
    end

    function Behavior.OnFailure(bot)
    end

    function Behavior.OnEnd(bot)
        local target = GetTarget(bot)
        if config.onEndFn then
            config.onEndFn(bot, target)
        end
        ClearTarget(bot)
        TTTBots.Behaviors.ClearState(bot, name)
        local loco = bot:BotLocomotor()
        if not loco then return end
        loco:StopAttack()
        bot:SetAttackTarget(nil, "BEHAVIOR_END")
        timer.Simple(1, function()
            if not IsValid(bot) then return end
            local inv = bot:BotInventory()
            if not inv then return end
            inv:ResumeAutoSwitch()
        end)
    end

    -- Store in the registry for introspection
    TTTBots.Behaviors.RoleWeaponRegistry[name] = config

    return Behavior
end
