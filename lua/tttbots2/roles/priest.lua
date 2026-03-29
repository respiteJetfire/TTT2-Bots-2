if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_PRIEST then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local lib = TTTBots.Lib

local bTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _bh.PriestConvert,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Minge,
    _prior.Investigate,
    _bh.Decrowd,
    _prior.Patrol
}

local roleDescription = "You are the Priest, a hidden innocent role. "
    .. "You have a Holy Deagle that can add likely-innocent players to your Brotherhood. "
    .. "Brotherhood members can identify each other and coordinate more safely. "
    .. "Be careful: shooting a Detective wastes your shot and damages them, "
    .. "and shooting many evil roles with the Holy Deagle can get you killed. "
    .. "Use the deagle on low-suspicion targets and build your Brotherhood early."

local priest = TTTBots.RoleBuilder.InnocentLike("priest")
priest:SetCanHaveRadar(false)
priest:SetAutoSwitch(true)
priest:SetAppearsPolice(false)
priest:SetAlliedTeams({ [TEAM_INNOCENT] = true })
priest:SetRoleDescription(roleDescription)
priest:SetBTree(bTree)
TTTBots.Roles.RegisterRole(priest)

if SERVER then
    local function IsBrother(ply)
        if not (IsValid(ply) and ply:IsPlayer()) then return false end
        if not (PRIEST_DATA and PRIEST_DATA.IsBrother) then return false end
        return PRIEST_DATA:IsBrother(ply) == true
    end

    ---@param bot Bot
    ---@param brother Player
    ---@param reason string
    local function MarkBrotherTrusted(bot, brother, reason)
        if not (IsValid(bot) and bot:IsBot()) then return end
        if not (IsValid(brother) and brother:IsPlayer()) then return end

        local morality = bot:BotMorality()
        if morality and morality.GetSuspicion then
            local cur = morality:GetSuspicion(brother)
            morality.suspicions[brother] = math.min(cur, 0)
        end

        local evidence = bot:BotEvidence()
        if evidence and evidence.ConfirmInnocent then
            evidence:ConfirmInnocent(brother, reason or "priest_brotherhood")
        end
    end

    --- Sync all current brotherhood members into the trust/morality systems
    --- for every alive bot that is itself in the brotherhood.
    ---@param reason string
    local function SyncBrotherhoodForBotBrothers(reason)
        if not (PRIEST_DATA and PRIEST_DATA.IsBrother and TTTBots.Match.RoundActive) then return end

        local brothers = {}
        for _, ply in ipairs(TTTBots.Match.AlivePlayers or {}) do
            if IsBrother(ply) then
                table.insert(brothers, ply)
            end
        end

        if #brothers == 0 then return end

        for _, bot in ipairs(TTTBots.Bots or {}) do
            if not (IsValid(bot) and bot:IsBot() and lib.IsPlayerAlive(bot)) then continue end
            if not IsBrother(bot) then continue end

            for _, brother in ipairs(brothers) do
                MarkBrotherTrusted(bot, brother, reason)
            end
        end
    end

    ---@return table<Player>
    local function GetAliveBrothers()
        local brothers = {}
        for _, ply in ipairs(TTTBots.Match.AlivePlayers or {}) do
            if IsBrother(ply) then
                table.insert(brothers, ply)
            end
        end
        return brothers
    end

    ---@param ply Player
    ---@return boolean
    local function IsCascadeThreat(ply)
        if not (IsValid(ply) and ply:IsPlayer() and lib.IsPlayerAlive(ply)) then return false end

        local subrole = ply.GetSubRole and ply:GetSubRole() or ROLE_NONE
        local team = ply.GetTeam and ply:GetTeam() or TEAM_NONE

        if TEAM_INFECTED and team == TEAM_INFECTED then return true end
        if ROLE_NECROMANCER and subrole == ROLE_NECROMANCER then return true end
        if ROLE_JACKAL and subrole == ROLE_JACKAL then return true end

        return false
    end

    --- Share high-confidence suspicion and evidence among bot brothers.
    local function ShareBrotherhoodIntel()
        if not TTTBots.Match.RoundActive then return end

        local botBrothers = {}
        for _, bot in ipairs(TTTBots.Bots or {}) do
            if not (IsValid(bot) and bot:IsBot() and lib.IsPlayerAlive(bot)) then continue end
            if not IsBrother(bot) then continue end
            table.insert(botBrothers, bot)
        end

        if #botBrothers < 2 then return end

        local alive = TTTBots.Match.AlivePlayers or {}

        for i = 1, #botBrothers do
            local botA = botBrothers[i]
            local evA = botA:BotEvidence()
            local morA = botA:BotMorality()

            for j = i + 1, #botBrothers do
                local botB = botBrothers[j]
                local evB = botB:BotEvidence()
                local morB = botB:BotMorality()

                if evA and evA.ShareEvidence then evA:ShareEvidence(botB) end
                if evB and evB.ShareEvidence then evB:ShareEvidence(botA) end

                if morA and morB and morA.GetSuspicion and morB.GetSuspicion then
                    for _, suspect in ipairs(alive) do
                        if not (IsValid(suspect) and lib.IsPlayerAlive(suspect)) then continue end
                        if suspect == botA or suspect == botB then continue end
                        if IsBrother(suspect) then continue end

                        local susA = morA:GetSuspicion(suspect)
                        local susB = morB:GetSuspicion(suspect)
                        local shared = math.max(susA, susB)

                        -- Only share strong suspicions to avoid noisy echoing.
                        if shared >= 6 then
                            morA.suspicions[suspect] = math.max(susA, shared - 1)
                            morB.suspicions[suspect] = math.max(susB, shared - 1)
                        end
                    end
                end
            end
        end
    end

    --- Move brotherhood bots closer together by steering InnocentCoordinator
    --- toward the brotherhood centroid when no urgent perimeter is active.
    local function PushBrotherhoodCoordination()
        if not (TTTBots.Match.RoundActive and TTTBots.InnocentCoordinator) then return end

        local brothers = GetAliveBrothers()
        if #brothers < 2 then return end

        local sum = Vector(0, 0, 0)
        for _, brother in ipairs(brothers) do
            sum = sum + brother:GetPos()
        end
        local center = sum / #brothers

        local ic = TTTBots.InnocentCoordinator
        local now = CurTime()

        -- Don't stomp over a very fresh investigation perimeter.
        if ic.PerimeterActivatedAt and (now - ic.PerimeterActivatedAt) < 5 then return end

        ic.PerimeterTarget = center
        ic.PerimeterActivatedAt = now
        ic.SelectedStrategy = nil
    end

    --- Cascade awareness: if a brother sees known cascade-converter threats,
    --- mark local danger and increase suspicion pressure on that threat.
    local function ApplyCascadeAwareness()
        if not TTTBots.Match.RoundActive then return end

        local brothers = GetAliveBrothers()
        if #brothers == 0 then return end

        for _, bot in ipairs(TTTBots.Bots or {}) do
            if not (IsValid(bot) and bot:IsBot() and lib.IsPlayerAlive(bot)) then continue end
            if not IsBrother(bot) then continue end

            local memory = bot:BotMemory()
            local morality = bot:BotMorality()

            for _, ply in ipairs(TTTBots.Match.AlivePlayers or {}) do
                if ply == bot then continue end
                if IsBrother(ply) then continue end
                if not IsCascadeThreat(ply) then continue end
                if not bot:Visible(ply) then continue end

                if memory and memory.AddDangerZone then
                    memory:AddDangerZone(ply:GetPos(), 450, "priest_cascade_threat", CurTime() + 10)
                end

                if morality and morality.ChangeSuspicion then
                    morality:ChangeSuspicion(ply, "NearUnidentified", 1.2)
                end
            end
        end
    end

    -- Wrap PRIEST_DATA:AddToBrotherhood so every successful brother addition
    -- immediately updates bot trust/suspicion state.
    local function InstallBrotherhoodAddHook()
        if not (PRIEST_DATA and PRIEST_DATA.AddToBrotherhood) then return false end
        if PRIEST_DATA._tttbotsWrappedAddToBrotherhood then return true end

        local originalAdd = PRIEST_DATA.AddToBrotherhood
        PRIEST_DATA.AddToBrotherhood = function(self, attacker, ply, ...)
            local ret = originalAdd(self, attacker, ply, ...)

            timer.Simple(0, function()
                if not TTTBots.Match.RoundActive then return end
                SyncBrotherhoodForBotBrothers("priest_brotherhood")
            end)

            return ret
        end

        PRIEST_DATA._tttbotsWrappedAddToBrotherhood = true
        return true
    end

    timer.Create("TTTBots.Priest.InstallBrotherhoodHook", 1, 0, function()
        if InstallBrotherhoodAddHook() then
            timer.Remove("TTTBots.Priest.InstallBrotherhoodHook")
        end
    end)

    hook.Add("TTTBeginRound", "TTTBots.Priest.SyncBrotherhood.BeginRound", function()
        timer.Simple(0.25, function()
            SyncBrotherhoodForBotBrothers("priest_brotherhood_roundstart")
        end)
    end)

    timer.Create("TTTBots.Priest.BrotherhoodCoordination", 4, 0, function()
        if not TTTBots.Match.RoundActive then return end

        SyncBrotherhoodForBotBrothers("priest_brotherhood_tick")
        ShareBrotherhoodIntel()
        ApplyCascadeAwareness()
        PushBrotherhoodCoordination()
    end)

    -- When a brother dies: raise suspicion on nearby non-brothers and
    -- trigger body-recovery style investigation for innocent coordinator.
    hook.Add("PlayerDeath", "TTTBots.Priest.BrotherDeathInvestigation", function(victim, weapon, attacker)
        if not TTTBots.Match.RoundActive then return end
        if not (IsValid(victim) and victim:IsPlayer()) then return end
        if not IsBrother(victim) then return end

        local deathPos = victim:GetPos()
        local nearby = ents.FindInSphere(deathPos, 700)

        for _, bot in ipairs(TTTBots.Bots or {}) do
            if not (IsValid(bot) and bot:IsBot() and lib.IsPlayerAlive(bot)) then continue end
            if not IsBrother(bot) then continue end

            local memory = bot:BotMemory()
            if memory then
                memory:AddDangerZone(deathPos, 600, "brotherhood_death", CurTime() + 120)
                if memory.AddWitnessEvent then
                    memory:AddWitnessEvent("brotherhood_death", string.format("Brother %s died", victim:Nick()))
                end
            end

            local morality = bot:BotMorality()
            if morality and morality.ChangeSuspicion then
                for _, ent in ipairs(nearby) do
                    if not (IsValid(ent) and ent:IsPlayer() and lib.IsPlayerAlive(ent)) then continue end
                    if ent == bot or ent == victim then continue end
                    if IsBrother(ent) then continue end

                    -- Nearby non-brothers around a brother's death become suspect.
                    morality:ChangeSuspicion(ent, "NearUnidentified", 1.5)
                end

                if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim and attacker ~= bot then
                    if not IsBrother(attacker) then
                        morality:ChangeSuspicion(attacker, "Kill", 1.25)
                    end
                end
            end
        end

        -- Reuse InnocentCoordinator's body-recovery strategy to pull innocent-side
        -- bots toward the death location for rapid investigation.
        if TTTBots.InnocentCoordinator then
            TTTBots.InnocentCoordinator.PerimeterTarget = deathPos
            TTTBots.InnocentCoordinator.PerimeterActivatedAt = CurTime()
            TTTBots.InnocentCoordinator.SelectedStrategy = nil
        end
    end)
end

return true
