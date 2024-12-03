--[[
    This component defines the morality of the agent. It is primarily responsible for determining who to shoot.
    It also tells traitors who to kill.
]]
---@class CMorality : Component
TTTBots.Components.Morality = TTTBots.Components.Morality or {}

local lib = TTTBots.Lib
---@class CMorality : Component
local BotMorality = TTTBots.Components.Morality

--- A scale of suspicious events to apply to a player's suspicion value. Scale is normally -10 to 10.
BotMorality.SUSPICIONVALUES = {
    -- Killing another player
    Kill = 5,                -- This player killed someone in front of us
    KillTrusted = 10,        -- This player killed a Trusted in front of us
    KillMedic = 15,           -- This player killed a medic in front of us
    KillTraitor = -15,       -- This player killed a traitor in front of us
    Hurt = 3,                -- This player hurt someone in front of us
    HurtMe = 9,             -- This player hurt us
    HurtTrusted = 6,        -- This player hurt a Trusted in front of us
    HurtByTrusted = 2,       -- This player was hurt by a Trusted
    HurtByEvil = -5,         -- This player was hurt by a traitor
    KOSByInnocent = 7,       -- KOS called on this player by innocent
    KOSByTrusted = 15,       -- KOS called on this player by trusted innocent
    KOSByTraitor = -5,       -- KOS called on this player by known traitor
    KOSByOther = 5,          -- KOS called on this player
    AffirmingKOS = -3,       -- KOS called on a player we think is a traitor (rare, but possible)
    TraitorWeapon = 3,      -- This player has a traitor weapon
    NearUnidentified = 2,    -- This player is near an unidentified body and hasn't identified it in more than 5 seconds
    IdentifiedTraitor = -2,  -- This player has identified a traitor's corpse
    IdentifiedInnocent = 0, -- This player has identified an innocent's corpse
    IdentifiedTrusted = 0,  -- This player has identified a Trusted's corpse
    DefuseC4 = -7,           -- This player is defusing C4
    PlantC4 = 10,            -- This player is throwing down C4
    FollowingMe = 3,         -- This player has been following me for more than 10 seconds
    FollowingMeLong = -6,   -- This player has been following me for more than 40 seconds
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
    ["8"] = "Highly likely evil", -- Declare them as evil
    ["7"] = "Very suspicious, likely evil",
    ["6"] = "Very suspicious",
    ["5"] = "Quite suspicious",
    ["4"] = "Suspicious", -- Declare them as suspicious
    ["3"] = "Somewhat suspicious",
    ["2"] = "A little suspicious",
    ["1"] = "Slightly suspicious",
    ["0"] = "Neutral",
    ["-1"] = "Slightly trustworthy",
    ["-2"] = "Somewhat trustworthy",
    ["-3"] = "Quite trustworthy",
    ["-4"] = "Very trustworthy", -- Declare them as trustworthy
    ["-5"] = "Highly likely to be innocent",
    ["-6"] = "Almost certainly innocent",
    ["-7"] = "Definitely innocent",
    ["-8"] = "Undeniably innocent", -- Declare them as innocent
    ["-9"] = "Absolutely innocent",
    ["-10"] = "Unwaveringly innocent",
}

BotMorality.Thresholds = {
    KOS = 7,
    Sus = 3,
    Trust = -3,
    Innocent = -7,
}

function BotMorality:New(bot)
    local newMorality = {}
    setmetatable(newMorality, {
        __index = function(t, k) return BotMorality[k] end,
    })
    newMorality:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        print("Initialized Morality for bot " .. bot:Nick())
    end

    return newMorality
end

function BotMorality:Initialize(bot)
    -- print("Initializing")
    bot.components = bot.components or {}
    bot.components.Morality = self

    self.componentID = string.format("Morality (%s)", lib.GenerateID()) -- Component ID, used for debugging

    self.tick = 0                                                       -- Tick counter
    self.bot = bot ---@type Bot
    self.suspicions = {}                                                -- A table of suspicions for each player
end

--- Increase/decrease the suspicion on the player for the given reason.
---@param target Player
---@param reason string The reason (matching a key in SUSPICIONVALUES)
function BotMorality:ChangeSuspicion(target, reason, mult)
    local roleDisablesSuspicion = not TTTBots.Roles.GetRoleFor(self.bot):GetUsesSuspicion()
    if roleDisablesSuspicion then return end
    if not mult then mult = 1 end
    if target == self.bot then return end                 -- Don't change suspicion on ourselves
    if TTTBots.Match.RoundActive == false then return end -- Don't change suspicion if the round isn't active, duh
    local targetIsPolice = TTTBots.Roles.GetRoleFor(target):GetAppearsPolice()
    
    mult = mult * (hook.Run("TTTBotsModifySuspicion", self.bot, target, reason, mult) or 1)

    local susValue = self.SUSPICIONVALUES[reason] or ErrorNoHaltWithStack("Invalid suspicion reason: " .. reason)
    if targetIsPolice and susValue > 0 then
        mult = mult * 0.3 -- Police are much less suspicious
    end
    local increase = math.ceil(susValue * mult)
    local susFinal = ((self:GetSuspicion(target)) + (increase))
    self.suspicions[target] = math.floor(susFinal)

    self:AnnounceIfThreshold(target)
    self:SetAttackIfTargetSus(target)

    -- print(string.format("%s's suspicion on %s has changed by %d", self.bot:Nick(), target:Nick(), increase))
end

function BotMorality:GetSuspicion(target)
    return self.suspicions[target] or 0
end

--- Announce the suspicion level of the given player if it is above a certain threshold.
---@param target Player
function BotMorality:AnnounceIfThreshold(target)
    local sus = self:GetSuspicion(target)
    local chatter = self.bot:BotChatter()
    if not chatter then return end
    local KOSThresh = self.Thresholds.KOS
    local SusThresh = self.Thresholds.Sus
    local TrustThresh = self.Thresholds.Trust
    local InnocentThresh = self.Thresholds.Innocent

    if sus >= KOSThresh then
        chatter:On("CallKOS", { player = target:Nick(), playerEnt = target })
        -- self.bot:Say("I think " .. target:Nick() .. " is evil!")
    elseif sus >= SusThresh then
        chatter:On("DeclareSuspicious", { player = target:Nick(), playerEnt = target })
        -- self.bot:Say("I think " .. target:Nick() .. " is suspicious!")
    elseif sus <= InnocentThresh then
        chatter:On("DeclareInnocent", { player = target:Nick(), playerEnt = target })
        -- self.bot:Say("I think " .. target:Nick() .. " is innocent!")
    elseif sus <= TrustThresh then
        chatter:On("DeclareTrustworthy", { player = target:Nick(), playerEnt = target })
        -- self.bot:Say("I think " .. target:Nick() .. " is trustworthy!")
    end
end

--- Set the bot's attack target to the given player if they seem evil.
function BotMorality:SetAttackIfTargetSus(target)
    if self.bot.attackTarget ~= nil then return end
    local sus = self:GetSuspicion(target)
    if sus >= self.Thresholds.KOS then
        self.bot:SetAttackTarget(target)
        return true
    end
    return false
end

function BotMorality:TickSuspicions()
    local roundStarted = TTTBots.Match.RoundActive
    if not roundStarted then
        self.suspicions = {}
        return
    end
end

--- Returns a random victim player, weighted off of each player's traits.
---@param playerlist table<Player>
---@return Player
function BotMorality:GetRandomVictimFrom(playerlist)
    local tbl = {}

    for i, player in pairs(playerlist) do
        if player:IsBot() then
            local victim = player:GetTraitMult("victim")
            table.insert(tbl, lib.SetWeight(player, victim))
        else
            table.insert(tbl, lib.SetWeight(player, 1))
        end
    end

    return lib.RandomWeighted(tbl)
end

--- Makes it so that traitor bots will attack random players nearby.
function BotMorality:SetRandomNearbyTarget()
    if not (self.tick % TTTBots.Tickrate == 0) then return end -- Run only once every second
    local roundStarted = TTTBots.Match.RoundActive
    local targetsRandoms = TTTBots.Roles.GetRoleFor(self.bot):GetStartsFights()
    if not (roundStarted and targetsRandoms) then return end
    if self.bot.attackTarget ~= nil then return end
    local delay = lib.GetConVarFloat("attack_delay")
    if TTTBots.Match.Time() <= delay then return end -- Don't attack randomly until the initial delay is over

    local aggression = math.max((self.bot:GetTraitMult("aggression")) * (self.bot:BotPersonality().rage / 100), 0.3)
    local time_modifier = TTTBots.Match.SecondsPassed / 30 -- Increase chance to attack over time.

    local maxTargets = math.max(2, math.ceil(aggression * 2 * time_modifier))
    local targets = lib.GetAllVisible(self.bot:EyePos(), true, self.bot)
    if (#targets > maxTargets) or (#targets == 0) then return end -- Don't attack if there are too many targets

    local base_chance = 4.5                                       -- X% chance to attack per second
    local chanceAttackPerSec = (
        base_chance
        * aggression
        * (maxTargets / #targets)
        * time_modifier
        * (#targets == 1 and 5 or 1)
    )
    if lib.TestPercent(chanceAttackPerSec) then
        local target = BotMorality:GetRandomVictimFrom(targets)
        self.bot:SetAttackTarget(target)
    end
end

function BotMorality:TickIfLastAlive()
    if not TTTBots.Match.RoundActive then return end
    local plys = self.bot.components.memory:GetActualAlivePlayers()
    if #plys > 2 then return end
    local otherPlayer = nil
    for i, ply in pairs(plys) do
        if ply ~= self.bot then
            otherPlayer = ply
            break
        end
    end

    local isCloaked = TTTBots.Match.IsPlayerCloaked(otherPlayer)
    if isCloaked then return end

    self.bot:SetAttackTarget(otherPlayer)
end

function BotMorality:Think()
    self.tick = (self.bot.tick or 0)
    if not lib.IsPlayerAlive(self.bot) then return end
    self:TickSuspicions()
    self:SetRandomNearbyTarget()
    self:TickIfLastAlive()
end

---Called by OnWitnessHurt, but only if we (the owning bot) is a traitor.
---@param victim Player
---@param attacker Player
---@param healthRemaining number
---@param damageTaken number
---@return nil
function BotMorality:OnWitnessHurtIfAlly(victim, attacker, healthRemaining, damageTaken)
    if not TTTBots.Roles.IsAllies(victim, attacker) then return end

    if self.bot.attackTarget == nil then
        self.bot:SetAttackTarget(attacker)
    end
end

function BotMorality:OnKilled(attacker)
    if not (attacker and IsValid(attacker) and attacker:IsPlayer()) or (self.bot:GetTeam() == TEAM_INNOCENT and attacker:GetTeam() == TEAM_INNOCENT) then
        self.bot.grudge = nil
        return
    end
    
    if self.bot:BotPersonality().archetype == "Hothead" then
        self.bot.grudge = attacker -- Set grudge to the attacker
    end
end

function BotMorality:OnWitnessKill(victim, weapon, attacker)
    if (weapon and IsValid(weapon) and weapon.GetClass and weapon:GetClass() == "ttt_c4") then return end -- We don't know who killed who with C4, so we can't build sus on it.
    -- For this function, we will allow the bots to technically cheat and know what role the victim was. They will not know what role the attacker is.
    -- This allows us to save time and resources in optimization and let players have a more fun experience, despite technically being a cheat.
    if not lib.IsPlayerAlive(self.bot) then return end
    local vicIsTraitor = victim:GetTeam() ~= TEAM_INNOCENT
    local vicIsMedic = victim:GetRoleStringRaw() == "medic"
    local numWitnesses = #lib.GetAllWitnesses(attacker:EyePos(), true)
    local chance = 1/numWitnesses or 1

    -- change suspicion on the attacker by KillTraitor, KillTrusted, or Kill. Depending on role.
    if vicIsTraitor then
        self:ChangeSuspicion(attacker, "KillTraitor")
    elseif TTTBots.Roles.GetRoleFor(victim):GetAppearsPolice() then
        self:ChangeSuspicion(attacker, "KillTrusted")
    elseif vicIsMedic then
        self:ChangeSuspicion(attacker, "KillMedic")
    else
        self:ChangeSuspicion(attacker, "Kill")
    end

    --- enable chatter for the bot to report the killer and victim
    local chatter = self.bot:BotChatter()
    if not chatter then return end
    -- print("Killed", victim:Nick(), attacker:Nick())
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
    if callerIsPolice or callerSus < INNOCENT then -- if we trust the caller or they are a detective, then:
        self:ChangeSuspicion(target, "KOSByInnocent")
    elseif callerSus < TRUSTED then -- if we trust the caller or they are a detective, then:
        self:ChangeSuspicion(target, "KOSByTrusted")
    elseif callerSus > TRAITOR then               -- if we think the caller is a traitor, then:
        self:ChangeSuspicion(target, "KOSByTraitor")
    else                                          -- if we don't know the caller, then:
        self:ChangeSuspicion(target, "KOSByOther")
    end
end

hook.Add("PlayerDeath", "TTTBots.Components.Morality.PlayerDeath", function(victim, weapon, attacker)
    if not (IsValid(victim) and victim:IsPlayer()) then return end
    if not (IsValid(attacker) and attacker:IsPlayer()) then return end
    local timestamp = CurTime()
    if attacker:IsBot() then
        attacker.lastKillTime = timestamp
    end
    if victim:IsBot() then
        victim.components.morality:OnKilled(attacker)
    end
    if not victim:Visible(attacker) then return end -- This must be an indirect attack, like C4 or fire.
    if victim:GetTeam() == TEAM_INNOCENT then       -- This is technically a cheat, but it's a necessary one.
        local ttt_bot_cheat_redhanded_time = lib.GetConVarInt("cheat_redhanded_time")
        attacker.redHandedTime = timestamp +
            ttt_bot_cheat_redhanded_time -- Only assign red handed time if it was a direct attack
    end
    local witnesses = lib.GetAllWitnesses(attacker:EyePos(), true)
    table.insert(witnesses, victim)

    for i, witness in pairs(witnesses) do
        if witness and witness.components then
            witness.components.morality:OnWitnessKill(victim, weapon, attacker)
        end
    end
end)

--- When we witness someone getting hurt.
function BotMorality:OnWitnessHurt(victim, attacker, healthRemaining, damageTaken)
    if damageTaken < 1 then return end -- Don't care.
    self:OnWitnessHurtIfAlly(victim, attacker, healthRemaining, damageTaken)
    if attacker == self.bot then       -- if we are the attacker, there is no sus to be thrown around.
        if victim == self.bot.attackTarget then
            local personality = self.bot:BotPersonality()
            if not personality then return end
            personality:OnPressureEvent("HurtEnemy")
        end
        return
    end
    if self.bot == victim then -- if we are the victim, just fight back instead of worrying about sus.
        self.bot:SetAttackTarget(attacker)
        local personality = self.bot:BotPersonality()
        if personality then
            personality:OnPressureEvent("Hurt")
        end
    end
    if self.bot == victim or self.bot == attacker and TTTBots.Roles.IsAllies(victim, attacker) then return end -- Don't build sus on ourselves or our allies
    -- If the target is disguised, we don't know who they are, so we can't build sus on them. Instead, ATTACK!
    if TTTBots.Match.IsPlayerDisguised(attacker) then
        if self.bot.attackTarget == nil then
            self.bot:SetAttackTarget(attacker)
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

    local impact = (damageTaken / victim:GetMaxHealth()) * 3 --- Percent of max health lost * 3. 50% health lost =  6 sus
    local victimIsPolice = TTTBots.Roles.GetRoleFor(victim):GetAppearsPolice()
    local attackerIsPolice = TTTBots.Roles.GetRoleFor(attacker):GetAppearsPolice()
    local attackerSus = self:GetSuspicion(attacker)
    local victimSus = self:GetSuspicion(victim)
    if victimIsPolice or victimSus < BotMorality.Thresholds.Trust then
        self:ChangeSuspicion(attacker, "HurtTrusted", impact * attackerSusMod) -- Increase sus on the attacker because we trusted their victim
    elseif attackerIsPolice or attackerSus < BotMorality.Thresholds.Trust then
        self:ChangeSuspicion(victim, "HurtByTrusted", impact * victimSusMod)   -- Increase sus on the victim because we trusted their attacker
    elseif attackerSus > BotMorality.Thresholds.KOS then
        self:ChangeSuspicion(victim, "HurtByEvil", impact * victimSusMod)      -- Decrease the sus on the victim because we know their attacker is evil
    else
        self:ChangeSuspicion(attacker, "Hurt", impact * attackerSusMod)        -- Increase sus on attacker because we don't trust anyone involved
    end

    -- self.bot:Say(string.format("I saw that! Attacker sus is %d; vic is %d", attackerSus, victimSus))
end

function BotMorality:OnWitnessFireBullets(attacker, data, angleDiff)
    local angleDiffPercent = angleDiff / 30
    local sus = -1 * (1 - angleDiffPercent) / 4 -- Sus decreases as angle difference grows
    if sus < 1 then sus = 0.1 end

    -- print(attacker, data, angleDiff, angleDiffPercent, sus)
    if sus > 3 then
        local personality = self.bot:BotPersonality()
        if personality then
            personality:OnPressureEvent("BulletClose")
        end
    end
    self:ChangeSuspicion(attacker, "ShotAt", sus)
end

hook.Add("EntityFireBullets", "TTTBots.Components.Morality.FireBullets", function(entity, data)
    if not (IsValid(entity) and entity:IsPlayer()) then return end
    local witnesses = lib.GetAllWitnesses(entity:EyePos(), true)

    local lookAngle = entity:EyeAngles()

    -- Combined loop for all witnesses
    for i, witness in pairs(witnesses) do
        if not witness:IsBot() then continue end
        ---@cast witness Bot
        local morality = witness:BotMorality()

        -- We calculate the angle difference between the entity and the witness
        local witnessAngle = witness:EyeAngles()
        local angleDiff = lookAngle.y - witnessAngle.y

        -- Adjust angle difference to be between -180 and 180
        angleDiff = ((angleDiff + 180) % 360) - 180
        -- Absolute value to ensure angleDiff is non-negative
        angleDiff = math.abs(angleDiff)

        morality:OnWitnessFireBullets(entity, data, angleDiff)
        hook.Run("TTTBotsOnWitnessFireBullets", witness, entity, data, angleDiff)
    end
end)

hook.Add("PlayerHurt", "TTTBots.Components.Morality.PlayerHurt", function(victim, attacker, healthRemaining, damageTaken)
    if not (IsValid(victim) and victim:IsPlayer()) then return end
    if not (IsValid(attacker) and attacker:IsPlayer()) then return end
    if not victim:Visible(attacker) then return end -- This must be an indirect attack, like C4 or fire.
    -- print(victim, attacker, healthRemaining, damageTaken)
    local witnesses = lib.GetAllWitnesses(attacker:EyePos(), true)
    table.insert(witnesses, victim)

    --- if NPC is the attacker, then we don't care about sus we should just attack them.
    if attacker:IsNPC() and not attacker:IsBot() then
        if victim:isBot() then
            bot:SetAttackTarget(attacker)
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

--- Table of [Player]=number showing seconds near unidentified corpses
--- Does not stack. If a player is near 2 corpses, it will only count as 1. This is to prevent innocents discovering massacres and being killed for it.
local playersNearBodies = {}
timer.Create("TTTBots.Components.Morality.PlayerCorpseTimer", 1, 0, function()
    if TTTBots.Match.RoundActive == false then return end
    local alivePlayers = TTTBots.Match.AlivePlayers
    local corpses = TTTBots.Match.Corpses

    for i, ply in pairs(alivePlayers) do
        if not IsValid(ply) then continue end
        local isNearCorpse = BotMorality.IsPlayerNearUnfoundCorpse(ply, corpses)
        if isNearCorpse then
            playersNearBodies[ply] = (playersNearBodies[ply] or 0) + 1
        else
            playersNearBodies[ply] = math.max((playersNearBodies[ply] or 0) - 1, 0)
        end
    end
end)

-- Disguised player detection
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
                if not chatter then continue end
                -- set attack target if we do not have one already
                bot:SetAttackTarget(bot.attackTarget or ply)
                bot:BotChatter():On("DisguisedPlayer")
            end
        end
    end
end)

---Keep killing any nearby non-allies if we're red-handed.
---@param bot Bot
local function continueMassacre(bot)
    local isRedHanded = bot.redHandedTime and (CurTime() < bot.redHandedTime)
    local isKillerRole = TTTBots.Roles.GetRoleFor(bot):GetStartsFights()

    if isRedHanded and isKillerRole then
        local nonAllies = TTTBots.Roles.GetNonAllies(bot)
        local closest = TTTBots.Lib.GetClosest(nonAllies, bot:GetPos())
        if closest and closest ~= NULL then
            bot:SetAttackTarget(closest)
        end
    end
end

local function preventAttackAlly(bot)
    local attackTarget = bot.attackTarget
    local isAllies = TTTBots.Roles.IsAllies(bot, attackTarget)
    if isAllies then
        bot:SetAttackTarget(nil)
    end
end

local function preventCloaked(bot)
    local attackTarget = bot.attackTarget
    if not IsValid(attackTarget) then return end
    local isCloaked = TTTBots.Match.IsPlayerCloaked(attackTarget)
    if isCloaked then
        -- print("Preventing attack on cloaked player" .. attackTarget:Nick())
        bot:SetAttackTarget(nil)
    end
end

--- Attack any player that is in the GetEnemies for our role
---@param bot Bot
local function attackEnemies(bot)
    local visible = TTTBots.Lib.GetAllWitnessesBasic(bot:EyePos(), TTTBots.Roles.GetNonAllies(bot))
    local isKillerRole = TTTBots.Roles.GetRoleFor(bot):GetStartsFights()
    local kosEnemies = TTTBots.Lib.GetConVarBool("kos_enemies")

    if isKillerRole or kosEnemies then
        local enemies = TTTBots.Roles.GetEnemies(bot)
        local closest = TTTBots.Lib.GetClosest(enemies, bot:GetPos())
        if closest and closest ~= NULL and TTTBots.Lib.IsPlayerAlive(closest) and table.HasValue(visible, closest) then
            -- print("Attacking enemy", closest, "who is", TTTBots.Roles.GetRoleFor(closest):GetName())
            bot:SetAttackTarget(closest)
        end
    end
end


--- Attack any player that is on TEAM_INFECTED and has a zombie player model models/player/corpse1.mdl
---@param bot Bot
local function attackZombies(bot)
    local visible = TTTBots.Lib.GetAllWitnessesBasic(bot:EyePos(), TTTBots.Roles.GetNonAllies(bot))
    local bestDist = math.huge
    if isKillerRole or kosZombies then
        for i, ply in visible do
            --- attack the closest zombie by distance
            if ply:GetModel() == "models/player/corpse1.mdl" then
                local dist = bot:GetPos():Distance(ply:GetPos())
                if dist < bestDist then
                    bestDist = dist
                end
            end
        end
        if ply and ply ~= NULL and TTTBots.Lib.IsPlayerAlive(ply) then
            bot:SetAttackTarget(ply)
        end
    end
end

--- Prevent attacking bots that have the Neutral override parameter set to true
---@param bot Bot
local function preventAttack(bot)
    local attackTarget = bot.attackTarget
    if not IsValid(attackTarget) then return end
    local isNeutral = TTTBots.Roles.GetRoleFor(attackTarget):GetNeutralOverride()
    local bot_zombie_cvar = TTTBots.Lib.GetConVarBool('cheat_bot_zombie')
    if isNeutral or bot_zombie_cvar then
        -- print("Preventing attack on neutral", attackTarget:Nick())
        bot:SetAttackTarget(nil)
    end
end

--- Prevent attacking bots that have used the role checker to determine they are allies
---@param bot Bot
local function preventAttackAllies(bot)
    local attackTarget = bot.attackTarget
    if not IsValid(attackTarget) then return end
    local isAllies = TTTBots.Roles.IsAllies(bot, attackTarget)
    local isChecked = TTTBots.Match.CheckedPlayers[attackTarget] or nil
    if isAllies and isChecked then
        -- print("Preventing attack on ally", attackTarget:Nick())
        bot:SetAttackTarget(nil)
    end
end

--- Attack any player that is in the GetNonAllies for our role
---@param bot Bot
local function attackNonAllies(bot)
    local visible = TTTBots.Lib.GetAllWitnessesBasic(bot:EyePos(), TTTBots.Roles.GetNonAllies(bot))
    local kosnonallies = TTTBots.Lib.GetConVarBool("kos_nonallies")
    local isINFECTEDs = INFECTEDS[bot]
    local kosrole = TTTBots.Roles.GetRoleFor(bot):GetKOSAll()
    -- print("KOSing non-allies", kosnonallies, isINFECTEDS, kosrole)
    -- print(kosnonallies, isINFECTEDS)
    if kosnonallies or isINFECTEDs or kosrole then
        -- print("KOSing non-allies")
        local nonAllies = TTTBots.Roles.GetNonAllies(bot)
        local closest = TTTBots.Lib.GetClosest(nonAllies, bot:GetPos())
        if closest and closest ~= NULL and TTTBots.Lib.IsPlayerAlive(closest) and table.HasValue(visible, closest) then
            bot:SetAttackTarget(closest)
        end
    end
end

--- Attack the closest player that is not an ally that has the SetKOSedByAll role parameter set to true, only if they happen to see them.
---@param bot Bot
local function attackKOSedByAll(bot)
    local visible = TTTBots.Lib.GetAllWitnessesBasic(bot:EyePos(), TTTBots.Roles.GetNonAllies(bot))
    local players = TTTBots.Roles.GetKOSedByAllPlayers()
    local closest = TTTBots.Lib.GetClosest(players, bot:GetPos())
    if closest and closest ~= NULL and closest ~= bot and TTTBots.Lib.IsPlayerAlive(closest) and table.HasValue(visible, closest) then
        -- print("Attacking KOSed player", closest)
        bot:SetAttackTarget(closest)
    end
end

--- Attack any player that has the "unknown" role
---@param bot Bot
local function attackUnknowns(bot)
    local cvarKosUnknowns = TTTBots.Lib.GetConVarBool("kos_unknown")
    local roleKosUnknown = TTTBots.Roles.GetRoleFor(bot):GetKOSUnknown()
    -- print(kosUnknowns)
    if cvarKosUnknowns or roleKosUnknown then
        -- print("KOSing Unknowns")
        local unknowns = TTTBots.Roles.GetUnknownPlayers()
        -- print("unknowns", unknowns)
        local closest = TTTBots.Lib.GetClosest(unknowns, bot:GetPos())
        -- print("closest", closest)
        if closest and closest ~= NULL and TTTBots.Lib.IsPlayerAlive(closest) then
            -- print("Attacking unknown", closest)
            bot:SetAttackTarget(closest)
        end
    end
end

--- KOS all non Bot NPCs (Zombies, Headcrabs, etc)
---@param bot Bot
local function attackNPCs(bot)
    local npcs = TTTBots.Lib.GetNPCs()
    -- print("NPCs", npcs)
    local closest = nil
    local minDist = math.huge
    for _, npc in pairs(npcs) do
        local dist = bot:GetPos():Distance(npc:GetPos())
        if dist < minDist then
            minDist = dist
            closest = npc
        end
    end
    if closest and closest ~= NULL then
        print("Attacking NPC", closest)
        bot.attackTarget = closest
    end
end

--- Attack 

local PS_RADIUS = 100
local PS_INTERVAL = 5 -- time before we start caring about personal space
local function personalSpace(bot)
    bot.personalSpaceTbl = bot.personalSpaceTbl or {}
    local ticked = {}
    if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then return end
    if IsValid(bot.attackTarget) then return end -- don't care about personal space if we're attacking someone

    local withinPSpace = lib.FilterTable(TTTBots.Match.AlivePlayers, function(other)
        if other == bot then return false end
        if not IsValid(other) then return false end
        if not lib.IsPlayerAlive(other) then return false end
        if not bot:Visible(other) then return false end
        if TTTBots.Roles.IsAllies(bot, other) then return false end -- don't care about allies

        local dist = bot:GetPos():Distance(other:GetPos())
        if dist > PS_RADIUS then return false end

        return true
    end)

    for i, other in pairs(withinPSpace) do
        bot.personalSpaceTbl[other] = (bot.personalSpaceTbl[other] or 0) + 0.5
        ticked[other] = true
    end

    for other, time in pairs(bot.personalSpaceTbl) do
        if not ticked[other] then
            bot.personalSpaceTbl[other] = math.max(time - 0.5, 0)
        end

        if bot.personalSpaceTbl[other] or 0 <= 0 then
            bot.personalSpaceTbl[other] = nil
        end

        if (bot.personalSpaceTbl[other] or 0) >= PS_INTERVAL then
            bot:GetMorality():ChangeSuspicion(other, "PersonalSpace")
            bot:BotChatter():On("PersonalSpace")
            bot.personalSpaceTbl[other] = nil
        end
    end
end

--- Look at the players around us and see if they are holding any T-weapons.
local function noticeTraitorWeapons(bot)
    if bot.attackTarget ~= nil then return end
    if not TTTBots.Roles.GetRoleFor(bot):GetUsesSuspicion() then return end

    local visible = TTTBots.Lib.GetAllWitnessesBasic(bot:EyePos(), TTTBots.Roles.GetNonAllies(bot))
    local filtered = TTTBots.Lib.FilterTable(visible, function(other)
        if TTTBots.Roles.GetRoleFor(other):GetAppearsPolice() then return false end -- We don't sus detectives.
        local hasTWeapon = TTTBots.Lib.IsHoldingTraitorWep(other)
        if not hasTWeapon then return false end
        local iCanSee = TTTBots.Lib.CanSeeArc(bot, other:GetPos() + Vector(0, 0, 24), 90)
        return iCanSee
    end)

    if table.IsEmpty(filtered) then return end

    local firstEnemy = TTTBots.Lib.GetClosest(filtered, bot:GetPos()) ---@cast firstEnemy Player?

    if not TTTBots.Lib.GetConVarBool("kos_traitorweapons") then return end

    if not firstEnemy then return end
    bot:SetAttackTarget(firstEnemy)
    bot:BotChatter():On("HoldingTraitorWeapon", { player = firstEnemy:Nick() })
end

local function preventAttackAll(bot)
    preventAttackAlly(bot)
    preventCloaked(bot)
    preventAttackAllies(bot)
    preventAttack(bot)
end

local function commonSense(bot)
    if not (bot.attackTarget ~= nil and bot.attackTarget:IsNPC() and not table.HasValue(TTTBots.Bots, bot.attackTarget)) then
        attackKOSedByAll(bot)
        -- attackNPCs(bot)
        attackEnemies(bot)
        attackNonAllies(bot)
        attackUnknowns(bot)
        continueMassacre(bot)
        preventAttackAll(bot)
        personalSpace(bot)
        noticeTraitorWeapons(bot)
    else
        print("Attacking NPC In Loop", bot.attackTarget)
    end
end

timer.Create("TTTBots.Components.Morality.CommonSense", 1, 0, function()
    if not TTTBots.Match.IsRoundActive() then return end
    for i, bot in pairs(TTTBots.Bots) do
        if not bot or bot == NULL or not IsValid(bot) then continue end
        if not bot.components.chatter or not bot:BotLocomotor() then continue end
        if not lib.IsPlayerAlive(bot) then continue end
        commonSense(bot)
    end
end)

---@class Player
local plyMeta = FindMetaTable("Player")
function plyMeta:BotMorality()
    ---@cast self Bot
    return self.components.morality
end
