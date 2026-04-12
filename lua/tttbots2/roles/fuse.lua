--- Fuse role integration for TTT Bots 2
--- The Fuse is a traitor sub-role on TEAM_TRAITOR. They have a countdown
--- timer: if it expires without a kill, they explode (dealing 200 damage
--- in a 300-unit radius). Each kill resets the timer. The explosion auto-
--- restarts the countdown. isOmniscientRole.
---
--- Bot behavior:
---   • TraitorLike builder — fights, coordinates, uses shop
---   • Extremely aggressive: MUST kill within the timer window
---   • isOmniscientRole: full life-state knowledge
---   • Timer pressure drives urgency — Stalk is kept very high priority
---   • FightBack / attack at top to minimize time between kills

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_FUSE then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.FightBack,           -- React instantly — delay costs time
    _prior.Traitor,             -- Coordinate with other traitors
    _bh.Stalk,                  -- Aggressively hunt targets (timer pressure)
    _prior.Requests,
    _prior.Restore,
    _prior.Patrol,
}

local roleDescription = "You are the Fuse, a traitor sub-role. You have a countdown timer: if it "
    .. "expires without you getting a kill, you explode. Each kill resets the timer. "
    .. "You must kill frequently to stay alive. Coordinate with traitors but prioritize "
    .. "getting kills above all else — the clock is always ticking."

-- Use TraitorLike as the foundation for traitor defaults
local fuse = TTTBots.RoleBuilder.TraitorLike("fuse", TEAM_TRAITOR)
fuse:SetBTree(bTree)
fuse:SetKnowsLifeStates(true)       -- isOmniscientRole
fuse:SetStartsFights(true)           -- Must fight to survive
fuse:SetCanHide(false)               -- No time to hide
fuse:SetCanSnipe(false)              -- Close-range is faster
fuse:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(fuse)

-- ---------------------------------------------------------------------------
-- Timer-based aggression: Fuse bot becomes increasingly desperate as the
-- countdown timer approaches zero. The Fuse addon typically stores the
-- remaining time as a NWFloat or NWInt.
-- ---------------------------------------------------------------------------
local _nextFuseCheck = 0
hook.Add("Think", "TTTBots.Fuse.TimerPressure", function()
    if not TTTBots.Match.IsRoundActive() then return end
    if CurTime() < _nextFuseCheck then return end
    _nextFuseCheck = CurTime() + 1

    for _, bot in ipairs(TTTBots.Bots or {}) do
        if not (IsValid(bot) and bot:IsBot() and bot:Alive()) then continue end
        if bot:GetSubRole() ~= ROLE_FUSE then continue end

        local personality = bot.BotPersonality and bot:BotPersonality()
        if not personality then continue end

        -- Try to read the fuse timer from NW data
        local fuseTime = bot:GetNWFloat("fuse_timer", -1)
        if fuseTime < 0 then
            fuseTime = bot:GetNWFloat("ttt2_fuse_timer", -1)
        end
        if fuseTime < 0 then
            fuseTime = bot:GetNWInt("fuse_timer", -1)
        end

        if fuseTime >= 0 then
            -- Scale aggression based on remaining time
            -- <5s = PANIC (1.0), <15s = URGENT (0.9), <30s = HIGH (0.8), else = NORMAL (0.7)
            local aggression = 0.7
            if fuseTime < 5 then
                aggression = 1.0
            elseif fuseTime < 15 then
                aggression = 0.9
            elseif fuseTime < 30 then
                aggression = 0.8
            end
            personality:SetAggression(aggression)
        else
            -- Fallback: always be highly aggressive (timer is ticking)
            personality:SetAggression(0.85)
        end
    end
end)

print("[TTT Bots 2] Fuse role integration loaded — timer-based aggression escalation.")
return true
