--- createlovers.lua — Cupid bot behavior: find two targets and create a lover pair.
---
--- This replaces the old RegisterRoleWeapon approach which was fundamentally broken
--- because the crossbow relies on a CLIENT→SERVER net message that bots cannot send.
---
--- Instead, this behavior:
---   1. Finds two valid targets (or one + self if forced_selflove is enabled)
---   2. Directly executes the lover-creation logic server-side
---   3. Strips the weapon after success (mirroring the addon's timer behavior)
---
--- The behavior tracks urgency based on ttt_cupid_timelimit_magic and escalates
--- as the deadline approaches.

if not (TTT2 and ROLE_CUPID) then return end

local lib = TTTBots.Lib

---@class BCreateLovers : BBase
TTTBots.Behaviors.CreateLovers = {}

---@class BCreateLovers
local CreateLovers = TTTBots.Behaviors.CreateLovers
CreateLovers.Name = "CreateLovers"
CreateLovers.Description = "Find two targets and create a lover pair (Cupid server-side bypass)."
CreateLovers.Interruptible = true

local STATUS = TTTBots.STATUS

--- Engage distance for aiming at a target.
local ENGAGE_DISTANCE = 600
--- Minimum start chance (early round).
local BASE_START_CHANCE = 5
--- Maximum start chance (near deadline).
local MAX_START_CHANCE = 100

-- ---------------------------------------------------------------------------
-- State management
-- ---------------------------------------------------------------------------

local function GetState(bot)
    return TTTBots.Behaviors.GetState(bot, "CreateLovers")
end

local function ClearState(bot)
    TTTBots.Behaviors.ClearState(bot, "CreateLovers")
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Return the Cupid weapon entity the bot is holding, or nil.
---@param bot Player
---@return Entity?
local function getCupidWeapon(bot)
    local inv = bot:BotInventory()
    if not inv then return nil end
    return inv:GetLoversGun()
end

--- Check how many seconds remain before the Cupid weapon is stripped.
---@return number seconds remaining
local function getTimeRemaining()
    local limit = GetConVar("ttt_cupid_timelimit_magic")
    if not limit then return 60 end
    local total = limit:GetInt()
    -- The addon creates a timer "remove_Cupid_weapon" at round start.
    if timer.Exists("remove_Cupid_weapon") then
        local left = timer.TimeLeft("remove_Cupid_weapon")
        if left then return left end
    end
    return total
end

--- Calculate urgency (0.0 = calm, 1.0 = desperate) based on time remaining.
---@return number urgency 0..1
local function getUrgency()
    local limit = GetConVar("ttt_cupid_timelimit_magic")
    if not limit then return 0 end
    local total = limit:GetInt()
    if total <= 0 then return 1 end
    local remaining = getTimeRemaining()
    return math.Clamp(1 - (remaining / total), 0, 1)
end

--- Get the dynamic start chance based on urgency.
---@return number 0-100
local function getStartChance()
    local urgency = getUrgency()
    return BASE_START_CHANCE + (MAX_START_CHANCE - BASE_START_CHANCE) * urgency
end

--- Check if a player is a valid lover target.
---@param bot Player
---@param target Player
---@param otherTarget Player? If set, exclude this player.
---@return boolean
local function isValidTarget(bot, target, otherTarget)
    if not IsValid(target) then return false end
    if not target:IsPlayer() then return false end
    if not lib.IsPlayerAlive(target) then return false end
    if target == bot then return false end
    if otherTarget and target == otherTarget then return false end
    -- Can't target public roles (e.g., detectives) — matches crossbow's restriction
    if target.GetSubRoleData and target:GetSubRoleData().isPublicRole then return false end
    -- Don't target players already in love
    if target.inLove then return false end
    return true
end

--- Find the best target to pair. Prefers isolated, close players.
---@param bot Player
---@param exclude Player? Player to exclude from targeting.
---@return Player?
local function findTarget(bot, exclude)
    local alive = TTTBots.Match.AlivePlayers or {}
    local bestTarget = nil
    local bestScore = -math.huge
    local botPos = bot:GetPos()
    local urgency = getUrgency()

    for _, ply in ipairs(alive) do
        if not isValidTarget(bot, ply, exclude) then continue end

        local dist = botPos:Distance(ply:GetPos())
        -- Score: closer is better, isolated is better
        local distScore = -dist / 500
        -- Witness penalty: fewer witnesses = better (reduced at high urgency)
        local witnesses = lib.GetAllWitnessesBasic(ply:GetPos(), TTTBots.Match.AlivePlayers, bot)
        local witnessPenalty = table.Count(witnesses) * (3 - urgency * 2)
        local score = distScore - witnessPenalty

        if score > bestScore then
            bestScore = score
            bestTarget = ply
        end
    end

    return bestTarget
end

--- Check if self-love (forced or strategic) should be used.
---@return boolean
local function shouldSelfLove()
    local cvar = GetConVar("ttt_cupid_forced_selflove")
    return cvar and cvar:GetBool()
end

-- ---------------------------------------------------------------------------
-- Server-side lover creation (bypasses the broken client net message)
-- ---------------------------------------------------------------------------

--- Directly execute the lover-creation logic on the server.
--- This replicates what net.Receive("Lovedones") does in sh_cupid_love_handler.lua.
---@param cupidBot Player
---@param lover1 Player
---@param lover2 Player
---@return boolean success
function TTTBots.Cupid_CreateLovers(cupidBot, lover1, lover2)
    if not (IsValid(cupidBot) and IsValid(lover1) and IsValid(lover2)) then return false end
    if not (lib.IsPlayerAlive(lover1) and lib.IsPlayerAlive(lover2)) then return false end

    -- Build the lovedones table matching the addon's expected format: {lover1, lover2, cupid}
    local lovedonesTbl = { lover1, lover2, cupidBot }

    -- Set the global lovedones table (the addon uses this globally)
    lovedones = lovedonesTbl

    -- Handle team switching (mirrors net.Receive("Lovedones") logic)
    local forceLoverTeam = GetConVar("ttt_cupid_lovers_force_own_team")
    local cupidJoinsTeam = GetConVar("ttt_cupid_joins_team_lovers")

    if lover1:GetTeam() ~= lover2:GetTeam() or (forceLoverTeam and forceLoverTeam:GetBool()) then
        -- Identify a betrayed traitor for notification
        local bfTraitor = lover1
        if lover1:GetTeam() == TEAM_TRAITOR then
            bfTraitor = lover1
        elseif lover2:GetTeam() == TEAM_TRAITOR then
            bfTraitor = lover2
        end

        lover1:UpdateTeam(TEAM_LOVER)
        lover2:UpdateTeam(TEAM_LOVER)
        PrintMessage(HUD_PRINTCONSOLE, lover1:Nick() .. " is now in love with " .. lover2:Nick() .. ".")

        if cupidJoinsTeam and cupidJoinsTeam:GetBool() then
            cupidBot:UpdateTeam(TEAM_LOVER)
        end

        -- Notify remaining traitors about the betrayal
        local otherTraitors = {}
        for _, v in ipairs(player.GetAll()) do
            if v:GetTeam() == TEAM_TRAITOR then
                table.insert(otherTraitors, v)
            end
        end
        if #otherTraitors > 0 then
            net.Start("betrayedTraitor")
                net.WritePlayer(bfTraitor)
            net.Send(otherTraitors)
        end
    end

    -- Handle Cupid joining lovers team
    if cupidJoinsTeam and cupidJoinsTeam:GetBool() and lover1:GetTeam() ~= cupidBot:GetTeam() then
        cupidBot:UpdateTeam(lover1:GetTeam())
        PrintMessage(HUD_PRINTCONSOLE, cupidBot:Nick() .. " is now also in on it.")
    end

    -- Update state
    SendFullStateUpdate()

    -- Send inLove net message to affected players (for client-side effects like halos)
    net.Start("inLove")
        net.WriteTable({ lover1, lover2, cupidBot })
    net.Send({ lover1, lover2, cupidBot })

    -- Mark as in love
    lover1.inLove = true
    lover2.inLove = true

    -- Set up damage splitting if enabled
    local damageSplit = GetConVar("ttt_cupid_damage_split_enabled")
    if damageSplit and damageSplit:GetBool() then
        hook.Add("EntityTakeDamage", "LoversDamageScaling", function(ply, dmginfo)
            if GetRoundState() ~= ROUND_ACTIVE then return end
            if ply.inLove then
                if not m_bApplyingDamage then
                    m_bApplyingDamage = true
                    dmginfo:SetDamage(dmginfo:GetDamage() / 2)
                    lovedones[1]:TakeDamageInfo(dmginfo)
                    lovedones[2]:TakeDamageInfo(dmginfo)
                    dmginfo:ScaleDamage(0)
                    m_bApplyingDamage = false
                    return
                end
            end
        end)
        hook.Add("Tick", "Lovers_Heal_Share", function()
            if CurTime() % 1 == 0 and table.Count(lovedones) > 1
                and IsValid(lovedones[1]) and IsValid(lovedones[2])
                and lovedones[1]:Alive() and lovedones[2]:Alive()
                and lovedones[1]:Health() ~= lovedones[2]:Health() then
                local healthDiff = lovedones[1]:Health() - lovedones[2]:Health()
                if healthDiff > 0 then
                    lovedones[2]:SetHealth(lovedones[1]:Health())
                else
                    lovedones[1]:SetHealth(lovedones[2]:Health())
                end
            end
        end)
    end

    -- Strip the Cupid's weapons
    cupidBot:StripWeapon("weapon_ttt2_cupidscrossbow")
    cupidBot:StripWeapon("weapon_ttt2_cupidsbow")

    return true
end

-- ---------------------------------------------------------------------------
-- Behavior interface
-- ---------------------------------------------------------------------------

function CreateLovers.Validate(bot)
    if not IsValid(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.attackTarget ~= nil then return false end

    -- Only for Cupid bots
    local role = TTTBots.Roles.GetRoleFor(bot)
    if not role or role:GetName() ~= "cupid" then return false end

    -- Must still have the Cupid weapon
    if not getCupidWeapon(bot) then return false end

    -- Already linked? Don't run again.
    if bot.inLove then return false end
    if TTTBots.Roles.IsCupidLinked and TTTBots.Roles.IsCupidLinked(bot) then return false end

    -- Chance gate with urgency scaling
    local chance = getStartChance()
    if math.random(0, 100) > chance then return false end

    return true
end

function CreateLovers.OnStart(bot)
    local state = GetState(bot)
    state.phase = "FINDING_FIRST"
    state.lover1 = nil
    state.lover2 = nil
    state.startTime = CurTime()
    state.timePressureChatFired = false

    -- Chatter: announce we're about to use the crossbow
    local chatter = bot:BotChatter()
    if chatter then
        chatter:On("CupidCreatingLovers", {}, true)
    end

    return STATUS.RUNNING
end

function CreateLovers.OnRunning(bot)
    local state = GetState(bot)
    local loco = bot:BotLocomotor()
    local inv = bot:BotInventory()
    if not (loco and inv) then return STATUS.FAILURE end

    -- Check if weapon was stripped (time ran out)
    if not getCupidWeapon(bot) then
        return STATUS.FAILURE
    end

    local urgency = getUrgency()

    -- Time pressure chatter
    if urgency > 0.75 and not state.timePressureChatFired then
        state.timePressureChatFired = true
        local chatter = bot:BotChatter()
        if chatter then
            chatter:On("CupidTimePressure", {}, false)
        end
    end

    -- -------------------------------------------------------------------
    -- Phase: FINDING_FIRST — find the first target
    -- -------------------------------------------------------------------
    if state.phase == "FINDING_FIRST" then
        if shouldSelfLove() then
            local target = findTarget(bot, nil)
            if not target then return STATUS.RUNNING end
            state.lover1 = bot
            state.lover2 = target
            state.phase = "NAVIGATING"
            return STATUS.RUNNING
        end

        local target = findTarget(bot, nil)
        if not target then return STATUS.RUNNING end

        state.lover1 = target
        state.phase = "FINDING_SECOND"
        return STATUS.RUNNING
    end

    -- -------------------------------------------------------------------
    -- Phase: FINDING_SECOND — find the second target
    -- -------------------------------------------------------------------
    if state.phase == "FINDING_SECOND" then
        if not IsValid(state.lover1) or not lib.IsPlayerAlive(state.lover1) then
            state.phase = "FINDING_FIRST"
            state.lover1 = nil
            return STATUS.RUNNING
        end

        local target2 = findTarget(bot, state.lover1)
        if not target2 then
            -- At high urgency, accept self-pairing as fallback
            if urgency > 0.8 then
                state.lover2 = bot
                state.phase = "NAVIGATING"
                return STATUS.RUNNING
            end
            return STATUS.RUNNING
        end

        state.lover2 = target2
        state.phase = "NAVIGATING"
        return STATUS.RUNNING
    end

    -- -------------------------------------------------------------------
    -- Phase: NAVIGATING — get close to the targets, then link
    -- -------------------------------------------------------------------
    if state.phase == "NAVIGATING" then
        if not IsValid(state.lover1) or not IsValid(state.lover2) then
            state.phase = "FINDING_FIRST"
            state.lover1 = nil
            state.lover2 = nil
            return STATUS.RUNNING
        end

        -- Navigate toward whichever target is farther (that isn't self)
        local navTarget = nil
        if state.lover1 == bot then
            navTarget = state.lover2
        elseif state.lover2 == bot then
            navTarget = state.lover1
        else
            local d1 = bot:GetPos():Distance(state.lover1:GetPos())
            local d2 = bot:GetPos():Distance(state.lover2:GetPos())
            navTarget = d1 < d2 and state.lover1 or state.lover2
        end

        if not IsValid(navTarget) or not lib.IsPlayerAlive(navTarget) then
            state.phase = "FINDING_FIRST"
            state.lover1 = nil
            state.lover2 = nil
            return STATUS.RUNNING
        end

        local dist = bot:GetPos():Distance(navTarget:GetPos())
        loco:SetGoal(navTarget:GetPos())
        loco:LookAt(navTarget:EyePos())

        -- Equip the Cupid weapon for visual effect while approaching
        inv:EquipLoversGun()
        inv:PauseAutoSwitch()

        -- At close range or high urgency, execute the pairing
        local engageDist = ENGAGE_DISTANCE + (urgency * 400)
        if dist <= engageDist or urgency > 0.9 then
            state.phase = "LINKING"
        end

        return STATUS.RUNNING
    end

    -- -------------------------------------------------------------------
    -- Phase: LINKING — execute the server-side lover creation
    -- -------------------------------------------------------------------
    if state.phase == "LINKING" then
        local lover1 = state.lover1
        local lover2 = state.lover2

        if not IsValid(lover1) or not IsValid(lover2) then
            state.phase = "FINDING_FIRST"
            state.lover1 = nil
            state.lover2 = nil
            return STATUS.RUNNING
        end

        if not lib.IsPlayerAlive(lover1) or not lib.IsPlayerAlive(lover2) then
            state.phase = "FINDING_FIRST"
            state.lover1 = nil
            state.lover2 = nil
            return STATUS.RUNNING
        end

        -- Execute the pairing
        local success = TTTBots.Cupid_CreateLovers(bot, lover1, lover2)
        if success then
            local chatter = bot:BotChatter()
            if chatter then
                local loverName = (lover1 ~= bot) and lover1:Nick() or lover2:Nick()
                local otherName = (lover2 ~= bot) and lover2:Nick() or lover1:Nick()
                chatter:On("CupidLoversFormed", {
                    player = loverName,
                    player2 = otherName,
                }, true)
            end
            return STATUS.SUCCESS
        else
            return STATUS.FAILURE
        end
    end

    return STATUS.RUNNING
end

function CreateLovers.OnSuccess(bot)
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end
    local inv = bot:BotInventory()
    if inv then inv:ResumeAutoSwitch() end
end

function CreateLovers.OnFailure(bot)
end

function CreateLovers.OnEnd(bot)
    ClearState(bot)
    local loco = bot:BotLocomotor()
    if loco then loco:StopAttack() end
    timer.Simple(1, function()
        if not IsValid(bot) then return end
        local inv = bot:BotInventory()
        if inv then inv:ResumeAutoSwitch() end
    end)
end
