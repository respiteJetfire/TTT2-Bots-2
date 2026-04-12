-- avatars are stored in "materials/avatars/" with the name "X.png", with a range of [1,5] for X.
-- so each ply object is assigned to an avatar number
local avatars = {}
local f = string.format

local function validateAvatarCache()
    for k, v in pairs(avatars) do
        if not IsValid(k) then
            avatars[k] = nil
        end
    end
end

--- Tries to select an avatar with a not-yet-selected avatar number
local function selectRandomHumanlike(bot)
    local RANGE_MIN = 0
    local RANGE_MAX = 87

    local selected = {} -- A hash map of selected numbers
    for i, other in pairs(TTTBots.Bots) do
        if other ~= bot and other.avatarN then
            selected[other.avatarN] = true
        end
    end

    local MAX_TRIES = 10
    local tries = 0
    local selectedNumber

    while (tries < MAX_TRIES) do
        selectedNumber = math.random(RANGE_MIN, RANGE_MAX)
        if not selected[selectedNumber] then
            break
        end
        tries = tries + 1
    end

    return selectedNumber
end

---@param bot Bot
local function assignBotAvatar(bot)
    validateAvatarCache()

    -- local avatarNumber = math.random(1, 281)
    -- avatars[bot] = avatarNumber
    local personality = bot:BotPersonality()
    if not personality then
        timer.Simple(1, function()
            assignBotAvatar(bot)
        end)
        return
    end

    local pfps_humanlike = TTTBots.Lib.GetConVarBool("pfps_humanlike")
    local assignedImage

    if not pfps_humanlike then
        local difficulty = personality:GetDifficulty()

        if difficulty <= -4 then
            assignedImage = 1
        elseif difficulty <= -2 then
            assignedImage = 2
        elseif difficulty <= 2 then
            assignedImage = 3
        elseif difficulty <= 4 then
            assignedImage = 4
        else
            assignedImage = 5
        end
    else
        assignedImage = selectRandomHumanlike(bot)
    end

    avatars[bot] = assignedImage
    bot.avatarN = assignedImage
end

hook.Add("TTTBotJoined", "TTTBotAssignAvatar", function(ply)
    assignBotAvatar(ply)
end)

local function syncClientAvatars(ply)
    validateAvatarCache()
    local avatars_nicks = {}

    for k, v in pairs(avatars) do
        avatars_nicks[k:Nick()] = v -- GLua doesn't appreciate sending tbls with keys that are userdata
    end

    net.Start("TTTBots_SyncAvatarNumbers")
    net.WriteTable(avatars_nicks)
    net.Send(ply)
end

-- Client is requesting we sync the bot avatar numbers, we will send the table of bot avatar numbers to the client
net.Receive("TTTBots_SyncAvatarNumbers", function(len, ply)
    syncClientAvatars(ply)
end)

net.Receive("TTTBots_RequestCvarUpdate", function(len, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end

    local cvar = net.ReadString()
    local value = net.ReadString()

    RunConsoleCommand(cvar, value)
end)

hook.Add("PlayerDisconnected", "TTTBots.Network.PlayerDisconnected", syncClientAvatars)
hook.Add("PlayerInitialSpawn", "TTTBots.Network.PlayerInitialSpawn", syncClientAvatars)

--- Bot Menu data: sends bot info (name, traits, difficulty, role, alive status)
--- and the registered buyables list to a requesting client.
net.Receive("TTTBots_RequestBotMenuData", function(len, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end

    -- Gather bot data
    local botData = {}
    for _, bot in ipairs(TTTBots.Bots) do
        if not IsValid(bot) then continue end
        local entry = {
            nick = bot:Nick(),
            alive = TTTBots.Lib.IsPlayerAlive(bot) or false,
            role = (bot.GetRoleStringRaw and bot:GetRoleStringRaw()) or "unknown",
            team = (bot.GetTeam and tostring(bot:GetTeam())) or "unknown",
        }
        local personality = bot.components and bot.components.personality
        if personality then
            entry.traits = personality:GetTraits() or {}
            entry.difficulty = personality:GetDifficulty() or 0
            entry.archetype = personality.archetype or "default"
            entry.rage = personality:GetRage() or 0
            entry.boredom = personality:GetBoredom() or 0
            entry.pressure = personality:GetPressure() or 0
        else
            entry.traits = {}
            entry.difficulty = 0
            entry.archetype = "default"
            entry.rage = 0
            entry.boredom = 0
            entry.pressure = 0
        end
        table.insert(botData, entry)
    end

    -- Gather buyables data (name, class, price, priority, roles)
    local buyableData = {}
    if TTTBots.Buyables and TTTBots.Buyables.m_buyables then
        for name, buyable in pairs(TTTBots.Buyables.m_buyables) do
            if buyable.DeferredEvent then continue end -- Skip deferred buyables for cleaner display
            table.insert(buyableData, {
                name = buyable.Name or name,
                class = buyable.Class or "",
                price = buyable.Price or 0,
                priority = buyable.Priority or 0,
                roles = buyable.Roles or {},
                primaryWeapon = buyable.PrimaryWeapon or false,
                ttt2 = buyable.TTT2 or false,
            })
        end
        table.sort(buyableData, function(a, b) return a.priority > b.priority end)
    end

    net.Start("TTTBots_BotMenuData")
    net.WriteTable({ bots = botData, buyables = buyableData })
    net.Send(ply)
end)
