--- Link role integration for TTT Bots 2
--- Link is an omniscient, public-facing, policing Detective sub-role
--- themed after The Legend of Zelda's Link.
--- Key mechanics:
---   • isPublicRole + isPolicingRole: everyone knows the Link
---   • isOmniscientRole: full MIA/life-state awareness
---   • unknownTeam = true — hidden alignment
---   • SHOP_FALLBACK_DETECTIVE: detective shop access
---   • Receives weapon_mastersword on loadout (if ttt2_link_msword_start is enabled)
---   • Gains extra HP and armor from convars (ttt2_link_max_health, ttt2_link_armor)
---   • Scores heavily for kills (8×), penalized for team kills (−8×)
---   • Credits awarded on enemy death
---   • Plays the Zelda theme on spawn
---
--- Bot behavior:
---   • DetectiveLike builder — investigate corpses, use DNA scanner, police the map
---   • Prefers melee (master sword) when available — close-range engagements
---   • Omniscient public authority; no hidden coordination needed

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_LINK then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- Melee-focused detective tree: Link has the Master Sword and high HP/armor.
-- Prioritize Stalk for proactive engagement, plus standard detective duties.
local bTree = {
    _prior.Chatter,
    _prior.FightBack,           -- React to combat with sword
    _prior.Accuse,              -- Detective accusation authority
    _prior.Requests,
    _prior.Support,
    _bh.Stalk,                  -- Proactively hunt traitors (melee range)
    _bh.ActiveInvestigate,      -- Actively seek evidence
    _prior.Restore,
    _bh.Defuse,
    _bh.Interact,
    _prior.Investigate,
    _bh.Decrowd,
    _prior.Patrol,
}

local roleDescription = "You are Link, a legendary public detective hero. You have a Master Sword for melee combat "
    .. "and high HP/armor. You are omniscient (know all life states). Score 8x for kills, -8x for team kills. "
    .. "Use your sword for close-range engagements and your detective authority to lead the investigation. "
    .. "Actively hunt traitors — your durability makes you an unstoppable force."

local link = TTTBots.RoleBuilder.DetectiveLike("link")
link:SetBTree(bTree)
link:SetKnowsLifeStates(true)       -- isOmniscientRole
link:SetStartsFights(true)           -- Proactive melee hunter
link:SetCanSnipe(false)              -- Prefers melee (Master Sword)
link:SetCanHide(false)               -- Tanky; no need to hide
link:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(link)

-- ---------------------------------------------------------------------------
-- Personality: Link is a confident, aggressive detective with high durability.
-- Set aggression high at round start.
-- ---------------------------------------------------------------------------
hook.Add("TTTBeginRound", "TTTBots.Link.SetPersonality", function()
    timer.Simple(1, function()
        for _, bot in ipairs(TTTBots.Bots or {}) do
            if not (IsValid(bot) and bot:IsBot()) then continue end
            if bot:GetSubRole() ~= ROLE_LINK then continue end
            local personality = bot.BotPersonality and bot:BotPersonality()
            if personality then
                personality:SetAggression(0.85) -- Confident melee fighter
            end
        end
    end)
end)

print("[TTT Bots 2] Link role integration loaded — melee-focused omniscient detective.")
return true
