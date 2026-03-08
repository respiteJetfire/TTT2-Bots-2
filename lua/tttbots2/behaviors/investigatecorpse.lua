
---@class InvestigateCorpse
TTTBots.Behaviors.InvestigateCorpse = {}

local lib = TTTBots.Lib
---@class InvestigateCorpse
local InvestigateCorpse = TTTBots.Behaviors.InvestigateCorpse
InvestigateCorpse.Name = "InvestigateCorpse"
InvestigateCorpse.Description = "Investigate the corpse of a fallen player"
InvestigateCorpse.Interruptible = true

local STATUS = TTTBots.STATUS

---@deprecated deprecated until distance check, technically works tho
function InvestigateCorpse.GetVisibleCorpses(bot)
    local corpses = TTTBots.Match.Corpses
    local visibleCorpses = {}
    for i, corpse in pairs(corpses) do
        local visible = bot:VisibleVec(corpse:GetPos())
        if visible then
            table.insert(visibleCorpses, corpse)
        end
    end
    return visibleCorpses
end

local CORPSE_MAXDIST = 2000
function InvestigateCorpse.GetVisibleUnidentified(bot)
    local corpses = TTTBots.Match.Corpses
    local results = {}
    for i, corpse in pairs(corpses) do
        if not IsValid(corpse) then continue end
        local visible = bot:Visible(corpse)
        local found = CORPSE.GetFound(corpse, false)
        local distTo = bot:GetPos():Distance(corpse:GetPos())
        -- TTTBots.DebugServer.DrawCross(corpse:GetPos(), 10, Color(255, 0, 0), 1, "body")
        if not found and visible and distTo < CORPSE_MAXDIST then
            table.insert(results, corpse)
        end
    end
    return results
end

--- Called every tick; basically just rolls a dice for if we should investigate any corpses this tick
function InvestigateCorpse.GetShouldInvestigateCorpses(bot)
    local BASE_PCT = 75
    local MIN_PCT = 5
    local personality = bot:BotPersonality()
    if not personality then return false end
    local mult = personality:GetTraitMult("investigateCorpse")
    return lib.TestPercent(
        math.max(MIN_PCT, BASE_PCT * mult)
    )
end

function InvestigateCorpse.CorpseValid(rag)
    if rag == nil then return false, "nil" end                         -- The corpse is nil.
    if not IsValid(rag) then return false, "invalid" end               -- The corpse is invalid.
    if not lib.IsValidBody(rag) then return false, "invalidbody" end   -- The corpse is not a valid body.
    if CORPSE.GetFound(rag, false) then return false, "discovered" end -- The corpse was discovered.

    return true, "valid"
end

--- Returns true if the given corpse belongs to a player this innocent bot killed in self-defense.
---@param bot Bot
---@param corpse Entity
---@return boolean
local function isOwnSelfDefenseKill(bot, corpse)
    if bot:GetTeam() ~= TEAM_INNOCENT then return false end
    local sdKills = bot.selfDefenseKills
    if not sdKills then return false end
    local victim = CORPSE.GetPlayer(corpse)
    return IsValid(victim) and sdKills[victim] ~= nil
end

--- Validate the behavior
function InvestigateCorpse.Validate(bot)
    if not InvestigateCorpse.GetShouldInvestigateCorpses(bot) then return false end

    -- Prevent traitors (and other post-kill cooldown cases) from immediately self-reporting.
    -- Exception: innocent-side bots should confirm bodies they killed in self-defense right away
    -- so they don't look suspicious standing next to an unidentified corpse they just made.
    local lastKillTime = bot.lastKillTime or 0
    local killedRecently = (CurTime() - lastKillTime) < 7 -- killed someone within X seconds

    local curCorpse = bot.corpseTarget
    if InvestigateCorpse.CorpseValid(curCorpse) then
        -- Allow confirming the current target if it's a self-defense kill (even right after)
        if killedRecently and not isOwnSelfDefenseKill(bot, curCorpse) then return false end
        return true
    end

    if killedRecently then
        -- Check if any visible unidentified body is one this innocent bot killed in self-defense
        local options = InvestigateCorpse.GetVisibleUnidentified(bot)
        if not options or #options == 0 then return false end
        local selfDefenseTarget = nil
        for _, corpse in ipairs(options) do
            if isOwnSelfDefenseKill(bot, corpse) then
                selfDefenseTarget = corpse
                break
            end
        end
        if not selfDefenseTarget then return false end
        bot.corpseTarget = selfDefenseTarget
        return true
    end

    local options = InvestigateCorpse.GetVisibleUnidentified(bot)
    if options and #options == 0 then return false end

    local closest = lib.GetClosest(options, bot:GetPos())
    if not InvestigateCorpse.CorpseValid(closest) then return false end

    -- local unreachable = TTTBots.PathManager.IsUnreachableVec(bot:GetPos(), closest:GetPos())
    -- if not unreachable then
    --     print("Found corpse but it was unreachable")
    --     return false
    -- end

    bot.corpseTarget = closest
    return true
end

--- Called when the behavior is started
function InvestigateCorpse.OnStart(bot)
    local name = CORPSE.GetPlayerNick(bot.corpseTarget)
    local chatter = bot:BotChatter()
    if chatter and chatter.On then
        chatter:On("InvestigateCorpse", { corpse = name })
    end
    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function InvestigateCorpse.OnRunning(bot)
    local validation, result = InvestigateCorpse.CorpseValid(bot.corpseTarget)
    if not validation then
        return STATUS.FAILURE
    end
    local loco = bot:BotLocomotor()
    loco:LookAt(bot.corpseTarget:GetPos())
    loco:SetGoal(bot.corpseTarget:GetPos())

    local distToBody = bot:GetPos():Distance(bot.corpseTarget:GetPos())
    if distToBody < 80 then
        loco:StopMoving()
        CORPSE.ShowSearch(bot, bot.corpseTarget, false, false)
        CORPSE.SetFound(bot.corpseTarget, true)

        -- Extract evidence from the corpse
        local evidence = bot:BotEvidence()
        if evidence then
            local corpse = bot.corpseTarget
            -- Killer identity from corpse data
            local killerEnt = CORPSE.GetPlayer(corpse, "killer")
            local victimEnt = CORPSE.GetPlayer(corpse)
            if IsValid(killerEnt) and killerEnt:IsPlayer() and killerEnt ~= bot then
                local weaponClass = CORPSE.GetPlayerNick(corpse, "weapon") or "unknown weapon"
                evidence:AddEvidence({
                    type   = "WITNESSED_KILL",
                    subject = killerEnt,
                    victim  = victimEnt,
                    detail  = weaponClass .. " (from corpse)",
                    weight  = 8, -- slightly lower than direct witness
                })
                local chatter = bot:BotChatter()
                if chatter and chatter.On then
                    chatter:On("BodyEvidenceFound", {
                        killer = killerEnt:Nick(),
                        killerEnt = killerEnt,
                        victim = IsValid(victimEnt) and victimEnt:Nick() or CORPSE.GetPlayerNick(corpse) or "unknown",
                    })
                end
            end

            -- FindFriendBody — emotional reaction when a trusted player's body is found
            if lib.GetConVarBool("emotional_chatter") then
                local victimEnt = CORPSE.GetPlayer(bot.corpseTarget)
                if IsValid(victimEnt) then
                    local wasTrusted = false
                    local companions = evidence.travelCompanions or {}
                    for _, companion in ipairs(companions) do
                        if companion == victimEnt then wasTrusted = true; break end
                    end
                    if not wasTrusted then
                        local ci = evidence.confirmedInnocents or {}
                        for _, innocent in ipairs(ci) do
                            if innocent == victimEnt then wasTrusted = true; break end
                        end
                    end
                    if wasTrusted then
                        local chatter = bot:BotChatter()
                        if chatter and chatter.On then
                            chatter:On("FindFriendBody", {
                                victim    = victimEnt:Nick(),
                                victimEnt = victimEnt,
                            }, false, 0.5)
                        end
                    end
                end
            end
        end

        return STATUS.SUCCESS
    end
    return STATUS.RUNNING
end

--- Called when the behavior returns a success state
function InvestigateCorpse.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function InvestigateCorpse.OnFailure(bot)
end

--- Called when the behavior ends
function InvestigateCorpse.OnEnd(bot)
    bot.corpseTarget = nil
end
