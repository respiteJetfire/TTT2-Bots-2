TTTBots.Buyables = {}
TTTBots.Buyables.m_buyables = {}
TTTBots.Buyables.m_buyables_role = {}
local buyables = TTTBots.Buyables.m_buyables
local buyables_role = TTTBots.Buyables.m_buyables_role

---@class Buyable
---@field Name string - The pretty name of this item.
---@field Class string - The class of this item.
---@field Price number - The price of this item, in credits. Bots are given an allowance of 2 credits.
---@field Priority number - The priority of this item. Higher numbers = higher priority. If two buyables have the same priority, the script will select one at random.
---@field OnBuy function? - Called when the bot successfully buys this item.
---@field CanBuy function? - Return false to prevent a bot from buying this item.
---@field Roles table<string> - A table of roles that can buy this item.
---@field RandomChance number? - An integer from 1 to math.huge. Functionally the item will be selected if random(1, RandomChoice) == 1.
---@field ShouldAnnounce boolean? - Should this create a chatter event?
---@field AnnounceTeam boolean? - Is announcing team-only?
---@field BuyFunc function? - A function called to "buy" the Class. By default, just calls function(ply) ply:Give(Class) end
---@field TTT2 boolean? - Is this TTT2 specific?
---@field PrimaryWeapon boolean? - Should the bot use this over whatever other primaries they have? (affects autoswitch)
---@field DeferredEvent string? - If set, this buyable is only considered during TryDeferredBuy calls matching this event name.
---@field SituationalScore function? - Returns a numeric score for how valuable this item is right now. Score <= 0 means skip.

--- A table of weapons that are preferred over primary weapons (PrimaryWeapon == true). Indexed by the weapon's classname.
---@type table<string, boolean>
TTTBots.Buyables.PrimaryWeapons = {}

--- Return a buyable item by its name.
---@param name string - The name of the buyable item.
---@return Buyable|nil - The buyable item, or nil if it does not exist.
function TTTBots.Buyables.GetBuyable(name) return buyables[name] end

---Return a list of buyables for the given rolestring. Defaults to an empty table.
---The result is ALWAYS sorted by priority, descending.
---@param roleString string
---@return table<Buyable>
function TTTBots.Buyables.GetBuyablesFor(roleString) return buyables_role[roleString] or {} end

---Adds the given Buyable data to the roleString. This is called automatically when registering a Buyable, but exists for sanity.
---@param buyable Buyable
---@param roleString string
function TTTBots.Buyables.AddBuyableToRole(buyable, roleString)
    buyables_role[roleString] = buyables_role[roleString] or {}
    table.insert(buyables_role[roleString], buyable)
    table.sort(buyables_role[roleString], function(a, b) return a.Priority > b.Priority end)
end

---Purchases any registered buyables for the given bot's rolestring. Returns a table of Buyables that were successfully purchased.
---@param bot Bot
---@return table<Buyable>
function TTTBots.Buyables.PurchaseBuyablesFor(bot)
    local roleString = bot:GetRoleStringRaw()
    local options = TTTBots.Buyables.GetBuyablesFor(roleString)
    local creditAllowance = 2
    local purchased = {}

    for i, option in pairs(options) do
        if option.TTT2 and not TTTBots.Lib.IsTTT2() then continue end                      -- for mod compat.
        if option.Class and not TTTBots.Lib.WepClassExists(option.Class) then continue end -- for mod compat.
        if option.Price > creditAllowance then continue end
        if option.CanBuy and not option.CanBuy(bot) then continue end
        if option.RandomChance and math.random(1, option.RandomChance) ~= 1 then continue end

        creditAllowance = creditAllowance - option.Price
        table.insert(purchased, option)
        local buyfunc = option.BuyFunc or (function(ply) ply:Give(option.Class) end)
        buyfunc(bot)
        if option.OnBuy then option.OnBuy(bot) end
        if option.ShouldAnnounce then
            local chatter = bot:BotChatter()
            if not chatter then continue end
            chatter:On("Buy" .. option.Name, {}, option.AnnounceTeam or false)
        end
    end

    return purchased
end

---Attempts to purchase any deferred buyables for the given bot that match the provided event name.
---A deferred buyable is one with a `DeferredEvent` field set. This function iterates all buyables
---registered for the bot's role, filters to those matching the event, scores them via `SituationalScore`,
---and purchases the best eligible one (score > 0, CanBuy passes, RandomChance passes).
---@param bot Bot
---@param eventName string - The event name to match against each buyable's DeferredEvent field.
---@return Buyable|nil - The buyable that was purchased, or nil if none was bought.
function TTTBots.Buyables.TryDeferredBuy(bot, eventName)
    if not IsValid(bot) then return nil end
    local roleString = bot.GetRoleStringRaw and bot:GetRoleStringRaw()
    if not roleString then return nil end

    local options = TTTBots.Buyables.GetBuyablesFor(roleString)
    local creditAllowance = 2

    local bestOption = nil
    local bestScore = 0

    for _, option in pairs(options) do
        if option.DeferredEvent ~= eventName then continue end
        if option.TTT2 and not TTTBots.Lib.IsTTT2() then continue end
        if option.Class and not TTTBots.Lib.WepClassExists(option.Class) then continue end
        if option.Price > creditAllowance then continue end
        if option.CanBuy and not option.CanBuy(bot) then continue end
        if option.RandomChance and math.random(1, option.RandomChance) ~= 1 then continue end

        local score = option.SituationalScore and option.SituationalScore(bot) or option.Priority
        if score > bestScore then
            bestScore = score
            bestOption = option
        end
    end

    if not bestOption then return nil end

    local buyfunc = bestOption.BuyFunc or (function(ply) ply:Give(bestOption.Class) end)
    buyfunc(bot)
    if bestOption.OnBuy then bestOption.OnBuy(bot) end
    if bestOption.ShouldAnnounce then
        local chatter = bot:BotChatter()
        if chatter then
            chatter:On("Buy" .. bestOption.Name, {}, bestOption.AnnounceTeam or false)
        end
    end

    return bestOption
end

--- Register a buyable item. This is useful for modders wanting to add custom buyable items.
---@param data Buyable - The data of the buyable item.
---@return boolean - Whther or not the override was successful.
function TTTBots.Buyables.RegisterBuyable(data)
    buyables[data.Name] = data

    for _, roleString in pairs(data.Roles) do
        TTTBots.Buyables.AddBuyableToRole(data, roleString)
    end

    if data.PrimaryWeapon then
        TTTBots.Buyables.PrimaryWeapons[data.Class] = true
    end

    return true
end

-- hook for TTTBeginRound
hook.Add("TTTBeginRound", "TTTBots_Buyables", function()
    -- The two second delay can avoid a bunch of confusing errors. Don't ask why, I don't fucking know.
    timer.Simple(2,
        function()
            if not TTTBots.Match.IsRoundActive() then return end
            for _, bot in pairs(TTTBots.Bots) do
                if not IsValid(bot) then continue end
                if not bot.components then continue end
                if not TTTBots.Lib.IsPlayerAlive(bot) then continue end
                TTTBots.Buyables.PurchaseBuyablesFor(bot)
            end
        end)
end)

-- Import default data
include("tttbots2/data/sv_default_buyables.lua")

-- ── LOW_AMMO deferred traitor weapon purchase ─────────────────────────────
-- Registered as a DeferredEvent so it only fires via TryDeferredBuy("LOW_AMMO").
-- Provides a mid-tier silent primary (M16 or MAC-10) with enough ammo to
-- finish a kill when the bot's current loadout is running dry.
-- Both weapons are silent which keeps a traitor from immediately exposing
-- themselves while they're low on ammo.
TTTBots.Buyables.RegisterBuyable({
    Name            = "LowAmmoM16",
    Class           = "weapon_ttt_m16",
    Price           = 1,
    Priority        = 5,
    Roles           = { "traitor" },
    PrimaryWeapon   = false,
    ShouldAnnounce  = false,
    DeferredEvent   = "LOW_AMMO",
    CanBuy = function(bot)
        -- Only buy if we don't already have a decent primary with ammo.
        local inv = bot and bot:BotInventory()
        if not inv then return false end
        local w, info = inv:GetPrimary()
        if IsValid(w) and info and info.has_bullets then return false end
        return TTTBots.Lib.WepClassExists("weapon_ttt_m16")
    end,
    SituationalScore = function(bot)
        -- Score proportional to how empty the bot is.
        local inv = bot and bot:BotInventory()
        if not inv then return 0 end
        local dmg = inv:EstimateTotalDamageAvailable()
        -- If we have some damage available we don't need this urgently.
        if dmg > 150 then return 0 end
        return math.max(10 - (dmg / 15), 1)
    end,
})

TTTBots.Buyables.RegisterBuyable({
    Name            = "LowAmmoMAC10",
    Class           = "weapon_ttt_mac10",
    Price           = 1,
    Priority        = 4,
    Roles           = { "traitor" },
    PrimaryWeapon   = false,
    ShouldAnnounce  = false,
    DeferredEvent   = "LOW_AMMO",
    CanBuy = function(bot)
        local inv = bot and bot:BotInventory()
        if not inv then return false end
        local w, info = inv:GetPrimary()
        if IsValid(w) and info and info.has_bullets then return false end
        return TTTBots.Lib.WepClassExists("weapon_ttt_mac10")
    end,
    SituationalScore = function(bot)
        local inv = bot and bot:BotInventory()
        if not inv then return 0 end
        local dmg = inv:EstimateTotalDamageAvailable()
        if dmg > 150 then return 0 end
        return math.max(8 - (dmg / 15), 1)
    end,
})
-- ── End LOW_AMMO deferred buyables ───────────────────────────────────────
