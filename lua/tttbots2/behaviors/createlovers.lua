

local lib = TTTBots.Lib

-- Module-level set tracking already-targeted players (prevents double-targeting)
local targets = {}

TTTBots.Behaviors.RegisterRoleWeapon({
    name         = "CreateLovers",
    description  = "Apply lovers to the closest un-targeted player.",
    interruptible = true,
    stateKey     = "LoversTarget",
    getWeaponFn  = function(inv) return inv:GetLoversGun() end,
    equipFn      = function(inv) return inv:EquipLoversGun() end,
    findTargetFn = function(bot)
        local Alive = TTTBots.Match.AlivePlayers
        local dist = math.huge
        local closest = nil
        for _, ply in ipairs(Alive) do
            if ply == bot then continue end
            if targets[ply] then continue end
            local d = bot:GetPos():Distance(ply:GetPos())
            if d < dist then
                dist = d
                closest = ply
            end
        end
        return closest
    end,
    engageDistance = 150,
    startChance  = 2,
    onFireFn = function(bot, target)
        print("Loversing", bot, target)
        targets[target] = true
        return TTTBots.STATUS.SUCCESS
    end,
})

local CreateLovers = TTTBots.Behaviors.CreateLovers
local STATUS = TTTBots.STATUS
