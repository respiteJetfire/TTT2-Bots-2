if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DEFECTOR then return false end

TEAM_JESTER = TEAM_JESTER or 'jesters'

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local allyTeams = {
    [TEAM_TRAITOR] = true,
    [TEAM_JESTER] = true,
}

--- The defector is a suicide-bomber traitor role that cannot deal gun damage.
--- Its behavior tree is heavily oriented toward deception/blending (appearing
--- innocent) and approaching enemy clusters before detonating the jihad bomb.
--- DefectorApproach seeks out optimal enemy clusters; Jihad validates and
--- triggers the bomb. Deception behaviors (AlibiBuilding, FakeInvestigate, etc.)
--- maintain the defector's innocent cover until the moment of detonation.
local bTree = {
    _prior.Requests,
    _prior.Chatter,
    _bh.DefectorApproach,
    _bh.Jihad,
    _prior.SelfDefense,
    _prior.Accuse,
    _prior.Deception,
    _prior.Restore,
    _prior.Investigate,
    _prior.Minge,
    _prior.Patrol,
}

local roleDescription = "The Defector is a traitor role with one single objective: blow themselves and their enemies up in a suicide attack using the famed Jihad bomb. The Defector cannot deal gun damage — only explosive damage works. Be careful not to take out your own teammates in the blast!"

local defector = TTTBots.RoleData.New("defector", TEAM_TRAITOR)
defector:SetDefusesC4(false)
defector:SetPlantsC4(false)
defector:SetCanHaveRadar(false)     -- Defector has 0 credits, cannot buy radar
defector:SetCanCoordinate(false)
defector:SetStartsFights(false)     -- Cannot deal gun damage — never starts fights
defector:SetTeam(TEAM_TRAITOR)
defector:SetAutoSwitch(false)       -- Never auto-switch weapons; keep jihad equipped when ready
defector:SetCanSnipe(false)         -- Cannot snipe — gun damage is zero
defector:SetCanHide(true)           -- Should blend with innocents
defector:SetBuyableWeapons("weapon_ttt_jihad_bomb")
defector:SetUsesSuspicion(false)
defector:SetIsFollower(true)        -- Follow crowds to blend in
defector:SetBTree(bTree)
defector:SetAlliedTeams(allyTeams)
defector:SetLovesTeammates(true)
defector:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(defector)

--- Mid-round conversion detection: when a bot is converted to defector via the
--- drop-and-pickup mechanism, this hook fires and initializes their bot state.
hook.Add("TTT2UpdateSubrole", "TTTBots_DefectorConversion", function(ply, oldSubrole, newSubrole)
    if not IsValid(ply) then return end
    if not ply:IsBot() then return end
    if newSubrole ~= ROLE_DEFECTOR then return end

    -- The player was just converted to defector mid-round.
    -- Force the bot to re-evaluate its behavior tree so it picks up the defector tree.
    ply.lastBehavior = nil

    -- Fire chatter event for the conversion
    local chatter = ply:BotChatter()
    if chatter and chatter.On then
        chatter:On("DefectorConverted", {})
    end
end)

return true
