--- Defective role integration for TTT Bots 2
--- The Defective is a traitor who appears to everyone as a Detective (or other
--- detective sub-role). They can use the DNA scanner, traitor buttons, and the
--- detective shop. No other traitor can see the Defective's true identity until
--- certain conditions are met (configured by server convars).
---
--- Bot behavior:
---   • TraitorLike builder — fights, coordinates with traitors, uses shop
---   • Deception blend: alibi-building and fake-investigating are prioritized
---   • unknownTeam: applies suspicion normally (disguised as detective)
---   • isOmniscientRole: knows MIA/life states like any traitor
---   • Uses DNA scanner just like a real detective (equipped via GiveRoleLoadout)
---   • On death the suspicion hook fires with a low multiplier (suspected detective)

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DEFECTIVE then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

-- The Defective plays like a traitor but needs to blend in convincingly as a detective.
-- Use DNA scanner behavior and fake-investigating to sell the disguise.
local bTree = {
    _prior.Chatter,             -- Social chatter for cover
    _prior.FightBack,           -- Defend if attacked
    _prior.Requests,            -- Handle requests
    _bh.FakeInvestigate,        -- Pretend to investigate corpses (detective cover)
    _bh.AlibiBbuilding,         -- Build alibis like an innocent
    _prior.Traitor,             -- Core traitor actions (coordinate, plant C4, etc.)
    _bh.UseDNAScanner,          -- Use DNA scanner (given by role loadout)
    _bh.InvestigateCorpse,      -- Investigate corpses for intel
    _prior.Restore,
    _prior.Investigate,
    _prior.Patrol,
}

local roleDescription = "You are the Defective, a traitor who appears to everyone as a Detective. "
    .. "You have the DNA scanner and detective shop access. Blend in as a detective: investigate corpses, "
    .. "use the DNA scanner, and act authoritative. Coordinate with fellow traitors secretly. "
    .. "Your disguise is your greatest weapon — stay in character as long as possible."

local defective = TTTBots.RoleData.New("defective", TEAM_TRAITOR)
defective:SetDefusesC4(false)
defective:SetPlantsC4(true)
defective:SetTeam(TEAM_TRAITOR)
defective:SetBTree(bTree)
defective:SetCanCoordinate(true)
defective:SetCanHaveRadar(true)
defective:SetStartsFights(true)
defective:SetUsesSuspicion(true)        -- Acts suspicious like a real traitor
defective:SetKOSUnknown(false)          -- unknownTeam is server-side; bot sees as traitor
defective:SetKnowsLifeStates(true)      -- isOmniscientRole
defective:SetLovesTeammates(false)      -- Hidden from traitors depending on convars
defective:SetAlliedTeams({ [TEAM_TRAITOR] = true })
defective:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(defective)

-- ---------------------------------------------------------------------------
-- Suspicion hook: The Defective shows as a detective to the world.
-- Lower suspicion slightly — they seem trustworthy (detective-like).
-- ---------------------------------------------------------------------------
hook.Add("TTTBotsModifySuspicion", "TTTBots.defective.sus", function(bot, target, reason, mult)
    if not IsValid(target) then return end
    local role = target:GetRoleStringRaw()
    if role == "defective" then
        -- Appears as a detective; other bots should trust them a bit more
        return mult * 0.5
    end
end)

return true
