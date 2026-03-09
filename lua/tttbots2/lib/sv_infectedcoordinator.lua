--- sv_infectedcoordinator.lua
--- Detects mid-round infections via TTT2UpdateSubrole, publishes events,
--- and provides lightweight swarm coordination for infected zombie bots.
--- This file is auto-included by IncludeDirectory("tttbots2/lib").

local lib = TTTBots.Lib

TTTBots.InfectedCoordinator = TTTBots.InfectedCoordinator or {}
local Coord = TTTBots.InfectedCoordinator

--- Track the last known zombie count per host so we can detect new infections.
Coord._lastZombieCounts = Coord._lastZombieCounts or {}

--- The current swarm focus target (the player all zombies should prioritise).
Coord._swarmTarget = nil

-- ---------------------------------------------------------------------------
-- Infection detection via TTT2UpdateSubrole hook
-- ---------------------------------------------------------------------------

hook.Add("TTT2UpdateSubrole", "TTTBots.InfectedCoordinator.DetectInfection", function(ply, oldSubrole, newSubrole)
    -- Only care about changes TO the infected subrole
    if not ROLE_INFECTED then return end
    if newSubrole ~= ROLE_INFECTED then return end
    if oldSubrole == newSubrole then return end

    -- This player was just converted into an infected (zombie).
    -- Find their host from the INFECTEDS global.
    timer.Simple(0.1, function()
        if not IsValid(ply) then return end
        if not INFECTEDS then return end

        local host = nil
        for h, zombies in pairs(INFECTEDS) do
            if istable(zombies) then
                for _, z in ipairs(zombies) do
                    if z == ply then
                        host = h
                        break
                    end
                end
            end
            if host then break end
        end

        local zombieCount = 0
        if host and INFECTEDS[host] and istable(INFECTEDS[host]) then
            zombieCount = #INFECTEDS[host]
        end

        -- Publish the infection event on the event bus
        TTTBots.Events.Publish(TTTBots.Events.NAMES.INFECTION_OCCURRED, {
            host = host,
            victim = ply,
            zombieCount = zombieCount,
        })

        -- Trigger chatter for bots that can see this player
        if TTTBots.Bots then
            for _, bot in ipairs(TTTBots.Bots) do
                if not IsValid(bot) then continue end
                if not lib.IsPlayerAlive(bot) then continue end
                if bot == ply or bot == host then continue end

                -- If the bot can see the newly converted zombie, react
                if bot:Visible(ply) then
                    local _c = bot:BotChatter()
                    if _c and _c.On then
                        _c:On("ZombieSpotted", { player = ply:Nick() })
                    end

                    -- Add suspicion evidence
                    local evidence = bot:BotEvidence()
                    if evidence then
                        evidence:AddEvidence({
                            type = "INFECTION_WITNESSED",
                            subject = ply,
                            detail = "was just converted into an infected zombie",
                        })
                    end

                    -- Publish zombie spotted event
                    TTTBots.Events.Publish(TTTBots.Events.NAMES.ZOMBIE_SPOTTED, {
                        witness = bot,
                        zombie = ply,
                    })
                end
            end
        end
    end)
end)

-- ---------------------------------------------------------------------------
-- Host death detection
-- ---------------------------------------------------------------------------

hook.Add("PlayerDeath", "TTTBots.InfectedCoordinator.HostDeath", function(victim, inflictor, attacker)
    if not IsValid(victim) then return end
    if not INFECTEDS then return end

    -- Check if the victim was a host (had zombies)
    if INFECTEDS[victim] then
        TTTBots.Events.Publish(TTTBots.Events.NAMES.HOST_DIED, {
            host = victim,
            killer = attacker,
        })

        -- Bots that can see this react with chatter
        if TTTBots.Bots then
            for _, bot in ipairs(TTTBots.Bots) do
                if not IsValid(bot) then continue end
                if not lib.IsPlayerAlive(bot) then continue end
                if bot == victim then continue end

                if bot:Visible(victim) then
                    local _c = bot:BotChatter()
                    if _c and _c.On then
                        _c:On("HostKilled", { player = victim:Nick() })
                    end
                end
            end
        end
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

--- Periodically pick the best swarm target: the non-allied player closest to the host.
timer.Create("TTTBots.InfectedCoordinator.SwarmTick", 2, 0, function()
    if not TTTBots.Match.IsRoundActive() then return end
    if not INFECTEDS then return end

    -- Find the first living host
    local host = nil
    for h, _ in pairs(INFECTEDS) do
        if IsValid(h) and lib.IsPlayerAlive(h) then
            host = h
            break
        end
    end

    if not host then
        Coord._swarmTarget = nil
        return
    end

    -- Get the host's role data to find non-allies
    local nonAllies = TTTBots.Roles.GetNonAllies(host)
    if not nonAllies or #nonAllies == 0 then
        Coord._swarmTarget = nil
        return
    end

    -- Pick the closest non-ally to the host
    local closest = TTTBots.Lib.GetClosest(nonAllies, host:GetPos())
    if closest and IsValid(closest) and lib.IsPlayerAlive(closest) then
        Coord._swarmTarget = closest
    else
        Coord._swarmTarget = nil
    end
end)

-- ---------------------------------------------------------------------------
-- Round cleanup
-- ---------------------------------------------------------------------------

hook.Add("TTTEndRound", "TTTBots.InfectedCoordinator.Cleanup", function()
    Coord._lastZombieCounts = {}
    Coord._swarmTarget = nil
end)
