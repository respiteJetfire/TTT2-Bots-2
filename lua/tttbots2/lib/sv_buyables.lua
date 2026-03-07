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
---@field SituationalScore function? - function(bot) → number. If present, replaces static Priority for buy-order scoring. Higher = more likely to be bought first.
---@field DeferredEvent string? - If set, this buyable is skipped during initial buying and instead purchased via TryDeferredBuy when the matching event fires.
---@field UniqueTeamItem boolean? - If true, only one bot per team may purchase this item per round.

--- A table of weapons that are preferred over primary weapons (PrimaryWeapon == true). Indexed by the weapon's classname.
---@type table<string, boolean>
TTTBots.Buyables.PrimaryWeapons = {}

--- Tracks which unique-team items have already been purchased this round, keyed by team then classname.
---@type table<string, table<string, boolean>>
TTTBots.Buyables.TeamPurchases = {}

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
    local creditAllowance = 1
    local purchased = {}

    -- Compute effective scores once and sort by them descending
    local scored = {}
    for i, option in ipairs(options) do
        local score = option.SituationalScore and option.SituationalScore(bot) or option.Priority
        scored[#scored + 1] = { option = option, score = score }
    end
    table.sort(scored, function(a, b) return a.score > b.score end)

    for _, entry in ipairs(scored) do
        local option = entry.option
        if option.DeferredEvent then continue end                                              -- skip deferred items
        if option.TTT2 and not TTTBots.Lib.IsTTT2() then continue end                        -- for mod compat.
        if option.Class and not TTTBots.Lib.WepClassExists(option.Class) then continue end   -- for mod compat.
        if option.Price > creditAllowance then continue end
        if option.CanBuy and not option.CanBuy(bot) then continue end
        if option.RandomChance and math.random(1, option.RandomChance) ~= 1 then continue end

        -- Team-unique item check
        if option.UniqueTeamItem then
            local team = bot:Team()
            TTTBots.Buyables.TeamPurchases[team] = TTTBots.Buyables.TeamPurchases[team] or {}
            if TTTBots.Buyables.TeamPurchases[team][option.Class] then continue end
        end

        creditAllowance = creditAllowance - option.Price
        table.insert(purchased, option)

        if option.UniqueTeamItem then
            local team = bot:Team()
            TTTBots.Buyables.TeamPurchases[team][option.Class] = true
        end

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

---Tries to purchase any deferred buyables matching the given event type for the given bot.
---@param bot Bot
---@param eventType string - One of: "ally_died", "round_mid", "round_late"
function TTTBots.Buyables.TryDeferredBuy(bot, eventType)
    if not IsValid(bot) then return end
    local roleString = bot:GetRoleStringRaw()
    local options = TTTBots.Buyables.GetBuyablesFor(roleString)
    local credits = bot.deferredCredits or 0
    if credits <= 0 then return end

    for _, option in ipairs(options) do
        if option.DeferredEvent ~= eventType then continue end
        if option.TTT2 and not TTTBots.Lib.IsTTT2() then continue end
        if option.Class and not TTTBots.Lib.WepClassExists(option.Class) then continue end
        if option.Price > credits then continue end
        if option.CanBuy and not option.CanBuy(bot) then continue end
        if option.RandomChance and math.random(1, option.RandomChance) ~= 1 then continue end

        credits = credits - option.Price
        bot.deferredCredits = credits
        local buyfunc = option.BuyFunc or (function(ply) ply:Give(option.Class) end)
        buyfunc(bot)
        if option.OnBuy then option.OnBuy(bot) end
        if option.ShouldAnnounce then
            local chatter = bot:BotChatter()
            if chatter then
                chatter:On("Buy" .. option.Name, {}, option.AnnounceTeam or false)
            end
        end
    end
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
    -- Clear per-round team purchase tracking
    TTTBots.Buyables.TeamPurchases = {}

    -- The two second delay can avoid a bunch of confusing errors. Don't ask why, I don't fucking know.
    timer.Simple(2,
        function()
            if not TTTBots.Match.IsRoundActive() then return end
            for _, bot in pairs(TTTBots.Bots) do
                if not IsValid(bot) then continue end
                if not bot.components then continue end
                if not TTTBots.Lib.IsPlayerAlive(bot) then continue end
                TTTBots.Buyables.PurchaseBuyablesFor(bot)
                bot.deferredCredits = 1
            end
        end)
end)

-- Import default data
include("tttbots2/data/sv_default_buyables.lua")
