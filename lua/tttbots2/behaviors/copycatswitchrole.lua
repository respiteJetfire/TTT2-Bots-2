--- copycatswitchrole.lua
--- Behavior for Copycat bots to switch roles using the Copycat Files weapon.
--- The bot will decide when to switch and which role to pick based on:
---   1. How many roles are available in the collection
---   2. Round phase (urgency increases as the round progresses)
---   3. Which roles are most useful for solo combat
---   4. Cooldown status (respects ttt2_copycat_role_change_cooldown)
---
--- This behavior triggers the server-side role switch by sending a net message
--- to the TTT2CopycatFilesResponse receiver, which handles all validation,
--- cooldown, and role change logic natively.

if not (TTT2 and ROLE_COPYCAT) then return end

---@class CopycatSwitchRole
TTTBots.Behaviors.CopycatSwitchRole = {}

local lib = TTTBots.Lib

---@class CopycatSwitchRole
local CopycatSwitchRole = TTTBots.Behaviors.CopycatSwitchRole
CopycatSwitchRole.Name = "CopycatSwitchRole"
CopycatSwitchRole.Description = "Switch to a collected role using the Copycat Files"
CopycatSwitchRole.Interruptible = true

local STATUS = TTTBots.STATUS

-- ---------------------------------------------------------------------------
-- Role desirability scoring
-- ---------------------------------------------------------------------------

--- Roles that are particularly useful for a solo combat Copycat.
--- Higher score = more desirable to copy.
local ROLE_SCORES = {}

--- Lazily populate role scores (since ROLE_* globals may not exist at load time).
local function getRoleScore(roleIndex)
    -- Build the table on first call
    if not next(ROLE_SCORES) then
        -- Combat/Traitor-like roles — strong for solo play
        if ROLE_TRAITOR then ROLE_SCORES[ROLE_TRAITOR] = 100 end
        if ROLE_SERIALKILLER then ROLE_SCORES[ROLE_SERIALKILLER] = 95 end
        if ROLE_HITMAN then ROLE_SCORES[ROLE_HITMAN] = 90 end
        if ROLE_INFECTED then ROLE_SCORES[ROLE_INFECTED] = 85 end
        if ROLE_VAMPIRE then ROLE_SCORES[ROLE_VAMPIRE] = 80 end

        -- Detective-like roles — good for deception (people trust you)
        if ROLE_DETECTIVE then ROLE_SCORES[ROLE_DETECTIVE] = 75 end
        if ROLE_SHERIFF then ROLE_SCORES[ROLE_SHERIFF] = 70 end
        if ROLE_SNIFFER then ROLE_SCORES[ROLE_SNIFFER] = 65 end

        -- Utility roles
        if ROLE_SURVIVALIST then ROLE_SCORES[ROLE_SURVIVALIST] = 60 end
        if ROLE_MEDIC then ROLE_SCORES[ROLE_MEDIC] = 50 end
        if ROLE_DOCTOR then ROLE_SCORES[ROLE_DOCTOR] = 45 end

        -- Innocent-like roles — still useful for blending in
        if ROLE_INNOCENT then ROLE_SCORES[ROLE_INNOCENT] = 30 end

        -- Jester/special roles — generally bad to copy
        if ROLE_JESTER then ROLE_SCORES[ROLE_JESTER] = 5 end
        if ROLE_SWAPPER then ROLE_SCORES[ROLE_SWAPPER] = 5 end
    end

    return ROLE_SCORES[roleIndex] or 40 -- Default score for unknown roles
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Get the available roles from the addon's Copycat Files data.
--- Returns a table of { roleIndex = true/false } where true means selectable.
---@param bot Player
---@return table|nil availableRoles
local function getAvailableRoles(bot)
    if not COPYCAT_FILES_DATA then return nil end
    if not bot.SteamID64 then return nil end

    local steamId = bot:SteamID64()
    if not steamId or not COPYCAT_FILES_DATA[steamId] then return nil end

    local oncePerRole = GetConVar("ttt2_copycat_once_per_role")
    local isPermanent = GetConVar("ttt2_copycat_permanent")
    local available = {}
    local count = 0

    for roleId, state in pairs(COPYCAT_FILES_DATA[steamId]) do
        if roleId == ROLE_COPYCAT then continue end

        local selectable = (state == true or (oncePerRole and not oncePerRole:GetBool()))
        if isPermanent and isPermanent:GetBool() and bot:GetSubRole() ~= ROLE_COPYCAT then
            selectable = false
        end

        if selectable then
            available[roleId] = true
            count = count + 1
        end
    end

    if count == 0 then return nil end
    return available
end

--- Check if the bot is currently on cooldown for role switching.
---@param bot Player
---@return boolean
local function isOnCooldown(bot)
    if not bot.SteamID64 then return false end
    local steamId = bot:SteamID64()
    if not steamId then return false end

    return timer.Exists("CCFilesCooldownTimer_Server_" .. steamId)
end

--- Select the best role to switch to from the available roles.
---@param available table Set of role indices
---@return number|nil bestRoleId
local function selectBestRole(available)
    local bestRole = nil
    local bestScore = -1

    for roleId, _ in pairs(available) do
        local score = getRoleScore(roleId)
        -- Add a small random factor so bots don't all pick the same role
        score = score + math.random(0, 15)

        if score > bestScore then
            bestScore = score
            bestRole = roleId
        end
    end

    return bestRole
end

--- Determine if the bot should switch roles right now.
--- Considers: number of collected roles, round phase, and randomness.
---@param bot Player
---@param available table
---@return boolean
local function shouldSwitchNow(bot, available)
    -- Count available roles
    local count = 0
    for _ in pairs(available) do count = count + 1 end

    -- Urgency scaling based on round time
    local roundStartTime = TTTBots.Match.RoundStartTime or CurTime()
    local elapsed = CurTime() - roundStartTime
    local urgency = math.Clamp(elapsed / 120, 0, 1) -- 0 at start, 1 after 2 minutes

    -- Base chance: increases with more roles collected and time elapsed
    local baseChance = 20 + (count * 15) + (urgency * 40)

    -- If we have 3+ roles or it's been a while, strongly consider switching
    if count >= 3 then baseChance = baseChance + 30 end
    if elapsed > 60 then baseChance = baseChance + 20 end

    -- Personality influence
    local personality = bot:BotPersonality()
    if personality then
        local mult = personality:GetTraitMult("aggression") or 1
        baseChance = baseChance * mult
    end

    return math.random(1, 100) <= math.Clamp(baseChance, 10, 95)
end

-- ---------------------------------------------------------------------------
-- Behavior Lifecycle
-- ---------------------------------------------------------------------------

--- Validate: only runs while the bot is still the base Copycat subrole,
--- has available roles to switch to, and is not on cooldown.
---@param bot Player
---@return boolean
function CopycatSwitchRole.Validate(bot)
    if not ROLE_COPYCAT then return false end
    if bot:GetSubRole() ~= ROLE_COPYCAT then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if not lib.IsPlayerAlive(bot) then return false end
    if isOnCooldown(bot) then return false end

    -- Check if permanent mode is on and we've already switched once
    local isPermanent = GetConVar("ttt2_copycat_permanent")
    if isPermanent and isPermanent:GetBool() and bot._copycatSwitchTime then
        return false
    end

    local available = getAvailableRoles(bot)
    if not available then return false end

    if not shouldSwitchNow(bot, available) then return false end

    local state = TTTBots.Behaviors.GetState(bot, "CopycatSwitchRole")
    state.availableRoles = available
    state.chosenRole = selectBestRole(available)
    return state.chosenRole ~= nil
end

--- Called when the behavior starts.
---@param bot Player
---@return BStatus
function CopycatSwitchRole.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "CopycatSwitchRole")

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        local roleName = roles and roles.GetByIndex and roles.GetByIndex(state.chosenRole)
        local roleStr = roleName and roleName.name or "something"
        chatter:On("CopycatSwitching", { role = roleStr })
    end

    return STATUS.RUNNING
end

--- Called each tick while running.
---@param bot Player
---@return BStatus
function CopycatSwitchRole.OnRunning(bot)
    local state = TTTBots.Behaviors.GetState(bot, "CopycatSwitchRole")
    local chosenRole = state.chosenRole

    if not chosenRole then return STATUS.FAILURE end
    if bot:GetSubRole() ~= ROLE_COPYCAT then return STATUS.SUCCESS end
    if isOnCooldown(bot) then return STATUS.FAILURE end

    -- Verify the chosen role is still valid
    local available = getAvailableRoles(bot)
    if not available or not available[chosenRole] then
        return STATUS.FAILURE
    end

    -- Trigger the role switch through the addon's native pipeline.
    -- We simulate what the client net message does: send TTT2CopycatFilesResponse
    -- with the chosen role ID. But since we're server-side, we invoke the
    -- logic directly.

    -- First, we need the bot to be in "processing" state (as if they opened the files)
    bot.ccfiles_processing = true

    -- Now perform the role switch using the addon's native validation pipeline
    local cooldown = GetConVar("ttt2_copycat_role_change_cooldown")
        and GetConVar("ttt2_copycat_role_change_cooldown"):GetInt() or 30
    local oncePerRole = GetConVar("ttt2_copycat_once_per_role")
    local steamId = bot:SteamID64()

    -- Validate the role is in the files data
    if not COPYCAT_FILES_DATA or not COPYCAT_FILES_DATA[steamId] then
        bot.ccfiles_processing = nil
        return STATUS.FAILURE
    end

    local fileEntry = COPYCAT_FILES_DATA[steamId][chosenRole]
    local isValid = fileEntry ~= nil and (fileEntry == true or (oncePerRole and not oncePerRole:GetBool()))

    if not isValid then
        bot.ccfiles_processing = nil
        return STATUS.FAILURE
    end

    -- Perform the role switch (mirrors the net.Receive handler logic)
    bot:SetRole(chosenRole, bot:GetTeam())
    SendFullStateUpdate()

    -- Mark role as used (once per role logic)
    if chosenRole ~= ROLE_COPYCAT then
        COPYCAT_FILES_DATA[steamId][chosenRole] = false
    end

    -- Apply cooldown (use the global STATUS from TTT2's status system, not the local behavior STATUS)
    if cooldown > 0 then
        timer.Create("CCFilesCooldownTimer_Server_" .. steamId, cooldown, 1, function() end)
        local ttt2Status = _G.STATUS
        if ttt2Status and ttt2Status.AddTimedStatus then
            ttt2Status:AddTimedStatus(bot, "ttt2_ccfiles_cooldown", cooldown, true)
        end
    end

    bot.ccfiles_processing = nil
    bot._copycatSwitchTime = CurTime()

    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        local roleName = roles and roles.GetByIndex and roles.GetByIndex(chosenRole)
        local roleStr = roleName and roleName.name or "new role"
        chatter:On("CopycatSwitchSuccess", { role = roleStr })
    end

    return STATUS.SUCCESS
end

--- Called on success.
---@param bot Player
function CopycatSwitchRole.OnSuccess(bot)
end

--- Called on failure.
---@param bot Player
function CopycatSwitchRole.OnFailure(bot)
end

--- Called when the behavior ends.
---@param bot Player
function CopycatSwitchRole.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "CopycatSwitchRole")
end
