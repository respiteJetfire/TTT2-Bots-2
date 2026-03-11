--- Unified pub/sub event bus for TTTBots2.
--- Replaces the previously scattered hook.Add / direct-function-call / chatter-event patterns
--- with a single, structured dispatch system.
---
--- Usage:
---   local id = TTTBots.Events.Subscribe("BODY_FOUND", function(payload) ... end, priority?)
---   TTTBots.Events.Publish("BODY_FOUND", { finder = bot, corpse = ent, victim = ply })
---   TTTBots.Events.Unsubscribe(id)
---
--- Priorities: lower number = called first. Default priority is 50.
--- Standard priority bands:
---   10  — safety/morality (before decisions are made)
---   50  — general logic (default)
---   90  — chatter/cosmetic reactions (last)

TTTBots = TTTBots or {}
TTTBots.Events = TTTBots.Events or {}

local Events = TTTBots.Events

--- Internal registry: eventName -> array of { id, callback, priority }
Events._subscriptions = Events._subscriptions or {}

--- Auto-incrementing ID counter for subscriptions
Events._nextID = Events._nextID or 1

--- Well-known event name constants — kept here so callers can use
--- TTTBots.Events.NAMES.BODY_FOUND instead of raw strings.
Events.NAMES = {
    BODY_FOUND         = "BODY_FOUND",          -- payload: { finder, corpse, victim }
    WITNESS_KILL       = "WITNESS_KILL",         -- payload: { witness, killer, victim }
    KOS_CALLED         = "KOS_CALLED",           -- payload: { caller, target }
    ROUND_STATE_CHANGE = "ROUND_STATE_CHANGE",   -- payload: { oldState, newState }
    SUSPICION_CHANGED  = "SUSPICION_CHANGED",    -- payload: { bot, target, oldValue, newValue, delta }
    ATTACK_START       = "ATTACK_START",         -- payload: { attacker, target }
    ATTACK_END         = "ATTACK_END",           -- payload: { attacker, target, reason }
    ROLE_WEAPON_USE    = "ROLE_WEAPON_USE",       -- payload: { bot, target, weaponName }
    BOT_SPAWNED        = "BOT_SPAWNED",          -- payload: { bot }
    BOT_DIED           = "BOT_DIED",             -- payload: { bot, killer }
    PLAN_ASSIGNED      = "PLAN_ASSIGNED",        -- payload: { bot, job }
    HEAL_REQUESTED     = "HEAL_REQUESTED",       -- payload: { requester, healer, accepted }
    -- Infected role events
    INFECTION_OCCURRED = "INFECTION_OCCURRED",    -- payload: { host, victim, zombieCount }
    ZOMBIE_SPOTTED     = "ZOMBIE_SPOTTED",        -- payload: { witness, zombie }
    HOST_DIED          = "HOST_DIED",             -- payload: { host, killer }
    -- Amnesiac role events
    AMNESIAC_CONVERTED = "AMNESIAC_CONVERTED",    -- payload: { player, oldRole, newRole, newRoleName }
}

--- Subscribe to an event.
--- Returns a unique subscription ID that can be passed to Unsubscribe.
---@param eventName string The event to subscribe to.
---@param callback function The function to call. Receives a single payload table.
---@param priority? number Lower runs first. Defaults to 50.
---@return number subscriptionID
function Events.Subscribe(eventName, callback, priority)
    assert(type(eventName) == "string", "TTTBots.Events.Subscribe: eventName must be a string")
    assert(type(callback) == "function", "TTTBots.Events.Subscribe: callback must be a function")
    priority = priority or 50

    Events._subscriptions[eventName] = Events._subscriptions[eventName] or {}

    local id = Events._nextID
    Events._nextID = Events._nextID + 1

    local sub = { id = id, callback = callback, priority = priority }

    -- Insert in sorted order (ascending priority)
    local subs = Events._subscriptions[eventName]
    local inserted = false
    for i = 1, #subs do
        if subs[i].priority > priority then
            table.insert(subs, i, sub)
            inserted = true
            break
        end
    end
    if not inserted then
        table.insert(subs, sub)
    end

    return id
end

--- Unsubscribe a previously registered callback by its ID.
---@param id number The subscription ID returned from Subscribe.
function Events.Unsubscribe(id)
    for eventName, subs in pairs(Events._subscriptions) do
        for i, sub in ipairs(subs) do
            if sub.id == id then
                table.remove(subs, i)
                return
            end
        end
    end
end

--- Publish an event to all registered subscribers in priority order.
--- Errors inside subscriber callbacks are caught and printed without halting execution.
---@param eventName string The event name to publish.
---@param payload? table A table of event data. Defaults to {}.
function Events.Publish(eventName, payload)
    assert(type(eventName) == "string", "TTTBots.Events.Publish: eventName must be a string")
    payload = payload or {}

    local subs = Events._subscriptions[eventName]
    if not subs or #subs == 0 then return end

    -- Iterate over a shallow copy so that subscriptions added during dispatch
    -- don't cause double-fire or index shift bugs.
    local snapshot = {}
    for i = 1, #subs do snapshot[i] = subs[i] end

    for _, sub in ipairs(snapshot) do
        local ok, err = pcall(sub.callback, payload)
        if not ok then
            ErrorNoHaltWithStack(string.format(
                "[TTTBots.Events] Error in subscriber %d for event '%s': %s\n",
                sub.id, eventName, tostring(err)
            ))
        end
    end
end

--- Returns the number of active subscribers for a given event name.
---@param eventName string
---@return number
function Events.SubscriberCount(eventName)
    local subs = Events._subscriptions[eventName]
    return subs and #subs or 0
end

--- Clears all subscribers for a given event name. Useful for map cleanup.
---@param eventName string
function Events.ClearEvent(eventName)
    Events._subscriptions[eventName] = nil
end

--- Clears ALL subscribers across all events. Use with care.
function Events.ClearAll()
    Events._subscriptions = {}
end
