--- sv_morality_suspicion.lua
--- Witness events, suspicion tracking, and announcement logic.
--- Extracted from sv_morality.lua — all suspicion-related instance methods
--- remain on BotMorality; global hooks and timers live here.

local lib = TTTBots.Lib

---@class CMorality : Component
local BotMorality = TTTBots.Components.Morality

local Arb = TTTBots.Morality  -- arbitration gateway
local PRI = Arb.PRIORITY

-- ===========================================================================
-- Static data tables
-- ===========================================================================

--- A scale of suspicious events to apply to a player's suspicion value. Scale is normally -10 to 10.
BotMorality.SUSPICIONVALUES = {
    -- Killing another player
    Kill = 5,                -- This player killed someone in front of us
    KillTrusted = 10,        -- This player killed a Trusted in front of us
    KillMedic = 15,          -- This player killed a medic in front of us
    KillTraitor = -15,       -- This player killed a traitor in front of us
    Hurt = 3,                -- This player hurt someone in front of us
    HurtMe = 9,              -- This player hurt us
    HurtTrusted = 6,         -- This player hurt a Trusted in front of us
    HurtByTrusted = 2,       -- This player was hurt by a Trusted
    HurtByEvil = -5,         -- This player was hurt by a traitor
    KOSByInnocent = 7,       -- KOS called on this player by innocent
    KOSByTrusted = 15,       -- KOS called on this player by trusted innocent
    KOSByTraitor = -5,       -- KOS called on this player by known traitor
    KOSByOther = 5,          -- KOS called on this player
    AffirmingKOS = -3,       -- KOS called on a player we think is a traitor (rare, but possible)
    TraitorWeapon = 3,       -- This player has a traitor weapon
    NearUnidentified = 2,    -- This player is near an unidentified body and hasn't identified it in more than 5 seconds
    IdentifiedTraitor = -2,  -- This player has identified a traitor's corpse
    IdentifiedInnocent = 0,  -- This player has identified an innocent's corpse
    IdentifiedTrusted = 0,   -- This player has identified a Trusted's corpse
    DefuseC4 = -7,           -- This player is defusing C4
    PlantC4 = 10,            -- This player is throwing down C4
    FollowingMe = 3,         -- This player has been following me for more than 10 seconds
    FollowingMeLong = -6,    -- This player has been following me for more than 40 seconds
    ShotAtMe = 5,            -- This player has been shooting at me
    ShotAt = 3,              -- This player has been shooting at someone
    ShotAtTrusted = 4,       -- This player has been shooting at a Trusted
    ThrowDiscombob = 2,      -- This player has thrown a discombobulator
    ThrowIncin = 5,          -- This player has thrown an incendiary grenade
    ThrowSmoke = 2,          -- This player has thrown a smoke grenade
    PersonalSpace = 2,       -- This player is standing too close to me for too long
}

BotMorality.SuspicionDescriptions = {
    ["10"] = "Definitely evil",
    ["9"] = "Almost certainly evil",
    ["8"] = "Highly likely evil",
    ["7"] = "Very suspicious, likely evil",
    ["6"] = "Very suspicious",
    ["5"] = "Quite suspicious",
    ["4"] = "Suspicious",
    ["3"] = "Somewhat suspicious",
    ["2"] = "A little suspicious",
    ["1"] = "Slightly suspicious",
    ["0"] = "Neutral",
    ["-1"] = "Slightly trustworthy",
    ["-2"] = "Somewhat trustworthy",
    ["-3"] = "Quite trustworthy",
    ["-4"] = "Very trustworthy",
    ["-5"] = "Highly likely to be innocent",
    ["-6"] = "Almost certainly innocent",
    ["-7"] = "Definitely innocent",
    ["-8"] = "Undeniably innocent",
    ["-9"] = "Absolutely innocent",
    ["-10"] = "Unwaveringly innocent",
}

BotMorality.Thresholds = {
    KOS = 7,
    RoleGuess = 6,
    Sus = 3,
    Trust = -3,
    Innocent = -7,
}

-- ===========================================================================
-- Instance methods (operate on BotMorality via self / self.bot)
-- ===========================================================================

--- Increase/decrease the suspicion on the player for the given reason.
---@param target Player
---@param reason string The reason (matching a key in SUSPICIONVALUES)
function BotMorality:ChangeSuspicion(target, reason, mult)
    local roleDisablesSuspicion = not TTTBots.Roles.GetRoleFor(self.bot):GetUsesSuspicion()
    if roleDisablesSuspicion then return end
    if not mult then mult = 1 end
    if target == self.bot then return end
    if TTTBots.Match.RoundActive == false then return end
    local targetIsPolice = TTTBots.Roles.GetRoleFor(target):GetAppearsPolice()

    mult = mult * (hook.Run("TTTBotsModifySuspicion", self.bot, target, reason, mult) or 1)

    local susValue = self.SUSPICIONVALUES[reason] or ErrorNoHaltWithStack("Invalid suspicion reason: " .. reason)
    if targetIsPolice and susValue > 0 then
        mult = mult * 0.3
    end
    -- Apply round-phase suspicion pressure: as fewer players remain unknown, suspicion
    -- events have more weight (reflecting that each unknown is proportionally more suspicious)
    local pressureMult = 1.0
    if susValue > 0 then
        local ra = self.bot:BotRoundAwareness()
        if ra then
            pressureMult = ra:GetSuspicionPressure()
        end
    end
    local increase = math.ceil(susValue * mult * pressureMult)
    local susFinal = ((self:GetSuspicion(target)) + (increase))
    self.suspicions[target] = math.floor(susFinal)

    self:AnnounceIfThreshold(target)
    self:SetAttackIfTargetSus(target)
    self:GuessRole(target)
end

function BotMorality:GetSuspicion(target)
    return self.suspicions[target] or 0
end

--- Mark a player as tested clean by a role tester. Sets suspicion floor to -5.
--- Call this when a player passes a RoleChecker test.
---@param target Player
function BotMorality:SetTestedClean(target)
    if not (IsValid(target) and target:IsPlayer()) then return end
    self.testedClean = self.testedClean or {}
    self.testedClean[target] = true
    -- Immediately reduce suspicion to at most -5
    local cur = self:GetSuspicion(target)
    self.suspicions[target] = math.min(cur, -5)
    -- Add positive evidence entry
    local evidence = self.bot:BotEvidence()
    if evidence then
        evidence:ConfirmInnocent(target, "passed_role_tester")
    end
end

--- Announce the suspicion level of the given player if it is above a certain threshold.
---@param target Player
function BotMorality:AnnounceIfThreshold(target)
    if not (IsValid(target) and target:IsPlayer() and target:Visible(self.bot) and target:GetPos():Distance(self.bot:GetPos()) <= 600) then
        return
    end

    local sus = self:GetSuspicion(target)
    local chatter = self.bot:BotChatter()
    if not chatter or not chatter.On then return end
    local KOSThresh = self.Thresholds.KOS
    local SusThresh = self.Thresholds.Sus
    local TrustThresh = self.Thresholds.Trust
    local InnocentThresh = self.Thresholds.Innocent

    if sus >= KOSThresh then
        chatter:On("CallKOS", { player = target:Nick() })
    elseif sus >= SusThresh then
        chatter:On("DeclareSuspicious", { player = target:Nick() })
    elseif sus <= InnocentThresh then
        chatter:On("DeclareInnocent", { player = target:Nick() })
    elseif sus <= TrustThresh then
        chatter:On("DeclareTrustworthy", { player = target:Nick() })
    end
end

--- Set the bot's attack target to the given player if they seem evil.
function BotMorality:SetAttackIfTargetSus(target)
    if self.bot.attackTarget ~= nil then return end
    local sus = self:GetSuspicion(target)
    if sus >= self.Thresholds.KOS then
        Arb.RequestAttackTarget(self.bot, target, "SUS_THRESHOLD", PRI.SUSPICION_THRESHOLD)
        return true
    end
    return false
end

--- Allow the bot to have a chance of correctly guessing the role of the player if they are suspicious enough
function BotMorality:GuessRole(target)
    local sus = self:GetSuspicion(target)
    local archetype = self.bot:BotPersonality().archetype
    if sus < self.Thresholds.RoleGuess then return end
    if not (IsValid(target) and target:IsPlayer() and target:Visible(self.bot) and target:GetPos():Distance(self.bot:GetPos()) <= 600) then
        return
    end
    local chance = math.random(1, 100)

    if archetype == "Tryhard/Nerd" then
        chance = math.max(chance - 40, 1)
    elseif archetype == "Bad" or archetype == "Dumb" then
        chance = math.min(chance + 40, 100)
    end

    if chance <= 15 then
        self.roleGuesses[target] = TTTBots.Roles.GetRoleFor(target)
        print(self.bot:Nick() .. " has guessed " .. target:Nick() .. "'s role as " .. self.roleGuesses[target]:GetName())
    elseif chance <= 45 then
        self.roleGuesses[target] = TTTBots.Roles.GetRandomRole()
        print(self.bot:Nick() .. " has INCORRECTLY guessed " .. target:Nick() .. "'s role as " .. self.roleGuesses[target]:GetName())
    end
    if self.roleGuesses[target] and self.roleGuesses[target]:GetTeam() ~= TEAM_INNOCENT then
        if math.random(1, 100) > 25 then
            local chatter = self.bot:BotChatter()
            if chatter and chatter.On then
                chatter:On("RoleGuess", { player = target:Nick(), playerEnt = target, role = self.roleGuesses[target]:GetName() })
            end
        end
        if math.random(1, 100) > 25 then
            Arb.RequestAttackTarget(self.bot, target, "SUS_ROLE_GUESS", PRI.SUSPICION_THRESHOLD)
        end
    end
end

--- Returns the evidence-weighted suspicion floor for a player.
--- This prevents suspicion from decaying below what the evidence supports.
---@param target Player
---@return number
function BotMorality:GetEvidenceFloor(target)
    local evidence = self.bot:BotEvidence()
    if not evidence then return 0 end
    return evidence:EvidenceWeight(target)
end

function BotMorality:TickSuspicions()
    local roundStarted = TTTBots.Match.RoundActive
    if not roundStarted then
        self.suspicions = {}
        return
    end

    -- Skip decay for roles that don't use suspicion
    if not TTTBots.Roles.GetRoleFor(self.bot):GetUsesSuspicion() then return end

    -- Trait-modulated decay rate
    local personality = self.bot:BotPersonality()
    local decayRate = 0.998  -- base per-tick decay multiplier (close to 1 = slow decay)
    if personality then
        local traits = personality.traits or {}
        for _, trait in ipairs(traits) do
            if trait == "suspicious" then
                decayRate = math.max(decayRate, 0.9995)  -- suspicious: even slower decay
            elseif trait == "gullible" then
                decayRate = math.min(decayRate, 0.994)   -- gullible: faster decay
            end
        end
    end

    for target, value in pairs(self.suspicions) do
        if not (IsValid(target) and target:IsPlayer()) then
            self.suspicions[target] = nil
            continue
        end

        -- Apply decay only to positive (suspicious) values; trust values decay separately
        local newValue
        if value > 0 then
            newValue = value * decayRate
            -- Snap to zero when negligible
            if newValue < 0.5 then newValue = 0 end
        elseif value < 0 then
            -- Negative (trust) decays back toward 0 slightly faster
            newValue = value * (2 - decayRate)  -- e.g. 0.998 → 1.002 for negative direction
            if newValue > -0.5 then newValue = 0 end
        else
            newValue = 0
        end

        -- Enforce evidence floor: can't decay below the evidence-based score
        local evidenceFloor = self:GetEvidenceFloor(target)
        newValue = math.max(newValue, evidenceFloor)

        -- Enforce tested-clean floor: players tested clean can't go above -5
        local testedClean = self.testedClean and self.testedClean[target]
        if testedClean and newValue > -5 then
            newValue = -5
        end

        self.suspicions[target] = math.floor(newValue)
    end
end

-- ===========================================================================
-- Witness event handlers (instance methods)
-- ===========================================================================

--- Called by OnWitnessHurt, but only if an ally is being attacked.
---@param victim Player
---@param attacker Player
---@param healthRemaining number
---@param damageTaken number
function BotMorality:OnWitnessHurtIfAlly(victim, attacker, healthRemaining, damageTaken)
    if not TTTBots.Roles.IsAllies(victim, attacker) then return end

    if self.bot.attackTarget == nil then
        Arb.RequestAttackTarget(self.bot, attacker, "ALLY_DEFENSE", PRI.SUSPICION_THRESHOLD)
    end
end

function BotMorality:OnKilled(attacker)
    if not (attacker and IsValid(attacker) and attacker:IsPlayer()) or (self.bot:GetTeam() == TEAM_INNOCENT and attacker:GetTeam() == TEAM_INNOCENT) then
        self.bot.grudge = nil
        return
    end

    if self.bot:BotPersonality().archetype == "Hothead" then
        self.bot.grudge = attacker
    end
end

function BotMorality:OnWitnessKill(victim, weapon, attacker)
    if (weapon and IsValid(weapon) and weapon.GetClass and weapon:GetClass() == "ttt_c4") then return end
    if not lib.IsPlayerAlive(self.bot) then return end
    local vicIsTraitor = victim:GetTeam() ~= TEAM_INNOCENT
    local vicIsMedic = victim:GetRoleStringRaw() == "medic"
    local numWitnesses = #lib.GetAllWitnesses(attacker:EyePos(), true)
    local chance = 1 / numWitnesses or 1

    if vicIsTraitor then
        self:ChangeSuspicion(attacker, "KillTraitor")
    elseif TTTBots.Roles.GetRoleFor(victim):GetAppearsPolice() then
        self:ChangeSuspicion(attacker, "KillTrusted")
    elseif vicIsMedic then
        self:ChangeSuspicion(attacker, "KillMedic")
    else
        self:ChangeSuspicion(attacker, "Kill")
    end

    -- Feed evidence log
    local evidence = self.bot:BotEvidence()
    if evidence then
        local weaponName = (weapon and IsValid(weapon) and weapon.GetPrintName) and weapon:GetPrintName() or "unknown weapon"
        local navArea    = navmesh.GetNearestNavArea(attacker:GetPos())
        local location   = (navArea and navArea.GetPlace and navArea:GetPlace() ~= "") and navArea:GetPlace() or "unknown location"
        evidence:AddEvidence({
            type     = "WITNESSED_KILL",
            subject  = attacker,
            victim   = victim,
            detail   = weaponName,
            location = location,
        })
    end

    local chatter = self.bot:BotChatter()
    if not chatter or not chatter.On then return end
    if TTTBots.Roles.IsAllies(self.bot, attacker) and self.bot:GetTeam() ~= TEAM_INNOCENT then return end
    -- Use the richer WitnessCallout event; fall back to Kill for backwards compat
    local weaponName = (weapon and IsValid(weapon) and weapon.GetPrintName) and weapon:GetPrintName() or nil
    local navArea    = navmesh.GetNearestNavArea(attacker:GetPos())
    local location   = (navArea and navArea.GetPlace and navArea:GetPlace() ~= "") and navArea:GetPlace() or nil
    chatter:On("WitnessCallout", {
        victim      = victim:Nick(),
        victimEnt   = victim,
        attacker    = attacker:Nick(),
        attackerEnt = attacker,
        weapon      = weaponName,
        location    = location,
    })
    -- Also fire legacy Kill event so existing locale lines still trigger
    chatter:On("Kill", { victim = victim:Nick(), victimEnt = victim, attacker = attacker:Nick(), attackerEnt = attacker })
end

function BotMorality:OnKOSCalled(caller, target)
    if not lib.IsPlayerAlive(self.bot) then return end
    if not TTTBots.Roles.GetRoleFor(caller):GetUsesSuspicion() then return end

    local callerSus = self:GetSuspicion(caller)
    local callerIsPolice = TTTBots.Roles.GetRoleFor(caller):GetAppearsPolice()
    local targetSus = self:GetSuspicion(target)

    local TRAITOR = self.Thresholds.KOS
    local TRUSTED = self.Thresholds.Trust
    local INNOCENT = self.Thresholds.Innocent

    if targetSus > TRAITOR then
        self:ChangeSuspicion(caller, "AffirmingKOS")
    end
    if callerIsPolice or callerSus < INNOCENT then
        self:ChangeSuspicion(target, "KOSByInnocent")
    elseif callerSus < TRUSTED then
        self:ChangeSuspicion(target, "KOSByTrusted")
    elseif callerSus > TRAITOR then
        self:ChangeSuspicion(target, "KOSByTraitor")
    else
        self:ChangeSuspicion(target, "KOSByOther")
    end

    -- Feed evidence log: hearing a KOS gives the bot reason to suspect the target
    local evidence = self.bot:BotEvidence()
    if evidence then
        evidence:AddEvidence({
            type    = "KOS_CALLED_BY",
            subject = target,
            detail  = caller:Nick(),
        })
    end
end

--- When we witness someone getting hurt.
function BotMorality:OnWitnessHurt(victim, attacker, healthRemaining, damageTaken)
    if damageTaken < 1 then return end
    self:OnWitnessHurtIfAlly(victim, attacker, healthRemaining, damageTaken)
    if attacker == self.bot then
        if victim == self.bot.attackTarget then
            local personality = self.bot:BotPersonality()
            if not personality then return end
            personality:OnPressureEvent("HurtEnemy")
        end
        return
    end
    if self.bot == victim then
        Arb.RequestAttackTarget(self.bot, attacker, "SELF_DEFENSE", PRI.SELF_DEFENSE)
        local personality = self.bot:BotPersonality()
        if personality then
            personality:OnPressureEvent("Hurt")
        end
    end
    if self.bot == victim or self.bot == attacker and TTTBots.Roles.IsAllies(victim, attacker) then return end
    if TTTBots.Match.IsPlayerDisguised(attacker) then
        if self.bot.attackTarget == nil then
            Arb.RequestAttackTarget(self.bot, attacker, "DISGUISED_ATTACKER", PRI.ROLE_HOSTILITY)
        end
        return
    end

    local attackerSusMod = 1.0
    local victimSusMod = 1.0
    local can_cheat = lib.GetConVarBool("cheat_know_shooter")
    if can_cheat then
        local bad_guy = TTTBots.Match.WhoShotFirst(victim, attacker)
        if bad_guy == victim then
            victimSusMod = 2.0
            attackerSusMod = 0.5
        elseif bad_guy == attacker then
            victimSusMod = 0.5
            attackerSusMod = 2.0
        end
    end

    local impact = (damageTaken / victim:GetMaxHealth()) * 3
    local victimIsPolice = TTTBots.Roles.GetRoleFor(victim):GetAppearsPolice()
    local attackerIsPolice = TTTBots.Roles.GetRoleFor(attacker):GetAppearsPolice()
    local attackerSus = self:GetSuspicion(attacker)
    local victimSus = self:GetSuspicion(victim)
    if victimIsPolice or victimSus < BotMorality.Thresholds.Trust then
        self:ChangeSuspicion(attacker, "HurtTrusted", impact * attackerSusMod)
    elseif attackerIsPolice or attackerSus < BotMorality.Thresholds.Trust then
        self:ChangeSuspicion(victim, "HurtByTrusted", impact * victimSusMod)
    elseif attackerSus > BotMorality.Thresholds.KOS then
        self:ChangeSuspicion(victim, "HurtByEvil", impact * victimSusMod)
    else
        self:ChangeSuspicion(attacker, "Hurt", impact * attackerSusMod)
    end
end

function BotMorality:OnWitnessFireBullets(attacker, data, angleDiff)
    local angleDiffPercent = angleDiff / 30
    local sus = -1 * (1 - angleDiffPercent) / 4
    if sus < 1 then sus = 0.1 end

    if sus > 3 then
        local personality = self.bot:BotPersonality()
        if personality then
            personality:OnPressureEvent("BulletClose")
        end
    end
    self:ChangeSuspicion(attacker, "ShotAt", sus)
end

-- ===========================================================================
-- Global hooks — witness event dispatchers
-- ===========================================================================

hook.Add("PlayerDeath", "TTTBots.Components.Morality.PlayerDeath", function(victim, weapon, attacker)
    if not (IsValid(victim) and victim:IsPlayer()) then return end
    if not (IsValid(attacker) and attacker:IsPlayer()) then return end
    local timestamp = CurTime()
    if attacker:IsBot() then
        attacker.lastKillTime = timestamp
        -- Track self-defense kills for innocent-side bots so InvestigateCorpse can
        -- confirm the body without the normal post-kill suppression delay.
        if attacker:GetTeam() == TEAM_INNOCENT then
            attacker.selfDefenseKills = attacker.selfDefenseKills or {}
            attacker.selfDefenseKills[victim] = timestamp
        end
    end
    if victim:IsBot() then
        victim.components.morality:OnKilled(attacker)
    end
    if not victim:Visible(attacker) then return end
    if victim:GetTeam() == TEAM_INNOCENT then
        local ttt_bot_cheat_redhanded_time = lib.GetConVarInt("cheat_redhanded_time")
        attacker.redHandedTime = timestamp + ttt_bot_cheat_redhanded_time
    end
    local witnesses = lib.GetAllWitnesses(attacker:EyePos(), true)
    table.insert(witnesses, victim)

    for i, witness in pairs(witnesses) do
        if witness and witness.components then
            witness.components.morality:OnWitnessKill(victim, weapon, attacker)
        end
    end
end)

hook.Add("EntityFireBullets", "TTTBots.Components.Morality.FireBullets", function(entity, data)
    if not (IsValid(entity) and entity:IsPlayer()) then return end
    local witnesses = lib.GetAllWitnesses(entity:EyePos(), true)

    local lookAngle = entity:EyeAngles()

    for i, witness in pairs(witnesses) do
        if not witness:IsBot() then continue end
        ---@cast witness Bot
        local morality = witness:BotMorality()

        local witnessAngle = witness:EyeAngles()
        local angleDiff = lookAngle.y - witnessAngle.y
        angleDiff = ((angleDiff + 180) % 360) - 180
        angleDiff = math.abs(angleDiff)

        morality:OnWitnessFireBullets(entity, data, angleDiff)
        hook.Run("TTTBotsOnWitnessFireBullets", witness, entity, data, angleDiff)
    end
end)

hook.Add("PlayerHurt", "TTTBots.Components.Morality.PlayerHurt", function(victim, attacker, healthRemaining, damageTaken)
    if not (IsValid(victim) and victim:IsPlayer()) then return end
    if not (IsValid(attacker) and attacker:IsPlayer()) then return end
    if not victim:Visible(attacker) then return end
    local witnesses = lib.GetAllWitnesses(attacker:EyePos(), true)
    table.insert(witnesses, victim)

    -- If NPC is the attacker, attack them directly.
    if attacker:IsNPC() and not attacker:IsBot() then
        if victim:IsBot() then
            Arb.RequestAttackTarget(victim, attacker, "NPC_ATTACKER", PRI.SELF_DEFENSE)
        end
        return
    end

    for i, witness in pairs(witnesses) do
        if witness and witness.components then
            witness.components.morality:OnWitnessHurt(victim, attacker, healthRemaining, damageTaken)
            hook.Run("TTTBotsOnWitnessHurt", witness, victim, attacker, healthRemaining, damageTaken)
        end
    end
end)

hook.Add("TTTBodyFound", "TTTBots.Components.Morality.BodyFound", function(ply, deadply, rag)
    if not (IsValid(ply) and ply:IsPlayer()) then return end
    if not (IsValid(deadply) and deadply:IsPlayer()) then return end
    local corpseIsTraitor = deadply:GetTeam() ~= TEAM_INNOCENT
    local corpseIsPolice = deadply:GetRoleStringRaw() == "detective"

    for i, bot in pairs(lib.GetAliveBots()) do
        local morality = bot.components and bot.components.morality
        if not morality or not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then continue end
        if corpseIsTraitor then
            morality:ChangeSuspicion(ply, "IdentifiedTraitor")
        elseif corpseIsPolice then
            morality:ChangeSuspicion(ply, "IdentifiedTrusted")
        else
            morality:ChangeSuspicion(ply, "IdentifiedInnocent")
        end
    end
end)

-- ===========================================================================
-- Corpse proximity tracking
-- ===========================================================================

function BotMorality.IsPlayerNearUnfoundCorpse(ply, corpses)
    local IsIdentified = CORPSE.GetFound
    for _, corpse in pairs(corpses) do
        if not IsValid(corpse) then continue end
        if IsIdentified(corpse) then continue end
        local dist = ply:GetPos():Distance(corpse:GetPos())
        local THRESHOLD = 500
        if ply:Visible(corpse) and (dist < THRESHOLD) then
            return true
        end
    end
    return false
end

local playersNearBodies = {}
timer.Create("TTTBots.Components.Morality.PlayerCorpseTimer", 1, 0, function()
    if TTTBots.Match.RoundActive == false then return end
    local alivePlayers = TTTBots.Match.AlivePlayers
    local corpses = TTTBots.Match.Corpses

    for i, ply in pairs(alivePlayers) do
        if not IsValid(ply) then continue end
        local isNearCorpse = BotMorality.IsPlayerNearUnfoundCorpse(ply, corpses)
        if isNearCorpse then
            local prev = playersNearBodies[ply] or 0
            playersNearBodies[ply] = prev + 1
            -- After 3 continuous seconds near a body, apply suspicion + evidence
            if playersNearBodies[ply] == 3 then
                for _, bot in pairs(lib.GetAliveBots()) do
                    if not (bot.components and bot.components.morality) then continue end
                    if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then continue end
                    -- Only apply if the bot can see the player near the body
                    if not bot:Visible(ply) then continue end
                    bot.components.morality:ChangeSuspicion(ply, "NearUnidentified")
                    local evidence = bot:BotEvidence()
                    if evidence then
                        evidence:AddEvidence({
                            type    = "NEAR_BODY",
                            subject = ply,
                            detail  = "near unidentified corpse for 3+ seconds",
                        })
                    end
                end
            end
        else
            playersNearBodies[ply] = math.max((playersNearBodies[ply] or 0) - 1, 0)
        end
    end
end)

-- ===========================================================================
-- Disguised player detection
-- ===========================================================================

timer.Create("TTTBots.Components.Morality.DisguisedPlayerDetection", 1, 0, function()
    if not TTTBots.Match.RoundActive then return end
    local alivePlayers = TTTBots.Match.AlivePlayers
    for i, ply in pairs(alivePlayers) do
        local isDisguised = TTTBots.Match.IsPlayerDisguised(ply)

        if isDisguised then
            local witnessBots = lib.GetAllWitnesses(ply:EyePos(), true)
            for i, bot in pairs(witnessBots) do
                ---@cast bot Bot
                if not IsValid(bot) then continue end
                if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then continue end
                local chatter = bot:BotChatter()
                if not chatter or not chatter.On then continue end
                if bot.attackTarget == nil then
                    Arb.RequestAttackTarget(bot, ply, "DISGUISED_PLAYER", PRI.ROLE_HOSTILITY)
                end
                chatter:On("DisguisedPlayer")
            end
        end
    end
end)

-- When a player passes a role tester, mark them as tested clean in nearby bots' morality
hook.Add("TTTBots.UseRoleChecker.Result", "TTTBots.Morality.TestedClean", function(user, target, result)
    -- result is expected to be "innocent" or "traitor" or similar
    if not (IsValid(user) and IsValid(target)) then return end
    if result ~= "innocent" then return end
    -- Inform nearby bots
    local witnesses = lib.GetAllWitnessesBasic(user:EyePos(), TTTBots.Match.AlivePlayers, user)
    for _, bot in ipairs(witnesses) do
        if not (bot:IsBot() and bot.components and bot.components.morality) then continue end
        bot.components.morality:SetTestedClean(target)
    end
end)
