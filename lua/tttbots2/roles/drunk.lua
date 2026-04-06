--- Drunk role integration for TTT Bots 2
--- The Drunk starts as a neutral with no allegiances. When a player dies there
--- is a chance the Drunk "remembers" their true role (TTT2UpdateSubrole fires,
--- changing them to a random dead player's role).
---
--- Bot strategy:
---   • Pre-reveal: completely passive — wanders, defibs allies, minges.
---     Does NOT start fights (no KOS, no suspicion).
---   • TTT2UpdateSubrole hook: when the bot's role changes away from ROLE_DRUNK,
---     it immediately hands off to the revealed role's registered RoleData tree.
---     The bot's BTree and team flags are refreshed in-place so it starts
---     behaving correctly as the new role on the very next tick.

if not TTTBots.Lib.IsTTT2() then return false end
if not ROLE_DRUNK then return false end

local _bh = TTTBots.Behaviors
local _prior = TTTBots.Behaviors.PriorityNodes

local bTree = {
    _prior.Chatter,
    _prior.Support,
    _prior.FightBack,
    _prior.Requests,
    _bh.Defib,
    _bh.Defuse,
    _prior.Restore,
    _bh.Interact,
    _prior.Investigate,
    _prior.Minge,
    _bh.Decrowd,
    _prior.Patrol
}

local roleDescription =
    "The Drunk starts as a neutral with no team. When a player dies the Drunk "
    .. "may remember their true role and switch to it. Bots are fully passive "
    .. "until the reveal, then immediately adopt the revealed role's behaviour tree."

local drunk = TTTBots.RoleData.New("drunk", TEAM_DRUNK)
drunk:SetDefusesC4(false)
drunk:SetStartsFights(false)
drunk:SetTeam(TEAM_DRUNK)
drunk:SetKOSUnknown(false)
drunk:SetBTree(bTree)
drunk:SetRoleDescription(roleDescription)
TTTBots.Roles.RegisterRole(drunk)

-- ---------------------------------------------------------------------------
-- Role-reveal hook: when the Drunk's subrole changes (they "remembered" their
-- role), look up the revealed role's RoleData and hot-swap the bot's tree.
-- ---------------------------------------------------------------------------
hook.Add("TTT2UpdateSubrole", "TTTBots.Drunk.RoleReveal",
    function(ply, oldRole, newRole)
        if not (IsValid(ply) and ply:IsBot()) then return end
        if oldRole ~= ROLE_DRUNK then return end
        if newRole == ROLE_DRUNK then return end

        -- Give the addon a tick to finish updating team / NW vars
        timer.Simple(0.2, function()
            if not (IsValid(ply) and ply:IsActive()) then return end

            -- Find the registered RoleData for the revealed role
            local roleStr = ply:GetRoleStringRaw()
            local revealedData = TTTBots.Roles.GetRoleData(roleStr)

            if revealedData then
                -- Hot-swap the behaviour tree so the bot acts correctly
                local newTree = revealedData:GetBTree()
                if newTree then
                    local loco = ply.BotLocomotor and ply:BotLocomotor()
                    if loco and loco.SetBTree then
                        loco:SetBTree(newTree)
                    end
                end

                -- Update team flags on the living locomotor component
                local startsFights = revealedData:GetStartsFights()
                local usesSusp    = revealedData:GetUsesSuspicion()
                local morality = ply.BotMorality and ply:BotMorality()
                if morality then
                    if startsFights ~= nil then morality:SetStartsFights(startsFights) end
                    if usesSusp   ~= nil then morality:SetUsesSuspicion(usesSusp) end
                end
            end

            local chatter = ply:BotChatter()
            if chatter and chatter.On then
                chatter:On("DrunkRevealed", { player = ply:Nick() }, false)
            end
        end)
    end)

print("[TTT Bots 2] Drunk role integration loaded.")
return true