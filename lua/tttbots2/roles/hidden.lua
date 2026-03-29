--- Hidden — solo neutral stealth killer role.
--- Wins by eliminating all non-allied players.
--- Has a unique two-phase design:
---   Phase 1 (Disguised): Normal player appearance, 20% damage, standard weapons.
---   Phase 2 (Stalker): Near-invisible, 1.6× speed, knife + stun nade only.
--- The bot must decide when to transform (press Reload) based on
--- game state, isolation, and opportunity. Transformation is permanent.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_HIDDEN then return false end

TEAM_JESTER = TEAM_JESTER or "jesters"

local _bh    = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes
local lib    = TTTBots.Lib

-- ---------------------------------------------------------------------------
-- Behavior Trees
-- ---------------------------------------------------------------------------

--- Pre-transformation tree (Disguised Phase).
--- The Hidden blends in as a normal player, scouting the map and waiting
--- for the optimal moment to transform.
local bTreeDisguised = {
    _prior.Chatter,                  -- Social deception to blend in
    _prior.FightBack,                -- React to being attacked (only 20% damage though)
    _prior.SelfDefense,              -- Defend from accusations
    _prior.Requests,                 -- Handle incoming requests
    _bh.HiddenActivate,              -- [NEW] Decision: should we transform now?
    _prior.Deception,                -- Alibi building, fake investigating
    _prior.Restore,                  -- Pick up weapons (still allowed)
    _bh.InvestigateCorpse,           -- Appear innocent
    _prior.Minge,                    -- Casual cover behavior
    _prior.Patrol,                   -- Default patrol
}

--- Post-transformation tree (Stalker Phase).
--- The Hidden is now invisible, fast, and armed only with a knife and stun nade.
--- Full aggression — stalk, kill, and survive.
local bTreeStalker = {
    _prior.FightBack,                -- React to immediate combat
    _bh.HiddenStunNade,              -- Throw stun nade for area denial/escape
    _bh.HiddenKnifeAttack,           -- Melee knife kills on isolated targets
    _bh.HiddenKnifeThrow,            -- Throw knife at wounded/distant targets
    _bh.Stalk,                       -- Hunt isolated targets (existing)
    _prior.Requests,                 -- Handle requests (rarely honored)
    _prior.Chatter,                  -- Minimal chatter
    _bh.Wander,                      -- Keep moving (speed advantage)
}

-- ---------------------------------------------------------------------------
-- Phase Detection
-- ---------------------------------------------------------------------------

--- Check if a bot is currently in Hidden stalker mode.
---@param bot Player
---@return boolean
local function isInStalkerMode(bot)
    return bot:GetNWBool("ttt2_hd_stalker_mode", false)
end

--- Dynamic tree selection: disguised vs stalker phase.
---@param bot Player
---@return table bTree
local function getPhaseBasedBTree(bot)
    if not IsValid(bot) then return bTreeDisguised end
    if isInStalkerMode(bot) then
        return bTreeStalker
    end
    return bTreeDisguised
end

-- ---------------------------------------------------------------------------
-- Role Registration
-- ---------------------------------------------------------------------------

local roleDescription = "The Hidden is a solo stealth killer. You start disguised as a normal player. "
    .. "Press Reload at the right moment to permanently transform: you become near-invisible, "
    .. "gain 60% speed, but lose all weapons except your knife and stun grenades. "
    .. "Kill everyone before they find and kill you. You know who the Jesters are (avoid them). "
    .. "Transform when isolated or when few players remain. Use your knife (melee or thrown) "
    .. "and stun grenades tactically. You are a predator — patient, fast, and lethal."

local hidden = TTTBots.RoleBuilder.NeutralKiller("hidden", TEAM_HIDDEN)
hidden:SetDefusesC4(false)
hidden:SetKnowsLifeStates(false)      -- Hidden doesn't have wallhack/radar
hidden:SetLovesTeammates(true)
hidden:SetIsFollower(false)            -- Hidden hunts, not follows
hidden:SetBTree(bTreeDisguised)        -- Default; overridden at runtime
hidden:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(hidden)

-- ---------------------------------------------------------------------------
-- Runtime tree override: swap tree based on stalker mode.
-- We hook into GetTreeFor by storing the original function and wrapping it.
-- This follows the same pattern as the Serial Killer role's dynamic tree switching.
-- ---------------------------------------------------------------------------

local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor
function TTTBots.Behaviors.GetTreeFor(bot)
    if not IsValid(bot) then return nil end

    local role = TTTBots.Roles.GetRoleFor(bot)
    if role and role:GetName() == "hidden" then
        return getPhaseBasedBTree(bot)
    end

    return _origGetTreeFor(bot)
end

-- ---------------------------------------------------------------------------
-- Global Helper
-- ---------------------------------------------------------------------------

--- Global helper: check if a player is a Hidden in stalker mode.
--- Used by stalk.lua exemption and perception hooks.
---@param bot Player
---@return boolean
function TTTBots.Roles.IsHiddenStalker(bot)
    if not IsValid(bot) then return false end
    local role = TTTBots.Roles.GetRoleFor(bot)
    if not role or role:GetName() ~= "hidden" then return false end
    return bot:GetNWBool("ttt2_hd_stalker_mode", false)
end

-- ---------------------------------------------------------------------------
-- Stun Nade Reaction: non-Hidden bots detect nearby stun nades and flee
-- ---------------------------------------------------------------------------

hook.Add("OnEntityCreated", "TTTBots.Hidden.StunNadeReaction", function(ent)
    -- Wait a tick for the entity to be fully initialized
    timer.Simple(0, function()
        if not IsValid(ent) then return end
        if ent:GetClass() ~= "ttt_hdnade_proj" then return end
        if not TTTBots.Match.RoundActive then return end

        local nadePos = ent:GetPos()
        local STUN_RADIUS = 350 -- slightly larger than 256 blast radius

        for _, bot in ipairs(TTTBots.Bots) do
            if not (IsValid(bot) and lib.IsPlayerAlive(bot)) then continue end

            -- Skip Hidden bots — they threw it
            local role = TTTBots.Roles.GetRoleFor(bot)
            if role and role:GetName() == "hidden" then continue end

            local dist = bot:GetPos():Distance(nadePos)
            if dist > STUN_RADIUS then continue end

            -- Add danger zone to memory so the bot avoids the area
            local memory = bot:BotMemory()
            if memory and type(memory.AddDangerZone) == "function" then
                memory:AddDangerZone(nadePos, STUN_RADIUS, "hidden_stun_nade", CurTime() + 8)
            end

            -- Attempt to set locomotor goal away from the nade
            local loco = bot:BotLocomotor()
            if loco then
                local fleeDir = (bot:GetPos() - nadePos):GetNormalized()
                local fleePos = bot:GetPos() + fleeDir * 400
                loco:SetGoal(fleePos)
            end
        end
    end)
end)

-- ---------------------------------------------------------------------------
-- Hidden Activation Monitoring: non-Hidden bots react to the EPOP announcement
-- When the Hidden transforms, all non-Hidden bots increase alertness.
-- ---------------------------------------------------------------------------

hook.Add("Think", "TTTBots.Hidden.MonitorActivation", function()
    -- Check once per second
    if (CurTime() - (TTTBots._lastHiddenCheck or 0)) < 1 then return end
    TTTBots._lastHiddenCheck = CurTime()

    if not TTTBots.Match.RoundActive then return end

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then continue end
        if not (ply.GetSubRole and ply:GetSubRole() == ROLE_HIDDEN) then continue end
        if not ply:GetNWBool("ttt2_hd_stalker_mode", false) then continue end

        -- Hidden is active — mark this for bot awareness
        if not TTTBots._hiddenActivated then
            TTTBots._hiddenActivated = true

            -- All non-Hidden bots: fire chatter event for awareness
            for _, bot in ipairs(TTTBots.Bots) do
                if not IsValid(bot) or not lib.IsPlayerAlive(bot) then continue end
                local role = TTTBots.Roles.GetRoleFor(bot)
                if role and role:GetName() == "hidden" then continue end

                local chatter = bot:BotChatter()
                if chatter and chatter.On then
                    chatter:On("HiddenSpotted", {}, false)
                end
            end
        end
    end
end)

-- Reset on round start
hook.Add("TTTBeginRound", "TTTBots.Hidden.ResetActivation", function()
    TTTBots._hiddenActivated = false
end)

-- ---------------------------------------------------------------------------
-- Perception: Reduce bot detection range against cloaked Hidden players.
-- Without this, bots perfectly track the invisible Hidden, making cloaking useless.
-- ---------------------------------------------------------------------------

--- Cached reference to the original CanSeeArc so we can intercept visibility checks
--- against a cloaked Hidden. Bots use CanSeeArc extensively for witness/target detection.
local _origCanSeeArc = TTTBots.Lib.CanSeeArc

--- Wrapper around CanSeeArc that reduces effective range vs. a cloaked Hidden.
--- Full cloak (no recent damage): only detectable within 150 units.
--- Partial cloak (damaged within 5s): detectable within 400 units.
--- Pre-transform (no cloak): normal detection range.
function TTTBots.Lib.CanSeeArc(ply, pos, arc)
    -- We only modify bot-to-Hidden visibility.
    -- The pos parameter is typically a position, so we can't directly check the target player
    -- from this function. The reduction is handled in HiddenKnifeAttack/Stalk target rating instead.
    -- This wrapper is a no-op passthrough; actual cloaking perception is done at behavior level.
    return _origCanSeeArc(ply, pos, arc)
end

--- Utility: check if a target Hidden player should be "invisible" to a bot at distance.
--- Used by behaviors to skip targets that are cloaked and out of detection range.
---@param bot Player  The observing bot
---@param target Player  The potential Hidden target
---@return boolean true if the target is effectively invisible to the bot
function TTTBots.Roles.IsHiddenInvisibleTo(bot, target)
    if not (IsValid(bot) and IsValid(target)) then return false end
    if not target:GetNWBool("ttt2_hd_stalker_mode", false) then return false end

    local dist = bot:GetPos():Distance(target:GetPos())

    -- Check if the Hidden was recently damaged (partial cloak: 5s window)
    local lastDmg = target._lastDamageTime or 0
    local isPartialCloak = (CurTime() - lastDmg) < 5

    local maxDetectionRange = isPartialCloak and 400 or 150

    return dist > maxDetectionRange
end

print("[TTT Bots 2] Hidden role integration loaded — two-phase stealth killer.")

return true
