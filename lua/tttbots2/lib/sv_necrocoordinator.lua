--- sv_necrocoordinator.lua
--- Detects mid-round zombie creation via TTT2UpdateSubrole, publishes events,
--- tracks necromancer→zombie relationships, and provides lightweight swarm
--- coordination for necromancer zombie bots.
--- Mirrors sv_infectedcoordinator.lua for the Necromancer role.
--- This file is auto-included by IncludeDirectory("tttbots2/lib").

local lib = TTTBots.Lib

TTTBots.NecroCoordinator = TTTBots.NecroCoordinator or {}
local Coord = TTTBots.NecroCoordinator

--- Track active zombies per necromancer { [necro] = { zombie1, zombie2, ... } }
Coord._zombiesByMaster = Coord._zombiesByMaster or {}

--- Track total zombie count.
Coord._totalZombieCount = 0

--- The current swarm focus target (the player all zombies should prioritise).
Coord._swarmTarget = nil

-- ---------------------------------------------------------------------------
-- Zombie creation detection via TTT2UpdateSubrole hook
-- ---------------------------------------------------------------------------

hook.Add("TTT2UpdateSubrole", "TTTBots.NecroCoordinator.DetectZombieCreation", function(ply, oldSubrole, newSubrole)
    if not ROLE_ZOMBIE then return end
    if newSubrole ~= ROLE_ZOMBIE then return end
    if oldSubrole == newSubrole then return end

    -- This player was just converted into a zombie by the necromancer.
    timer.Simple(0.1, function()
        if not IsValid(ply) then return end

        -- Find the necromancer master from the zombieMaster field set by AddZombie()
        local master = ply.zombieMaster

        -- Track the zombie under its master
        if IsValid(master) then
            Coord._zombiesByMaster[master] = Coord._zombiesByMaster[master] or {}
            table.insert(Coord._zombiesByMaster[master], ply)
        end

        -- Update total count
        Coord._totalZombieCount = Coord._totalZombieCount + 1

        -- Publish the zombie creation event
        if TTTBots.Events and TTTBots.Events.Publish then
            TTTBots.Events.Publish("NECRO_ZOMBIE_CREATED", {
                master = master,
                zombie = ply,
                zombieCount = Coord._totalZombieCount,
            })
        end

        -- Trigger chatter for bots that can see the newly risen zombie
        if TTTBots.Bots then
            for _, bot in ipairs(TTTBots.Bots) do
                if not IsValid(bot) then continue end
                if not lib.IsPlayerAlive(bot) then continue end
                if bot == ply or bot == master then continue end

                -- If the bot can see the newly risen zombie, react
                if bot:Visible(ply) then
                    local _c = bot:BotChatter()
                    if _c and _c.On then
                        _c:On("NecroZombieSpotted", { player = ply:Nick() })
                    end

                    -- Add suspicion evidence
                    local evidence = bot:BotEvidence()
                    if evidence then
                        evidence:AddEvidence({
                            type = "NECRO_ZOMBIE_WITNESSED",
                            subject = ply,
                            detail = "was just raised from the dead as a necromancer zombie",
                        })
                    end
                end
            end

            -- Fire ZombieRisen chatter for the zombie bot itself
            if ply:IsBot() then
                local _c = ply:BotChatter()
                if _c and _c.On then
                    timer.Simple(math.random(1, 3), function()
                        if not IsValid(ply) then return end
                        _c:On("ZombieRisen", {}, false, 0)
                    end)
                end
            end
        end
    end)
end)

-- ---------------------------------------------------------------------------
-- Necromancer death detection
-- ---------------------------------------------------------------------------

hook.Add("PlayerDeath", "TTTBots.NecroCoordinator.NecromancerDeath", function(victim, inflictor, attacker)
    if not IsValid(victim) then return end
    if not ROLE_NECROMANCER then return end

    -- Check if the victim was a necromancer
    if victim:GetSubRole() ~= ROLE_NECROMANCER then return end

    -- Publish event
    if TTTBots.Events and TTTBots.Events.Publish then
        TTTBots.Events.Publish("NECRO_MASTER_DIED", {
            master = victim,
            killer = attacker,
        })
    end

    -- Notify zombie bots that their master has died
    local zombies = Coord._zombiesByMaster[victim]
    if zombies then
        for _, zombie in ipairs(zombies) do
            if IsValid(zombie) and lib.IsPlayerAlive(zombie) and zombie:IsBot() then
                local _c = zombie:BotChatter()
                if _c and _c.On then
                    timer.Simple(math.random(1, 3), function()
                        if not IsValid(zombie) then return end
                        _c:On("NecroMasterDied", { player = victim:Nick() }, false, 0)
                    end)
                end
            end
        end
    end

    -- Clean up tracking for this master
    Coord._zombiesByMaster[victim] = nil

    -- Bots that can see this react with chatter
    if TTTBots.Bots then
        for _, bot in ipairs(TTTBots.Bots) do
            if not IsValid(bot) then continue end
            if not lib.IsPlayerAlive(bot) then continue end
            if bot == victim then continue end

            if bot:Visible(victim) then
                local role = TTTBots.Roles.GetRoleFor(bot)
                -- Only non-necro-team bots celebrate
                if role and role:GetTeam() ~= TEAM_NECROMANCER then
                    local _c = bot:BotChatter()
                    if _c and _c.On then
                        _c:On("NecroMasterKilled", { player = victim:Nick() })
                    end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Zombie death detection
-- ---------------------------------------------------------------------------

hook.Add("PlayerDeath", "TTTBots.NecroCoordinator.ZombieDeath", function(victim, inflictor, attacker)
    if not IsValid(victim) then return end
    if not ROLE_ZOMBIE then return end
    if victim:GetSubRole() ~= ROLE_ZOMBIE then return end

    -- Remove from tracking
    for master, zombies in pairs(Coord._zombiesByMaster) do
        for i, zombie in ipairs(zombies) do
            if zombie == victim then
                table.remove(zombies, i)
                break
            end
        end
    end

    -- Update total count
    Coord._totalZombieCount = math.max(0, Coord._totalZombieCount - 1)

    -- Publish event
    if TTTBots.Events and TTTBots.Events.Publish then
        TTTBots.Events.Publish("NECRO_ZOMBIE_DIED", {
            zombie = victim,
            killer = attacker,
            remainingZombies = Coord._totalZombieCount,
        })
    end
end)

-- ---------------------------------------------------------------------------
-- Swarm coordination: assign a shared focus target for all zombies
-- ---------------------------------------------------------------------------

--- Get the current swarm target, or nil if none is set.
---@return Player?
function Coord.GetSwarmTarget()
    if IsValid(Coord._swarmTarget) and lib.IsPlayerAlive(Coord._swarmTarget) then
        return Coord._swarmTarget
    end
    Coord._swarmTarget = nil
    return nil
end

--- Set a swarm focus target for all zombies.
---@param target Player?
function Coord.SetSwarmTarget(target)
    Coord._swarmTarget = target
end

--- Get all living zombies under a given necromancer.
---@param master Player
---@return table
function Coord.GetZombiesFor(master)
    if not IsValid(master) then return {} end
    local zombies = Coord._zombiesByMaster[master] or {}
    local alive = {}
    for _, z in ipairs(zombies) do
        if IsValid(z) and lib.IsPlayerAlive(z) then
            table.insert(alive, z)
        end
    end
    return alive
end

--- Get the total number of living zombies.
---@return number
function Coord.GetTotalZombieCount()
    local count = 0
    for _, zombies in pairs(Coord._zombiesByMaster) do
        for _, z in ipairs(zombies) do
            if IsValid(z) and lib.IsPlayerAlive(z) then
                count = count + 1
            end
        end
    end
    return count
end

--- Periodically pick the best swarm target: the non-allied player closest to the necromancer.
timer.Create("TTTBots.NecroCoordinator.SwarmTick", 2, 0, function()
    if not TTTBots.Match.IsRoundActive() then return end
    if not ROLE_NECROMANCER then return end

    -- Find the first living necromancer
    local necro = nil
    for master, _ in pairs(Coord._zombiesByMaster) do
        if IsValid(master) and lib.IsPlayerAlive(master) then
            necro = master
            break
        end
    end

    -- Fallback: find any living necromancer
    if not necro then
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:GetSubRole() == ROLE_NECROMANCER and lib.IsPlayerAlive(ply) then
                necro = ply
                break
            end
        end
    end

    if not necro then
        Coord._swarmTarget = nil
        return
    end

    -- Get non-allies of the necromancer
    local nonAllies = TTTBots.Roles.GetNonAllies(necro)
    if not nonAllies or #nonAllies == 0 then
        Coord._swarmTarget = nil
        return
    end

    -- Pick the closest non-ally to the necromancer
    local closest = lib.GetClosest(nonAllies, necro:GetPos())
    if closest and IsValid(closest) and lib.IsPlayerAlive(closest) then
        Coord._swarmTarget = closest
    else
        Coord._swarmTarget = nil
    end

    -- Fire team rally chatter occasionally
    if Coord._swarmTarget and necro:IsBot() and math.random(1, 5) == 1 then
        local _c = necro:BotChatter()
        if _c and _c.On then
            _c:On("NecroTeamRally", { player = Coord._swarmTarget:Nick() }, true)
        end
    end
end)

--- Multi-zombie flanking: when 2+ zombies exist, try to coordinate approach vectors.
--- Assigns alternating zombies to approach from different sides of the target.
timer.Create("TTTBots.NecroCoordinator.FlankTick", 3, 0, function()
    if not TTTBots.Match.IsRoundActive() then return end

    local swarmTarget = Coord.GetSwarmTarget()
    if not swarmTarget then return end

    for master, zombies in pairs(Coord._zombiesByMaster) do
        local aliveZombies = {}
        for _, z in ipairs(zombies) do
            if IsValid(z) and lib.IsPlayerAlive(z) and z:IsBot() then
                table.insert(aliveZombies, z)
            end
        end

        -- Only flank with 2+ zombies
        if #aliveZombies < 2 then continue end

        local targetPos = swarmTarget:GetPos()
        local angleStep = 360 / #aliveZombies

        for i, zombie in ipairs(aliveZombies) do
            -- Store a flanking offset angle for this zombie
            local state = TTTBots.Behaviors.GetState(zombie, "ZombieAttack")
            state.flankAngle = angleStep * (i - 1)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Round cleanup
-- ---------------------------------------------------------------------------

hook.Add("TTTEndRound", "TTTBots.NecroCoordinator.Cleanup", function()
    Coord._zombiesByMaster = {}
    Coord._totalZombieCount = 0
    Coord._swarmTarget = nil
end)

-- ---------------------------------------------------------------------------
-- Necromancer victory chatter
-- ---------------------------------------------------------------------------

hook.Add("TTTEndRound", "TTTBots.NecroCoordinator.VictoryChatter", function(result)
    if not TEAM_NECROMANCER then return end
    if result ~= TEAM_NECROMANCER then return end

    if not TTTBots.Bots then return end
    for _, bot in ipairs(TTTBots.Bots) do
        if not (IsValid(bot) and bot.components) then continue end
        local role = TTTBots.Roles.GetRoleFor(bot)
        if not (role and role:GetTeam() == TEAM_NECROMANCER) then continue end

        local chatter = bot:BotChatter()
        if chatter and math.random(1, 2) == 1 then
            timer.Simple(math.random(1, 3), function()
                if not IsValid(bot) then return end
                chatter:On("NecroVictory", {}, true, 0)
            end)
        end
    end
end)
