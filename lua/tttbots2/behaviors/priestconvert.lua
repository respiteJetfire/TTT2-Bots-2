local lib = TTTBots.Lib

---@param ply Player
---@return boolean
local function IsBrother(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return false end
    if not (PRIEST_DATA and PRIEST_DATA.IsBrother) then return false end
    return PRIEST_DATA:IsBrother(ply) == true
end

---@param alive table<Player>
---@return integer, integer
local function GetBrotherhoodCounts(alive)
    local brotherCount = 0
    local nonBrotherCount = 0

    for _, ply in ipairs(alive or {}) do
        if not (IsValid(ply) and lib.IsPlayerAlive(ply)) then continue end
        if IsBrother(ply) then
            brotherCount = brotherCount + 1
        else
            nonBrotherCount = nonBrotherCount + 1
        end
    end

    return brotherCount, nonBrotherCount
end

---@param phase string|number|nil
---@param aliveCount integer
---@param brotherCount integer
---@param nonBrotherCount integer
---@return number, integer, boolean, string
local function GetBrotherhoodConversionPolicy(phase, aliveCount, brotherCount, nonBrotherCount)
    local maxSuspicion = 0.4
    local witnessLimit = 2
    local mode = "small"

    if phase == "EARLY" or phase == 1 then
        maxSuspicion = 0.5
    elseif phase == "MID" or phase == 2 then
        maxSuspicion = 0.4
    elseif phase == "LATE" or phase == 3 then
        maxSuspicion = 0.3
        witnessLimit = 1
    elseif phase == "OVERTIME" or phase == 4 then
        return 0, 0, true, "full"
    end

    -- Brotherhood size-based strategy:
    -- small   => convert aggressively
    -- large   => stricter safety, focus coordination
    -- full    => stop converting
    local fullThreshold = math.max(4, math.ceil(aliveCount * 0.6))
    if nonBrotherCount <= 1 or brotherCount >= fullThreshold then
        return maxSuspicion, witnessLimit, true, "full"
    end

    if brotherCount >= 3 then
        mode = "large"
        maxSuspicion = math.max(maxSuspicion - 0.08, 0.22)
        witnessLimit = math.min(witnessLimit, 1)
    else
        mode = "small"
        maxSuspicion = math.min(maxSuspicion + 0.05, 0.55)
        witnessLimit = witnessLimit + 1
    end

    return maxSuspicion, witnessLimit, false, mode
end

---@param bot Bot
---@return number?, string?
local function GetPhaseSuspicionThreshold(bot)
    local ra = bot:BotRoundAwareness()
    local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
    if not (ra and PHASE) then
        return 0.4, nil
    end

    local phase = ra:GetPhase()
    if phase == PHASE.EARLY then
        return 0.5, phase
    elseif phase == PHASE.MID then
        return 0.4, phase
    elseif phase == PHASE.LATE then
        return 0.3, phase
    elseif phase == PHASE.OVERTIME then
        return nil, phase -- don't convert in overtime
    end

    return 0.4, phase
end

--- Finds a low-risk target for the Holy Deagle.
--- Priest dies when shooting most evil roles, so we prioritize low-suspicion,
--- nearby, visible, non-detective players that are not already in brotherhood.
---@param bot Bot
---@return Player?
local function FindSafeBrotherhoodTarget(bot)
    if not IsValid(bot) then return nil end

    local alive = lib.GetAlivePlayers()
    if not alive or #alive == 0 then return nil end

    local morality = bot:BotMorality()
    local evidence = bot:BotEvidence()

    local maxAllowedSuspicion, phase = GetPhaseSuspicionThreshold(bot)
    if maxAllowedSuspicion == nil then
        return nil -- overtime: survive, don't convert
    end

    local brotherCount, nonBrotherCount = GetBrotherhoodCounts(alive)
    local policySuspicion, witnessLimit, stopConverting, strategyMode =
        GetBrotherhoodConversionPolicy(phase, #alive, brotherCount, nonBrotherCount)
    if stopConverting then
        return nil
    end
    maxAllowedSuspicion = math.min(maxAllowedSuspicion, policySuspicion)

    local state = TTTBots.Behaviors.GetState(bot, "PriestConvert")
    local neverTarget = (state and state._neverTargetEnts) or {}

    local candidates = {}

    for _, ply in ipairs(alive) do
        if not IsValid(ply) then continue end
        if ply == bot then continue end
        if not lib.IsPlayerAlive(ply) then continue end
        if not bot:Visible(ply) then continue end

        if neverTarget[ply:EntIndex()] then continue end

        -- Never target known detective base role (Priest only damages detective)
        if ROLE_DETECTIVE and ply.GetBaseRole and ply:GetBaseRole() == ROLE_DETECTIVE then continue end
        -- Sniffer is detective-like: also avoid
        if ROLE_SNIFFER and ply.GetSubRole and ply:GetSubRole() == ROLE_SNIFFER then continue end

        -- Cascade awareness: avoid known cascade-converter threats.
        if ROLE_JACKAL and ply.GetSubRole and ply:GetSubRole() == ROLE_JACKAL then continue end
        if ROLE_NECROMANCER and ply.GetSubRole and ply:GetSubRole() == ROLE_NECROMANCER then continue end
        if TEAM_INFECTED and ply.GetTeam and ply:GetTeam() == TEAM_INFECTED then continue end

        -- Never target priests
        if ROLE_PRIEST and ply.GetSubRole and ply:GetSubRole() == ROLE_PRIEST then continue end

        -- Avoid shooting already-KOS players (high chance they are actually evil)
        if TTTBots.Match and TTTBots.Match.KOSList and TTTBots.Match.KOSList[ply] then continue end

        -- Skip existing brothers
        if PRIEST_DATA and PRIEST_DATA.IsBrother and PRIEST_DATA:IsBrother(ply) then continue end

        -- Skip players with strong existing evidence against them
        if evidence and evidence.EvidenceWeight and evidence:EvidenceWeight(ply) >= 4 then continue end

        local suspicionRaw = (morality and morality.GetSuspicion and morality:GetSuspicion(ply)) or 0
        -- Morality suspicion is typically in ~[-10..10]; normalize to [-1..1] for thresholding
        local suspicionNorm = math.Clamp((suspicionRaw or 0) / 10, -1, 1)
        if suspicionNorm >= maxAllowedSuspicion then continue end

        local dist = bot:GetPos():Distance(ply:GetPos())
        if dist > 1800 then continue end

        -- Prefer fewer witnesses when using a hidden role's conversion tool
        local witnesses = lib.GetAllWitnessesBasic(ply:GetPos(), alive, bot)
        local witnessCount = 0
        for _, witness in ipairs(witnesses or {}) do
            if not (IsValid(witness) and witness:IsPlayer()) then continue end
            if witness == bot or witness == ply then continue end
            -- only count non-brother witnesses (hidden-role witness management)
            if IsBrother(witness) then continue end
            witnessCount = witnessCount + 1
        end

        if witnessCount > witnessLimit then continue end

        -- Higher score is better
        local score = 0
        score = score + ((maxAllowedSuspicion - suspicionNorm) * 320)
        score = score + math.max(0, (1800 - dist) * 0.05)
        score = score - (witnessCount * 100)

        -- Earlier phases should be more willing to convert than later phases
        if phase == "EARLY" then
            score = score + 60
        elseif phase == "LATE" then
            score = score - 40
        end

        if strategyMode == "small" then
            score = score + 55
        elseif strategyMode == "large" then
            score = score - 45
        end

        table.insert(candidates, {
            ply = ply,
            score = score,
            dist = dist,
        })
    end

    if #candidates == 0 then return nil end

    table.sort(candidates, function(a, b)
        if a.score == b.score then
            return a.dist < b.dist
        end

        return a.score > b.score
    end)

    return candidates[1].ply
end

TTTBots.Behaviors.RegisterRoleWeapon({
    name         = "PriestConvert",
    description  = "Use the Holy Deagle to add a low-risk target to the priest brotherhood.",
    interruptible = true,
    stateKey     = "PriestTarget",
    getWeaponFn  = function(inv) return inv:GetPriestGun() end,
    equipFn      = function(inv) return inv:EquipPriestGun() end,
    findTargetFn = FindSafeBrotherhoodTarget,
    engageDistance = 1300,
    startChance  = 35,
    isConversion = true,
    validateStartBothConditions = true,
    equipFailureFails = true,
    chatterEvent = "PriestConverting",
    chatterTeamOnly = true,
    onFireFn = function(bot, target)
        -- Outcome detection: after the shot resolves server-side, check if target joined Brotherhood.
        local state = TTTBots.Behaviors.GetState(bot, "PriestConvert")
        if not state then return end

        local now = CurTime()
        local key = IsValid(target) and target:EntIndex() or -1
        if state._outcomePendingKey == key and (state._outcomePendingUntil or 0) > now then
            return
        end

        state._outcomePendingKey = key
        state._outcomePendingUntil = now + 0.8

        timer.Simple(0.35, function()
            if not IsValid(bot) then return end
            if not IsValid(target) then return end

            local st = TTTBots.Behaviors.GetState(bot, "PriestConvert")
            if st then
                st._outcomePendingKey = nil
                st._outcomePendingUntil = nil
            end

            -- If priest died from an unsafe shot, stop here.
            if not lib.IsPlayerAlive(bot) then return end

            local chatter = bot:BotChatter()

            -- Successful conversion: treat target as confirmed innocent.
            if PRIEST_DATA and PRIEST_DATA.IsBrother and PRIEST_DATA:IsBrother(target) then
                local morality = bot:BotMorality()
                if morality and morality.GetSuspicion then
                    local cur = morality:GetSuspicion(target)
                    if cur > 0 then
                        morality:SetSuspicionDirect(target, 0)
                    end
                end

                local evidence = bot:BotEvidence()
                if evidence and evidence.ConfirmInnocent then
                    evidence:ConfirmInnocent(target, "priest_brotherhood_conversion")
                end

                if chatter and chatter.On then
                    chatter:On("PriestConvertSuccess", { player = target:Nick(), playerEnt = target }, true)
                end

                if PRIEST_DATA and PRIEST_DATA.IsBrother and not bot._priestBrotherhoodStrongFired then
                    local brotherCount = 0
                    for _, ply in ipairs(TTTBots.Match.AlivePlayers or player.GetAll()) do
                        if IsValid(ply) and PRIEST_DATA:IsBrother(ply) then
                            brotherCount = brotherCount + 1
                        end
                    end

                    if brotherCount >= 3 then
                        bot._priestBrotherhoodStrongFired = true
                        if chatter and chatter.On then
                            chatter:On("PriestBrotherhoodStrong", {}, true)
                        end
                    end
                end

                return
            end

            -- Detective/Detective-like shot outcome.
            if ROLE_DETECTIVE and target.GetBaseRole and target:GetBaseRole() == ROLE_DETECTIVE then
                if st then
                    st._neverTargetEnts = st._neverTargetEnts or {}
                    st._neverTargetEnts[target:EntIndex()] = true
                end

                if chatter and chatter.On then
                    chatter:On("PriestDetectiveShot", { player = target:Nick(), playerEnt = target }, true)
                end
                return
            end

            if ROLE_SNIFFER and target.GetSubRole and target:GetSubRole() == ROLE_SNIFFER then
                if st then
                    st._neverTargetEnts = st._neverTargetEnts or {}
                    st._neverTargetEnts[target:EntIndex()] = true
                end

                if chatter and chatter.On then
                    chatter:On("PriestDetectiveShot", { player = target:Nick(), playerEnt = target }, true)
                end
                return
            end

            -- Special evil kill outcome (infected / necromancer / sidekick).
            if not lib.IsPlayerAlive(target) then
                local subrole = target.GetSubRole and target:GetSubRole() or ROLE_NONE
                local team = target.GetTeam and target:GetTeam() or TEAM_NONE
                local specialEvilKill =
                    (TEAM_INFECTED and team == TEAM_INFECTED) or
                    (ROLE_NECROMANCER and subrole == ROLE_NECROMANCER) or
                    (ROLE_SIDEKICK and subrole == ROLE_SIDEKICK)

                if specialEvilKill and st then
                    st._validatedKillCount = (st._validatedKillCount or 0) + 1
                end

                if specialEvilKill and chatter and chatter.On then
                    chatter:On("PriestEvilKill", { player = target:Nick(), playerEnt = target }, true)
                end
            end
        end)
    end,
    validateExtraFn = function(bot)
        if not TTTBots.Lib.IsTTT2() then return false end
        if not ROLE_PRIEST then return false end
        local maxAllowedSuspicion = GetPhaseSuspicionThreshold(bot)
        if maxAllowedSuspicion == nil then return false end
        return bot:GetSubRole() == ROLE_PRIEST
    end,
})

local PriestConvert = TTTBots.Behaviors.PriestConvert
local STATUS = TTTBots.STATUS
