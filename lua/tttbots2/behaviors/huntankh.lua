--- HuntAnkh: Graverobber bot proactively searches the map for the Pharaoh's
--- placed ankh, prioritizing secluded areas where Pharaohs are likely to hide it.

TTTBots.Behaviors.HuntAnkh = {}

local lib = TTTBots.Lib

local HuntAnkh = TTTBots.Behaviors.HuntAnkh
HuntAnkh.Name = "HuntAnkh"
HuntAnkh.Description = "Proactively search for the Pharaoh's ankh"
HuntAnkh.Interruptible = true

local STATUS = TTTBots.STATUS

--- Maximum time (seconds) to spend searching before giving up for a while
HuntAnkh.MAX_SEARCH_TIME = 60
--- Cooldown between search attempts
HuntAnkh.SEARCH_COOLDOWN = 30
--- How close we need to be to a search point to mark it "checked"
HuntAnkh.ARRIVAL_DIST = 100
--- How long to look around at each search point
HuntAnkh.SCAN_TIME = 3

--- Validate the behavior
function HuntAnkh.Validate(bot)
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.attackTarget ~= nil then return false end

    -- Only Graverobbers who DON'T already control an ankh
    if bot:GetSubRole() ~= ROLE_GRAVEROBBER then return false end
    if PHARAOH_HANDLER:PlayerControlsAnAnkh(bot) then return false end

    -- Don't hunt for ankhs in late/overtime — abandon the objective and engage remaining targets
    local ra = bot.BotRoundAwareness and bot:BotRoundAwareness()
    if ra then
        local PHASE = TTTBots.Components.RoundAwareness and TTTBots.Components.RoundAwareness.PHASE
        local phase = ra:GetPhase()
        if PHASE and (phase == PHASE.LATE or phase == PHASE.OVERTIME) then
            return false -- Fall through to Stalk/FightBack/combat behaviors
        end
    end

    -- If there's already a visible ankh, CaptureAnkh will handle it
    local ankhs = ents.FindByClass("ttt_ankh")
    for _, ankh in pairs(ankhs) do
        if IsValid(ankh) and bot:Visible(ankh) then
            return false
        end
    end

    -- Cooldown check
    if (bot._lastHuntAnkhEnd or 0) + HuntAnkh.SEARCH_COOLDOWN > CurTime() then
        return false
    end

    -- Must have at least one ankh on the map (placed but not yet found)
    if #ankhs == 0 then return false end

    return true
end

--- Build a list of candidate search positions, prioritizing secluded areas
---@param bot Entity
---@return table
function HuntAnkh.BuildSearchCandidates(bot)
    local candidates = {}

    -- Try using the hiding spots system first (secluded areas)
    if TTTBots.Spots and TTTBots.Spots.GetSpotsInCategory then
        local hidingSpots = TTTBots.Spots.GetSpotsInCategory("hiding")
        if hidingSpots then
            for _, spot in pairs(hidingSpots) do
                local pos = spot.pos or spot
                if isvector(pos) then
                    table.insert(candidates, { pos = pos, priority = 3 })
                end
            end
        end

        -- Also check sniper spots (could be secluded areas too)
        local sniperSpots = TTTBots.Spots.GetSpotsInCategory("sniper")
        if sniperSpots then
            for _, spot in pairs(sniperSpots) do
                local pos = spot.pos or spot
                if isvector(pos) then
                    table.insert(candidates, { pos = pos, priority = 2 })
                end
            end
        end
    end

    -- Fall back to navmesh areas if no spot data
    if #candidates == 0 then
        local allAreas = navmesh.GetAllNavAreas()
        if allAreas then
            for _, area in pairs(allAreas) do
                if not IsValid(area) then continue end
                local connections = area:GetAdjacentCount()
                -- Prefer dead ends and low-traffic areas (few connections)
                local priority = 1
                if connections <= 2 then
                    priority = 3 -- dead end or corridor
                elseif connections <= 4 then
                    priority = 2
                end
                table.insert(candidates, { pos = area:GetCenter(), priority = priority })
            end
        end
    end

    -- Use knowledge of where the Pharaoh was last seen
    if bot.components and bot.components.memory then
        local memory = bot.components.memory
        for _, ply in pairs(player.GetAll()) do
            if IsValid(ply) and ply:GetSubRole() == ROLE_PHARAOH then
                -- If Pharaoh is dead, search near their death location
                if not lib.IsPlayerAlive(ply) then
                    local corpses = TTTBots.Match.Corpses or {}
                    for _, rag in pairs(corpses) do
                        if IsValid(rag) then
                            table.insert(candidates, { pos = rag:GetPos(), priority = 5 })
                        end
                    end
                else
                    -- Search where the Pharaoh has been spending time
                    local lastSeen = memory.lastSeenPositions and memory.lastSeenPositions[ply]
                    if lastSeen then
                        table.insert(candidates, { pos = lastSeen, priority = 4 })
                    end
                end
            end
        end
    end

    -- Sort by priority (highest first) and shuffle within same priority
    table.sort(candidates, function(a, b) return a.priority > b.priority end)

    return candidates
end

--- Called when the behavior is started
function HuntAnkh.OnStart(bot)
    bot._huntAnkhStart = CurTime()
    bot._huntAnkhCandidates = HuntAnkh.BuildSearchCandidates(bot)
    bot._huntAnkhIndex = 1
    bot._huntAnkhChecked = bot._huntAnkhChecked or {}
    bot._huntAnkhScanStart = nil

    -- Fire chatter about hunting (team only for Graverobbers)
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("HuntingAnkh", {}, true)
    end

    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function HuntAnkh.OnRunning(bot)
    -- Time limit on searching
    if CurTime() - (bot._huntAnkhStart or 0) > HuntAnkh.MAX_SEARCH_TIME then
        return STATUS.FAILURE
    end

    -- If an ankh becomes visible during search, let CaptureAnkh take over
    local ankhs = ents.FindByClass("ttt_ankh")
    for _, ankh in pairs(ankhs) do
        if IsValid(ankh) and bot:Visible(ankh) then
            -- Fire ankh spotted chatter
            local chatter = bot:BotChatter()
            if chatter and chatter.On then
                chatter:On("AnkhSpotted", {}, true)
            end
            return STATUS.SUCCESS
        end
    end

    if bot.attackTarget ~= nil then return STATUS.FAILURE end

    local candidates = bot._huntAnkhCandidates or {}
    local index = bot._huntAnkhIndex or 1
    local locomotor = bot:BotLocomotor()

    -- If we've exhausted candidates, fail out
    if index > #candidates then
        return STATUS.FAILURE
    end

    local target = candidates[index]
    if not target or not target.pos then
        bot._huntAnkhIndex = index + 1
        return STATUS.RUNNING
    end

    local targetPos = target.pos
    local dist = bot:GetPos():Distance(targetPos)

    -- If we're scanning at the current spot
    if bot._huntAnkhScanStart then
        -- Look around for the ankh
        local scanElapsed = CurTime() - bot._huntAnkhScanStart
        local lookAngle = scanElapsed * 120 -- rotate 120 deg/sec
        local lookDir = Vector(math.cos(math.rad(lookAngle)), math.sin(math.rad(lookAngle)), 0)
        locomotor:LookAt(bot:GetPos() + lookDir * 200)

        if scanElapsed >= HuntAnkh.SCAN_TIME then
            -- Done scanning, move to next candidate
            bot._huntAnkhScanStart = nil
            bot._huntAnkhChecked[tostring(targetPos)] = true
            bot._huntAnkhIndex = index + 1
        end
        return STATUS.RUNNING
    end

    -- Skip already-checked positions
    if bot._huntAnkhChecked[tostring(targetPos)] then
        bot._huntAnkhIndex = index + 1
        return STATUS.RUNNING
    end

    -- Navigate to the target position
    if dist > HuntAnkh.ARRIVAL_DIST then
        locomotor:SetGoal(targetPos)
        return STATUS.RUNNING
    end

    -- Arrived at search point — start scanning
    bot._huntAnkhScanStart = CurTime()
    return STATUS.RUNNING
end

--- Called when the behavior returns a success state
function HuntAnkh.OnSuccess(bot)
    bot._lastHuntAnkhEnd = CurTime()
end

--- Called when the behavior returns a failure state
function HuntAnkh.OnFailure(bot)
    bot._lastHuntAnkhEnd = CurTime()
end

--- Called when the behavior ends
function HuntAnkh.OnEnd(bot)
    bot._huntAnkhStart = nil
    bot._huntAnkhCandidates = nil
    bot._huntAnkhIndex = nil
    bot._huntAnkhScanStart = nil
end
