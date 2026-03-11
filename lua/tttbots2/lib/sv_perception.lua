--- sv_perception.lua
--- Perception Layer — Asymmetric alliance checking for roles that disguise
--- their team membership (e.g., Spy appears as traitor to traitor-team bots).
---
--- This module provides a perception overlay that sits between game-state
--- queries (IsAllies, GetNonAllies) and the actual team/role data. Systems
--- that need to act on *what bots believe* should call the perception
--- functions rather than the raw role functions.
---
--- Design: Traitor bots perceive the Spy as an ally. The Spy perceives
--- traitors as enemies (but knows who they are). This is an intentionally
--- asymmetric relationship.

TTTBots.Perception = TTTBots.Perception or {}

local lib = TTTBots.Lib

-- =========================================================================
-- Cache — invalidated on round start and spy death
-- =========================================================================

local perceivedAllyCache = {}  -- [observerIdx .. "_" .. targetIdx] = bool
local spyPlayersCache = nil     -- table of players with role "spy", or nil = dirty
local traitorPlayersCache = nil -- table of players on TEAM_TRAITOR, or nil = dirty

--- Invalidate all perception caches.
function TTTBots.Perception.InvalidateCache()
    perceivedAllyCache = {}
    spyPlayersCache = nil
    traitorPlayersCache = nil
end

--- Build and cache the set of alive spy players.
---@return table<Player>
local function getSpyPlayers()
    if spyPlayersCache then return spyPlayersCache end
    spyPlayersCache = {}
    if not ROLE_SPY then return spyPlayersCache end
    for _, ply in pairs(TTTBots.Match.AlivePlayers or {}) do
        if IsValid(ply) and ply.GetRoleStringRaw and ply:GetRoleStringRaw() == "spy" then
            table.insert(spyPlayersCache, ply)
        end
    end
    return spyPlayersCache
end

--- Build and cache the set of alive traitor-team players.
---@return table<Player>
local function getTraitorPlayers()
    if traitorPlayersCache then return traitorPlayersCache end
    traitorPlayersCache = {}
    for _, ply in pairs(TTTBots.Match.AlivePlayers or {}) do
        if IsValid(ply) and ply.GetTeam and ply:GetTeam() == TEAM_TRAITOR then
            table.insert(traitorPlayersCache, ply)
        end
    end
    return traitorPlayersCache
end

--- Check if a player is a spy (by role string).
---@param ply Player
---@return boolean
function TTTBots.Perception.IsSpy(ply)
    if not IsValid(ply) then return false end
    if not ROLE_SPY then return false end
    return ply.GetRoleStringRaw and ply:GetRoleStringRaw() == "spy"
end

--- Check if a player is on the traitor team.
---@param ply Player
---@return boolean
function TTTBots.Perception.IsTraitorTeam(ply)
    if not IsValid(ply) then return false end
    return ply.GetTeam and ply:GetTeam() == TEAM_TRAITOR
end

-- =========================================================================
-- Core Perception Functions
-- =========================================================================

--- Does the observer perceive the target as an ally?
--- Asymmetric:
---   • Traitor → Spy: true (traitor thinks spy is a fellow traitor)
---   • Spy → Traitor: false (spy knows the truth — traitors are enemies)
---   • All other cases: delegate to TTTBots.Roles.IsAllies()
---@param observer Player  The bot making the decision
---@param target Player    The player being evaluated
---@return boolean
function TTTBots.Perception.IsPerceivedAlly(observer, target)
    if not (IsValid(observer) and IsValid(target)) then return false end
    if observer == target then return true end

    -- Cache key
    local key = tostring(observer:EntIndex()) .. "_" .. tostring(target:EntIndex())
    if perceivedAllyCache[key] ~= nil then
        return perceivedAllyCache[key]
    end

    local result

    -- Traitor observer looking at a Spy → perceive as ally
    if TTTBots.Perception.IsTraitorTeam(observer)
       and TTTBots.Perception.IsSpy(target) then
        result = true
    -- Spy observer looking at a Traitor → NOT an ally (spy knows the truth)
    elseif TTTBots.Perception.IsSpy(observer)
           and TTTBots.Perception.IsTraitorTeam(target) then
        result = false
    else
        -- All other cases: use real alliance
        result = TTTBots.Roles.IsAllies(observer, target)
    end

    perceivedAllyCache[key] = result
    return result
end

--- Get the perceived role string of the target from the observer's viewpoint.
--- Traitors see spy as "traitor". Traitors see clown as "jester".
--- Spy sees traitors by their real role.
---@param observer Player
---@param target Player
---@return string  role string
function TTTBots.Perception.GetPerceivedRole(observer, target)
    if not (IsValid(observer) and IsValid(target)) then return "unknown" end

    -- Traitor team observer looking at a Spy → perceive as "traitor"
    if TTTBots.Perception.IsTraitorTeam(observer)
       and TTTBots.Perception.IsSpy(target) then
        return "traitor"
    end

    -- Traitor team observer looking at a Clown → perceive as "jester"
    -- Mirrors TTT2SpecialRoleSyncing hook "TTT2RoleClown"
    if ROLE_CLOWN
       and TTTBots.Perception.IsTraitorTeam(observer)
       and target.GetRoleStringRaw
       and target:GetRoleStringRaw() == "clown" then
        return "jester"
    end

    -- Everyone else sees real role
    return target:GetRoleStringRaw()
end

--- Get the perceived team of the target from the observer's viewpoint.
---@param observer Player
---@param target Player
---@return string  team string
function TTTBots.Perception.GetPerceivedTeam(observer, target)
    if not (IsValid(observer) and IsValid(target)) then return TEAM_NONE or "none" end

    if TTTBots.Perception.IsTraitorTeam(observer)
       and TTTBots.Perception.IsSpy(target) then
        return TEAM_TRAITOR
    end

    -- Traitors see Clown as being on TEAM_JESTER (mirrors TTT2SpecialRoleSyncing)
    if ROLE_CLOWN
       and TTTBots.Perception.IsTraitorTeam(observer)
       and IsValid(target)
       and target.GetRoleStringRaw
       and target:GetRoleStringRaw() == "clown" then
        return TEAM_JESTER or "jesters"
    end

    return target:GetTeam()
end

--- Get a filtered list of alive players that the observer perceives as
--- NOT allies. This is the perception-aware replacement for GetNonAllies().
---@param observer Player
---@return table<Player>
function TTTBots.Perception.GetPerceivedNonAllies(observer)
    local alive = TTTBots.Match.AlivePlayers or {}
    return lib.FilterTable(alive, function(other)
        if not (IsValid(other) and lib.IsPlayerAlive(other)) then return false end
        if other == observer then return false end
        return not TTTBots.Perception.IsPerceivedAlly(observer, other)
    end)
end

--- Get a filtered list of alive players that the observer perceives as allies.
---@param observer Player
---@return table<Player>
function TTTBots.Perception.GetPerceivedAllies(observer)
    local alive = TTTBots.Match.AlivePlayers or {}
    return lib.FilterTable(alive, function(other)
        if not (IsValid(other) and lib.IsPlayerAlive(other)) then return false end
        if other == observer then return false end
        return TTTBots.Perception.IsPerceivedAlly(observer, other)
    end)
end

--- Does the observer know the traitor identities? This applies to the Spy,
--- who is informed of traitor identities at round start.
---@param observer Player
---@return boolean
function TTTBots.Perception.KnowsTraitorIdentities(observer)
    return TTTBots.Perception.IsSpy(observer)
end

--- Get the list of traitors that the spy knows about.
--- Returns empty table for non-spy roles.
---@param observer Player
---@return table<Player>
function TTTBots.Perception.GetKnownTraitors(observer)
    if not TTTBots.Perception.IsSpy(observer) then return {} end
    return getTraitorPlayers()
end

--- Is any spy currently alive? Used for team-chat jamming awareness.
---@return boolean
function TTTBots.Perception.IsAnySpyAlive()
    return #getSpyPlayers() > 0
end

--- Get the alive spy players.
---@return table<Player>
function TTTBots.Perception.GetAliveSpies()
    return getSpyPlayers()
end

-- =========================================================================
-- Spy Cover Tracking
-- =========================================================================

--- Per-spy cover state. Tracks whether each spy's cover is still intact
--- from the perspective of traitor bots.
local spyCoverState = {}  -- [spyEntIndex] = { blown = bool, suspicion = number, blownTime = number }

--- Get or initialize the cover state for a spy.
---@param spy Player
---@return table { blown: bool, suspicion: number, blownTime: number }
function TTTBots.Perception.GetCoverState(spy)
    local idx = spy:EntIndex()
    if not spyCoverState[idx] then
        spyCoverState[idx] = {
            blown = false,
            suspicion = 0,
            blownTime = 0,
        }
    end
    return spyCoverState[idx]
end

--- Increase traitor suspicion of a spy bot. Once suspicion exceeds threshold,
--- the spy's cover is blown and traitors will target them.
---@param spy Player
---@param amount number  Suspicion to add (default 1)
function TTTBots.Perception.AddSpySuspicion(spy, amount)
    local state = TTTBots.Perception.GetCoverState(spy)
    if state.blown then return end  -- already blown

    amount = amount or 1
    state.suspicion = state.suspicion + amount

    local threshold = lib.GetConVarFloat("tttbots_spy_traitor_detection_threshold") or 10
    if state.suspicion >= threshold then
        TTTBots.Perception.BlowCover(spy)
    end
end

--- Immediately blow a spy's cover. Traitor bots will now treat the spy as an enemy.
---@param spy Player
function TTTBots.Perception.BlowCover(spy)
    local state = TTTBots.Perception.GetCoverState(spy)
    if state.blown then return end

    state.blown = true
    state.blownTime = CurTime()

    -- Invalidate cache so traitors re-evaluate the spy
    TTTBots.Perception.InvalidateCache()

    -- Fire hook for chatter/event system integration
    hook.Run("TTTBots.SpyCoverBlown", spy)

    -- Notify nearby traitor bots via chatter
    for _, traitor in pairs(getTraitorPlayers()) do
        if not (IsValid(traitor) and traitor:IsBot()) then continue end
        local chatter = traitor:BotChatter()
        if chatter and chatter.On then
            chatter:On("TraitorDiscoversSpy", { player = spy:Nick(), playerEnt = spy }, false, math.random(0, 2))
        end
    end

    -- Spy reacts
    if spy:IsBot() then
        local chatter = spy:BotChatter()
        if chatter and chatter.On then
            chatter:On("SpyCoverBlow", {}, false, math.random(1, 3))
        end
    end
end

--- Is the spy's cover blown from the traitor perspective?
---@param spy Player
---@return boolean
function TTTBots.Perception.IsCoverBlown(spy)
    local state = TTTBots.Perception.GetCoverState(spy)
    return state.blown
end

-- Override the main IsPerceivedAlly to account for blown cover and Clown perception
local _originalIsPerceivedAlly = TTTBots.Perception.IsPerceivedAlly
function TTTBots.Perception.IsPerceivedAlly(observer, target)
    -- If the target is a spy whose cover has been blown, traitors no longer see them as ally
    if TTTBots.Perception.IsTraitorTeam(observer)
       and TTTBots.Perception.IsSpy(target)
       and TTTBots.Perception.IsCoverBlown(target) then
        return false
    end

    -- Clown perception: Traitor bots see the Clown as a Jester (neutral/non-threat)
    -- This mirrors the game's TTT2SpecialRoleSyncing hook ("TTT2RoleClown")
    -- which makes the Clown appear as ROLE_JESTER to traitor-team observers.
    -- NeutralOverride already prevents attacks, but this ensures perception consistency.
    if ROLE_CLOWN
       and TTTBots.Perception.IsTraitorTeam(observer)
       and IsValid(target)
       and target.GetRoleStringRaw
       and target:GetRoleStringRaw() == "clown" then
        -- Traitors perceive Clown as neutral (like a Jester) — not an ally, not an enemy
        -- Return false (not ally) but the NeutralOverride on the Clown role prevents attacks
        return false
    end

    return _originalIsPerceivedAlly(observer, target)
end

-- =========================================================================
-- Cache Invalidation Hooks
-- =========================================================================

hook.Add("TTTBeginRound", "TTTBots.Perception.RoundStart", function()
    TTTBots.Perception.InvalidateCache()
    spyCoverState = {}
end)

hook.Add("TTTEndRound", "TTTBots.Perception.RoundEnd", function()
    TTTBots.Perception.InvalidateCache()
    spyCoverState = {}
end)

hook.Add("PlayerDeath", "TTTBots.Perception.PlayerDeath", function(victim)
    -- Invalidate on any death so spy/traitor lists are refreshed
    TTTBots.Perception.InvalidateCache()
end)

-- Periodic cache refresh (every 5s) to account for mid-round role changes
timer.Create("TTTBots.Perception.CacheRefresh", 5, 0, function()
    TTTBots.Perception.InvalidateCache()
end)

-- =========================================================================
-- Debug Tooling (P5-4)
-- =========================================================================

--- Print a debug summary of the current spy perception state.
--- Useful for server operators to verify the perception layer is working.
function TTTBots.Perception.DebugDump()
    print("=== TTTBots Perception Debug ===")
    local spies = getSpyPlayers()
    print(string.format("  Alive Spies: %d", #spies))
    for _, spy in ipairs(spies) do
        local state = TTTBots.Perception.GetCoverState(spy)
        print(string.format("    - %s [Cover: %s, Suspicion: %.1f]",
            spy:Nick(),
            state.blown and "BLOWN" or "intact",
            state.suspicion))
    end

    local traitors = getTraitorPlayers()
    print(string.format("  Alive Traitors: %d", #traitors))
    for _, tr in ipairs(traitors) do
        print(string.format("    - %s", tr:Nick()))
    end

    -- Print perception matrix for spies/traitors
    for _, spy in ipairs(spies) do
        for _, tr in ipairs(traitors) do
            local trSeesSpy = TTTBots.Perception.IsPerceivedAlly(tr, spy)
            local spySeeTr = TTTBots.Perception.IsPerceivedAlly(spy, tr)
            print(string.format("    %s→%s: %s  |  %s→%s: %s",
                tr:Nick(), spy:Nick(), trSeesSpy and "ALLY" or "ENEMY",
                spy:Nick(), tr:Nick(), spySeeTr and "ALLY" or "ENEMY"))
        end
    end
    print("================================")
end

-- Console command for debug
concommand.Add("tttbots_perception_debug", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    TTTBots.Perception.DebugDump()
end)

print("[TTT Bots 2] Perception layer loaded — asymmetric alliance support enabled.")
