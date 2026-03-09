--- behaviors/cursedimmolate.lua
--- Cursed self-immolation behavior.
--- Allows the Cursed bot to self-immolate (set themselves/corpse on fire)
--- to destroy evidence and reposition on respawn.
--- Sends the native TTT2CursedSelfImmolateRequest net message.

if not (TTT2 and ROLE_CURSED) then return end

---@class BCursedImmolate : BBase
TTTBots.Behaviors.CursedImmolate = {}

local lib = TTTBots.Lib

---@class BCursedImmolate
local CursedImmolate = TTTBots.Behaviors.CursedImmolate
CursedImmolate.Name = "CursedImmolate"
CursedImmolate.Description = "Self-immolates as the Cursed to destroy evidence or reposition."
CursedImmolate.Interruptible = true

local STATUS = TTTBots.STATUS

--- Per-bot cooldown to avoid spamming immolation requests
local lastImmolateTime = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local IMMOLATE_MODE = { NO = 0, CORPSE_ONLY = 1, WHENEVER = 2 }

--- Check if self-immolation is currently useful
---@param bot Player
---@return boolean
local function ShouldImmolate(bot)
    local mode = GetConVar("ttt2_cursed_self_immolate_mode")
        and GetConVar("ttt2_cursed_self_immolate_mode"):GetInt() or 2

    if mode == IMMOLATE_MODE.NO then return false end

    -- Cooldown: don't spam (15 seconds between attempts)
    local lastTime = lastImmolateTime[bot] or 0
    if CurTime() - lastTime < 15 then return false end

    local isAlive = lib.IsPlayerAlive(bot)

    if mode == IMMOLATE_MODE.CORPSE_ONLY and isAlive then return false end

    if isAlive then
        -- When alive, immolate strategically:
        -- 1. When being pursued by multiple enemies and no swap targets nearby
        -- 2. When in a bad position with no escape routes
        local enemies = TTTBots.Roles.GetNonAllies(bot)
        local nearbyEnemies = 0
        local botPos = bot:GetPos()

        for _, enemy in ipairs(enemies or {}) do
            if IsValid(enemy) and lib.IsPlayerAlive(enemy) then
                if botPos:Distance(enemy:GetPos()) < 400 then
                    nearbyEnemies = nearbyEnemies + 1
                end
            end
        end

        -- Immolate when surrounded by enemies (repositioning strategy)
        return nearbyEnemies >= 2
    end

    -- When dead, always try to immolate corpse (evidence destruction)
    return true
end

-- ---------------------------------------------------------------------------
-- Behavior Lifecycle
-- ---------------------------------------------------------------------------

function CursedImmolate.Validate(bot)
    if bot:GetSubRole() ~= ROLE_CURSED then return false end
    if not TTTBots.Match.IsRoundActive() then return false end

    -- The preventWin check ensures the Cursed hasn't already swapped
    local roleData = bot:GetSubRoleData()
    if roleData and not roleData.preventWin then return false end

    return ShouldImmolate(bot)
end

function CursedImmolate.OnStart(bot)
    -- Fire chatter only when alive (corpse immolation is silent)
    if lib.IsPlayerAlive(bot) then
        local chatter = bot:BotChatter()
        if chatter and chatter.On then
            chatter:On("CursedSelfImmolate", {})
        end
    end
    return STATUS.RUNNING
end

function CursedImmolate.OnRunning(bot)
    -- Send the native immolation request
    -- Bots are server-side, so we call the same logic the net.Receive handler uses
    local mode = GetConVar("ttt2_cursed_self_immolate_mode")
        and GetConVar("ttt2_cursed_self_immolate_mode"):GetInt() or 2

    if bot:GetSubRole() ~= ROLE_CURSED or mode == IMMOLATE_MODE.NO then
        return STATUS.FAILURE
    end

    local isAlive = lib.IsPlayerAlive(bot)
    if mode == IMMOLATE_MODE.CORPSE_ONLY and isAlive then
        return STATUS.FAILURE
    end

    local plyOrCorpse = bot
    if not isAlive then
        -- Find the bot's corpse
        if bot.FindCorpse then
            plyOrCorpse = bot:FindCorpse()
        else
            -- Fallback: search for corpse entities
            for _, ent in ipairs(ents.FindByClass("prop_ragdoll")) do
                if ent.sid64 and ent.sid64 == bot:SteamID64() then
                    plyOrCorpse = ent
                    break
                end
            end
        end

        if not IsValid(plyOrCorpse) then
            return STATUS.FAILURE
        end
    end

    -- Use the IgniteTarget function if available (same as the addon uses)
    if IgniteTarget then
        local path = { Entity = plyOrCorpse }
        local dmgInfo = DamageInfo()
        dmgInfo:SetAttacker(bot)
        dmgInfo:SetInflictor(bot)
        IgniteTarget(bot, path, dmgInfo)
    elseif IsValid(plyOrCorpse) and plyOrCorpse.Ignite then
        -- Fallback: direct ignite
        plyOrCorpse:Ignite(8, 0)
    end

    lastImmolateTime[bot] = CurTime()
    return STATUS.SUCCESS
end

function CursedImmolate.OnSuccess(bot)
end

function CursedImmolate.OnFailure(bot)
end

function CursedImmolate.OnEnd(bot)
    TTTBots.Behaviors.ClearState(bot, "CursedImmolate")
end

-- Cleanup on round end
hook.Add("TTTEndRound", "TTTBots.CursedImmolate.Cleanup", function()
    lastImmolateTime = {}
end)
