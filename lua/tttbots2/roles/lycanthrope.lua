--- Lycanthrope role integration for TTT Bots 2
--- The Lycanthrope is an Innocent that transforms when all teammates die:
---   Phase 1 (Normal): Plays as a standard Innocent. Their role may not even
---     be visible to them (ttt2_lyc_know_role = 0 by default).
---   Phase 2 (Unleashed): When LycTransformed NWBool becomes true:
---     - Max HP → 150, gains 30 armor.
---     - 1.5× speed, 1.5× stamina, 1.5× damage dealt.
---     - Regenerates 2 HP every 0.5s (after 5s delay from last damage).
---     - Still wins with Innocents (traitors must die).
---
--- Bot strategy:
---   • Phase 1: Play exactly like a standard Innocent.
---   • Phase 2: Switch to aggressive behavior — hunt traitors with speed advantage
---     and health regen. Use regen to tank more hits.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_LYCANTHROPE then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- Phase 1: Standard Innocent tree
local normalTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _prior.Support,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol,
}

-- Phase 2: Unleashed — aggressive hunter
local unleashTree = {
    _prior.Chatter,
    _prior.FightBack,
    _prior.Requests,
    _bh.Stalk,              -- Hunt traitors aggressively (1.5× speed advantage)
    _prior.Support,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol,
}

local lycDesc =
    "You are the Lycanthrope, an innocent-team role with a hidden transformation. "
    .. "While any of your innocent teammates are alive, you play as a normal innocent. "
    .. "When you are the LAST surviving innocent, you unleash your true form: "
    .. "you gain bonus max health, armor, 1.5× speed, 1.5× damage, and health regeneration. "
    .. "In your unleashed form, hunt traitors aggressively — your speed advantage makes "
    .. "you nearly impossible to outrun, and your regen lets you take risks in combat."

local lyc = TTTBots.RoleData.New("lycanthrope")
lyc:SetDefusesC4(true)
lyc:SetPlantsC4(false)
lyc:SetTeam(TEAM_INNOCENT)
lyc:SetBTree(normalTree)
lyc:SetCanCoordinate(true)
lyc:SetCanHaveRadar(false)
lyc:SetStartsFights(false)
lyc:SetUsesSuspicion(true)
lyc:SetCanSnipe(true)
lyc:SetCanHide(true)
lyc:SetKOSUnknown(false)
lyc:SetLovesTeammates(true)
lyc:SetAlliedTeams({ [TEAM_INNOCENT] = true })
lyc:SetRoleDescription(lycDesc)
TTTBots.Roles.RegisterRole(lyc)

-- ---------------------------------------------------------------------------
-- Runtime tree override: swap tree when Lycanthrope transforms.
-- ---------------------------------------------------------------------------
local _origGetTreeFor = TTTBots.Behaviors.GetTreeFor
function TTTBots.Behaviors.GetTreeFor(bot)
    if not IsValid(bot) then return nil end

    if ROLE_LYCANTHROPE and bot:GetSubRole() == ROLE_LYCANTHROPE then
        if bot:GetNWBool("LycTransformed", false) then
            return unleashTree
        else
            return normalTree
        end
    end

    return _origGetTreeFor(bot)
end

-- ---------------------------------------------------------------------------
-- Transform hook: when a Lycanthrope bot transforms, react with chatter
-- and immediately start hunting.
-- ---------------------------------------------------------------------------
hook.Add("TTTBots.LycanthropyTransformed", "TTTBots.Lycanthrope.OnTransform",
    function(lycBot)
        if not (IsValid(lycBot) and lycBot:IsBot()) then return end
        if not ROLE_LYCANTHROPE then return end

        local chatter = lycBot:BotChatter()
        if chatter and chatter.On then
            chatter:On("LycanthropeUnleashed", {}, false)
        end
    end
)

-- Fallback: poll LycTransformed each round since some addons don't fire a hook
hook.Add("Think", "TTTBots.Lycanthrope.PollTransform", function()
    if not TTTBots.Match.IsRoundActive() then return end

    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and bot:IsBot()) then continue end
        if not ROLE_LYCANTHROPE then continue end
        if bot:GetSubRole() ~= ROLE_LYCANTHROPE then continue end

        local transformed = bot:GetNWBool("LycTransformed", false)
        if transformed and not bot._lycWasTransformed then
            bot._lycWasTransformed = true
            hook.Run("TTTBots.LycanthropyTransformed", bot)
        elseif not transformed then
            bot._lycWasTransformed = false
        end
    end
end)

hook.Add("TTTBeginRound", "TTTBots.Lycanthrope.Reset", function()
    for _, bot in ipairs(TTTBots.Bots or {}) do
        if IsValid(bot) then
            bot._lycWasTransformed = false
        end
    end
end)

print("[TTT Bots 2] Lycanthrope role integration loaded.")
return true
