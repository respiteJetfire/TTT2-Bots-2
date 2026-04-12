--- Mayor role integration for TTT Bots 2
--- The Mayor is an omniscient, public-facing, policing Detective sub-role on TEAM_INNOCENT.
--- Key mechanics:
---   • isPublicRole + isPolicingRole: everyone knows the Mayor and takes them seriously
---   • isOmniscientRole: full MIA/life-state awareness
---   • unknownTeam: uses suspicion system
---   • SHOP_FALLBACK_DETECTIVE: has access to detective shop
---   • After a random delay, the Mayor gets a private "tip" naming one player's role
---     (via ttt2_mayor_message net message) — this is server-driven and repeats
---
--- Bot behavior:
---   • DetectiveLike builder — investigate corpses, use DNA scanner, police the map
---   • Public authority figure with omniscient awareness
---   • The intel tip is fed into the bot's evidence system when the Mayor's NW
---     data is updated, giving the bot actionable suspicion intel.
---   • As a public policing figure, the Mayor is more aggressive about accusing
---     and calling KOS based on evidence.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_MAYOR then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local roleDescription =
    "You are the Mayor, a public-facing detective authority figure. "
    .. "Everyone knows who you are. You receive periodic tips about player roles. "
    .. "Use your tips and detective tools to identify and eliminate traitors. "
    .. "You are a high-value target — stay guarded and act on your intelligence quickly."

-- Custom detective tree with emphasis on accusation and corpse investigation
local bTree = {
    _bh.EvadeGravityMine,
    _prior.FightBack,
    _prior.SelfDefense,
    _prior.Chatter,
    _prior.Grenades,
    _prior.Requests,
    _prior.Accuse,              -- Mayor should accuse early and often based on tips
    _bh.InvestigateCorpse,      -- Priority: ID bodies for intel
    _prior.DNAScanner,          -- Core detective work
    _prior.Convert,
    _prior.Restore,
    _bh.FollowInnocentPlan,
    _prior.Support,
    _prior.TacticalEquipment,
    _bh.Defuse,
    _bh.ActiveInvestigate,
    _bh.Interact,
    _prior.Minge,
    _prior.Investigate,
    _bh.Decrowd,
    _prior.Patrol,
}

local mayor = TTTBots.RoleBuilder.DetectiveLike("mayor")
mayor:SetBTree(bTree)
mayor:SetKnowsLifeStates(true)     -- isOmniscientRole
mayor:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(mayor)

-- ---------------------------------------------------------------------------
-- Mayor Tip Intelligence: periodically check the Mayor's NW data for tips
-- about player roles and feed them into the bot's evidence/suspicion system.
-- The addon sets NW strings like "ttt2_mayor_tip_name" / "ttt2_mayor_tip_role"
-- or stores data in ply.mayor_tips.
-- ---------------------------------------------------------------------------
local _lastTipCheck = 0
local _processedTips = {}

hook.Add("Think", "TTTBots.Mayor.TipIntel", function()
    if not TTTBots.Match.IsRoundActive() then return end
    if CurTime() < _lastTipCheck then return end
    _lastTipCheck = CurTime() + 3 -- Check every 3 seconds

    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and bot:IsBot()) then continue end
        if not ROLE_MAYOR then continue end
        if bot:GetSubRole() ~= ROLE_MAYOR then continue end
        if not bot:Alive() then continue end

        -- Try to read tip data from NW vars or the addon's data table
        local tipTarget = bot:GetNWEntity("mayor_tip_target", NULL)
        local tipRole = bot:GetNWString("mayor_tip_role", "")

        if IsValid(tipTarget) and tipRole ~= "" then
            local tipKey = tostring(tipTarget) .. "_" .. tipRole
            if _processedTips[tipKey] then continue end
            _processedTips[tipKey] = true

            -- Feed the tip into evidence system
            local evidence = bot.BotEvidence and bot:BotEvidence()
            if evidence then
                -- Hostile role tips generate high suspicion
                local isHostile = (tipRole == "traitor" or tipRole == "hitman"
                    or tipRole == "vampire" or tipRole == "executioner"
                    or tipRole == "serialkiller" or tipRole == "necromancer"
                    or tipRole == "infected")
                local weight = isHostile and 80 or -20
                evidence:AddEvidence({
                    type    = "MAYOR_TIP",
                    subject = tipTarget,
                    detail  = "Mayor tip: " .. tipTarget:Nick() .. " is " .. tipRole,
                    weight  = weight,
                })
            end

            -- Announce the tip via chatter
            local chatter = bot:BotChatter()
            if chatter and chatter.On then
                chatter:On("MayorTipReceived", {
                    player = tipTarget:Nick(),
                    playerEnt = tipTarget,
                }, false)
            end
        end
    end
end)

-- Reset processed tips on round start
hook.Add("TTTBeginRound", "TTTBots.Mayor.ResetTips", function()
    _processedTips = {}
end)

print("[TTT Bots 2] Mayor role integration loaded — intel-driven detective authority.")
return true
