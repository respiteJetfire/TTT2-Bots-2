TTTBots.Spots = {}
TTTBots.Spots.CachedSpots = {
    ["all"] = {},
}

--- Go to through all of the spots on the navmesh and categorize them ourselves.
---@return table<Vector>
function TTTBots.Spots.CacheAllSpots()
    local allNavs = navmesh.GetAllNavAreas()
    for i,v in pairs(allNavs) do
        local exposedSpots = v:GetExposedSpots()
        local hidingSpots = v:GetHidingSpots()
        for i,v in pairs(exposedSpots) do
            table.insert(TTTBots.Spots.CachedSpots["all"], v)
        end
        for i,v in pairs(hidingSpots) do
            table.insert(TTTBots.Spots.CachedSpots["all"], v)
        end
    end
    TTTBots.Spots.CacheSpecialSpots()

    return TTTBots.Spots.CachedSpots["all"]
end

function TTTBots.Spots.GetAllSpots()
    return TTTBots.Spots.CachedSpots["all"]
end

function TTTBots.Spots.RegisterSpotCategory(title, spotValidCallback)
    TTTBots.Spots.CachedSpots[title] = {}
    TTTBots.Spots.CachedSpots[title].IsValid = spotValidCallback
    TTTBots.Spots.CachedSpots[title].Spots = {}

    local spotsToFilter = TTTBots.Spots.GetAllSpots()
    for i, spot in pairs(spotsToFilter) do
        if spotValidCallback(spot) then
            table.insert(TTTBots.Spots.CachedSpots[title].Spots, spot)
        end
    end

    print(string.format("Registered spot category '%s' with %d spots.", title, #TTTBots.Spots.CachedSpots[title].Spots))
end

function TTTBots.Spots.GetSpotsInCategory(title)
    return TTTBots.Spots.CachedSpots[title].Spots
end

function TTTBots.Spots.CacheSpecialSpots()
    local SNIPER_MIN_TO_BE_CONSIDERED = 5
    local SniperExclusionaryFunc = function(spot)
        local visibleNavs = 0
        local myNav = navmesh.GetNearestNavArea(spot)
        local navsICanSee = myNav:GetVisibleAreas()
        for i,nav in pairs(navsICanSee) do
            if not nav:IsPartiallyVisible(spot) then -- If we can see them, but they can't see us (this is for exclusionary)
                visibleNavs = visibleNavs + 1
            end
        end
        return visibleNavs >= SNIPER_MIN_TO_BE_CONSIDERED
    end

    local HIDING_MAX_AREA_METERS = 500 -- 500 square meters
    local visibleAreaAverage = 0
    local visibleAreaCount = 0
    local HidingFunc = function(spot)
        local myNav = navmesh.GetNearestNavArea(spot)
        local visibleAreas = myNav:GetVisibleAreas()
        local totalVisArea = 0
        for i,nav in pairs(visibleAreas) do
            local area = nav:GetSizeX() * nav:GetSizeY()
            totalVisArea = totalVisArea + area
        end

        visibleAreaAverage = visibleAreaAverage + totalVisArea
        visibleAreaCount = visibleAreaCount + 1

        return totalVisArea <= TTTBots.Lib.MetersToHU(HIDING_MAX_AREA_METERS)
    end

    TTTBots.Spots.RegisterSpotCategory("sniper", SniperExclusionaryFunc)
    TTTBots.Spots.RegisterSpotCategory("hiding", HidingFunc)
    
    print(string.format("Average visible area: %dm^2", TTTBots.Lib.HUToMeters(visibleAreaAverage / visibleAreaCount) ))
end