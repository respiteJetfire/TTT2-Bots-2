--- spyfakebuy.lua
--- SpyFakeBuy Behavior — Spy executes a fake equipment purchase.
---
--- When ttt2_spy_fake_buy is enabled, the spy can trigger a fake buy that
--- sends TEBN_ItemBought to traitors, making them think the spy bought gear.
--- This is a one-shot behavior (once per round, 30% chance).

---@class SpyFakeBuy
TTTBots.Behaviors.SpyFakeBuy = {}

local lib = TTTBots.Lib

---@class SpyFakeBuy
local SpyFakeBuy = TTTBots.Behaviors.SpyFakeBuy
SpyFakeBuy.Name = "SpyFakeBuy"
SpyFakeBuy.Description = "Spy executes a fake equipment purchase to deceive traitors."
SpyFakeBuy.Interruptible = true

local STATUS = TTTBots.STATUS

function SpyFakeBuy.Validate(bot)
    if not IsValid(bot) then return false end
    if not TTTBots.Perception then return false end
    if not TTTBots.Perception.IsSpy(bot) then return false end
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.attackTarget ~= nil then return false end

    -- Check ConVar
    local fakeBuyEnabled = GetConVar("ttt2_spy_fake_buy")
    if not fakeBuyEnabled or not fakeBuyEnabled:GetBool() then return false end

    local state = TTTBots.Behaviors.GetState(bot, "SpyFakeBuy")

    -- Only once per round
    if state.hasFakeBought then return false end

    -- 30% chance per validation, modified by personality
    local mods = TTTBots.Spy and TTTBots.Spy.GetPersonalityModifiers and TTTBots.Spy.GetPersonalityModifiers(bot) or {}
    local buyMod = mods.fakeBuyChance or 1.0
    if not lib.TestPercent(3 * buyMod) then return false end

    -- Only in mid/late round
    local ra = bot:BotRoundAwareness()
    if ra then
        local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
        if PHASE then
            local phase = ra:GetPhase()
            if phase == PHASE.EARLY then return false end  -- wait for mid-round
        end
    end

    return true
end

function SpyFakeBuy.OnStart(bot)
    local state = TTTBots.Behaviors.GetState(bot, "SpyFakeBuy")
    state.hasFakeBought = true

    -- The actual fake buy is handled server-side by the spy addon's
    -- TTTCanOrderEquipment hook — we just need to attempt an equipment order.
    -- The spy addon intercepts it and sends the fake net message.

    -- Simulate the buy attempt (the spy addon handles the net message)
    -- We can trigger this by calling the equipment order function
    if bot.OrderEquipment then
        -- Try ordering a random traitor equipment item
        local fakeItems = {
            "weapon_ttt_c4",
            "weapon_ttt_knife",
            "item_ttt_radar",
            "weapon_ttt_sipistol",
        }
        local randomItem = fakeItems[math.random(1, #fakeItems)]
        bot:OrderEquipment(randomItem)
    end

    -- Fire chatter event
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("SpyFakeBuy", {}, false, math.random(2, 5))
    end

    return STATUS.SUCCESS
end

function SpyFakeBuy.OnRunning(bot)
    return STATUS.SUCCESS
end

function SpyFakeBuy.OnSuccess(bot) end
function SpyFakeBuy.OnFailure(bot) end

function SpyFakeBuy.OnEnd(bot)
    -- Don't clear state — we need hasFakeBought to persist for the round
end
