--- behaviors/usepoisondart.lua
--- Bot behavior: use the Poison Dart Gun to stealthily poison an isolated target.

TTTBots.Behaviors.RegisterRoleWeapon({
    name            = "UsePoisonDart",
    description     = "Fire a poison dart at an isolated enemy for stealthy DOT damage",
    interruptible   = true,

    -- Weapon access via inventory
    hasWeaponFn     = function(bot)
        return bot:HasWeapon("weapon_ttt2_poison_dart")
            and bot:GetWeapon("weapon_ttt2_poison_dart"):Clip1() > 0
    end,
    equipDirectFn   = function(bot)
        local wep = bot:GetWeapon("weapon_ttt2_poison_dart")
        return IsValid(wep) and wep or nil
    end,

    -- Targeting: find an isolated visible enemy
    findTargetFn    = function(bot)
        return TTTBots.Lib.FindIsolatedTarget(bot)
    end,
    stateKey        = "PoisonTarget",

    -- Engagement: medium range, prefer few witnesses
    engageDistance       = 800,
    witnessThreshold     = 1,
    startChance          = 3,
    clipEmptyFails       = true,

    -- Chatter
    chatterEvent    = "UsingPoisonDart",
    chatterTeamOnly = true,
})
