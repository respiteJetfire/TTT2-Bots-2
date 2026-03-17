--- behaviors/rolechangedeagle.lua
--- Uses the Role Change Deagle (weapon_ttt2_role_change_deagle) to randomly
--- change a target's role within their own team.
--- This is a detective-only weapon, so targets should be non-allies (evil players
--- the detective wants to disrupt).
---
--- Uses the RegisterRoleWeapon factory since it's a standard "aim and fire at target"
--- deagle-style weapon.

TTTBots.Behaviors.RegisterRoleWeapon({
    name         = "RoleChangeDeagle",
    description  = "Use the Role Change Deagle to disrupt an enemy's role.",
    stateKey     = "RoleChangeTarget",

    --- Weapon access: direct bot check (no inventory getter needed for this pattern).
    hasWeaponFn = function(bot)
        if not bot:HasWeapon("weapon_ttt2_role_change_deagle") then return false end
        local wep = bot:GetWeapon("weapon_ttt2_role_change_deagle")
        if not IsValid(wep) then return false end
        -- Must have clip ammo and refill timer must not be active
        return wep:Clip1() > 0
    end,
    equipDirectFn = function(bot)
        local wep = bot:GetWeapon("weapon_ttt2_role_change_deagle")
        return IsValid(wep) and wep or nil
    end,

    --- Target: find a non-ally player. Prefer evil team players the detective knows about.
    findTargetFn = function(bot)
        local best = nil
        local bestScore = -1
        for _, ply in pairs(player.GetAll()) do
            if not IsValid(ply) or not ply:Alive() or ply == bot then continue end
            if TTTBots.Roles.IsAllies(bot, ply) then continue end
            -- Skip jesters
            if ply.GetSubRoleData and ply:GetSubRoleData() and ply:GetSubRoleData().defaultTeam == TEAM_NONE then continue end
            -- Prefer players the bot suspects or has evidence against
            local score = 1
            local suspect = TTTBots.Behaviors.GetSuspicion and TTTBots.Behaviors.GetSuspicion(bot, ply)
            if suspect and suspect > 0 then score = score + suspect end
            -- Prefer closer targets
            local dist = bot:GetPos():Distance(ply:GetPos())
            if dist < 500 then score = score + 3 end
            if dist < 800 then score = score + 1 end
            -- Bot must be able to see the target
            if not bot:Visible(ply) then continue end
            if score > bestScore then
                bestScore = score
                best = ply
            end
        end
        return best
    end,

    engageDistance = 1000,
    minDistance    = 200,
    witnessThreshold = nil,  -- Detective can fire openly, no witness check needed
    startChance   = 15,
    isConversion  = false,  -- Not a conversion (detective utility)
    clipEmptyFails = true,  -- Fail when out of ammo

    chatterEvent = "UsingRoleChangeDeagle",
    chatterTeamOnly = false,  -- Detective can announce openly
})
