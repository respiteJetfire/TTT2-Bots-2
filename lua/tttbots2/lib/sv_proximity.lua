--- sv_proximity.lua
--- Proximity chat integration for TTT Bots 2.
--- Reads TTT2's locational voice cvars (ttt_locational_voice, ttt_locational_voice_range,
--- ttt_locational_voice_prep, ttt_locational_voice_team) and provides utility functions
--- that other bot modules use to filter chat / voice output by distance.

TTTBots.Proximity = TTTBots.Proximity or {}

local lib = TTTBots.Lib

-- ---------------------------------------------------------------------------
-- Cached ConVar references (created by TTT2's sv_voice.lua; safe to read)
-- ---------------------------------------------------------------------------

--- Safely retrieve a ConVar that may not exist (TTT2 not loaded yet).
---@param name string
---@return ConVar|nil
local function SafeGetConVar(name)
    local cv = GetConVar(name)
    return cv
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Returns true if TTT2's locational/proximity voice chat is currently active.
--- Accounts for round state and the prep-phase cvar.
--- Also checks the bot-specific ttt_bot_chatter_proximity toggle.
---@return boolean
function TTTBots.Proximity.IsActive()
    -- Bot-specific toggle: if disabled, bots ignore proximity entirely
    if not lib.GetConVarBool("chatter_proximity") then return false end

    local cv = SafeGetConVar("ttt_locational_voice")
    if not cv or not cv:GetBool() then return false end

    -- Respect round state: proximity is always off during post-round
    local roundState = GetRoundState and GetRoundState() or ROUND_WAIT
    if roundState == ROUND_POST then return false end

    -- During prep phase, only active if the prep cvar is on
    if roundState == ROUND_PREP then
        local cvPrep = SafeGetConVar("ttt_locational_voice_prep")
        if not cvPrep or not cvPrep:GetBool() then return false end
    end

    return true
end

--- Returns true if team voice chat should also be proximity-filtered.
---@return boolean
function TTTBots.Proximity.IsTeamProximity()
    local cv = SafeGetConVar("ttt_locational_voice_team")
    return cv and cv:GetBool() or false
end

--- Returns the configured proximity range in Hammer units.
--- A value of 0 means infinite range (distance-based falloff only, no hard cutoff).
---@return number
function TTTBots.Proximity.GetRange()
    local cv = SafeGetConVar("ttt_locational_voice_range")
    return cv and cv:GetFloat() or 0
end

--- Returns true if `listener` is within proximity range of `speaker`.
--- If proximity chat is not active, always returns true.
--- If the range cvar is 0, always returns true (infinite range, 3D falloff only).
---@param listener Player
---@param speaker Player
---@param teamOnly boolean|nil  if true and team proximity is off, skip distance check
---@return boolean
function TTTBots.Proximity.CanHear(listener, speaker, teamOnly)
    if not TTTBots.Proximity.IsActive() then return true end

    -- If this is team-only chat and team proximity is disabled, everyone on
    -- the same team hears it regardless of distance.
    if teamOnly and not TTTBots.Proximity.IsTeamProximity() then
        return true
    end

    local range = TTTBots.Proximity.GetRange()
    if range <= 0 then return true end  -- 0 = no hard cutoff

    if not (IsValid(listener) and IsValid(speaker)) then return false end

    return listener:GetPos():DistToSqr(speaker:GetPos()) <= (range * range)
end

--- Given a speaker entity and a table of candidate players, return only those
--- within proximity range.  Respects the teamOnly flag for team voice rules.
---@param speaker Player       the bot or player that is speaking
---@param candidates table     array of Player entities
---@param teamOnly boolean|nil whether this is team-only speech
---@return table               filtered array of Players within range
function TTTBots.Proximity.FilterRecipients(speaker, candidates, teamOnly)
    if not TTTBots.Proximity.IsActive() then return candidates end

    local filtered = {}
    for _, ply in ipairs(candidates) do
        if TTTBots.Proximity.CanHear(ply, speaker, teamOnly) then
            table.insert(filtered, ply)
        end
    end
    return filtered
end

--- Build a CRecipientFilter containing only human players within proximity
--- range of the speaker.  Used for net.Send() calls (TTS audio, URL mode).
--- Falls back to all human players if proximity is not active.
---@param speaker Player
---@param teamOnly boolean|nil
---@return table  array of Player entities to send to
function TTTBots.Proximity.GetHumanRecipients(speaker, teamOnly)
    local humans = player.GetHumans()
    if not TTTBots.Proximity.IsActive() then return humans end

    local recipients = {}
    for _, ply in ipairs(humans) do
        if IsValid(ply) and TTTBots.Proximity.CanHear(ply, speaker, teamOnly) then
            table.insert(recipients, ply)
        end
    end
    return recipients
end

print("[TTT Bots 2] Proximity chat integration loaded.")
